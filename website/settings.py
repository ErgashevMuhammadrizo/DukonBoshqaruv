import os
import secrets
from pathlib import Path
BASE_DIR = Path(__file__).resolve().parent
SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY') or secrets.token_urlsafe(48)
DEBUG = os.environ.get('DEBUG', '0') == '1'
ALLOWED_HOSTS = [x.strip() for x in os.environ.get('ALLOWED_HOSTS', 'localhost,127.0.0.1,[::1]').split(',') if x.strip()]
if os.environ.get('RAILWAY_PUBLIC_DOMAIN'): ALLOWED_HOSTS.append(os.environ['RAILWAY_PUBLIC_DOMAIN'])
ROOT_URLCONF = 'website.urls'
INSTALLED_APPS = []
MIDDLEWARE = ['django.middleware.security.SecurityMiddleware', 'django.middleware.common.CommonMiddleware']
TEMPLATES = [{'BACKEND': 'django.template.backends.django.DjangoTemplates', 'DIRS': [BASE_DIR / 'templates'], 'APP_DIRS': False, 'OPTIONS': {'context_processors': []}}]
DATABASES = {}
USE_TZ = True
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
SECURE_CONTENT_TYPE_NOSNIFF = True
