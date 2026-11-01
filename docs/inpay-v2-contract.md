````
# inPAY REST API v2 — Sun'iy Intellekt va LLM uchun Bilimlar Kutubxonasi

> inPAY — O'zbekiston bozoridagi Stripe-standartidagi universal to'lov agregatori va Hosted inPAY Checkout v2 to'lov tizimi. Ushbu fayl AI agentlari, LLM modellar va dasturchilar uchun inPAY API v2 bilan integratsiya qilishning to'liq va aniq texnik qo'llanmasi hisoblanadi.

## Asosiy Ma'lumotlar va Arxitektura

- **Tizim Falsafasi**: Savdogar (merchant) alohida to'lov provayderlari (Click, Payme, Uzcard, Humo, Visa, Mastercard, Paynet) bilan emas, yagona inPAY Payment API va zamonaviy **Hosted inPAY Checkout v2** sahifasi bilan ishlaydi.
- **Base URL**: `https://inpay.uz/api/v2/`
- **Protokol**: HTTPS POST / GET (JSON payload, UTF-8 kodlash)
- **Valyuta va Summa**: `UZS` (O'zbekiston so'mi). Summa to'g'ridan-to'g'ri so'mda ifodalanadi: `amount: 50000` = 50,000 UZS. Minimal miqdor: 1,000 UZS.
- **Autentifikatsiya**: HTTP Header `Authorization: Bearer <SECRET_KEY>` yoki `X-InPAY-Secret-Key: <SECRET_KEY>`
  - Jonli kalitlar: `sk_live_...` (ishlab chiqarish uchun)
  - Test kalitlar: `sk_test_...` (sandbox va simulyatsiya uchun)
- **Idempotentlik**: `Idempotency-Key: <unikal-uuid>` headeri orqali tarmoq uzilishlarida takroriy to'lovlardan 100% kafolatlangan himoya (24 soat keshlanadi).
- **Kuzatuvchanlik**: Har bir javobda `X-Request-Id: req_...` sarlavhasi qaytariladi.

---

## Asosiy To'lov Oqimi (End-to-End Hosted Checkout Flow)

1. **To'lov Yaratish**: Merchant serveri `POST /api/v2/payments/` chaqirib, buyurtma yaratadi va API javobidan `checkout_url` (`https://inpay.uz/checkout/{id}`) oladi.
2. **Checkout v2 Sahifasiga Yo'naltirish**: Savdogar xaridor brauzerini `checkout_url` manziliga yo'naltiradi.
3. **Hosted inPAY Checkout v2 Sahifasi**:
   - Sahifa yuqorisida yashil **`⚡ v2`** nishoni aks etadi.
   - O'zbekistonning barcha to'lov tizimlari mavjud: **Uzcard, Humo, Click, Payme, Visa, Mastercard, Paynet**.
   - Mijoz o'ziga qulay tizimni tanlaydi va to'lovni tasdiqlaydi.
4. **To'lov Yakunlanishi**:
   - inPAY to'lov statusini `succeeded` qiladi (ichki `transactions.status = 'success'`).
   - inPAY savdogar serverining `callback_url` manziliga imzolangan HMAC-SHA256 Webhook (`payment.succeeded`) yuboradi.
   - inPAY mijoz brauzerini avtomatik ravishda merchantning `return_url` manziliga qaytaradi.

---

## 1. To'lov Yaratish (Create Payment)

### Endpoint
`POST https://inpay.uz/api/v2/payments/`

### Sarlavhalar (Headers)
```http
Authorization: Bearer sk_live_your_secret_key
Content-Type: application/json
Idempotency-Key: 7b9a5281-4e2b-4fa8-bf12-984e72cb8019
```

### So'rov Tanasi (Request Body)
```json
{
  "amount": 50000,
  "currency": "UZS",
  "description": "Buyurtma #1084 uchun to'lov",
  "return_url": "https://merchant.uz/orders/1084/success",
  "webhook_url": "https://merchant.uz/api/inpay_webhook",
  "sub_merchant": "sm0a1b2c3d4e",
  "application_fee": 3000,
  "metadata": {
    "order_id": "1084"
  }
}
```

