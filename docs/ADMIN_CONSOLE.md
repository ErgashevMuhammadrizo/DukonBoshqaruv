# Superadmin platforma paneli

Panel superuser-only `/api/v1/admin/` endpointlaridan haqiqiy user, do‘kon, tarif, obuna, to‘lov va audit ma’lumotlarini oladi. User/do‘kon ro‘yxatlari, to‘lov va audit sahifalanadi. Store bloklanganda `ActiveStoreUser` permission barcha autentifikatsiyalangan store API so‘rovlarini rad etadi; ma’lumotlar saqlanib qoladi. Bloklash sababi audit metadata’da yoziladi. AuditLog Django admin’da ko‘rish uchun ochiq, lekin qo‘shish, tahrirlash va o‘chirish yopiq.

Obunani uzaytirish/bekor qilish va `pending` billing yozuvini tasdiqlash transaction ichida bajarilib audit qilinadi. Payment provider integratsiyasi/refund endpointi mavjud emas; panel faqat loyihadagi ichki `PaymentRecord` yozuvlarini ko‘rsatadi va mavjud admin tasdiqlash jarayonini boshqaradi. Currency modeli avval bo‘lmagani sabab yangi `PaymentRecord.currency` UZS default bilan qo‘shildi.

`SubscriptionPlan` hozir oylar, narx, chegirma va active maydonlariga ega. Trial konfiguratsiyasi, tarif limitlari va tarifning obunaga bevosita bog‘lanishi mavjud emas; ularni panelda soxta ko‘rsatmaymiz. Trial muddati aktivatsiya vaqtida mavjud xizmat qoidasi bo‘yicha 30 kun beriladi. Product yaratish endpointida obuna limiti tekshiruvi hozir mavjud emas.

System status endpoint API va DB (`SELECT 1`) holatini tekshiradi. Backup, disk va media monitoring tizimi loyihada yo‘q; panel backup monitoring mavjud emasligini aniq ko‘rsatadi. Admin API testlari `backend/tests/test_security.py` ichida joylashgan.
