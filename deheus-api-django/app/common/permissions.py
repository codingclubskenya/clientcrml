from rest_framework import permissions


class RoleBasedPermission(permissions.BasePermission):
    """
    Map roles to permissions:
    1 = Admin (full access)
    2 = Regional Manager (read/write, no delete)
    3 = BAS Supervisor (read/write, no delete)
    4 = Field Agent (read/write, delete own)
    5 = Sales Rep (read/write, delete own)
    """

    ROLE_PERMISSIONS = {
        1: {'read': True, 'write': True, 'delete': True, 'admin': True},
        2: {'read': True, 'write': True, 'delete': False, 'admin': False},
        3: {'read': True, 'write': True, 'delete': False, 'admin': False},
        4: {'read': True, 'write': True, 'delete': True, 'admin': False},
        5: {'read': True, 'write': True, 'delete': True, 'admin': False},
    }

    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False

        role_perms = self.ROLE_PERMISSIONS.get(user.role, self.ROLE_PERMISSIONS[5])

        # SAFE_METHODS (GET, HEAD, OPTIONS) only need read access
        if request.method in permissions.SAFE_METHODS:
            return role_perms['read']

        # POST (create) and PUT/PATCH (update) need write access
        if request.method in ('POST', 'PUT', 'PATCH'):
            return role_perms['write']

        # DELETE needs delete access
        if request.method == 'DELETE':
            return role_perms['delete']

        return False

    def has_object_permission(self, request, view, obj):
        user = request.user
        role_perms = self.ROLE_PERMISSIONS.get(user.role, self.ROLE_PERMISSIONS[5])

        if request.method in permissions.SAFE_METHODS:
            return role_perms['read']

        if request.method in ('POST', 'PUT', 'PATCH'):
            return role_perms['write']

        if request.method == 'DELETE':
            # Agents can delete their own objects
            if user.role in (4, 5) and hasattr(obj, 'captured_by') and obj.captured_by == user:
                return True
            return role_perms['delete']

        return False


class TenantAccessPermission(permissions.BasePermission):
    """Ensures the user can only access objects within their tenant."""

    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return True
        return hasattr(request.user, 'tenant') and request.user.tenant is not None

    def has_object_permission(self, request, view, obj):
        if hasattr(obj, 'tenant'):
            return obj.tenant == request.user.tenant
        return True
