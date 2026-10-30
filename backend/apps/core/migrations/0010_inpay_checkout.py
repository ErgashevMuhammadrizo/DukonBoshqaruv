from django.db import migrations, models
class Migration(migrations.Migration):
    dependencies = [('core', '0009_product_deleted_at')]
    operations = [
        migrations.AddField(model_name='paymentrecord', name='checkout_url', field=models.URLField(max_length=500, blank=True)),
        migrations.AddField(model_name='paymentrecord', name='purchased_months', field=models.PositiveSmallIntegerField(default=1)),
    ]
