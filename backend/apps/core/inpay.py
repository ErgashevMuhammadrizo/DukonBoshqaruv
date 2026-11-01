"""Hosted inPAY v2; persisted idempotency and signed, independently verified settlement."""
import hashlib
import hmac
import json
import logging
import os
import re
import time
from decimal import Decimal, InvalidOperation
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen, HTTPRedirectHandler, build_opener
from urllib.parse import urlencode, urlparse
from django.db import transaction
from django.utils import timezone
from dateutil.relativedelta import relativedelta
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from .models import Store, SubscriptionPlan, PaymentRecord, Subscription, SubscriptionHistory

log = logging.getLogger(__name__)
BASE_URL = 'https://inpay.uz/api/v2/'

class ProviderError(Exception):
    def __init__(self, code, message, status=502, request_id=''):
        self.code, self.status, self.request_id = code, status, request_id
        super().__init__(message)
    def response(self):
        return Response({'detail': str(self), 'code': self.code, 'request_id': self.request_id}, status=self.status)

MESSAGES = {
    'authentication_error': 'inPAY maxfiy kalitini tekshiring.',
    'invalid_api_key': 'INPAY_SECRET_KEY noto‘g‘ri yoki bekor qilingan.',
    'rate_limit_exceeded': 'inPAY so‘rov limiti. Birozdan keyin qayta urinib ko‘ring.',
    'idempotency_key_reused': 'Hisob ma’lumotlari mos emas. Yordam xizmatiga murojaat qiling.',
    'callback_not_whitelisted': 'inPAY kabinetida webhook domeniga ruxsat bering.',
}

def secret_key():
    key = os.getenv('INPAY_SECRET_KEY', '').strip()
    if not key.startswith(('sk_test_', 'sk_live_')):
        raise ProviderError('configuration_error', 'Backend INPAY_SECRET_KEY maydoniga API v2 sk_test_ yoki sk_live_ kalitini kiriting.', 503)
    return key

def ensure_enabled():
    if os.getenv('INPAY_ENABLED', '0') != '1':
        raise ProviderError('disabled', 'inPAY hozircha yoqilmagan.', 503)
    secret_key()
    if not os.getenv('INPAY_WEBHOOK_SECRET', '').strip().startswith('whsec_'):
        raise ProviderError('configuration_error', 'INPAY_WEBHOOK_SECRET maydoniga whsec_ imzo sirini kiriting.', 503)

class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

