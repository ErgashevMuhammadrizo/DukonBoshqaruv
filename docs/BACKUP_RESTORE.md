# Backup and restore

`python manage.py backup_database` creates a consistent SQLite copy using SQLite's online backup API or a PostgreSQL custom-format dump using `pg_dump`. It creates private files (directory mode `0700`, artifact/status mode `0600`), atomically publishes completed artifacts, and records last success/error metadata. Backup failures are logged without including database credentials. The command does not automatically prune or delete old backups.

## Schedule and protect

Configure `BACKUP_DIR`, optional `BACKUP_STATUS_FILE`, `BACKUP_RETENTION_DAYS`, and `BACKUP_INTERVAL_SECONDS` (minimum 60; default 86400). To enable the repository's opt-in scheduled worker, run `docker compose --profile backup up -d backup`. It takes a backup immediately after startup, then waits the configured interval between attempts. Check it with `docker compose logs -f backup`. Alternatively, schedule the one-shot command through a host scheduler at a chosen wall-clock time:

```cron
15 2 * * * cd /srv/dokon && docker compose exec -T api python manage.py backup_database
```

Check protected admin endpoint `/api/v1/admin/system-status/` for last backup time, size, and error type. Alert externally when no successful backup arrives within the recovery objective. Copy artifacts to an encrypted, access-controlled off-site destination, keep keys separate, and restrict access. A named Docker volume alone is not off-site protection. Back up media separately (including `product_media`) and periodically compare file counts/checksums; use a filesystem/object-store snapshot or a controlled archive copied off-host. Do not put database backups under `MEDIA_ROOT`.

## PostgreSQL restore to isolated staging

Choose a new, empty staging database and verify its host/name before proceeding. Never use the production database name for a drill.

```sh
pg_restore --list /secure/path/dokon-YYYYMMDDTHHMMSSZ.dump
createdb -h STAGING_DB_HOST -U STAGING_DB_USER dokon_restore_drill
pg_restore --no-owner --no-privileges -h STAGING_DB_HOST -U STAGING_DB_USER -d dokon_restore_drill /secure/path/dokon-YYYYMMDDTHHMMSSZ.dump
```

Point a separate staging application environment at that database and run `python manage.py check`, `python manage.py showmigrations`, and application smoke checks. Verify users, stores, products, sales, debt records/payments, subscriptions, payment records, counts and representative foreign-key relations without printing personal data. Restore media from its matching snapshot into an isolated media directory. Confirm uploaded files resolve, then test login, store isolation, inventory, reports and financial totals. Record duration and data-loss window.

## SQLite restore drill

Copy a backup to a new isolated path, then validate without overwriting the source:

```sh
sqlite3 /secure/staging/dokon-copy.sqlite3 'PRAGMA integrity_check;'
```

The automated test creates a backup from the isolated Django test database and opens that backup read-only to check integrity and schema. This is not a production PostgreSQL restore drill.

## Failure and rollback

If a backup fails, retain previous artifacts, inspect protected service logs and disk/permissions/database availability, fix the cause, and rerun. Do not remove old artifacts to make space without retention approval and a verified off-site copy. If a restore fails, stop the isolated staging app, preserve the failed restored database for diagnosis, create a new empty staging database, and retry from another verified backup. For an actual incident, isolate the affected service, preserve evidence, select a verified backup and matching media snapshot, restore to a new database first, validate it, then switch application configuration under the incident change procedure. Roll back by switching back to the preserved prior database/configuration; never overwrite the only surviving copy.

Retention duration must be selected against legal requirements and RPO/RTO. `BACKUP_RETENTION_DAYS` records the intended retention policy; automatic deletion is deliberately disabled so backups are never removed without an operator-approved retention process.
