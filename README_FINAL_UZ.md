# Dokon Boshqaruv 0.2.0+3

Yangi nusxada oq/ko‘k/qora dizayn, Inter shrifti (OFL litsenziya bilan), saqlanadigan mavzu va til sozlamalari, o‘zbek/rus/ingliz matnlari bor. Ichki papkalar va API manzillari saqlangan.

## Ilovada

- Profil → **Ilova mavzusi**: tizimga mos, yorug‘, qorong‘i. Tanlov qayta ochilganda tiklanadi.
- Profil → **Til**: O‘zbekcha / Русский / English. Qayta login talab qilinmaydi. Mahsulot nomlari va foydalanuvchi ma’lumotlari o‘zgarmaydi.
- Skaner markazida moslashuvchan kvadrat ramka bor. Kamera ishlashini boshqaruvchi navbat va bir martalik natija qaytarish mantig‘i saqlangan. Ruxsat rad etilganda sozlamalarga o‘tish va qayta urinish ko‘rsatiladi. Kechikkan ishga tushirish cheksiz spinner o‘rniga xabar ko‘rsatadi.
- Qizil bilan belgilangan sinxronlash paneli va eski diagnostika oynasi olib tashlangan. Avtomatik sinxronlash va menyudagi qo‘lda sinxronlash ishlashi saqlangan.
- Savatdagi −/+ shu mahsulot qatorini yangilaydi. Nolga tushgan qator olib tashlanadi. Ombordagidan ortiq miqdor qo‘shilmaydi. Miqdor mingdan bir birlikka, pul hisoblari tiyin birliklariga normallashtiriladi; yakuniy qiymatlar mavjud sotuv API’ga uzatiladi.
- Tarif tugmalari haqiqiy **qo‘lda tasdiqlanadigan to‘lov arizasini** yaratadi. Karta avtomatik yechilmaydi. To‘lov rekvizitlarini administrator bilan kelishish, keyin uning tasdiqlashi kerak. Narxni server belgilaydi; kutilayotgan bir xil ariza takrorlanmaydi.

## Flutter

Tekshiruvlar Flutter 3.44.6 manbalari / rasmiy test engine va Dart 3.12.2 bilan bajarilgan. `pubspec.lock` minimum Flutter 3.44.0 / Dart 3.12.0 talab qiladi.

```bash
cd dokon_boshqaruv
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define=API_BASE_URL=https://dukonboshqaruvi-production.up.railway.app/api/v1/
```

Natija: `build/app/outputs/flutter-apk/app-release.apk`. Telefonga bir xil signing kaliti bilan ustidan yangilang; saqlangan sotuvlar bor paytda ilova ma’lumotlarini tozalamang.

## Backend — mahalliy tekshiruv

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Namuna `.env.example`dan shaxsiy `.env` yarating; u arxivga kiritilmaydi. Mahalliy ishlab chiqish uchun konfiguratsiyani to‘ldirgach:

```bash
python manage.py check
python manage.py makemigrations --check --dry-run
python manage.py test
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

Production bazasini almashtirish yoki tozalash talab qilinmaydi. Ushbu yangilanish uchun yangi migratsiya yo‘q. Railway’dagi amaldagi sirli environment o‘zgaruvchilarini saqlang.

## Media va Railway

Rasm yo‘li production’da ham mavjud. Fayl serverda qolishi uchun doimiy storage kerak: mavjud `backend/Dockerfile` /app’dan ishlaydi, shuning uchun media uchun volume mount nuqtasi `/app/media`. Mavjud rasmlarni ko‘chirishdan oldin zaxiralang. Ushbu ish davomida Railway hisobiga yoki production bazasiga kirilmadi; volume borligi tasdiqlanmagan. Manba ZIP’da foydalanuvchi bazasi yoki rasmlari bo‘lmaydi.

## Tarjimalarni tahrirlash

Manbalar: `lib/src/l10n/app_uz.arb`, `app_ru.arb`, `app_en.arb`. Kalitlar va `{0}` kabi parametrlar uchalasida bir xil bo‘lishi kerak. So‘ng:

```bash
python3 tool/generate_catalog.py
```

Runtime katalogi manba kodga kiritilgan, ilovani yig‘ish uchun Python talab qilinmaydi. `flutter_localizations` material komponentlar, sanalar va dialoglar uchun ulangan. `intl` Flutter SDK talab qiladigan 0.20.2 bilan moslashtirilgan.

## Arxiv

```bash
python3 tools/package_release.py --output ../DokonBoshqaruv_final.zip
```

Faqat source fayllar arxivlanadi: `.env`, SQLite bazalar, media, signing kalitlari, venv, build va keshlar chiqarib tashlanadi.

Aniq tekshiruv natijalari va chegaralari: `RELEASE_CHECKS_UZ.md`.
