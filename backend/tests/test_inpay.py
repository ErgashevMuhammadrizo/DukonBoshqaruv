from decimal import Decimal
from unittest.mock import patch
from django.test import TestCase
from rest_framework.test import APIClient
from apps.core.models import User, Store, SubscriptionPlan, PaymentRecord, Subscription, SubscriptionHistory
from apps.core.inpay import reconcile, ProviderError

class InpayTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='buyer', password='password123')
        self.store = Store.objects.create(owner=self.user, name='Test')
        self.plan = SubscriptionPlan.objects.create(name='Test', price=49000, months=3)
        self.payment = PaymentRecord.objects.create(store=self.store, plan=self.plan,
            amount=49000, reference='inPAY', provider='inpay', provider_transaction_id='order123', purchased_months=3)

    @patch('apps.core.inpay.bearer', return_value='test')
    @patch('apps.core.inpay.request_api')
    def test_duplicate_callback_extends_once(self, api, token):
        api.return_value = {'success': True, 'order_id': 'order123', 'amount': '49000.00', 'status': 'success'}
        reconcile(self.payment.pk)
        expiry = Subscription.objects.get(store=self.store).paid_until
        reconcile(self.payment.pk)
        self.assertEqual(Subscription.objects.get(store=self.store).paid_until, expiry)
        self.assertEqual(SubscriptionHistory.objects.filter(store=self.store).count(), 1)
        self.assertEqual(api.call_count, 1)

    @patch('apps.core.inpay.bearer', return_value='test')
    @patch('apps.core.inpay.request_api')
    def test_wrong_amount_does_not_activate(self, api, token):
        api.return_value = {'success': True, 'order_id': 'order123', 'amount': '1000', 'status': 'success'}
        with self.assertRaises(ProviderError): reconcile(self.payment.pk)
        self.payment.refresh_from_db()
        self.assertEqual(self.payment.status, 'pending')
        self.assertFalse(SubscriptionHistory.objects.filter(store=self.store).exists())

    @patch('apps.core.inpay.bearer', return_value='test')
    @patch('apps.core.inpay.request_api')
    def test_fake_callback_status_is_ignored(self, api, token):
        api.return_value = {'success': True, 'order_id': 'order123', 'amount': '49000', 'status': 'pending'}
        response = APIClient().post('/api/v1/payments/inpay/callback/', {'order_id':'order123', 'status':'success'}, format='json')
        self.assertEqual(response.status_code, 200)
        self.payment.refresh_from_db()
        self.assertEqual(self.payment.status, 'pending')

    def test_other_store_cannot_check(self):
        user = User.objects.create_user(username='other')
        Store.objects.create(owner=user, name='Other')
        client = APIClient(); client.force_authenticate(user)
        self.assertEqual(client.post(f'/api/v1/payments/inpay/{self.payment.pk}/check/').status_code, 404)

    @patch.dict('os.environ', {'INPAY_ENABLED':'1', 'INPAY_CALLBACK_URL':'https://shop.uz/api/v1/payments/inpay/callback/'})
    @patch('apps.core.inpay.bearer', return_value='test')
    @patch('apps.core.inpay.request_api')
    def test_checkout_uses_server_price_and_reuses_pending(self, api, token):
        self.payment.status = 'approved'; self.payment.save()
        api.return_value = {'success': True, 'order_id': 'new-order', 'pay_url': 'https://inpay.uz/checkout/new-order'}
        client = APIClient(); client.force_authenticate(self.user)
        response = client.post('/api/v1/payments/inpay/', {'plan_id': self.plan.pk, 'amount': 1}, format='json')
        self.assertEqual(response.status_code, 201)
        self.assertEqual(api.call_args.kwargs['payload']['amount'], 49000)
        payment = PaymentRecord.objects.get(pk=response.data['id'])
        self.assertEqual(payment.purchased_months, 3)
        second = client.post('/api/v1/payments/inpay/', {'plan_id': self.plan.pk}, format='json')
        self.assertEqual(second.data['id'], payment.pk)
        self.assertEqual(api.call_count, 1)
