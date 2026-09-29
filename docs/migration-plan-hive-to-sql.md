# Migration Plan: Hive → Supabase SQL

## Objective

Migrate the remaining local-only Hive data (Product, Consignment, ConsignmentItem) to Supabase (PostgreSQL) so that catalog and consignment data is persisted remotely, synced across devices, and accessible via the existing RBAC/RLS layer.

---

## 0. Current State Summary

| Layer | Storage | Tables / Boxes | Sync Status |
|---|---|---|---|
| `CatalogService` | Hive `catalog_products_box` | `products`, `consignments`, `seeded` keys | **Local-only — no Supabase** |
| `DatabaseService` schools | Hive `school_box` | SchoolModel as Map | **Synced** ✓ |
| `DatabaseService` catalog items | Hive `catalog_box` | CatalogItemModel as Map | **Synced** ✓ |
| `DatabaseService` school visits | Hive `pending_ops_box` | Offline queue | **Queued** ✓ |
| `event_sales` writes | Direct Supabase insert | `event_sales` table | **Remote** ✓ (but consignment checks are local-only) |
| Background sync | `workmanager_dispatcher.dart` | `school_box` only | **Only schools** |

### Key Gap: Two Parallel Catalog Systems

1. **`DatabaseService` ↔ `catalog_items` table ↔ Hive `catalog_box`**
   - Uses `CatalogItemModel` (11 fields: id, name, category, sku, itemType, unitPrice, stockQty, description, isActive, isSynced, createdAt, updatedAt)
   - Read/write via `getCatalogItems()`, `upsertCatalogItems()`

2. **`CatalogService` ↔ Hive `catalog_products_box` only**
   - Uses `Product` model (29 fields — a superset that adds supplierId, supplierName, barcode, wholesalePrice, unit, minStock, maxStock, imageUrl, author, publisher, isbn, edition, gradeLevel, subject, language, pageCount)
   - No Supabase CRUD methods exist; all reads/writes are in-memory + Hive

The `Product` model is the one used throughout the UI (`AddProductScreen`, `ProductListScreen`, `EventOrdersPage`, `CreateConsignmentScreen`). The Supabase `catalog_items` table already has ALL the columns for the full `Product` model (added by `schema_updates_consignments.sql`), but no Dart code populates them from Supabase.

---

## 1. SQL Schema Alignment

### 1.1 `catalog_items` table

**Status**: Already has all required columns via `schema_updates_consignments.sql`.

| Product field (camelCase) | catalog_items column (snake_case) | Already in schema? |
|---|---|---|
| `id` | `id` (uuid) | ✅ |
| `name` | `name` | ✅ |
| `sku` | `sku` | ✅ |
| `description` | `description` | ✅ |
| `supplierId` | `supplier_id` (uuid) | ✅ added by migration |
| `supplierName` | `supplier_name` (text) | ✅ added by migration |
| `barcode` | `barcode` | ✅ added by migration |
| `unitPrice` | `unit_price` | ✅ |
| `wholesalePrice` | `wholesale_price` | ✅ added by migration |
| `unit` | `unit` | ✅ added by migration |
| `currentStock` | `stock_qty` | ✅ |
| `minStock` | `min_stock` | ✅ added by migration |
| `maxStock` | `max_stock` | ✅ added by migration |
| `imageUrl` | `image_url` | ✅ added by migration |
| `isActive` | `is_active` | ✅ |
| `author` | `author` | ✅ added by migration |
| `publisher` | `publisher` | ✅ added by migration |
| `isbn` | `isbn` | ✅ added by migration |
| `edition` | `edition` | ✅ added by migration |
| `gradeLevel` | `grade_level` | ✅ added by migration |
| `subject` | `subject` | ✅ added by migration |
| `language` | `language` | ✅ added by migration |
| `pageCount` | `page_count` | ✅ added by migration |

**Action needed**: No schema changes. The `catalog_items` table is ready. The only issue is the column name mismatch (`stock_qty` vs `currentStock`, `unit_price` vs `unitPrice`, `is_active` vs `isActive`) in the Dart models, which is already handled in `CatalogItemModel.fromMap()` / `toMap()`.

