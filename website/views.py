"""Public, database-free product website. No login, cookies or API calls required."""
import json
import re
from pathlib import Path
from urllib.parse import urlparse
from django.http import FileResponse, JsonResponse
from django.shortcuts import render
from django.views.decorators.http import require_safe
from django.views.static import serve

ROOT = Path(__file__).resolve().parent
APK_PATH = ROOT / 'public/downloads/dokon-boshqaruv.apk'
MISSING_APK = 'Ilova fayli hozircha joylanmagan. Iltimos, keyinroq qayta urinib ko‘ring.'

def configuration():
    defaults = {'product_name': 'Dokon Boshqaruv', 'download_url': '/downloads/dokon-boshqaruv.apk', 'apk_version': '', 'telegram_url': '', 'phone': '', 'email': ''}
    try:
        values = json.loads((ROOT / 'site_config.json').read_text())
    except (FileNotFoundError, ValueError):
        values = {}
    result = {k: str(values.get(k, v)).strip() for k, v in defaults.items()}
    url = urlparse(result['download_url'])
    if not (result['download_url'].startswith('/') and not result['download_url'].startswith('//')) and not (url.scheme == 'https' and url.netloc):
        result['download_url'] = defaults['download_url']
    telegram = urlparse(result['telegram_url'])
    if telegram.scheme != 'https' or telegram.hostname not in ('t.me', 'telegram.me'):
        result['telegram_url'] = ''
    if not re.fullmatch(r'[+0-9 ()-]{7,30}', result['phone']): result['phone'] = ''
    result['phone_href'] = re.sub(r'[^+0-9]', '', result['phone'])
    if not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', result['email']): result['email'] = ''
    result['has_contacts'] = any(result[k] for k in ('telegram_url', 'phone', 'email'))
    return result

def unavailable_apk():
    response = JsonResponse({'code': 'apk_unavailable', 'message': MISSING_APK}, status=404)
    response['Cache-Control'] = 'no-store'
    return response

def context(request, page):
    return {'site': configuration(), 'page': page, 'canonical': request.build_absolute_uri(request.path), 'og_image': request.build_absolute_uri('/static/site/og.png')}

@require_safe
def home(request):
    return render(request, 'index.html', context(request, 'home'))

@require_safe
def download_page(request):
    return render(request, 'download.html', context(request, 'download'))

@require_safe
def apk_download(request):
    if not APK_PATH.is_file():
        return unavailable_apk()
    try:
        file = APK_PATH.open('rb')
    except OSError:
        return unavailable_apk()
    if file.read(4) != b'PK\x03\x04':
        file.close()
        return unavailable_apk()
    file.seek(0)
    response = FileResponse(file, as_attachment=True, filename='dokon-boshqaruv.apk', content_type='application/vnd.android.package-archive')
    response['Cache-Control'] = 'no-cache, must-revalidate'
    response['X-Content-Type-Options'] = 'nosniff'
    return response

@require_safe
def asset(request, path):
    response = serve(request, path, document_root=ROOT / 'static/site')
    response['X-Content-Type-Options'] = 'nosniff'
    response['Cache-Control'] = 'public, max-age=3600'
    return response

def not_found(request, exception):
    return render(request, '404.html', context(request, 'error'), status=404)
