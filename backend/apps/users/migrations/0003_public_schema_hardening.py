from django.db import migrations

ENABLE_RLS_ON_PUBLIC_TABLES_SQL = """
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT schemaname, tablename
        FROM pg_tables
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', rec.schemaname, rec.tablename);
    END LOOP;
END;
$$;
"""

REVOKE_PUBLIC_SCHEMA_ACCESS_SQL = """
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT schemaname, tablename
        FROM pg_tables
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('REVOKE ALL ON TABLE %I.%I FROM anon, authenticated', rec.schemaname, rec.tablename);
    END LOOP;

    FOR rec IN
        SELECT sequence_schema, sequence_name
        FROM information_schema.sequences
        WHERE sequence_schema = 'public'
    LOOP
        EXECUTE format('REVOKE ALL ON SEQUENCE %I.%I FROM anon, authenticated', rec.sequence_schema, rec.sequence_name);
    END LOOP;

    FOR rec IN
        SELECT n.nspname AS schema_name,
               p.proname AS function_name,
               pg_get_function_identity_arguments(p.oid) AS function_args
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
    LOOP
        EXECUTE format(
            'REVOKE ALL ON FUNCTION %I.%I(%s) FROM anon, authenticated',
            rec.schema_name,
            rec.function_name,
            rec.function_args
        );
    END LOOP;
END;
$$;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon, authenticated;
"""


def harden_public_schema(apps, schema_editor):
    if schema_editor.connection.vendor != 'postgresql':
        return

    statements = [
        ENABLE_RLS_ON_PUBLIC_TABLES_SQL,
        REVOKE_PUBLIC_SCHEMA_ACCESS_SQL,
    ]
    with schema_editor.connection.cursor() as cursor:
        for sql in statements:
            cursor.execute(sql)


class Migration(migrations.Migration):

    dependencies = [
        ('appointments', '0003_blockedperiod_professionalavailability_and_more'),
        ('chat', '0003_chatroom_message_delete_patientinteraction'),
        ('financial', '0002_sessionpackage_transaction_delete_invoice'),
        ('medical_records', '0002_medicaldocument_medicalrecordaccesslog_and_more'),
        ('notifications', '0002_notification_notificationtoken_and_more'),
        ('patients', '0002_doctorpatientassignment'),
        ('post_op', '0003_postopjourney_postopchecklist_evolutionphoto_and_more'),
        ('referrals', '0001_initial'),
        ('tenants', '0002_tenantspecialty_default_duration_minutes'),
        ('users', '0002_goklinikuser_referral_code_goklinikuser_referred_by'),
    ]

    operations = [
        migrations.RunPython(harden_public_schema, reverse_code=migrations.RunPython.noop),
    ]
