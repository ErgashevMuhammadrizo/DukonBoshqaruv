import json
import logging
import os
import shutil
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import connections

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Create a private, consistent database backup and update backup status metadata.'

    def handle(self, *args, **options):
        target = Path(settings.BACKUP_DIR).expanduser().resolve()
        status_path = Path(settings.BACKUP_STATUS_FILE).expanduser() if settings.BACKUP_STATUS_FILE else target / 'status.json'
        timestamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        engine = connections['default'].settings_dict['ENGINE']
        suffix = 'sqlite3' if engine.endswith('sqlite3') else 'dump'
        filename = f'dokon-{timestamp}.{suffix}'
        target.mkdir(mode=0o700, parents=True, exist_ok=True)
        target.chmod(0o700)
        temp_path = None
        try:
            fd, temp_name = tempfile.mkstemp(prefix='.backup-', dir=target)
            os.close(fd)
            temp_path = Path(temp_name)
            if engine.endswith('sqlite3'):
                import sqlite3
                connections['default'].ensure_connection()
                source = connections['default'].connection
                destination = sqlite3.connect(str(temp_path))
                try:
                    source.backup(destination)
                    result = destination.execute('PRAGMA integrity_check').fetchone()
                    if not result or result[0] != 'ok':
                        raise CommandError('SQLite backup integrity check failed.')
                finally:
                    destination.close()
            elif engine.endswith('postgresql'):
                db = connections['default'].settings_dict
                executable = shutil.which('pg_dump')
                if not executable:
                    raise CommandError('pg_dump is required for PostgreSQL backups.')
                env = os.environ.copy()
                if db.get('PASSWORD'):
                    env['PGPASSWORD'] = str(db['PASSWORD'])
                command = [executable, '--format=custom', '--no-password', '--host', str(db.get('HOST') or ''), '--port', str(db.get('PORT') or 5432), '--username', str(db.get('USER') or ''), '--file', str(temp_path), str(db['NAME'])]
                subprocess.run(command, env=env, check=True, capture_output=True, text=True, timeout=3600)
            else:
                raise CommandError(f'Unsupported database backend: {engine}')
            os.chmod(temp_path, 0o600)
            final_path = target / filename
            os.replace(temp_path, final_path)
            temp_path = None
            previous = self._read_status(status_path)
            status = {
                'available': True,
                'last_success_at': datetime.now(timezone.utc).isoformat(),
                'last_error_at': previous.get('last_error_at'),
                'last_error': previous.get('last_error'),
                'filename': filename,
                'size_bytes': final_path.stat().st_size,
                'database_engine': 'sqlite' if suffix == 'sqlite3' else 'postgresql',
            }
            self._write_status(status_path, status)
            logger.info('Database backup completed: file=%s size_bytes=%s', filename, status['size_bytes'])
            self.stdout.write(self.style.SUCCESS(f'Backup created: {filename} ({status["size_bytes"]} bytes)'))
        except Exception as exc:
            old = self._read_status(status_path)
            self._write_status(status_path, {
                'available': bool(old.get('filename')),
                'last_success_at': old.get('last_success_at'),
                'last_error_at': datetime.now(timezone.utc).isoformat(),
                'last_error': type(exc).__name__,
                'filename': old.get('filename'),
                'size_bytes': old.get('size_bytes'),
                'database_engine': 'sqlite' if engine.endswith('sqlite3') else 'postgresql',
            })
            logger.exception('Database backup failed (%s)', type(exc).__name__)
            raise CommandError('Database backup failed; inspect protected server logs.') from exc
        finally:
            if temp_path:
                temp_path.unlink(missing_ok=True)

    @staticmethod
    def _read_status(path):
        try:
            return json.loads(path.read_text())
        except (OSError, ValueError):
            return {}

    @staticmethod
    def _write_status(path, data):
        path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        fd, temp_name = tempfile.mkstemp(prefix='.status-', dir=path.parent)
        try:
            with os.fdopen(fd, 'w') as stream:
                json.dump(data, stream)
                stream.write('\n')
            os.chmod(temp_name, 0o600)
            os.replace(temp_name, path)
        finally:
            Path(temp_name).unlink(missing_ok=True)
