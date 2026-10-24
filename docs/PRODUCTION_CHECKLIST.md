# Production release checklist

## Before release

- [ ] Review release diff, migration SQL, dependency changes, and source-control secret scan/history.
- [ ] Pin reviewed container image digests and resolve Python dependencies into a reproducible lock/SBOM before the production release.
- [ ] Configure unique Django/database secrets in a secret manager; `DEBUG=0`; explicit host and CSRF origin allowlists.
- [ ] Configure HTTPS proxy, forwarded-proto/host handling, firewall, TLS renewal, and HSTS only after validation.
- [ ] Validate persistent volume ownership, encrypted storage, disk capacity, resource limits, and log rotation.
- [ ] Configure private media serving and size limits; verify media backup/snapshot procedure.
- [ ] Create database backup and copy encrypted artifact off-host; record size/time and verify integrity.
- [ ] Run `manage.py check --deploy`, `makemigrations --check --dry-run`, backend tests, Flutter format/analyze/tests, and review results.
- [ ] Review migration plan and rollback for the exact release. Apply through the controlled migration job only.
- [ ] Configure external uptime, latency, error, database, disk, and missed-backup alerts; test alert delivery.
- [ ] Confirm payment provider integration is implemented/tested before configuring merchant secrets.

## Deploy and validate

- [ ] Build immutable release image and retain previous image.
- [ ] Apply reviewed migrations after backup.
- [ ] Start API; verify `/health/live`, `/health/ready`, TLS endpoint, logs, and admin/API smoke tests.
- [ ] Check login, refresh/logout, store isolation, product/stock, POS idempotency, reports, debt partial payments, subscription behavior, and offline sync.
- [ ] Verify backup job and status metadata; run restore drill in isolated staging.
- [ ] Build and smoke-test signed Android artifact with production `API_BASE_URL`; validate iOS on macOS/Xcode if shipping iOS.
- [ ] Record version, checksums, migration outcome, backup reference, approver, and rollback decision.

## Rollback

- [ ] Stop/route away from affected release; preserve logs and data.
- [ ] Revert application image/configuration only when compatible with current schema.
- [ ] Restore database into a new database and validate before switching; never overwrite the only copy.
- [ ] Restore matching media snapshot if needed; communicate incident and record recovery time/data loss.
