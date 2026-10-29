"""Deployment checks never contact Railway or the application's real database."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from django.conf import settings
from django.test import SimpleTestCase, TestCase
from django.urls import resolve
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken
from datetime import timedelta
from apps.core.models import User, Store


class RoutingTests(SimpleTestCase):
    def test_all_existing_endpoint_families_still_resolve(self):
        paths = [
            '/', '/admin/', '/api/v1/', '/api/v1/products/', '/api/v1/products/1/',
            '/api/v1/products/1/archive/', '/api/v1/categories/', '/api/v1/sales/',
            '/api/v1/debts/', '/api/v1/debts/1/', '/api/v1/debts/1/payments/',
            '/api/v1/auth/login/', '/api/v1/auth/logout/', '/api/v1/auth/activate/',
            '/api/v1/auth/set-password/', '/api/v1/auth/password-reset/confirm/',
            '/api/v1/auth/change-username/', '/api/v1/auth/change-password/',
            '/api/v1/auth/token/refresh/', '/api/v1/me/', '/api/v1/store/',
            '/api/v1/inventory/', '/api/v1/inventory/movements/',
            '/api/v1/inventory/adjustments/', '/api/v1/sync/push/', '/api/v1/sync/pull/',
            '/api/v1/reports/summary/', '/api/v1/subscription/status/',
            '/api/v1/subscriptions/history/', '/api/v1/plans/', '/api/v1/payments/',
            '/api/v1/admin/dashboard/', '/api/v1/admin/users/', '/api/v1/admin/users/1/',
            '/api/v1/admin/stores/', '/api/v1/admin/plans/', '/api/v1/admin/plans/1/',
            '/api/v1/admin/subscriptions/', '/api/v1/admin/payments/',
            '/api/v1/admin/payments/1/', '/api/v1/admin/audit/',
            '/api/v1/admin/system-status/', '/api/v1/admin/issue-credential/',
            '/api/v1/schema/', '/api/v1/docs/', '/health/live', '/health/ready',
            '/media/unknown.jpg',
        ]
        for path in paths:
            with self.subTest(path=path):
                self.assertIsNotNone(resolve(path).func)

    def test_api_only_home_needs_neither_database_nor_website(self):
        response = self.client.get('/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['service'], 'VEXO API')

    def test_integrated_deployment_example_matches_real_url_configuration(self):
        root=Path(settings.BASE_DIR).parent
        for name in ('urls.py','public_website.py'):
            self.assertEqual((root/'website/integration/backend/config'/name).read_bytes(),
                             (Path(settings.BASE_DIR)/'config'/name).read_bytes())


class IsolatedDeploymentTests(SimpleTestCase):
    def run_deployment(self, integrated=False, include_website=False):
        source=Path(settings.BASE_DIR)
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            shutil.copytree(source,root/'backend',ignore=shutil.ignore_patterns(
                '.env','.env.*','*.sqlite3','*.db','__pycache__','media','.venv','staticfiles'))
            if include_website:
                shutil.copytree(source.parent/'website',root/'website',ignore=shutil.ignore_patterns(
                    '__pycache__','dist','.openai','.env','*.apk'))
            env=os.environ.copy()
            env.update({'DEBUG':'1','APP_ENV':'development','DB_ENGINE':'sqlite',
                'ENABLE_DEMO_BOOTSTRAP':'0','ALLOWED_HOSTS':'testserver,localhost',
                'SECURE_SSL_REDIRECT':'0','SERVE_WEBSITE':'1' if integrated else '0',
                'WEBSITE_ROOT':str(root/'website'),'PYTHONPATH':str(root/'backend'),
                'DJANGO_SETTINGS_MODULE':'config.settings',
                'DJANGO_SECRET_KEY':'isolated-routing-test-secret-not-for-production-29102026'})
            script="""
import django
from django.conf import settings
settings.DATABASES['default']['NAME']=':memory:'
django.setup()
from django.core.management import call_command
call_command('check')
from django.urls import resolve
from django.test import Client
assert resolve('/api/v1/auth/token/refresh/').func
assert resolve('/api/v1/schema/').func
response=Client().get('/')
assert response.status_code==200
if settings.SERVE_WEBSITE:
    assert resolve('/download/').func
    assert Client().get('/download/').status_code==200
else:
    assert response.json()['service']=='VEXO API'
