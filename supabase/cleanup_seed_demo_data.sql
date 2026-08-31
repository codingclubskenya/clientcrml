-- Cleanup script for hardcoded demo IDs from supabase/seed.sql and related seed files
--
-- This targets known dummy UUIDs used in seed.sql, seed_dynamic_crm_data.sql,
-- seed_role5_performance.sql, and seed_sample_roi_dummy.sql.
--
-- Run after cleanup_test_users.sql and cleanup_orphaned_records.sql.

BEGIN;

-- ============================================================================
-- Known demo user UUIDs
-- ============================================================================
-- faith.agent@example.com
-- manager.role2@example.com
-- grounds.role5@example.com
-- grounds.demo@dehus.com
-- agent.demo@dehus.com

-- ============================================================================
-- Delete catalog items created by demo users
-- ============================================================================
DELETE FROM public.catalog_items
WHERE created_by IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-aaaa-aaaa-aaaa-222222222222',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  '92000000-0000-0000-0000-000000000001',
  '92000000-0000-0000-0000-000000000002'
);

-- ============================================================================
-- Delete pipeline history linked to demo school_sales
-- ============================================================================
DELETE FROM public.pipeline_history
WHERE pipeline_id IN (
  SELECT id FROM public.school_sales
  WHERE agent_id IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  )
);

-- ============================================================================
-- Delete school_sales linked to demo agents or demo schools
-- ============================================================================
DELETE FROM public.school_sales
WHERE agent_id IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  )
  OR school_id IN (
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333',
    '44444444-4444-4444-4444-444444444444',
    '55555555-5555-5555-5555-555555555555',
    '66666666-6666-6666-6666-666666666666',
    'a1000000-0000-0000-0000-000000000001',
    'a1000000-0000-0000-0000-000000000002',
    'a1000000-0000-0000-0000-000000000003',
    'a1000000-0000-0000-0000-000000000004',
    'a1000000-0000-0000-0000-000000000005',
    'a1000000-0000-0000-0000-000000000006',
    'a1000000-0000-0000-0000-000000000007',
    'a1000000-0000-0000-0000-000000000008',
    'a1000000-0000-0000-0000-000000000009',
    'a1000000-0000-0000-0000-000000000010',
    'a1000000-0000-0000-0000-000000000011',
    'a1000000-0000-0000-0000-000000000012'
  );

-- ============================================================================
-- Delete opportunity_activities linked to demo school_sales or demo agents
-- ============================================================================
DELETE FROM public.opportunity_activities
WHERE actor_id IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  )
  OR school_id IN (
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333',
    '44444444-4444-4444-4444-444444444444',
    '55555555-5555-5555-5555-555555555555',
    '66666666-6666-6666-6666-666666666666'
  );

-- ============================================================================
-- Delete school_follow_ups linked to demo agents or demo schools
-- ============================================================================
DELETE FROM public.school_follow_ups
WHERE agent_id IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  )
  OR school_id IN (
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333',
    '44444444-4444-4444-4444-444444444444',
    '55555555-5555-5555-5555-555555555555',
    '66666666-6666-6666-6666-666666666666'
  );

-- ============================================================================
-- Delete school_sample_distributions linked to demo agents or demo schools
-- ============================================================================
DELETE FROM public.school_sample_distributions
WHERE agent_id IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  )
  OR school_id IN (
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333',
    '44444444-4444-4444-4444-444444444444',
    '55555555-5555-5555-5555-555555555555',
    '66666666-6666-6666-6666-666666666666'
  );

-- ============================================================================
-- Delete school_visits linked to demo agents or demo schools
-- ============================================================================
DELETE FROM public.school_visits
WHERE agent_id IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  )
  OR school_id IN (
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333',
    '44444444-4444-4444-4444-444444444444',
    '55555555-5555-5555-5555-555555555555',
    '66666666-6666-6666-6666-666666666666'
  );

-- ============================================================================
-- Delete order_items for demo orders
-- ============================================================================
DELETE FROM public.order_items
WHERE order_id IN (
  SELECT id FROM public.orders
  WHERE id IN (
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'd1111111-d111-d111-d111-d11111111111',
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    'f0000000-f000-f000-f000-f00000000000'
  )
);

-- ============================================================================
-- Delete orders linked to demo agents or demo schools
-- ============================================================================
DELETE FROM public.orders
WHERE agent_id IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  )
  OR school_id IN (
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333',
    '44444444-4444-4444-4444-444444444444',
    '55555555-5555-5555-5555-555555555555',
    '66666666-6666-6666-6666-666666666666'
  )
  OR id IN (
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'd1111111-d111-d111-d111-d11111111111',
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    'f0000000-f000-f000-f000-f00000000000'
  );