> **Platforma rejimi (ixtiyoriy).** `sub_merchant` — to'lovni o'z platformangizdagi faol sub-merchant'ga biriktiradi (`sub_id`, masalan `sm…`). Sub-merchant kabinetning «Sub-merchantlar» bo'limida yaratiladi; hisobot va analitikada alohida ajratiladi. Noto'g'ri yoki faolsiz `sub_id` yuborilsa — `400 sub_merchant_invalid` xatosi qaytadi. `metadata.sub_merchant` ko'rinishida ham uzatish mumkin.
>
> **Split — `application_fee` (ixtiyoriy).** Shu to'lovdan platforma oladigan komissiya (so'm). Faqat `sub_merchant` bilan ishlaydi. Ko'rsatilmasa — sub-merchant sozlamasidagi foiz + qat'iy qiymatdan avtomatik hisoblanadi (yo'q bo'lsa — komissiyasiz). To'lov summasidan kichik bo'lishi shart, aks holda `400 application_fee_too_large`. Sub-merchant neti = `amount − application_fee`.

### Muvaffaqiyatli Javob (Response 200 OK)
```json
{
  "success": true,
  "data": {
    "id": "47907909afd21a28",
    "object": "payment",
    "amount": 50000,
    "currency": "UZS",
    "status": "requires_payment_method",
    "description": "Buyurtma #1084 uchun to'lov",
    "checkout_url": "https://inpay.uz/checkout/47907909afd21a28",
    "return_url": "https://merchant.uz/orders/1084/success",
    "livemode": true,
    "metadata": {
      "order_id": "1084"
    },
    "created": 1727685600,
    "latest_attempt": null
  }
}
```

Merchant mijozni to'lovni amalga oshirish uchun qaytgan `checkout_url` manziliga yo'naltiradi.

---

## 2. To'lov Holatini Tekshirish (Get Payment)

### Endpoint
`GET https://inpay.uz/api/v2/payments/?id=47907909afd21a28`

### Javob (Response 200 OK)
```json
{
  "success": true,
  "data": {
    "id": "47907909afd21a28",
    "object": "payment",
    "amount": 50000,
    "currency": "UZS",
    "status": "succeeded",
    "description": "Buyurtma #1084 uchun to'lov",
    "checkout_url": "https://inpay.uz/checkout/47907909afd21a28",
    "return_url": "https://merchant.uz/orders/1084/success",
    "livemode": true,
    "metadata": {
      "order_id": "1084"
    },
    "created": 1727685600,
    "latest_attempt": {
      "id": 142,
      "provider": "payme",
      "status": "succeeded",
      "error_code": null,
      "error_message": null
    }
  }
}
```

---

## 3. To'lovni Bekor Qilish (Cancel Payment)

### Endpoint
`POST https://inpay.uz/api/v2/payments/cancel`

### So'rov Tanasi
```json
{
  "id": "47907909afd21a28"
}
```

### Javob (Response 200 OK)
```json
{
  "success": true,
  "data": {
    "id": "47907909afd21a28",
    "object": "payment",
    "amount": 50000,
    "currency": "UZS",
    "status": "canceled",
    "livemode": true
  }
}
```

---

## 4. Kassa Balansi (Merchant Balance)

### Endpoint
`GET https://inpay.uz/api/v2/balance/`

### Javob (Response 200 OK)
```json
{
  "success": true,
  "data": {
    "object": "balance",
    "available": [
      {
        "amount": 14500000,
        "currency": "UZS"
      }
    ],
    "pending": [
      {
        "amount": 250000,
        "currency": "UZS"
      }
    ],
    "livemode": true
  }
}
```

---

## 5. Webhook Replay (Qayta Yuborish)