"""
            return subprocess.run([sys.executable,'-c',script],cwd=root/'backend',env=env,
                                  capture_output=True,text=True,timeout=30)

    def test_backend_only_image_imports_without_any_website_folder(self):
        result=self.run_deployment()
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    def test_integrated_image_serves_site_and_keeps_api_routes(self):
        result=self.run_deployment(integrated=True,include_website=True)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    def test_explicit_missing_website_is_a_clear_configuration_error(self):
        result=self.run_deployment(integrated=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('SERVE_WEBSITE=1 requires the website package',result.stderr)
        self.assertNotIn("No module named 'website'",result.stderr)


class LocalizedAuthenticationTests(TestCase):
    def setUp(self):
        self.user=User.objects.create_user(username='locale-user',password='test-only-password-2910')
        Store.objects.create(owner=self.user,name='Isolated locale fixture')
        self.client=APIClient()

    def test_uz_ru_uz_keeps_jwt_and_response_field_names(self):
        token=RefreshToken.for_user(self.user)
        for language in ('uz','ru','uz'):
            response=self.client.get('/api/v1/me/',HTTP_AUTHORIZATION=f'Bearer {token.access_token}',
                                     HTTP_ACCEPT_LANGUAGE=language)
            self.assertEqual(response.status_code,200)
            self.assertEqual(response.data['id'],self.user.pk)
            self.assertEqual(response.data['username'],'locale-user')

    def test_ru_refresh_rotates_valid_token_and_rejects_expired_token(self):
        token=RefreshToken.for_user(self.user)
        response=self.client.post('/api/v1/auth/token/refresh/',{'refresh':str(token)},
                                  format='json',HTTP_ACCEPT_LANGUAGE='ru')
        self.assertEqual(response.status_code,200)
        self.assertIn('access',response.data); self.assertIn('refresh',response.data)
        expired=RefreshToken.for_user(self.user)
        expired.set_exp(lifetime=timedelta(seconds=-1))
        self.assertEqual(self.client.post('/api/v1/auth/token/refresh/',{'refresh':str(expired)},
                         format='json',HTTP_ACCEPT_LANGUAGE='ru').status_code,401)

    def test_schema_and_swagger_remain_available(self):
        self.assertEqual(self.client.get('/api/v1/schema/').status_code,200)
        self.assertEqual(self.client.get('/api/v1/docs/').status_code,200)


class ProductionConfigurationTests(SimpleTestCase):
    def settings_probe(self, engine=None, sqlite_path=None, ssl_mode=None):
        env=os.environ.copy()
        env.update({'DEBUG':'0','APP_ENV':'production','ENABLE_DEMO_BOOTSTRAP':'0',
            'DJANGO_SECRET_KEY':'production-settings-test-only-secret-not-a-real-key-0123456789',
            'ALLOWED_HOSTS':'api.example.test','SECURE_SSL_REDIRECT':'1',
            'PGDATABASE':'isolated','PGUSER':'isolated','PGPASSWORD':'test-placeholder',
            'PGHOST':'db.example.test','PGPORT':'5432'})
        env.pop('DB_ENGINE',None);env.pop('SQLITE_PATH',None);env.pop('PGSSLMODE',None)
        if engine is not None: env['DB_ENGINE']=engine
        if ssl_mode is not None: env['PGSSLMODE']=ssl_mode
        if sqlite_path is not None: env['SQLITE_PATH']=sqlite_path
        return subprocess.run([sys.executable,'-c',
            "import config.settings as s; print(s.DATABASES['default']['ENGINE']); print(s.DATABASES['default']['NAME'])"],
            cwd=settings.BASE_DIR,env=env,capture_output=True,text=True,timeout=20)

    def test_production_cannot_silently_create_an_ephemeral_sqlite_database(self):
        result=self.settings_probe()
        self.assertNotEqual(result.returncode,0)
        self.assertIn('Set DB_ENGINE explicitly for production',result.stderr)

    def test_explicit_postgres_configuration_does_not_fall_back_to_sqlite(self):
        result=self.settings_probe('postgres')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('django.db.backends.postgresql',result.stdout)
        self.assertNotIn('sqlite3',result.stdout)

    def test_intentional_sqlite_deployment_can_target_a_persistent_volume(self):
        result=self.settings_probe('sqlite','/data/vexo-test.sqlite3')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('/data/vexo-test.sqlite3',result.stdout)

    def test_production_postgres_cannot_silently_disable_tls(self):
        result=self.settings_probe('postgres',ssl_mode='disable')
        self.assertNotEqual(result.returncode,0)
        self.assertIn('Production PostgreSQL requires TLS',result.stderr)
