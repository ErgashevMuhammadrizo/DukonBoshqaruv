from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [('core', '0008_standard_trial_default')]
    operations = [migrations.AddField(model_name='product', name='deleted_at', field=models.DateTimeField(blank=True, null=True, db_index=True))]
