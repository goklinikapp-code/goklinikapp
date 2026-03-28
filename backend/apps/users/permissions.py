from __future__ import annotations

from rest_framework.permissions import BasePermission

from .models import GoKlinikUser


class BaseTenantRolePermission(BasePermission):
    allowed_roles: tuple[str, ...] = ()

    def has_permission(self, request, view) -> bool:
        user = request.user
        if not user or not user.is_authenticated:
            return False

        if user.role == GoKlinikUser.RoleChoices.SUPER_ADMIN:
            return True

        if user.role not in self.allowed_roles:
            return False

        if not user.tenant_id:
            return False

        tenant_id = request.data.get("tenant") or request.data.get("tenant_id")
        if tenant_id and str(tenant_id) != str(user.tenant_id):
            return False

        return True

    def has_object_permission(self, request, view, obj) -> bool:
        user = request.user
        if user.role == GoKlinikUser.RoleChoices.SUPER_ADMIN:
            return True

        if user.role not in self.allowed_roles or not user.tenant_id:
            return False

        obj_tenant_id = getattr(obj, "tenant_id", None)
        if obj_tenant_id is None and hasattr(obj, "tenant"):
            obj_tenant_id = getattr(obj.tenant, "id", None)

        if obj_tenant_id is None and hasattr(obj, "user"):
            obj_tenant_id = getattr(obj.user, "tenant_id", None)

        return str(obj_tenant_id) == str(user.tenant_id)


class IsTenantMaster(BaseTenantRolePermission):
    allowed_roles = (GoKlinikUser.RoleChoices.CLINIC_MASTER,)


class IsSurgeon(BaseTenantRolePermission):
    allowed_roles = (GoKlinikUser.RoleChoices.SURGEON,)


class IsSecretary(BaseTenantRolePermission):
    allowed_roles = (GoKlinikUser.RoleChoices.SECRETARY,)


class IsNurse(BaseTenantRolePermission):
    allowed_roles = (GoKlinikUser.RoleChoices.NURSE,)


class IsPatient(BaseTenantRolePermission):
    allowed_roles = (GoKlinikUser.RoleChoices.PATIENT,)
