from django.test import SimpleTestCase

from apps.users.access import resolve_access_permissions_for_role
from apps.users.models import GoKlinikUser


class ResolveAccessPermissionsForRoleTestCase(SimpleTestCase):
    def test_surgeon_permissions_always_include_pre_operatory(self):
        permissions = resolve_access_permissions_for_role(
            GoKlinikUser.RoleChoices.SURGEON,
            ["dashboard", "patients"],
        )

        self.assertIn("pre_operatory", permissions)