### 1.2 `consignments` table

**Status**: Defined in `schema_updates_consignments.sql`. ✅

| Consignment field | consignments column | Matched? |
|---|---|---|
| `consignmentId` | `consignment_id` (text PK) | ✅ |
| `businessAssociateId` | `business_associate_id` (uuid FK → users) | ⚠️ Type mismatch — Dart stores string like `ba1`, SQL expects `uuid` |
| `businessAssociateName` | `business_associate_name` (text) | ✅ |
| `notes` | `notes` (text) | ✅ |
| `createdAt` | `created_at` (timestamptz) | ✅ |
| `status` | `status` (text, CHECK) | ✅ |

**Issue**: The Dart `businessAssociateId` is a free-form string (e.g., `ba1`, `ba2`, or a UUID). When syncing to Supabase, we need to resolve this to a real `users.id` UUID. The `business_associate_id` column is a FK to `users.id`, so we must map the Dart value to a valid UUID before insert. If it doesn't match a user, insert with `null` or use `business_associate_name` only.

**Action needed**: Add a Supabase migration to relax the FK constraint (make `business_associate_id` nullable, which it already is via the column definition `not null` — need to change to nullable).

### 1.3 `consignment_items` table

**Status**: Defined in `schema_updates_consignments.sql`. ✅

| ConsignmentItem field | consignment_items column | Matched? |
|---|---|---|
| `product.id` (nested) | `product_id` (uuid FK → catalog_items) | ✅ |
| `unitsToAssign` | `units_to_assign` (integer) | ✅ |
| `unitsSold` | `units_sold` (integer) | ✅ |
| `unitPrice` | `unit_price` (numeric) | ✅ |
| `consignmentId` (parent) | `consignment_id` (text FK) | ✅ |

**Note**: In the Dart model, `ConsignmentItem` embeds the full `Product` object (`product: p1`), while the SQL table stores only `product_id`. The migration must flatten this — store `product_id` reference + keep `unit_price` on the allocation (which already exists in SQL).

### 1.4 `event_sales` table

**Status**: Defined in `schema_updates_event_sales.sql`. ✅

| EventOrdersPage field (Dart) | event_sales column | Matched? |
|---|---|---|
| `event_id` | `event_id` (uuid FK) | ✅ |
| `product_id` | `product_id` (uuid FK) | ✅ |
| `agent_id` | `agent_id` (uuid FK) | ✅ |
| `quantity` | `quantity` (integer) | ✅ |
| `amount` | `amount` (numeric) | ✅ |
| `payment_method` | `payment_method` (text) | ✅ |
| `notes` | `notes` (text) | ✅ |
| `sold_at` | `sold_at` (timestamptz) | ✅ |

**Action needed**: Add `consignment_id` and `consignment_item_id` FK columns — **already added** by `schema_updates_consignments.sql` (section 3). The `apply_consignment_sale()` trigger already atomically updates stock + `units_sold`. Update the Dart `_recordSale()` in `EventOrdersPage` to include these references.

### 1.5 `visit_checkins` table

**Status**: Defined in `schema_updates_visit_checkins.sql`. ✅ No Dart model exists yet.

---

## 2. Phase-by-Phase Migration Plan

### Phase 1: Schema Preparation (SQL — already 95% complete)

**1.1** `schema_updates_consignments.sql` already adds `consignment_id` and `consignment_item_id` to `event_sales` and creates the `apply_consignment_sale()` trigger. ✅ No change needed.

**1.2** Create `supabase/schema_updates_catalog_products.sql` — a new migration to add a `seeded` boolean column to `catalog_items` so we can track which rows came from the seed vs. user-added, and add a unique constraint on `sku`:

```sql
-- Track whether a catalog item was seeded (default seed data)
ALTER TABLE public.catalog_items ADD COLUMN IF NOT EXISTS seeded boolean NOT NULL DEFAULT false;

-- Ensure SKU uniqueness (the Dart models use SKU as a lookup key)
ALTER TABLE public.catalog_items DROP CONSTRAINT IF EXISTS catalog_items_sku_key;
ALTER TABLE public.catalog_items ADD CONSTRAINT catalog_items_sku_key UNIQUE (sku);

-- Allow null business_associate_id on consignments (some BAs are free-form strings)
ALTER TABLE public.consignments ALTER COLUMN business_associate_id DROP NOT NULL;
```

