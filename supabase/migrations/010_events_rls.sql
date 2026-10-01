-- Event Module Row Level Security Policies
-- Enables RLS on all event tables and creates appropriate access policies
-- Safe to rerun (drops existing policies before recreating)

-- ============================================================
-- Enable Row Level Security on event tables
-- ============================================================

alter table if exists public.events enable row level security;
alter table if exists public.event_assignments enable row level security;
alter table if exists public.event_checkins enable row level security;
alter table if exists public.event_tasks enable row level security;
alter table if exists public.event_leads enable row level security;
alter table if exists public.event_orders enable row level security;
alter table if exists public.event_samples enable row level security;
alter table if exists public.event_photos enable row level security;
alter table if exists public.event_expenses enable row level security;
alter table if exists public.event_reports enable row level security;

-- ============================================================
-- Events table policies
-- ============================================================

-- Drop existing policies
drop policy if exists "admins_can_manage_events" on public.events;
drop policy if exists "managers_can_manage_events" on public.events;
drop policy if exists "authenticated_can_view_events" on public.events;
drop policy if exists "agents_can_create_events" on public.events;

-- Admins (role 1) can do everything
create policy "admins_can_manage_events"
on public.events
for all
to authenticated
using (public.current_user_role_id() = 1)
with check (public.current_user_role_id() = 1);

-- Managers (role 2) can manage all events
create policy "managers_can_manage_events"
on public.events
for all
to authenticated
using (public.current_user_role_id() = 2)
with check (public.current_user_role_id() = 2);

-- BAS (role 3) can view events in their region
create policy "bas_can_view_events_in_region"
on public.events
for select
to authenticated
using (
  public.current_user_role_id() = 3
  and lower(coalesce(region, '')) = lower(coalesce(public.current_user_region(), ''))
);

-- Agents (roles 4-5) can view all events and create new ones
create policy "authenticated_can_view_events"
on public.events
for select
to authenticated
using (true);

-- Authenticated users can create events
create policy "agents_can_create_events"
on public.events
for insert
to authenticated
with check (true);

-- Agents can update events they created
create policy "agents_can_update_own_events"
on public.events
for update
to authenticated
using (
  created_by = auth.uid()
  or public.current_user_role_id() <= 3
)
with check (
  created_by = auth.uid()
  or public.current_user_role_id() <= 3
);

-- ============================================================
-- Event Assignments table policies
-- ============================================================

drop policy if exists "admins_can_manage_event_assignments" on public.event_assignments;
drop policy if exists "managers_can_manage_event_assignments" on public.event_assignments;
drop policy if exists "authenticated_can_view_event_assignments" on public.event_assignments;
drop policy if exists "agents_can_manage_own_assignments" on public.event_assignments;

-- Admins can manage all assignments
create policy "admins_can_manage_event_assignments"
on public.event_assignments
for all
to authenticated
using (public.current_user_role_id() = 1)
with check (public.current_user_role_id() = 1);

-- Managers can manage all assignments
create policy "managers_can_manage_event_assignments"
on public.event_assignments
for all
to authenticated
using (public.current_user_role_id() = 2)
with check (public.current_user_role_id() = 2);

-- BAS can view assignments in their region
create policy "bas_can_view_event_assignments"
on public.event_assignments
for select
to authenticated
using (
  public.current_user_role_id() = 3
  and exists (
    select 1 from public.events e
    where e.id = event_assignments.event_id
      and lower(coalesce(e.region, '')) = lower(coalesce(public.current_user_region(), ''))
  )
);

-- All authenticated users can view assignments
create policy "authenticated_can_view_event_assignments"
on public.event_assignments
for select
to authenticated
using (true);

-- Agents can create assignments (when assigning themselves or being assigned)
create policy "agents_can_create_event_assignments"
on public.event_assignments
for insert
to authenticated
with check (true);

-- Agents can update their own assignments
create policy "agents_can_update_own_assignments"
on public.event_assignments
for update
to authenticated
using (
  agent_id = auth.uid()
  or public.current_user_role_id() <= 3
)
with check (
  agent_id = auth.uid()
  or public.current_user_role_id() <= 3
);

-- ============================================================
-- Event Checkins table policies
-- ============================================================

drop policy if exists "admins_can_manage_event_checkins" on public.event_checkins;
drop policy if exists "authenticated_can_view_event_checkins" on public.event_checkins;
drop policy if exists "agents_can_create_event_checkins" on public.event_checkins;

-- Admins can manage all checkins
create policy "admins_can_manage_event_checkins"
on public.event_checkins
for all
to authenticated
using (public.current_user_role_id() = 1)
with check (public.current_user_role_id() = 1);

-- All authenticated users can view checkins
create policy "authenticated_can_view_event_checkins"
on public.event_checkins
for select
to authenticated
using (true);

