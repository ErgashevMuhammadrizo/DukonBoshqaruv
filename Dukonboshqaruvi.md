# Do‘kon Boshqaruvi — loyiha holati

**Ko‘rib chiqilgan sana:** 2026-10-22  
**Holat:** ishlaydigan MVP yo‘nalishidagi loyiha; productionda ishlatishga tayyor deb hisoblamang. Xavfsizlikka oid bir nechta startup va account-creation muammolari tuzatildi, lekin eski muhitdagi credentiallarni rotatsiya qilish hamda deployment tekshiruvlari baribir zarur.

Ushbu hujjat repozitoriydagi Flutter va Django kodini hamda mavjud loyiha hujjatlarini ko‘rib chiqib tuzildi. Bu barcha qurilma va serverlarda bajarilgan end-to-end sinov hisoblanmaydi. “Kodda bor” degani ayni paytda har bir muhitda muammosiz ishlashi isbotlangan degani emas.

## Loyiha nimalardan iborat

- **Mobil/mijoz ilovasi:** Flutter, Dart 3.5+, Riverpod. Asosiy kod `dokon_boshqaruv/lib/` ichida.
- **Server:** Django va Django REST Framework, API prefiksi `/api/v1/`.
- **Ma’lumotlar bazasi:** SQLite lokal ishlab chiqish uchun; PostgreSQL deployment uchun sozlanishi mumkin.
- **Mahalliy offline saqlash:** Flutter ilovasida SQLite asosidagi mahsulot keshi va sotuvlar navbati.
- **Veb sahifa:** Django template asosidagi tanishtiruv sahifasi.
- **API hujjatlari:** `/api/v1/schema/` va `/api/v1/docs/`.

## Ishlayotgan yoki kodda amalga oshirilgan qismlar

### Foydalanuvchi va kirish

- Login, JWT access/refresh tokenlari, tokenni yangilash va logout endpointlari.
- Rolga qarab superadmin paneli yoki do‘kon bosh sahifasiga yo‘naltirish.
- Aktivatsiya kodi orqali hisobni faollashtirish va parol o‘rnatish.
- Tizim ichida parolni almashtirish, parol siyosati va tokenlarni bekor qilish.
- Superadmin foydalanuvchi/do‘kon yaratishi hamda bir martalik aktivatsiya yoki tiklash kodi chiqarishi.
- Yangi do‘kon foydalanuvchisi aktivatsiyagacha nofaol, Django Admin huquqisiz va foydalaniladigan parolsiz yaratiladi; activation kodi yangi parolni belgilaydi.
- API ma’lumotni foydalanuvchiga tegishli do‘kon doirasida qaytarishga mo‘ljallangan.

### Mahsulot va ombor

- Mahsulot va toifalarni ko‘rish, yaratish, tahrirlash va mahsulotni arxivlash.
- SKU/shtrix-kod, birlik, xarid/sotuv narxi, qoldiq va minimal qoldiq maydonlari.
- Mahsulot qidirish, boshlang‘ich qoldiq va keyingi ombor tuzatishlarini harakat sifatida qayd etish.
- JPG/PNG/WebP mahsulot rasmi yuklash (5 MB limit) va ilovada ko‘rsatish.
- Qoldiq harakati tarixi endpointi va kam qolgan/tugagan mahsulotlar hisobotlari.
- Mahsulot rasmlari Django media papkasida saqlanadi; media route so‘rov vaqtida joriy `MEDIA_ROOT`dan foydalanadi. Productionda media saqlash joyini alohida sozlash kerak.

### Kassa va hisobot

- Savatga mahsulot kiritish, miqdorni o‘zgartirish, chegirma va naqd/karta to‘lovini kiritish.
- Shtrix-kodni qo‘lda/USB skaner bilan kiritish oqimi; kodda kamera skaneri integratsiyasi ham mavjud.
- Server narx va ombor qoldig‘ini qayta tekshiradi, sotuvni tranzaksiya ichida yozadi va takror so‘rovga qarshi `operation_id` ishlatadi.
- Sotuvlar tarixi va chek tafsilotlari.
- Sana oralig‘i bo‘yicha tushum, sotuvlar soni, o‘rtacha chek, to‘lov taqsimoti, top mahsulotlar va kunlik hisobot.

### Offline ishlash

- Mahsulotlar lokal SQLite keshiga yoziladi.
- Offline sotuvlar navbatga yozilib, keyin API orqali yuboriladi; ziddiyat bo‘lsa navbat elementi saqlanadi.
- Serverga yuborilgan sotuvni idempotent qayta yuborish uchun operation ID ishlatiladi.

