# Dokon Boshqaruv — kamera tuzatishi va diagnostika

## Hozir nima ma’lum?

AndroidManifest.xml ichida CAMERA ruxsati allaqachon bor. Rasmda ham ruxsat
berilgani ko‘rinadi. Ruxsatni qayta-qayta yoqish asosiy tashxis emas.

ZIPdagi haqiqiy kombinatsiya: Flutter 3.44.6, mobile_scanner 5.2.3.
Eski scannerning Android kodida kamera ochishdagi ayrim exceptionlar sabab va
stacki saqlanmasdan CameraError/NoCamera ga almashtirilgan; Dart tomonda ular
ko‘pincha genericErrorga aylangan. Shuning uchun rasm asl sababni bermaydi.

Yana bir tasdiqlangan kod xatosi: MobileScannerController.start() ayrim
xatolarni throw qilish o‘rniga value.errorga saqlaydi. Ilova faqat await va
try/catchga tayanib, natijani muvaffaqiyatli deb qabul qilishi mumkin edi.
Oldin barcha xatolarni “kamera ruxsati kerak” deb ko‘rsatish ham noto‘g‘ri edi.

Telefonning aniq HAL/CameraX xatosi hali qayta hosil qilinmagan. Kutubxona
versiyasining o‘zi qurilmadagi sababni isbotlamaydi. Yangi hisobot aynan
telefon qaytargan sababni ko‘rsatish uchun qo‘shildi.

## O‘zgarishlar

- mobile_scanner 7.4.2 asosidagi lokal nusxa third_party/mobile_scannerga qo‘shildi.
  U upstream SurfaceProducer, CameraX va kadrni bo‘shatish tuzatishlarini oladi.
- Native xatolar endi bosqich, exception, message, stack va cleanup_failure
  maydonlari bilan Dartga uzatiladi. Setup xatosida kamera resurslari bo‘shatiladi.
- start/stop/dispose bitta ketma-ket navbat bilan boshqariladi.
- start()dan keyin value.error va isRunning majburiy tekshiriladi.
- Kamera vidjeti birinchi framega ulanmaguncha start chaqirilmaydi.
- Ruxsat oynasining inactive/resumed hodisalari parallel start hosil qilmaydi.
- Kamera yopilayotganda yangi start qabul qilinmaydi; dispose startdan keyin bajariladi.
- Boshqa kamera tugmasi old/orqa kamerani alohida sinash imkonini beradi.
- Boshlanish 12 soniyada javob bermasa shu bosqich qayd etiladi; xavfli parallel
  qayta start boshlanmaydi. Kutilayotgan native amalning o‘zi majburan uzilmaydi.
- Native diagnostika Android ruxsatini, telefon modelini va kameralar ro‘yxatini oladi.
- Kadrlar, ML Kit so‘rovlari, muvaffaqiyatli tahlillar va xatolar sanaladi.
  Kadrlar yoki shtrix-kod qiymatlari hisobotga yozilmaydi.
- Flutter framework va uncaught xatolari oldingi error handlerlarni saqlagan holda
  lokal, oxirgi 80 hodisali diagnostikaga qo‘shiladi.
- Hisobot hech qayerga avtomatik yuborilmaydi. “Nusxalash” orqali ulashiladi.
- pubspec versiyasi 0.1.1+2. Paket identifikatori va imzolash sozlamasi saqlangan.
- Backend, kassadagi to‘lov qoidalari, obuna logikasi va ma’lumotlar bazasi o‘zgarmadi.

## O‘rnatish

1. Hozirgi loyihangizdan zaxira nusxa oling.
2. Arxivni alohida papkaga oching. Bu to‘liq SOURCE nusxa: build, .dart_tool,
   .gradle, ephemeral va boshqa qayta yaratiladigan keshlar chiqarilgan.
   Asl foydalanuvchi konfiguratsiyasi/media fayllari mavjud bo‘lsa saqlangan.
3. Ishlayotgan server ma’lumotlarini yoki telefondagi ilovani o‘chirmang.
4. Android Studio/IDEda dokon_boshqaruv/pubspec.yamlni oching va “Pub get”ni bajaring.
   Faqat barcode_scanner_dialog.dartni ko‘chirish yetmaydi: yangi third_party,
   diagnostics, MainActivity, pubspec va lock fayllari birga bo‘lishi kerak.
