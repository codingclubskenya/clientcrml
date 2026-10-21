from django.contrib import admin
from tenant.models import Tenant
from users.models import User
from api.models import School


@admin.register(Tenant)
class TenantAdmin(admin.ModelAdmin):
    list_display = ('name', 'schema_name', 'is_active', 'created_at')
    list_filter = ('is_active',)


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ('email', 'full_name', 'role', 'tenant', 'created_at')
    list_filter = ('role', 'tenant')


@admin.register(School)
class SchoolAdmin(admin.ModelAdmin):
    list_display = ('name', 'county', 'phone', 'source', 'captured_by', 'tenant', 'is_synced')
    list_filter = ('source', 'county', 'tenant', 'is_synced', 'created_at')
    search_fields = ('name', 'phone', 'county')
