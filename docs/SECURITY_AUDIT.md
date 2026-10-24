# Security and production audit

Repository inspection date: 2026-10-23. This is a code/configuration review, not a penetration test. The workspace has a `.git` directory that is empty/unusable (`git status` reports that it is not a repository), so commit history and whether secrets were ever committed cannot be verified. No production host/database was accessed.

## Findings by severity

### Critical

No confirmed critical vulnerability was established in this scoped repository inspection. This does not certify production safety.

### High

- **Production media was routed through Django's static development `serve()` view.** Fixed: media route is now registered only when `DEBUG=True`. Production must configure an appropriate media server/storage policy before uploads are enabled.
- **Flutter's API fallback had been changed to a non-routable `example.invalid` URL, so debug clients could not reach the local backend.** Fixed: debug chooses Android emulator host bridge, localhost for desktop/web, or explicit `API_BASE_URL`; release without an explicit HTTPS URL still fails closed to `example.invalid`.
- **Compose ran database migrations as an implicit API startup side effect.** Fixed: API start no longer migrates; a separately invoked release-profile migration service is provided. Operators must review migration operations and take a verified backup first.
- **Docker API process ran as root.** Fixed: image runs as UID/GID 10001 and Compose adds read-only root filesystem, dropped capabilities, and no-new-privileges. Validate volume ownership on the target Docker engine.
- **Secrets/history exposure could not be ruled out.** A root `.gitignore` now excludes env files, local DB/media and backups; `.env.example` contains placeholders. Rotate any reused credential if independent source control history or host inspection finds it exposed. Git history was unavailable here; no secret value is reproduced.

### Medium

- **No CI pipeline and no configured alert destination were present.** A CI workflow now runs backend and Flutter checks. It does not deploy; monitoring/alert delivery remains an operator integration.
- **Container and Python dependencies are version-ranged, not digest/lock pinned.** Review and pin tested image digests and a dependency lock/SBOM policy before production for reproducible releases.
- **No implemented backup or restore workflow was present.** A SQLite/PostgreSQL backup command, status metadata and isolated SQLite restore test were added. PostgreSQL restore, media restore, off-site encryption/copy and scheduled alerting have not been run/configured.
- **Production Compose previously lacked app health checks and log rotation.** Added readiness/liveness endpoints, a Compose readiness check, and bounded JSON logs. Host-level uptime/latency/error monitoring is still required.
- **Static/media hosting, TLS termination, firewall, secret manager, and resource sizing are not provisioned by this repository.** Follow deployment guide and validate them per environment. Production `check --deploy` with sample-safe settings still warns that HSTS subdomain coverage and preload are disabled; enable only after confirming every subdomain is HTTPS-ready.
- **The application includes no Click/Payme provider adapters or callback implementation.** Payment provider credentials are placeholders only; do not accept real payments or claim provider integration until implemented and callback signature/idempotency tests exist. See `BILLING_ACCOUNT_STATUS.md`.
- **Login throttling exists (5/min scoped) and JWT rotation/blacklisting is enabled, but lockout/credential-stuffing detection and security alerting are absent.** Add operational detection before public launch.
- **Migration review:** no `DeleteModel`, `RemoveField`, or raw SQL operation was found in current migrations. There are data migrations for plan-name snapshots, plan seeding, and preserving legacy trial values, plus field alterations; review them against a production backup before applying.

### Low

- Flutter version remains `0.1.0+1`; define release numbering/signing and store metadata before publishing.
- The project supports native Flutter clients. No CORS middleware is configured; if Flutter Web is exposed cross-origin, configure an explicit allowlist at the application or reverse proxy and test it. Do not use wildcard origins with credentials.

## Verified controls

- Production settings reject a missing/short/default Django secret, empty host allowlist, disabled HTTPS redirect, SQLite, or missing PostgreSQL password; debug defaults off. Deployment environment supplies explicit host and origin values.
- Django password hashing, password validators, JWT access lifetime 15 minutes, refresh rotation and blacklist are configured.
- DRF has default authenticated permissions and scoped throttles; admin APIs require superuser; store-scoped APIs and service tests exist.
- Product image upload limit is 5 MiB and DRF ImageField validates decoded image content. Validate reverse-proxy request-size limits as well.
- `ENABLE_DEMO_BOOTSTRAP` is explicitly restricted to development and does not reset existing credentials.
- Compose does not publish a PostgreSQL host port; API binds to loopback.

## Outstanding release blockers

Set real host/origin/secrets in deployment secret storage; validate proxy/TLS/HSTS; execute deploy checks; review migration SQL; verify PostgreSQL and media backups off-host; complete PostgreSQL restore drill; configure uptime/error/backup alerts; run Flutter signed release builds and business regression suite; implement and test payment integration before enabling provider credentials.
