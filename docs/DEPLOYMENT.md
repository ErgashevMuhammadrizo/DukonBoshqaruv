# Production deployment

The repository uses Docker Compose with PostgreSQL 17 and Gunicorn. This is a deploy template; no production host, DNS, TLS proxy, secrets, or off-site storage is configured here.

## Prepare

1. Provision a supported Linux host, private Docker network, DNS, TLS reverse proxy, encrypted off-site backup target, and a non-root operations account.
2. Copy `.env.example` to `.env`. Generate a unique `DJANGO_SECRET_KEY` (at least 50 random characters), database password, exact `ALLOWED_HOSTS`, and `CSRF_TRUSTED_ORIGINS`. Keep `.env` mode `0600`, outside source control, and do not put credentials in the image.
3. Set `DEBUG=0`, `APP_ENV=production`, `SECURE_SSL_REDIRECT=1`. Set HSTS only after HTTPS and proxy headers have been validated; begin with a short period and increase deliberately. TLS proxy must set `X-Forwarded-Proto: https` and forward the correct host.
4. Ensure PostgreSQL and backup volumes are on encrypted, access-controlled storage. Compose binds API port 8000 to loopback only; expose it only through the TLS proxy. Do not publish the DB port.
5. Build and start PostgreSQL: `docker compose up -d db`. Verify `docker compose ps` and `docker compose logs db`.

## Release procedure

1. Review code and migration SQL; take a backup and verify the artifact is copied off-host.
2. Build the image: `docker compose build api`.
3. Run deployment checks in the built image (configure secure values in `.env`): `docker compose run --rm api python manage.py check --deploy` and `docker compose run --rm api python manage.py makemigrations --check --dry-run`.
4. Apply reviewed migrations as a one-off task: `docker compose --profile release run --rm migrate`. This command is separate from API startup. Do not run against production until backup and maintenance/rollback plans are approved.
5. Start or replace the API: `docker compose up -d api`; confirm `docker compose ps`, `curl -fsS http://127.0.0.1:8000/health/ready`, proxy HTTPS response, and admin/API smoke checks.
6. Run `docker compose --profile release run --rm collectstatic`; serve the `static_data` volume from the configured web server/object store. Production media is not served by Django's development file server. Configure a private media delivery policy appropriate to product images.

To create an initial superuser, run `docker compose run --rm api python manage.py createsuperuser` interactively. Never bake a password into Compose or an image. Roll back by restoring the previous image and following the migration-specific rollback plan; schema rollback is not automatically safe.

## Current boundaries

Compose has non-root API, health checks, bounded JSON logs, read-only root filesystem, dropped Linux capabilities, and named persistent DB/media/backup volumes. The optional backup profile runs scheduled database backups when explicitly enabled. Host-level reverse proxy, TLS, firewall, encrypted storage, off-site replication, backup alert delivery, and orchestration are operator responsibilities. The API container has a 1 GiB memory and 2 CPU Compose limit; tune from measured load. Avoid `docker compose down -v`.

Flutter release builds must use `--dart-define=API_BASE_URL=https://api.example.com/api/v1/`. Release builds without an explicit endpoint fail closed to a non-routable HTTPS placeholder. Debug defaults are for local development only. Run the platform build in a supported toolchain and distribute signed artifacts through the platform's normal release process.
