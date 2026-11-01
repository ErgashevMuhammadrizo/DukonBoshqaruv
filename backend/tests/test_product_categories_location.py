from django.test import TestCase
from rest_framework.test import APIClient
from tests import test_services as fixtures
from apps.core.models import Category, User, Store, Product

class CategoryLocationTests(TestCase):
    setUp = fixtures.ProductAndReportTests.setUp

    def test_create_and_read_location_and_category(self):
        category=self.client.post('/api/v1/categories/', {'name':'  Elektronika  '}, format='json')
        self.assertEqual(category.status_code,201)
        result=self.client.post('/api/v1/products/', {'name':'Quloqchin','sku':'LOC-1','sale_price':'10000',
            'category':category.data['id'],'warehouse':'Asosiy ombor','section':'B bo‘lim','shelf':'3-qator, 2-polka'},format='json')
        self.assertEqual(result.status_code,201,result.data)
        self.assertEqual(result.data['category_name'],'Elektronika')
        self.assertEqual(result.data['shelf'],'3-qator, 2-polka')
        saved=Product.objects.get(pk=result.data['id'])
        self.assertEqual(saved.warehouse,'Asosiy ombor')
        sync=self.client.get('/api/v1/sync/pull/').data['products']
        row=next(p for p in sync if p['id']==saved.pk)
        self.assertEqual(row['category_name'],'Elektronika');self.assertEqual(row['section'],'B bo‘lim')

    def test_duplicate_category_rejected_case_insensitively(self):
        self.assertEqual(self.client.post('/api/v1/categories/', {'name':'Kiyimlar'},format='json').status_code,201)
        self.assertEqual(self.client.post('/api/v1/categories/', {'name':'  kiyimlar  '},format='json').status_code,400)
        self.assertEqual(Category.objects.filter(store=self.store).count(),1)

    def test_empty_category_rejected(self):
        self.assertEqual(self.client.post('/api/v1/categories/', {'name':'  '},format='json').status_code,400)

    def test_other_store_category_not_visible_or_assignable(self):
        user=User.objects.create_user(username='location-other')
        other=Store.objects.create(owner=user,name='Other')
        category=Category.objects.create(store=other,name='Private category')
        self.assertEqual(self.client.get(f'/api/v1/categories/{category.pk}/').status_code,404)
        result=self.client.patch(f'/api/v1/products/{self.product.pk}/', {'category':category.pk},format='json')
        self.assertEqual(result.status_code,400)
        self.assertNotIn('Private category',str(result.data))

    def test_location_can_be_changed_cleared_and_is_length_limited(self):
        url=f'/api/v1/products/{self.product.pk}/'
        self.assertEqual(self.client.patch(url, {'warehouse':'W1','section':'S2','shelf':'P3'},format='json').status_code,200)
        result=self.client.patch(url, {'shelf':''},format='json')
        self.assertEqual(result.data['shelf'],'');self.assertEqual(result.data['warehouse'],'W1')
        self.assertEqual(self.client.patch(url, {'warehouse':'x'*101},format='json').status_code,400)
        self.product.refresh_from_db();self.assertEqual(self.product.warehouse,'W1')

    def test_category_can_be_cleared_without_removing_location(self):
        category=Category.objects.create(store=self.store,name='Tools')
        url=f'/api/v1/products/{self.product.pk}/'
        self.client.patch(url, {'category':category.pk,'shelf':'A1'},format='json')
        result=self.client.patch(url, {'category':None},format='json')
        self.assertEqual(result.status_code,200);self.assertIsNone(result.data['category'])
        self.assertEqual(result.data['shelf'],'A1')

    def test_categories_are_isolated_between_stores(self):
        own=Category.objects.create(store=self.store,name='Bir xil nom')
        user=User.objects.create_user(username='category-other')
        other=Store.objects.create(owner=user,name='Other')
        client=APIClient();client.force_authenticate(user)
        result=client.post('/api/v1/categories/', {'name':own.name},format='json')
        self.assertEqual(result.status_code,201)
        self.assertEqual([c['id'] for c in self.client.get('/api/v1/categories/').data],[own.pk])
