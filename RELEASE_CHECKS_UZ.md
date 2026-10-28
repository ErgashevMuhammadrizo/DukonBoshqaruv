# Yakuniy tekshiruvlar — 2026-10-28

## Natija

- Flutter manba kodi rasmiy Dart 3.12.2 analyzer va Flutter 3.44.6 kutubxonalari bilan tekshirildi: **0 error, 0 warning, 0 info**.
- Flutter testlar: **43 passed, 0 failed**. Test fayllari rasmiy `flutter_tester` engine ichida `tool/headless_test_runner.dart` orqali bajarildi. Oddiy `flutter test` shell buyrug‘i ishlatilmagan; haqiqiy Flutter widget/test framework ishlatilgan. Platforma kamera va server o‘rnida test mocklari qo‘llangan; SQLite navbat sinovi mahalliy SQLite FFI bilan bajarilgan.
- Backend: `python manage.py test` — **50 test, OK**; izolyatsiyalangan test bazasi ishlatilgan.
- `python manage.py check` — muammo yo‘q.
- `python manage.py makemigrations --check --dry-run` — `No changes detected`.
- Uch til katalogida **673 kalit**, barcha tillarda bir xil kalit va parametrlar. Koddagi literal tarjima kalitlari tekshirilgan: topilmagan kalit yo‘q.
- Inter shriftining lotin/kirill va o‘zbek apostroflari mavjudligi tekshirilgan, OFL litsenziya qo‘shilgan.
- Manba nusxasi ZIP orqali kelgan; unda `.git` yo‘q. Shu sabab Git diff o‘rniga boshlang‘ich fayllar bilan bayt bo‘yicha solishtirildi.

## Test qamrovi

Savat: bitta mahsulotni qayta qo‘shish; 1→2; 4→3; 0 ga tushirish; ombor chegarasi; kasrli qoldiqda +1; 1.001 va 0.009 normallashtirish; nolga yaxlitlanadigan juda kichik va cheksiz qiymatlarni rad etish; tiyin birliklarida jami; tozalash; sotuv JSON miqdori.

Uch til × ikki tema uchun 360×780 o‘lchamda login, mahsulot kartasi, savat, bo‘sh hisobot, qarzlar, mahsulot yaratish/tahrirlash formalari, admin dashboard va profil/tarif kartalari tekshirildi. Aniqlangan hisobot/formalar/admin/profil overflowlari tuzatildi. Til/tema almashtirishda login matni va savat holati saqlanishi, sozlamalarning qayta tiklanishi tekshirildi.

Auth: 401 → refresh → retry; refresh rad etilganda logout. Offline: ack va conflict/retry. Skaner: ruxsat rad etilganda cheksiz yuklanishsiz fallback. Kamera session regressiya executable fayli rasmiy headless engine orqali alohida bajarildi: **10 ta ssenariy, PASS**. Oddiy host Dart launcher ushbu muhitda uni ishga tushira olmadi (chiqish kodi 255, xabarsiz); Flutter engine orqali ayni manba muvaffaqiyatli bajarildi.

Backend testlar mahsulot rasmi, o‘chirish va tarixni himoya qilish, do‘konlar izolyatsiyasi, savdo/qarz/obuna/admin/auth va tarif arizasi narxini serverdan olish hamda takrorlanishni tekshiradi.

## Bajarilmagan tashqi tekshiruvlar

- Android release APK: bu muhitda Android SDK yo‘q; APK yig‘ilmadi.
- Yangi dizaynning haqiqiy telefon kamerasi: qurilma ulanmagan. Oldin foydalanuvchi tasdiqlagan ishlaydigan native kamera patchi saqlangan; yangi UI uchun qurilma sinovi talab qilinadi.
- Railway production deploy, haqiqiy merchant/card tranzaksiyasi va storage volume: hisobga kirilmagan. To‘lov oqimi administrator tasdiqlaydigan ariza; avtomatik bank to‘lovi emas.
- Har bir mumkin bo‘lgan server ma’lumot hajmi, klaviatura va telefon o‘lchami tekshirilgan deb da’vo qilinmaydi.

## Asosiy o‘zgarishlar

`preferences.dart`: saqlanadigan tema/til; `adaptive_colors.dart`: eski komponentlarning dark rang moslashuvi; `l10n/*`: uch tildagi matnlar; `app.dart`: locale/theme integratsiyasi; `main.dart`: uch til sana formatlari; ekran/widgetlar: tarjima, kontrast va responsive layout; `cart_provider.dart` va `cart_item.dart`: miqdor/ombor himoyasi; skaner: moslashuvchan kvadrat ramka va xato holati. Sinxronlashning o‘zi saqlangan, yuqoridagi banner o‘chirilgan. Keraksiz diagnostika UI fayli olib tashlangan.

