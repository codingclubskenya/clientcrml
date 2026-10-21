import uuid

from django.contrib.auth.models import AbstractBasePasswordHasher, BaseUserManager
from django.db import models
from django.utils import timezone

from tenant.models import Tenant
from tenant.middleware import tenant_context


class UserManager(BaseUserManager):
    use_in_migrations = True

    def _create_user(self, email, password, tenant, **extra_fields):
        if not email:
            raise ValueError('Users must set an email address')
        email = self.normalize_email(email)
        user = self.model(email=email, tenant=tenant, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email, password, tenant, **extra_fields):
        extra_fields.setdefault('is_staff', False)
        extra_fields.setdefault('is_superuser', False)
        return self._create_user(email, password, tenant, **extra_fields)

    def create_superuser(self, email, password, tenant=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_active', True)
        extra_fields.setdefault('role', 1)
        if tenant is None:
            tenant = Tenant.objects.first()
        return self._create_user(email, password, tenant, **extra_fields)


class User(AbstractBasePasswordHasher):
    tenant = models.ForeignKey(
        Tenant,
        on_delete=models.CASCADE,
        db_column='tenant_id',
        null=True,
        blank=True,
    )
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(max_length=255)
    full_name = models.CharField(max_length=255, null=True, blank=True)
    phone = models.CharField(max_length=50, null=True, blank=True)
    role = models.IntegerField(default=5)
    is_synced = models.BooleanField(default=False, db_column='isSynced')
    created_at = models.DateTimeField(default=timezone.now, db_column='created_at')
    updated_at = models.DateTimeField(auto_now=True, db_column='updated_at')
    password_hash = models.CharField(max_length=255, null=True, blank=True, db_column='password_hash')
    password_reset_token = models.CharField(max_length=255, null=True, blank=True, db_column='password_reset_token')
    password_reset_expires = models.DateTimeField(null=True, blank=True, db_column='password_reset_expires')

    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    is_superuser = models.BooleanField(default=False)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = []
    EMAIL_FIELD = 'email'

    objects = UserManager()

    class Meta:
        db_table = 'users'
        unique_together = ('tenant', 'email')

    @property
    def is_authenticated(self):
        return True

    def get_full_name(self):
        return self.full_name or self.email

    def get_short_name(self):
        return self.full_name or self.email

    @property
    def is_admin(self):
        return self.role == 1

    def has_perm(self, perm, obj=None):
        return True

    def has_module_perms(self, app_label):
        return True

    def save(self, *args, **kwargs):
        tenant = getattr(tenant_context, 'tenant', None)
        if self.tenant_id is None and tenant is not None:
            self.tenant = tenant
        if self.pk is None:
            if 'password' in kwargs:
                pw = kwargs.pop('password')
                self.set_password(pw)
        super().save(*args, **kwargs)
