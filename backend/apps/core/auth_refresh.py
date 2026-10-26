"""Convert a deleted refresh-token owner into a normal authentication failure."""

from django.contrib.auth import get_user_model
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.serializers import TokenRefreshSerializer
from rest_framework_simplejwt.settings import api_settings
from rest_framework_simplejwt.utils import get_md5_hash_password
from rest_framework_simplejwt.views import TokenRefreshView as JWTTokenRefreshView


class SafeTokenRefreshSerializer(TokenRefreshSerializer):
    def validate(self, attrs):
        try:
            # Validate signature/expiry/blacklist before trusting any claims.
            refresh = self.token_class(attrs['refresh'])
            user_id = refresh.payload.get(api_settings.USER_ID_CLAIM)
            if user_id is None:
                raise AuthenticationFailed(
                    'Sessiya yaroqsiz. Qayta kiring.', code='no_active_account',
                )
            try:
                user = get_user_model().objects.get(
                    **{api_settings.USER_ID_FIELD: user_id},
                )
            except (ValueError, TypeError) as exc:
                raise AuthenticationFailed(
                    'Sessiya yaroqsiz. Qayta kiring.', code='no_active_account',
                ) from exc
            if not api_settings.USER_AUTHENTICATION_RULE(user):
                raise AuthenticationFailed(
                    'Sessiya yaroqsiz. Qayta kiring.', code='no_active_account',
                )
            # SimpleJWT 5.5.1 checks this for access authentication but not refresh.
            # Honor the application's existing CHECK_REVOKE_TOKEN configuration.
            if api_settings.CHECK_REVOKE_TOKEN and (
                refresh.payload.get(api_settings.REVOKE_TOKEN_CLAIM)
                != get_md5_hash_password(user.password)
            ):
                raise AuthenticationFailed(
                    'Parol o‘zgartirilgan. Qayta kiring.', code='password_changed',
                )
            # Preserve upstream rotation and blacklist writes.
            return super().validate(attrs)
        except get_user_model().DoesNotExist as exc:
            # Some SimpleJWT 5.5 releases let this exception escape as HTTP 500.
            raise AuthenticationFailed(
                'Sessiya yaroqsiz. Login va parol bilan qayta kiring.',
                code='no_active_account',
            ) from exc


class SafeTokenRefreshView(JWTTokenRefreshView):
    serializer_class = SafeTokenRefreshSerializer
    throttle_scope = 'auth'