-- Agents can create checkins for themselves
create policy "agents_can_create_event_checkins"
on public.event_checkins
for insert
to authenticated
with check (
  agent_id = auth.uid()
  or public.current_user_role_id() <= 2
);

-- Agents can update their own checkins
create policy "agents_can_update_own_checkins"
on public.event_checkins
for update
to authenticated
using (agent_id = auth.uid())
with check (agent_id = auth.uid());

-- ============================================================
-- Event Tasks table policies
-- ============================================================

drop policy if exists "admins_can_manage_event_tasks" on public.event_tasks;
drop policy if exists "managers_can_manage_event_tasks" on public.event_tasks;
drop policy if exists "authenticated_can_view_event_tasks" on public.event_tasks;
drop policy if exists "agents_can_update_event_tasks" on public.event_tasks;

-- Admins can manage all tasks
create policy "admins_can_manage_event_tasks"
on public.event_tasks
for all
to authenticated
using (public.current_user_role_id() = 1)
with check (public.current_user_role_id() = 1);

-- Managers can manage all tasks
create policy "managers_can_manage_event_tasks"
on public.event_tasks
for all
to authenticated
using (public.current_user_role_id() = 2)
with check (public.current_user_role_id() = 2);

-- All authenticated users can view tasks
create policy "authenticated_can_view_event_tasks"
on public.event_tasks
for select
to authenticated
using (true);

-- Agents can create tasks
create policy "agents_can_create_event_tasks"
on public.event_tasks
for insert
to authenticated
with check (true);

-- Agents can update tasks (mark as complete)
create policy "agents_can_update_event_tasks"
on public.event_tasks
for update
to authenticated
using (true)
with check (true);

-- ============================================================
-- Event Leads table policies
-- ============================================================

drop policy if exists "admins_can_manage_event_leads" on public.event_leads;
drop policy if exists "authenticated_can_view_event_leads" on public.event_leads;
drop policy if exists "agents_can_manage_event_leads" on public.event_leads;

-- Admins can manage all leads
create policy "admins_can_manage_event_leads"
on public.event_leads
for all
to authenticated
using (public.current_user_role_id() = 1)
with check (public.current_user_role_id() = 1);

-- All authenticated users can view leads
create policy "authenticated_can_view_event_leads"
on public.event_leads
for select
to authenticated
using (true);

-- Agents can create leads
create policy "agents_can_create_event_leads"
on public.event_leads
for insert
to authenticated
with check (true);

-- Agents can update their own leads
create policy "agents_can_update_own_leads"
on public.event_leads
for update
to authenticated
using (
  agent_id = auth.uid()
  or public.current_user_role_id() <= 2
)
with check (
  agent_id = auth.uid()
  or public.current_user_role_id() <= 2
);

-- ============================================================
-- Event Orders table policies
-- ============================================================

drop policy if exists "admins_can_manage_event_orders" on public.event_orders;
drop policy if exists "authenticated_can_view_event_orders" on public.event_orders;
drop policy if exists "agents_can_manage_event_orders" on public.event_orders;

-- Admins can manage all event orders
create policy "admins_can_manage_event_orders"
on public.event_orders
for all
to authenticated
using (public.current_user_role_id() = 1)
with check (public.current_user_role_id() = 1);

-- All authenticated users can view event orders
create policy "authenticated_can_view_event_orders"
on public.event_orders
for select
to authenticated
using (true);

-- Agents can create event orders
create policy "agents_can_create_event_orders"
on public.event_orders
for insert
to authenticated
with check (true);

-- Agents can update their own event orders
create policy "agents_can_update_own_event_orders"
on public.event_orders
for update
to authenticated
using (
  agent_id = auth.uid()
  or public.current_user_role_id() <= 2
)
with check (
  agent_id = auth.uid()
  or public.current_user_role_id() <= 2
);

-- ============================================================
-- Event Samples table policies
-- ============================================================

drop policy if exists "admins_can_manage_event_samples" on public.event_samples;
drop policy if exists "authenticated_can_view_event_samples" on public.event_samples;
drop policy if exists "agents_can_manage_event_samples" on public.event_samples;

-- Admins can manage all samples
create policy "admins_can_manage_event_samples"
on public.event_samples
for all
to authenticated
using (public.current_user_role_id() = 1)
with check (public.current_user_role_id() = 1);

-- All authenticated users can view samples
create policy "authenticated_can_view_event_samples"
on public.event_samples
for select
to authenticated
using (true);

-- Agents can create samples
create policy "agents_can_create_event_samples"
on public.event_samples
for insert
to authenticated
with check (true);

