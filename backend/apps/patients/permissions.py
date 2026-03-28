from rest_framework.permissions import BasePermission

from apps.users.models import GoKlinikUser


class CanManagePatients(BasePermission):
    allowed_roles = {
        GoKlinikUser.RoleChoices.CLINIC_MASTER,
        GoKlinikUser.RoleChoices.SECRETARY,
        GoKlinikUser.RoleChoices.NURSE,
        GoKlinikUser.RoleChoices.SURGEON,
    }

    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated and user.role in self.allowed_roles)

    def has_object_permission(self, request, view, obj):
        user = request.user
        return bool(user.tenant_id and obj.tenant_id and str(user.tenant_id) == str(obj.tenant_id))
