from django.urls import path
from tenant.views import TenantViewSet

urlpatterns = [
    path('tenants/', TenantViewSet.as_list_or_create()),
    path('tenants/<int:pk>/', TenantViewSet.as_retrieve_or_update_or_destroy()),
]
