# Premium dizayn va tarif arizasi
ZIP ichidagi 4 faylni loyihadagi aynan shu yo‘llarga almashtiring.
Oldingi bosqich tuzatishlari saqlangan. Migratsiya yo‘q.
Backendni qayta deploy qiling va yangi APK yig‘ing:
flutter build apk --release --dart-define=API_BASE_URL=https://dukonboshqaruvi-production.up.railway.app/api/v1/
Tarif xaridi: profil → tarif → to‘lov izohi → ariza. Bu karta orqali avtomatik to‘lov emas; mavjud admin tasdiqlashi kerak. Admin bilan to‘lov rekvizitlarini kelishing.
Dizayn: ilova umumiy theme, inputlar, navigatsiya, tugmalar va profildagi tarif kartalari. Boshqa ekranlarning individual layoutlari to‘liq qayta ishlanmagan.
Flutter SDK bu muhitda yo‘q: analyze, widget test va APK bajarilmadi. Telefon ko‘rinishini tekshiring.