## Hozircha yo‘q yoki to‘liq emas

- **To‘liq offline savdo kafolati yo‘q.** Bir nechta qurilma offline sotganda serverda qoldiq yetmasligi mumkin; sinxronlashda ziddiyat qaytadi. Fon rejimida avtomatik sinxronlash ko‘rinmaydi.
- **Web build hozirgi SQLite plugin bilan mos emas.** Flutter Web uchun alohida saqlash adapteri va API/CORS yoki reverse proxy sozlamasi kerak.
- **Kvitansiya chop etish va PDF eksporti** interfeysda tugallanmagan (ekranda “tez orada” xabari bor).
- **Yordam markazi va ombor tarixining ayrim UI oqimlari** tugallanmagan; endpoint bo‘lsa ham barcha ekranlarda foydalanish yo‘q.
- **Obuna/to‘lov:** reja va obuna holatini o‘qish endpointlari bor, lekin to‘liq to‘lov provayderi va admin tasdiqlash oqimi ko‘rinmaydi. Obunani tekshirish barcha yozuvchi endpointlarga qo‘llanmagan.
- **Mahsulot qaytarish/refund** qoidasi va oqimi mavjud emas.
- **Hisobni tiklash:** backendda admin chiqaradigan reset kodi va tasdiqlash endpointi bor, ammo foydalanuvchi uchun to‘liq reset-credential chiqarish UI oqimi hujjatlarda tugallanmagan deb ko‘rsatilgan.
- **Qurilmaga xos tekshiruvlar:** Android, iOS, Web va Linuxda kamera, USB skaner, rasm yuklash va POS oqimini alohida sinash kerak.
- **Backup/restore, kuzatuv, audit nazorati va production media storage** deployment darajasida yakuniy tekshiruv talab qiladi.

## Productionga chiqishdan oldin bajariladigan muhim ishlar

1. **Eski admin/demo ma’lumotlarini yangilang.** Avvalgi bootstrap `admin` parolini ma’lum qiymatga qayta o‘rnatgan. Kod endi buni qilmaydi va `DEBUG` standart bo‘yicha o‘chiq; ammo shu qiymat eski real yoki ulashilgan muhitda ishlatilgan bo‘lishi mumkin. Qayta ishlatilgan admin parolini almashtiring, token va sessiyalarni bekor qiling, activation/reset kodlari tarqalgan bo‘lsa ularni yaroqsiz qiling.
2. **Demo ma’lumotlarini ataylab yoqish.** Startup va migration endi user yaratmaydi. Demo account faqat `APP_ENV=development`, `DEBUG=1`, `ENABLE_DEMO_BOOTSTRAP=1`, alohida `DEMO_USERNAME`/`DEMO_PASSWORD` bilan va `python manage.py bootstrap_demo` buyrug‘i chaqirilganda yaratiladi. Production muhiti bu flagni qabul qilmaydi.
3. **Eski test qaydlarini tozalash.** `TESTING_RESULTS.md`dagi account va bir martalik credential qiymatlari olib tashlandi; fayl qayta ishlatmaslik va rotatsiya qilish talabini eslatadi.
4. **Deployment sozlamalari:** production `DEBUG=0`, noyob maxfiy `DJANGO_SECRET_KEY`, cheklangan `ALLOWED_HOSTS`, HTTPS, CORS, PostgreSQL, statik/media fayl servisi va restore qilinadigan zaxira nusxalarini tekshirish.
5. **Tenant va ruxsatlar xavfsizligi:** mavjud API testlari boshqa do‘kon mahsulotini o‘qish/sotish va reportlar uchun do‘kon scope’ini tekshiradi. Release oldidan qolgan har bir endpoint hamda superadmin ruxsatini alohida ko‘rib chiqing.

## Keyingi ishlar — tavsiya etilgan tartib

### P0 — xavfsizlik va ishga tushirish

- Demo bootstrapni productiondan ajratish, admin parolini startupda o‘zgartirmaslik, yangi accountlarni aktivatsiyagacha nofaol/non-staff saqlash va login formadagi demo qiymatlarini olib tashlash bajarildi; regression testlar qo‘shildi.
- `TESTING_RESULTS.md` tozalandi. Avvalgi qiymatlar real yoki ulashilgan muhitda ishlatilgan bo‘lsa, tegishli parol/token/kodlarni rotatsiya qiling.
- Debug APK muvaffaqiyatli yig‘ildi. Real Android qurilmada kamera va USB skaner bilan tekshirish kerak; Flutter builddagi `mobile_scanner` Kotlin Gradle Plugin ogohlantirishini plugin yangilanganda kuzatish lozim.
- Migrations, deployment, maxfiy kalitlar va backup/restore tartibini release checklist bilan tekshirish.

