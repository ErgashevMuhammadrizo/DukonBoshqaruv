# Operations

## Health and monitoring

- `GET /health/live` returns only `{"status":"ok"}` while the web process responds.
- `GET /health/ready` checks database connectivity and returns a minimal status; database failure returns HTTP 503 without exception details.
- Superadmin-authenticated `/api/v1/admin/system-status/` reports database state and backup metadata. It does not expose backup paths or credentials.
- Configure external uptime and response-time monitoring for the TLS endpoint, plus alerting on 5xx, container restarts, DB saturation, disk use, and stale backup timestamps. No external monitoring/notification integration is included here.

## Logs

Django emits JSON-formatted records to stdout/stderr; Compose rotates API logs at 10 MiB x 5 files and migration logs at 10 MiB x 3. Read with `docker compose logs --since=1h api` or `docker compose logs -f api`. Restrict Docker socket/log access and ship logs to protected centralized storage with retention. Do not enable request-body or authorization-header logging. Investigate generic exception reports without copying tokens, passwords, payment secrets, or personal data into tickets.

## Restart and release

Check `docker compose ps` and `docker compose logs api db` before restart. Restart API with `docker compose restart api`; this does not change database volumes. For releases, follow `DEPLOYMENT.md`; take a backup, review migrations, run the one-off migration job, then update API. Never use `docker compose down -v` as a routine restart.

## Backup and incident response

Run `docker compose exec -T api python manage.py backup_database` and verify protected admin backup status. Schedule it externally, copy encrypted backup/media snapshots off-host, and alert on missed runs. See `BACKUP_RESTORE.md` for isolated restore steps. In an incident, preserve logs and existing backup artifacts, restrict compromised credentials at the provider only after incident authorization, isolate affected services, recover into a new database first, validate, then switch traffic. Do not restore over the only database copy.

## Current gaps

No external log service, pager/notification channel, metrics collector, background worker, payment callback integration, managed secret store, or off-site backup destination is configured in this repository. Add and test these per deployment; local health endpoints alone are not monitoring.