Oldingi backend refresh/media/DELETE/to‘lov arizasi tuzatishlari saqlangan. Bu bosqichda backend sxemasi o‘zgarmagan.

## Fayllar ro‘yxati

### O‘zgargan

- `.env.example`
- `create_zip.sh`
- `dokon_boshqaruv/lib/features/debts/screens/debts_screen.dart`
- `dokon_boshqaruv/lib/features/pos/models/cart_item.dart`
- `dokon_boshqaruv/lib/features/pos/providers/cart_provider.dart`
- `dokon_boshqaruv/lib/features/pos/screens/pos_screen.dart`
- `dokon_boshqaruv/lib/features/pos/screens/receipt_screen.dart`
- `dokon_boshqaruv/lib/features/pos/screens/sales_history_screen.dart`
- `dokon_boshqaruv/lib/features/pos/widgets/cart_panel.dart`
- `dokon_boshqaruv/lib/features/pos/widgets/payment_dialog.dart`
- `dokon_boshqaruv/lib/features/pos/widgets/product_grid.dart`
- `dokon_boshqaruv/lib/features/pos/widgets/product_search.dart`
- `dokon_boshqaruv/lib/features/products/models/product.dart`
- `dokon_boshqaruv/lib/features/products/providers/products_provider.dart`
- `dokon_boshqaruv/lib/features/products/screens/add_product_screen.dart`
- `dokon_boshqaruv/lib/features/products/screens/edit_product_screen.dart`
- `dokon_boshqaruv/lib/features/products/screens/product_detail_screen.dart`
- `dokon_boshqaruv/lib/features/products/screens/products_screen.dart`
- `dokon_boshqaruv/lib/features/products/widgets/barcode_scanner_dialog.dart`
- `dokon_boshqaruv/lib/features/products/widgets/empty_state.dart`
- `dokon_boshqaruv/lib/features/products/widgets/image_picker_widget.dart`
- `dokon_boshqaruv/lib/features/products/widgets/product_card.dart`
- `dokon_boshqaruv/lib/features/products/widgets/product_summary_cards.dart`
- `dokon_boshqaruv/lib/features/products/widgets/quick_stock_adjustment.dart`
- `dokon_boshqaruv/lib/features/products/widgets/unit_selector.dart`
- `dokon_boshqaruv/lib/features/reports/screens/reports_screen.dart`
- `dokon_boshqaruv/lib/main.dart`
- `dokon_boshqaruv/lib/src/api.dart`
- `dokon_boshqaruv/lib/src/app.dart`
- `dokon_boshqaruv/lib/src/offline.dart`
- `dokon_boshqaruv/lib/src/preferences.dart`
- `dokon_boshqaruv/lib/src/screens/account_settings.dart`
- `dokon_boshqaruv/lib/src/screens/activate_account.dart`
- `dokon_boshqaruv/lib/src/screens/admin_panel.dart`
- `dokon_boshqaruv/lib/src/screens/change_password.dart`
- `dokon_boshqaruv/lib/src/screens/home_screen.dart`
- `dokon_boshqaruv/pubspec.lock`
- `dokon_boshqaruv/pubspec.yaml`
- `dokon_boshqaruv/test/account_settings_test.dart`
- `dokon_boshqaruv/test/api_and_queue_regression_test.dart`
- `dokon_boshqaruv/test/features/pos/cart_provider_test.dart`
- `dokon_boshqaruv/test/widget_test.dart`
- `dokon_boshqaruv/third_party/mobile_scanner/LOCAL_PATCH.md`
- `dokon_boshqaruv/third_party/mobile_scanner/analysis_options.yaml`
- `dokon_boshqaruv/third_party/mobile_scanner/pubspec.yaml`

### Yangi

- `README_FINAL_UZ.md`
- `dokon_boshqaruv/assets/fonts/Inter.ttf`
- `dokon_boshqaruv/assets/fonts/OFL.txt`
- `dokon_boshqaruv/lib/src/adaptive_colors.dart`
- `dokon_boshqaruv/lib/src/l10n/app_en.arb`
- `dokon_boshqaruv/lib/src/l10n/app_ru.arb`
- `dokon_boshqaruv/lib/src/l10n/app_strings.dart`
- `dokon_boshqaruv/lib/src/l10n/app_uz.arb`
- `dokon_boshqaruv/lib/src/l10n/catalog.dart`
- `dokon_boshqaruv/lib/src/l10n/translations.dart`
- `dokon_boshqaruv/test/redesign_test.dart`
- `dokon_boshqaruv/tool/generate_catalog.py`
- `dokon_boshqaruv/tool/headless_test_runner.dart`
- `tools/package_release.py`

### Olib tashlangan

- `dokon_boshqaruv/lib/src/diagnostics/diagnostics_view.dart`
