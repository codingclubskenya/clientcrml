import threading

from tenant.models import Tenant


class _TenantContext:
    """Thread-local storage for the current tenant."""

    def __init__(self):
        self._local = threading.local()

    @property
    def tenant(self):
        return getattr(self._local, 'tenant', None)

    @tenant.setter
    def tenant(self, value):
        self._local.tenant = value

    @tenant.deleter
    def tenant(self):
        del self._local.tenant

    def clear(self):
        if hasattr(self._local, 'tenant'):
            del self._local.tenant


tenant_context = _TenantContext()


class TenantMiddleware:
    """
    Middleware that resolves the current tenant from the JWT token or
    a custom X-Tenant-Id header and makes it available throughout the request.

    The tenant is stored in thread-local storage so that model managers
    can filter querysets by tenant_id automatically.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        tenant = self._resolve_tenant(request)
        if tenant:
            tenant_context.tenant = tenant
        response = self.get_response(request)
        tenant_context.clear()
        return response

    def _resolve_tenant(self, request):
        # 1. Try to get tenant from JWT token
        tenant = self._get_tenant_from_jwt(request)
        if tenant:
            return tenant

        # 2. Try to get tenant from X-Tenant-Id header
        tenant_id = request.headers.get('X-Tenant-Id')
        if tenant_id:
            try:
                return Tenant.objects.get(id=tenant_id, is_active=True)
            except Tenant.DoesNotExist:
                pass

        # 3. Try to get tenant from subdomain (for web access)
        host = request.get_host().split(':')[0]
        subdomain = host.split('.')[0]
        if subdomain and subdomain not in ('www', 'localhost', '127'):
            try:
                return Tenant.objects.get(schema_name=subdomain, is_active=True)
            except Tenant.DoesNotExist:
                pass

        # 4. Fall back to the first active tenant (for backward compatibility)
        try:
            return Tenant.objects.filter(is_active=True).first()
        except Exception:
            return None

    def _get_tenant_from_jwt(self, request):
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return None

        token = auth_header[7:]
        try:
            from rest_framework_simplejwt.tokens import UntypedToken
            from rest_framework_simplejwt.exceptions import InvalidToken
            unverified = UntypedToken(token)
            tenant_id = unverified.payload.get('tenant_id')
            if tenant_id:
                return Tenant.objects.get(id=tenant_id, is_active=True)
        except Exception:
            pass
        return None
