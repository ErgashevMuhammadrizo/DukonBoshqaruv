from django.db import migrations


def preserve_legacy_trial(apps, schema_editor):
    Plan = apps.get_model('core', 'SubscriptionPlan')
    Audit = apps.get_model('core', 'AuditLog')
    if not Audit.objects.filter(action__in=['admin_plan_saved', 'django_admin_subscriptionplan_saved']).exists():
        Plan.objects.filter(code='standard', trial_days=0).update(trial_days=30)


class Migration(migrations.Migration):
    dependencies = [('core', '0007_billing_plan_name_snapshots')]
    operations = [migrations.RunPython(preserve_legacy_trial, migrations.RunPython.noop)]
