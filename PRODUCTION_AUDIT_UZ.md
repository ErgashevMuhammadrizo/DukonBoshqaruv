# VEXO — localization va production audit, 2026-10-29

Versiya: **0.2.2+5**. Bu audit oxirgi `VEXO_updated_project.zip` asosida bajarildi. Oldingi mahsulot o‘chirish, savdo tarixi, offline navbat, tenant isolation, kamera kodi va papka tuzilishi saqlandi. Avvalgi `VEXO_HISOBOT.md` va `verification/` eski reliz dalillari; joriy natijalar `audit_verification/2026-10-29/` da.

## 1. Asl sabablar va tuzatishlar

### Rus tilida API ulanishi

`api.dart` HTTP header nomini `tr('m40')` orqali yozgan. O‘zbekcha qiymat `Authorization`, ruscha qiymat `Авторизация` edi. Bu texnik header tarjima qilinmasligi kerak: ruscha nom standart Authorization header bo‘lmaydi, HTTP client tomonidan ham noqonuniy header nomi sifatida rad etilishi mumkin. Natijada JWT bor bo‘lsa ham avtorizatsiya ishlamasdi.

Header endi o‘zgarmas `Authorization` konstantasi. Login/refresh yo‘llarida bu header olib tashlanadi; qolgan so‘rovlarda `Bearer` token qo‘yiladi. Endpointlar, JSON kalitlari va token storage kalitlari tarjimaga bog‘lanmagan. Locale va theme o‘zgarishi API client, queue egasi, token, cart yoki startup Future’ni almashtirmaydi.

### Refresh va xatolikni noto‘g‘ri ko‘rsatish

- Refresh 403/429/5xx bilan tugaganda eski 401 qaytarilib, haqiqiy sabab yo‘qolardi. Hozir haqiqiy status saqlanadi. Faqat invalid refresh 401 bo‘lsa sessiya bekor qilinadi.
- Timeout, internet/connection xatosi, TLS sertifikati, cancel, 401, 403 va 5xx alohida lokalizatsiyalangan xabar beradi.
- Kechikkan eski access-token 401 javobi uchun allaqachon yangilangan token ishlatiladi; qayta-qayta refresh qilinmaydi. Asl so‘rov bir marta qayta yuboriladi.
- Logoutdan keyin kelgan refresh javobi eski sessiyani qayta tiklamaydi. Session generation eski so‘rovning yangi akkaunt tokeni bilan qayta yuborilishiga to‘sqinlik qiladi.
- Takroriy invalid refresh faqat bitta logout hodisasini chiqaradi. Logoutdan so‘ng oldingi ekranlar rebuild bo‘lsa, ular cheksiz refresh tarmoq siklini boshlamaydi.
- Startup vaqtida 5xx yoki boshqa vaqtinchalik nosozlik tokenlarni o‘chirmaydi va foydalanuvchini avtomatik Login’ga tushirmaydi: xato, qayta urinish va ongli qayta kirish yo‘li bor. Haqiqiy yaroqsiz refresh Login’ga qaytaradi.
- Rasm yuborishdagi multipart body birinchi so‘rovda finalized bo‘ladi; 401 dan keyingi retry uchun FormData klonlanadi.
- Developer diagnostikasida faqat method/status/error kind yoziladi. Header, token, parol, query yoki API body logga qo‘shilmaydi. Asl Dio xatosi saqlanadi.

### Hisobot kun/hafta tugmalari

Oldingi komponent oq selected fon, oq unselected matn, shaffof fon va Material 3 selection animatsiyasini aralashtirgan. Selected holati o‘zgarganda matn darhol boshqa rangga o‘tadi, fon esa oraliq animatsiyadan o‘tadi: oq matn oq fonga yoki ko‘k matn ko‘k fonga to‘g‘ri kelishi mumkin edi. Faqat yakuniy holatni ko‘rgan test bu o‘tishdagi muammoni ushlamasdi. Holatlarga ajratilgan aniq rang siyosati ham yo‘q edi.

Yangi `ReportPeriodChip` opaque ColorScheme ranglaridan foydalanadi. Selected, unselected, disabled, pressed/hovered/focused uchun o‘qiladigan juftliklar tekshirilgan, surface tint va elevation aralashuvi olib tashlangan. Selection rang animatsiyasi o‘chirilgan: matn va fon bir kadrda mos almashadi. Checkmark va selected semantikasi saqlangan. Uzun ruscha matnlar uchun horizontal scroll va yetarli bosish maydoni bor.

