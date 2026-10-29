import os
from pathlib import Path
from datetime import timedelta
from dotenv import load_dotenv
from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parent.parent
PROJECT_ROOT = BASE_DIR.parent
# Prefer the local backend .env for development. The repo-root .env is a deployment
# template and should only be used as a fallback when the backend-specific config is absent.
backend_env = BASE_DIR / '.env'
root_env = PROJECT_ROOT / '.env'
if backend_env.exists():
    load_dotenv(backend_env)
elif root_env.exists():
    load_dotenv(root_env)

SECRET_KEY = os.getenv('DJANGO_SECRET_KEY', 'dev-only-insecure-replace-before-deploy')
DEBUG = str(os.getenv('DEBUG', '0')).strip().lower() in {'1', 'true', 'yes', 'on'}
APP_ENV = os.getenv('APP_ENV', 'production').strip().lower()
ENABLE_DEMO_BOOTSTRAP = str(os.getenv('ENABLE_DEMO_BOOTSTRAP', '0')).strip().lower() in {'1', 'true', 'yes', 'on'}
DEMO_USERNAME = os.getenv('DEMO_USERNAME', '').strip()
DEMO_PASSWORD = os.getenv('DEMO_PASSWORD', '')

if ENABLE_DEMO_BOOTSTRAP and (APP_ENV != 'development' or not DEBUG):
    raise ImproperlyConfigured(
        'Demo bootstrap requires APP_ENV=development and DEBUG=1.'
    )

if not DEBUG and (SECRET_KEY == 'dev-only-insecure-replace-before-deploy' or SECRET_KEY.startswith('replace-') or len(SECRET_KEY) < 50):
    raise RuntimeError('Set a random DJANGO_SECRET_KEY of at least 50 characters for production or DEBUG=1 for development')

ALLOWED_HOSTS = [
    host.strip()
    for host in os.getenv('ALLOWED_HOSTS', 'localhost,127.0.0.1,[::1],0.0.0.0').split(',')
    if host.strip()
]
if DEBUG and '10.0.2.2' not in ALLOWED_HOSTS:
    ALLOWED_HOSTS.append('10.0.2.2')  # Android emulator host bridge for local development.
if not DEBUG and not os.getenv('ALLOWED_HOSTS', '').strip():
    raise RuntimeError('Set ALLOWED_HOSTS explicitly for production')

BACKUP_DIR = os.getenv('BACKUP_DIR', str(PROJECT_ROOT / 'var' / 'backups'))
BACKUP_RETENTION_DAYS = max(1, int(os.getenv('BACKUP_RETENTION_DAYS', '30')))
BACKUP_STATUS_FILE = os.getenv('BACKUP_STATUS_FILE', '')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'rest_framework_simplejwt.token_blacklist',
    'drf_spectacular',
    'apps.core',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

# API-only is the normal backend/Dockerfile deployment. Explicit opt-in keeps
# the sibling website optional instead of making all API URLs depend on it.
SERVE_WEBSITE = os.getenv('SERVE_WEBSITE', '0').strip().lower() in {'1', 'true', 'yes', 'on'}
_default_website = Path('/website') if Path('/website').exists() else PROJECT_ROOT / 'website'
WEBSITE_ROOT = Path(os.getenv('WEBSITE_ROOT', str(_default_website))).expanduser().resolve()
TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [str(WEBSITE_ROOT / 'templates')],
    'APP_DIRS': True,
    'OPTIONS': {
        'context_processors': [
            'django.template.context_processors.debug',
            'django.template.context_processors.request',
            'django.contrib.auth.context_processors.auth',
            'django.contrib.messages.context_processors.messages',
        ]
    }
}]

WSGI_APPLICATION = 'config.wsgi.application'

import os

DB_ENGINE = os.getenv("DB_ENGINE", "sqlite").strip().lower()
if not DEBUG and not os.getenv('DB_ENGINE', '').strip():
    raise ImproperlyConfigured(
        'Set DB_ENGINE explicitly for production; preserve the existing database choice.'
    )

if DB_ENGINE == "sqlite":
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": Path(os.getenv('SQLITE_PATH', str(BASE_DIR / 'db.sqlite3'))),
        }
    }
