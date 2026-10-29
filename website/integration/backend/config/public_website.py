"""Optional public site mounting, shared by repository and backend-only builds."""
import sys
from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.http import JsonResponse
from django.urls import include, path
from django.views.decorators.http import require_safe


@require_safe
def api_home(request):
    return JsonResponse({'service': 'VEXO API', 'api': '/api/v1/',
                         'docs': '/api/v1/docs/'})


def public_urlpatterns():
    if not settings.SERVE_WEBSITE:
        return [path('', api_home, name='api-home')]
    root = settings.WEBSITE_ROOT
    if root.name != 'website' or not all((root / name).is_file()
                                        for name in ('__init__.py', 'urls.py')):
        raise ImproperlyConfigured(
            'SERVE_WEBSITE=1 requires the website package in the image. '
            'Use the repository-root website/integration/Dockerfile with '
            'WEBSITE_ROOT=/website, or set SERVE_WEBSITE=0 for API-only deployment.'
        )
    parent = str(root.parent)
    if parent not in sys.path:
        sys.path.insert(0, parent)
    # Deliberately do not catch import errors inside a present website package.
    return [path('', include('website.urls'))]
