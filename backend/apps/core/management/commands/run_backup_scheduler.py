import logging
import os
import time

from django.core.management import BaseCommand, call_command
from django.core.management.base import CommandError

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Run the opt-in periodic database backup worker.'

    def handle(self, *args, **options):
        interval = int(os.getenv('BACKUP_INTERVAL_SECONDS', '86400'))
        if interval < 60:
            raise CommandError('BACKUP_INTERVAL_SECONDS must be at least 60.')
        logger.info('Backup scheduler started; interval_seconds=%s', interval)
        while True:
            try:
                call_command('backup_database')
            except CommandError:
                logger.error('Scheduled database backup failed; next attempt after configured interval.')
            time.sleep(interval)
