from django.core.management.base import BaseCommand

from apps.tenants.models import Tenant, TenantSpecialty
from apps.users.models import GoKlinikUser


class Command(BaseCommand):
    help = "Seed Go Klinik demo data"

    def handle(self, *args, **options):
        tenant, _ = Tenant.objects.update_or_create(
            slug="goklinik-demo",
            defaults={
                "name": "GoKlinik Demo",
                "plan": Tenant.PlanChoices.PROFESSIONAL,
                "primary_color": "#0D5C73",
                "secondary_color": "#4A7C59",
                "accent_color": "#C8992E",
                "clinic_addresses": [
                    "Unidade Principal - Av. Demo, 1000",
                    "Unidade Norte - Rua Exemplo, 245",
                ],
                "is_active": True,
            },
        )
        self.stdout.write(self.style.SUCCESS(f"Tenant ready: {tenant.slug}"))

        master_email = "admin@goklinik.com"
        master_password = "GoKlinik2024!"
        master_user, created = GoKlinikUser.objects.get_or_create(
            email=master_email,
            defaults={
                "first_name": "GoKlinik",
                "last_name": "Admin",
                "tenant": tenant,
                "role": GoKlinikUser.RoleChoices.CLINIC_MASTER,
                "is_staff": True,
                "is_active": True,
            },
        )
        master_user.tenant = tenant
        master_user.role = GoKlinikUser.RoleChoices.CLINIC_MASTER
        master_user.is_staff = True
        master_user.is_active = True
        master_user.set_password(master_password)
        master_user.save()

        if created:
            self.stdout.write(self.style.SUCCESS(f"Master user created: {master_email}"))
        else:
            self.stdout.write(self.style.WARNING(f"Master user updated: {master_email}"))

        specialties = [
            ("Rinoplastia", "nose"),
            ("Mamoplastia", "heart"),
            ("Harmonizacao Facial", "sparkles"),
            ("Lipoaspiracao", "activity"),
            ("Blefaroplastia", "eye"),
            ("Botox", "zap"),
            ("Preenchimento", "droplet"),
            ("Peeling", "sun"),
        ]

        for order, (name, icon) in enumerate(specialties, start=1):
            TenantSpecialty.objects.update_or_create(
                tenant=tenant,
                specialty_name=name,
                defaults={
                    "specialty_icon": icon,
                    "is_active": True,
                    "display_order": order,
                },
            )
        self.stdout.write(self.style.SUCCESS("Tenant specialties synced."))

        doctors = [
            {
                "email": "dr.elif@goklinik.com",
                "first_name": "Elif",
                "last_name": "Yilmaz",
                "phone": "+90 555 100 0001",
                "crm_number": "TR-CRM-1001",
                "years_experience": 11,
                "bio": "Facial plastic surgeon focused on rhinoplasty and harmonization.",
            },
            {
                "email": "dr.kerem@goklinik.com",
                "first_name": "Kerem",
                "last_name": "Demir",
                "phone": "+90 555 100 0002",
                "crm_number": "TR-CRM-1002",
                "years_experience": 14,
                "bio": "Body contouring surgeon with expertise in lipoaspiration techniques.",
            },
            {
                "email": "dr.zeynep@goklinik.com",
                "first_name": "Zeynep",
                "last_name": "Aydin",
                "phone": "+90 555 100 0003",
                "crm_number": "TR-CRM-1003",
                "years_experience": 9,
                "bio": "Aesthetic physician specialized in injectables and skin rejuvenation.",
            },
        ]

        for doctor in doctors:
            email = doctor.pop("email")
            user, _ = GoKlinikUser.objects.get_or_create(
                email=email,
                defaults={
                    **doctor,
                    "tenant": tenant,
                    "role": GoKlinikUser.RoleChoices.SURGEON,
                    "is_active": True,
                    "is_visible_in_app": True,
                },
            )
            for key, value in doctor.items():
                setattr(user, key, value)
            user.tenant = tenant
            user.role = GoKlinikUser.RoleChoices.SURGEON
            user.is_visible_in_app = True
            user.is_active = True
            user.set_password("Doctor2024!")
            user.save()

        self.stdout.write(self.style.SUCCESS("Demo surgeons synced (3)."))
        self.stdout.write(self.style.SUCCESS("Go Klinik demo seed completed."))