5. Avvalgi Flutter 3.44.6 muhitingiz bilan yangi Android APK yig‘ing.
   Kutubxona Android compileSdk 36 va Java 17ni talab qiladi; loyiha allaqachon
   Java 17 va Flutter compileSdk sozlamasidan foydalanadi.
6. Avvalgi APKni imzolagan o‘sha kompyuter/kalit bilan yangilanish o‘rnating.
   Signing yoki versiya xatosi bo‘lsa ilovani o‘chirmang, xatoni yuboring.
7. Kamera uchun Railway backendini qayta deploy qilish shart emas.
   Railway build xatosi bo‘lsa uning Build Logs matni alohida talab etiladi.

## Endi xatoni qanday aniqlaymiz?

1. Telefonda kamera skanerini oching va natijani kuting.
2. “Xato hisoboti” tugmasini bosing. Shu tugma diagnostika uchun yangi native
   probe va kadr hisoblagichlarini ham oladi.
3. “Nusxalash”ni bosing va matnni chatga yuboring.
4. Asosiy oynadagi hasharot belgisi ham oxirgi Flutter/kamera hisobotini ochadi.

Hisobot tepasida patch=camera-fix-2026-10-26-v1 bo‘lishi kerak. Native probe ham
shu patchni qaytaradi. MissingPluginException chiqsa yangi native qism APKga
kirmagan bo‘lishi mumkin — faqat Dartni yangilash/hot reload yetarli emas.

Bosqichlarni talqin qilish:

| Hisobot | Nimani bildiradi? |
| --- | --- |
| permission.status/result | Android runtime ruxsatining haqiqiy holati |
| android.camera2.probe | Kamera ruxsati, model va Android ko‘rgan kameralar |
| start.configure | ML Kit yoki kamerani tanlash sozlamasidagi native exception |
| provider.initialize | CameraX providerini tayyorlashdagi asl exception |
| preview.surface | Preview uchun Flutter/Android surface yaratish xatosi |
| analysis.build | Kamera kadr tahlili konfiguratsiyasi xatosi |
| camera.bind_to_lifecycle | Kamerani activity/lifecyclega ulashdagi asl exception |
| analysis.resolution | Kamera/tahlil o‘lchamlari olinmagan yoki mos kelmagan |
| camera.start.pending | Native start hali javob bermagan; aniq sabab hali noma’lum |
| camera.plugin.error | Kutubxona kodi, native_code, native_message va native_details |
| android.analysis.counters | Kamera kadr yuboryaptimi, ML Kit ishlayaptimi? |
| frames_received=0 | Shu sessiyada tahlilga hali kadr kelmagan |
| mlkit_successes>0, barcodes_detected_count=0 | Tahlil ishlagan, ammo kod topilmagan |
| analysis.mlkit/pipeline | Kadrni tahlil qilishdagi asl exception |
| flutter.framework.error/unhandled.error | Flutterdagi ushlangan texnik xato va stack |

Bu hisoblagichlar sababni avtomatik taxmin qilish o‘rniga bosqichni ajratadi.
Masalan, frames_received=0ning o‘zi kamera ruxsati yo‘q degani emas.

## Tekshiruv natijasi va chegaralar

- Lokal Dart SDK 3.12.2 bilan 10 ta mustaqil kamera regressiya holati o‘tdi.
  Takroriy resume, startup paytida pause/close, retry, error holatlari,
  navbatning tiklanishi va diagnostika chegarasi tekshirildi.
- O‘zgargan Dart kodlari lokal analyzer orqali xatosiz tekshirildi.
- Butun lib statik tahlilida error/warning yo‘q; avvaldan mavjud lint va
  eskirgan API haqida informatsion eslatmalar bor.
- Android/Kotlin kodi kompilyatsiyasi, APK yig‘ilishi va real qurilma testi
  bajarilmagan. Fizik kameraning ishlashi hali tasdiqlanmagan.
- Flutter vositasining ishga tushishi cloud metadata manziliga murojaat
  urinishi sabab avtomatik xavfsizlik nazorati tomonidan rad etildi.
  U chetlab o‘tilmadi. Statik tahlil va Flutter engine talab qilmaydigan yuqoridagi core testlar
  lokal Dart bilan bajarildi.

Kamera ochilsa ham mahsulot topilmasa, bu boshqa zanjir: shtrix-kod qiymati,
mahsulot bazasi va POS qidiruvi tekshiriladi. Hisobot barcode qiymatini saqlamaydi.
