import hashlib
import hmac
import json
import time
from unittest.mock import patch
from django.test import TestCase
from rest_framework.test import APIClient
from apps.core.models import User, Store, SubscriptionPlan, PaymentRecord, Subscription, SubscriptionHistory
from apps.core.inpay import reconcile, ProviderError

ENV = {'INPAY_ENABLED':'1', 'INPAY_SECRET_KEY':'sk_live_fixture',
 'INPAY_WEBHOOK_SECRET':'whsec_fixture','APP_ENV':'production',
 'INPAY_WEBHOOK_URL':'https://shop.uz/api/v1/payments/inpay/callback/',
 'INPAY_RETURN_URL':'https://shop.uz/api/v1/payments/inpay/return/'}

@patch.dict('os.environ', ENV)
class InpayTests(TestCase):
 def setUp(self):
  self.user=User.objects.create_user(username='buyer',password='password123')
  self.store=Store.objects.create(owner=self.user,name='Test')
  self.plan=SubscriptionPlan.objects.create(name='Test',price=49000,annual_price=490000,months=3)
  self.payment=PaymentRecord.objects.create(store=self.store,plan=self.plan,amount=49000,reference='inPAY',provider='inpay',provider_version='v2',provider_transaction_id='order123',purchased_months=3)
  self.client=APIClient();self.client.force_authenticate(self.user)
 def data(self,**extra):
  return dict({'id':'order123','amount':49000,'currency':'UZS','status':'succeeded','livemode':True},**extra)
 def signed(self,event,timestamp=None,secret='whsec_fixture'):
  timestamp=str(int(time.time()) if timestamp is None else timestamp)
  raw=json.dumps(event,separators=(',',':')).encode()
  sig=hmac.new(secret.encode(),timestamp.encode()+b'.'+raw,hashlib.sha256).hexdigest()
  return APIClient().post('/api/v1/payments/inpay/callback/',raw,content_type='application/json',HTTP_X_INPAY_SIGNATURE=f't={timestamp},v1={sig}')
 @patch('apps.core.inpay.request_api')
 def test_duplicate_extends_once(self,api):
  api.return_value=self.data();reconcile(self.payment.pk)
  expiry=Subscription.objects.get(store=self.store).paid_until
  reconcile(self.payment.pk)
  self.assertEqual(Subscription.objects.get(store=self.store).paid_until,expiry)
  self.assertEqual(SubscriptionHistory.objects.filter(store=self.store).count(),1)
  self.assertEqual(api.call_count,1)
 @patch('apps.core.inpay.request_api')
 def test_mismatches_rejected(self,api):
  for extra in ({'amount':1000},{'currency':'USD'},{'id':'wrong'},{'livemode':False}):
   api.return_value=self.data(**extra)
   with self.assertRaises(ProviderError):reconcile(self.payment.pk)
  self.assertFalse(SubscriptionHistory.objects.filter(store=self.store).exists())
 @patch('apps.core.inpay.request_api')
 def test_signed_webhook_rechecks_provider(self,api):
  api.return_value=self.data(status='processing')
  self.assertEqual(self.signed({'type':'payment.succeeded','data':{'object':{'id':'order123'}}}).status_code,200)
  self.payment.refresh_from_db();self.assertEqual(self.payment.status,'pending')
 @patch('apps.core.inpay.request_api')
 def test_bad_signature_never_calls_provider(self,api):
  self.assertEqual(self.signed({'type':'payment.succeeded'},secret='wrong').status_code,401)
  api.assert_not_called()
 def test_stale_signature(self):
  self.assertEqual(self.signed({},timestamp=1).status_code,400)
 def test_unsigned_callback(self):
  self.assertEqual(APIClient().post('/api/v1/payments/inpay/callback/',{},format='json').status_code,400)
 def test_other_store_cannot_check(self):
  user=User.objects.create_user(username='other');Store.objects.create(owner=user,name='Other')
  self.client.force_authenticate(user)
  self.assertEqual(self.client.post(f'/api/v1/payments/inpay/{self.payment.pk}/check/').status_code,404)
 @patch('apps.core.inpay.request_api')
 def test_checkout_server_price_reuse(self,api):
  self.payment.status='approved';self.payment.save()
  api.return_value=self.data(id='new',checkout_url='https://inpay.uz/checkout/new')
  result=self.client.post('/api/v1/payments/inpay/',{'plan_id':self.plan.pk,'amount':1},format='json')
  self.assertEqual(result.status_code,200)
  self.assertEqual(api.call_args.kwargs['payload']['amount'],49000)
  payment=PaymentRecord.objects.get(pk=result.data['id'])
  self.assertEqual(payment.purchased_months,3)
  self.assertEqual(str(api.call_args.kwargs['idempotency_key']),str(payment.order_id))
  second=self.client.post('/api/v1/payments/inpay/',{'plan_id':self.plan.pk},format='json')
  self.assertEqual(second.data['id'],payment.pk);self.assertEqual(api.call_count,1)
 @patch('apps.core.inpay.request_api')
 def test_timeout_preserves_key_and_payload(self,api):
  self.payment.status='approved';self.payment.save()
  api.side_effect=ProviderError('timeout','Timeout')
  self.client.post('/api/v1/payments/inpay/',{'plan_id':self.plan.pk},format='json')
  first=api.call_args.kwargs.copy()
  self.plan.price=59000;self.plan.save()
  self.client.post('/api/v1/payments/inpay/',{'plan_id':self.plan.pk},format='json')
  self.assertEqual(first,api.call_args.kwargs)
  self.assertEqual(PaymentRecord.objects.filter(status='pending').count(),1)
 @patch('apps.core.inpay.request_api')
 @patch.dict('os.environ',{'INPAY_SECRET_KEY':'sk_test_fixture'})
 def test_test_payment_never_extends_production(self,api):
  api.return_value=self.data(livemode=False)
  self.assertEqual(reconcile(self.payment.pk).status,'test_paid')
  self.assertFalse(SubscriptionHistory.objects.filter(store=self.store).exists())
 @patch('apps.core.inpay.request_api')
 def test_annual_price_duration(self,api):
  api.return_value=self.data(id='annual',amount=490000,checkout_url='https://inpay.uz/checkout/annual')
  result=self.client.post('/api/v1/payments/inpay/',{'plan_id':self.plan.pk,'billing_period':'year'},format='json')
  self.assertEqual(result.status_code,200)
  self.assertEqual(PaymentRecord.objects.get(pk=result.data['id']).purchased_months,12)

