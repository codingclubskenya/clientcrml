from django.db import models


class Tenant(models.Model):
    name = models.CharField(max_length=100, unique=True)
    schema_name = models.CharField(max_length=100, unique=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = 'tenants'

    def __str__(self):
        return self.name