**1.3** Update RLS policies for `catalog_items` and `consignments`/`consignment_items` — the existing policies in `schema.sql` need review. Ensure:
- Admins (role 1) can manage all
- Managers (roles 2-3) can manage
- Agents (role 4) can read catalog items and view consignments
- BAS (role 5) can read-only

### Phase 2: Model Layer (Dart)

**2.1** `Product.toMap()` → `Product.toSqlMap()`

Add a method to `Product` that produces snake_case keys matching Supabase columns:

```dart
Map<String, dynamic> toSqlMap() => {
  'id': id,
  'name': name,
  'sku': sku,
  'description': description,
  'supplier_id': supplierId,
  'supplier_name': supplierName,
  'category': category,
  'barcode': barcode,
  'unit_price': unitPrice,
  'wholesale_price': wholesalePrice,
  'unit': unit,
  'stock_qty': currentStock,
  'min_stock': minStock,
  'max_stock': maxStock,
  'image_url': imageUrl,
  'is_active': isActive,
  'author': author,
  'publisher': publisher,
  'isbn': isbn,
  'edition': edition,
  'grade_level': gradeLevel,
  'subject': subject,
  'language': language,
  'page_count': pageCount,
  'seeded': false,  // set true for seeded products
  'updated_at': DateTime.now().toIso8601String(),
};
```

**2.2** `Product.fromSqlMap()` factory

Add a factory that reads snake_case keys from Supabase:

```dart
factory Product.fromSqlMap(Map<String, dynamic> map) => Product(
  id: (map['id'] ?? '').toString(),
  name: (map['name'] ?? '').toString(),
  sku: map['sku']?.toString(),
  ...
  currentStock: _parseInt(map['stock_qty']),
  unitPrice: _parseDouble(map['unit_price']),
  ...
);
```

**2.3** `Consignment.toSqlMap()`

```dart
Map<String, dynamic> toSqlMap() => {
  'consignment_id': consignmentId,
  'business_associate_id': businessAssociateId,  // may be null UUID or string
  'business_associate_name': businessAssociateName,
  'status': status.name,
  'notes': notes,
  'created_at': createdAt.toIso8601String(),
  'updated_at': createdAt.toIso8601String(),
};
```

**2.4** `ConsignmentItem.toSqlMap()`

```dart
Map<String, dynamic> toSqlMap(String consignmentId) => {
  'consignment_id': consignmentId,
  'product_id': product.id,
  'units_to_assign': unitsToAssign,
  'units_sold': unitsSold,
  'unit_price': unitPrice,
  'created_at': DateTime.now().toIso8601String(),
};
```

### Phase 3: DatabaseService Integration

Add Supabase CRUD methods to `DatabaseService` (mirroring the pattern used for schools and catalog items):

**3.1** `getProducts()` — fetch from Supabase `catalog_items`, cache to Hive `catalog_products_box`

```dart
Future<void> loadProductsFromSupabase() async {
  final data = await _supabase.from('catalog_items').select().order('name');
  final products = data.map((row) => Product.fromSqlMap(row)).toList();
  // Merge with in-memory CatalogService
  CatalogService.instance.mergeFromSupabase(products);
  // Persist to Hive cache
  final box = await Hive.openBox('catalog_products_box');
  await box.put('products', products.map((p) => p.toSqlMap()).toList());
}
```

**3.2** `upsertProduct(Product product)` — upsert to Supabase + invalidate Hive cache

```dart
Future<void> upsertProduct(Product product) async {
  final userId = _supabase.auth.currentUser?.id;
  final map = product.toSqlMap();
  map['created_by'] = userId;  // if catalog_items has this column
  await _supabase.from('catalog_items').upsert(map, onConflict: 'id');
  // Also update in-memory CatalogService
  CatalogService.instance.updateProduct(product);
}
```

**3.3** `getConsignments()` — fetch from Supabase + items separately

