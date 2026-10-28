# Haqiqiy APKni joylashtirish

Hozir paketda APK yo‘q. Tugma fayl borligini tekshiradi va mavjud bo‘lmasa aniq xabar ko‘rsatadi:

> Ilova fayli hozircha joylanmagan. Iltimos, keyinroq qayta urinib ko‘ring.

1. Flutter loyihangizda release APK yarating:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://dukonboshqaruvi-production.up.railway.app/api/v1/
```

2. Hosil bo‘lgan `build/app/outputs/flutter-apk/app-release.apk` ni `website/public/downloads/dokon-boshqaruv.apk` nomi bilan ko‘chiring. Faqat o‘zingiz tekshirgan va to‘g‘ri imzolangan APKni tarqating. Mavjud o‘rnatma ustiga yangilash uchun signing key va applicationId mos bo‘lishi kerak.
3. `website/site_config.json` ichidagi `apk_version` ni haqiqiy versiya bilan to‘ldiring; noma’lum bo‘lsa bo‘sh qoldiring. Hajm serverdagi real fayldan olinadi, taxminiy son yo‘q.
4. Website image ni qayta build/deploy qiling yoki APKni persistent volumega joylang (READMEdagi mount yo‘lini tekshiring).
5. `/download/` ni oching va tugmani bosing. Bevosita fayl URL: `/downloads/dokon-boshqaruv.apk`. GET va HEAD to‘g‘ri MIME, fayl nomi va hajmni qaytaradi. Fayl yo‘q bo‘lsa 404 JSON qaytadi.

Server oddiy ZIP sarlavhasini tekshiradi; bu Android imzosi yoki APK haqiqiyligini to‘liq tekshirish emas. Haqiqiy APK qurilmada alohida sinovdan o‘tkazilishi kerak.

Tashqi HTTPS download URL ishlatish mumkin, lekin u HEAD, Android/ZIP MIME va frontend origin uchun CORSni qo‘llashi kerak. Ishonchli variant — standart shu domen ichidagi URL. HTML qaytaradigan noto‘g‘ri URL yuklash sifatida qabul qilinmaydi.

Website yuklash sahifasi APIga murojaat qilmaydi. Ilovaning serverga ulanishi APK buildidagi API_BASE_URL va backend holatiga bog‘liq.
