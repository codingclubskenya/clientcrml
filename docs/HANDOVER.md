# Handover Document: Deheus CRM — Django Migration & Mapbox Fix

**Date**: 2026-10-21  
**Branch**: `joe`  
**Repos**: `codingclubskenya/clientcrml` (origin), `codingclubskenya/lcrm` (lcrm)

---

## 1. What Was Done

### 1.1 CSV Data Migration (Live MySQL)

Migrated real CSV data from `users_rows.csv` (42 records) and `12.csv` (1657 records) to the live MySQL database (`longhorn` @ `213.199.41.219`).

**Results**:
| Table | CSV Records | DB Total | Notes |
|-------|------------|----------|-------|
| users | 42 | 57 | 15 pre-existing seed records |
| schools | 1588 | 1594 | 67 malformed UUID rows skipped, 5 pre-existing + 1 fallback user |
| school_sales | 1589 | 1594 | 5 pre-existing |
| school_follow_ups | 6 | 12 | 6 pre-existing |

### 1.2 Data Integrity Fix (captured_by)

**Problem**: The migration assigned ALL 1593 schools to the fallback "Faith Agent" (`11111111-1111-1111-1111-111111111111`).

**Fix**: Ran a SQL UPDATE via SSH to restore the original `captured_by` values from the CSV for 1311 schools that had valid UUIDs matching user IDs. 282 schools with corrupted `captured_by` (file paths) remain on the fallback user since the original agent data is unrecoverable.

**Verification** (live DB):
```
matched_to_real_user:  1312
fallback_user:          282
total:                 1594
```

### 1.3 Boolean Type Fix (TINYINT → bool)

MySQL returns `TINYINT(1)` as integer `1`/`0`, but Dart models declare `bool`. This caused silent `TypeError` in `fromMap()`, returning empty lists.

**Files fixed** (11 model + service files):
- `lib/models/farmer_model.dart`
- `lib/models/school_sale_model.dart`
- `lib/models/catalog_item_model.dart`
- `lib/models/product_model.dart`
- `lib/models/message_model.dart`
- `lib/models/event_model.dart`
- `lib/features/database/database_service.dart`
- `lib/features/workmanager/workmanager_dispatcher.dart`

Pattern: `map['isSynced'] == true || map['isSynced'] == 1`

### 1.4 Mapbox Key Not Working

**Root cause**: Mapbox token is a compile-time constant via `String.fromEnvironment('MAPBOX_ACCESS_TOKEN')`. When missing, app silently falls back to OSM tiles.

**Fixes**:
1. Added `activeProvider` getter to `MapTileConfig` for runtime debugging
2. Added debug badges on all map screens (green=Mapbox, orange=OSM)
3. Fixed satellite/street toggle: `TileLayer` now gets a `ValueKey` to force tile cache invalidation
4. Created `run.sh` helper script for running with the token
5. Updated `README.md` with clear token instructions

**Valid token**: `pk.eyJ1Ijo...` (redacted for security)  
**Needs to be added to**: `lcrm` GitHub repo → Settings → Secrets → `MAPBOX_ACCESS_TOKEN`

### 1.5 Password Reset Fix

**Root cause**: `_sendResetLink()` in `reset_password_page.dart:98` called `Navigator.pop(context)` unconditionally after the API returned the reset token, popping the page before the user could enter their new password.

**Fix**: Removed the `Navigator.pop(context)` call so the page stays open to show the password form.

### 1.6 getAllSchools() Limit Fix

**Root cause**: `getAllSchools()` was hardcoded with `limit: 500`, only loading half the schools.

**Fix**: Changed to `getAllSchools({int limit = 2000})` and updated callers.

### 1.7 User-School Onboarding Page

- Case-insensitive UUID matching (`.toLowerCase()` on both `capturedBy` and `userId`)
- Added "Unassigned Schools" section for schools whose `captured_by` doesn't match any user
- Updated PDF export to use same case-insensitive matching

### 1.8 Django REST API (Multitenancy + Security)

