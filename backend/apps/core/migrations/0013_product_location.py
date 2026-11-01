from django.db import migrations, models
class Migration(migrations.Migration):
    dependencies = [('core', '0012_inpay_v2')]
    operations = [migrations.AddField(model_name='product',name=name,
        field=models.CharField(max_length=100,blank=True,default=''))
        for name in ['warehouse','section','shelf']]