def request_api(path, payload=None, params=None, idempotency_key=None):
    key = secret_key()
    url = BASE_URL + path
    if params:
        url += '?' + urlencode(params)
    headers = {'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + key}
    if idempotency_key:
        headers['Idempotency-Key'] = str(idempotency_key)
    req = Request(url, data=json.dumps(payload, separators=(',', ':')).encode() if payload is not None else None, headers=headers)
    http_status = 200
    try:
        with build_opener(NoRedirect()).open(req, timeout=12) as response:
            raw = response.read(1024 * 1024)
            request_id = response.headers.get('X-Request-Id', '')
    except HTTPError as exc:
        http_status = exc.code
        raw = exc.read(65536)
        request_id = exc.headers.get('X-Request-Id', '')
    except (URLError, TimeoutError, OSError):
        raise ProviderError('provider_unavailable', 'inPAY bilan aloqa uzildi. Qayta bosish yangi hisob yaratmaydi.') from None
    try:
        result = json.loads(raw)
    except (ValueError, UnicodeDecodeError):
        raise ProviderError('invalid_response', 'inPAY JSON javob qaytarmadi. Yordam xizmatiga murojaat qiling.') from None
    if not isinstance(result, dict) or result.get('success') is not True or http_status >= 300:
        error = result.get('error', {}) if isinstance(result, dict) else {}
        code = error.get('code', 'provider_error') if isinstance(error, dict) else 'provider_error'
        code = re.sub(r'[^a-zA-Z0-9_]', '', str(code))[:80]
        rid = error.get('request_id', request_id) if isinstance(error, dict) else request_id
        rid = re.sub(r'[^a-zA-Z0-9_-]', '', str(rid))[:100]
        log.warning('inPAY rejected request: http=%s code=%s request_id=%s', http_status, code, rid)
        message = MESSAGES.get(code, 'inPAY so‘rovni rad etdi. Xato kodi: ' + code)
        if http_status in (401, 403):
            message = 'inPAY kaliti, kassa faolligi va IP ruxsatlarini tekshiring. Kod: ' + code
        raise ProviderError(code, message, 502, rid)
    data = result.get('data')
    if not isinstance(data, dict):
        raise ProviderError('invalid_response', 'inPAY javob formati noto‘g‘ri.')
    return data

def validate_payment(payment, data):
    try:
        amount = Decimal(str(data.get('amount')))
        valid = amount.is_finite() and amount == payment.amount
    except (InvalidOperation, TypeError):
        valid = False
    expected_live = secret_key().startswith('sk_live_')
    if payment.provider_livemode is not None and payment.provider_livemode is not expected_live:
        raise ProviderError('payment_mode_changed', 'Hisob boshqa test/jonli kalit bilan yaratilgan. Dastlabki rejimda tekshiring.', 409)
    if (not valid or data.get('id') != payment.provider_transaction_id or
            data.get('currency') != payment.currency or data.get('livemode') is not expected_live):
        raise ProviderError('payment_mismatch', 'To‘lov ID, summa, valyuta yoki test/jonli rejim mos kelmadi.')


def reconcile(payment_id):
    payment = PaymentRecord.objects.get(pk=payment_id, provider='inpay')
    if payment.status in ('approved', 'test_paid'):
        return payment
    if payment.provider_version != 'v2' or not payment.provider_transaction_id:
        raise ProviderError('legacy_payment', 'Eski yoki yaratilayotgan hisob. Tarif tugmasidan qayta urinib ko‘ring.', 409)
    data = request_api('payments/', params={'id': payment.provider_transaction_id})
    validate_payment(payment, data)
    with transaction.atomic():
        Store.objects.select_for_update().get(pk=payment.store_id)
        payment = PaymentRecord.objects.select_for_update().select_related('plan').get(pk=payment_id)
        if payment.status in ('approved', 'test_paid'):
            return payment
        state = data.get('status')
        if state in ('failed', 'canceled'):
            payment.status = state
            payment.save(update_fields=['status'])
            return payment
        if state != 'succeeded':
            return payment
        if data['livemode'] is False and os.getenv('APP_ENV', 'production') != 'development':
            payment.status = 'test_paid'
            payment.save(update_fields=['status'])
            return payment
        sub, _ = Subscription.objects.select_for_update().get_or_create(store_id=payment.store_id)
        now = timezone.now()
        base = max([now] + [d for d in (sub.paid_until, sub.trial_end) if d])
        sub.paid_until = base + relativedelta(months=payment.purchased_months)
        sub.save(update_fields=['paid_until'])
        payment.subscription = SubscriptionHistory.objects.create(store_id=payment.store_id, plan=payment.plan,
            plan_name=payment.plan_name, status='active', billing_period=payment.billing_period,
            starts_at=base, ends_at=sub.paid_until, amount=payment.amount, currency=payment.currency)
        payment.status, payment.approved_at = 'approved', now
        payment.save(update_fields=['subscription', 'status', 'approved_at'])
        return payment

class Checkout(APIView):
    def post(self, request):
        try:
            ensure_enabled()
            store = getattr(request.user, 'store', None)
            if not store or not store.is_active:
                return Response({'detail': 'Faol do‘kon biriktirilmagan.'}, status=403)
            period = request.data.get('billing_period', 'month')
            if period not in ('month', 'year'):
                return Response({'detail': 'Davr noto‘g‘ri.'}, status=400)
            with transaction.atomic():
                Store.objects.select_for_update().get(pk=store.pk)
                try:
                    plan = SubscriptionPlan.objects.get(pk=request.data.get('plan_id'), active=True)
                except (SubscriptionPlan.DoesNotExist, ValueError, TypeError):
                    return Response({'detail': 'Tarif topilmadi.'}, status=400)
                amount = plan.annual_price if period == 'year' else plan.price
                if plan.currency != 'UZS' or amount is None or amount < 1000 or amount != int(amount) or not plan.months:
                    return Response({'detail': 'Tarif summasi butun so‘mda va kamida 1000 bo‘lishi kerak.'}, status=400)
                callback = os.getenv('INPAY_WEBHOOK_URL', '').strip()
                return_url = os.getenv('INPAY_RETURN_URL', '').strip()
                if any(urlparse(url).scheme != 'https' or not urlparse(url).hostname for url in (callback, return_url)):
                    raise ProviderError('configuration_error', 'INPAY_WEBHOOK_URL va INPAY_RETURN_URL uchun HTTPS manzil kiriting.', 503)
                # Pending record commits BEFORE contacting provider, preserving the same UUID on timeout.
                payment = PaymentRecord.objects.filter(store=store, plan=plan, provider='inpay',
                    provider_version='v2', provider_livemode=secret_key().startswith('sk_live_'), status='pending', billing_period=period).order_by('-pk').first()
                if payment and timezone.now() - payment.submitted_at > timezone.timedelta(hours=23):
                    raise ProviderError('pending_expired', 'Eski hisobni tekshirish uchun yordam xizmatiga murojaat qiling.', 409)
                if not payment:
                    payment = PaymentRecord.objects.create(store=store, plan=plan, amount=amount, currency='UZS',
                        provider='inpay', provider_version='v2', provider_livemode=secret_key().startswith('sk_live_'), billing_period=period, reference='inPAY v2',
                        purchased_months=12 if period == 'year' else plan.months)
                    payment.provider_payload = {'amount': int(amount), 'currency': 'UZS',
                        'description': 'e-dukon: ' + plan.name, 'return_url': return_url, 'webhook_url': callback,
                        'metadata': {'order_id': str(payment.order_id)}}
                    payment.save(update_fields=['provider_payload'])
            if not payment.checkout_url:
                data = request_api('payments/', payload=payment.provider_payload, idempotency_key=payment.order_id)
                order, url = data.get('id'), data.get('checkout_url')
                parsed = urlparse(url) if isinstance(url, str) else None
                if (not isinstance(order, str) or not order or len(order) > 160 or not parsed or
                        parsed.scheme != 'https' or parsed.hostname != 'inpay.uz' or parsed.username or len(url) > 500):
                    raise ProviderError('invalid_response', 'inPAY to‘lov havolasi noto‘g‘ri.')
                payment.provider_transaction_id = order
                validate_payment(payment, data)
                payment.checkout_url = url
                payment.save(update_fields=['provider_transaction_id', 'checkout_url'])
            return Response({'id': payment.pk, 'pay_url': payment.checkout_url, 'status': payment.status})
        except ProviderError as exc:
            return exc.response()

class CheckPayment(APIView):
    def post(self, request, pk):
        payment = PaymentRecord.objects.filter(pk=pk, store=getattr(request.user, 'store', None), provider='inpay').first()
        if not payment:
            return Response(status=404)
        try:
            ensure_enabled()
            payment = reconcile(payment.pk)
            return Response({'id': payment.pk, 'status': payment.status})
        except ProviderError as exc:
            return exc.response()

class Callback(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    def post(self, request):
        raw = request.body
        secret = os.getenv('INPAY_WEBHOOK_SECRET', '').strip()
        if not secret.startswith('whsec_'):
            return Response({'detail': 'Webhook siri sozlanmagan.'}, status=503)
        match = re.fullmatch(r't=(\d+),v1=([a-fA-F0-9]{64})', request.headers.get('X-InPAY-Signature', ''))
        if not match or abs(time.time() - int(match[1])) > 300:
            return Response({'detail': 'Imzo vaqti yaroqsiz.'}, status=400)
        expected = hmac.new(secret.encode(), match[1].encode() + b'.' + raw, hashlib.sha256).hexdigest()
        if not hmac.compare_digest(expected, match[2].lower()):
            return Response({'detail': 'Imzo yaroqsiz.'}, status=401)
        try:
            event = json.loads(raw)
            obj = event.get('data', {}).get('object', {})
            kind, order = event.get('type'), obj.get('id')
        except (ValueError, AttributeError):
            return Response(status=400)
        if kind not in ('payment.succeeded', 'payment.failed', 'payment.canceled'):
            return Response({'received': True})
        if not isinstance(order, str) or len(order) > 160:
            return Response(status=400)
        payment = PaymentRecord.objects.filter(provider='inpay', provider_version='v2', provider_transaction_id=order).first()
        if not payment:
            # Callback may arrive before the create response was persisted. Retry later.
            return Response({'detail': 'Hisob hali tayyor emas.'}, status=503)
        try:
            reconcile(payment.pk)
        except ProviderError as exc:
            return exc.response()
        return Response({'received': True})

class PaymentReturn(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    def get(self, request):
        from django.http import HttpResponse
        return HttpResponse('<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>e-dukon</title><h1>e-dukon</h1><p>Ilovaga qayting. To‘lov holati avtomatik tekshiriladi.</p>')
