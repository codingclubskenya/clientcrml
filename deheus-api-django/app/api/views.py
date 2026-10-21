from rest_framework import viewsets, permissions, filters
from django_filters.rest_framework import DjangoFilterBackend

from api.models import School
from api.serializers import SchoolSerializer
from common.permissions import TenantAccessPermission, RoleBasedPermission


class SchoolViewSet(viewsets.ModelViewSet):
    queryset = School.objects.all()
    serializer_class = SchoolSerializer
    permission_classes = [permissions.IsAuthenticated, RoleBasedPermission, TenantAccessPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['source', 'county', 'dealer_type', 'is_synced', 'created_at']
    search_fields = ['name', 'phone', 'county', 'contact_name']
    ordering_fields = ['name', 'created_at', 'updated_at', 'county']
    ordering = ['created_at']

    def get_queryset(self):
        return super().get_queryset().filter(tenant=self.request.user.tenant)
