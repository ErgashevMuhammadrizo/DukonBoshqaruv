from django.core.management.base import BaseCommand

from apps.core.bootstrap import ensure_demo_user


class Command(BaseCommand):
    help = 'Create the explicitly configured local development demo account.'

    def handle(self, *args, **options):
        user = ensure_demo_user()
        self.stdout.write(self.style.SUCCESS(f'Demo account {user.username!r} is ready.'))
