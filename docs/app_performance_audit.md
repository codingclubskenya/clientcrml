# App Performance Audit

Date: 2026-08-31

## Scope

I checked the app against this priority order:

1. Fetch less data.
2. Make fewer rebuilds.
3. Add the right database indexes.
4. Cache what can be reused.
5. Keep long work off the UI thread.

## Short Verdict

The app already has some good building blocks: local Hive storage, an offline queue, and several indexed query paths in Supabase. The main performance problem is that many screens still load whole tables or very large slices of data, then filter in Dart. That will get slow as the dataset grows.

The biggest wins are:

- Stop loading full-table datasets on dashboard and analytics screens.
- Push more filtering, grouping, and aggregation into Supabase.
- Add missing indexes for the tables that are queried by agent, school, status, and timestamp.
- Batch background sync writes instead of looping row-by-row.

## What I Found

### 1. Fetch less data

This is the biggest issue.

#### High-impact hot spots

- [lib/admin_dashboard.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/admin_dashboard.dart#L23) loads six global counts one-by-one, then loads the current user profile and recent orders in the same pass. That is fine for tiny data, but the pattern scales poorly.
- [lib/features/admin/admin_dashboard_screen.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/admin/admin_dashboard_screen.dart#L64) fetches exact counts from `tasks`, `geofences`, and `schools` every refresh.
- [lib/features/admin/analytics_page.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/admin/analytics_page.dart#L70) pulls all rows from `tasks`, `orders`, `school_sales`, `school_visits`, `users`, and `schools`, then computes metrics in memory.
- [lib/features/admin/regions_page.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/admin/regions_page.dart#L36) loads `users`, `schools`, `school_visits`, `school_sales`, and `opportunity_activities` for a whole year window, then builds regional metrics client-side.
- [lib/features/admin/admin_geofence_map_screen.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/admin/admin_geofence_map_screen.dart#L97) loads all non-admin users, all geofences, and all schools up front.
- [lib/features/admin/sample_receipts_page.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/admin/sample_receipts_page.dart#L31) loads distributions, schools, orders, and sales in one shot, then does more filtering and ROI work locally.
- [lib/features/dashboard/sample_distribution_page.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/dashboard/sample_distribution_page.dart#L130) loads up to 2,000 receipts, 2,000 orders, and 2,000 sales for a single ROI summary.
- [lib/features/admin/role2_route_plan_page.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/admin/role2_route_plan_page.dart#L49) loads all school records in pages of 1,000 and also loads a local cache copy before merging.

#### Why this matters

This pattern increases:

- initial load time
- memory usage
- network usage
- CPU time in Dart for aggregation and filtering

#### Recommended fix

- Move counting and aggregation into SQL views or RPCs.
- Use paged endpoints with explicit filters.
- Load only the columns the screen actually shows.
- Limit “admin overview” style screens to summary data and drill down on demand.

### 2. Fewer rebuilds

The app uses `setState()` heavily across large screens. That is not automatically bad, but several screens tie large data loads to broad widget rebuilds.

#### Examples

- [lib/features/dashboard/my_shops_page.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/dashboard/my_shops_page.dart#L168) rebuilds the full list whenever search or client type changes.
- [lib/features/admin/sample_receipts_page.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/admin/sample_receipts_page.dart#L113) computes filters and report sections inside `build()`.
- [lib/features/admin/regions_page.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/admin/regions_page.dart#L30) keeps the full metrics calculation inside a single stateful screen.

#### Why this matters

The rebuild cost is not the worst part here. The bigger issue is that rebuilds are coupled to expensive in-memory filtering and repeated map/list creation.

#### Recommended fix

- Split large dashboards into smaller widgets.
- Move expensive derivations out of `build()` and into cached state or view models.
- Use paginated list widgets for long tables.
- Keep filter state local to the section that needs it.

### 3. Database indexes

The schema has some useful indexes already:

- `users(role, region)`
- `tasks(assigned_to, status, due_at)`
- `geofences(region, assigned_to)`
- `route_plans(assigned_to, route_date, status)`
- several `school_sales` and event indexes

But I did not find matching indexes for several common query shapes used by the app:

- `orders.agent_id`, `orders.status`, `orders.created_at`
- `school_visits.agent_id`, `school_visits.visited_at`
- `school_sample_distributions.agent_id`, `school_sample_distributions.distributed_at`
- `messages.sender_id`, `messages.recipient_id`, `messages.created_at`
- `sample_requests.requested_by`, `sample_requests.status`, `sample_requests.requested_at`
- `schools.captured_by`

#### Why this matters

Screens like analytics, sample receipts, route planning, and inboxes repeatedly sort and filter on those columns. Without indexes, the database does more scanning as data grows.

#### Recommended fix

- Add composite indexes that match the most common filters and sort order.
- Add separate indexes only when the query patterns really need them.
- Re-check query plans after adding each index.

### 4. Caching

The app has some real caching:

- [lib/features/database/database_service.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/database/database_service.dart#L77) caches reports in Hive.
- [lib/features/database/database_service.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/database/database_service.dart#L1250) caches catalog items locally.
- [lib/features/database/database_service.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/database/database_service.dart#L787) merges Supabase schools with local Hive school data.

But caching is not used consistently for the expensive dashboard screens. Most high-cost views still hit Supabase live and then recalculate everything in Dart.

#### Recommended fix

- Cache summary reports with a short TTL.
- Cache list data that changes slowly.
- Use local data as the first render, then refresh in the background.

### 5. Background work

The background sync path is functional but not optimized.

- [lib/features/background/workmanager_dispatcher.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/background/workmanager_dispatcher.dart#L1) iterates unsynced schools and upserts them one by one.
- [lib/features/database/database_service.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/database/database_service.dart#L1610) writes single rows to Supabase or queues them locally.

#### Why this matters

Row-by-row sync is fine for low volume. It becomes slow when offline queues grow or when the app needs to recover a lot of pending data.

#### Recommended fix

- Batch upserts where possible.
- Drain the offline queue in chunks.
- Keep background jobs small and idempotent.
- Avoid rebuilding large UI state from the sync process.

## File-by-File Notes

- [lib/features/database/database_service.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/database/database_service.dart) is the main performance choke point because it mixes remote reads, local cache reads, and sync triggers in the same methods.
- [lib/features/admin/analytics_page.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/admin/analytics_page.dart) should be moved to aggregated queries or RPCs first.
- [lib/features/admin/regions_page.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/admin/regions_page.dart) should stop pulling broad datasets for year-long regional reports unless the user explicitly requests the detail.
- [lib/features/admin/sample_receipts_page.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/admin/sample_receipts_page.dart) currently does too much report building on the client.
- [lib/features/admin/admin_geofence_map_screen.dart](/home/joe/Documents/Code/dehus/dehus%20(Copy)/lib/features/admin/admin_geofence_map_screen.dart) should fetch by selected county or map viewport, not load everything up front.

## Priority Fix Plan

### Phase 1

- Replace global list loads on analytics and admin dashboards with aggregated Supabase views or RPCs.
- Add the missing indexes listed above.
- Add pagination and server-side filters to the largest list screens.

### Phase 2

- Move derived metrics out of `build()` into cached state or helper services.
- Rework the background sync path to batch inserts/upserts.
- Add cache warming for frequently viewed summary screens.

### Phase 3

- Add query profiling on the slowest screens.
- Split especially heavy dashboards into smaller feature widgets.
- Revisit image-heavy pages and add lazy loading or thumbnailing if they become a bottleneck.

## Bottom Line

The app is not fundamentally broken, but it is currently designed like a small-data app in several places. The fastest improvement is to stop shipping full tables to the client and stop calculating reports in Dart when SQL can do it better.

