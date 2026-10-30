import hashlib,secrets
from datetime import timedelta
from decimal import Decimal,ROUND_HALF_UP,InvalidOperation
from django.db import transaction
from django.utils import timezone
from django.core.exceptions import ValidationError
from .models import Credential,Subscription,SubscriptionPlan,Sale,SaleItem,Product,InventoryMovement,AuditLog,SyncOperation,Store,DebtRecord
CENT=Decimal('0.01')
def money(value):
    try: return Decimal(str(value)).quantize(CENT,rounding=ROUND_HALF_UP)
    except (InvalidOperation,TypeError,ValueError): raise ValidationError('Noto‘g‘ri summa')
def issue_credential(user,purpose,actor=None):
    raw=secrets.token_urlsafe(32)
    with transaction.atomic():
        Credential.objects.filter(user=user,purpose=purpose,consumed_at__isnull=True).update(consumed_at=timezone.now())
        Credential.objects.create(user=user,purpose=purpose,token_hash=hashlib.sha256(raw.encode()).hexdigest(),expires_at=timezone.now()+timedelta(hours=30 if purpose=='activation' else 1))
        AuditLog.objects.create(actor=actor,action='credential_issued',target=f'user:{user.pk}',metadata={'purpose':purpose})
    return raw
@transaction.atomic
def redeem_credential(raw,purpose,password):
    from django.contrib.auth.password_validation import validate_password
    digest=hashlib.sha256(raw.encode()).hexdigest()
    cred=Credential.objects.select_for_update().select_related('user').filter(token_hash=digest,purpose=purpose).first()
    if not cred or cred.consumed_at or cred.expires_at<=timezone.now(): raise ValidationError('Kod yaroqsiz yoki muddati tugagan')
    user=cred.user
    validate_password(password,user)
    user.set_password(password); user.is_active=True; user.save(update_fields=['password','is_active'])
    cred.consumed_at=timezone.now(); cred.save(update_fields=['consumed_at'])
    if purpose=='activation':
        store=user.store
        now=timezone.now()
        plan=SubscriptionPlan.objects.filter(code='standard',active=True).first()
        trial_days=plan.trial_days if plan else 0
        Subscription.objects.get_or_create(store=store,defaults={'trial_start':now,'trial_end':now+timedelta(days=trial_days)})
    else:
        from rest_framework_simplejwt.token_blacklist.models import OutstandingToken,BlacklistedToken
        for token in OutstandingToken.objects.filter(user=user): BlacklistedToken.objects.get_or_create(token=token)
    AuditLog.objects.create(actor=user,action='credential_redeemed',target=f'user:{user.pk}',metadata={'purpose':purpose})
    return user
@transaction.atomic
def create_sale(store,payload):
    from uuid import UUID
    # Serialize checkout attempts per store so an operation replay cannot race its first commit.
    Store.objects.select_for_update().get(pk=store.pk)
    op=UUID(str(payload['operation_id']))
    existing=Sale.objects.filter(store=store,operation_id=op).first()
    if existing: return existing,False
    lines=payload.get('items',[])
    if not lines: raise ValidationError('Savat bo‘sh')
    ids=[i['product_id'] for i in lines]
    if len(set(ids))!=len(ids): raise ValidationError('Takror mahsulot')
    products={str(p.pk):p for p in Product.objects.select_for_update().filter(store=store,id__in=ids,active=True).order_by('id')}
    if len(products)!=len(lines): raise ValidationError('Mahsulot topilmadi')
    detail=[]; subtotal=Decimal('0')
    for line in lines:
        product=products[str(line['product_id'])]
        try: qty=Decimal(str(line['quantity']))
        except (InvalidOperation,ValueError): raise ValidationError('Miqdor xato')
        if not qty.is_finite() or qty<=0 or qty.as_tuple().exponent < -3: raise ValidationError('Miqdor xato')
        if product.unit not in {'kg','gramm','litr','ml','metr','m²','m³'} and qty%1:
            raise ValidationError('Bu mahsulot butun birlikda sotiladi')
        if product.stock<qty: raise ValidationError(f'Omborda yetarli emas: {product.name}')
        total=money(product.sale_price*qty)
        subtotal+=total
        detail.append((product,qty,total))
    discount=money(payload.get('discount',0)); due=money(subtotal-discount)
    cash=money(payload.get('cash',0)); card=money(payload.get('card',0)); debt=money(payload.get('debt',0))
    customer_name=str(payload.get('customer_name') or payload.get('customer') or '').strip() or 'Mijoz'
    customer_phone=str(payload.get('customer_phone') or '').strip()
    if not all(v.is_finite() for v in (discount,cash,card,debt,due)) or discount<0 or discount>subtotal or cash<0 or card<0 or debt<0: raise ValidationError('To‘lov yoki qarz xato')
    if money(cash+card+debt)!=due: raise ValidationError('To‘lov yoki qarz xato')
    sale=Sale.objects.create(store=store,operation_id=op,subtotal=subtotal,discount=discount,total=due,cash=cash,card=card)
    if debt>0:
        DebtRecord.objects.create(store=store,direction='customer',party_name=customer_name,phone=customer_phone,amount=debt,reason='POS savdo',note=f'Operatsiya {op}')
    for p,qty,total in detail:
        before=p.stock; p.stock-=qty; p.save(update_fields=['stock','updated_at'])
        SaleItem.objects.create(sale=sale,product=p,name=p.name,quantity=qty,unit_price=p.sale_price,cost_price=p.purchase_price,line_total=total)
        InventoryMovement.objects.create(store=store,product=p,kind='sale',delta=-qty,before=before,after=p.stock,reference=str(sale.pk))
    AuditLog.objects.create(actor=store.owner,action='sale_created',target=str(sale.pk))
    return sale,True
