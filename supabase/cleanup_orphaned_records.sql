-- Cleanup orphaned records after users were deleted.
--
-- Since the test users are already removed, their child records now have
-- NULL user FK columns. This script removes those orphaned rows.
--
-- Run each DELETE individually or as a whole in the Supabase SQL Editor.

BEGIN;

-- Schools with no valid captured_by reference
DELETE FROM public.schools
WHERE captured_by IS NULL;

-- Orders with no valid agent_id reference
DELETE FROM public.orders
WHERE agent_id IS NULL;

-- Order items for removed orders are usually cleaned by cascade,
-- but if not, explicitly delete order items whose parent order was removed above.
-- DELETE FROM public.order_items WHERE order_id NOT IN (SELECT id FROM public.orders);

-- School visits with no valid agent_id
DELETE FROM public.school_visits
WHERE agent_id IS NULL;

-- School sales with no valid agent_id
DELETE FROM public.school_sales
WHERE agent_id IS NULL;

-- Opportunity activities with no valid actor_id
DELETE FROM public.opportunity_activities
WHERE actor_id IS NULL;

-- Debt collections with no valid collected_by
DELETE FROM public.debt_collections
WHERE collected_by IS NULL;

-- School sample distributions with no valid agent_id
DELETE FROM public.school_sample_distributions
WHERE agent_id IS NULL;

-- Sample requests with no valid requested_by or reviewed_by
DELETE FROM public.sample_requests
WHERE requested_by IS NULL
   AND reviewed_by IS NULL;

-- Messages with neither sender nor recipient
DELETE FROM public.messages
WHERE sender_id IS NULL
  AND recipient_id IS NULL;

-- Route plans with no valid assigned_to/created_by/reviewed_by
DELETE FROM public.route_plans
WHERE assigned_to IS NULL
  AND created_by IS NULL
  AND reviewed_by IS NULL;

-- Geofences with no valid assigned_to/created_by
DELETE FROM public.geofences
WHERE assigned_to IS NULL
  AND created_by IS NULL;

-- Regions with no valid assigned_to/supervisor_id
DELETE FROM public.regions
WHERE assigned_to IS NULL
  AND supervisor_id IS NULL;

-- Targets with no valid assigned_to
DELETE FROM public.targets
WHERE assigned_to IS NULL;

-- Events with no valid created_by
DELETE FROM public.events
WHERE created_by IS NULL;

-- Event assignments with no valid agent_id/assigned_by
DELETE FROM public.event_assignments
WHERE agent_id IS NULL
  AND assigned_by IS NULL;

-- Event checkins with no valid agent_id
DELETE FROM public.event_checkins
WHERE agent_id IS NULL;

-- Event leads with no valid agent_id
DELETE FROM public.event_leads
WHERE agent_id IS NULL;

-- Event samples with no valid distributed_by
DELETE FROM public.event_samples
WHERE distributed_by IS NULL;

-- Event expenses with no valid submitted_by/approved_by
DELETE FROM public.event_expenses
WHERE submitted_by IS NULL
  AND approved_by IS NULL;

-- Event reports with no valid created_by
DELETE FROM public.event_reports
WHERE created_by IS NULL;

-- Project forms with no valid created_by
DELETE FROM public.project_forms
WHERE created_by IS NULL;

-- Project form responses with no valid respondent_id
DELETE FROM public.project_form_responses
WHERE respondent_id IS NULL;

-- Tasks with no valid assigned_to/created_by
DELETE FROM public.tasks
WHERE assigned_to IS NULL
  AND created_by IS NULL;

-- Task completion evidence with no valid submitted_by
DELETE FROM public.task_completion_evidence
WHERE submitted_by IS NULL;

-- School follow ups with no valid agent_id
DELETE FROM public.school_follow_ups
WHERE agent_id IS NULL;

-- Audit events with no valid actor_id
DELETE FROM public.audit_events
WHERE actor_id IS NULL;

-- Supervisor alerts with no valid user_id
DELETE FROM public.supervisor_alerts
WHERE user_id IS NULL;

-- Supervisor incidents with no valid user_id/created_by
DELETE FROM public.supervisor_incidents
WHERE user_id IS NULL
  AND created_by IS NULL;

-- Supervisor notes with no valid user_id/supervisor_id
DELETE FROM public.supervisor_notes
WHERE user_id IS NULL
  AND supervisor_id IS NULL;

-- Supervisor notifications with no valid supervisor_id
DELETE FROM public.supervisor_notifications
WHERE supervisor_id IS NULL;

SELECT 'Cleanup complete' AS status;

-- Verify nothing remains linked to deleted users via NULL checks
SELECT 'schools_orphaned' AS tbl, COUNT(*) AS cnt FROM public.schools WHERE captured_by IS NULL
UNION ALL
SELECT 'orders_orphaned', COUNT(*) FROM public.orders WHERE agent_id IS NULL
UNION ALL
SELECT 'visits_orphaned', COUNT(*) FROM public.school_visits WHERE agent_id IS NULL
UNION ALL
SELECT 'sales_orphaned', COUNT(*) FROM public.school_sales WHERE agent_id IS NULL
UNION ALL
SELECT 'tasks_orphaned', COUNT(*) FROM public.tasks WHERE assigned_to IS NULL AND created_by IS NULL;

COMMIT;
