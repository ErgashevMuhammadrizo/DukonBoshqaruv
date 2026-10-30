"""inPAY checkout. Callback is a hint; settlement always uses provider lookup."""
import json
import os
from decimal import Decimal, InvalidOperation
from urllib.request import Request, urlopen
from urllib.parse import urlencode, urlparse
from django.core.cache import cache
from django.db import transaction
from django.utils import timezone
from dateutil.relativedelta import relativedelta
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from .models import Store, SubscriptionPlan, PaymentRecord, Subscription, SubscriptionHistory

class ProviderError(Exception):
    pass

def enabled():
    return os.getenv('INPAY_ENABLED', '0') == '1'

def request_api(path, payload=None, token=None, params=None):
    url = 'https://inpay.uz/api/v1/' + path
    if params:
        url += '?' + urlencode(params)
    headers = {'Accept': 'application/json', 'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = Request(url, data=json.dumps(payload).encode() if payload is not None else None, headers=headers)
    try:
        with urlopen(req, timeout=15) as response:
            data = json.load(response)
        if not isinstance(data, dict) or data.get('success') is not True:
            raise ProviderError()
        return data
    except Exception:
        raise ProviderError('inPAY bilan aloqa amalga oshmadi') from None

def bearer():
    merchant = os.getenv('INPAY_MERCHANT_ID', '')
    secret = os.getenv('INPAY_MERCHANT_TOKEN', '')
    if not merchant or not secret:
        raise ProviderError('inPAY sozlanmagan')
    key = 'inpay-bearer-' + merchant
    token = cache.get(key)
    if not token:
        token = request_api('authorization/', params={'merchant_id': merchant, 'merchant_token': secret}).get('bearer_token')
        if not isinstance(token, str) or not token:
            raise ProviderError('inPAY autentifikatsiya xatosi')
        cache.set(key, token, 23 * 3600)
    return token

@transaction.atomic
def reconcile(payment_id):
    payment = PaymentRecord.objects.select_for_update().select_related('plan').get(pk=payment_id, provider='inpay')
    if payment.status == 'approved':
        return payment
    if not payment.provider_transaction_id:
        raise ProviderError('Hisob hali yaratilmagan')
    data = request_api('transactions/', token=bearer(), params={'order_id': payment.provider_transaction_id})
    try:
        valid = str(data.get('order_id')) == payment.provider_transaction_id and Decimal(str(data.get('amount'))) == payment.amount
    except (InvalidOperation, TypeError):
        valid = False
    if not valid or payment.currency != 'UZS':
        raise ProviderError('To‘lov ma’lumotlari mos kelmadi')
    if data.get('status') != 'success':
        return payment
    Store.objects.select_for_update().get(pk=payment.store_id)
    sub, _ = Subscription.objects.select_for_update().get_or_create(store_id=payment.store_id)
    now = timezone.now()
    base = max([now] + [d for d in (sub.paid_until, sub.trial_end) if d])
    months = payment.purchased_months
    sub.paid_until = base + relativedelta(months=months)
    sub.save(update_fields=['paid_until'])
    payment.subscription = SubscriptionHistory.objects.create(store_id=payment.store_id, plan=payment.plan,
        plan_name=payment.plan_name, status='active', billing_period=payment.billing_period,
        starts_at=base, ends_at=sub.paid_until, amount=payment.amount, currency=payment.currency)
    payment.status = 'approved'
    payment.approved_at = now
    payment.save(update_fields=['subscription', 'status', 'approved_at'])
    return payment

class Checkout(APIView):
    @transaction.atomic
    def post(self, request):
        if not enabled():
            return Response({'detail': 'inPAY hozircha yoqilmagan'}, status=503)
        store = getattr(request.user, 'store', None)
        if not store:
            return Response(status=403)
        Store.objects.select_for_update().get(pk=store.pk)
        period = request.data.get('billing_period', 'month')
        if period not in ('month', 'year'):
            return Response({'detail': 'Davr noto‘g‘ri'}, status=400)
        try:
            plan = SubscriptionPlan.objects.get(pk=request.data.get('plan_id'), active=True)
        except (SubscriptionPlan.DoesNotExist, ValueError, TypeError):
            return Response({'detail': 'Tarif topilmadi'}, status=400)
        amount = plan.annual_price if period == 'year' else plan.price
        if plan.currency != 'UZS' or amount is None or amount < 1000:
            return Response({'detail': 'Tarif summasi inPAY uchun mos emas'}, status=400)
        callback = os.getenv('INPAY_CALLBACK_URL', '')
        if urlparse(callback).scheme != 'https':
            return Response({'detail': 'HTTPS callback sozlanmagan'}, status=503)
        pending = PaymentRecord.objects.filter(store=store, plan=plan, provider='inpay', status='pending', billing_period=period).first()
        if pending:
            return Response({'detail': 'Oldingi hisobni tekshiring', 'id': pending.pk, 'pay_url': pending.checkout_url or None}, status=200)
        try:
            data = request_api('create/', token=bearer(), payload={
                'merchant_id': os.getenv('INPAY_MERCHANT_ID'), 'token': os.getenv('INPAY_MERCHANT_TOKEN'),
                'amount': float(amount), 'description': 'Dokon Boshqaruv: ' + plan.name,
                'callback_url': callback})
            order, pay_url = str(data.get('order_id', '')), data.get('pay_url', '')
            parsed = urlparse(pay_url)
            if not order or len(order) > 160 or parsed.scheme != 'https' or parsed.hostname != 'inpay.uz' or len(pay_url) > 500:
                raise ProviderError('inPAY javobi noto‘g‘ri')
            payment = PaymentRecord.objects.create(store=store, plan=plan, amount=amount, currency='UZS',
                provider='inpay', provider_transaction_id=order, billing_period=period,
                reference='inPAY', purchased_months=12 if period == 'year' else plan.months, checkout_url=pay_url)
            return Response({'id': payment.pk, 'pay_url': pay_url, 'status': payment.status}, status=201)
        except ProviderError as exc:
            return Response({'detail': str(exc)}, status=502)

class CheckPayment(APIView):
    def post(self, request, pk):
        payment = PaymentRecord.objects.filter(pk=pk, store=getattr(request.user, 'store', None), provider='inpay').first()
        if not payment:
            return Response(status=404)
        try:
            payment = reconcile(payment.pk)
            return Response({'id': payment.pk, 'status': payment.status})
        except ProviderError as exc:
            return Response({'detail': str(exc)}, status=502)

class Callback(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    def post(self, request):
        order = request.data.get('order_id')
        if not isinstance(order, str) or len(order) > 160:
            return Response(status=400)
        payment = PaymentRecord.objects.filter(provider='inpay', provider_transaction_id=order).first()
        if not payment:
            return Response({'ok': True})
        try:
            reconcile(payment.pk)
        except ProviderError:
            return Response({'detail': 'Qayta urinib ko‘ring'}, status=503)
        return Response({'ok': True})
