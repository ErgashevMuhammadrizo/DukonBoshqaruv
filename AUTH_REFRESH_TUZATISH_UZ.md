# Refresh token: User.DoesNotExist → HTTP 401

Tasdiqlangan sabab: refresh token ichidagi user_id bo‘yicha server bazasida
foydalanuvchi topilmagan. SimpleJWT 5.5.1 serializeridagi .objects.get() exceptioni
ushlanmagani uchun 500 yuz bergan. Kamera xatosi bilan bir xil sabab deb hisoblanmaydi.

O‘zgargan backend fayllari:
- backend/apps/core/api.py: TokenRefreshView importi yangi himoyalangan viewga yo‘naltirildi.
- backend/apps/core/auth_refresh.py: yangi serializer va view.
- backend/tests/test_auth_refresh.py: 12 ta regressiya testi.

Himoya: imzo, muddat, blacklist, faol akkaunt, parol o‘zgarishi va rotatsiya
tekshiruvlari saqlanadi. CHECK_REVOKE_TOKEN o‘chirilmagan. Boshqa DB xatolari
401 sifatida yashirilmaydi. Token logga yozilmaydi. Yo‘q foydalanuvchi avtomatik
yaratilmaydi. Ma’lumotlar bazasi sxemasi o‘zgarmaydi, yangi migratsiya yo‘q.

O‘rnatish:
1. Hozirgi backenddan zaxira nusxa oling.
2. Yuqoridagi backend fayllarini loyiha repozitoriysiga joylashtiring.
3. Railway backendini yangilang. Faqat shu backend tuzatishi uchun APKni qayta
   yig‘ish talab qilinmaydi. Arxivda oldingi kamera tuzatishlari ham saqlangan.
4. Telefonda login/parol bilan qayta kiring. Eski, egasi yo‘q refresh token tiklanmaydi.
5. Agar login ham ishlamasa, avval akkaunt va baza ulanishini tekshiring.
   Ilovani o‘chirmang, uning ma’lumotlarini tozalamang: offline sotuvlar bo‘lishi mumkin.

Akkaunt nega yo‘qolganini bu patch isbotlamaydi. Foydalanuvchi o‘chirilgan,
server boshqa bazaga ulangan yoki doimiy saqlanmagan baza qayta yaratilgan
bo‘lishi mumkin. settings.py DB_ENGINE berilmasa sqlite tanlaydi. SQLite doimiy
volume bo‘lmagan diskda bo‘lsa, redeploy ma’lumotlarni yo‘qotishi mumkin.
DB_ENGINEni tekshirmasdan almashtirmang: mavjud ma’lumotlar ko‘chishi avtomatik emas.

Tekshiruv: lokal, vaqtinchalik in-memory test bazasida Django 5.2.18,
DRF 3.16.1, SimpleJWT 5.5.1 bilan 12 test muvaffaqiyatli o‘tdi.
Holatlar: mavjud/yo‘q/inactive user, expired/blacklisted/malformed token,
parol o‘zgarishi, token rotatsiyasi, user_id yo‘q/noto‘g‘ri token va haqiqiy
DB xatosini yashirmaslik. Production baza va Railway sozlamalari o‘zgartirilmagan.
