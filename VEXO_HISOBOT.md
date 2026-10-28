# VEXO — o‘zgarishlar hisoboti

Ilovaning ko‘rinadigan nomi VEXO, versiyasi 0.2.1+4. Flutter/Django tuzilishi saqlandi; package/application ID, API domeni, token kalitlari va offline bazalar nomlari o‘zgartirilmadi.

## Mahsulot o‘chirishning aniqlangan sabablari

1. `ProductView.destroy()` mahsulotda savdo yoki ombor harakati bo‘lsa, ForeignKey `PROTECT` sabab 409 qaytarardi. Boshlang‘ich qoldiq ham ombor harakati yaratgani uchun yangi mahsulotlarda ham bu holat uchrashi mumkin edi.
2. `product_detail_screen.dart` bottom-sheet builderining `context`ini menyu yopilgandan keyin dialog uchun ishlatardi. Endi tasdiqlash oynasi ochiq ekran contextidan foydalanadi.
3. Frontend DELETE muvaffaqiyatidan so‘ng faqat `refresh()`ga tayanardi. Keyingi GET uzilsa, eski cache mahsulotni qayta ko‘rsatishi mumkin edi.
4. Backend mahsulot ro‘yxati va `sync/pull/` faol bo‘lmagan mahsulotlarni ham qaytarardi. Endi katalog va sinxronlash ular bilan to‘ldirilmaydi.

DELETE URL va HTTP metodi oldindan to‘g‘ri edi: `/api/v1/products/<id>/`, `DELETE`. Tenant filtri ham mavjud edi va saqlandi. Muammo noto‘g‘ri URL deb taxmin qilinmadi.

## Yangi o‘chirish qoidasi

- Tarixsiz mahsulot: jismoniy DELETE, HTTP 204.
- Savdo yoki ombor tarixi mavjud mahsulot: `active=False`, `deleted_at` belgilanishi, HTTP 204. Mahsulot bazadan jismonan o‘chirilmaydi. Savdo, uning summasi, SaleItem va InventoryMovement saqlanadi.
- `X-Product-Deletion` javob sarlavhasi `permanent` yoki `soft` qiymatini beradi.
- O‘z do‘konida topilmagan, noto‘g‘ri ID yoki boshqa do‘kon mahsuloti: 404. Autentifikatsiyasiz: 401; bloklangan do‘kon: 403.
- Soft delete qilingan yozuvni oddiy PATCH yoki yangi savdo orqali qayta faollashtirib bo‘lmaydi. Eski operation_id bilan savdo replay qilinsa, oldingi savdo qaytadi, yangi savdo yaratilmaydi.
- Store → Product lock tartibi checkout bilan bir xil. ForeignKey PROTECT saqlandi; CASCADE bilan tarix o‘chirilmaydi.
- Tarix uchun saqlangan SKU va barcode unique cheklovlari o‘zgarmadi: soft delete ularni bo‘shatmaydi.

## Offline va cache

O‘chirish faqat server tasdiqlaganidan keyin bajarilgan deb ko‘rsatiladi. Tarmoq xatosida mahsulot va cache saqlanadi, DELETE offline navbatga qo‘shilmaydi; internet tiklangach foydalanuvchi qayta urinadi. Tasdiqlanmagan offline savdolar mavjud bo‘lsa avval ular sinxronlanishi yoki ziddiyatlari hal qilinishi kerak.

Tasdiqlangan DELETE uchun shu akkaunt SQLite cache jadvalida `removed_product_ids` belgisi saqlanadi. Cache tozalanadi; ilova qayta ochilganda yoki eski javob qaytganda ham mahsulot qayta ko‘rinmaydi. So‘rov vaqtida mahsulot saqlanadi, loading dialogi chiqadi va takroriy bosish bloklanadi. Muvaffaqiyatdan so‘ng joriy savatdan ham shu ID olib tashlanadi. Oddiy arxivlash uchun doimiy tombstone qo‘yilmaydi, shuning uchun keyinchalik serverda aniq qayta faollashtirilgan mahsulotni qaytarish yo‘li saqlanadi.

## Tugmalar va interfeys

