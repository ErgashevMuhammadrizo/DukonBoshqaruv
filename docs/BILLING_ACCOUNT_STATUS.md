# Account and billing implementation status

## Available now

- `GET/PATCH /api/v1/me/` returns user and store data and permits only first name, last name, and email updates.
- `POST /api/v1/auth/change-username/` validates Django username syntax and checks case-insensitive conflicts.
- `POST /api/v1/auth/change-password/` verifies the current password, checks confirmation, applies Django password validators, blacklists outstanding refresh tokens, and audits the change.
- `GET /api/v1/plans/` returns active catalog entries. Migration `0006_billing_profile_catalog` seeds STANDARD, PRO, and VIP idempotently with separate annual and monthly prices, features, and finite limits.
- `GET /api/v1/payments/` and `/api/v1/subscriptions/history/` are scoped to the authenticated store.
- Product creation is blocked after the current trial/paid period and enforces the active product cap while locking the store row. Historical products and read/report endpoints remain available.
- Manual admin payment approval updates the legacy subscription expiry and writes a linked subscription history row in one transaction. Non-manual provider records cannot be approved through the manual admin endpoint.
- `python manage.py expire_subscriptions` marks elapsed history rows expired and emits audit entries. Schedule this command at least every few minutes in deployment. Request authorization still checks the exact expiry time directly, so a delayed scheduler does not preserve paid access.

## Not production-ready

Click and Payme are **not integrated**. The repository previously had no provider adapters or verified callback handlers, and this change does not create a simulated success path. The Flutter plan page shows catalog prices but keeps purchase locked until a real provider flow exists. The credentials in `backend/.env.example` are placeholders and are not read by the application.

Before enabling payments, implement and test provider-specific invoice creation, authenticated callback parsing, signature verification, transaction lookup, amount/currency/merchant validation, cancellation/refund handling, and idempotent activation against the current merchant documentation and sandbox. Click publishes its developer documentation at [docs.click.uz](https://docs.click.uz/). Payme documents its [Merchant API protocol](https://developer.help.paycom.uz/protokol-merchant-api/) and [interaction setup](https://developer.help.paycom.uz/nastroyka-vzaimodeystviya/). Merchant credentials, callback URLs, and sandbox access are still required.

## Model boundaries

The current data model has one store owner per account; it has no store membership/role table. `user_limit` is catalog metadata and is not enforceable until the project adds staff memberships and routes user provisioning through that relationship. Premium feature flags also remain catalog metadata until each relevant API endpoint is mapped to a named entitlement. The existing `Subscription` table remains the compatibility source for authorization; `SubscriptionHistory` stores new billing history.

Deployment should use HTTPS, a strong `DJANGO_SECRET_KEY`, production `ALLOWED_HOSTS`, database backups, and never copy development `.env` values into production. The web client needs an explicit CORS policy if it is served from a different origin; Flutter native clients do not use browser CORS.
