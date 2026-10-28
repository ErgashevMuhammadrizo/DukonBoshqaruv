from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch
from django.test import SimpleTestCase, override_settings
from website import views

@override_settings(ALLOWED_HOSTS=['testserver', 'localhost'], DEBUG=False)
class PublicWebsiteTests(SimpleTestCase):
    def test_both_pages_are_public(self):
        for url in ['/', '/download/']:
            response = self.client.get(url)
            self.assertEqual(response.status_code, 200)
            self.assertNotIn('csrfmiddlewaretoken', response.content.decode())
            self.assertContains(response, 'name="description"')
            self.assertContains(response, 'property="og:image"')
            self.assertContains(response, 'lang="uz"')

    def test_home_sections_and_illustration_disclosure(self):
        response = self.client.get('/')
        for section in ['imkoniyatlar', 'biz-haqimizda', 'boglanish', 'savollar', 'interfeys']:
            self.assertContains(response, f'id="{section}"')
        self.assertContains(response, 'Haqiqiy screenshot emas')
        self.assertContains(response, 'href="/download/"', count=4)
        self.assertNotContains(response, 'href="#tariflar"')

    def test_missing_apk_does_not_offer_false_metadata(self):
        with TemporaryDirectory() as d, patch.object(views, 'APK_PATH', Path(d) / 'dokon-boshqaruv.apk'):
            for method in [self.client.get, self.client.head]:
                response = method('/downloads/dokon-boshqaruv.apk')
                self.assertEqual(response.status_code, 404)
            response = self.client.get('/downloads/dokon-boshqaruv.apk')
            self.assertEqual(response.json()['message'], views.MISSING_APK)
            page = self.client.get('/download/')
            self.assertContains(page, 'id="apk-size" hidden')
            self.assertContains(page, 'id="apk-version" hidden')

    def test_apk_available_get_and_head(self):
        # Synthetic ZIP header fixture, not an installable or advertised APK.
        payload = b'PK\x03\x04' + b'test-only-apk-route-fixture'
        with TemporaryDirectory() as d:
            apk = Path(d) / 'dokon-boshqaruv.apk'
            apk.write_bytes(payload)
            with patch.object(views, 'APK_PATH', apk):
                response = self.client.get('/downloads/dokon-boshqaruv.apk')
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response['Content-Type'], 'application/vnd.android.package-archive')
                self.assertIn('attachment', response['Content-Disposition'])
                self.assertIn('dokon-boshqaruv.apk', response['Content-Disposition'])
                self.assertEqual(b''.join(response.streaming_content), payload)
                response.close()
                head = self.client.head('/downloads/dokon-boshqaruv.apk')
                self.assertEqual(head.status_code, 200)
                self.assertEqual(int(head['Content-Length']), len(payload))
                head.close()

    def test_wrong_file_is_not_served_as_apk(self):
        with TemporaryDirectory() as d:
            apk = Path(d) / 'dokon-boshqaruv.apk'
            apk.write_text('<html>not an APK</html>')
            with patch.object(views, 'APK_PATH', apk):
                self.assertEqual(self.client.get('/downloads/dokon-boshqaruv.apk').status_code, 404)

    def test_public_static_resources_in_production(self):
        for name in ['site.css', 'site.js', 'download.js', 'logo.svg', 'icons.svg', 'fonts/Inter.woff2', 'og.png']:
            response = self.client.get('/static/site/' + name)
            self.assertEqual(response.status_code, 200, name)
            response.close()

    def test_static_traversal_is_rejected(self):
        self.assertIn(self.client.get('/static/site/../../site_config.json').status_code, (400, 404))

    def test_unknown_page_and_wrong_methods(self):
        response = self.client.get('/not-a-page/')
        self.assertEqual(response.status_code, 404)
        self.assertContains(response, 'Sahifa topilmadi', status_code=404)
        for url in ['/', '/download/', '/downloads/dokon-boshqaruv.apk']:
            self.assertEqual(self.client.post(url).status_code, 405)

    def test_config_rejects_unsafe_contact_and_download_urls(self):
        with TemporaryDirectory() as d:
            root = Path(d)
            (root / 'site_config.json').write_text('{"download_url":"javascript:alert(1)","telegram_url":"https://fake.invalid/a","email":"bad", "phone":"not a phone"}')
            with patch.object(views, 'ROOT', root):
                config = views.configuration()
            self.assertEqual(config['download_url'], '/downloads/dokon-boshqaruv.apk')
            self.assertFalse(config['has_contacts'])