Yana bir state bug: tanlangan period ekran ichida saqlanardi, range esa providerda qolardi. Ekranga qaytilganda oy belgisi bilan eski kun/hafta ma’lumoti mos kelmasligi mumkin edi. Endi period ham providerda saqlanadi. Locale/theme almashishi yoki ekranga qaytish tanlovni buzmaydi. Range-dependent providerlar keraksiz qo‘shimcha invalidate qilinmaydi.

Hisobot xato oynasi oldin real xabarni tashlab, umumiy ulanish xabarini ko‘rsatardi. Endi lokalizatsiyalangan real xato turi ko‘rsatiladi.

### `No module named website`

Website — backendning yonidagi alohida Django package. Oldingi URL fayli uni majburiy import qilgan, `backend/Dockerfile` esa faqat backend papkasini imagega olgan. Shuning uchun backend-only Railway build’da package mavjud emasdi.

Endi ikki aniq rejim bor:

- **API-only — default:** `SERVE_WEBSITE=0`. Backend website’siz ham ishga tushadi. `/` VEXO API haqida kichik JSON beradi; barcha API/admin/auth/sync/schema/docs va health yo‘llari saqlangan.
- **Integrated:** `SERVE_WEBSITE=1`, `WEBSITE_ROOT=/website`; repository-root build context bilan `website/integration/Dockerfile` ishlatiladi. Bu Dockerfile website’ni ham imagega oladi va rejimni yoqadi. `/` hamda `/download/` saqlanadi.

Agar integrated rejim ongli yoqilgan, lekin website image ichida yo‘q bo‘lsa, aniq konfiguratsiya xatosi chiqadi. Bor package ichidagi boshqa import buglari yashirilmaydi. Routing nusxalari bir xil ekanligi testda tekshirildi. Website mustaqil servis sifatida o‘z `website/Dockerfile`i bilan ham ishlaydi.

### Boshqa topilgan muammolar

- Akkaunt almashganda cart, daftar va hisobot cache’lari qayta ishlatilmasligi uchun sessiya koordinatori qo‘shildi. Bu tozalash locale almashganda ishlamaydi. API providerning o‘z Ref’idan uning dependantlarini invalidatsiya qilish o‘rniga alohida coordinator ishlatiladi.
- Daftar query key’i `|` bilan ajratilardi; mijoz qidiruvi shu belgini o‘z ichiga olsa, boshqa filtrlar buzilardi. Endi JSON array key; unused query providerlar autoDispose.
- O‘lchov birliklari ruscha/inglizcha ko‘rinishda tarjima qilinadi. API’dagi `dona`, `kg`, `quti` va boshqa identifikatorlar o‘zgarmaydi. Foydalanuvchi yozgan mahsulot/mijoz/tarif nomlari majburan tarjima qilinmaydi.
- Compose build context rootga qaragan, backend Dockerfile esa requirements.txt’ni context ildizidan kutgan. Contextlar `./backend` ga moslandi. Compose PG* o‘zgaruvchilari Django bilan mos; standart DB paroli olib tashlandi.
- `backend/.dockerignore` real .env, DB, media va signing keylarni imagega ko‘chirmaydi.
- Backend .env namunasi POSTGRES_* deb yozilgan, sozlamalar esa PG* o‘qirdi. Namuna to‘g‘rilandi; haqiqiy env qiymatlariga tegilmadi.
- Productionda DB_ENGINE ko‘rsatilmasa, jim yangi SQLite bazasi ochilmaydi: aniq tanlov talab qilinadi. Mavjud bazani avtomatik postgresga o‘tkazish yoki joyini almashtirish yo‘q. Ixtiyoriy SQLITE_PATH persistent volume uchun qo‘shilgan, default eski yo‘l saqlangan.
- Railway uchun PostgreSQL TLS default `require` saqlandi. Lokal Compose PostgreSQL’da TLS sertifikati yo‘q, shu sabab local debug muhitda `prefer` tanlanadi. Production DEBUG=0 holatida `prefer`/`disable` rad etiladi; TLS talab qilinadi.
- PostgreSQL backup buyrug‘i pg_dump ishlatadi, lekin image’da u yo‘q edi. Ikkala backend image Dockerfile’iga postgresql-client o‘rnatish qo‘shildi. Haqiqiy pg_dump bu muhitda ishga tushirilmagan.

## 2. Haqiqiy tekshiruvlar

| Tekshiruv | Natija |
|---|---|
| Flutter test deklaratsiyalari, rasmiy flutter_tester headless engine | **88 passed, 0 failed** |
| Django backend testlari | **71 ta o‘tdi** |
| Mustaqil website testlari | **9 ta o‘tdi** |
| `dart analyze lib test` | No issues found |
| `dart format --output=none --set-exit-if-changed lib test` | 56 fayl, 0 o‘zgarish |
| Django check | 0 issue |
| Migratsiya mosligi, SQLite :memory: | No changes detected |
| Tarjima kalitlari | 650 literal UI key uz/ru/en’da bor va bo‘sh emas |
| Compose | YAML va build context/PG sozlamalari strukturaviy tekshirildi |
| `flutter analyze` | CLI boshlanishida to‘xtadi: Flutter katalogi to‘liq Git clone emas |
| Release APK | Xuddi shu SDK cheklovi sabab yaratilmagan |

