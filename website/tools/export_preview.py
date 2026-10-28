"""Render a static QA preview; production uses Django and the real APK route."""
from pathlib import Path
import os, sys, shutil
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root.parent))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'website.settings')
import django
django.setup()
from django.test import RequestFactory
from website import views
out = root / 'dist'
out.mkdir(exist_ok=True)
for url, destination, handler in [('/', out / 'index.html', views.home), ('/download/', out / 'download/index.html', views.download_page)]:
    destination.parent.mkdir(parents=True, exist_ok=True)
    response = handler(RequestFactory().get(url, HTTP_HOST='localhost'))
    destination.write_bytes(response.content)
shutil.copytree(root / 'static/site', out / 'static/site', dirs_exist_ok=True)
shutil.copytree(root / 'public/downloads', out / 'downloads', dirs_exist_ok=True)
print('Static QA preview:', out)
