from datetime import date
from decimal import Decimal
from django.core.paginator import Paginator
from django.conf import settings
from django.db import connection
from django.db import transaction
from django.db.models import Count, Q, Sum
from django.utils import timezone
from rest_framework import serializers
from rest_framework.permissions import BasePermission
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import AuditLog, PaymentRecord, Store, Subscription, SubscriptionHistory, SubscriptionPlan, User

def err(message):
    return Response({'error': {'code': 'invalid_request', 'message': str(message)}}, status=400)


class SuperadminOnly(BasePermission):
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.is_superuser)


class AdminBase(APIView):
    permission_classes = [SuperadminOnly]


def _user(user):
    store = getattr(user, 'store', None)
    return {'id': user.pk, 'username': user.username, 'is_active': user.is_active,
            'has_password': user.has_usable_password(), 'is_superuser': user.is_superuser, 'date_joined': user.date_joined,
            'store_id': store.pk if store else None, 'store_name': store.name if store else None}


def _store(store):
    sub = getattr(store, 'subscription', None)
    now = timezone.now()
    if sub and sub.trial_end and sub.trial_end > now and not (sub.paid_until and sub.paid_until > now):
        state = 'trial'
    elif sub and ((sub.trial_end and sub.trial_end > now) or (sub.paid_until and sub.paid_until > now)):
        state = 'active'
    else:
        state = 'expired'
    return {'id': store.pk, 'name': store.name, 'phone': store.phone, 'owner': store.owner.username,
            'owner_id': store.owner_id, 'is_active': store.is_active, 'created_at': store.created_at,
            'subscription_status': state, 'trial_end': sub.trial_end if sub else None,
            'paid_until': sub.paid_until if sub else None, 'staff_count': 1}


def _page(qs, request, size=25):
    page = Paginator(qs, size).get_page(request.query_params.get('page', 1))
    return page


class Dashboard(AdminBase):
    def get(self, request):
        start, end = request.query_params.get('start'), request.query_params.get('end')
        try:
            if start: date.fromisoformat(start)
            if end: date.fromisoformat(end)
        except ValueError:
            return err('Sana YYYY-MM-DD formatida bo‘lishi kerak')
        users, stores = User.objects.all(), Store.objects.all()
        new_users, new_stores = users, stores
        if start:
            new_users, new_stores = new_users.filter(date_joined__date__gte=start), new_stores.filter(created_at__date__gte=start)
        if end:
            new_users, new_stores = new_users.filter(date_joined__date__lte=end), new_stores.filter(created_at__date__lte=end)
        if not start and not end:
            new_users, new_stores = new_users.filter(date_joined__date=timezone.localdate()), new_stores.filter(created_at__date=timezone.localdate())
        now = timezone.now()
        subs = Subscription.objects.all()
        active = Q(paid_until__gt=now)
        trial = Q(trial_end__gt=now) & (Q(paid_until__isnull=True) | Q(paid_until__lte=now))
        expired = (Q(paid_until__isnull=True) | Q(paid_until__lte=now)) & (Q(trial_end__isnull=True) | Q(trial_end__lte=now))
        payments = PaymentRecord.objects.filter(status='approved').aggregate(amount=Sum('amount'), count=Count('id'))
        logs = AuditLog.objects.select_related('actor').order_by('-timestamp')[:12]
        return Response({
            'users': {'total': users.count(), 'active': users.filter(is_active=True).count(), 'blocked': users.filter(is_active=False).count()},
            'stores': {'total': stores.count(), 'active': stores.filter(is_active=True).count(), 'blocked': stores.filter(is_active=False).count()},
            'new_users': new_users.count(), 'new_stores': new_stores.count(),
            'subscriptions': {'active': subs.filter(active).count(), 'trial': subs.filter(trial).count(), 'expired': subs.filter(expired).count()},
            'payments': {'approved_total': payments['amount'] or Decimal('0'), 'approved_count': payments['count'] or 0},
            'recent_actions': [{'id': x.pk, 'actor': x.actor.username if x.actor else '—', 'action': x.action,
                                'target': x.target, 'timestamp': x.timestamp} for x in logs]})


