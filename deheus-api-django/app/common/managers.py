from django.db import models
from tenant.middleware import tenant_context


class TenantAwareManager(models.Manager):
    def get_queryset(self):
        qs = super().get_queryset()
        tenant = getattr(tenant_context, 'tenant', None)
        if tenant:
            return qs.filter(tenant=tenant)
        return qs.none()


class TenantAwareQuerySet(models.QuerySet):
    def _filter_or_exclude(self, *args, **kwargs):
        tenant = getattr(tenant_context, 'tenant', None)
        if tenant:
            kwargs.setdefault('tenant', tenant)
        return super()._filter_or_explain('filter', *args, **kwargs)
