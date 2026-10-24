from django.contrib import admin
from django.db import transaction
from django.utils import timezone
from dateutil.relativedelta import relativedelta
from .models import *
@admin.action(description='Tasdiqlash va obunani uzaytirish')
def approve(modeladmin,request,queryset):
    for pk in queryset.values_list('pk',flat=True):
        with transaction.atomic():
            p=PaymentRecord.objects.select_for_update().select_related('plan','store').get(pk=pk)
            if p.status!='pending' or p.provider!='manual':continue
            Store.objects.select_for_update().get(pk=p.store_id)
            sub,_=Subscription.objects.select_for_update().get_or_create(store=p.store)
            now=timezone.now();dates=[x for x in (sub.paid_until,sub.trial_end) if x and x>now];start=max([now,*dates])
            months=12 if p.billing_period=='year' else 1
            sub.paid_until=start+relativedelta(months=months);sub.save()
            if p.subscription_id:
                h=p.subscription;h.status='active';h.starts_at=start;h.ends_at=sub.paid_until
                h.save(update_fields=['status','starts_at','ends_at','updated_at'])
            else:
                p.subscription=SubscriptionHistory.objects.create(
                    store=p.store,plan=p.plan,status='active',billing_period=p.billing_period,
                    starts_at=start,ends_at=sub.paid_until,amount=p.amount,currency=p.currency,created_by=request.user)
            p.status='approved';p.approved_by=request.user;p.approved_at=now;p.save()
            AuditLog.objects.create(actor=request.user,action='payment_approved',target=f'payment:{p.pk}',metadata={'billing_period':p.billing_period,'reason':'Django admin bulk approval; receipt verified'})
@admin.register(PaymentRecord)
class PaymentAdmin(admin.ModelAdmin):
    list_display=['store','amount','status','approved_at']; actions=[approve]
@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display=['timestamp','actor','action','target']
    readonly_fields=['actor','action','target','timestamp','metadata']
    def has_add_permission(self,request):return False
    def has_change_permission(self,request,obj=None):return False
    def has_delete_permission(self,request,obj=None):return False

class AuditedAdmin(admin.ModelAdmin):
    def save_model(self,request,obj,form,change):
        super().save_model(request,obj,form,change)
        AuditLog.objects.create(actor=request.user,action=f'django_admin_{obj._meta.model_name}_saved',target=f'{obj._meta.model_name}:{obj.pk}',metadata={'changed_fields':list(form.changed_data)})
    def has_delete_permission(self,request,obj=None):return False

@admin.register(Store)
class StoreAdmin(AuditedAdmin):
    list_display=['name','owner','is_active','created_at']
    readonly_fields=['is_active']

@admin.register(SubscriptionPlan)
class PlanAdmin(AuditedAdmin):
    list_display=['name','months','price','annual_price','user_limit','product_limit','active']

@admin.register(Subscription)
class SubscriptionAdmin(AuditedAdmin):
    list_display=['store','trial_end','paid_until']

for model in [Category,Product,InventoryMovement,Sale,SaleItem,Credential,SyncOperation]:admin.site.register(model)

@admin.register(SubscriptionHistory)
class SubscriptionHistoryAdmin(admin.ModelAdmin):
    list_display=['store','plan','status','billing_period','starts_at','ends_at','amount']
    readonly_fields=[field.name for field in SubscriptionHistory._meta.fields]
    def has_add_permission(self,request):return False
    def has_change_permission(self,request,obj=None):return False
    def has_delete_permission(self,request,obj=None):return False
