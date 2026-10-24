# Dokon Boshqaruv — kod auditi

## Amalga oshirildi

- Kassada USB skaner uchun alohida shtrix-kod maydoni qo‘shildi. Enter orqali mahsulot keshlangan/API ma’lumotidan topilib savatga kiritiladi; kamera skaneri ham shu oqimga ulandi.
- Takror yuborilgan Enter parallel ishlov vaqtida bloklanadi; keyingi mustaqil skan bir xil mahsulot miqdorini oshiradi. Topilmagan kod va ombor/network xatolari uchun alohida xabarlar bor.
- Savat qatorlari narxi mahsulotdan olinadi; satr va jami qiymat sentlarda jamlanadi. Server narxni o‘zi oladi, chegirma/to‘lov/qoldiqni tekshiradi, sotuvdagi tarixiy narx va xarid narxini saqlaydi.
- Checkout ombor qoldig‘ini mahsulot qatorlarini bloklab tekshiradi; do‘kon bo‘yicha tranzaksiya qulfi va `operation_id` takror sotuv/zaxira kamayishini oldini oladi. Muvaffaqiyatsiz checkout vaqtida savat saqlanadi.
- Mahsulot rasmi Django `ImageField` va serializer multipart upload orqali saqlanadi. JPG/PNG/WebP formatlari va 5 MB hajm cheklovi bor. Flutter preview/upload, mahsulotlar ro‘yxati, tafsilotlari va POS’da rasm ko‘rsatish hamda rasm bo‘lmagandagi fallback qo‘shildi. Docker media fayllari volume’da saqlanadi.
- Hisobot API davrga mos tushum, sotuvlar soni, o‘rtacha chek, to‘lov taqsimoti, sotilgan miqdor, top mahsulotlar, kunlik kesim va ombor ogohlantirishlarini qaytaradi. UI filtrlari: bugun, kecha, 7/30 kun, oy va ixtiyoriy oraliq.
- Kam qolgan/tugagan mahsulotlar soni va mahsulot nomi, qoldig‘i, chegarasi ko‘rsatilgan ilova ichidagi ogohlantirishlar qo‘shildi. Sotuvdan so‘ng mahsulotlar yangilanadi.
- Offline keshdan foydalanilganda POS va mahsulotlar sahifasida qoldiq tasdiqlanmagan/keshlangan ekani haqida banner ko‘rinadi.
- Mahsulot rasmi uchun `0002_product_image` migratsiyasi, rasm uploadi, hisobot va barcode bo‘yicha Django testlari, savat/miqdor/pul yaxlitlash Flutter testlari qo‘shildi.

## Qolgan ishlar va cheklovlar

- Loyihada qaytarish/refund modeli va sozlangan qaytarish qoidasi yo‘q, shu sabab qaytarish oqimi qo‘shilmadi. Buni amalga oshirishdan oldin qisman/to‘liq qaytarish, pulni qaytarish va tovarni omborga tiklash qoidalarini belgilash kerak.
- Android/Web/Linux qurilmalarida kamera, USB skaner va multipart rasm uploadini integratsion sinash kerak.
- Django standart lokal media storage’dan foydalanadi. Docker volume rasmlarni saqlaydi; ko‘p serverli production muhitida umumiy object storage/NFS sozlamasi kerak bo‘ladi.
- Offline mahsulot keshi barcode qidiruvi uchun zaxira manba bo‘ladi. Offline kassadagi sotuvlarni server bilan to‘liq sinxronlash oqimi bu ishga qo‘shilmadi.
- Flutter format tekshiruvi avvaldan format farqi bo‘lgan fayllarda to‘xtadi; bu ishda o‘zgartirilgan Dart fayllar formatter’dan o‘tkazildi.
- Flutter analyze compile xatosini topmadi, ammo amaldagi deprecated API va uslub lintlari sabab `flutter analyze` exit 1 qaytardi.

## Tekshiruv natijalari

- `backend/venv/bin/python manage.py check` — muvaffaqiyatli.
- `backend/venv/bin/python manage.py makemigrations --check --dry-run` — yangi migration talab qilinmadi; muvaffaqiyatli.
- `backend/venv/bin/python manage.py migrate --noinput` — `core.0002_product_image` mahalliy SQLite bazaga qo‘llandi.
- `backend/venv/bin/python manage.py test` — 9 ta test muvaffaqiyatli.
- `flutter pub get` — muvaffaqiyatli; ishlatilmayotgan `image_cropper` lock-fayldan olib tashlandi.
- `flutter test` — 4 ta test muvaffaqiyatli.
- `flutter analyze` — 61 ta info/lint; compile/analyzer xatosi yo‘q, lekin CLI exit 1.
- `dart format --output=none --set-exit-if-changed .` — Flutter loyihasidagi boshqa format farqlari sabab exit 1. Bu ishda o‘zgartirilgan Dart fayllar formatlandi.
