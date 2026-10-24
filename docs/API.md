# API surface
Prefix `/api/v1/`.
- POST `auth/login/` `{username,password}` -> `{access,refresh}`.
- POST `auth/activate/` and `auth/set-password/` `{code,password}`.
- POST `auth/password-reset/confirm/` `{code,password}` (administrator must first issue reset credential).
- POST `auth/token/refresh/` `{refresh}`; POST `auth/logout/` `{refresh}`.
- GET `me/`; GET/PATCH `store/`.
- GET/POST `products/`, GET/PATCH `products/{id}/`, POST `products/{id}/archive/`.
- GET/POST `categories/`, PATCH `categories/{id}/`.
- GET `inventory/`, GET `inventory/movements/`, POST `inventory/adjustments/` `{product_id,delta,reason}`.
- GET/POST `sales/`, GET `sales/{id}/`. POST: `{operation_id: UUID,items:[{product_id,quantity}],discount,cash,card}`.
- GET `reports/summary/?start=YYYY-MM-DD&end=YYYY-MM-DD`.
- POST `sync/push/` (see OFFLINE_SYNC), GET `sync/pull/`.
- GET `subscription/status/`, GET `plans/`, GET `payments/`.
- Superadmin: GET/POST `admin/users/`; POST accepts `{username,store_name}` and creates an inactive, non-staff account with no usable password. Use `admin/issue-credential/` with `purpose:'activation'` to enable activation.
- POST `admin/issue-credential/` for superadmin `{user_id,purpose:'activation'|'reset'}`.
- GET `schema/` and `docs/` generated from drf-spectacular.

Default authenticated JWT except plan listing, login, credential redeem. API validation formats are not yet normalized across DRF and domain service failures. Pagination is not configured. Optional endpoints omitted from MVP are tracked in `PROGRESS.md`.
