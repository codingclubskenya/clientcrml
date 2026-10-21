# Implementation Plan: Django REST API for Multi-Tenancy and Security

## Objective
Migrate and enhance the existing Node.js/Express API (`api/index.js`) to a Django REST Framework (DRF) backend that provides:
1. **Multi-tenancy** — Row-level tenant isolation (each tenant sees only its data)
2. **Security** — JWT auth, RBAC, input validation, rate limiting, audit logging

## Current State Analysis

### Existing API (Node.js + Express + MySQL)
- **Location**: `api/index.js` (1202 lines)
- **Auth**: JWT token with 7-day expiry; bcrypt for new passwords, PBKDF2 for legacy
- **DB**: MySQL on Contabo (`213.199.41.219`, user `longhorn`, db `longhorn`)
- **Endpoints**: `/api/auth/*`, `/api/users`, `/api/schools`, `/api/school_sales`, `/api/school_follow_ups`, `/api/visit_checkins`, `/api/tasks`, `/api/messages`, `/api/orders`, etc.
- **Columns on `schools`**: `id, name, phone, county, source, captured_by, isSynced, created_at, updated_at` (33 total)
- **Columns on `users`**: `id, email, full_name, phone, role, isSynced, created_at, updated_at, password_hash, password_reset_token, password_reset_expires` (16 total)

### Existing Frontend (Flutter)
- **Base URL**: `https://codingclubskenya.com/deheus-api`
- **Auth**: JWT token stored in `flutter_secure_storage`
- **API Service**: `lib/services/api_service.dart` — uses `dio` HTTP client

## Phase 1: Django Project Setup

### 1.1 Project Structure
```
deheus-api/
├── manage.py
├── requirements.txt
├── deheus_api/
│   ├── __init__.py
│   ├── settings.py          # Multi-tenant aware settings
│   ├── urls.py
│   ├── wsgi.py
│   └── asgi.py
├── tenant/
│   ├── __init__.py
│   ├── models.py            # Tenant model
│   ├── middleware.py        # Tenant routing middleware
│   └── serializers.py
├── api/
│   ├── __init__.py
│   ├── models.py
│   ├── serializers.py
│   ├── views.py
│   ├── permissions.py       # RBAC permissions
│   └── urls.py
├── users/
│   ├── __init__.py
│   ├── models.py            # CustomUser with tenant FK
│   ├── serializers.py
│   ├── views.py
│   └── urls.py
└── common/
    ├── __init__.py
    ├── pagination.py        # Custom pagination
    ├── filters.py           # Custom filter backends
    └── middleware.py        # Audit logging middleware
```

### 1.2 Dependencies
```txt
Django>=4.2
djangorestframework>=3.14
djangorestframework-simplejwt>=5.3
django-cors-headers>=4.3
django-filter>=23.5
mysqlclient>=4.2              # MySQL driver
django-tenants>=3.6           # OR django-tenant-schemas (choose one)
drf-spectacular>=0.27         # OpenAPI schema
redis>=5.0                    # Rate limiting backend
django-axes>=6.3             # Brute-force protection
```

## Phase 2: Multi-Tenancy Implementation

### 2.1 Tenant Model
```python
# tenant/models.py
class Tenant(models.Model):
    name = models.CharField(max_length=100, unique=True)
    schema_name = models.CharField(max_length=100, unique=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'tenants'
```

### 2.2 Tenant-Aware Models
All existing models get a `tenant` ForeignKey:
```python
# users/models.py
class User(AbstractBaseUser):
    tenant = models.ForeignKey(Tenant, on_delete=models.CASCADE, db_column='tenant_id')
    email = models.EmailField(unique=False)  # unique per tenant
    # ... existing fields ...

    class Meta:
        unique_together = ('tenant', 'email')
```

### 2.3 Tenant Routing Strategy
**Option A: Shared Database, Shared Schema (Row-Level Isolation)**
- Single `tenants` table
- All models have `tenant_id` FK
- Middleware extracts tenant from JWT claim or request header
- Querysets automatically filtered by `tenant_id`

**Option B: `django-tenants` (Separate Schemas)**
- PostgreSQL required for true schema separation
- Not compatible with current MySQL setup

**Decision**: Use **shared database + row-level isolation** since the project currently uses MySQL.

