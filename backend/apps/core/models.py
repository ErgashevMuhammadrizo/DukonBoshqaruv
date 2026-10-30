import uuid
from decimal import Decimal
from django.db import models
from django.db.models import Sum
from django.contrib.auth.models import AbstractUser
from django.conf import settings
from django.core.validators import MinValueValidator
from django.utils import timezone
D= models.DecimalField
class User(AbstractUser):
    pass
class Store(models.Model):
    owner=models.OneToOneField(settings.AUTH_USER_MODEL,on_delete=models.PROTECT,related_name='store')
    name=models.CharField(max_length=200)
    phone=models.CharField(max_length=50,blank=True)
    is_active=models.BooleanField(default=True)
    created_at=models.DateTimeField(auto_now_add=True)
class Category(models.Model):
    store=models.ForeignKey(Store,on_delete=models.CASCADE)
    name=models.CharField(max_length=160)
    class Meta:
        constraints=[models.UniqueConstraint(fields=['store','name'],name='unique_store_category')]
class Product(models.Model):
    store=models.ForeignKey(Store,on_delete=models.PROTECT)
    category=models.ForeignKey(Category,on_delete=models.PROTECT,null=True,blank=True)
    name=models.CharField(max_length=220)
    sku=models.CharField(max_length=70)
    barcode=models.CharField(max_length=80,null=True,blank=True)
    image=models.ImageField(upload_to='products/%Y/%m/',null=True,blank=True)
    purchase_price=D(max_digits=16,decimal_places=2,default=0)
    sale_price=D(max_digits=16,decimal_places=2)
    stock=D(max_digits=16,decimal_places=3,default=0)
    unit=models.CharField(max_length=16,default='dona')
    min_stock=D(max_digits=16,decimal_places=3,default=0)
    active=models.BooleanField(default=True)
    deleted_at=models.DateTimeField(null=True,blank=True,db_index=True)
    updated_at=models.DateTimeField(auto_now=True)
    class Meta:
        constraints=[models.UniqueConstraint(fields=['store','sku'],name='unique_store_sku'),models.UniqueConstraint(fields=['store','barcode'],name='unique_store_barcode'),models.CheckConstraint(condition=models.Q(stock__gte=0),name='nonnegative_stock')]
class InventoryMovement(models.Model):
    store=models.ForeignKey(Store,on_delete=models.PROTECT)
    product=models.ForeignKey(Product,on_delete=models.PROTECT)
    kind=models.CharField(max_length=24)
    delta=D(max_digits=16,decimal_places=3)
    before=D(max_digits=16,decimal_places=3)
    after=D(max_digits=16,decimal_places=3)
    reference=models.CharField(max_length=150,blank=True)
    created_at=models.DateTimeField(auto_now_add=True)
class Sale(models.Model):
    id=models.UUIDField(primary_key=True,default=uuid.uuid4,editable=False)
    store=models.ForeignKey(Store,on_delete=models.PROTECT)
    operation_id=models.UUIDField()
    subtotal=D(max_digits=18,decimal_places=2)
    discount=D(max_digits=18,decimal_places=2,default=0)
    total=D(max_digits=18,decimal_places=2)
    cash=D(max_digits=18,decimal_places=2,default=0)
    card=D(max_digits=18,decimal_places=2,default=0)
    created_at=models.DateTimeField(auto_now_add=True)
    class Meta:
        constraints=[models.UniqueConstraint(fields=['store','operation_id'],name='unique_sale_operation')]
class SaleItem(models.Model):
    sale=models.ForeignKey(Sale,on_delete=models.PROTECT,related_name='items')
    product=models.ForeignKey(Product,on_delete=models.PROTECT)
    name=models.CharField(max_length=220)
    quantity=D(max_digits=16,decimal_places=3)
    unit_price=D(max_digits=16,decimal_places=2)
    cost_price=D(max_digits=16,decimal_places=2)
    line_total=D(max_digits=18,decimal_places=2)
class SubscriptionPlan(models.Model):
    name=models.CharField(max_length=120)
    months=models.PositiveSmallIntegerField()
    price=D(max_digits=16,decimal_places=2)
    discount_percent=D(max_digits=5,decimal_places=2,default=0)
    active=models.BooleanField(default=True)
    code=models.SlugField(max_length=32,unique=True,null=True,blank=True)
    description=models.TextField(blank=True)
    annual_price=D(max_digits=16,decimal_places=2,null=True,blank=True)
    currency=models.CharField(max_length=3,default='UZS')
    trial_days=models.PositiveSmallIntegerField(default=0)
    user_limit=models.PositiveSmallIntegerField(default=2)
    product_limit=models.PositiveIntegerField(default=500)
    features=models.JSONField(default=list,blank=True)
    updated_at=models.DateTimeField(auto_now=True)
class Subscription(models.Model):
    store=models.OneToOneField(Store,on_delete=models.PROTECT)
    trial_start=models.DateTimeField(null=True,blank=True)
    trial_end=models.DateTimeField(null=True,blank=True)
    paid_until=models.DateTimeField(null=True,blank=True)
