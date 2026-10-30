# inPAY ulash

Manba: https://inpay.uz/api/ va https://inpay.uz/api/llms.txt (30.10.2026).

1. Railway backend Variables bo‘limiga INPAY_MERCHANT_ID va INPAY_MERCHANT_TOKEN kiriting. Haqiqiy token ZIP ichiga qo‘shilmagan.
2. INPAY_CALLBACK_URL=https://dukonboshqaruvi-production.up.railway.app/api/v1/payments/inpay/callback/ qiymatini qo‘ying. Shu domenni inPAY kassasida ruxsat etilgan callback domenlariga kiriting. IP whitelist strict bo‘lsa, backend chiqish IP manzilini kelishing.
3. python manage.py migrate bajaring; backendni qayta ishga tushiring. INPAY_ENABLED=1 qo‘ying.
4. Flutter ilovasini qayta yig‘ing. Sozlamalar → tarif → inPAY orqali to‘lash. Havolani nusxalab brauzerda oching. To‘lov yakunlangach sozlamalarni yangilang.

Backend narxni bazadan oladi. Callback ichidagi statusga ishonilmaydi: inPAY transactions API orqali order ID va summa tekshiriladi. Takroriy callback obunani ikkinchi marta uzaytirmaydi. Mavjud sinov yoki pullik muddatdan keyin yangi muddat qo‘shiladi. Oylik muddat tarif months maydonidan olinadi; yillik to‘lov 12 oy.

API: POST /api/v1/payments/inpay/ {plan_id, billing_period: month yoki year}; javobda id va pay_url. POST /api/v1/payments/inpay/<id>/check/ — o‘z to‘lovini qayta tekshirish. Callback yo‘qolsa shu endpointdan foydalaning. Ilovada hozir oylik checkout tugmasi mavjud; yillik checkout API orqali ishlaydi.

Muhim chegaralar: checkout yaratishda timeout bo‘lsa provider hisob yaratgan bo‘lishi mumkin; qayta urinishdan oldin inPAY kabinetini tekshiring. Provider create API hujjatida idempotency kaliti ko‘rsatilmagan. Avtomatik kartadan yechib olish yo‘q: mijoz har safar havola orqali to‘laydi. Haqiqiy merchant bilan to‘lov sinovi bajarilmadi. Flutter SDK bo‘lmasa APK yig‘ilishi alohida tekshiriladi.
