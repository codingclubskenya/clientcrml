from django.urls import path, include
from rest_framework.routers import DefaultRouter
from api.views import SchoolViewSet

router = DefaultRouter()
router.register(r'schools', SchoolViewSet)

urlpatterns = [
    path('', include(router.urls)),
]