Created a complete Django REST Framework backend at `deheus-api-django/app/` with:

**Multi-tenancy**:
- `Tenant` model with thread-local middleware (JWT token claim, `X-Tenant-Id` header, subdomain routing)
- `TenantAwareManager` auto-filters all querysets by tenant
- Row-level isolation on shared MySQL database

**Security**:
- JWT auth (15-min access token, 7-day refresh with rotation + blacklist)
- RBAC: 5 roles (Admin, Regional Manager, BAS Supervisor, Field Agent, Sales Rep) with granular permissions
- django-axes brute-force protection (5 attempts → 15-min lockout)
- Rate limiting (5/min login, 1000/hour API)
- Audit logging middleware
- CORS, input validation via DRF serializers

**API Endpoints**:
- Auth: `/api/auth/login`, `/api/auth/refresh`, `/api/auth/logout`, `/api/auth/forgot-password`, `/api/auth/reset-password`, `/api/auth/me`
- Data: `/api/schools` (with filtering, search, ordering)
- Schema: `/api/schema/`, `/api/docs/swagger/`, `/api/docs/redoc/`

**Deployment**:
- Gunicorn + Nginx on Contabo VM (`213.199.41.219`)
- GitHub Actions workflow (`deploy-django.yml`) triggers on push to `joe`/`master`
- Works alongside existing Node.js API (parallel deployment)

---

## 2. Live Server Configuration

### SSH Access
```
Server: 213.199.41.219
User: devops
Password: Kenyacom23
```

### MySQL
```
Host: 213.199.41.219
User: longhorn
Password: 3577
Database: longhorn
Port: 3306
```

### API (Node.js — currently active)
```
Running on: port 3000
Command: node /home/devops/deheus-api/index.js
Base URL: https://codingclubskenya.com/deheus-api
Health: https://codingclubskenya.com/deheus-api/health
```

### API (Django — new, to be deployed)
```
Running on: port 8000 (via Gunicorn)
Working dir: /home/devops/deheus-api-django/app
Config: /etc/systemd/system/gunicorn.service
```

### Working Admin Credentials
| Email | Password | Role |
|-------|----------|------|
| admin2@test.com | admin123 | 1 (Admin) |
| nungari100@gmail.com | 12345678 | 5 (Sales Rep) |

---

## 3. GitHub Actions / CI/CD

### Workflows (`.github/workflows/`)
| File | Trigger | Purpose |
|------|---------|---------|
| `deploy-gh-pages.yml` | push to `joe`/`master` | Builds Flutter web → GitHub Pages |
| `deploy.yml` | push to `main`/`master` | Builds web+APK, deploys to server |
| `deploy-django.yml` | push to `joe`/`master` | Builds Django API, deploys via SSH |
| `ci.yml` | push/PR to `master` | Analyzes + tests |
| `release.yml` | push to `master`/`joe`, tags `v*` | Builds APK, creates GitHub Release |

### Required Secrets (in `lcrm` repo)
| Secret | Value | Used By |
|--------|-------|---------|
| `MAPBOX_ACCESS_TOKEN` | `pk.eyJ1Ijo...` (contact project owner for actual token) | `deploy-gh-pages.yml`, `release.yml`, `deploy.yml` |
| `SERVER_HOST` | `213.199.41.219` | `deploy.yml`, `deploy-django.yml` |
| `SERVER_USER` | `devops` | `deploy.yml`, `deploy-django.yml` |
| `SSH_PRIVATE_KEY` | (SSH key) | `deploy.yml`, `deploy-django.yml` |

### Pending Manual Setup
1. **Enable GitHub Pages** at `https://github.com/codingclubskenya/lcrm/settings/pages` (Source: "Deploy from GitHub Actions workflow")
2. **Add `MAPBOX_ACCESS_TOKEN` secret** in `lcrm` repo settings
3. **Add SSH secrets** (`SERVER_HOST`, `SERVER_USER`, `SSH_PRIVATE_KEY`) in `lcrm` repo for Django deployment

---

## 4. How to Run Locally