class UserList(AdminBase):
    def get(self, request):
        qs = User.objects.select_related('store').order_by('-id')
        q = request.query_params.get('q', '').strip()
        if q: qs = qs.filter(Q(username__icontains=q) | Q(store__name__icontains=q))
        active = request.query_params.get('active')
        if active in ('true', 'false'): qs = qs.filter(is_active=(active == 'true'))
        page = _page(qs, request)
        return Response({'count': page.paginator.count, 'page': page.number, 'pages': page.paginator.num_pages,
                         'results': [_user(x) for x in page.object_list]})

    @transaction.atomic
    def post(self, request):
        username = str(request.data.get('username', '')).strip()
        if not username: return err('Username kerak')
        if User.objects.filter(username=username).exists(): return err('Bu username band')
        store_name = str(request.data.get('store_name', '')).strip() or f'{username} do‘koni'
        user = User.objects.create_user(username=username, is_active=False)
        store = Store.objects.create(owner=user, name=store_name)
        AuditLog.objects.create(actor=request.user, action='admin_user_created', target=f'user:{user.pk}', metadata={'store_id': store.pk})
        return Response({'id': user.pk, 'username': username, 'store_id': store.pk, 'store_name': store.name}, status=201)


class UserDetail(AdminBase):
    def get(self, request, pk):
        user = User.objects.select_related('store').filter(pk=pk).first()
        return Response(_user(user)) if user else Response(status=404)

    @transaction.atomic
    def patch(self, request, pk):
        user = User.objects.select_related('store').filter(pk=pk).first()
        if not user: return Response(status=404)
        active = request.data.get('is_active')
        if not isinstance(active, bool): return err('is_active boolean bo‘lishi kerak')
        if active and not user.has_usable_password(): return err('Hisobni faollashtirish uchun bir martalik aktivatsiya kodidan foydalaning')
        if user.pk == request.user.pk and user.is_superuser and not active: return err('O‘z hisobingizni bloklay olmaysiz')
        user.is_active = active
        user.save(update_fields=['is_active'])
        AuditLog.objects.create(actor=request.user, action='admin_user_activated' if active else 'admin_user_blocked', target=f'user:{user.pk}')
        return Response(_user(user))


class StoreList(AdminBase):
    def get(self, request):
        qs = Store.objects.select_related('owner', 'subscription').order_by('-created_at')
        q = request.query_params.get('q', '').strip()
        if q: qs = qs.filter(Q(name__icontains=q) | Q(owner__username__icontains=q))
        active = request.query_params.get('active')
        if active in ('true', 'false'): qs = qs.filter(is_active=(active == 'true'))
        page = _page(qs, request)
        return Response({'count': page.paginator.count, 'page': page.number, 'pages': page.paginator.num_pages,
                         'results': [_store(x) for x in page.object_list]})

    @transaction.atomic
    def patch(self, request):
        store = Store.objects.filter(pk=request.data.get('store_id')).first()
        if not store: return Response(status=404)
        active = request.data.get('is_active')
        if not isinstance(active, bool): return err('is_active boolean bo‘lishi kerak')
        reason = str(request.data.get('reason', '')).strip()
        if not active and not reason: return err('Do‘konni bloklash sababi majburiy')
        store.is_active = active
        store.save(update_fields=['is_active'])
        AuditLog.objects.create(actor=request.user, action='admin_store_activated' if active else 'admin_store_blocked',
                                target=f'store:{store.pk}', metadata={'reason': reason[:300]})
        return Response(_store(store))


class PlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = SubscriptionPlan
        fields = ['id', 'code', 'name', 'description', 'months', 'price', 'annual_price', 'currency',
                  'trial_days', 'user_limit', 'product_limit', 'features', 'discount_percent', 'active', 'updated_at']
        read_only_fields = ['updated_at']

    def validate_discount_percent(self, value):
        if value < 0 or value > 100: raise serializers.ValidationError('Chegirma 0–100 oralig‘ida bo‘lishi kerak')
        return value

    def validate_months(self, value):
        if value < 1: raise serializers.ValidationError('Muddat kamida bir oy bo‘lishi kerak')
        return value

    def validate_price(self, value):
        if value < 0: raise serializers.ValidationError('Narx manfiy bo‘lishi mumkin emas')
        return value

    def validate_annual_price(self, value):
        if value is not None and value < 0: raise serializers.ValidationError('Yillik narx manfiy bo‘lishi mumkin emas')
        return value

    def validate_features(self, value):
        if not isinstance(value, list) or any(not isinstance(item, str) or len(item) > 200 for item in value):
            raise serializers.ValidationError('Imkoniyatlar qisqa matnlar ro‘yxati bo‘lishi kerak')
        return value


class Plans(AdminBase):
    def get(self, request): return Response(PlanSerializer(SubscriptionPlan.objects.order_by('months'), many=True).data)
    def post(self, request): return self.save(request)
    def save(self, request, plan=None):
        serializer = PlanSerializer(plan, data=request.data, partial=plan is not None)
        if not serializer.is_valid(): return Response({'error': {'code': 'invalid_request', 'message': serializer.errors}}, status=400)
        plan = serializer.save()
        AuditLog.objects.create(actor=request.user, action='admin_plan_saved', target=f'plan:{plan.pk}')
        return Response(PlanSerializer(plan).data, status=201 if serializer.instance is plan and request.method == 'POST' else 200)


