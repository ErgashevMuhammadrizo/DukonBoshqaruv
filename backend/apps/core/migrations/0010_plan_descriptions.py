from django.db import migrations

def describe(apps, schema_editor):
    Plan = apps.get_model('core', 'SubscriptionPlan')
    descriptions = {
      'standard': 'Kichik do‘kon uchun kundalik ishlar: mahsulot katalogi, POS orqali savdo, savdolar tarixi, asosiy hisobotlar va qarz daftari. Tarif kartasida mahsulot hamda foydalanuvchi limitlari ko‘rsatilgan. Birinchi faollashtirishda 30 kun sinov. Oylik obuna — muntazam ishlash uchun, yillik narx mavjud bo‘lsa — uzoq muddat foydalanish uchun.',
      'pro': 'Katalogi o‘sib borayotgan do‘konlar uchun: STANDARD imkoniyatlari va ko‘proq mahsulot bilan ishlashga mo‘ljallangan tarif. Savdo, ombor qoldig‘i va qarzlarni bir joyda kuzatib boring. Katta assortimentni yagona katalogda saqlash mahsulot topish va hisob yuritishni qulaylashtiradi. Aniq limitlar tarif kartasida ko‘rsatilgan.',
      'vip': 'Keng assortimentli do‘konlar uchun: PRO imkoniyatlari va katalogdagi eng yuqori mahsulot limiti. Mahsulotlar, savdolar, qoldiqlar va qarzlar bo‘yicha kundalik hisobni bir tizimda yuriting. Ko‘p mahsulot saqlash zarur bo‘lgan biznesga mos. Aniq narx, foydalanuvchi va mahsulot limitlari tarif kartasida ko‘rsatiladi.'}
    for code, text in descriptions.items():
        Plan.objects.filter(code=code, description='').update(description=text)

class Migration(migrations.Migration):
    dependencies = [('core', '0009_inpay_checkout')]
    operations = [migrations.RunPython(describe, migrations.RunPython.noop)]
