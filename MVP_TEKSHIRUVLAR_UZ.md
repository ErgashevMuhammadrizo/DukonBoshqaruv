# e-dukon 0.3.1 — joriy tekshiruvlar

92 backend testi o‘tdi, shu jumladan 7 kategoriya/manzil testi. Django migration mosligi tekshirildi: yangi o‘zgarish topilmadi. Yangi maydonlar mavjud mahsulotlarga bo‘sh qiymat bilan qo‘shiladi. O‘zgargan Dart fayllari formatter bilan sintaksis tekshiruvidan o‘tdi. Uchta yangi Dart cache/filter regressiya testi qo‘shildi, lekin Flutter test runner bu muhitda bajarilmadi.

Flutter build/analiz, Android APK, Windows EXE va haqiqiy qurilmada sinov hali bajarilmagan. Oldingi Flutter metadata murojaati bilan bog‘liq avtomatik xavfsizlik cheklovi chetlab o‘tilmadi. Haqiqiy inPAY merchant bilan to‘lov ham tekshirilmagan.

Kategoriyalar va mahsulot manzili uchun KATEGORIYA_MANZIL_UZ.md yo‘riqnomasini ko‘ring. Backend yangilangach python manage.py migrate kerak.

## Oldingi reliz tekshiruvlari

# e-dukon 0.3.0 tekshiruvlari — 01.11.2026

- 85 backend testi o‘tdi, shu jumladan 14 inPAY v2/transport testi.
- HMAC imzosi, eskirgan webhook, soxta holat, summa/valyuta/live rejimi mosligi, takroriy callback, timeoutdan keyingi idempotent qayta urinish, yillik tarif va tenant izolyatsiyasi tekshirildi.
- 401 provider xatosi code/request_id bilan tushunarli javob beradi; raw token va provider xabaridagi secret logga chiqmaydi.
- Django system check va makemigrations --check --dry-run o‘tdi.
- O‘zgargan Dart fayllari SDK formatter yordamida sintaksis tekshiruvidan o‘tdi. Flutter analiz/widget testlari bajarilmadi: Flutter tool jarayonining ichki bulut metadata endpointiga murojaati avtomatik xavfsizlik nazoratida bloklandi. Cheklov chetlab o‘tilmadi.
- Windows runner manbalari rasmiy Flutter templatelaridan tayyorlandi. Windows EXE va Android APK yig‘ilmadi; Windows qurilmasida login/POS/offline ishlashi bu muhitda tasdiqlanmadi. Build skripti va aniq talablar qo‘shilgan.
- Paket lock fayli eski pinlarni saqlaydi; yangi url_launcher uchun flutter pub get Windows/mahalliy muhitda uni yangilaydi. Bu muhitda paketlarni to‘liq yechish va Flutter compile tekshiruvi tugamagan.
- Haqiqiy API kalitlari bilan inPAY sandbox/jonli so‘rovlari bajarilmadi. To‘lovlar mock provider orqali sinovdan o‘tdi.
- Backend parallel qator lock qoidalari PostgreSQL uchun yozilgan; testlar SQLite’da bajarilgan, haqiqiy PostgreSQL parallel yuk testi bajarilmadi.

Bu ZIP yangilangan manba koddir. Ishlab chiqarishga to‘liq tayyorlikni tasdiqlash uchun Windows build/qurilma va haqiqiy sandbox tekshiruvlari hali kerak.