```dart
Future<List<Consignment>> getConsignments() async {
  final rows = await _supabase.from('consignments').select();
  final items = await _supabase.from('consignment_items').select();
  // Group items by consignment_id
  final itemsByConsignment = <String, List<Map>>{};
  for (final item in items) {
    final cid = item['consignment_id'] as String;
    itemsByConsignment.putIfAbsent(cid, () => []).add(item);
  }
  // Build Consignment objects from rows + items
  return rows.map((c) {
    final cid = c['consignment_id'] as String;
    final itemMaps = itemsByConsignment[cid] ?? [];
    // Need product info — fetch from local cache or catalog_items
    ...
  }).toList();
}
```

**3.4** `upsertConsignment(Consignment c)` and `upsertConsignmentItem(...)`

### Phase 4: CatalogService Migration

**4.1** Add `mergeFromSupabase()` — merge remote products/consignments into in-memory state, dedup by ID.

**4.2** Modify `addProduct()`, `updateProduct()`, `removeProduct()`, `consumeStock()` to optionally sync to Supabase when online.

**4.3** Add `recordSale()` Supabase write — when a consignment sale is recorded:
- Update local in-memory state (existing behavior)
- Additionally insert into `event_sales` Supabase table with `consignment_id` and `consignment_item_id` references
- The `apply_consignment_sale()` trigger will atomically update `consignment_items.units_sold` and `catalog_items.stock_qty`

### Phase 5: EventOrdersPage Integration

**5.1** Update `_recordSale()` to include `consignment_id` and `consignment_item_id` in the Supabase insert to `event_sales`.

**5.2** Replace the local-only `_catalog.recordSale()` call with a Supabase-backed version that uses the `apply_consignment_sale()` trigger for atomic stock + allocation updates.

### Phase 6: Visit Check-ins

Create a lightweight Dart model for `visit_checkins` and methods in `DatabaseService` to insert check-in/out events. This table exists in the schema but has no Dart code.

### Phase 7: Background Sync Expansion

**7.1** Update `workmanager_dispatcher.dart` to also sync `catalog_products_box` (products + consignments), not just `school_box`.

**7.2** Use the existing `pending_ops_box` pattern for offline-first writes to `catalog_items`, `consignments`, `consignment_items`.

### Phase 8: One-Time Data Migration

**8.1** Create `supabase/migrate_catalog_hive_to_supabase.sql` — a SQL script that can be run manually to backfill any existing Supabase rows from a Hive export (for production data).

**8.2** The Dart-side migration is automatic: `CatalogService.init()` will call `DatabaseService.loadProductsFromSupabase()` on first load. If Supabase is empty, seed products will be upserted from the local defaults.

---

## 3. Field Mapping Summary