- Umumiy button theme: kamida 48 px bosish maydoni, bir xil padding va radius.
- `ActionButtons`: keng joyda teng enli, tor ekran yoki katta matnda to‘liq enli ustun; tasdiqlash oxirida, asosiy rangda.
- Profil: tahrirlash, username va parol tugmalari bir xil tartibda.
- Mahsulotlar: qoldiq, narx va ombor tugmasi kichik trailing joyga siqilmaydi; nom va tugma matni o‘raladi. Rasm tanlash maydoni katta matnda o‘sadi.
- Mahsulot tafsiloti: o‘chirish/arxivlash contexti, kutish holati, tushunarli xato; ombor tarixi tugmasi endi API orqali haqiqiy ma’lumot ochadi. API product_id filtri qo‘shildi va do‘kon bilan chegaralangan.
- Kassa: tor ekranda tarix va savatni tozalash tugmalari uchun joy ajratilgan; soat keng ekranda qoladi. Mahsulot kartalari mavjud kenglik va matn o‘lchamiga moslashadi.
- Savat: miqdor boshqaruvi 48 px, tooltip va semantik IconButton; narx/qoldiq satrlari moslashadi, to‘lov standart FilledButton.
- To‘lov: summa va sarlavha alohida qatorda; bekor qilish/tasdiqlash tor ekranda ustun.
- Hisobot: davr tanlash ChoiceChip, refresh tooltip; daromad sarlavhasi o‘raladi.
- Daftar va admin dashboard: sana tugmalari moslashuvchan.
- Admin tariflari: yoqish/tahrirlash alohida qatorda; uzun tarif matni tugmalarni siqmaydi.
- Tarif xarid arizasi: bo‘sh reference tekshiriladi, bekor qilish so‘rov yubormaydi, to‘g‘ri plan_id yuboriladi. Controller dialog yopilish animatsiyasi tugagach tozalanadi.
- Chekdagi printer/PDF integratsiyalari asl loyihada amalga oshirilmagan edi. Soxta ishlayotgandek ko‘ringan tugmalar hozir o‘chirilgan va mavjud emasligi tooltipda ko‘rsatilgan. Haqiqiy printer/PDF eksporti qo‘shilgani da’vo qilinmaydi.

Screenshot bu topshiriqda biriktirilmagan: uning o‘zini vizual taqqoslash bajarilmadi. Tekshiruv mavjud kod va quyidagi widget testlari asosida qilindi. Ekranlar sababsiz to‘liq qayta yozilmadi.

## Haqiqiy tekshiruv natijalari

Yakuniy aniq natijalar `verification/` ichidagi loglarda saqlanadi:

- Backend: 58 test o‘tdi. Django alohida test SQLite bazasini yaratib ishlatdi; ishlab turgan serverga DELETE yoki test so‘rovi yuborilmadi.
- Flutter: rasmiy `flutter_tester` headless engine orqali 59 test o‘tdi, 0 xato. Yakuniy natija `verification/flutter_widget_tests.txt` oxiridagi HEADLESS RESULT satrida.
- Eski cart, login/startup, localization, profil, refresh-token va offline sync testlari ham shu ro‘yxatda.
- Yangi testlar: DELETE URL/ID, server javobigacha ro‘yxatni saqlash, cache/tombstone, restart, eski javob, tarmoq/server xatosi, pending sale, takroriy bosish, cancel, progress va navigatsiya.
- Layout testlari: 320×780, matn 1.3x, uz/ru/en; login, mahsulot, POS, tarix, hisobot, daftar, adminning barcha bo‘limlari/tarif tahriri, profil va mahsulot formalari. Savat +/- va hisobot davri, POS → tarix → ortga amallari bosib tekshirildi. Oldingi testlar 360 px va light/dark holatlarni ham qamraydi.
- Tarif arizasi faqat mock transportda tekshirildi; haqiqiy to‘lov amalga oshirilmadi.
- `dart analyze lib test`: yakuniy log alohida saqlangan.
- Migratsiya mosligi: `makemigrations core --check --dry-run` → No changes detected; bu tekshiruv ham `:memory:` SQLite sozlamasida bajarildi.
- `flutter analyze` va `flutter build apk --release` buyruqlari urinish loglari bor. Muhitdagi Flutter manbalari Git clone bo‘lmagani sabab Flutter CLI ishga tushmadi. Ularni muvaffaqiyatli o‘tdi deb hisoblamang. Android release APK yaratilmagan; haqiqiy telefonda yangi build sinalmagan.

