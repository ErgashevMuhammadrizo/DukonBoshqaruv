from datetime import timedelta
from unittest.mock import patch

from django.core.cache import cache
from django.db import OperationalError
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.core.auth_refresh import SafeTokenRefreshSerializer
from apps.core.models import User


class RefreshTokenRegressionTests(TestCase):
    url = '/api/v1/auth/token/refresh/'

    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='refresh-fixture', password='test-only-password-8174',
        )

    def token(self):
        return RefreshToken.for_user(self.user)

    def test_existing_user_can_refresh_and_rotation_still_works(self):
        token = self.token()
        response = self.client.post(self.url, {'refresh': str(token)}, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)
        self.assertNotEqual(response.data['refresh'], str(token))

    def test_deleted_user_gets_401_instead_of_500(self):
        token = str(self.token())
        self.user.delete()
        response = self.client.post(self.url, {'refresh': token}, format='json')
        self.assertEqual(response.status_code, 401)
        self.assertNotIn('access', response.data)

    def test_inactive_user_cannot_refresh(self):
        token = str(self.token())
        self.user.is_active = False
        self.user.save(update_fields=['is_active'])
        response = self.client.post(self.url, {'refresh': token}, format='json')
        self.assertEqual(response.status_code, 401)

    def test_expired_token_cannot_refresh(self):
        token = self.token()
        token.set_exp(lifetime=timedelta(seconds=-60))
        response = self.client.post(self.url, {'refresh': str(token)}, format='json')
        self.assertEqual(response.status_code, 401)

    def test_blacklisted_token_cannot_refresh(self):
        token = self.token()
        token.blacklist()
        response = self.client.post(self.url, {'refresh': str(token)}, format='json')
        self.assertEqual(response.status_code, 401)

    def test_password_change_revokes_refresh(self):
        token = str(self.token())
        self.user.set_password('changed-test-password-8174')
        self.user.save(update_fields=['password'])
        response = self.client.post(self.url, {'refresh': token}, format='json')
        self.assertEqual(response.status_code, 401)

    def test_malformed_token_cannot_refresh(self):
        response = self.client.post(self.url, {'refresh': 'not-a-token'}, format='json')
        self.assertEqual(response.status_code, 401)

    def test_missing_token_is_a_validation_error(self):
        response = self.client.post(self.url, {}, format='json')
        self.assertEqual(response.status_code, 400)

    def test_rotated_old_token_cannot_be_reused(self):
        token = str(self.token())
        first = self.client.post(self.url, {'refresh': token}, format='json')
        self.assertEqual(first.status_code, 200)
        second = self.client.post(self.url, {'refresh': token}, format='json')
        self.assertEqual(second.status_code, 401)

    def test_unrelated_database_failure_is_not_masked_as_invalid_session(self):
        token = str(self.token())
        with patch('rest_framework_simplejwt.serializers.TokenRefreshSerializer.validate',
                   side_effect=OperationalError('isolated test database failure')):
            with self.assertRaises(OperationalError):
                SafeTokenRefreshSerializer().validate({'refresh': token})

    def test_signed_token_missing_user_id_is_rejected(self):
        token = self.token()
        del token['user_id']
        response = self.client.post(self.url, {'refresh': str(token)}, format='json')
        self.assertEqual(response.status_code, 401)

    def test_signed_token_with_invalid_user_id_is_rejected(self):
        token = self.token()
        token['user_id'] = 'not-an-integer'
        response = self.client.post(self.url, {'refresh': str(token)}, format='json')
        self.assertEqual(response.status_code, 401)
