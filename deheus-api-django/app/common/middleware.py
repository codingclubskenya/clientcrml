import logging
from datetime import timedelta

from django.core.cache import cache
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle

logger = logging.getLogger('audit')


class TenantPagination:
    """Custom pagination that respects tenant context."""

    page_size = 100
    max_page_size = 500

    def __init__(self):
        from rest_framework.pagination import PageNumberPagination
        self._paginator = PageNumberPagination()
        self._paginator.page_size = self.page_size
        self._paginator.max_page_size = self.max_page_size

    # DRF hooks — delegate to inner paginator
    def paginate_queryset(self, queryset, request, view=None):
        return self._paginator.paginate_queryset(queryset, request, view=view)

    def get_paginated_response(self, data):
        return self._paginator.get_paginated_response(data)

    @property
    def root_view(self):
        return self._paginator.root_view


class AuditLogMiddleware:
    """
    Middleware that logs all mutating operations (POST, PUT, PATCH, DELETE)
    with user, tenant, and timestamp for audit purposes.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.method in ('POST', 'PUT', 'PATCH', 'DELETE'):
            user = getattr(request, 'user', None)
            if user and user.is_authenticated:
                tenant = getattr(request, 'tenant', None)
                logger.info(
                    'audit: %s %s user=%s tenant=%s',
                    request.method,
                    request.path,
                    user.email if hasattr(user, 'email') else user.id,
                    tenant.id if tenant else 'none',
                )
        return self.get_response(request)


def axes_locked(request, credentials, *args, **kwargs):
    """Callback when a user is locked out by django-axes."""
    from django.http import JsonResponse
    return JsonResponse(
        {'error': 'Account temporarily locked due to too many failed login attempts. Try again later.'},
        status=429,
    )


class LoginRateThrottle(UserRateThrottle):
    scope = 'login'
    rate = '5/minute'


class AuthRateThrottle(UserRateThrottle):
    scope = 'auth'
    rate = '10/minute'