## Yangilash tartibi

Barcha fayllar eski papka tuzilishida berilgan. Mavjud serverning env, PostgreSQL, media va imzolash kalitlarini o‘zingizdagi holatda saqlang. Paketda real `.env`, ma’lumotlar bazasi, signing key, build yoki `.dart_tool` berilmaydi. Loyihadagi asl kod fayllari olib tashlanmagan.

1. Backend kodi va `0009_product_deleted_at.py` migratsiyasini birga yangilang. Odatdagi backup tartibidan so‘ng mavjud muhitda:

```bash
cd backend
python manage.py migrate
```

Bu migratsiya nullable maydon va index qo‘shadi; mavjud mahsulot yoki tarixni o‘chirmaydi. Avval backendni yangilang, keyin APKni.

2. To‘liq Flutter SDK va Android SDK o‘rnatilgan kompyuteringizda:

```bash
cd dokon_boshqaruv
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define=API_BASE_URL=https://dukonboshqaruvi-production.up.railway.app/api/v1/
```

APK: `build/app/outputs/flutter-apk/app-release.apk`. Ilova nomi VEXO ko‘rinadi. Mavjud ilova ustiga yangilash uchun avvalgi applicationId va signing keydan foydalaning; ular bu patchda almashtirilmadi. Saqlanmagan offline sotuvlarni yo‘qotmaslik uchun ilovani o‘chirib tashlash talab qilinmaydi.

Serverga deploy bu ish davomida bajarilmadi. `website/` oldingi website paketi sifatida saqlangan; ushbu ishda marketing sayti qayta brendlanmadi.

## O‘zgargan va yangi kod fayllari

- `backend/apps/core/api.py`
- `backend/apps/core/migrations/0009_product_deleted_at.py`
- `backend/apps/core/models.py`
- `backend/apps/core/services.py`
- `backend/tests/test_product_deletion.py`
- `backend/tests/test_services.py`
- `dokon_boshqaruv/android/app/src/main/AndroidManifest.xml`
- `dokon_boshqaruv/ios/Runner/Info.plist`
- `dokon_boshqaruv/lib/features/debts/screens/debts_screen.dart`
- `dokon_boshqaruv/lib/features/pos/screens/pos_screen.dart`
- `dokon_boshqaruv/lib/features/pos/screens/receipt_screen.dart`
- `dokon_boshqaruv/lib/features/pos/widgets/cart_panel.dart`
- `dokon_boshqaruv/lib/features/pos/widgets/payment_dialog.dart`
- `dokon_boshqaruv/lib/features/pos/widgets/product_grid.dart`
- `dokon_boshqaruv/lib/features/products/providers/products_provider.dart`
- `dokon_boshqaruv/lib/features/products/screens/product_detail_screen.dart`
- `dokon_boshqaruv/lib/features/products/widgets/image_picker_widget.dart`
- `dokon_boshqaruv/lib/features/products/widgets/product_card.dart`
- `dokon_boshqaruv/lib/features/reports/screens/reports_screen.dart`
- `dokon_boshqaruv/lib/src/l10n/app_en.arb`
- `dokon_boshqaruv/lib/src/l10n/app_ru.arb`
- `dokon_boshqaruv/lib/src/l10n/app_uz.arb`
- `dokon_boshqaruv/lib/src/l10n/catalog.dart`
- `dokon_boshqaruv/lib/src/offline.dart`
- `dokon_boshqaruv/lib/src/preferences.dart`
- `dokon_boshqaruv/lib/src/screens/account_settings.dart`
- `dokon_boshqaruv/lib/src/screens/admin_panel.dart`
- `dokon_boshqaruv/lib/src/widgets/action_buttons.dart`
- `dokon_boshqaruv/linux/runner/my_application.cc`
- `dokon_boshqaruv/pubspec.yaml`
- `dokon_boshqaruv/test/action_layout_test.dart`
- `dokon_boshqaruv/test/product_deletion_test.dart`
- `dokon_boshqaruv/tool/headless_test_runner.dart`
- `dokon_boshqaruv/web/index.html`
- `dokon_boshqaruv/web/manifest.json`