### 2.4 Tenant Middleware
```python
# tenant/middleware.py
class TenantMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Extract tenant from JWT token or header
        tenant = self._get_tenant(request)
        request.tenant = tenant
        # Set tenant on thread-local for model filtering
        TenantContext.set_tenant(tenant)
        response = self._get_response(request)
        TenantContext.clear()
        return response

    def _get_tenant(self, request):
        # 1. Check Authorization header for JWT
        # 2. Fall back to custom X-Tenant header
        # 3. Default to public tenant
        pass
```

### 2.5 Tenant-Aware Base Manager
```python
# common/managers.py
class TenantAwareManager(models.Manager):
    def get_queryset(self):
        qs = super().get_queryset()
        tenant = TenantContext.get_current_tenant()
        if tenant:
            return qs.filter(tenant=tenant)
        return qs.none()
```

## Phase 3: Security Implementation

### 3.1 JWT Authentication
```python
# settings.py
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=15),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
}
```

### 3.2 RBAC Permissions
```python
# api/permissions.py
class RoleBasedPermission(BasePermission):
    """
    Map roles to permissions:
    1 = Admin (full access)
    2 = Regional Manager
    3 = BAS Supervisor
    4 = Field Agent
    5 = Sales Rep
    """
    ROLE_PERMISSIONS = {
        1: {'read': True, 'write': True, 'delete': True, 'admin': True},
        2: {'read': True, 'write': True, 'delete': False, 'admin': False},
        3: {'read': True, 'write': True, 'delete': False, 'admin': False},
        4: {'read': True, 'write': True, 'delete': True, 'admin': False},
        5: {'read': True, 'write': True, 'delete': True, 'admin': False},
    }

    def has_permission(self, request, view):
        user = request.user
        role = user.role
        # Check permission based on view action (list/create/update/destroy)
        # Check tenant ownership for object-level permissions
        return self._check_role_permission(role, view)
```

### 3.3 Rate Limiting
```python
# Using Django Ratelimit or DRF SimpleRateRate
REST_FRAMEWORK = {
    'DEFAULT_THROTTLE_RATES': {
        'anon': '100/day',
        'user': '1000/hour',
        'login_attempts': '5/minute',
    }
}
```

### 3.4 Input Validation
- Use DRF Serializers with explicit field validators
- Validate email format, password strength, phone format
- Reject unknown fields in request body (like the dynamic column filtering issue in Node.js)
- Sanitize all file upload paths

### 3.5 Audit Logging
```python
# common/middleware.py
class AuditLogMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self._get_response(request)
        # Log the request/response for create/update/delete operations
        self._log_audit(request, response)
        return response
```

### 3.6 CORS Configuration
```python
# settings.py
CORS_ALLOWED_ORIGINS = [
    "https://codingclubskenya.com",
    "https://lcrm.vercel.app",
    "http://localhost:5000",  # Web dev
    "http://localhost:3000",  # Flutter web dev
]
```

## Phase 4: API Endpoint Migration

### 4.1 Auth Endpoints
| Endpoint | Method | Description | Tenant-Aware |
|----------|--------|-------------|-------------|
| `/api/auth/login` | POST | JWT login (email+password) | No (public) |
| `/api/auth/register` | POST | New user registration | Yes |
| `/api/auth/refresh` | POST | Refresh JWT token | No (public) |
| `/api/auth/forgot-password` | POST | Request password reset | No (public) |
| `/api/auth/reset-password` | POST | Reset password with token | No (public) |
| `/api/auth/me` | GET | Get current user profile | Yes |
| `/api/auth/logout` | POST | Blacklist JWT | Yes |

### 4.2 Core Data Endpoints
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/users` | GET/POST/PUT/DELETE | User management |
| `/api/schools` | GET/POST/PUT/DELETE | School/institution data |
| `/api/school-sales` | GET/POST/PUT/DELETE | Sales records |
| `/api/school-follow-ups` | GET/POST/PUT/DELETE | Follow-up records |
| `/api/visit-checkins` | GET/POST | Agent location check-ins |
| `/api/tasks` | GET/POST/PUT/DELETE | Task management |
| `/api/messages` | GET/POST | Messaging |
| `/api/orders` | GET/POST | Order processing |
| `/api/regions` | GET/POST/PUT/DELETE | Region management |
| `/api/analytics` | GET | Dashboard analytics |

### 4.3 Data Model Migration (MySQL → Django ORM)

#### Users Table
```python
class User(AbstractBaseUser):
    tenant = models.ForeignKey(Tenant, on_delete=models.CASCADE)
    email = models.EmailField()
    full_name = models.CharField(max_length=255, null=True, blank=True)
    phone = models.CharField(max_length=50, null=True, blank=True)
    role = models.IntegerField(default=5)
    is_synced = models.BooleanField(default=False)  # was tinyint(1)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    password_hash = models.CharField(max_length=255, null=True, blank=True)
    password_reset_token = models.CharField(max_length=255, null=True, blank=True)
    password_reset_expires = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'users'
        unique_together = ('tenant', 'email')
