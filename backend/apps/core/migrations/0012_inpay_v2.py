from django.db import migrations, models
class Migration(migrations.Migration):
    dependencies = [('core', '0011_plan_descriptions')]
    operations = [
        migrations.AddField(model_name='paymentrecord', name='provider_livemode', field=models.BooleanField(null=True, blank=True)),
        migrations.AddField(model_name='paymentrecord', name='provider_version', field=models.CharField(max_length=4, default='v1')),
        migrations.AddField(model_name='paymentrecord', name='provider_payload', field=models.JSONField(default=dict, blank=True)),
    ]
