from rest_framework import serializers

from api.models import School
from users.serializers import UserSerializer


class SchoolSerializer(serializers.ModelSerializer):
    captured_by = UserSerializer(read_only=True)
    captured_by_id = serializers.UUIDField(write_only=True, required=False, allow_null=True)

    class Meta:
        model = School
        fields = [
            'id', 'tenant', 'name', 'phone', 'county', 'source',
            'external_place_id', 'external_vicinity', 'focus_areas',
            'book_category', 'dealer_type', 'shop_category', 'selected_product',
            'partner_subtype', 'latitude', 'longitude', 'gps_accuracy_meters',
            'photo_url', 'photo_path', 'captured_by', 'captured_by_id',
            'captured_at', 'capture_status', 'contact_name', 'contact_phone',
            'contact_title', 'feedback', 'notes', 'samples_left', 'sample_book',
            'engagement_type', 'school_ownership', 'school_ownership_other',
            'school_population', 'school_lifecycle_status', 'sample_proof_url',
            'sample_proof_path', 'is_synced', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'tenant']

    def create(self, validated_data):
        validated_data.pop('captured_by_id', None)
        return super().create(validated_data)

    def update(self, instance, validated_data):
        validated_data.pop('captured_by_id', None)
        return super().update(instance, validated_data)
