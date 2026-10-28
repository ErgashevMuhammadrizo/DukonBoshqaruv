from decimal import Decimal
from uuid import uuid4
from django.core.exceptions import ValidationError
from django.test import TestCase
from rest_framework.test import APIClient
from tests import test_services as fixtures
from apps.core.models import Product, InventoryMovement, SaleItem, AuditLog
from apps.core.services import create_sale


class ProductDeletionTests(TestCase):
    setUp = fixtures.ProductAndReportTests.setUp
    # Reuse fixtures only; don't repeat inherited tests in this class.
    def sale(self):
        return create_sale(self.store, {'operation_id':str(uuid4()),
            'items':[{'product_id':self.product.pk,'quantity':'1'}],
            'cash':'2500','card':'0'})[0]

    def test_unused_delete_is_physical_and_missing_delete_is_404(self):
        pk=self.product.pk
        response=self.client.delete(f'/api/v1/products/{pk}/')
        self.assertEqual(response.status_code,204)
        self.assertEqual(response['X-Product-Deletion'],'permanent')
        self.assertFalse(Product.objects.filter(pk=pk).exists())
        self.assertEqual(self.client.delete(f'/api/v1/products/{pk}/').status_code,404)
        self.assertEqual(self.client.delete('/api/v1/products/not-an-id/').status_code,404)

    def test_history_delete_preserves_sale_totals_stock_and_movements(self):
        sale=self.sale()
        item=SaleItem.objects.get(sale=sale)
        before=InventoryMovement.objects.filter(product=self.product).count()
        self.assertEqual(self.client.delete(f'/api/v1/products/{self.product.pk}/').status_code,204)
        sale.refresh_from_db(); item.refresh_from_db(); self.product.refresh_from_db()
        self.assertEqual(sale.total,Decimal('2500'))
        self.assertEqual(item.product_id,self.product.pk)
        self.assertEqual(self.product.stock,Decimal('2'))
        self.assertEqual(InventoryMovement.objects.filter(product=self.product).count(),before)
        self.assertIsNotNone(self.product.deleted_at)
        self.assertEqual(AuditLog.objects.filter(action='product_deleted').count(),1)
        self.assertEqual(self.client.delete(f'/api/v1/products/{self.product.pk}/').status_code,404)

    def test_deleted_product_absent_from_catalog_search_inventory_and_sync(self):
        self.sale()
        self.client.delete(f'/api/v1/products/{self.product.pk}/')
        self.assertEqual(self.client.get('/api/v1/products/').data,[])
        self.assertEqual(self.client.get('/api/v1/products/',{'q':self.product.barcode}).data,[])
        self.assertEqual(self.client.get('/api/v1/sync/pull/').data['products'],[])
        self.assertEqual(self.client.get(f'/api/v1/products/{self.product.pk}/').status_code,404)
        self.assertEqual(self.client.patch(f'/api/v1/products/{self.product.pk}/',{'active':True},format='json').status_code,404)

    def test_replayed_old_sale_is_idempotent_and_new_sale_cannot_restore_product(self):
        payload={'operation_id':str(uuid4()),'items':[{'product_id':self.product.pk,'quantity':'1'}],'cash':'2500','card':'0'}
        sale,_=create_sale(self.store,payload)
        self.client.delete(f'/api/v1/products/{self.product.pk}/')
        same,created=create_sale(self.store,payload)
        self.assertEqual(same.pk,sale.pk); self.assertFalse(created)
        payload['operation_id']=str(uuid4())
        with self.assertRaises(ValidationError): create_sale(self.store,payload)
        self.product.refresh_from_db(); self.assertFalse(self.product.active)

    def test_initial_stock_history_also_uses_safe_delete(self):
        response=self.client.post('/api/v1/products/',{'name':'Stocked','sku':'STOCKED',
            'sale_price':'10','initial_stock':'3','unit':'dona'},format='json')
        self.assertEqual(response.status_code,201)
        pk=response.data['id']
        self.assertEqual(self.client.delete(f'/api/v1/products/{pk}/').status_code,204)
        self.assertTrue(InventoryMovement.objects.filter(product_id=pk).exists())
        self.assertFalse(Product.objects.get(pk=pk).active)

    def test_anonymous_and_blocked_store_cannot_delete(self):
        anonymous=APIClient()
        self.assertEqual(anonymous.delete(f'/api/v1/products/{self.product.pk}/').status_code,401)
        self.store.is_active=False; self.store.save(update_fields=['is_active'])
        self.assertEqual(self.client.delete(f'/api/v1/products/{self.product.pk}/').status_code,403)
        self.assertTrue(Product.objects.filter(pk=self.product.pk).exists())

    def test_archived_product_absent_from_catalog_and_sync(self):
        self.assertEqual(self.client.post(f'/api/v1/products/{self.product.pk}/archive/').status_code,200)
        self.assertEqual(self.client.get('/api/v1/products/').data,[])
        self.assertEqual(self.client.get('/api/v1/sync/pull/').data['products'],[])

    def test_inventory_history_filter_is_product_and_store_scoped(self):
        self.sale()
        response=self.client.get('/api/v1/inventory/movements/',{'product_id':self.product.pk})
        self.assertEqual(response.status_code,200)
        self.assertTrue(response.data)
        self.assertTrue(all(row['product_id']==self.product.pk for row in response.data))
        self.assertEqual(self.client.get('/api/v1/inventory/movements/',{'product_id':'bad'}).status_code,400)
        self.assertEqual(self.client.get('/api/v1/inventory/movements/',{'product_id':999999}).data,[])
