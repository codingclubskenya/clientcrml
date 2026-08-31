-- Demo cleanup - auto-commit mode (no BEGIN/COMMIT/ROLLBACK)
-- Run each section separately in Supabase SQL Editor and verify the count drops to 0

-- ============================================================================
-- Section 1: Delete catalog items
-- ============================================================================
DELETE FROM public.catalog_items
WHERE created_by IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-aaaa-aaaa-aaaa-222222222222',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  '92000000-0000-0000-0000-000000000001',
  '92000000-0000-0000-0000-000000000002'
);

SELECT 'catalog_items' AS tbl, COUNT(*) AS cnt FROM public.catalog_items WHERE created_by IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002');

-- ============================================================================
-- Section 2: Delete pipeline_history
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

SELECT 'pipeline_history' AS tbl, COUNT(*) AS cnt FROM public.pipeline_history WHERE pipeline_id IN (SELECT id FROM public.school_sales WHERE agent_id IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002'));

-- ============================================================================
-- Section 3: Delete school_sales
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
    '66666666-6666-6666-6666-666666666666'
  );

SELECT 'school_sales' AS tbl, COUNT(*) AS cnt FROM public.school_sales WHERE agent_id IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002');

-- ============================================================================
-- Section 4: Delete opportunity_activities
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

SELECT 'opportunity_activities' AS tbl, COUNT(*) AS cnt FROM public.opportunity_activities WHERE actor_id IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002');

-- ============================================================================
-- Section 5: Delete school_follow_ups
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

SELECT 'school_follow_ups' AS tbl, COUNT(*) AS cnt FROM public.school_follow_ups WHERE agent_id IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','92000000-0000-0000-0000-000000000001','92000000-0000-0000-000000000002');

-- ============================================================================
-- Section 6: Delete school_sample_distributions
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

SELECT 'school_sample_distributions' AS tbl, COUNT(*) AS cnt FROM public.school_sample_distributions WHERE agent_id IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002');

-- ============================================================================
-- Section 7: Delete school_visits
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

SELECT 'school_visits' AS tbl, COUNT(*) AS cnt FROM public.school_visits WHERE agent_id IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002');

-- ============================================================================
-- Section 8: Delete order_items and orders
-- ============================================================================
DELETE FROM public.order_items
WHERE order_id IN (
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  'd1111111-d111-d111-d111-d11111111111',
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
  'f0000000-f000-f000-f000-f00000000000'
);

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

SELECT 'orders' AS tbl, COUNT(*) AS cnt FROM public.orders WHERE agent_id IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002');

-- ============================================================================
-- Section 9: Delete messages
-- ============================================================================
DELETE FROM public.messages
WHERE id IN (
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    'f1111111-f111-f111-f111-f11111111111'
  );

SELECT 'messages' AS tbl, COUNT(*) AS cnt FROM public.messages WHERE id IN ('cccccccc-cccc-cccc-cccc-cccccccccccc','dddddddd-dddd-dddd-dddd-dddddddddddd','eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee','f1111111-f111-f111-f111-f11111111111');

-- ============================================================================
-- Section 10: Delete schools
-- ============================================================================
DELETE FROM public.schools
WHERE id IN (
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333',
    '44444444-4444-4444-4444-444444444444',
    '55555555-5555-5555-5555-555555555555',
    '66666666-6666-6666-6666-666666666666'
  );

SELECT 'schools' AS tbl, COUNT(*) AS cnt FROM public.schools WHERE id IN ('22222222-2222-2222-2222-222222222222','33333333-3333-3333-3333-333333333333','44444444-4444-4444-4444-444444444444','55555555-5555-5555-5555-555555555555','66666666-6666-6666-6666-666666666666');

-- ============================================================================
-- Section 11: Delete tasks
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

SELECT 'tasks' AS tbl, COUNT(*) AS cnt FROM public.tasks WHERE assigned_to IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002');

-- ============================================================================
-- Section 12: Delete route_plans
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

SELECT 'route_plans' AS tbl, COUNT(*) AS cnt FROM public.route_plans WHERE assigned_to IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002');