from django.test import SimpleTestCase
from urllib.error import HTTPError
from io import BytesIO
from apps.core.inpay import request_api

@patch.dict('os.environ', ENV)
class ProviderTransportTests(SimpleTestCase):
 @patch('apps.core.inpay.build_opener')
 def test_auth_error_code_is_visible_but_raw_secret_is_not(self, opener):
  body=json.dumps({'success':False,'error':{'code':'invalid_api_key','message':'sk_live_DO_NOT_LOG','request_id':'req_123'}}).encode()
  opener.return_value.open.side_effect=HTTPError('https://inpay.uz/api/v2/payments/',401,'Unauthorized',{},BytesIO(body))
  with self.assertLogs('apps.core.inpay',level='WARNING') as captured:
   with self.assertRaises(ProviderError) as error:request_api('payments/',payload={'amount':49000},idempotency_key='fixed')
  self.assertEqual(error.exception.code,'invalid_api_key')
  self.assertEqual(error.exception.request_id,'req_123')
  self.assertNotIn('DO_NOT_LOG',str(error.exception));self.assertNotIn('DO_NOT_LOG',str(captured.output))
 @patch('apps.core.inpay.build_opener')
 def test_v2_auth_and_idempotency_header(self, opener):
  response=opener.return_value.open.return_value.__enter__.return_value
  response.read.return_value=b'{"success":true,"data":{"id":"test"}}'
  response.headers={}
  self.assertEqual(request_api('payments/',payload={'amount':49000},idempotency_key='uuid')['id'],'test')
  req=opener.return_value.open.call_args.args[0]
  self.assertEqual(req.full_url,'https://inpay.uz/api/v2/payments/')
  self.assertEqual(req.get_header('Authorization'),'Bearer sk_live_fixture')
  self.assertEqual(req.get_header('Idempotency-key'),'uuid')
 @patch('apps.core.inpay.build_opener')
 def test_html_response_has_safe_message(self, opener):
  response=opener.return_value.open.return_value.__enter__.return_value
  response.read.return_value=b'<html>proxy failure</html>';response.headers={}
  with self.assertRaises(ProviderError) as error:request_api('payments/')
  self.assertEqual(error.exception.code,'invalid_response')