Flutter testlari yangi regression testlari bilan birga oldingi login, profil, cart, mahsulot o‘chirish/cache, offline sync, sales history va tenant testlarini ham qamraydi. 320 px va kattalashtirilgan matn, uz/ru/en hamda light/dark holatlar sinovdan o‘tdi. Rang testlari resolved palette’da kamida 4.5:1 kontrast va birinchi kadrni tekshiradi; fizik telefondagi pixel/golden yoki native kamera sinovi deb hisoblamang.

Backend-only build website papkasisiz alohida vaqtinchalik nusxada tekshirildi. Integrated build tuzilishi ham alohida nusxada Django check va ikki sahifa GET bilan sinaldi. PostgreSQL konfiguratsiya guardlari subprocess orqali sinovdan o‘tdi, haqiqiy PG serverga ulanilmadi. Django ma’lumot testlari alohida SQLite test bazasida ishladi. Production bazaga test uchun DELETE yoki boshqa o‘zgartirish yuborilmadi. Yangi migratsiya yaratilmadi; eski 0001–0009 fayllari saqlandi.

Joriy xom loglar: `audit_verification/2026-10-29/`. Eski relizning loglari o‘chirilmagan.

## 3. Railway qayta deploy

**Backendni qayta deploy qilish kerak. Yangi APK ham kerak.** Bu ishda production deploy bajarilmadi, Railway maxfiy sozlamalari o‘qilmadi/o‘zgartirilmadi.

### A. Backend alohida servis bo‘lsa

- Railway Root Directory: `backend`.
- Builder: shu papkadagi Dockerfile.
- `SERVE_WEBSITE=0`.
- Mavjud PostgreSQL, media va backup volumelarini saqlang.
- `DEBUG=0`, `APP_ENV=production`, kuchli DJANGO_SECRET_KEY, aniq ALLOWED_HOSTS va `SECURE_SSL_REDIRECT=1` kerak.
- **DB_ENGINE amaldagi bazaga mos aniq ko‘rsatilishi shart. Uni taxmin bilan o‘zgartirmang.** PostgreSQL uchun PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD va odatda PGSSLMODE=require. Namuna .env’ni haqiqiy env ustiga ko‘chirmang.
- Agar ongli ravishda SQLite ishlatsangiz, amaldagi bazani saqlang; yangi bo‘sh bazaga yo‘naltirmang. Persistent volume va SQLITE_PATH yo‘lini o‘zingizdagi bazaga mos tekshiring.
- Docker CMD migratsiya va gunicornni ishga tushiradi. Custom Start Command bor bo‘lsa:

```bash
python manage.py migrate && exec gunicorn config.wsgi:application --bind 0.0.0.0:${PORT:-8000} --access-logfile - --error-logfile -
```

### B. Backend va website bir servis bo‘lsa

Build context repo ildizi bo‘lsin; Dockerfile path `website/integration/Dockerfile`. `SERVE_WEBSITE=1`, `WEBSITE_ROOT=/website`. Dockerfile ikkala package’ni qo‘shadi. Oldingi root Dockerfile nusxasidan foydalansangiz ham shu flaglar va COPY website qatori zarur. Faqat `urls.py`ni eski backendga ko‘chirish yetmaydi — yangi `config/public_website.py` va settings ham birga yangilanadi.

Standalone website servisi Root Directory `website` bilan oldingidek ishlaydi; u backendga majburiy import bilan bog‘lanmaydi.

## 4. API domeni va APK buyrug‘i

Siz bergan manzil: `https://dukonboshqaruv-production.up.railway.app/api/v1/`.
Koddagi avvalgi default: `https://dukonboshqaruvi-production.up.railway.app/api/v1/`.

Ular **bitta harf bilan farq qiladigan ikki alohida host**. Default kodda sababsiz almashtirilmadi va avtomatik fallback qo‘shilmadi. Ikkalasining jonli health holatini bu muhitdan tasdiqlab bo‘lmadi; bu server ishlamayotganini isbotlamaydi. Railway servisidagi haqiqiy Public Domain’ni solishtiring. Agar haqiqatan boshqa backendga o‘tsangiz, eski server refresh tokenining yangi serverda qabul qilinmasligi normal; yangi serverga qayta login kerak bo‘lishi mumkin.