class PlanDetail(AdminBase):
    def patch(self, request, pk):
        plan = SubscriptionPlan.objects.filter(pk=pk).first()
        return Plans().save(request, plan) if plan else Response(status=404)


class SubscriptionList(AdminBase):
    def get(self, request):
        stores = Store.objects.select_related('owner', 'subscription').order_by('-created_at')
        q=request.query_params.get('q','').strip()
        if q: stores=stores.filter(Q(name__icontains=q)|Q(owner__username__icontains=q))
        raw_plan=request.query_params.get('plan')
        if raw_plan:
            try: stores=stores.filter(subscription_history__plan_id=int(raw_plan)).distinct()
            except ValueError: return err('Tarif filtri noto‘g‘ri')
        rows=[]
        for store in stores:
            legacy=getattr(store,'subscription',None)
            state=_store(store)['subscription_status']
            history=store.subscription_history.select_related('plan').order_by('-created_at').first()
            if history:
                state=history.status
            if history and state=='active' and history.ends_at and history.ends_at<=timezone.now(): state='expired'
            rows.append({'id':history.pk if history else getattr(legacy,'pk',None),
                         'store_id':store.pk,'store':store.name,'owner':store.owner.username,
                         'status':state,'plan':history.plan_name if history else None,
                         'plan_id':history.plan_id if history else None,
                         'billing_period':history.billing_period if history else None,
                         'amount':history.amount if history else None,
                         'trial_end':legacy.trial_end if legacy else None,
                         'paid_until':legacy.paid_until if legacy else None})
        state=request.query_params.get('status')
        if state: rows=[row for row in rows if row['status']==state]
        return Response(rows)

    @transaction.atomic
    def post(self, request):
        from dateutil.relativedelta import relativedelta
        try:
            store = Store.objects.select_for_update().get(pk=request.data['store_id'])
        except (KeyError, Store.DoesNotExist): return Response(status=404)
        sub, _ = Subscription.objects.select_for_update().get_or_create(store=store)
        action = request.data.get('action')
        reason=str(request.data.get('reason','')).strip()
        if not reason: return err('Admin amalining sababi majburiy')
        if action == 'extend':
            try: months = int(request.data.get('months', 1))
            except (TypeError, ValueError): return err('Oylar soni noto‘g‘ri')
            if months < 1 or months > 36: return err('Muddat 1–36 oy bo‘lishi kerak')
            now = timezone.now()
            dates = [x for x in (sub.paid_until, sub.trial_end) if x and x > now]
            sub.paid_until = max([now, *dates]) + relativedelta(months=months)
        elif action == 'cancel':
            sub.paid_until = sub.trial_end = timezone.now()
        else: return err('Amal turi noto‘g‘ri')
        sub.save()
        history=store.subscription_history.order_by('-created_at').first()
        if action=='cancel' and history and history.status in ('active','trial','pending'):
            history.status='cancelled';history.ends_at=timezone.now();history.save(update_fields=['status','ends_at','updated_at'])
        elif action=='extend':
            plan=history.plan if history else SubscriptionPlan.objects.filter(active=True,code='standard').first()
            if plan:
                start=sub.paid_until-relativedelta(months=months)
                SubscriptionHistory.objects.create(store=store,plan=plan,status='active',billing_period='year' if months==12 else 'month',starts_at=start,ends_at=sub.paid_until,amount=Decimal('0.00'),currency=plan.currency,created_by=request.user)
        AuditLog.objects.create(actor=request.user, action=f'admin_subscription_{action}', target=f'subscription:{sub.pk}', metadata={'months': request.data.get('months'),'reason':reason[:300]})
        return Response({'id': sub.pk, 'store_id': sub.store_id, 'paid_until': sub.paid_until, 'trial_end': sub.trial_end})


