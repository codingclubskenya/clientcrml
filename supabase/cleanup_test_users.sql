-- Supabase cleanup script for test/demo accounts
-- Target emails: specific list + any ending in @example.com or @dehus.com
--
-- HOW TO USE:
-- 1. Open Supabase Dashboard → SQL Editor
-- 2. Paste the SELECT queries first to preview what will be deleted
-- 3. Then run the DELETE section
--
-- WARNING: This permanently deletes data. Run inside a transaction so you can ROLLBACK if needed.

-- ============================================================================
-- STEP 1: Preview users that match
-- ============================================================================
SELECT id, email, full_name, role, created_at
FROM public.users
WHERE email ILIKE '%@example.com'
   OR email ILIKE '%@dehus.com'
   OR email IN (
     'faith.agent@example.com',
     'diana.sales@example.com',
     'agent@dehus.com',
     'alice.manager@example.com',
     'grounds.role5@example.com',
     'agent.demo@dehus.com',
     'grounds.demo@dehus.com',
     'manager.role2@example.com'
   )
ORDER BY created_at;

-- ============================================================================
-- STEP 2: Preview affected records in child tables
-- ============================================================================
-- Run these individually to see counts before deleting

SELECT 'schools' AS table_name, COUNT(*) AS cnt FROM public.schools WHERE captured_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'orders' AS table_name, COUNT(*) AS cnt FROM public.orders WHERE agent_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'school_visits' AS table_name, COUNT(*) AS cnt FROM public.school_visits WHERE agent_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'tasks' AS table_name, COUNT(*) AS cnt FROM public.tasks WHERE assigned_to IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com')) OR created_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'school_sales' AS table_name, COUNT(*) AS cnt FROM public.school_sales WHERE agent_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'opportunity_activities' AS table_name, COUNT(*) AS cnt FROM public.opportunity_activities WHERE actor_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'debt_collections' AS table_name, COUNT(*) AS cnt FROM public.debt_collections WHERE collected_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'school_sample_distributions' AS table_name, COUNT(*) AS cnt FROM public.school_sample_distributions WHERE agent_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'sample_requests' AS table_name, COUNT(*) AS cnt FROM public.sample_requests WHERE requested_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com')) OR reviewed_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'messages' AS table_name, COUNT(*) AS cnt FROM public.messages WHERE sender_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com')) OR recipient_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'route_plans' AS table_name, COUNT(*) AS cnt FROM public.route_plans WHERE assigned_to IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com')) OR created_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com')) OR reviewed_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'geofences' AS table_name, COUNT(*) AS cnt FROM public.geofences WHERE assigned_to IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com')) OR created_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'regions' AS table_name, COUNT(*) AS cnt FROM public.regions WHERE assigned_to IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com')) OR supervisor_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'targets' AS table_name, COUNT(*) AS cnt FROM public.targets WHERE assigned_to IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'supervisor_alerts' AS table_name, COUNT(*) AS cnt FROM public.supervisor_alerts WHERE user_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'supervisor_incidents' AS table_name, COUNT(*) AS cnt FROM public.supervisor_incidents WHERE user_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com')) OR created_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'supervisor_notes' AS table_name, COUNT(*) AS cnt FROM public.supervisor_notes WHERE user_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com')) OR supervisor_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'supervisor_notifications' AS table_name, COUNT(*) AS cnt FROM public.supervisor_notifications WHERE supervisor_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'audit_events' AS table_name, COUNT(*) AS cnt FROM public.audit_events WHERE actor_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'project_forms' AS table_name, COUNT(*) AS cnt FROM public.project_forms WHERE created_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'project_form_responses' AS table_name, COUNT(*) AS cnt FROM public.project_form_responses WHERE respondent_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'events' AS table_name, COUNT(*) AS cnt FROM public.events WHERE created_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'event_assignments' AS table_name, COUNT(*) AS cnt FROM public.event_assignments WHERE agent_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com')) OR assigned_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'event_checkins' AS table_name, COUNT(*) AS cnt FROM public.event_checkins WHERE agent_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'event_leads' AS table_name, COUNT(*) AS cnt FROM public.event_leads WHERE agent_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'event_samples' AS table_name, COUNT(*) AS cnt FROM public.event_samples WHERE distributed_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'event_expenses' AS table_name, COUNT(*) AS cnt FROM public.event_expenses WHERE submitted_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com')) OR approved_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'event_reports' AS table_name, COUNT(*) AS cnt FROM public.event_reports WHERE created_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'school_follow_ups' AS table_name, COUNT(*) AS cnt FROM public.school_follow_ups WHERE agent_id IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));
SELECT 'task_completion_evidence' AS table_name, COUNT(*) AS cnt FROM public.task_completion_evidence WHERE submitted_by IN (SELECT id FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com'));

-- ============================================================================
-- STEP 3: Delete records (run only after verifying Step 1 & 2)
-- ============================================================================
-- Wrap in a transaction for safety. If something looks wrong, run ROLLBACK;
-- If everything looks good, run COMMIT;

BEGIN;

-- Store target user IDs in a temporary table so it persists across statements
CREATE TEMP TABLE target_users AS
SELECT id
FROM public.users
WHERE email ILIKE '%@example.com'
   OR email ILIKE '%@dehus.com'
   OR email IN (
     'faith.agent@example.com',
     'diana.sales@example.com',
     'agent@dehus.com',
     'alice.manager@example.com',
     'grounds.role5@example.com',
     'agent.demo@dehus.com',
     'grounds.demo@dehus.com',
     'manager.role2@example.com'
   );

-- Delete child records in dependency-safe order
DELETE FROM public.event_reports WHERE created_by IN (SELECT id FROM target_users);
DELETE FROM public.event_expenses WHERE submitted_by IN (SELECT id FROM target_users) OR approved_by IN (SELECT id FROM target_users);
DELETE FROM public.event_samples WHERE distributed_by IN (SELECT id FROM target_users);
DELETE FROM public.event_leads WHERE agent_id IN (SELECT id FROM target_users);
DELETE FROM public.event_checkins WHERE agent_id IN (SELECT id FROM target_users);
DELETE FROM public.event_assignments WHERE agent_id IN (SELECT id FROM target_users) OR assigned_by IN (SELECT id FROM target_users);
DELETE FROM public.events WHERE created_by IN (SELECT id FROM target_users);
DELETE FROM public.project_form_responses WHERE respondent_id IN (SELECT id FROM target_users);
DELETE FROM public.project_forms WHERE created_by IN (SELECT id FROM target_users);
DELETE FROM public.audit_events WHERE actor_id IN (SELECT id FROM target_users);
DELETE FROM public.supervisor_notifications WHERE supervisor_id IN (SELECT id FROM target_users);
DELETE FROM public.supervisor_notes WHERE user_id IN (SELECT id FROM target_users) OR supervisor_id IN (SELECT id FROM target_users);
DELETE FROM public.supervisor_incidents WHERE user_id IN (SELECT id FROM target_users) OR created_by IN (SELECT id FROM target_users);
DELETE FROM public.supervisor_alerts WHERE user_id IN (SELECT id FROM target_users);
DELETE FROM public.targets WHERE assigned_to IN (SELECT id FROM target_users);
DELETE FROM public.regions WHERE assigned_to IN (SELECT id FROM target_users) OR supervisor_id IN (SELECT id FROM target_users);
DELETE FROM public.geofences WHERE assigned_to IN (SELECT id FROM target_users) OR created_by IN (SELECT id FROM target_users);
DELETE FROM public.route_plans WHERE assigned_to IN (SELECT id FROM target_users) OR created_by IN (SELECT id FROM target_users) OR reviewed_by IN (SELECT id FROM target_users);
DELETE FROM public.messages WHERE sender_id IN (SELECT id FROM target_users) OR recipient_id IN (SELECT id FROM target_users);
DELETE FROM public.sample_requests WHERE requested_by IN (SELECT id FROM target_users) OR reviewed_by IN (SELECT id FROM target_users);
DELETE FROM public.school_sample_distributions WHERE agent_id IN (SELECT id FROM target_users);
DELETE FROM public.debt_collections WHERE collected_by IN (SELECT id FROM target_users);
DELETE FROM public.opportunity_activities WHERE actor_id IN (SELECT id FROM target_users);
DELETE FROM public.school_sales WHERE agent_id IN (SELECT id FROM target_users);
DELETE FROM public.school_follow_ups WHERE agent_id IN (SELECT id FROM target_users);
DELETE FROM public.school_visits WHERE agent_id IN (SELECT id FROM target_users);
DELETE FROM public.task_completion_evidence WHERE submitted_by IN (SELECT id FROM target_users);
DELETE FROM public.tasks WHERE assigned_to IN (SELECT id FROM target_users) OR created_by IN (SELECT id FROM target_users);
DELETE FROM public.orders WHERE agent_id IN (SELECT id FROM target_users);
DELETE FROM public.schools WHERE captured_by IN (SELECT id FROM target_users);

-- Finally delete users from auth.users (this cascades to public.users)
DELETE FROM auth.users WHERE id IN (SELECT id FROM target_users);

-- ============================================================================
-- STEP 4: Verify deletion
-- ============================================================================
SELECT COUNT(*) AS remaining_users FROM public.users WHERE email ILIKE '%@example.com' OR email ILIKE '%@dehus.com' OR email IN ('faith.agent@example.com','diana.sales@example.com','agent@dehus.com','alice.manager@example.com','grounds.role5@example.com','agent.demo@dehus.com','grounds.demo@dehus.com','manager.role2@example.com');

-- ============================================================================
-- If everything looks correct:
-- ============================================================================
-- COMMIT;

-- If something looks wrong:
-- ROLLBACK;
