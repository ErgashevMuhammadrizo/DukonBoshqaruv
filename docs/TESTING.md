# Test and release checks

## Backend

```sh
cd backend
python manage.py check
python manage.py makemigrations --check --dry-run
python manage.py test tests
```

The latest repository run completed 33 Django tests, `check`, and migration consistency successfully. The suite covers auth/security, superadmin/store isolation, inventory/POS/reports/debts, payment records, subscription behavior, and an isolated SQLite backup/integrity/schema restore check. It does not test PostgreSQL backup/restore, production concurrency/load, or external payment providers.

Run `python manage.py check --deploy` with actual production settings before release. The test-only production security check was run with HTTPS redirect and HSTS enabled; it reports two HSTS warnings because subdomain coverage and browser preload are deliberately disabled. Enable them only after validating the whole domain. The schema generator also has existing serializer/operation-ID warnings; see the command output and `SECURITY_AUDIT.md`.

## Flutter

Run `flutter pub get`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, and `flutter test` under a writable supported Flutter SDK. Formatter check is clean and direct Dart analysis exits successfully with 84 informational diagnostics, mostly deprecated `withOpacity` calls. In this workspace Flutter wrapper commands could not update the read-only SDK cache, so Flutter widget/unit tests and platform builds remain unverified.

## CI

`.github/workflows/ci.yml` runs Python checks/tests and Flutter formatting/analyze/tests on push and pull request. It never deploys to production.