class Payments(AdminBase):
    def get(self, request):
        qs = PaymentRecord.objects.select_related('store', 'plan', 'approved_by').order_by('-submitted_at')
        status = request.query_params.get('status')
        if status: qs = qs.filter(status=status)
        start, end = request.query_params.get('start'), request.query_params.get('end')
        try:
            if start: date.fromisoformat(start)
            if end: date.fromisoformat(end)
        except ValueError: return err('Sana YYYY-MM-DD formatida bo‘lishi kerak')
        if start and end and start > end: return err('Boshlanish sanasi tugash sanasidan keyin bo‘lishi mumkin emas')
        if start: qs = qs.filter(submitted_at__date__gte=start)
        if end: qs = qs.filter(submitted_at__date__lte=end)
        page = _page(qs, request, 50)
        return Response({'count': page.paginator.count, 'page': page.number, 'pages': page.paginator.num_pages,
                         'results': [{'id': p.pk, 'store': p.store.name, 'store_id': p.store_id, 'plan': p.plan_name,
                                      'amount': p.amount, 'currency': p.currency, 'status': p.status, 'reference': p.reference,
                                      'provider':p.provider,'provider_transaction_id':p.provider_transaction_id,
                                      'billing_period':p.billing_period,'failure_reason':p.failure_reason,
                                      'subscription_id':p.subscription_id,
                                      'submitted_at': p.submitted_at, 'approved_at': p.approved_at,
                                      'approved_by': p.approved_by.username if p.approved_by else None} for p in page.object_list]})


class PaymentDetail(AdminBase):
    @transaction.atomic
    def patch(self, request, pk):
        if request.data.get('action') != 'approve': return err('Faqat pending to‘lovni tasdiqlash mumkin')
        reason=str(request.data.get('reason','')).strip()
        if not reason: return err('To‘lovni tasdiqlash sababi majburiy')
        payment = PaymentRecord.objects.select_for_update().select_related('store', 'plan', 'subscription').filter(pk=pk).first()
        if not payment: return Response(status=404)
        if payment.status != 'pending': return err('To‘lov allaqachon ko‘rib chiqilgan')
        if payment.provider != 'manual': return err('Provider to‘lovlarini faqat tasdiqlangan provider callback’i yakunlaydi')
        from dateutil.relativedelta import relativedelta
        Store.objects.select_for_update().get(pk=payment.store_id)
        sub, _ = Subscription.objects.select_for_update().get_or_create(store=payment.store)
        now = timezone.now()
        dates = [x for x in (sub.paid_until, sub.trial_end) if x and x > now]
        base = max([now, *dates])
        months = 12 if payment.billing_period == 'year' else 1
        sub.paid_until = base + relativedelta(months=months)
        sub.save(update_fields=['paid_until'])
        history = payment.subscription
        if history:
            history.status, history.starts_at, history.ends_at = 'active', base, sub.paid_until
            history.save(update_fields=['status', 'starts_at', 'ends_at', 'updated_at'])
        else:
            history=SubscriptionHistory.objects.create(
                store=payment.store,plan=payment.plan,status='active',billing_period=payment.billing_period,
                starts_at=base,ends_at=sub.paid_until,amount=payment.amount,currency=payment.currency,
                created_by=request.user)
            payment.subscription=history
        payment.status, payment.approved_by, payment.approved_at = 'approved', request.user, now
        payment.save(update_fields=['status', 'approved_by', 'approved_at', 'subscription'])
        AuditLog.objects.create(actor=request.user, action='payment_approved', target=f'payment:{payment.pk}', metadata={'billing_period': payment.billing_period, 'reason': reason[:300]})
        return Response({'id': payment.pk, 'status': payment.status, 'approved_at': payment.approved_at})


class Audit(AdminBase):
    def get(self, request):
        qs = AuditLog.objects.select_related('actor').order_by('-timestamp')
        q = request.query_params.get('q', '').strip()
        if q: qs = qs.filter(Q(action__icontains=q) | Q(target__icontains=q) | Q(actor__username__icontains=q))
        page = _page(qs, request, 50)
        return Response({'count': page.paginator.count, 'page': page.number, 'pages': page.paginator.num_pages,
                         'results': [{'id': x.pk, 'actor': x.actor.username if x.actor else '—', 'action': x.action,
                                      'target': x.target, 'metadata': x.metadata, 'timestamp': x.timestamp} for x in page.object_list]})


class SystemStatus(AdminBase):
    def get(self, request):
        try:
            with connection.cursor() as cursor: cursor.execute('SELECT 1'); cursor.fetchone()
            database = 'ok'
        except Exception: database = 'error'
        import json
        from pathlib import Path
        status_file = Path(settings.BACKUP_STATUS_FILE).expanduser() if settings.BACKUP_STATUS_FILE else Path(settings.BACKUP_DIR) / 'status.json'
        try:
            backup = json.loads(status_file.read_text())
            backup = {key: backup.get(key) for key in ('available', 'last_success_at', 'last_error_at', 'last_error', 'size_bytes', 'database_engine')}
            backup['configured'] = True
        except (OSError, ValueError):
            backup = {'configured': False, 'available': False, 'message': 'Backup hali qayd etilmagan'}
        return Response({'api': 'ok', 'database': database, 'backup': backup, 'checked_at': timezone.now()})
