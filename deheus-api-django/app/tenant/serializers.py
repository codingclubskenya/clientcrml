from rest_framework import serializers
from tenant.models import Tenant


class TenantSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tenant
        fields = ['id', 'name', 'schema_name', 'is_active', 'created_at']
        read_only_fields = ['id', 'created_at']
