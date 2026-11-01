import os
from django.core.management.base import BaseCommand, CommandError
from apps.core.inpay import secret_key, request_api, ProviderError
class Command(BaseCommand):
    help = 'inPAY v2 konfiguratsiyasi; --probe faqat balans endpointini o‘qiydi, to‘lov yaratmaydi.'
    def add_arguments(self, parser):
        parser.add_argument('--probe', action='store_true')
    def handle(self, *args, **options):
        try:
            key = secret_key()
            for name in ['INPAY_WEBHOOK_URL', 'INPAY_RETURN_URL', 'INPAY_WEBHOOK_SECRET']:
                if not os.getenv(name): raise CommandError(name + ' kiritilmagan')
            self.stdout.write('API v2; rejim: ' + ('LIVE' if key.startswith('sk_live_') else 'TEST'))
            self.stdout.write('Secret qiymatlari yashirilgan. INPAY_ENABLED=' + os.getenv('INPAY_ENABLED','0'))
            if options['probe']:
                request_api('balance/')
                self.stdout.write(self.style.SUCCESS('inPAY autentifikatsiyasi muvaffaqiyatli.'))
        except ProviderError as exc:
            raise CommandError(str(exc) + ' code=' + exc.code + ' request_id=' + exc.request_id)