### Endpoint
`POST https://inpay.uz/api/v2/webhooks/replay/`

### So'rov Tanasi
```json
{
  "event_id": "evt_839201ab9c02d84716e"
}
```

### Javob (Response 200 OK)
```json
{
  "success": true,
  "replayed": true,
  "http_status": 200
}
```

---

## 7. Webhook Hodisalari va HMAC-SHA256 Xavfsizligi

To'lov holati o'zgarganda inPAY savdogar serverining `callback_url` manziliga avtomatik POST so'rov yuboradi.

### Webhook Sarlavhalari (Headers)
```http
Content-Type: application/json
X-InPAY-Signature: t=1727685600,v1=9f83a48e...3b21
X-InPAY-Timestamp: 1727685600
X-InPAY-Event: payment.succeeded
```

### Webhook Payload Namunasi
```json
{
  "id": "evt_839201ab9c02d84716e",
  "object": "event",
  "type": "payment.succeeded",
  "created": 1727685600,
  "livemode": true,
  "data": {
    "object": {
      "id": "47907909afd21a28",
      "merchant_id": "92598",
      "amount": 50000,
      "currency": "UZS",
      "status": "succeeded",
      "description": "Buyurtma #1084 uchun to'lov",
      "checkout_url": "https://inpay.uz/checkout/47907909afd21a28",
      "return_url": "https://merchant.uz/orders/1084/success",
      "webhook_url": "https://merchant.uz/api/inpay_webhook",
      "metadata": {
        "order_id": "1084"
      },
      "is_test": 0,
      "created_at": "2026-09-30 11:00:00"
    }
  }
}
```

### Webhook Imzo Siri (`$merchant_webhook_secret`)
Har bir kassaning O'Z imzo siri bor (`whsec_...`). Uni jonli (`sk_live_`) kalit bilan olasiz:
```http
GET /api/v2/webhooks/secret/
Authorization: Bearer sk_live_...
```
Sirni almashtirish (eski sir darhol bekor bo'ladi):
```http
POST /api/v2/webhooks/secret/
{"action": "rotate"}
```

### Webhook Jurnali va Qayta Yuborish
- `GET /api/v2/webhooks/?limit=20&status=retrying` — kassangizga yuborilgan hodisalar ro'yxati (holat, HTTP javob kodi, urinishlar soni).
- `GET /api/v2/webhooks/?event_id=evt_...` — bitta hodisa: yuborilgan payload va serveringiz javobi bilan.
- `POST /api/v2/webhooks/replay/` `{"event_id": "evt_..."}` — hodisani yangi vaqt belgisi va imzo bilan qayta yuboradi.

Webhook manzili ommaviy internetda ochiq bo'lishi shart (http/https, 80/443/8080/8443 port). Ichki tarmoq manzillariga (localhost, 10.x, 192.168.x va h.k.) webhook yuborilmaydi.

### Idempotency-Key
Bir xil `Idempotency-Key` bilan aynan bir xil so'rov qayta yuborilsa — avvalgi javob qaytadi (yangi to'lov yaratilmaydi). Shu kalit BOSHQA mazmundagi so'rov bilan ishlatilsa — `409 idempotency_key_reused`.

### Imzoni Tekshirish Algoritmi (PHP Namunasi):
```php
$payload = file_get_contents('php://input');
$sigHeader = $_SERVER['HTTP_X_INPAY_SIGNATURE'] ?? '';

// t=TIMESTAMP,v1=SIGNATURE ajratib olish
if (!preg_match('/t=(\d+),v1=([a-f0-9]+)/', $sigHeader, $matches)) {
    http_response_code(400);
    exit('Imzo sarlavhasi topilmadi');
}
$timestamp = $matches[1];
$signature = $matches[2];

// Tolerans tekshiruvi (5 daqiqa)
if (abs(time() - (int)$timestamp) > 300) {
    http_response_code(400);
    exit('Vaqt eskirgan');
}

$expected = hash_hmac('sha256', "{$timestamp}.{$payload}", $merchant_webhook_secret);
if (!hash_equals($expected, $signature)) {
    http_response_code(401);
    exit('Imzo yaroqsiz');
}

// To'lovni tasdiqlash
http_response_code(200);
echo json_encode(['received' => true]);
```

