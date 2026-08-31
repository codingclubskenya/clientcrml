# Make the app fast

This is the practical checklist for keeping the app fast.

## Priority order

1. Fetch less data.
2. Make fewer rebuilds.
3. Add the right database indexes.
4. Cache what can be reused.
5. Keep long work off the UI thread.

## Flutter

- Use `ListView.builder` and pagination for large lists.
- Split big widgets into smaller widgets so only the changed part rebuilds.
- Avoid repeated async calls inside `build()`.
- Use local state for local UI changes, not global refreshes.
- Resize images before display and use lazy loading.
- Keep animations simple and short.

## Supabase / SQL

- Select only the columns you need.
- Add indexes for common filters, joins, and sort fields.
- Use server-side filtering and paging instead of loading everything.
- Prefer one query with joins over many small queries when possible.
- Cache repeated lookups in the app when the data changes slowly.

## Sync / API

- Batch writes instead of sending one request at a time.
- Limit concurrency for slow external systems.
- Retry only failed items, not the whole job.
- Use background sync for heavy work.

## App structure

- Keep large screens split by feature.
- Move expensive calculations out of the widget tree.
- Reuse existing models and avoid repeated parsing.
- Measure before optimizing.

## What to check first

- `SRS.md` for the app’s performance requirements.
- `docs/role3_role5_supervision_backlog.md` for the performance work items.
- `docs/NAV2018_INTEGRATION_PLAN.md` for sync and rate-limiting notes.

## Rule of thumb

If the app feels slow, first ask:

- Am I loading too much?
- Am I rebuilding too much?
- Am I querying too much?
- Am I syncing too much?