elif DB_ENGINE == "postgres":
    pg_sslmode = os.getenv('PGSSLMODE', 'require').strip().lower()
    if pg_sslmode not in {'disable', 'allow', 'prefer', 'require', 'verify-ca', 'verify-full'}:
        raise ImproperlyConfigured('PGSSLMODE is invalid.')
    if not DEBUG and pg_sslmode not in {'require', 'verify-ca', 'verify-full'}:
        raise ImproperlyConfigured('Production PostgreSQL requires TLS: set PGSSLMODE=require or verify-full.')
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": os.environ["PGDATABASE"],
            "USER": os.environ["PGUSER"],
            "PASSWORD": os.environ["PGPASSWORD"],
            "HOST": os.environ["PGHOST"],
            "PORT": os.getenv("PGPORT", "5432"),
            "OPTIONS": {"sslmode": pg_sslmode},
        }
    }
else:
    raise ValueError(f"Noto'g'ri DB_ENGINE: {DB_ENGINE}")

AUTH_USER_MODEL = 'core.User'
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator', 'OPTIONS': {'min_length': 10}},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'uz'
TIME_ZONE = 'Asia/Tashkent'
USE_TZ = True

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'
STATICFILES_DIRS = [str(WEBSITE_ROOT / 'static')] if (WEBSITE_ROOT / 'static').exists() else []

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

NUM_PROXIES = max(0, int(os.getenv('NUM_PROXIES', '1').strip() or '1'))

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': ['rest_framework_simplejwt.authentication.JWTAuthentication'],
    'DEFAULT_PERMISSION_CLASSES': ['apps.core.permissions.ActiveStoreUser'],
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
        'rest_framework.throttling.ScopedRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {'anon': '30/min', 'user': '300/min', 'auth': '5/min'},
    'NUM_PROXIES': NUM_PROXIES,
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=15),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'AUTH_HEADER_TYPES': ('Bearer',),
    'CHECK_REVOKE_TOKEN': True,
}

SPECTACULAR_SETTINGS = {'TITLE': 'Dokon Boshqaruv API', 'VERSION': '1.0.0'}
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
SECURE_SSL_REDIRECT = str(os.getenv('SECURE_SSL_REDIRECT', '0')).strip().lower() in {'1','true','yes','on'}
SECURE_REDIRECT_EXEMPT = [r'^/health/live$', r'^/health/ready$']
SECURE_HSTS_SECONDS = int(os.getenv('SECURE_HSTS_SECONDS', '0'))
if not DEBUG and not SECURE_SSL_REDIRECT:
    raise RuntimeError('Enable SECURE_SSL_REDIRECT for production behind a validated HTTPS proxy')
SECURE_HSTS_INCLUDE_SUBDOMAINS = str(os.getenv('SECURE_HSTS_INCLUDE_SUBDOMAINS', '0')).strip().lower() in {'1', 'true', 'yes', 'on'}
SECURE_HSTS_PRELOAD = str(os.getenv('SECURE_HSTS_PRELOAD', '0')).strip().lower() in {'1', 'true', 'yes', 'on'}
SECURE_REFERRER_POLICY = 'same-origin'
SECURE_CROSS_ORIGIN_OPENER_POLICY = 'same-origin'
SESSION_COOKIE_SECURE = not DEBUG
CSRF_COOKIE_SECURE = not DEBUG
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'
CSRF_TRUSTED_ORIGINS = [
    origin.strip()
    for origin in os.getenv(
        'CSRF_TRUSTED_ORIGINS',
        'http://localhost:8000,http://127.0.0.1:8000,http://10.0.2.2:8000,http://localhost:3000,http://127.0.0.1:3000' if DEBUG else ''
    ).split(',')
    if origin.strip()
]

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {'structured': {'()': 'apps.core.logging.JsonFormatter'}},
    'handlers': {'console': {'class': 'logging.StreamHandler', 'formatter': 'structured'}},
    'root': {'handlers': ['console'], 'level': os.getenv('LOG_LEVEL', 'INFO').upper()},
}