### P1 — savdoning ishonchliligi

- Authenticated backend API oqimi barcode qidiruvi → sotuv → qoldiq → tarix → hisobot bilan avtomatik tekshirildi; login va aktivatsiya alohida testlangan. Real qurilma va kamera/USB skaner sinovi hali kerak.
- Offline navbatni qo‘lda boshqarish, konfliktni tushunarli ko‘rsatish, takroriy yuborish va qoldiqning mos kelmasligini hal qilish.
- Subscription enforcementni barcha yozuvchi endpointlarga qo‘llash.
- Hisobotning kunlik tushumi chegirmadan keyingi `Sale.total` bo‘yicha, top mahsulot summalari esa sale chegirmasini qatorlarga mutanosib taqsimlab hisoblanadi. Ikki mahsulotli chegirmali sotuv regression test bilan tekshiriladi.
- Sotuvni bekor qilish/qaytarish va audit talablarini biznes qoidalari bilan belgilash.

### P2 — foydalanish va platformalar

- Kvitansiyani printerga chiqarish va PDF eksport.
- Kamera/USB shtrix-kod skanerini qo‘llab-quvvatlanadigan Android qurilmalarda tekshirish.
- Web uchun mos lokal saqlash, API origin/proxy va CORS sozlamalari.
- Ombor harakatlari tarixi, profil/sozlamalar/yordam ekranlarini yakunlash.
- Sotuvlar ko‘payganda API pagination va katta katalog ishlashini yaxshilash.

## Tekshiruvlar holati

- `backend/.venv/bin/python manage.py test` — **14 test muvaffaqiyatli**; startup credential, production demo cheklovi, aktivatsiya, do‘kon scope’i, barcode → sale → stock → history → report, chegirmali tushum va chegirmani mahsulotlar orasida taqsimlash, takroriy so‘rov va rasmni olish tekshirildi.
- `backend/.venv/bin/python manage.py check` — muvaffaqiyatli; `makemigrations --check --dry-run` — migration o‘zgarishi talab qilinmadi.
- `flutter test` — **4/4 muvaffaqiyatli**, login va parol maydonlari bo‘shligini tekshiruvchi test bilan.
- `flutter build apk --debug` — muvaffaqiyatli. `mobile_scanner` KGP mosligi haqida ogohlantirish qoldi.
- `flutter analyze` — **61 ta info/lint**; compile xatosi ko‘rsatmadi, ammo exit 1 bilan tugadi. Yangi login va account oqimida compile xatosi yo‘q.
- API darajasida barcode qidiruvi tekshirildi; real kamera/USB skanerda butun oqim hali sinovdan o‘tkazilmadi.
- `README.md`, `PROGRESS.md`, `QUALITY_AUDIT.md` va `TESTING_RESULTS.md`da eski ma’lumotlar bo‘lishi mumkin. Release oldidan ularni ushbu hisobotga moslang.

## Muhim fayllar

- Flutter: `dokon_boshqaruv/lib/`
- Backend API va biznes logikasi: `backend/apps/core/`
- Django sozlamalari va URL: `backend/config/`
- API qo‘llanmasi: `docs/API.md`
- Offline protokoli: `docs/OFFLINE_SYNC.md`
- Xavfsizlik: `docs/SECURITY.md`
- Deployment: `docs/DEPLOYMENT.md`
- Oldingi audit: `QUALITY_AUDIT.md`
- Oldingi test qaydlari: `TESTING_RESULTS.md` (eski qiymatlar olib tashlangan; qayta ishlatilgan bo‘lsa rotatsiya qiling)

## Yakun

Loyihada do‘konning asosiy oqimlari — mahsulot/ombor, kassa, sotuvlar va hisobotlar uchun jiddiy asos bor. Eng katta keyingi ehtiyojlar: administrator/demo hisoblarini xavfsiz boshqarish, offline sinxronlash ziddiyatlari, obuna va ruxsat nazorati, platformalarda amaliy sinov hamda production deployment. Hozirgi kod va hujjatlar ilovani productionga tayyor deb tasdiqlamaydi.