---

## 8. Two-Phase Pre-Check (Ikki Bosqichli Tekshiruv)

Agar merchant sozlamalarida `precheck_url` ko'rsatilgan bo'lsa, inPAY mijoz kartasidan pul yechishdan oldin merchant serveriga tekshiruv so'rovi yuboradi:

```http
POST {precheck_url}
Content-Type: application/json
X-InPAY-Event: order.precheck

{
  "action": "check_order",
  "order_id": "1084",
  "amount": 50000,
  "merchant_id": "92598",
  "timestamp": 1727685600
}
```
Merchant serveri `{"allow": true}` yoki tovar tugagan bo'lsa `{"allow": false, "message": "Mahsulot qolmagan"}` qaytaradi.

---

## 9. Sandbox Test Rejimi va Virtual Kartalar

Sinov paytida `sk_test_...` kaliti ishlatiladi:

| Test Karta Raqami | Amal Muddati | SMS Kod | Natija (Status) |
| :--- | :---: | :---: | :--- |
| `8600 0000 0000 0001` | 12/28 | Ixtiyoriy (1111) | `succeeded` — Muvaffaqiyatli to'lov |
| `8600 0000 0000 0002` | 12/28 | Ixtiyoriy | `failed` — Mablag' yetarli emas (`insufficient_funds`) |
| `8600 0000 0000 0003` | 01/20 | Ixtiyoriy | `failed` — Karta muddati tugagan (`expired_card`) |
| `8600 0000 0000 0004` | 12/28 | Noto'g'ri | `failed` — OTP 3DS xatolik (`otp_failed`) |

---

## 10. To'lov Statuslari Xaritasi

| API v2 Status | API v1 Status | transactions Bazasi | Tavsif |
| :--- | :---: | :---: | :--- |
| `requires_payment_method` | `pending` | `pending` | To'lov yaratilgan, xaridor Checkout v2 sahifasida to'lov usulini tanlashi kutilmoqda. |
| `processing` | `pending` | `pending` | Karta ma'lumotlari kiritilgan, OTP / 3DS tekshiruvi ketmoqda. |
| `succeeded` | `success` | `success` | To'lov muvaffaqiyatli amalga oshirildi va pul hisobga olindi. |
| `canceled` | `canceled` | `canceled` | To'lov bekor qilingan yoki muddati o'tgan. |
| `failed` | `failed` | `failed` | To'lov amalga oshmadi (mablag' yetishmasligi, rad etilgan karta va h.k.). |

---

## 11. Standart Xatolik Formatlari (Error Envelopes)

```json
{
  "success": false,
  "error": {
    "type": "invalid_request_error",
    "code": "missing_parameter",
    "message": "'amount' maydoni majburiy va 1000 dan katta bo'lishi kerak.",
    "param": "amount",
    "request_id": "req_4f9ce037"
  }
}
```

---

## 12. Xizmat To'lovlari Webhook'lari (Service Payments)

inPAY mobil ilovasining **«Xizmatlar» (Services)** bo'limi orqali mijoz kassaning hisobiga to'g'ridan-to'g'ri to'lov qiladi (o'yin hisobi, internet, TV, kommunal va h.k.). Mijoz kassani tanlaydi, ID (login / username / shartnoma raqami) kiritadi — inPAY savdogar serveriga webhook yuboradi. Ikkala xabar ham oddiy to'lov webhook'lari bilan **bir xil imzo sxemasi** (`X-Inpay-Signature: t=…,v1=…`) va **bir xil sir** (`whsec_…`, `GET /api/v2/webhooks/secret/`) bilan ishlaydi (7-bo'limga qarang).