-- Agents can update their own samples
create policy "agents_can_update_own_samples"
on public.event_samples
for update
to authenticated
using (
  distributed_by = auth.uid()
  or public.current_user_role_id() <= 2
)
with check (
  distributed_by = auth.uid()
  or public.current_user_role_id() <= 2
);

-- ============================================================
-- Event Photos table policies
-- ============================================================

drop policy if exists "admins_can_manage_event_photos" on public.event_photos;
drop policy if exists "authenticated_can_view_event_photos" on public.event_photos;
drop policy if exists "agents_can_manage_event_photos" on public.event_photos;

-- Admins can manage all photos
create policy "admins_can_manage_event_photos"
on public.event_photos
for all
to authenticated
using (public.current_user_role_id() = 1)
with check (public.current_user_role_id() = 1);

-- All authenticated users can view photos
create policy "authenticated_can_view_event_photos"
on public.event_photos
for select
to authenticated
using (true);

-- Agents can upload photos
create policy "agents_can_create_event_photos"
on public.event_photos
for insert
to authenticated
with check (true);

-- Agents can update their own photos
create policy "agents_can_update_own_photos"
on public.event_photos
for update
to authenticated
using (
  agent_id = auth.uid()
  or public.current_user_role_id() <= 2
)
with check (
  agent_id = auth.uid()
  or public.current_user_role_id() <= 2
);

-- ============================================================
-- Event Expenses table policies
-- ============================================================

drop policy if exists "admins_can_manage_event_expenses" on public.event_expenses;
drop policy if exists "authenticated_can_view_event_expenses" on public.event_expenses;
drop policy if exists "agents_can_manage_event_expenses" on public.event_expenses;
drop policy if exists "managers_can_approve_expenses" on public.event_expenses;

-- Admins can manage all expenses
create policy "admins_can_manage_event_expenses"
on public.event_expenses
for all
to authenticated
using (public.current_user_role_id() = 1)
with check (public.current_user_role_id() = 1);

-- All authenticated users can view expenses
create policy "authenticated_can_view_event_expenses"
on public.event_expenses
for select
to authenticated
using (true);

-- Agents can create expenses
create policy "agents_can_create_event_expenses"
on public.event_expenses
for insert
to authenticated
with check (true);

-- Agents can update their own pending expenses
create policy "agents_can_update_own_expenses"
on public.event_expenses
for update
to authenticated
using (
  (submitted_by = auth.uid() and status = 'pending')
  or public.current_user_role_id() <= 2
)
with check (
  (submitted_by = auth.uid() and status = 'pending')
  or public.current_user_role_id() <= 2
);

-- Managers can approve/reject expenses
create policy "managers_can_approve_expenses"
on public.event_expenses
for update
to authenticated
using (public.current_user_role_id() <= 2)
with check (public.current_user_role_id() <= 2);

-- ============================================================
-- Event Reports table policies
-- ============================================================

drop policy if exists "admins_can_manage_event_reports" on public.event_reports;
drop policy if exists "authenticated_can_view_event_reports" on public.event_reports;
drop policy if exists "agents_can_manage_event_reports" on public.event_reports;

-- Admins can manage all reports
create policy "admins_can_manage_event_reports"
on public.event_reports
for all
to authenticated
using (public.current_user_role_id() = 1)
with check (public.current_user_role_id() = 1);

-- All authenticated users can view reports
create policy "authenticated_can_view_event_reports"
on public.event_reports
for select
to authenticated
using (true);

-- Agents can create reports
create policy "agents_can_create_event_reports"
on public.event_reports
for insert
to authenticated
with check (true);

-- Agents can update their own reports
create policy "agents_can_update_own_reports"
on public.event_reports
for update
to authenticated
using (
  created_by = auth.uid()
  or public.current_user_role_id() <= 2
)
with check (
  created_by = auth.uid()
  or public.current_user_role_id() <= 2
);

-- ============================================================
-- Grant necessary permissions to authenticated users
-- ============================================================

grant usage on schema public to authenticated;
grant all on public.events to authenticated;
grant all on public.event_assignments to authenticated;
grant all on public.event_checkins to authenticated;
grant all on public.event_tasks to authenticated;
grant all on public.event_leads to authenticated;
grant all on public.event_orders to authenticated;
grant all on public.event_samples to authenticated;
grant all on public.event_photos to authenticated;
grant all on public.event_expenses to authenticated;
grant all on public.event_reports to authenticated;

-- ============================================================
-- Storage bucket for event photos and selfies
-- ============================================================

-- Create storage bucket for event photos (run in SQL editor or via Supabase dashboard)
-- Note: Storage policies are managed separately in Supabase Storage

-- Insert bucket if not exists (requires storage.buckets table access)
insert into storage.buckets (id, name, public)
values ('event_photos', 'event_photos', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('event_selfies', 'event_selfies', true)
on conflict (id) do nothing;

-- End of event module RLS migration
