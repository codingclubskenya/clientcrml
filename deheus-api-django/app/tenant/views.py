from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from tenant.models import Tenant
from tenant.serializers import TenantSerializer


class TenantViewSet(viewsets.ModelViewSet):
    queryset = Tenant.objects.all()
    serializer_class = TenantSerializer

    @action(detail=True, methods=['get'])
    def switch(self, request, pk=None):
        tenant = self.get_object()
        from tenant.middleware import tenant_context
        tenant_context.tenant = tenant
        return Response({'message': f'Switched to tenant: {tenant.name}'})
