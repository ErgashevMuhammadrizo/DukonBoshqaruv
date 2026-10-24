import os
import secrets
import subprocess
import sys
import json
import sqlite3
import tempfile
from pathlib import Path

from django.apps import apps
from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.core.management import call_command
from django.db.models.signals import post_migrate
from django.test import TestCase, TransactionTestCase, override_settings
from django.db import connections

from apps.core.bootstrap import ensure_demo_user
from apps.core.models import User


class BackupCommandTests(TransactionTestCase):
    def test_sqlite_backup_is_private_and_restorable_in_isolation(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            backup_dir = Path(temp_dir) / 'backups'
            with connections['default'].cursor() as cursor:
                cursor.execute('CREATE TABLE restore_probe (value TEXT NOT NULL)')
                cursor.execute("INSERT INTO restore_probe VALUES ('isolated-fixture')")
            with override_settings(BACKUP_DIR=str(backup_dir), BACKUP_STATUS_FILE=''):
                call_command('backup_database', verbosity=0)
            backup_file = next(backup_dir.glob('dokon-*.sqlite3'))
            self.assertEqual(backup_file.stat().st_mode & 0o777, 0o600)
            with sqlite3.connect(f'file:{backup_file}?mode=ro', uri=True) as restored:
                self.assertEqual(restored.execute('PRAGMA integrity_check').fetchone()[0], 'ok')
                tables = {row[0] for row in restored.execute("SELECT name FROM sqlite_master WHERE type='table'")}
                self.assertTrue({'core_user', 'core_store', 'core_product', 'core_sale', 'core_debtrecord', 'core_debtpayment', 'core_subscription', 'core_subscriptionhistory', 'core_paymentrecord'} <= tables)
                self.assertEqual(restored.execute('SELECT value FROM restore_probe').fetchone()[0], 'isolated-fixture')
            status = json.loads((backup_dir / 'status.json').read_text())
            self.assertTrue(status['available'])
            self.assertGreater(status['size_bytes'], 0)


class BootstrapSecurityTests(TestCase):

    def test_health_endpoints_do_not_expose_environment_details(self):
        from django.test import Client
        client = Client()
        live = client.get('/health/live')
        emulator_live = client.get('/health/live', HTTP_HOST='10.0.2.2:8000')
        ready = client.get('/health/ready')
        self.assertEqual(live.status_code, 200)
        self.assertEqual(live.json(), {'status': 'ok'})
        self.assertEqual(emulator_live.status_code, 200)
        self.assertEqual(ready.status_code, 200)
        self.assertEqual(ready.json(), {'status': 'ok', 'database': 'ok'})

    def test_secure_redirect_exemptions_and_num_proxies_are_configured(self):
        self.assertIn(r'^/health/live$', settings.SECURE_REDIRECT_EXEMPT)
        self.assertIn(r'^/health/ready$', settings.SECURE_REDIRECT_EXEMPT)
        self.assertEqual(settings.REST_FRAMEWORK['NUM_PROXIES'], 1)

    def test_post_migrate_never_resets_an_existing_admin_password(self):
        password = secrets.token_urlsafe(36)
        admin = User.objects.create_superuser(username='persistent-admin', password=password)
        core_config = apps.get_app_config('core')

        post_migrate.send(
            sender=core_config,
            app_config=core_config,
            verbosity=0,
            interactive=False,
            using='default',
            plan=[],
            apps=apps,
        )

        admin.refresh_from_db()
        self.assertTrue(admin.check_password(password))
        self.assertFalse(User.objects.filter(username='demo').exists())

    def test_demo_bootstrap_requires_explicit_development_opt_in(self):
        with override_settings(
            APP_ENV='development',
            DEBUG=True,
            ENABLE_DEMO_BOOTSTRAP=False,
            DEMO_USERNAME='local-demo',
            DEMO_PASSWORD=secrets.token_urlsafe(36),
        ):
            with self.assertRaises(ImproperlyConfigured):
                ensure_demo_user()
        self.assertFalse(User.objects.filter(username='local-demo').exists())

    def test_production_settings_reject_demo_bootstrap(self):
        env = os.environ.copy()
        env.update({
            'APP_ENV': 'production',
            'DEBUG': '0',
            'ENABLE_DEMO_BOOTSTRAP': '1',
            'DJANGO_SECRET_KEY': secrets.token_urlsafe(48),
        })
        result = subprocess.run(
            [sys.executable, '-c', 'import config.settings'],
            cwd=settings.BASE_DIR,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Demo bootstrap requires APP_ENV=development', result.stderr)

    def test_explicit_demo_command_does_not_reset_existing_demo_password(self):
        password = secrets.token_urlsafe(36)
        User.objects.create_superuser(username='local-demo', password=password)
        with override_settings(
            APP_ENV='development',
            DEBUG=True,
            ENABLE_DEMO_BOOTSTRAP=True,
            DEMO_USERNAME='local-demo',
            DEMO_PASSWORD=secrets.token_urlsafe(36),
        ):
            demo = ensure_demo_user()

        demo.refresh_from_db()
        self.assertTrue(demo.check_password(password))


class SuperadminConsoleTests(TestCase):
    def setUp(self):
        from datetime import timedelta
        from django.utils import timezone
        from rest_framework.test import APIClient
        from apps.core.models import Store, Subscription, SubscriptionPlan
        self.admin=User.objects.create_superuser(username='console-admin',password='secure-password-123')
        self.owner=User.objects.create_user(username='console-owner',password='secure-password-456')
        self.store=Store.objects.create(owner=self.owner,name='Console shop')
        self.plan=SubscriptionPlan.objects.create(name='Basic',months=1,price='10000')
        Subscription.objects.create(store=self.store,trial_end=timezone.now()+timedelta(days=5))
        self.client=APIClient()

    def test_regular_user_cannot_access_global_admin_apis(self):
        self.client.force_authenticate(self.owner)
        for url in ['/api/v1/admin/dashboard/','/api/v1/admin/users/','/api/v1/admin/stores/','/api/v1/admin/plans/','/api/v1/admin/subscriptions/','/api/v1/admin/payments/','/api/v1/admin/audit/','/api/v1/admin/system-status/']:
            self.assertEqual(self.client.get(url).status_code,403,url)

    def test_dashboard_uses_database_counts_and_subscriptions(self):
        self.client.force_authenticate(self.admin)
        result=self.client.get('/api/v1/admin/dashboard/')
        self.assertEqual(result.status_code,200)
        self.assertEqual(result.data['users']['total'],2)
        self.assertEqual(result.data['stores']['total'],1)
        self.assertEqual(result.data['subscriptions']['trial'],1)
        listing=self.client.get('/api/v1/admin/subscriptions/')
        self.assertEqual(listing.status_code,200,listing.data)
        self.assertEqual(listing.data[0]['status'],'trial')

    def test_block_store_is_audited_and_denies_shop_api(self):
        from apps.core.models import AuditLog
        self.client.force_authenticate(self.admin)
        missing_reason=self.client.patch('/api/v1/admin/stores/',{'store_id':self.store.pk,'is_active':False},format='json')
        self.assertEqual(missing_reason.status_code,400)
        response=self.client.patch('/api/v1/admin/stores/',{'store_id':self.store.pk,'is_active':False,'reason':'qarzdorlik'},format='json')
        self.assertEqual(response.status_code,200)
        self.assertTrue(AuditLog.objects.filter(action='admin_store_blocked',actor=self.admin,target=f'store:{self.store.pk}').exists())
        self.client.force_authenticate(self.owner)
        self.assertEqual(self.client.get('/api/v1/products/').status_code,403)

    def test_user_toggle_and_subscription_management_are_audited(self):
        from apps.core.models import AuditLog
        self.client.force_authenticate(self.admin)
        self.assertEqual(self.client.patch(f'/api/v1/admin/users/{self.owner.pk}/',{'is_active':False},format='json').status_code,200)
        self.assertTrue(AuditLog.objects.filter(action='admin_user_blocked',target=f'user:{self.owner.pk}').exists())
        sub=self.store.subscription
        response=self.client.post('/api/v1/admin/subscriptions/',{'store_id':self.store.pk,'action':'extend','months':2,'reason':'Sinov uzaytirishi'},format='json')
        self.assertEqual(response.status_code,200,response.data)
        sub.refresh_from_db();self.assertIsNotNone(sub.paid_until);self.assertGreater(sub.paid_until,sub.trial_end)
        self.assertTrue(AuditLog.objects.filter(action='admin_subscription_extend',target=f'subscription:{sub.pk}').exists())
        pending=User.objects.create_user(username='pending-activation',is_active=False)
        refused=self.client.patch(f'/api/v1/admin/users/{pending.pk}/',{'is_active':True},format='json')
        self.assertEqual(refused.status_code,400)

    def test_admin_pagination_plan_write_audit_and_backup_truth(self):
        from apps.core.models import AuditLog
        self.client.force_authenticate(self.admin)
        listing=self.client.get('/api/v1/admin/users/')
        self.assertEqual(listing.status_code,200);self.assertIn('results',listing.data);self.assertEqual(listing.data['count'],2)
        created=self.client.post('/api/v1/admin/plans/',{'name':'Annual','months':12,'price':'90000','discount_percent':'5','active':True},format='json')
        self.assertEqual(created.status_code,201,created.data)
        self.assertTrue(AuditLog.objects.filter(action='admin_plan_saved').exists())
        status=self.client.get('/api/v1/admin/system-status/')
        self.assertEqual(status.data['database'],'ok');self.assertFalse(status.data['backup']['available'])

    def test_admin_approves_only_pending_payment_atomically(self):
        from apps.core.models import AuditLog, PaymentRecord
        payment=PaymentRecord.objects.create(store=self.store,plan=self.plan,amount='10000',reference='proof-1',billing_period='year')
        self.client.force_authenticate(self.admin)
        approved=self.client.patch(f'/api/v1/admin/payments/{payment.pk}/',{'action':'approve','reason':'Kvitansiya tekshirildi'},format='json')
        self.assertEqual(approved.status_code,200,approved.data)
        payment.refresh_from_db();self.assertEqual(payment.status,'approved');self.assertEqual(payment.currency,'UZS')
        self.store.subscription.refresh_from_db();self.assertGreater(self.store.subscription.paid_until,self.store.subscription.trial_end)
        self.assertEqual(self.store.subscription.paid_until.month, (self.store.subscription.trial_end.month + 12 - 1) % 12 + 1)
        payment.refresh_from_db()
        self.assertEqual(payment.subscription.status, 'active')
        self.assertEqual(payment.subscription.billing_period, 'year')
        self.assertTrue(AuditLog.objects.filter(action='payment_approved',target=f'payment:{payment.pk}').exists())
        repeated=self.client.patch(f'/api/v1/admin/payments/{payment.pk}/',{'action':'approve','reason':'Takror tekshiruv'},format='json')
        self.assertEqual(repeated.status_code,400)

class StoreActivationSecurityTests(TestCase):
    def test_store_user_is_inactive_non_staff_until_activation(self):
        from rest_framework.test import APIClient

        from apps.core.models import Store

        admin_password = secrets.token_urlsafe(36)
        admin = User.objects.create_superuser(
            username='tenant-admin', password=admin_password
        )
        admin_client = APIClient()
        admin_client.force_authenticate(admin)
        created = admin_client.post('/api/v1/admin/users/', {
            'username': 'new-store-owner',
            'store_name': 'Yangi do‘kon',
        }, format='json')
        self.assertEqual(created.status_code, 201, created.data)

        owner = User.objects.get(username='new-store-owner')
        self.assertFalse(owner.is_active)
        self.assertFalse(owner.is_staff)
        self.assertFalse(owner.has_usable_password())
        self.assertTrue(Store.objects.filter(owner=owner).exists())

        public_client = APIClient()
        self.assertEqual(public_client.post('/api/v1/auth/login/', {
            'username': owner.username,
            'password': secrets.token_urlsafe(36),
        }, format='json').status_code, 401)

        issued = admin_client.post('/api/v1/admin/issue-credential/', {
            'user_id': owner.pk,
            'purpose': 'activation',
        }, format='json')
        self.assertEqual(issued.status_code, 200, issued.data)
        new_password = secrets.token_urlsafe(36)
        activated = public_client.post('/api/v1/auth/activate/', {
            'code': issued.data['one_time_code'],
            'password': new_password,
        }, format='json')
        self.assertEqual(activated.status_code, 200, activated.data)

        from apps.core.models import SubscriptionPlan
        trial_plan=SubscriptionPlan.objects.get(code='standard')
        trial_plan.refresh_from_db()
        owner.store.subscription.refresh_from_db()
        self.assertEqual((owner.store.subscription.trial_end-owner.store.subscription.trial_start).days,trial_plan.trial_days)

        owner.refresh_from_db()
        self.assertTrue(owner.is_active)
        self.assertFalse(owner.is_staff)
        logged_in = public_client.post('/api/v1/auth/login/', {
            'username': owner.username,
            'password': new_password,
        }, format='json')
        self.assertEqual(logged_in.status_code, 200, logged_in.data)


class AccountBillingTests(TestCase):
    def setUp(self):
        from rest_framework.test import APIClient
        from apps.core.models import Store, SubscriptionPlan
        self.user = User.objects.create_user(username='account-owner', password='Strong-password-123')
        self.store = Store.objects.create(owner=self.user, name='Hisob do‘koni')
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        self.plan = SubscriptionPlan.objects.create(name='Test', code='test-plan', months=1,
            price='49000', annual_price='490000', user_limit=2, product_limit=500)

    def test_username_change_and_case_insensitive_duplicate_rejection(self):
        other = User.objects.create_user(username='ReservedName', password='Strong-password-123')
        changed = self.client.post('/api/v1/auth/change-username/', {'username': 'new.owner'}, format='json')
        self.assertEqual(changed.status_code, 200, changed.data)
        self.user.refresh_from_db()
        self.assertEqual(self.user.username, 'new.owner')
        duplicate = self.client.post('/api/v1/auth/change-username/', {'username': other.username.lower()}, format='json')
        self.assertEqual(duplicate.status_code, 400)

    def test_profile_does_not_allow_role_or_store_mutation(self):
        response = self.client.patch('/api/v1/me/', {'is_superuser': True, 'store_id': 999}, format='json')
        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertFalse(self.user.is_superuser)
        self.assertEqual(self.user.store.pk, self.store.pk)
        self.assertEqual(response.data['store'], self.store.name)

    def test_password_change_checks_old_password_and_confirmation(self):
        invalid = self.client.post('/api/v1/auth/change-password/', {
            'old_password': 'wrong-password', 'new_password': 'A completely new password 234',
            'confirm_password': 'A completely new password 234'}, format='json')
        self.assertEqual(invalid.status_code, 400)
        mismatch = self.client.post('/api/v1/auth/change-password/', {
            'old_password': 'Strong-password-123', 'new_password': 'A completely new password 234',
            'confirm_password': 'Other completely new password 234'}, format='json')
        self.assertEqual(mismatch.status_code, 400)
        valid = self.client.post('/api/v1/auth/change-password/', {
            'old_password': 'Strong-password-123', 'new_password': 'A completely new password 234',
            'confirm_password': 'A completely new password 234'}, format='json')
        self.assertEqual(valid.status_code, 200, valid.data)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password('A completely new password 234'))
        self.assertFalse(self.user.check_password('Strong-password-123'))

    def test_catalog_contains_distinct_monthly_and_annual_prices(self):
        response = self.client.get('/api/v1/plans/')
        self.assertEqual(response.status_code, 200)
        item = next(x for x in response.data if x['code'] == 'test-plan')
        self.assertEqual(str(item['price']), '49000.00')
        self.assertEqual(str(item['annual_price']), '490000.00')

    def test_plan_edit_does_not_rewrite_existing_payment_snapshot(self):
        from decimal import Decimal
        from apps.core.models import PaymentRecord
        payment=PaymentRecord.objects.create(store=self.store,plan=self.plan,amount='49000',reference='snapshot')
        self.plan.name='Renamed'
        self.plan.price='99000'
        self.plan.save()
        payment.refresh_from_db()
        self.assertEqual(payment.amount, Decimal('49000.00'))
        self.assertEqual(payment.plan_name, 'Test')

    def test_subscription_expiry_command_updates_state_and_audit(self):
        from datetime import timedelta
        from django.core.management import call_command
        from django.utils import timezone
        from apps.core.models import AuditLog, SubscriptionHistory
        history=SubscriptionHistory.objects.create(store=self.store,plan=self.plan,status='active',
            billing_period='month',amount='49000',starts_at=timezone.now()-timedelta(days=35),
            ends_at=timezone.now()-timedelta(days=1))
        call_command('expire_subscriptions', verbosity=0)
        history.refresh_from_db()
        self.assertEqual(history.status,'expired')
        self.assertTrue(AuditLog.objects.filter(action='subscription_expired',target=f'subscription:{history.pk}').exists())

    def test_backend_enforces_active_product_limit(self):
        from datetime import timedelta
        from django.utils import timezone
        from apps.core.models import Product, Subscription, SubscriptionPlan
        Subscription.objects.create(store=self.store, trial_start=timezone.now(),
            trial_end=timezone.now() + timedelta(days=5))
        standard = SubscriptionPlan.objects.get(code='standard')
        standard.product_limit = 0
        standard.save(update_fields=['product_limit', 'updated_at'])
        response = self.client.post('/api/v1/products/', {
            'name': 'Limitdan tashqari', 'sku': 'LIMIT-1', 'sale_price': '1000',
            'purchase_price': '500', 'unit': 'dona', 'initial_stock': '0',
        }, format='json')
        self.assertEqual(response.status_code, 400, response.data)
        self.assertIn('0 ta faol mahsulot limiti', str(response.data))
        self.assertFalse(Product.objects.filter(store=self.store).exists())