To‘liq Flutter SDK va Android SDK bor o‘z kompyuteringizda, **siz ko‘rsatgan host uchun**:

```bash
cd "$HOME/startup conteyner/DokonBoshqaruv/dokon_boshqaruv"
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define=API_BASE_URL=https://dukonboshqaruv-production.up.railway.app/api/v1/
```

Haqiqiy Public Domain oxirida `...boshqaruvi...` bo‘lsa, yuqoridagi define qiymatini aynan o‘sha tasdiqlangan manzilga almashtiring. APK chiqishi: `build/app/outputs/flutter-apk/app-release.apk`.

Application ID/package nomi, storage kalitlari va imzolash sozlamalari o‘zgarmadi. Gradle’da avvaldan release uchun debug signing ishlatilgan; bu audit yangi production signing key yaratmaydi/almashtirmaydi. Mavjud o‘rnatma ustiga yangilash uchun avvalgi signing key kerak. Offline ma’lumotlarni yo‘qotmaslik uchun ilovani o‘chirib tashlash tavsiya qilinmaydi.

## 5. Hali tashqi yoki qo‘lda tekshiriladigan holatlar

- Yangi APK build va haqiqiy Android telefonda ruscha/o‘zbekcha cold start, locale/theme, kamera, offline savdo va internet tiklangandagi sync.
- Jonli Railway Public Domain, env qiymatlari, yangi deployment health va PostgreSQL/media volume mavjudligi.
- Haqiqiy PostgreSQL concurrency/row-lock va backup/restore; Docker image build va pg_dump server versiyasi mosligi bu muhitda tekshirilmagan.
- `/api/v1/schema/` va `/api/v1/docs/` 200 qaytarishi testlandi. Oldindan mavjud ayrim custom APIView serializer tavsiflari to‘liq emas: drf-spectacular warning/error diagnostikalari logda qolgan. Bu audit barcha OpenAPI request/response modellarini qayta loyihalaganini da’vo qilmaydi.
- Chek printer/PDF integratsiyasi avvaldan yo‘q; oldingi relizdagi o‘chirilgan placeholder tugmalar shu holatda qoldi.

## 6. O‘zgargan/yangi kod va konfiguratsiya fayllari

- `.env.example`
- `backend/.dockerignore`
- `backend/.env.example`
- `backend/Dockerfile`
- `backend/config/public_website.py`
- `backend/config/settings.py`
- `backend/config/urls.py`
- `backend/tests/test_routing_deployment.py`
- `docker-compose.yml`
- `dokon_boshqaruv/lib/features/debts/screens/debts_screen.dart`
- `dokon_boshqaruv/lib/features/pos/screens/sales_history_screen.dart`
- `dokon_boshqaruv/lib/features/pos/widgets/product_grid.dart`
- `dokon_boshqaruv/lib/features/products/providers/products_provider.dart`
- `dokon_boshqaruv/lib/features/products/screens/add_product_screen.dart`
- `dokon_boshqaruv/lib/features/products/screens/edit_product_screen.dart`
- `dokon_boshqaruv/lib/features/products/screens/product_detail_screen.dart`
- `dokon_boshqaruv/lib/features/products/widgets/product_card.dart`
- `dokon_boshqaruv/lib/features/products/widgets/quick_stock_adjustment.dart`
- `dokon_boshqaruv/lib/features/reports/screens/reports_screen.dart`
- `dokon_boshqaruv/lib/features/reports/widgets/report_period_chip.dart`
- `dokon_boshqaruv/lib/src/api.dart`
- `dokon_boshqaruv/lib/src/app.dart`
- `dokon_boshqaruv/lib/src/l10n/app_en.arb`
- `dokon_boshqaruv/lib/src/l10n/app_ru.arb`
- `dokon_boshqaruv/lib/src/l10n/app_uz.arb`
- `dokon_boshqaruv/lib/src/l10n/catalog.dart`
- `dokon_boshqaruv/lib/src/l10n/translations.dart`
- `dokon_boshqaruv/pubspec.yaml`
- `dokon_boshqaruv/test/localization_auth_regression_test.dart`
- `dokon_boshqaruv/test/product_deletion_test.dart`
- `dokon_boshqaruv/test/report_period_regression_test.dart`
- `dokon_boshqaruv/tool/headless_test_runner.dart`
- `website/README.md`
- `website/integration/Dockerfile`
- `website/integration/backend/config/public_website.py`
- `website/integration/backend/config/urls.py`
- `README.md` — joriy audit ko‘rsatmalariga havola.
- `PRODUCTION_AUDIT_UZ.md` — joriy hisobot va deployment yo‘riqnomasi.
- `audit_verification/2026-10-29/` — joriy tekshiruv loglari.