-- ============================================================================
-- Delete schools with hardcoded demo IDs
-- ============================================================================
DELETE FROM public.schools
WHERE id IN (
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333',
    '44444444-4444-4444-4444-444444444444',
    '55555555-5555-5555-5555-555555555555',
    '66666666-6666-6666-6666-666666666666',
    'a1000000-0000-0000-0000-000000000001',
    'a1000000-0000-0000-0000-000000000002',
    'a1000000-0000-0000-0000-000000000003',
    'a1000000-0000-0000-0000-000000000004',
    'a1000000-0000-0000-0000-000000000005',
    'a1000000-0000-0000-0000-000000000006',
    'a1000000-0000-0000-0000-000000000007',
    'a1000000-0000-0000-0000-000000000008',
    'a1000000-0000-0000-0000-000000000009',
    'a1000000-0000-0000-0000-000000000010',
    'a1000000-0000-0000-0000-000000000011',
    'a1000000-0000-0000-0000-000000000012'
  );

-- ============================================================================
-- Delete tasks assigned to demo users or with hardcoded demo IDs
-- ============================================================================
DELETE FROM public.tasks
WHERE assigned_to IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  )
  OR created_by IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  );

-- ============================================================================
-- Delete route plans assigned to demo users or with hardcoded demo IDs
-- ============================================================================
DELETE FROM public.route_plans
WHERE assigned_to IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  )
  OR created_by IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  )
  OR id IN (
    '77777777-7777-7777-7777-777777777777',
    '88888888-8888-8888-8888-888888888888',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  );

-- ============================================================================
-- Delete geofences assigned to demo users or with hardcoded demo IDs
-- ============================================================================
DELETE FROM public.geofences
WHERE assigned_to IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  )
  OR created_by IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  )
  OR id = '99999999-9999-9999-9999-999999999999';

-- ============================================================================
-- Delete messages with hardcoded demo IDs
-- ============================================================================
DELETE FROM public.messages
WHERE id IN (
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    'f1111111-f111-f111-f111-f11111111111'
  )
  OR sender_id IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  )
  OR recipient_id IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  );

-- ============================================================================
-- Delete supervisor data linked to demo users
-- ============================================================================
DELETE FROM public.supervisor_notifications
WHERE supervisor_id IN (
    '22222222-aaaa-aaaa-aaaa-222222222222',
    '92000000-0000-0000-0000-000000000001'
  );

DELETE FROM public.supervisor_notes
WHERE supervisor_id IN (
    '22222222-aaaa-aaaa-aaaa-222222222222',
    '92000000-0000-0000-0000-000000000001'
  )
  OR user_id IN (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  );

DELETE FROM public.supervisor_incidents
WHERE user_id IN (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  )
  OR created_by IN (
    '22222222-aaaa-aaaa-aaaa-222222222222',
    '92000000-0000-0000-0000-000000000001'
  );

DELETE FROM public.supervisor_alerts
WHERE user_id IN (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  );

DELETE FROM public.geofence_events
WHERE user_id IN (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  );

-- ============================================================================
-- Verify cleanup
-- ============================================================================
SELECT 'remaining_schools' AS tbl, COUNT(*) AS cnt FROM public.schools WHERE id IN ('22222222-2222-2222-2222-222222222222','33333333-3333-3333-3333-333333333333','44444444-4444-4444-4444-444444444444','55555555-5555-5555-5555-555555555555','66666666-6666-6666-6666-666666666666')
UNION ALL
SELECT 'remaining_orders', COUNT(*) FROM public.orders WHERE agent_id IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')
UNION ALL
SELECT 'remaining_school_visits', COUNT(*) FROM public.school_visits WHERE agent_id IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')
UNION ALL
SELECT 'remaining_school_sales', COUNT(*) FROM public.school_sales WHERE agent_id IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')
UNION ALL
SELECT 'remaining_tasks', COUNT(*) FROM public.tasks WHERE assigned_to IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')
UNION ALL
SELECT 'remaining_messages', COUNT(*) FROM public.messages WHERE id IN ('cccccccc-cccc-cccc-cccc-cccccccccccc','dddddddd-dddd-dddd-dddd-dddddddddddd','eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee','f1111111-f111-f111-f111-f11111111111')
UNION ALL
SELECT 'remaining_catalog_items', COUNT(*) FROM public.catalog_items WHERE created_by = '11111111-1111-1111-1111-111111111111';

-- ============================================================================
-- If everything looks correct:
-- ============================================================================
-- COMMIT;

-- If something looks wrong:
-- ROLLBACK;
