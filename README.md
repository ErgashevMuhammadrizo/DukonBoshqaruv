# Dokon Boshqaruv

Uzbek Latin retail management application. **Development source / incomplete MVP, NOT production-ready.** This repository contains a Django REST API, Flutter client, Django-template landing page, transaction tests, and a persistent offline sale queue. See `PROGRESS.md` before deployment.

## GitHubdan klon qilib ishga tushirish

Agar repo GitHubdan yuklab olingan bo'lsa, birinchi navbatda loyiha ildizi ostida `.env` yaratib olish kerak. Tez boshlash uchun `.env.example` dan nusxa olish kifoya:

```sh
cp .env.example .env
```

Agar yuqori darajadagi `.env` ishlatmay yoki Docker bilan ishga tushirmoqchi bo'lsangiz, quyidagi buyruq yetarli:

```sh
cp .env.example .env
docker compose up -d db
cd backend
python -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
export DEBUG=1 DB_ENGINE=sqlite
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

## Local backend

Requires Python 3.12+, PostgreSQL 17 (or development SQLite).

```sh
cd backend
python -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
export DEBUG=1 DB_ENGINE=sqlite
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver 0.0.0.0:8000
python manage.py test tests
```

The local `backend/.env` may already set `DEBUG=1` and `DB_ENGINE=sqlite`; Django loads it automatically. The development app uses the Android emulator host bridge (`10.0.2.2`) or localhost on desktop/web. For a physical phone, keep the backend bound to `0.0.0.0`, add the computer's LAN IP to `ALLOWED_HOSTS`, allow port 8000 on the local firewall, and run Flutter with `--dart-define=API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:8000/api/v1/`. Release builds must use an HTTPS API URL.

For PostgreSQL set environment variables from `backend/.env.example`, create DB, and run migrations. Review migrations before applying them to a production database.

## Flutter

Flutter SDK (compatible with Dart >=3.5) is required. From `dokon_boshqaruv/`:

```sh
flutter create --platforms=android,ios,web,linux .
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api/v1/
```

Platform native skeletons must be generated with the locally installed Flutter SDK before builds. Web requires same-origin API proxy or configured restricted CORS; not yet implemented. On Android emulator use host `10.0.2.2` instead of `localhost`. Secure HTTPS required outside local development. Native SQLite plugin is **not supported in Flutter Web** with the current implementation; this limitation requires a web-specific database adapter.

## Account onboarding

Use Django Admin to create an inactive user and a Store with that owner; use `POST /api/v1/admin/issue-credential/` with `user_id` and `purpose=activation` using a superadmin JWT, then securely transmit the returned one-time code. Activation is `POST /api/v1/auth/activate/` with `code` and `password`. Admin endpoint returns the newly issued secret **once**; do not save or log it. Customer-facing activation UI is not implemented yet.

## Limitations

This is NOT a completed production application. Important features such as server-side subscription entitlement enforcement on mutations, password-reset issuance workflow, website legal documents, camera scanner, expanded admin flow, full offline/online synchronization, data reconciliation, web persistence, more tests, and end-to-end build validation are outstanding. See `PROGRESS.md`.