### Flutter App
```bash
cd C:\Users\kmuga\OneDrive\Desktop\clientcrml

# With Mapbox (recommended)
flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token_here

# Or use helper script
export MAPBOX_ACCESS_TOKEN=pk.your_token_here
./run.sh

# Build APK with Mapbox
flutter build apk --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token_here
```

### Django API (Development)
```bash
cd deheus-api-django/app
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

---

## 5. Files Modified

| File | Change |
|------|--------|
| `lib/models/farmer_model.dart` | Boolean coercion fix, `toMap()` column cleanup |
| `lib/models/school_sale_model.dart` | Boolean coercion fix, removed `region_id` |
| `lib/models/catalog_item_model.dart` | Added `isActive`/`isSynced` boolean coercion |
| `lib/models/product_model.dart` | `isActive` boolean coercion |
| `lib/models/message_model.dart` | `isRead` boolean coercion |
| `lib/models/event_model.dart` | `isSynced` boolean coercion |
| `lib/features/database/database_service.dart` | `getAllSchools({int limit = 2000})`, `isSynced` fix in `getUserProfile` |
| `lib/features/admin/user_school_onboarding_page.dart` | Case-insensitive UUID matching, Unassigned Schools section, PDF export fix |
| `lib/features/welcome/auth/reset_password_page.dart` | Removed `Navigator.pop()` that blocked password form |
| `lib/features/dashboard/agrovet_onboarding.dart` | `_selectedBookProgram` fallback, submission payload update |
| `lib/core/widgets/map_tile_controls.dart` | `ValueKey` on TileLayer for cache invalidation |
| `lib/core/config/map_tile_config.dart` | Added `activeProvider` getter |
| `lib/features/admin/admin_dashboard_page.dart` | Debug tile provider badges |
| `lib/features/admin/admin_geofence_map_screen.dart` | Debug tile provider badge |
| `README.md` | Mapbox token instructions |
| `AGENTS.md` | Lint/test/build commands |

---

## 6. Files Created

### Flutter
- `lib/features/admin/user_school_onboarding_page.dart` (modified)

### API (Node.js)
- `api/fix_captured_by.js` — SSH script to fix school-captured_by relationships
- `api/check_db_relations.js` — SSH script to check live DB state
- `api/check_users_schema.js` — SSH script to check users table columns

### Django REST API
- `deheus-api-django/app/` — Full Django project (see Section 1.8)

### CI/CD
- `.github/workflows/deploy-django.yml` — Django deployment workflow

### Tools
- `run.sh` — Helper script for Flutter with Mapbox token

### Docs
- `docs/django-multitenancy-security-plan.md` — Implementation plan
- `AGENTS.md` — Development guide
- `README.md` (updated) — Mapbox token instructions

---

## 7. Known Issues & Notes

1. **GitHub Pages deploy failing** — The deploy job builds successfully (14.5MB artifact) but fails because GitHub Pages is not enabled in the `lcrm` repo settings.

2. **Node.js API still active** — The existing Node.js API on port 3000 is running and serving requests. The Django API is a replacement but hasn't been deployed to the server yet.

3. **282 schools on fallback user** — These schools had corrupted `captured_by` values (file paths instead of UUIDs) in the original CSV. The original agent data is unrecoverable.

4. **51 empty `captured_by` values** — Handled gracefully (shown in "Unassigned Schools" section on the onboarding page).

5. **67 malformed UUID school IDs were skipped** — These had invalid `id` values in the CSV.

6. **The `role_ref` column does not exist** in the live `users` table — The `SchoolModel.toMap()` was already updated to exclude it.

7. **The `forecast_category` and `region_id` columns do not exist** on `school_sales` — Excluded from model `toMap()` methods.

8. **The `visit_checkins` table lacks `created_at`/`updated_at`/`agent_name`/`gps_lat`/`gps_lng`/`location_text`** — The API's dynamic column filtering handles this automatically.

5 tables are missing from the live server: `supervisor_incidents`, `supervisor_notifications`, `task_completion_evidence`, `consignments`, `consignment_items`.