-- ============================================================================
-- Section 13: Delete geofences
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

SELECT 'geofences' AS tbl, COUNT(*) AS cnt FROM public.geofences WHERE assigned_to IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002');

-- ============================================================================
-- Section 14: Delete targets
-- ============================================================================
DELETE FROM public.targets
WHERE assigned_to IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  );

SELECT 'targets' AS tbl, COUNT(*) AS cnt FROM public.targets WHERE assigned_to IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002');

-- ============================================================================
-- Section 15: Delete regions
-- ============================================================================
DELETE FROM public.regions
WHERE assigned_to IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  )
  OR supervisor_id IN (
    '22222222-aaaa-aaaa-aaaa-222222222222',
    '92000000-0000-0000-0000-000000000001'
  );

SELECT 'regions' AS tbl, COUNT(*) AS cnt FROM public.regions WHERE assigned_to IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002');

-- ============================================================================
-- Section 16: Delete supervisor data
-- ============================================================================
DELETE FROM public.supervisor_alerts
WHERE user_id IN (
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

DELETE FROM public.supervisor_notifications
WHERE supervisor_id IN (
    '22222222-aaaa-aaaa-aaaa-222222222222',
    '92000000-0000-0000-0000-000000000001'
  );

DELETE FROM public.geofence_events
WHERE user_id IN (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '92000000-0000-0000-0000-000000000001',
    '92000000-0000-0000-0000-000000000002'
  );

SELECT 'supervisor_alerts' AS tbl, COUNT(*) AS cnt FROM public.supervisor_alerts WHERE user_id IN ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002');

-- ============================================================================
-- Section 17: Delete event and project data linked to demo users
-- ============================================================================
DELETE FROM public.event_reports WHERE created_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com');
DELETE FROM public.event_expenses WHERE submitted_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com') OR approved_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com');
DELETE FROM public.event_samples WHERE distributed_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com');
DELETE FROM public.event_leads WHERE agent_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com');
DELETE FROM public.event_checkins WHERE agent_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com');
DELETE FROM public.event_assignments WHERE agent_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com') OR assigned_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com');
DELETE FROM public.events WHERE created_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com');

DELETE FROM public.project_form_responses WHERE respondent_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com');
DELETE FROM public.project_forms WHERE created_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com');

SELECT 'events' AS tbl, COUNT(*) AS cnt FROM public.events WHERE created_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com');

-- ============================================================================
-- Section 18: Delete demo users from public.users
-- ============================================================================
DELETE FROM public.users
WHERE email ILIKE '%@example.com'
   OR email ILIKE '%@dehus.com';

SELECT 'users' AS tbl, COUNT(*) AS cnt FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com';

-- ============================================================================
-- Section 19: Final verification
-- ============================================================================
SELECT 'school_sales' AS tbl, COUNT(*) AS cnt FROM public.school_sales WHERE agent_id IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')
UNION ALL
SELECT 'schools', COUNT(*) FROM public.schools WHERE id IN ('22222222-2222-2222-2222-222222222222','33333333-3333-3333-3333-333333333333','44444444-4444-4444-4444-444444444444','55555555-5555-5555-5555-555555555555','66666666-6666-6666-6666-666666666666')
UNION ALL
SELECT 'orders', COUNT(*) FROM public.orders WHERE agent_id IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')
UNION ALL
SELECT 'school_visits', COUNT(*) FROM public.school_visits WHERE agent_id IN ('11111111-1111-1111-1111-111111111111','22222222-aaaa-aaaa-aaaa-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')
UNION ALL
SELECT 'messages', COUNT(*) FROM public.messages WHERE id IN ('cccccccc-cccc-cccc-cccc-cccccccccccc','dddddddd-dddd-dddd-dddd-dddddddddddd','eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee','f1111111-f111-f111-f111-f11111111111')
UNION ALL
SELECT 'catalog_items', COUNT(*) FROM public.catalog_items WHERE created_by = '11111111-1111-1111-1111-111111111111'
UNION ALL
SELECT 'users', COUNT(*) FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com';
