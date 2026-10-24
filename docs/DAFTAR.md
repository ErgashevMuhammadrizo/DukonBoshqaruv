# Daftar modulining joriy chegarasi

Daftar qarz yozuvlari POS savdolaridan mustaqil saqlanadi. Amaldagi checkout to‘lovni faqat naqd va karta summalari sifatida qabul qiladi; qarz holatini hamda mijoz identifikatorini saqlamaydi. Shu sabab POS orqali qarzga savdo yaratish hozircha yoqilmagan. Kelgusi integratsiyada `Sale` bilan `DebtRecord` o‘rtasida birga-bir havola va operation ID takrorlanishidan himoya kerak.

Daftar yozuvlari va to‘lovlari serverga darhol yuboriladi. Offline holatda ular mahalliy navbatga yozilmaydi va UI muvaffaqiyat deb ko‘rsatmaydi. Mavjud offline queue faqat savdolarni qabul qiladi.

Joriy versiyada qarz summasi/sababi va to‘lovlar tarixi ishlaydi. Mahsulot satrlari, mijoz katalogi, qarzni bekor qilish yoki tuzatish uchun reversal, alohida ruxsat rollari va audit tarixi API, kengaytirilgan sanali hisobotlar hamda pagination hali qo‘shilmagan. Mavjud auth modeli faqat do‘kon egasi va superuser rollarini taniydi; shu sabab endpointlar foydalanuvchining o‘z do‘koni bilan cheklangan.