### Hodisalar

| Hodisa | Tur | Qachon |
| :--- | :---: | :--- |
| `service.account.check` | sinxron | Mijoz ID kiritib «Tekshirish» bosganda. Javobda hisob egasi ismini qaytaring. |
| `service.payment.succeeded` | asinxron | To'lov muvaffaqiyatli o'tgach. Hisobni shu yerda to'ldiring (`tx_id` bo'yicha idempotent). |

### 12.1. service.account.check (Hisobni Oldindan Tekshirish)

Mijoz ID kiritgach, inPAY savdogar `webhook_url` iga quyidagini yuboradi. Serveringiz hisobni topib, egasining ismini qaytaradi (**sinxron** — 8 soniya ichida JSON javob kerak). Bu faqat qidiruv, pul o'tganini anglatmaydi.

**So'rov:**
```http
POST {webhook_url}
Content-Type: application/json
X-Inpay-Event: service.account.check
X-Inpay-Signature: t=1790511600,v1=9f83a48e…3b21
X-Inpay-Timestamp: 1790511600
```
```json
{
  "id": "evt_…",
  "object": "event",
  "type": "service.account.check",
  "created": 1790511600,
  "livemode": true,
  "data": {
    "object": {
      "object": "service_account_check",
      "merchant_id": "94055",
      "service_type": "game",
      "fields": { "game_id": "PLAYER777" }
    }
  }
}
```

**Javob — hisob topildi (200 OK):**
```json
{
  "ok": true,
  "name": "Bekzod Rahimov",
  "details": [
    { "label": "Hisob",  "value": "PLAYER777" },
    { "label": "Server", "value": "Asia" },
    { "label": "Daraja", "value": "42" }
  ],
  "amount": 25000
}
```
- `name` — majburiy (ilova yashil kartada ko'rsatadi). Muqobil: `account_name`, `client`, `full_name`.
- `details` — ixtiyoriy `[{label,value}]`; ilova ism ostida chiqaradi.
- `amount` — ixtiyoriy; berilsa summa maydoni avtomatik to'ladi (masalan qarzdorlik).

**Javob — topilmadi:**
```json
{ "ok": false, "error": "Bunday hisob topilmadi. ID ni tekshiring." }
```

### 12.2. service.payment.succeeded (To'lov Tasdig'i)

Mijoz muvaffaqiyatli to'lagach, inPAY shu xabarni yuboradi — **aynan shu yerda hisobni to'ldiring / xizmatni faollashtiring**. `2xx` qaytaring. `tx_id` bo'yicha idempotent bo'ling. Yetkazilmasa qayta yuboriladi (8 urinish) va `POST /api/v2/webhooks/replay/` orqali qayta yuborish mumkin; jurnali `GET /api/v2/webhooks/?type=service.payment.succeeded`.

```json
{
  "id": "evt_…",
  "object": "event",
  "type": "service.payment.succeeded",
  "created": 1790511660,
  "livemode": true,
  "data": {
    "object": {
      "object": "service_payment",
      "tx_id": "a1b2c3d4…",
      "merchant_id": "94055",
      "service_type": "game",
      "amount": 25000,
      "currency": "UZS",
      "fields": { "game_id": "PLAYER777" },
      "paid_at": "2026-10-19 14:32:05"
    }
  }
}
```

---

## Foydali Havolalar

- [To'liq Veb Hujjatlar](https://inpay.uz/api/v2/): Interaktiv developer sahifasi va Live Playground
- [Postman Kolleksiyasi](https://inpay.uz/api/v2/postman/): Tayyor JSON formatdagi API test to'plami
- [Kassa Balansi API](https://inpay.uz/api/v2/balance/): Joriy hisob qoldig'i ma'lumotlari
- [Webhook Replay](https://inpay.uz/api/v2/webhooks/replay/): O'tkazib yuborilgan hodisalarni qayta yuborish

````
