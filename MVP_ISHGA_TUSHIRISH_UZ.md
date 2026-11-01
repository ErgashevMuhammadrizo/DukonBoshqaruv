# e-dukon — ishga tushirish

## 502 sababi va yangi integratsiya

Avvalgi kod v1 merchant_id/token oqimida edi. Sizdagi kabinet v2 sk_test_/sk_live_ kalitlarini beradi. Endi backend to‘g‘ridan-to‘g‘ri https://inpay.uz/api/v2/payments/ ga Bearer SECRET_KEY bilan ulanadi. Provider xatolarining code va request_id maydonlari qaytadi; token va provider xom javobi logga yozilmaydi.

## Railway Variables

Mavjud Django/database sozlamalarini SAQLANG. DB_ENGINE ni almashtirmang — eski baza yo‘qolgandek ko‘rinishi mumkin.

- INPAY_ENABLED=1
- INPAY_SECRET_KEY=sk_live_... (inPAY → Kassa → API v2 kalitlari)
- INPAY_WEBHOOK_SECRET=whsec_... (inPAY webhook imzo siri)
- INPAY_WEBHOOK_URL=https://dukonboshqaruvi-production.up.railway.app/api/v1/payments/inpay/callback/
- INPAY_RETURN_URL=https://dukonboshqaruvi-production.up.railway.app/api/v1/payments/inpay/return/

Merchant ID va eski merchant token v2 uchun kerak emas. sk_test_ haqiqiy pul yechmaydi. APP_ENV=production bo‘lsa test to‘lovi jonli obunani uzaytirmaydi. Sinov obunasini tekshirish uchun alohida development deployment ishlating.

inPAY kabinetidagi Webhook URL maydoniga aynan INPAY_WEBHOOK_URL qiymatini yozib Saqlash bosing. Imzo siri hujjat bo‘yicha GET https://inpay.uz/api/v2/webhooks/secret/ so‘rovi orqali jonli Bearer kalit bilan olinadi; uni backendga whsec_... ko‘rinishida kiriting. Sirni chatga, Flutterga, GitHubga joylamang. O‘z kassangiz domen/IP ruxsatlarini ham tekshiring.

Backend deploy: avval bazani backup qiling, so‘ng backend ichida python manage.py migrate va python manage.py check_inpay --probe. Probe balansni o‘qiydi, to‘lov yaratmaydi. So‘ng backendni qayta ishga tushiring.

Lokal backend: backend/.env.example → backend/.env nusxalang; o‘zingizning Django SECRET_KEY va baza qiymatlarini kiriting. .env.inpay.example faqat to‘lov o‘zgaruvchilarining qisqa nusxasi. ZIP ichida haqiqiy kalit yo‘q. Railway Variables lokal .env o‘rnini bosadi.

## Ilova API manzili

Flutter backendga ulanadi: https://dukonboshqaruvi-production.up.railway.app/api/v1/
Bu manzil dokon_boshqaruv/config/production.json ichidagi API_BASE_URL. Uni inpay.uz/api/v2 bilan almashtirmang. inPAY chaqiruvlari faqat serverda bajariladi. Android: flutter build apk --release --dart-define-from-file=config/production.json

## Windows

Windows 10/11 x64, Flutter 3.44+ (Dart 3.12+) SDK va Visual Studio (VS Code emas) Desktop development with C++ workload kerak. PowerShell: dokon_boshqaruv/tool/build_windows.ps1. EXE bilan birga DLL va data papkasini ham tarqating; skript dist/e-dukon-Windows.zip yaratadi.

Windows’da SQLite FFI, secure storage, fayldan mahsulot rasmi tanlash va tashqi brauzer orqali to‘lov ishlatiladi. Mobil kamera ruxsati Windows’da so‘ralmaydi. USB shtrix-kod skaner klaviatura kabi ishlaydi: qidiruv/kod maydoniga fokus bering va Enter yuboring. Windows kamera orqali shtrix-kod o‘qish bu MVPda yo‘q; Android kamera skaneri saqlangan.

## To‘lov foydalanuvchi oqimi

Tarif kartasida faqat “inPAY orqali to‘lash” tugmasi mavjud. Bosilganda brauzerda hosted checkout ochiladi. Ilova qaytishni kutmasdan vaqt-vaqti bilan to‘lovni tekshiradi; webhook serverda obunani yangilaydi. Ilova qayta ochilganda pending hisob tekshiruvi tiklanadi. Qo‘lda to‘lov arizasi tugmasi olib tashlangan; eski to‘lov tarixi saqlangan.

Webhook HMAC-SHA256, 5 daqiqa tolerans bilan tekshiriladi. Keyin server inPAY’dan ID, summa, valyuta va livemode ni mustaqil tekshiradi. Takroriy callback ikki marta muddat qo‘shmaydi. Hisob UUID va so‘rov tanasi API chaqiruvidan oldin bazaga yoziladi; timeoutdan keyin ayni Idempotency-Key bilan qayta urinish mumkin. 23 soatdan eski pending hisob avtomatik yangidan yaratilmaydi: avval provider kabinetida tekshiring.

Eski v1 pending hisoblar o‘chirilmagan. v2 faqat yangi v2 hisoblarni yaratadi/tekshiradi. Eski v1 hisob bo‘yicha pul tushgan bo‘lsa alohida tekshirib yarashtirish kerak.

## Chiqarishdan oldin

inPAY sandbox orqali to‘lov, webhook yetkazilishi va obuna holatini tekshiring. Windows buildni Windows kompyuterda ishga tushirib login, mahsulot rasmi, savdo va offline qayta ulanishni tekshiring. Bu hujjat real to‘lov yoki Windows qurilma sinovi o‘rnini bosmaydi.