class PaymentRecord(models.Model):
    checkout_url=models.URLField(max_length=500,blank=True)
    purchased_months=models.PositiveSmallIntegerField(default=1)
    store=models.ForeignKey(Store,on_delete=models.PROTECT)
    plan=models.ForeignKey(SubscriptionPlan,on_delete=models.PROTECT)
    amount=D(max_digits=16,decimal_places=2)
    currency=models.CharField(max_length=3,default='UZS')
    reference=models.CharField(max_length=160)
    status=models.CharField(max_length=16,default='pending')
    approved_by=models.ForeignKey(settings.AUTH_USER_MODEL,null=True,on_delete=models.PROTECT)
    approved_at=models.DateTimeField(null=True)
    submitted_at=models.DateTimeField(auto_now_add=True)
    order_id=models.UUIDField(default=uuid.uuid4,unique=True,editable=False)
    provider=models.CharField(max_length=16,default='manual')
    billing_period=models.CharField(max_length=8,default='month')
    provider_transaction_id=models.CharField(max_length=160,blank=True)
    failure_reason=models.CharField(max_length=300,blank=True)
    subscription=models.ForeignKey('SubscriptionHistory',null=True,blank=True,on_delete=models.PROTECT,related_name='payments')
    plan_name=models.CharField(max_length=120,blank=True)

    def save(self,*args,**kwargs):
        if not self.plan_name and self.plan_id:
            self.plan_name=self.plan.name
        super().save(*args,**kwargs)

class SubscriptionHistory(models.Model):
    STATUSES=[('pending','Pending'),('trial','Trial'),('active','Active'),('expired','Expired'),('cancelled','Cancelled')]
    PERIODS=[('month','Month'),('year','Year')]
    store=models.ForeignKey(Store,on_delete=models.PROTECT,related_name='subscription_history')
    plan=models.ForeignKey(SubscriptionPlan,on_delete=models.PROTECT,related_name='subscriptions')
    starts_at=models.DateTimeField(null=True,blank=True)
    ends_at=models.DateTimeField(null=True,blank=True)
    status=models.CharField(max_length=12,choices=STATUSES,default='pending')
    billing_period=models.CharField(max_length=8,choices=PERIODS)
    amount=D(max_digits=16,decimal_places=2)
    currency=models.CharField(max_length=3,default='UZS')
    created_by=models.ForeignKey(settings.AUTH_USER_MODEL,null=True,blank=True,on_delete=models.SET_NULL)
    created_at=models.DateTimeField(auto_now_add=True)
    updated_at=models.DateTimeField(auto_now=True)
    plan_name=models.CharField(max_length=120,blank=True)

    def save(self,*args,**kwargs):
        if not self.plan_name and self.plan_id:
            self.plan_name=self.plan.name
        super().save(*args,**kwargs)
class Credential(models.Model):
    user=models.ForeignKey(settings.AUTH_USER_MODEL,on_delete=models.CASCADE)
    purpose=models.CharField(max_length=20)
    token_hash=models.CharField(max_length=64,unique=True)
    expires_at=models.DateTimeField()
    consumed_at=models.DateTimeField(null=True)
class SyncOperation(models.Model):
    store=models.ForeignKey(Store,on_delete=models.PROTECT)
    operation_id=models.UUIDField()
    kind=models.CharField(max_length=32)
    response=models.JSONField(default=dict)
    created_at=models.DateTimeField(auto_now_add=True)
    class Meta:
        constraints=[models.UniqueConstraint(fields=['store','operation_id'],name='unique_sync_operation')]
class AuditLog(models.Model):
    actor=models.ForeignKey(settings.AUTH_USER_MODEL,null=True,on_delete=models.SET_NULL)
    action=models.CharField(max_length=100)
    target=models.CharField(max_length=150)
    timestamp=models.DateTimeField(auto_now_add=True)
    metadata=models.JSONField(default=dict)

class DebtRecord(models.Model):
    CUSTOMER='customer'
    STORE='store'
    DIRECTIONS=[(CUSTOMER,'Mijozdan olinadi'),(STORE,'Do‘kon qarzi')]
    store=models.ForeignKey(Store,on_delete=models.PROTECT,related_name='debts')
    direction=models.CharField(max_length=12,choices=DIRECTIONS)
    party_name=models.CharField(max_length=220)
    phone=models.CharField(max_length=50,blank=True)
    amount=D(max_digits=18,decimal_places=2,validators=[MinValueValidator(Decimal('0.01'))])
    reason=models.CharField(max_length=500,blank=True)
    note=models.TextField(blank=True)
    created_on=models.DateField(default=timezone.localdate)
    due_date=models.DateField(null=True,blank=True)
    created_at=models.DateTimeField(auto_now_add=True)
    class Meta:
        indexes=[models.Index(fields=['store','direction','due_date']),models.Index(fields=['store','party_name'])]

    @property
    def paid(self):
        if 'payments' in getattr(self,'_prefetched_objects_cache',{}):
            return sum((p.amount for p in self._prefetched_objects_cache['payments']),Decimal('0.00'))
        return self.payments.aggregate(total=Sum('amount'))['total'] or Decimal('0.00')

    @property
    def balance(self):
        return self.amount-self.paid

class DebtPayment(models.Model):
    METHODS=[('cash','Naqd'),('card','Karta'),('bank','Bank o‘tkazmasi')]
    debt=models.ForeignKey(DebtRecord,on_delete=models.PROTECT,related_name='payments')
    operation_id=models.UUIDField()
    amount=D(max_digits=18,decimal_places=2,validators=[MinValueValidator(Decimal('0.01'))])
    method=models.CharField(max_length=8,choices=METHODS,default='cash')
    paid_on=models.DateField(default=timezone.localdate)
    note=models.CharField(max_length=500,blank=True)
    created_by=models.ForeignKey(settings.AUTH_USER_MODEL,on_delete=models.PROTECT)
    created_at=models.DateTimeField(auto_now_add=True)
    class Meta:
        constraints=[models.UniqueConstraint(fields=['debt','operation_id'],name='unique_debt_payment_operation')]