```

#### Schools Table
```python
class School(models.Model):
    tenant = models.ForeignKey(Tenant, on_delete=models.CASCADE)
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    phone = models.CharField(max_length=100, null=True, blank=True)
    county = models.CharField(max_length=100, null=True, blank=True, default='Unknown')
    source = models.CharField(max_length=50, default='manual')
    # ... all 33 columns mapped ...
    captured_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    is_synced = models.BooleanField(default=False)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'schools'
```

## Phase 5: Deployment Architecture

### 5.1 Server Setup
```
VM: 213.199.41.219
├── /home/devops/deheus-api-django/     # Django project root
│   ├── venv/                           # Python virtual environment
│   ├── gunicorn                  # WSGI server
│   ├── app/
│   │   ├── manage.py
│   │   └── deheus_api/
│   └── requirements.txt
├── /etc/gunicorn/deheus-api.service  # systemd service
├── /etc/nginx/sites-available/deheus-api
├── MySQL (existing)
└── Redis (for rate limiting + caching)
```

### 5.2 systemd Service (gunicorn)
```ini
[Unit]
Description=Deheus Django API
After=network.target

[Service]
User=devops
Group=www-data
WorkingDirectory=/home/devops/deheus-api-django/app
ExecStart=/home/devops/deheus-api-django/venv/bin/gunicorn deheus_api.wsgi:application --bind 0.0.0.0:3000
Restart=always
EnvironmentFile=/home/devops/deheus-api-django/.env

[Install]
WantedBy=multi-user.target
```

### 5.3 Nginx Reverse Proxy
```nginx
server {
    listen 443 ssl;
    server_name codingclubskenya.com;

    location /deheus-api/ {
        proxy_pass http://127.0.0.1:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Phase 6: Migration Steps

### 6.1 Database Schema Migration
1. Export existing MySQL schema
2. Create Django models matching existing tables
3. Run `makemigrations` + `migrate --fake` (tables already exist)
4. Add `tenant_id` column with data migration script

### 6.2 Data Migration Script
```python
# scripts/migrate_tenant_data.py
"""
1. Create super tenant for existing data
2. Assign all existing users/schools to the default tenant
3. Populate tenant_id on all rows
"""
```

### 6.3 API Contract Compatibility
- Maintain identical endpoint paths (e.g., `/api/schools` stays the same)
- Ensure response formats match existing Node.js API
- Map `isSynced` (TINYINT → Boolean) automatically in Django
- Handle `created_at`/`updated_at` datetime serialization consistently

## Phase 7: Testing

### 7.1 Unit Tests
- Tenant isolation tests (each tenant sees only its data)
- RBAC permission tests (role 1-5 access levels)
- Auth token rotation and blacklist tests
- Rate limiting tests

### 7.2 Integration Tests
- Full password reset flow
- User registration → login → data access
- Role-based access to schools/sales data

### 7.3 Load Testing
- Concurrent user simulation
- Database connection pool tuning
- Response time benchmarks

## Phase 8: Timeline

| Week | Tasks |
|------|-------|
| 1 | Django project setup, dependencies, basic auth endpoints |
| 2 | Multi-tenancy middleware, tenant model, tenant-aware managers |
| 3 | RBAC permissions, rate limiting, JWT refresh flow |
| 4 | Core data endpoints (users, schools, sales) |
| 5 | Remaining endpoints (tasks, messages, orders, analytics) |
| 6 | Audit logging, CORS, input validation, testing |
| 7 | Deployment to Contabo, data migration, cutover |

## Phase 9: Rollback Plan

1. Keep Node.js API running on port 3001 (backup)
2. Database schema changes are additive (no destructive changes)
3. Flip Nginx proxy to Node.js if Django issues occur
4. Run both in parallel during transition period
