from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("tenants", "0004_tenant_ai_assistant_prompt"),
    ]

    operations = [
        migrations.AddField(
            model_name="tenantspecialty",
            name="description",
            field=models.TextField(blank=True, default=""),
        ),
    ]