| Dart Model | Dart Field | Supabase Table | Supabase Column | Notes |
|---|---|---|---|---|
| `Product` | `id` | `catalog_items` | `id` (uuid) | String in Dart, ensure UUID format |
| `Product` | `name` | `catalog_items` | `name` | ✅ |
| `Product` | `sku` | `catalog_items` | `sku` | ✅ (unique constraint) |
| `Product` | `description` | `catalog_items` | `description` | ✅ |
| `Product` | `supplierId` | `catalog_items` | `supplier_id` (uuid) | Resolve to users table if needed |
| `Product` | `supplierName` | `catalog_items` | `supplier_name` | ✅ |
| `Product` | `category` | `catalog_items` | `category` | ✅ |
| `Product` | `barcode` | `catalog_items` | `barcode` | ✅ |
| `Product` | `unitPrice` | `catalog_items` | `unit_price` | ✅ |
| `Product` | `wholesalePrice` | `catalog_items` | `wholesale_price` | ✅ |
| `Product` | `unit` | `catalog_items` | `unit` | ✅ |
| `Product` | `currentStock` | `catalog_items` | `stock_qty` | ✅ |
| `Product` | `minStock` | `catalog_items` | `min_stock` | ✅ |
| `Product` | `maxStock` | `catalog_items` | `max_stock` | ✅ |
| `Product` | `imageUrl` | `catalog_items` | `image_url` | ✅ |
| `Product` | `isActive` | `catalog_items` | `is_active` | ✅ |
| `Product` | `author` | `catalog_items` | `author` | ✅ |
| `Product` | `publisher` | `catalog_items` | `publisher` | ✅ |
| `Product` | `isbn` | `catalog_items` | `isbn` | ✅ |
| `Product` | `edition` | `catalog_items` | `edition` | ✅ |
| `Product` | `gradeLevel` | `catalog_items` | `grade_level` | ✅ |
| `Product` | `subject` | `catalog_items` | `subject` | ✅ |
| `Product` | `language` | `catalog_items` | `language` | ✅ |
| `Product` | `pageCount` | `catalog_items` | `page_count` | ✅ |
| `Consignment` | `consignmentId` | `consignments` | `consignment_id` | Text PK — e.g. "CON-2526" |
| `Consignment` | `businessAssociateId` | `consignments` | `business_associate_id` | UUID FK — map from free-form string |
| `Consignment` | `businessAssociateName` | `consignments` | `business_associate_name` | ✅ |
| `Consignment` | `notes` | `consignments` | `notes` | ✅ |
| `Consignment` | `createdAt` | `consignments` | `created_at` | ✅ |
| `Consignment` | `status` | `consignments` | `status` | Enum → string name |
| `ConsignmentItem` | `product.id` (nested) | `consignment_items` | `product_id` | Flatten from embedded Product |
| `ConsignmentItem` | `unitsToAssign` | `consignment_items` | `units_to_assign` | ✅ |
| `ConsignmentItem` | `unitPrice` | `consignment_items` | `unit_price` | ✅ |
| `ConsignmentItem` | `unitsSold` | `consignment_items` | `units_sold` | ✅ |
| `ConsignmentItem` | (parent link) | `consignment_items` | `consignment_id` | FK to consignments |

---

## 4. Migration Order

1. **Schema** — apply `schema_updates_catalog_products.sql` (new file)
2. **Models** — add `toSqlMap()` / `fromSqlMap()` to `Product` and `Consignment` / `ConsignmentItem`
3. **DatabaseService** — add `upsertProduct()`, `getConsignmentFromSupabase()`, `upsertConsignment()`, `upsertConsignmentItems()`
4. **CatalogService** — add `initFromSupabase()` merge logic, add optional Supabase writes on mutations
5. **EventOrdersPage** — update `_recordSale()` to use consignment references + rely on DB trigger
6. **workmanager_dispatcher.dart** — expand background sync to `catalog_products_box`
7. **Tests** — add migration/sync tests mirroring `database_service_sync_test.dart` patterns
8. **One-time production migration** — SQL script to backfill existing Supabase tables from a Hive JSON export

---

## 5. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| **Dual write inconsistency** — if Supabase write fails, local state may diverge | Keep in-memory + Hive as the source of truth; treat Supabase as the async sync target. On next launch, re-sync from Supabase if online. |
| **ID type mismatch** — Dart `Product.id` is a string like `p1`, Supabase expects `uuid` | Use `uuid` package to generate UUIDs for new products. For seeded products with non-UUID IDs (`p1`, `p2`), assign UUIDs at migration time. |
| **businessAssociateId type** — Dart stores free-form strings like `ba1` / `ba2`, Supabase `business_associate_id` is `uuid FK` | Make `business_associate_id` nullable. Store the resolved UUID if it maps to a real user; otherwise store `null` and rely on `business_associate_name`. |
| **ConsignmentItem embeds full Product** — Dart stores the entire Product inside each item, SQL stores only `product_id` | Flatten at sync time: extract `product.id` as `product_id`, drop the embedded object |
| **Offline mode** — writes must succeed locally even without network | Keep all existing in-memory + Hive behavior as primary; queue Supabase writes for background sync |
| **RLS policy conflicts** — managers vs. agents on consignments/catalog_items | Audit existing policies; add role-appropriate `INSERT`/`UPDATE`/`DELETE` policies matching the existing school/task pattern |
| **Breaking change to CatalogService** — `recordSale` is tightly coupled to in-memory state in EventOrdersPage | Introduce a `recordSaleWithSupabase()` variant that does the DB insert + trigger, and deprecate the in-memory-only `recordSale()` |
