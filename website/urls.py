from django.urls import path, re_path
from . import views
urlpatterns = [
    path('', views.home, name='website-home'),
    path('download/', views.download_page, name='website-download'),
    path('downloads/dokon-boshqaruv.apk', views.apk_download, name='website-apk'),
    re_path(r'^static/site/(?P<path>.+)$', views.asset, name='website-asset'),
]
handler404 = 'website.views.not_found'
