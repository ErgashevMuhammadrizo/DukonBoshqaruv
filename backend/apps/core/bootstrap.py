from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ImproperlyConfigured
from django.utils import timezone

from .models import Store, Subscription


def ensure_demo_user():
    """Create an explicitly configured development demo account.

    This function is never called during application startup or migrations.
    Existing accounts are deliberately left untouched, including their password.
    """
    if (
        settings.APP_ENV != 'development'
        or not settings.DEBUG
        or not settings.ENABLE_DEMO_BOOTSTRAP
    ):
        raise ImproperlyConfigured(
            'Demo bootstrap requires APP_ENV=development, DEBUG=True, '
            'and ENABLE_DEMO_BOOTSTRAP=True.'
        )

    username = settings.DEMO_USERNAME
    password = settings.DEMO_PASSWORD
    if not username or not password:
        raise ImproperlyConfigured(
            'DEMO_USERNAME and DEMO_PASSWORD are required for demo bootstrap.'
        )

    user_model = get_user_model()
    user = user_model.objects.filter(username=username).first()
    if user is None:
        validate_password(password)
        user = user_model.objects.create_superuser(username=username, password=password)

    store, _ = Store.objects.get_or_create(
        owner=user,
        defaults={'name': 'Demo Market'},
    )
    Subscription.objects.get_or_create(
        store=store,
        defaults={
            'trial_start': timezone.now(),
            'trial_end': timezone.now() + timedelta(days=30),
        },
    )
    return user
