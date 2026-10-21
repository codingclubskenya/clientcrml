import django.db.models
from django.db import models
import uuid

from common.managers import TenantAwareManager
from tenant.models import Tenant
from users.models import User


class School(models.Model):
    tenant = models.ForeignKey(Tenant, on_delete=models.CASCADE, db_column='tenant_id')
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    phone = models.CharField(max_length=100, null=True, blank=True)
    county = models.CharField(max_length=100, null=True, blank=True, default='Unknown')
    source = models.CharField(max_length=50, default='manual')
    external_place_id = models.CharField(max_length=255, null=True, blank=True, db_column='external_place_id')
    external_vicinity = models.TextField(null=True, blank=True, db_column='external_vicinity')
    focus_areas = models.JSONField(default=list, db_column='focusAreas')
    book_category = models.CharField(max_length=100, null=True, blank=True, db_column='book_category')
    dealer_type = models.CharField(max_length=100, null=True, blank=True, db_column='dealer_type')
    shop_category = models.CharField(max_length=100, null=True, blank=True, db_column='shop_category')
    selected_product = models.CharField(max_length=255, null=True, blank=True, db_column='selected_product')
    partner_subtype = models.CharField(max_length=100, null=True, blank=True, db_column='partner_subtype')
    latitude = models.CharField(max_length=50, null=True, blank=True)
    longitude = models.CharField(max_length=50, null=True, blank=True)
    gps_accuracy_meters = models.CharField(max_length=50, null=True, blank=True, db_column='gps_accuracy_meters')
    photo_url = models.TextField(null=True, blank=True, db_column='photo_url')
    photo_path = models.TextField(null=True, blank=True, db_column='photo_path')
    captured_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        db_column='captured_by',
        related_name='captured_schools',
    )
    captured_at = models.DateTimeField(null=True, blank=True, db_column='captured_at')
    capture_status = models.CharField(max_length=50, null=True, blank=True, db_column='capture_status')
    contact_name = models.CharField(max_length=255, null=True, blank=True, db_column='contact_name')
    contact_phone = models.CharField(max_length=50, null=True, blank=True, db_column='contact_phone')
    contact_title = models.CharField(max_length=100, null=True, blank=True, db_column='contact_title')
    feedback = models.TextField(null=True, blank=True)
    notes = models.TextField(null=True, blank=True)
    samples_left = models.IntegerField(default=0, db_column='samples_left')
    sample_book = models.CharField(max_length=255, null=True, blank=True, db_column='sample_book')
    engagement_type = models.CharField(max_length=100, null=True, blank=True, db_column='engagement_type')
    school_ownership = models.CharField(max_length=100, null=True, blank=True, db_column='school_ownership')
    school_ownership_other = models.CharField(max_length=255, null=True, blank=True, db_column='school_ownership_other')
    school_population = models.CharField(max_length=100, null=True, blank=True, db_column='school_population')
    school_lifecycle_status = models.CharField(max_length=100, null=True, blank=True, db_column='school_lifecycle_status')
    sample_proof_url = models.TextField(null=True, blank=True, db_column='sample_proof_url')
    sample_proof_path = models.TextField(null=True, blank=True, db_column='sample_proof_path')
    is_synced = models.BooleanField(default=False, db_column='isSynced')
    created_at = models.DateTimeField(default=django.db.models.functions.Now, db_column='created_at')
    updated_at = models.DateTimeField(auto_now=True, db_column='updated_at')

    objects = TenantAwareManager()
    admin = models.Manager()

    class Meta:
        db_table = 'schools'

    def __str__(self):
        return self.name
