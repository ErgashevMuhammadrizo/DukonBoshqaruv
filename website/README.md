# Dokon Boshqaruv — public website

Ikki ochiq sahifa: `/` va `/download/`. Mavjud Django texnologiyasi saqlandi. Sayt login, ma’lumotlar bazasi yoki API ulanishisiz ishlaydi. Flutter ilovasi o‘zgartirilmaydi.

## Lokal ishga tushirish

ZIP ichidagi `website` papkasining yonida terminal oching:

```bash
python3 -m venv .venv
.venv/bin/pip install -r website/requirements.txt
.venv/bin/python website/manage.py runserver
```

Brauzer: http://127.0.0.1:8000/ . Frontend build shart emas.

## Tuzilishi va tahrirlash

- `templates/index.html`: bosh sahifa matnlari va bo‘limlar.
- `templates/download.html`: yuklab olish sahifasi.
- `templates/base.html`: navigatsiya, footer, SEO.
- `static/site/site.css`: ranglar, shrift, responsive dizayn; ranglar CSS o‘zgaruvchilarida.
- `static/site/site.js`, `download.js`: menyu, animatsiya va APK tekshiruvi.
- `site_config.json`: haqiqiy Telegram, telefon, email, APK URL va ma’lum versiya.
- `public/downloads/`: signed APK joyi; batafsil `APK_JOYLASHTIRISH.md`.
- `integration/`: mavjud backend bilan birlashtirish uchun namunalar.

Kontaktlar hali berilmagan: konfiguratsiyada bo‘sh. Soxta kontakt, obunachilar soni yoki sharhlar qo‘shilmagan. Telefon tasvirlari HTML/CSS orqali tayyorlangan namunaviy interfeys, haqiqiy screenshot emas. Offline imkoniyatlari cheklovlari matnda ko‘rsatilgan.

## Tekshirish

ZIP papkasining tashqarisidan:

```bash
.venv/bin/python website/manage.py test website.tests
cd website
npm run check
npm test
```

Node faqat frontend testlari uchun kerak; production uchun kerak emas. Python testlari haqiqiy APK emas, vaqtinchalik fayl bilan download endpointini tekshiradi.

## Railway: alohida website xizmati

Repo ichida `website/` papkasini saqlang. Railway yangi servisining Root Directory qiymati `website`, builder Dockerfile bo‘lsin. `Dockerfile` PORT muhit o‘zgaruvchisini ishlatadi. `RAILWAY_PUBLIC_DOMAIN` avtomatik ruxsat etiladi; boshqa domenlar uchun `ALLOWED_HOSTS=example.uz,www.example.uz` belgilang. `DEBUG=0`. Migratsiya yoki DB kerak emas. `.env.example` namuna, real sirlarni Gitga yozmang.

APKni image ichiga qo‘shish yoki `/app/website/public/downloads` ga persistent volume ulash mumkin. Volume ulangan bo‘lsa, signed APKni shu volumega joylang.

## Mavjud backend bilan bir domen

Faqat URL faylini almashtirish yetmaydi: website papkasi ham image ichida bo‘lishi shart. Quyidagini shu loyihaning nusxasida bajaring:

1. ZIPdagi `website/` ni mavjud `backend/` yoniga joylang.
2. `integration/backend/config/urls.py` namunasi yuborilgan backend URL fayliga mos: faqat root route website.urls ga uzatilgan va website package yo‘li qo‘shilgan. Backendga keyin boshqa URL qo‘shgan bo‘lsangiz, butun faylni ko‘r-ko‘rona almashtirmang; shu ikki o‘zgarishni ko‘chiring.
3. Repo rootidan build uchun `website/integration/Dockerfile` ni root `Dockerfile` sifatida qo‘ying. `integration/project-root.dockerignore` ni root `.dockerignore` sifatida qo‘llang.
4. Railway build context repo root bo‘lsin. Mavjud PostgreSQL, env va `/app/media` volumeni saqlang. Ushbu image backendni `/app`, website ni `/website` da saqlaydi.
5. Backendning amaldagi settings faylida `WEBSITE_ROOT` va template DIRS sozlamalari kerak (yuborilgan loyihada mavjud). APK volume kerak bo‘lsa `/website/public/downloads` ga ulang.

API, admin, auth va health yo‘llari namunada saqlangan. Productionga deploy bu ZIPni tayyorlash vaqtida bajarilmagan. ZIP butun backend yoki Flutter o‘rniga yozilmaydi.

## Qamrov

Ikki marketing sahifasidan tashqari faqat static assetlar, APK endpointi va 404 fallback bor. Tarif sotib olish yoki yangi mobil funksiyalar ushbu website paketining vazifasi emas. `static/css/site.css` eski loyihadan qolgan, yangi sahifalar `static/site/site.css` ni ishlatadi. `tools/export_preview.py` faqat lokal dizayn tekshiruvi uchun; `dist/` production uchun kerak emas.
