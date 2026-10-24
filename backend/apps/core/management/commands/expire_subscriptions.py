from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone

from apps.core.models import AuditLog, SubscriptionHistory


class Command(BaseCommand):
    help = 'Mark paid subscription history entries expired after their end time.'

    @transaction.atomic
    def handle(self, *args, **options):
        now = timezone.now()
        expired = list(SubscriptionHistory.objects.filter(
            status='active', ends_at__lte=now
        ).values_list('id', 'store_id'))
        if not expired:
            self.stdout.write('No subscriptions to expire.')
            return
        ids = [row[0] for row in expired]
        SubscriptionHistory.objects.filter(pk__in=ids).update(status='expired', updated_at=now)
        AuditLog.objects.bulk_create([
            AuditLog(actor=None, action='subscription_expired', target=f'subscription:{pk}',
                     metadata={'store_id': store_id})
            for pk, store_id in expired
        ])
        self.stdout.write(f'Expired {len(expired)} subscriptions.')
