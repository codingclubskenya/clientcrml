-- MARGED SQL
-- Combined on 2026-05-22 07:38:50 UTC
-- Source: all .sql files found in this project

-- =========================================================
-- BEGIN FILE: supabase/demo_geofences.sql
-- =========================================================
-- Demo county geofences for admin map visualization
-- Run this after schema/seed setup.

insert into public.geofences (name, description, region, coordinates)
values
  (
    'Nairobi County Demo',
    'Demo boundary for Nairobi county.',
    'Nairobi',
    '[{"lat": -1.220, "lng": 36.760}, {"lat": -1.220, "lng": 36.940}, {"lat": -1.380, "lng": 36.940}, {"lat": -1.380, "lng": 36.760}]'::jsonb
  ),
  (
    'Mombasa County Demo',
    'Demo boundary for Mombasa county.',
    'Mombasa',
    '[{"lat": -3.930, "lng": 39.610}, {"lat": -3.930, "lng": 39.760}, {"lat": -4.120, "lng": 39.760}, {"lat": -4.120, "lng": 39.610}]'::jsonb
  ),
  (
    'Kisumu County Demo',
    'Demo boundary for Kisumu county.',
    'Kisumu',
    '[{"lat": -0.020, "lng": 34.650}, {"lat": -0.020, "lng": 34.860}, {"lat": -0.190, "lng": 34.860}, {"lat": -0.190, "lng": 34.650}]'::jsonb
  ),
  (
    'Nakuru County Demo',
    'Demo boundary for Nakuru county.',
    'Nakuru',
    '[{"lat": -0.130, "lng": 35.950}, {"lat": -0.130, "lng": 36.220}, {"lat": -0.430, "lng": 36.220}, {"lat": -0.430, "lng": 35.950}]'::jsonb
  ),
  (
    'Kiambu County Demo',
    'Demo boundary for Kiambu county.',
    'Kiambu',
    '[{"lat": -1.000, "lng": 36.620}, {"lat": -1.000, "lng": 37.000}, {"lat": -1.280, "lng": 37.000}, {"lat": -1.280, "lng": 36.620}]'::jsonb
  ),
  (
    'Uasin Gishu County Demo',
    'Demo boundary for Uasin Gishu county.',
    'Uasin Gishu',
    '[{"lat": 0.350, "lng": 35.100}, {"lat": 0.350, "lng": 35.450}, {"lat": 0.000, "lng": 35.450}, {"lat": 0.000, "lng": 35.100}]'::jsonb
  );

-- END FILE: supabase/demo_geofences.sql

-- =========================================================
-- BEGIN FILE: supabase/generate_mock_data.sql
-- =========================================================
-- Generate mock tasks + pipeline data for dashboard testing
-- Safe to rerun: uses deterministic IDs and upserts.

begin;

-- 1) Ensure task status normalization in existing rows
update public.tasks
set status = 'closed'
where lower(status) in ('complete', 'completed', 'done');

update public.tasks
set status = 'in_progress'
where lower(status) in ('in progress', 'progress');

update public.tasks
set status = 'open'
where lower(status) not in ('open', 'in_progress', 'closed');

-- 2) Insert/update demo tasks across statuses and due dates
insert into public.tasks (
  id, title, description, target_role, assigned_to, status, due_at, created_by, "isSynced"
)
values
  ('90000000-0000-0000-0000-000000000001', 'Pipeline Follow-up Call', 'Call 3 schools and confirm next action.', 5, null, 'open', now() + interval '1 day', null, true),
  ('90000000-0000-0000-0000-000000000002', 'Sample Delivery Review', 'Review sample delivery proof and update remarks.', 5, null, 'in_progress', now() + interval '3 days', null, true),
  ('90000000-0000-0000-0000-000000000003', 'Closed Task Demo', 'Already completed task for admin closed filter.', 5, null, 'closed', now() - interval '1 day', null, true),
  ('90000000-0000-0000-0000-000000000004', 'Admin Visibility Task', 'Task to verify role 1 can filter by status.', 2, null, 'closed', now() - interval '2 days', null, true)
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  target_role = excluded.target_role,
  assigned_to = excluded.assigned_to,
  status = excluded.status,
  due_at = excluded.due_at,
  created_by = excluded.created_by,
  "isSynced" = excluded."isSynced";

-- 3) Add/refresh social pipeline stage demo data from available schools
with selected_schools as (
  select id, row_number() over (order by created_at desc nulls last, id) as rn
  from public.schools
  limit 6
),
stage_matrix as (
  select * from (values
    (1, 'lead', 45000::numeric),
    (2, 'contacted', 60000::numeric),
    (3, 'meeting_scheduled', 90000::numeric),
    (4, 'negotiation', 140000::numeric),
    (5, 'won', 180000::numeric),
    (6, 'lost', 30000::numeric)
  ) as t(rn, stage, expected_value)
)
insert into public.school_sales (
  id, school_id, package_name, sale_status, expected_value, stage_updated_at, probability, notes, "isSynced"
)
select
  ('91000000-0000-0000-0000-' || lpad(ss.rn::text, 12, '0'))::uuid as id,
  ss.id as school_id,
  'Generated Demo Package' as package_name,
  sm.stage,
  sm.expected_value,
  now() - ((ss.rn::text || ' days')::interval),
  case sm.stage
    when 'won' then 100
    when 'negotiation' then 75
    when 'meeting_scheduled' then 60
    when 'contacted' then 40
    when 'lead' then 25
    when 'lost' then 0
    else 20
  end,
  'Generated demo pipeline row',
  true
from selected_schools ss
join stage_matrix sm on sm.rn = ss.rn
on conflict (id) do update set
  package_name = excluded.package_name,
  sale_status = excluded.sale_status,
  expected_value = excluded.expected_value,
  stage_updated_at = excluded.stage_updated_at,
  probability = excluded.probability,
  notes = excluded.notes,
  "isSynced" = excluded."isSynced";

commit;

-- END FILE: supabase/generate_mock_data.sql

-- =========================================================
-- BEGIN FILE: supabase/schema.sql
-- =========================================================
create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.role_id_from_text(role_text text)
returns integer
language plpgsql
immutable
as $$
begin
  if role_text is null or btrim(role_text) = '' then
    return 5;
  end if;

  case lower(btrim(role_text))
    when 'admin' then return 1;
    when 'sales manager' then return 2;
    when 'bas' then return 3;
    when 'agent' then return 4;
    when 'grounds person' then return 5;
    else
      begin
        return role_text::integer;
      exception
        when others then
          return 5;
      end;
  end case;
end;
$$;

create table if not exists public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  full_name text,
  phone text,
  role integer not null default 5,
  region text,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Ensure region, phone and isSynced columns exist (in case table was created previously)
do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'users' and column_name = 'region') then
    alter table public.users add column region text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'users' and column_name = 'phone') then
    alter table public.users add column phone text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'users' and column_name = 'isSynced') then
    alter table public.users add column "isSynced" boolean not null default false;
  end if;
end $$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'users'
      and column_name = 'role'
      and data_type <> 'integer'
  ) then
    alter table public.users
      alter column role drop default;
    alter table public.users
      alter column role type integer using public.role_id_from_text(role::text);
    alter table public.users
      alter column role set default 5;
  end if;
end $$;

alter table public.users
  alter column role set default 5;

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users
    where id = auth.uid()
      and role = 1
  );
$$;

create or replace function public.is_manager_or_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users
    where id = auth.uid()
      and role <= 3
  );
$$;

create or replace function public.is_sales_manager()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users
    where id = auth.uid()
      and role <= 2
  );
$$;

create or replace function public.is_bas()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users
    where id = auth.uid()
      and role <= 3
  );
$$;

create or replace function public.current_user_role_id()
returns integer
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (select role from public.users where id = auth.uid() limit 1),
    5
  );
$$;

create or replace function public.current_user_role_from_jwt()
returns integer
language sql
stable
as $$
  select public.role_id_from_text(
    coalesce(
      auth.jwt() -> 'user_metadata' ->> 'role',
      auth.jwt() -> 'app_metadata' ->> 'role'
    )
  );
$$;

create or replace function public.current_user_region_from_jwt()
returns text
language sql
stable
as $$
  select coalesce(
    auth.jwt() -> 'user_metadata' ->> 'region',
    auth.jwt() -> 'app_metadata' ->> 'region'
  );
$$;

create or replace function public.current_user_region()
returns text
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (select nullif(btrim(region), '') from public.users where id = auth.uid() limit 1),
    nullif(btrim(public.current_user_region_from_jwt()), '')
  );
$$;

create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text not null,
  county text not null,
  source text not null default 'manual',
  external_place_id text,
  external_vicinity text,
  "focusAreas" jsonb not null default '[]'::jsonb,
  book_category text,
  dealer_type text,
  shop_category text,
  selected_product text,
  partner_subtype text,
  latitude double precision,
  longitude double precision,
  gps_accuracy_meters double precision,
  photo_url text,
  photo_path text,
  captured_by uuid references public.users (id) on delete set null,
  captured_at timestamptz,
  capture_status text,
  contact_name text,
  contact_phone text,
  contact_title text,
  feedback text,
  notes text,
  samples_left text,
  sample_book text,
  school_ownership text,
  school_ownership_other text,
  school_population integer,
  school_lifecycle_status text,
  engagement_type text,
  sample_proof_url text,
  sample_proof_path text,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Ensure isSynced column exists in schools
do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'source') then
    alter table public.schools add column source text not null default 'manual';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'external_place_id') then
    alter table public.schools add column external_place_id text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'external_vicinity') then
    alter table public.schools add column external_vicinity text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'isSynced') then
    alter table public.schools add column "isSynced" boolean not null default false;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'book_category') then
    alter table public.schools add column book_category text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'dealer_type') then
    alter table public.schools add column dealer_type text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'shop_category') then
    alter table public.schools add column shop_category text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'selected_product') then
    alter table public.schools add column selected_product text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'partner_subtype') then
    alter table public.schools add column partner_subtype text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'gps_accuracy_meters') then
    alter table public.schools add column gps_accuracy_meters double precision;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'photo_url') then
    alter table public.schools add column photo_url text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'photo_path') then
    alter table public.schools add column photo_path text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'captured_by') then
    alter table public.schools add column captured_by uuid references public.users (id) on delete set null;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'captured_at') then
    alter table public.schools add column captured_at timestamptz;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'capture_status') then
    alter table public.schools add column capture_status text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'contact_name') then
    alter table public.schools add column contact_name text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'contact_phone') then
    alter table public.schools add column contact_phone text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'contact_title') then
    alter table public.schools add column contact_title text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'feedback') then
    alter table public.schools add column feedback text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'notes') then
    alter table public.schools add column notes text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'samples_left') then
    alter table public.schools add column samples_left text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'sample_book') then
    alter table public.schools add column sample_book text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'school_ownership') then
    alter table public.schools add column school_ownership text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'school_ownership_other') then
    alter table public.schools add column school_ownership_other text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'school_population') then
    alter table public.schools add column school_population integer;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'school_lifecycle_status') then
    alter table public.schools add column school_lifecycle_status text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'engagement_type') then
    alter table public.schools add column engagement_type text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'sample_proof_url') then
    alter table public.schools add column sample_proof_url text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'sample_proof_path') then
    alter table public.schools add column sample_proof_path text;
  end if;
end $$;

do $$
begin
  if to_regclass('public.users') is not null then
    create index if not exists idx_users_role_region on public.users(role, region);
  end if;
  if to_regclass('public.tasks') is not null then
    create index if not exists idx_tasks_assigned_status_due on public.tasks(assigned_to, status, due_at);
  end if;
  if to_regclass('public.geofences') is not null then
    create index if not exists idx_geofences_region_assigned on public.geofences(region, assigned_to);
  end if;
  if to_regclass('public.route_plans') is not null then
    create index if not exists idx_route_plans_assigned_date_status on public.route_plans(assigned_to, route_date, status);
  end if;
end $$;

create unique index if not exists idx_schools_external_place_id
  on public.schools (external_place_id)
  where external_place_id is not null;

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  target_role integer not null default 2,
  due_at timestamptz,
  status text not null default 'open',
  created_by uuid references auth.users (id) on delete set null,
  assigned_to uuid references public.users (id) on delete set null,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Ensure isSynced column exists in tasks
do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'tasks' and column_name = 'isSynced') then
    alter table public.tasks add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists public.geofences (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  region text,
  coordinates jsonb not null default '[]'::jsonb,
  assigned_to uuid references public.users (id) on delete set null,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'geofences'
      and column_name = 'region'
  ) then
    alter table public.geofences add column region text;
  end if;
end $$;

create table if not exists public.route_plans (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  route_date date not null,
  assigned_to uuid references public.users (id) on delete set null,
  school_ids jsonb not null default '[]'::jsonb,
  notes text,
  status text not null default 'assigned',
  created_by uuid references auth.users (id) on delete set null,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'route_plans' and column_name = 'reviewed_by') then
    alter table public.route_plans add column reviewed_by uuid references public.users (id) on delete set null;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'route_plans' and column_name = 'reviewed_at') then
    alter table public.route_plans add column reviewed_at timestamptz;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'route_plans' and column_name = 'review_note') then
    alter table public.route_plans add column review_note text;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'route_plans_status_check'
      and conrelid = 'public.route_plans'::regclass
  ) then
    alter table public.route_plans
      add constraint route_plans_status_check
      check (status in ('draft', 'submitted', 'approved', 'rejected', 'assigned', 'in_progress', 'completed'));
  end if;
end $$;

create table if not exists public.geofence_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  geofence_id uuid references public.geofences (id) on delete set null,
  event_type text not null,
  region text,
  lat double precision,
  lng double precision,
  reason text,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table if not exists public.supervisor_alerts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  region text,
  alert_type text not null,
  severity text not null default 'amber',
  status text not null default 'open',
  message text,
  acked_at timestamptz,
  resolved_at timestamptz,
  ack_sla_met boolean default false,
  resolve_sla_met boolean default false,
  escalated_to_admin boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.supervisor_incidents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  region text,
  incident_type text not null,
  severity text not null default 'high',
  status text not null default 'open',
  notes text,
  created_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.supervisor_notes (
  id uuid primary key default gen_random_uuid(),
  supervisor_id uuid not null references public.users (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  region text,
  context_type text,
  context_id uuid,
  note text not null,
  follow_up_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.users (id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text not null,
  region text,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.task_completion_evidence (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks (id) on delete cascade,
  submitted_by uuid not null references public.users (id) on delete cascade,
  gps_lat double precision,
  gps_lng double precision,
  proof_url text,
  proof_type text,
  created_at timestamptz not null default now()
);

create table if not exists public.supervisor_notifications (
  id uuid primary key default gen_random_uuid(),
  supervisor_id uuid not null references public.users (id) on delete cascade,
  region text,
  notification_type text not null,
  title text not null,
  body text not null,
  payload jsonb not null default '{}'::jsonb,
  scheduled_for timestamptz not null default now(),
  sent_at timestamptz,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_supervisor_alerts_status_created
  on public.supervisor_alerts(status, created_at);
create index if not exists idx_supervisor_alerts_region
  on public.supervisor_alerts(region);
create index if not exists idx_supervisor_notifications_supervisor_scheduled
  on public.supervisor_notifications(supervisor_id, scheduled_for);
create index if not exists idx_supervisor_notifications_read_at
  on public.supervisor_notifications(read_at);

create or replace function public.process_supervisor_alert_sla()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  affected_count integer := 0;
begin
  -- Mark open red alerts older than 15 minutes as SLA-breached for ack.
  update public.supervisor_alerts
  set ack_sla_met = false
  where status = 'open'
    and lower(coalesce(severity, '')) = 'red'
    and created_at <= now() - interval '15 minutes'
    and coalesce(ack_sla_met, true) = true;
  get diagnostics affected_count = row_count;

  -- Escalate unresolved red alerts older than 2 hours.
  with to_escalate as (
    update public.supervisor_alerts
    set escalated_to_admin = true
    where status = 'open'
      and lower(coalesce(severity, '')) = 'red'
      and created_at <= now() - interval '2 hours'
      and coalesce(escalated_to_admin, false) = false
    returning id, user_id, region, alert_type
  )
  insert into public.supervisor_notifications (
    supervisor_id,
    region,
    notification_type,
    title,
    body,
    payload,
    scheduled_for
  )
  select
    u.id,
    u.region,
    'escalation',
    'Escalated Red Alert',
    'A red alert is unresolved for over 2 hours and has been escalated.',
    jsonb_build_object('alert_id', e.id, 'alert_type', e.alert_type, 'user_id', e.user_id),
    now()
  from to_escalate e
  join public.users u
    on u.role = 3
   and lower(coalesce(u.region, '')) = lower(coalesce(e.region, ''));

  return affected_count;
end;
$$;

create or replace function public.queue_supervisor_daily_digests()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted_count integer := 0;
  batch_count integer := 0;
begin
  -- Morning digest at 07:00 local DB time.
  if to_char(now(), 'HH24:MI') between '07:00' and '07:10' then
    insert into public.supervisor_notifications (
      supervisor_id,
      region,
      notification_type,
      title,
      body,
      payload,
      scheduled_for
    )
    select
      s.id,
      s.region,
      'daily_digest',
      'Morning Supervision Digest',
      'Start-of-day summary for your Role 5 region.',
      jsonb_build_object(
        'open_alerts', (
          select count(*)
          from public.supervisor_alerts a
          where lower(coalesce(a.region, '')) = lower(coalesce(s.region, ''))
            and a.status = 'open'
        ),
        'overdue_tasks', (
          select count(*)
          from public.tasks t
          join public.users u on u.id = t.assigned_to
          where u.role = 5
            and lower(coalesce(u.region, '')) = lower(coalesce(s.region, ''))
            and t.due_at < now()
            and lower(coalesce(t.status, '')) not in ('closed', 'completed')
        )
      ),
      now()
    from public.users s
    where s.role = 3;
    get diagnostics batch_count = row_count;
    inserted_count := inserted_count + batch_count;
  end if;

  -- Evening digest at 18:00 local DB time.
  if to_char(now(), 'HH24:MI') between '18:00' and '18:10' then
    insert into public.supervisor_notifications (
      supervisor_id,
      region,
      notification_type,
      title,
      body,
      payload,
      scheduled_for
    )
    select
      s.id,
      s.region,
      'evening_summary',
      'Evening Supervision Summary',
      'End-of-day summary for Role 5 execution in your region.',
      jsonb_build_object(
        'resolved_alerts', (
          select count(*)
          from public.supervisor_alerts a
          where lower(coalesce(a.region, '')) = lower(coalesce(s.region, ''))
            and a.status = 'resolved'
            and a.resolved_at >= date_trunc('day', now())
        ),
        'completed_routes', (
          select count(*)
          from public.route_plans r
          join public.users u on u.id = r.assigned_to
          where u.role = 5
            and lower(coalesce(u.region, '')) = lower(coalesce(s.region, ''))
            and lower(coalesce(r.status, '')) = 'completed'
            and r.route_date = current_date
        )
      ),
      now()
    from public.users s
    where s.role = 3;
    get diagnostics batch_count = row_count;
    inserted_count := inserted_count + batch_count;
  end if;

  return inserted_count;
end;
$$;

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'route_plans' and column_name = 'isSynced') then
    alter table public.route_plans add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists public.catalog_items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  sku text not null unique,
  item_type text not null default 'sale',
  unit_price numeric(12,2) not null default 0,
  stock_qty integer not null default 0,
  description text,
  is_active boolean not null default true,
  "isSynced" boolean not null default false,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'catalog_items' and column_name = 'isSynced') then
    alter table public.catalog_items add column "isSynced" boolean not null default false;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'catalog_items' and column_name = 'is_active') then
    alter table public.catalog_items add column is_active boolean not null default true;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'catalog_items' and column_name = 'item_type') then
    alter table public.catalog_items add column item_type text not null default 'sale';
  end if;
end $$;

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools (id) on delete set null,
  school_name text not null,
  school_phone text,
  agent_id uuid references public.users (id) on delete set null,
  order_number text not null unique,
  payment_method text not null default 'cash',
  payment_reference text,
  checkout_amount numeric(12,2) not null default 0,
  status text not null default 'pending',
  notes text,
  submitted_at timestamptz,
  approved_at timestamptz,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'orders' and column_name = 'isSynced') then
    alter table public.orders add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  product_name text not null,
  category text,
  sku text,
  quantity integer not null default 1,
  unit_price numeric(12,2) not null default 0,
  line_total numeric(12,2) not null default 0,
  notes text,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'order_items' and column_name = 'isSynced') then
    alter table public.order_items add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.users (id) on delete cascade,
  recipient_id uuid not null references public.users (id) on delete cascade,
  subject text not null,
  body text not null,
  related_school_id uuid references public.schools (id) on delete set null,
  related_task_id uuid references public.tasks (id) on delete set null,
  is_read boolean not null default false,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'messages' and column_name = 'isSynced') then
    alter table public.messages add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists public.school_visits (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  agent_id uuid references public.users (id) on delete set null,
  outcome text,
  notes text,
  photo_url text,
  photo_path text,
  latitude double precision,
  longitude double precision,
  visit_status text not null default 'completed',
  visited_at timestamptz not null default now(),
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_visits' and column_name = 'isSynced') then
    alter table public.school_visits add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists public.school_follow_ups (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  agent_id uuid references public.users (id) on delete set null,
  contact_person text,
  next_step text,
  due_at timestamptz,
  notes text,
  follow_up_status text not null default 'open',
  completed_at timestamptz,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_follow_ups' and column_name = 'isSynced') then
    alter table public.school_follow_ups add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists public.debt_collections (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  collected_by uuid references public.users (id) on delete set null,
  amount numeric(12,2) not null check (amount > 0),
  payment_method text not null default 'cash',
  payment_reference text,
  notes text,
  collected_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.school_sales (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  agent_id uuid references public.users (id) on delete set null,
  package_name text not null,
  expected_value numeric(12,2),
  notes text,
  sale_status text not null default 'lead' check (
    sale_status in (
      'lead',
      'contacted',
      'meeting_scheduled',
      'sample_issued',
      'quotation_sent',
      'decision_pending',
      'negotiation',
      'won',
      'lost',
      'dormant'
    )
  ),
  stage_contact_person text,
  sample_quantity integer check (sample_quantity is null or sample_quantity >= 0),
  quotation_reference text,
  decision_owner text,
  negotiation_topic text,
  loss_reason text,
  dormant_reason text,
  stage_updated_at timestamptz,
  expected_close_date date,
  probability integer not null default 0 check (probability >= 0 and probability <= 100),
  closed_at timestamptz,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'isSynced') then
    alter table public.school_sales add column "isSynced" boolean not null default false;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'next_action') then
    alter table public.school_sales add column next_action text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'next_action_date') then
    alter table public.school_sales add column next_action_date date;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'last_activity_at') then
    alter table public.school_sales add column last_activity_at timestamptz;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'forecast_category') then
    alter table public.school_sales add column forecast_category text default 'pipeline';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'risk_level') then
    alter table public.school_sales add column risk_level text default 'low';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'weighted_forecast') then
    alter table public.school_sales add column weighted_forecast numeric(12,2) default 0;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'stage_sla_due_at') then
    alter table public.school_sales add column stage_sla_due_at timestamptz;
  end if;
end $$;

create index if not exists idx_school_sales_stage_sla_due_at
  on public.school_sales (stage_sla_due_at);
create index if not exists idx_school_sales_next_action_date
  on public.school_sales (next_action_date);
create index if not exists idx_school_sales_risk_level
  on public.school_sales (risk_level);

create table if not exists public.opportunity_activities (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references public.school_sales (id) on delete cascade,
  school_id uuid references public.schools (id) on delete set null,
  actor_id uuid references public.users (id) on delete set null,
  activity_type text not null,
  activity_outcome text,
  notes text,
  next_action text,
  next_action_date date,
  created_at timestamptz not null default now()
);

create index if not exists idx_opportunity_activities_opportunity
  on public.opportunity_activities (opportunity_id, created_at desc);

create or replace function public.refresh_school_sale_metrics()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_expected numeric(12,2) := coalesce(new.expected_value, 0);
  v_probability integer := coalesce(new.probability, 0);
  v_stage text := lower(coalesce(new.sale_status, 'lead'));
  v_sla_days integer := 5;
begin
  new.weighted_forecast := round((v_expected * v_probability) / 100.0, 2);

  if v_stage in ('lead', 'contacted') then
    v_sla_days := 3;
  elsif v_stage in ('meeting_scheduled', 'sample_issued') then
    v_sla_days := 5;
  elsif v_stage in ('quotation_sent', 'decision_pending', 'negotiation') then
    v_sla_days := 7;
  end if;

  if new.stage_sla_due_at is null then
    new.stage_sla_due_at := now() + make_interval(days => v_sla_days);
  end if;

  if v_stage in ('won', 'lost') then
    new.risk_level := 'low';
  elsif new.next_action_date is null then
    new.risk_level := 'high';
  elsif new.next_action_date < current_date then
    new.risk_level := 'high';
  elsif new.next_action_date <= current_date + 1 then
    new.risk_level := 'medium';
  else
    new.risk_level := 'low';
  end if;

  return new;
end;
$$;

drop trigger if exists derive_school_sale_metrics on public.school_sales;
create trigger derive_school_sale_metrics
before insert or update on public.school_sales
for each row execute procedure public.refresh_school_sale_metrics();

create or replace function public.enforce_school_sale_followup()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stage text := lower(coalesce(new.sale_status, 'lead'));
begin
  if v_stage not in ('won', 'lost', 'dormant') then
    -- Auto-fill defaults during migration/legacy updates to avoid hard failures.
    if nullif(btrim(coalesce(new.next_action, '')), '') is null then
      new.next_action := 'Follow up call';
    end if;
    if new.next_action_date is null then
      new.next_action_date := current_date + 2;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_school_sale_followup_trigger on public.school_sales;
create trigger enforce_school_sale_followup_trigger
before insert or update on public.school_sales
for each row execute procedure public.enforce_school_sale_followup();

update public.school_sales
set
  next_action = coalesce(nullif(btrim(next_action), ''), 'Follow up call'),
  next_action_date = coalesce(next_action_date, current_date + 2)
where lower(coalesce(sale_status, 'lead')) not in ('won', 'lost', 'dormant')
  and (
    nullif(btrim(coalesce(next_action, '')), '') is null
    or next_action_date is null
  );

create or replace function public.sync_opportunity_activity_to_sale()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if nullif(btrim(coalesce(new.next_action, '')), '') is null then
    raise exception 'next_action is required when logging opportunity activity';
  end if;
  if new.next_action_date is null then
    raise exception 'next_action_date is required when logging opportunity activity';
  end if;

  update public.school_sales
  set
    last_activity_at = new.created_at,
    next_action = new.next_action,
    next_action_date = new.next_action_date,
    stage_updated_at = now()
  where id = new.opportunity_id;

  return new;
end;
$$;

drop trigger if exists sync_opportunity_activity_to_sale_trigger on public.opportunity_activities;
create trigger sync_opportunity_activity_to_sale_trigger
after insert on public.opportunity_activities
for each row execute procedure public.sync_opportunity_activity_to_sale();

create or replace function public.enforce_role5_task_completion_evidence()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_role5 boolean := false;
  v_has_evidence boolean := false;
begin
  if lower(coalesce(new.status, '')) not in ('closed', 'completed') then
    return new;
  end if;

  if lower(coalesce(old.status, '')) in ('closed', 'completed') then
    return new;
  end if;

  select exists (
    select 1 from public.users u
    where u.id = new.assigned_to
      and u.role = 5
  ) into v_is_role5;

  if not v_is_role5 then
    return new;
  end if;

  select exists (
    select 1
    from public.task_completion_evidence e
    where e.task_id = new.id
      and e.gps_lat is not null
      and e.gps_lng is not null
      and nullif(btrim(coalesce(e.proof_url, '')), '') is not null
  ) into v_has_evidence;

  if not v_has_evidence then
    raise exception 'Role 5 task completion requires evidence with GPS and proof_url';
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_role5_task_completion_evidence_trigger on public.tasks;
create trigger enforce_role5_task_completion_evidence_trigger
before update on public.tasks
for each row execute procedure public.enforce_role5_task_completion_evidence();

create or replace function public.generate_overdue_followup_alerts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted_count integer := 0;
begin
  insert into public.supervisor_alerts (
    user_id,
    region,
    alert_type,
    severity,
    status,
    message,
    created_at
  )
  select
    s.agent_id as user_id,
    u.region,
    'overdue_followup',
    'amber',
    'open',
    'Opportunity follow-up is overdue for assigned Role 5 user.',
    now()
  from public.school_sales s
  join public.users u on u.id = s.agent_id
  where u.role = 5
    and s.next_action_date is not null
    and s.next_action_date < current_date
    and lower(coalesce(s.sale_status, '')) not in ('won', 'lost', 'dormant')
    and not exists (
      select 1
      from public.supervisor_alerts a
      where a.user_id = s.agent_id
        and a.alert_type = 'overdue_followup'
        and a.status = 'open'
        and a.created_at >= now() - interval '24 hours'
    );

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;

create table if not exists public.pipeline_history (
  id uuid primary key default gen_random_uuid(),
  pipeline_id uuid not null references public.school_sales (id) on delete cascade,
  old_stage text,
  new_stage text not null,
  changed_by uuid references public.users (id) on delete set null,
  changed_at timestamptz not null default now(),
  notes text
);

create index if not exists idx_pipeline_history_pipeline_id
  on public.pipeline_history (pipeline_id);

create index if not exists idx_pipeline_history_changed_at
  on public.pipeline_history (changed_at desc);

create or replace function public.log_pipeline_stage_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.pipeline_history (pipeline_id, old_stage, new_stage, changed_by, notes)
    values (new.id, null, new.sale_status, auth.uid(), new.notes);
    return new;
  end if;

  if tg_op = 'UPDATE' and coalesce(new.sale_status, '') <> coalesce(old.sale_status, '') then
    insert into public.pipeline_history (pipeline_id, old_stage, new_stage, changed_by, notes)
    values (new.id, old.sale_status, new.sale_status, auth.uid(), new.notes);
  end if;

  return new;
end;
$$;

create table if not exists public.school_sample_distributions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  agent_id uuid references public.users (id) on delete set null,
  sample_name text not null,
  sample_category text,
  quantity integer not null default 1,
  stamped_receipt_url text,
  stamped_receipt_path text,
  notes text,
  distributed_at timestamptz not null default now(),
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sample_distributions' and column_name = 'isSynced') then
    alter table public.school_sample_distributions add column "isSynced" boolean not null default false;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sample_distributions' and column_name = 'stamped_receipt_url') then
    alter table public.school_sample_distributions add column stamped_receipt_url text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sample_distributions' and column_name = 'stamped_receipt_path') then
    alter table public.school_sample_distributions add column stamped_receipt_path text;
  end if;
end $$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.users (id, email, full_name, phone, role, region)
  values (
    new.id,
    new.email,
    coalesce(nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''), 'Not Captured'),
    coalesce(nullif(btrim(new.raw_user_meta_data ->> 'phone'), ''), 'Not Captured'),
    public.role_id_from_text(new.raw_user_meta_data ->> 'role'),
    coalesce(nullif(btrim(new.raw_user_meta_data ->> 'region'), ''), 'Not Captured')
  )
  on conflict (id) do update
  set email = excluded.email,
      full_name = excluded.full_name,
      phone = excluded.phone,
      role = excluded.role,
      region = excluded.region;
  return new;
end;
$$;

create or replace function public.handle_updated_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update public.users
  set email = new.email,
      full_name = coalesce(nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''), full_name, 'Not Captured'),
      phone = coalesce(nullif(btrim(new.raw_user_meta_data ->> 'phone'), ''), phone, 'Not Captured'),
      region = coalesce(nullif(btrim(new.raw_user_meta_data ->> 'region'), ''), region, 'Not Captured')
      -- Keep role untouched so admin changes in public.users are not overwritten by auth metadata.
  where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
after update on auth.users
for each row execute procedure public.handle_updated_user();

-- Backfill existing auth users into public.users so current accounts are linked too.
insert into public.users (id, email, full_name, phone, role, region)
select
  u.id,
  u.email,
  coalesce(nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''), 'Not Captured'),
  coalesce(nullif(btrim(u.raw_user_meta_data ->> 'phone'), ''), 'Not Captured'),
  public.role_id_from_text(u.raw_user_meta_data ->> 'role'),
  coalesce(nullif(btrim(u.raw_user_meta_data ->> 'region'), ''), 'Not Captured')
from auth.users u
on conflict (id) do update
set email = excluded.email,
    full_name = excluded.full_name,
    phone = excluded.phone,
    role = excluded.role,
    region = excluded.region;

drop trigger if exists touch_users_updated_at on public.users;
create trigger touch_users_updated_at
before update on public.users
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_schools_updated_at on public.schools;
create trigger touch_schools_updated_at
before update on public.schools
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_tasks_updated_at on public.tasks;
create trigger touch_tasks_updated_at
before update on public.tasks
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_geofences_updated_at on public.geofences;
create trigger touch_geofences_updated_at
before update on public.geofences
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_route_plans_updated_at on public.route_plans;
create trigger touch_route_plans_updated_at
before update on public.route_plans
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_catalog_items_updated_at on public.catalog_items;
create trigger touch_catalog_items_updated_at
before update on public.catalog_items
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_orders_updated_at on public.orders;
create trigger touch_orders_updated_at
before update on public.orders
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_order_items_updated_at on public.order_items;
create trigger touch_order_items_updated_at
before update on public.order_items
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_messages_updated_at on public.messages;
create trigger touch_messages_updated_at
before update on public.messages
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_school_visits_updated_at on public.school_visits;
create trigger touch_school_visits_updated_at
before update on public.school_visits
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_school_follow_ups_updated_at on public.school_follow_ups;
create trigger touch_school_follow_ups_updated_at
before update on public.school_follow_ups
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_debt_collections_updated_at on public.debt_collections;
create trigger touch_debt_collections_updated_at
before update on public.debt_collections
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_school_sales_updated_at on public.school_sales;
create trigger touch_school_sales_updated_at
before update on public.school_sales
for each row execute procedure public.set_updated_at();

drop trigger if exists log_school_sales_stage_change on public.school_sales;
create trigger log_school_sales_stage_change
after insert or update on public.school_sales
for each row execute procedure public.log_pipeline_stage_change();

drop trigger if exists touch_school_sample_distributions_updated_at on public.school_sample_distributions;
create trigger touch_school_sample_distributions_updated_at
before update on public.school_sample_distributions
for each row execute procedure public.set_updated_at();

alter table public.users enable row level security;
alter table public.schools enable row level security;
alter table public.tasks enable row level security;
alter table public.geofences enable row level security;
alter table public.route_plans enable row level security;
alter table public.catalog_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.messages enable row level security;
alter table public.school_visits enable row level security;
alter table public.school_follow_ups enable row level security;
alter table public.debt_collections enable row level security;
alter table public.school_sales enable row level security;
alter table public.pipeline_history enable row level security;
alter table public.school_sample_distributions enable row level security;
alter table public.opportunity_activities enable row level security;
alter table public.geofence_events enable row level security;
alter table public.supervisor_alerts enable row level security;
alter table public.supervisor_incidents enable row level security;
alter table public.supervisor_notes enable row level security;
alter table public.audit_events enable row level security;
alter table public.task_completion_evidence enable row level security;
alter table public.supervisor_notifications enable row level security;

drop policy if exists "users_can_manage_own_row" on public.users;
create policy "users_can_manage_own_row"
on public.users
for all
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "authenticated_can_view_users" on public.users;
create policy "authenticated_can_view_users"
on public.users
for select
to authenticated
using (
  auth.uid() = id
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and role = 5
    and lower(coalesce(region, '')) = lower(coalesce(public.current_user_region(), ''))
  )
);

drop policy if exists "admins_can_manage_users" on public.users;
create policy "admins_can_manage_users"
on public.users
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "authenticated_can_manage_schools" on public.schools;
create policy "authenticated_can_manage_schools"
on public.schools
for all
to authenticated
using (true)
with check (true);

drop policy if exists "authenticated_can_view_assigned_tasks" on public.tasks;
create policy "authenticated_can_view_assigned_tasks"
on public.tasks
for select
to authenticated
using (
  target_role = 0
  or target_role >= public.current_user_role_id()
  or assigned_to = auth.uid()
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and exists (
      select 1
      from public.users u
      where u.id = public.tasks.assigned_to
        and u.role = 5
        and lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
    )
  )
);

drop policy if exists "admins_can_manage_tasks" on public.tasks;
drop policy if exists "managers_can_manage_tasks" on public.tasks;
create policy "managers_can_manage_tasks"
on public.tasks
for all
to authenticated
using (
  public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and exists (
      select 1
      from public.users u
      where u.id = public.tasks.assigned_to
        and u.role = 5
        and lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
    )
  )
)
with check (
  public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and exists (
      select 1
      from public.users u
      where u.id = public.tasks.assigned_to
        and u.role = 5
        and lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
    )
  )
);

drop policy if exists "authenticated_can_view_geofences" on public.geofences;
create policy "authenticated_can_view_geofences"
on public.geofences
for select
to authenticated
using (
  assigned_to = auth.uid()
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and (
      lower(coalesce(public.geofences.region, '')) = lower(coalesce(public.current_user_region(), ''))
      or exists (
        select 1
        from public.users u
        where u.id = public.geofences.assigned_to
          and u.role = 5
          and lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
      )
    )
  )
);

drop policy if exists "managers_can_manage_geofences" on public.geofences;
create policy "managers_can_manage_geofences"
on public.geofences
for all
to authenticated
using (
  public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and (
      lower(coalesce(public.geofences.region, '')) = lower(coalesce(public.current_user_region(), ''))
      or exists (
        select 1
        from public.users u
        where u.id = public.geofences.assigned_to
          and u.role = 5
          and lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
      )
    )
  )
)
with check (
  public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and (
      lower(coalesce(public.geofences.region, '')) = lower(coalesce(public.current_user_region(), ''))
      or exists (
        select 1
        from public.users u
        where u.id = public.geofences.assigned_to
          and u.role = 5
          and lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
      )
    )
  )
);

drop policy if exists "authenticated_can_view_route_plans" on public.route_plans;
create policy "authenticated_can_view_route_plans"
on public.route_plans
for select
to authenticated
using (
  assigned_to = auth.uid()
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and exists (
      select 1
      from public.users u
      where u.id = public.route_plans.assigned_to
        and u.role = 5
        and lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
    )
  )
);

drop policy if exists "managers_can_manage_route_plans" on public.route_plans;
create policy "managers_can_manage_route_plans"
on public.route_plans
for all
to authenticated
using (
  public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and exists (
      select 1
      from public.users u
      where u.id = public.route_plans.assigned_to
        and u.role = 5
        and lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
    )
  )
)
with check (
  public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and exists (
      select 1
      from public.users u
      where u.id = public.route_plans.assigned_to
        and u.role = 5
        and lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
    )
  )
);

drop policy if exists "role5_can_submit_route_plans" on public.route_plans;
create policy "role5_can_submit_route_plans"
on public.route_plans
for update
to authenticated
using (assigned_to = auth.uid())
with check (
  assigned_to = auth.uid()
  and status in ('submitted', 'in_progress', 'completed')
);

drop policy if exists "authenticated_can_view_geofence_events" on public.geofence_events;
create policy "authenticated_can_view_geofence_events"
on public.geofence_events
for select
to authenticated
using (
  user_id = auth.uid()
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and lower(coalesce(region, '')) = lower(coalesce(public.current_user_region(), ''))
  )
);

drop policy if exists "authenticated_can_manage_geofence_events" on public.geofence_events;
create policy "authenticated_can_manage_geofence_events"
on public.geofence_events
for all
to authenticated
using (
  user_id = auth.uid()
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and lower(coalesce(region, '')) = lower(coalesce(public.current_user_region(), ''))
  )
)
with check (
  user_id = auth.uid()
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and lower(coalesce(region, '')) = lower(coalesce(public.current_user_region(), ''))
  )
);

drop policy if exists "authenticated_can_view_supervisor_alerts" on public.supervisor_alerts;
create policy "authenticated_can_view_supervisor_alerts"
on public.supervisor_alerts
for select
to authenticated
using (
  user_id = auth.uid()
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and lower(coalesce(region, '')) = lower(coalesce(public.current_user_region(), ''))
  )
);

drop policy if exists "managers_can_manage_supervisor_alerts" on public.supervisor_alerts;
create policy "managers_can_manage_supervisor_alerts"
on public.supervisor_alerts
for all
to authenticated
using (public.current_user_role_id() <= 3)
with check (public.current_user_role_id() <= 3);

drop policy if exists "authenticated_can_view_supervisor_incidents" on public.supervisor_incidents;
create policy "authenticated_can_view_supervisor_incidents"
on public.supervisor_incidents
for select
to authenticated
using (
  user_id = auth.uid()
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and lower(coalesce(region, '')) = lower(coalesce(public.current_user_region(), ''))
  )
);

drop policy if exists "managers_can_manage_supervisor_incidents" on public.supervisor_incidents;
create policy "managers_can_manage_supervisor_incidents"
on public.supervisor_incidents
for all
to authenticated
using (public.current_user_role_id() <= 3)
with check (public.current_user_role_id() <= 3);

drop policy if exists "authenticated_can_view_supervisor_notes" on public.supervisor_notes;
create policy "authenticated_can_view_supervisor_notes"
on public.supervisor_notes
for select
to authenticated
using (
  user_id = auth.uid()
  or supervisor_id = auth.uid()
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and lower(coalesce(region, '')) = lower(coalesce(public.current_user_region(), ''))
  )
);

drop policy if exists "managers_can_manage_supervisor_notes" on public.supervisor_notes;
create policy "managers_can_manage_supervisor_notes"
on public.supervisor_notes
for all
to authenticated
using (supervisor_id = auth.uid() or public.current_user_role_id() <= 2)
with check (supervisor_id = auth.uid() or public.current_user_role_id() <= 2);

drop policy if exists "admins_can_view_audit_events" on public.audit_events;
create policy "admins_can_view_audit_events"
on public.audit_events
for select
to authenticated
using (public.current_user_role_id() <= 2);

drop policy if exists "managers_can_insert_audit_events" on public.audit_events;
create policy "managers_can_insert_audit_events"
on public.audit_events
for insert
to authenticated
with check (public.current_user_role_id() <= 3);

drop policy if exists "authenticated_can_view_task_completion_evidence" on public.task_completion_evidence;
create policy "authenticated_can_view_task_completion_evidence"
on public.task_completion_evidence
for select
to authenticated
using (
  submitted_by = auth.uid()
  or exists (
    select 1
    from public.tasks t
    where t.id = task_id
      and (t.assigned_to = auth.uid() or public.current_user_role_id() <= 3)
  )
);

drop policy if exists "authenticated_can_manage_task_completion_evidence" on public.task_completion_evidence;
create policy "authenticated_can_manage_task_completion_evidence"
on public.task_completion_evidence
for all
to authenticated
using (submitted_by = auth.uid() or public.current_user_role_id() <= 3)
with check (submitted_by = auth.uid() or public.current_user_role_id() <= 3);

drop policy if exists "authenticated_can_view_supervisor_notifications" on public.supervisor_notifications;
create policy "authenticated_can_view_supervisor_notifications"
on public.supervisor_notifications
for select
to authenticated
using (
  supervisor_id = auth.uid()
  or public.current_user_role_id() <= 2
);

drop policy if exists "authenticated_can_update_supervisor_notifications" on public.supervisor_notifications;
create policy "authenticated_can_update_supervisor_notifications"
on public.supervisor_notifications
for update
to authenticated
using (
  supervisor_id = auth.uid()
  or public.current_user_role_id() <= 2
)
with check (
  supervisor_id = auth.uid()
  or public.current_user_role_id() <= 2
);

drop policy if exists "managers_can_insert_supervisor_notifications" on public.supervisor_notifications;
create policy "managers_can_insert_supervisor_notifications"
on public.supervisor_notifications
for insert
to authenticated
with check (public.current_user_role_id() <= 3);

drop policy if exists "authenticated_can_view_catalog_items" on public.catalog_items;
create policy "authenticated_can_view_catalog_items"
on public.catalog_items
for select
to authenticated
using (is_active = true or public.is_manager_or_admin());

drop policy if exists "admins_can_manage_catalog_items" on public.catalog_items;
drop policy if exists "managers_can_manage_catalog_items" on public.catalog_items;
create policy "managers_can_manage_catalog_items"
on public.catalog_items
for all
to authenticated
using (public.is_manager_or_admin())
with check (public.is_manager_or_admin());

drop policy if exists "authenticated_can_view_orders" on public.orders;
create policy "authenticated_can_view_orders"
on public.orders
for select
to authenticated
using (
  agent_id = auth.uid()
  or public.is_manager_or_admin()
);

drop policy if exists "authenticated_can_manage_orders" on public.orders;
create policy "authenticated_can_manage_orders"
on public.orders
for all
to authenticated
using (
  agent_id = auth.uid()
  or public.is_manager_or_admin()
)
with check (
  agent_id = auth.uid()
  or public.is_manager_or_admin()
);

drop policy if exists "authenticated_can_view_order_items" on public.order_items;
create policy "authenticated_can_view_order_items"
on public.order_items
for select
to authenticated
using (
  exists (
    select 1
    from public.orders
    where public.orders.id = order_id
      and (public.orders.agent_id = auth.uid() or public.is_manager_or_admin())
  )
);

drop policy if exists "authenticated_can_manage_order_items" on public.order_items;
create policy "authenticated_can_manage_order_items"
on public.order_items
for all
to authenticated
using (
  exists (
    select 1
    from public.orders
    where public.orders.id = order_id
      and (public.orders.agent_id = auth.uid() or public.is_manager_or_admin())
  )
)
with check (
  exists (
    select 1
    from public.orders
    where public.orders.id = order_id
      and (public.orders.agent_id = auth.uid() or public.is_manager_or_admin())
  )
);

drop policy if exists "authenticated_can_view_messages" on public.messages;
create policy "authenticated_can_view_messages"
on public.messages
for select
to authenticated
using (
  sender_id = auth.uid()
  or recipient_id = auth.uid()
  or public.is_manager_or_admin()
);

drop policy if exists "authenticated_can_send_messages" on public.messages;
create policy "authenticated_can_send_messages"
on public.messages
for insert
to authenticated
with check (
  sender_id = auth.uid()
  or public.is_manager_or_admin()
);

drop policy if exists "authenticated_can_update_messages" on public.messages;
create policy "authenticated_can_update_messages"
on public.messages
for update
to authenticated
using (
  sender_id = auth.uid()
  or recipient_id = auth.uid()
  or public.is_manager_or_admin()
)
with check (
  sender_id = auth.uid()
  or recipient_id = auth.uid()
  or public.is_manager_or_admin()
);

drop policy if exists "authenticated_can_delete_messages" on public.messages;
create policy "authenticated_can_delete_messages"
on public.messages
for delete
to authenticated
using (
  sender_id = auth.uid()
  or recipient_id = auth.uid()
  or public.is_manager_or_admin()
);

drop policy if exists "agents_can_manage_school_visits" on public.school_visits;
create policy "agents_can_manage_school_visits"
on public.school_visits
for all
to authenticated
using (agent_id = auth.uid() or public.is_manager_or_admin())
with check (agent_id = auth.uid() or public.is_manager_or_admin());

drop policy if exists "agents_can_manage_school_follow_ups" on public.school_follow_ups;
create policy "agents_can_manage_school_follow_ups"
on public.school_follow_ups
for all
to authenticated
using (agent_id = auth.uid() or public.is_manager_or_admin())
with check (agent_id = auth.uid() or public.is_manager_or_admin());

drop policy if exists "authenticated_can_manage_debt_collections" on public.debt_collections;
create policy "authenticated_can_manage_debt_collections"
on public.debt_collections
for all
to authenticated
using (collected_by = auth.uid() or public.is_manager_or_admin())
with check (collected_by = auth.uid() or public.is_manager_or_admin());

drop policy if exists "agents_can_manage_school_sales" on public.school_sales;
create policy "agents_can_manage_school_sales"
on public.school_sales
for all
to authenticated
using (agent_id = auth.uid() or public.is_manager_or_admin())
with check (agent_id = auth.uid() or public.is_manager_or_admin());

drop policy if exists "authenticated_can_view_opportunity_activities" on public.opportunity_activities;
create policy "authenticated_can_view_opportunity_activities"
on public.opportunity_activities
for select
to authenticated
using (
  actor_id = auth.uid()
  or exists (
    select 1
    from public.school_sales s
    where s.id = opportunity_id
      and (s.agent_id = auth.uid() or public.current_user_role_id() <= 3)
  )
);

drop policy if exists "authenticated_can_manage_opportunity_activities" on public.opportunity_activities;
create policy "authenticated_can_manage_opportunity_activities"
on public.opportunity_activities
for all
to authenticated
using (
  actor_id = auth.uid()
  or public.current_user_role_id() <= 3
)
with check (
  actor_id = auth.uid()
  or public.current_user_role_id() <= 3
);

drop policy if exists "authenticated_can_view_pipeline_history" on public.pipeline_history;
create policy "authenticated_can_view_pipeline_history"
on public.pipeline_history
for select
to authenticated
using (
  exists (
    select 1
    from public.school_sales s
    where s.id = pipeline_id
      and (s.agent_id = auth.uid() or public.is_manager_or_admin())
  )
);

drop policy if exists "agents_can_manage_school_sample_distributions" on public.school_sample_distributions;
create policy "agents_can_manage_school_sample_distributions"
on public.school_sample_distributions
for all
to authenticated
using (agent_id = auth.uid() or public.is_manager_or_admin())
with check (agent_id = auth.uid() or public.is_manager_or_admin());

-- END FILE: supabase/schema.sql

-- =========================================================
-- BEGIN FILE: supabase/schema_updates.sql
-- =========================================================
-- Updates for newly added Dashboard, Analytics, Geofencing, and Assignment features

-- 0. Update Tasks Table for Individual Assignment and Time Filtering
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS assigned_to UUID REFERENCES public.users(id) ON DELETE SET NULL;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS due_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS target_role INTEGER NOT NULL DEFAULT 2;

-- 0b. Schools table updates for onboarding tracking + external discovery
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'manual';
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS external_place_id TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS external_vicinity TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS contact_name TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS contact_phone TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS contact_title TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS feedback TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS samples_left TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS sample_book TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS school_ownership TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS school_ownership_other TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS school_population INTEGER;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS school_lifecycle_status TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS engagement_type TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS dealer_type TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS shop_category TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS selected_product TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS partner_subtype TEXT;
ALTER TABLE public.school_sample_distributions ADD COLUMN IF NOT EXISTS stamped_receipt_url TEXT;
ALTER TABLE public.school_sample_distributions ADD COLUMN IF NOT EXISTS stamped_receipt_path TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_schools_external_place_id
ON public.schools (external_place_id)
WHERE external_place_id IS NOT NULL;

DO $$ BEGIN
    ALTER TABLE public.schools
    DROP CONSTRAINT IF EXISTS schools_source_check;
    ALTER TABLE public.schools
    ADD CONSTRAINT schools_source_check CHECK (source IN ('manual', 'google'));
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- 1. Route Plans Table
CREATE TABLE IF NOT EXISTS public.route_plans (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL DEFAULT 'Route Plan',
    route_date DATE NOT NULL DEFAULT CURRENT_DATE,
    assigned_to UUID REFERENCES public.users(id) ON DELETE CASCADE,
    school_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'assigned',
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    "isSynced" BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Geofences Table
CREATE TABLE IF NOT EXISTS public.geofences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    coordinates JSONB NOT NULL DEFAULT '[]'::jsonb,
    assigned_to UUID REFERENCES public.users(id) ON DELETE CASCADE,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. School Sample Distributions Table
CREATE TABLE IF NOT EXISTS public.school_sample_distributions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    agent_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    sample_name TEXT NOT NULL,
    sample_category TEXT,
    quantity INTEGER NOT NULL DEFAULT 1,
    notes TEXT,
    distributed_at TIMESTAMP WITH TIME ZONE,
    "isSynced" BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3b. Debt Collections Table
CREATE TABLE IF NOT EXISTS public.debt_collections (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    collected_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    payment_method TEXT NOT NULL DEFAULT 'cash',
    payment_reference TEXT,
    notes TEXT,
    collected_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Catalog Items Table
CREATE TABLE IF NOT EXISTS public.catalog_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT,
    sku TEXT UNIQUE,
    item_type TEXT NOT NULL DEFAULT 'sale',
    unit_price NUMERIC(12,2) NOT NULL DEFAULT 0,
    stock_qty INTEGER NOT NULL DEFAULT 0,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    "isSynced" BOOLEAN NOT NULL DEFAULT false,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Orders Table (For Revenue Analytics)
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID REFERENCES public.schools(id) ON DELETE SET NULL,
    school_name TEXT NOT NULL,
    school_phone TEXT,
    agent_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    order_number TEXT UNIQUE,
    payment_method TEXT NOT NULL DEFAULT 'cash',
    payment_reference TEXT,
    checkout_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending',
    notes TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE,
    approved_at TIMESTAMP WITH TIME ZONE,
    "isSynced" BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. School Sales Pipeline migrations
-- Source of truth schema lives in schema.sql; keep only ALTER/DO migrations here.

DO $$ BEGIN
    ALTER TABLE public.school_sales
        ADD COLUMN IF NOT EXISTS stage_contact_person TEXT,
        ADD COLUMN IF NOT EXISTS sample_quantity INTEGER,
        ADD COLUMN IF NOT EXISTS quotation_reference TEXT,
        ADD COLUMN IF NOT EXISTS decision_owner TEXT,
        ADD COLUMN IF NOT EXISTS negotiation_topic TEXT,
        ADD COLUMN IF NOT EXISTS loss_reason TEXT,
        ADD COLUMN IF NOT EXISTS dormant_reason TEXT,
        ADD COLUMN IF NOT EXISTS stage_updated_at TIMESTAMP WITH TIME ZONE,
        ADD COLUMN IF NOT EXISTS expected_close_date DATE,
        ADD COLUMN IF NOT EXISTS probability INTEGER NOT NULL DEFAULT 0;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.pipeline_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    pipeline_id UUID NOT NULL REFERENCES public.school_sales(id) ON DELETE CASCADE,
    old_stage TEXT,
    new_stage TEXT NOT NULL,
    changed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    changed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_pipeline_history_pipeline_id
ON public.pipeline_history (pipeline_id);

CREATE INDEX IF NOT EXISTS idx_pipeline_history_changed_at
ON public.pipeline_history (changed_at DESC);

CREATE OR REPLACE FUNCTION public.log_pipeline_stage_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.pipeline_history (pipeline_id, old_stage, new_stage, changed_by, notes)
        VALUES (NEW.id, NULL, NEW.sale_status, auth.uid(), NEW.notes);
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND coalesce(NEW.sale_status, '') <> coalesce(OLD.sale_status, '') THEN
        INSERT INTO public.pipeline_history (pipeline_id, old_stage, new_stage, changed_by, notes)
        VALUES (NEW.id, OLD.sale_status, NEW.sale_status, auth.uid(), NEW.notes);
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_school_sales_stage_change ON public.school_sales;
CREATE TRIGGER log_school_sales_stage_change
AFTER INSERT OR UPDATE ON public.school_sales
FOR EACH ROW EXECUTE PROCEDURE public.log_pipeline_stage_change();

DO $$ BEGIN
    UPDATE public.school_sales
    SET sale_status = 'lead'
    WHERE sale_status IN ('draft', 'pipeline') OR sale_status IS NULL;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE public.school_sales
    ALTER COLUMN sale_status SET DEFAULT 'lead';
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE public.school_sales
    DROP CONSTRAINT IF EXISTS school_sales_sale_status_check;
    ALTER TABLE public.school_sales
    DROP CONSTRAINT IF EXISTS school_sales_sample_quantity_check;
    ALTER TABLE public.school_sales
    ADD CONSTRAINT school_sales_sale_status_check CHECK (
        sale_status IN (
            'lead',
            'contacted',
            'meeting_scheduled',
            'sample_issued',
            'quotation_sent',
            'decision_pending',
            'negotiation',
            'won',
            'lost',
            'dormant'
        )
    );
    ALTER TABLE public.school_sales
    ADD CONSTRAINT school_sales_sample_quantity_check CHECK (
        sample_quantity IS NULL OR sample_quantity >= 0
    );
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- Enable Row Level Security (RLS) on all new tables
ALTER TABLE public.route_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.geofences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_sample_distributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalog_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pipeline_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.debt_collections ENABLE ROW LEVEL SECURITY;

-- Optional: Re-create missing permissive policies if needed
-- (Your schema.sql handles granular RLS policies already, these act as fallbacks if missing)
DO $$ BEGIN
    CREATE POLICY "Allow authenticated full access on route_plans" ON public.route_plans FOR ALL TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "authenticated_can_view_pipeline_history"
    ON public.pipeline_history
    FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1
        FROM public.school_sales s
        WHERE s.id = pipeline_id
          AND (s.agent_id = auth.uid() OR public.is_manager_or_admin())
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "authenticated_can_delete_messages"
    ON public.messages
    FOR DELETE
    TO authenticated
    USING (
      sender_id = auth.uid()
      OR recipient_id = auth.uid()
      OR public.is_manager_or_admin()
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "authenticated_can_manage_debt_collections"
    ON public.debt_collections
    FOR ALL
    TO authenticated
    USING (collected_by = auth.uid() OR public.is_manager_or_admin())
    WITH CHECK (collected_by = auth.uid() OR public.is_manager_or_admin());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Social inbox sync tables for Facebook + WhatsApp bot
CREATE TABLE IF NOT EXISTS public.social_conversations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    channel text NOT NULL CHECK (channel IN ('facebook', 'whatsapp')),
    external_conversation_id text NOT NULL,
    participant_display text,
    participant_phone text,
    last_message_preview text,
    last_message_at timestamptz,
    raw_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    UNIQUE (channel, external_conversation_id)
);

CREATE TABLE IF NOT EXISTS public.social_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id uuid NOT NULL REFERENCES public.social_conversations(id) ON DELETE CASCADE,
    channel text NOT NULL CHECK (channel IN ('facebook', 'whatsapp')),
    external_message_id text NOT NULL,
    sender_name text,
    sender_id text,
    body text,
    sent_at timestamptz,
    raw_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    UNIQUE (channel, external_message_id)
);

ALTER TABLE public.social_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_messages ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "authenticated_can_view_social_conversations"
    ON public.social_conversations
    FOR SELECT
    TO authenticated
    USING (public.is_manager_or_admin());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "service_role_can_manage_social_conversations"
    ON public.social_conversations
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "authenticated_can_view_social_messages"
    ON public.social_messages
    FOR SELECT
    TO authenticated
    USING (public.is_manager_or_admin());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "service_role_can_manage_social_messages"
    ON public.social_messages
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Stamped sample proof fields on schools
ALTER TABLE public.schools
ADD COLUMN IF NOT EXISTS sample_proof_url TEXT;

ALTER TABLE public.schools
ADD COLUMN IF NOT EXISTS sample_proof_path TEXT;

-- ROI support for sample distribution (Role 5 and admin analytics)
CREATE INDEX IF NOT EXISTS idx_sample_distributions_agent_school
ON public.school_sample_distributions (agent_id, school_id, distributed_at DESC);

CREATE INDEX IF NOT EXISTS idx_orders_agent_status
ON public.orders (agent_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_school_sales_agent_stage
ON public.school_sales (agent_id, sale_status, created_at DESC);

CREATE OR REPLACE VIEW public.v_agent_sample_roi AS
WITH sample_stats AS (
  SELECT
    d.agent_id,
    COALESCE(SUM(d.quantity), 0)::int AS samples_given,
    COUNT(DISTINCT d.school_id)::int AS schools_reached
  FROM public.school_sample_distributions d
  WHERE d.agent_id IS NOT NULL
  GROUP BY d.agent_id
),
revenue_stats AS (
  SELECT
    o.agent_id,
    COALESCE(
      SUM(
        CASE
          WHEN LOWER(COALESCE(o.status, '')) IN ('approved', 'paid')
          THEN COALESCE(o.checkout_amount, 0)
          ELSE 0
        END
      ),
      0
    )::numeric(12,2) AS revenue_earned
  FROM public.orders o
  WHERE o.agent_id IS NOT NULL
  GROUP BY o.agent_id
),
won_stats AS (
  SELECT
    s.agent_id,
    COALESCE(
      SUM(
        CASE
          WHEN LOWER(COALESCE(s.sale_status, '')) = 'won'
          THEN COALESCE(s.expected_value, 0)
          ELSE 0
        END
      ),
      0
    )::numeric(12,2) AS won_value
  FROM public.school_sales s
  WHERE s.agent_id IS NOT NULL
  GROUP BY s.agent_id
)
SELECT
  u.id AS agent_id,
  COALESCE(u.full_name, u.email, 'Unknown User') AS agent_name,
  COALESCE(ss.samples_given, 0) AS samples_given,
  COALESCE(ss.schools_reached, 0) AS schools_reached,
  COALESCE(rs.revenue_earned, 0)::numeric(12,2) AS revenue_earned,
  COALESCE(ws.won_value, 0)::numeric(12,2) AS won_value
FROM public.users u
LEFT JOIN sample_stats ss ON ss.agent_id = u.id
LEFT JOIN revenue_stats rs ON rs.agent_id = u.id
LEFT JOIN won_stats ws ON ws.agent_id = u.id
WHERE u.role IN (4, 5);

-- END FILE: supabase/schema_updates.sql

-- =========================================================
-- BEGIN FILE: supabase/schema_updates_project_forms.sql
-- =========================================================
-- Project forms persistence for Admin publish -> Role 5 quick actions

create table if not exists public.project_forms (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  questions jsonb not null default '[]'::jsonb,
  assigned_user_ids uuid[] not null default '{}',
  published_at timestamptz not null default now(),
  created_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'project_forms'
      and column_name = 'assigned_user_ids'
  ) then
    alter table public.project_forms
      add column assigned_user_ids uuid[] not null default '{}';
  end if;
end $$;

create index if not exists idx_project_forms_published_at
  on public.project_forms (published_at desc);

alter table public.project_forms enable row level security;

drop policy if exists "authenticated_can_view_project_forms" on public.project_forms;
create policy "authenticated_can_view_project_forms"
on public.project_forms
for select
to authenticated
using (
  public.is_manager_or_admin()
  or auth.uid() = any (assigned_user_ids)
);

drop policy if exists "managers_can_publish_project_forms" on public.project_forms;
create policy "managers_can_publish_project_forms"
on public.project_forms
for insert
to authenticated
with check (public.is_manager_or_admin());

create table if not exists public.project_form_responses (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references public.project_forms (id) on delete cascade,
  form_title text not null,
  respondent_id uuid not null references public.users (id) on delete cascade,
  answers jsonb not null default '{}'::jsonb,
  submitted_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_project_form_responses_form_title
  on public.project_form_responses (form_title);

create index if not exists idx_project_form_responses_submitted_at
  on public.project_form_responses (submitted_at desc);

alter table public.project_form_responses enable row level security;

drop policy if exists "assigned_users_can_submit_project_form_responses" on public.project_form_responses;
create policy "assigned_users_can_submit_project_form_responses"
on public.project_form_responses
for insert
to authenticated
with check (
  exists (
    select 1
    from public.project_forms f
    where f.id = project_form_responses.form_id
      and auth.uid() = any (f.assigned_user_ids)
  )
  and respondent_id = auth.uid()
);

drop policy if exists "managers_can_view_project_form_responses" on public.project_form_responses;
create policy "managers_can_view_project_form_responses"
on public.project_form_responses
for select
to authenticated
using (public.is_manager_or_admin());

-- Dummy data for testing (safe to re-run)
-- Assumes seeded users exist:
-- admin:   11111111-1111-1111-1111-111111111111
-- role 5:  bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb

insert into public.project_forms (
  id,
  title,
  description,
  questions,
  assigned_user_ids,
  published_at,
  created_by
)
values
  (
    'a1a1a1a1-1111-4444-8888-111111111111',
    'Term 2 School Readiness Check',
    'Collect readiness data from assigned schools before term opening.',
    '[
      {"title":"School Name","type":"shortAnswer","required":true,"options":[]},
      {"title":"Visit Date","type":"datePicker","required":true,"options":[]},
      {"title":"Head Teacher Contact","type":"phoneNumberInput","required":true,"options":[]},
      {"title":"Books Received?","type":"toggleSwitch","required":true,"options":[]},
      {"title":"Readiness Rating","type":"linearScale","required":true,"options":["1","2","3","4","5","6","7","8","9","10"]}
    ]'::jsonb,
    array['bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid],
    now() - interval '2 days',
    '11111111-1111-1111-1111-111111111111'::uuid
  ),
  (
    'a2a2a2a2-2222-4444-8888-222222222222',
    'Weekly Route Feedback Form',
    'Capture route-level observations and blockers.',
    '[
      {"title":"Route Name","type":"shortAnswer","required":true,"options":[]},
      {"title":"Arrival Time","type":"timePicker","required":true,"options":[]},
      {"title":"Main Challenge","type":"paragraph","required":true,"options":[]},
      {"title":"Evidence Upload","type":"fileUpload","required":false,"options":[]},
      {"title":"Overall Experience","type":"ratingScale","required":true,"options":["1","2","3","4","5"]}
    ]'::jsonb,
    array['bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid],
    now() - interval '1 day',
    '11111111-1111-1111-1111-111111111111'::uuid
  )
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  questions = excluded.questions,
  assigned_user_ids = excluded.assigned_user_ids,
  published_at = excluded.published_at,
  created_by = excluded.created_by;

insert into public.project_form_responses (
  id,
  form_id,
  form_title,
  respondent_id,
  answers,
  submitted_at
)
values
  (
    'b1b1b1b1-1111-4444-9999-111111111111',
    'a1a1a1a1-1111-4444-8888-111111111111'::uuid,
    'Term 2 School Readiness Check',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid,
    '{
      "School Name":"Nairobi Primary",
      "Visit Date":"2026-05-20",
      "Head Teacher Contact":"+254700123456",
      "Books Received?":"Yes",
      "Readiness Rating":"8"
    }'::jsonb,
    now() - interval '20 hours'
  ),
  (
    'b2b2b2b2-2222-4444-9999-222222222222',
    'a2a2a2a2-2222-4444-8888-222222222222'::uuid,
    'Weekly Route Feedback Form',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid,
    '{
      "Route Name":"Kisumu West Cluster",
      "Arrival Time":"09:10",
      "Main Challenge":"Delayed handover at first school.",
      "Evidence Upload":"route-photo-2026-05-21.jpg",
      "Overall Experience":"4"
    }'::jsonb,
    now() - interval '10 hours'
  )
on conflict (id) do update set
  form_id = excluded.form_id,
  form_title = excluded.form_title,
  respondent_id = excluded.respondent_id,
  answers = excluded.answers,
  submitted_at = excluded.submitted_at;

-- END FILE: supabase/schema_updates_project_forms.sql

-- =========================================================
-- BEGIN FILE: supabase/schema_updates_sample_proof.sql
-- =========================================================
-- Add stamped sample proof fields on schools
begin;

alter table public.schools
  add column if not exists sample_proof_url text;

alter table public.schools
  add column if not exists sample_proof_path text;

commit;

-- END FILE: supabase/schema_updates_sample_proof.sql

-- =========================================================
-- BEGIN FILE: supabase/schema_updates_tasks_pipeline.sql
-- =========================================================
-- Task + pipeline SQL updates for dashboard filtering and consistency

begin;

-- 1) Normalize task statuses before adding constraint
update public.tasks
set status = 'closed'
where lower(status) in ('complete', 'completed', 'done');

update public.tasks
set status = 'in_progress'
where lower(status) in ('in progress', 'progress');

update public.tasks
set status = 'open'
where lower(status) not in ('open', 'in_progress', 'closed');

-- 2) Enforce allowed task statuses
alter table public.tasks
  drop constraint if exists tasks_status_check;

alter table public.tasks
  add constraint tasks_status_check
  check (status in ('open', 'in_progress', 'closed'));

-- 3) Helpful indexes for admin dashboard filters
create index if not exists idx_tasks_status_due_at
  on public.tasks (status, due_at);

create index if not exists idx_tasks_target_role_status
  on public.tasks (target_role, status);

create index if not exists idx_school_sales_stage_updated_at
  on public.school_sales (sale_status, stage_updated_at desc);

commit;

-- END FILE: supabase/schema_updates_tasks_pipeline.sql

-- =========================================================
-- BEGIN FILE: supabase/storage_policies_sample_receipts.sql
-- =========================================================
-- Enable storage for stamped sample receipt photos
-- Run in Supabase SQL editor as a project admin.

begin;

-- 1) Ensure bucket exists (public for easy admin viewing via public URL)
insert into storage.buckets (id, name, public)
values ('schools', 'schools', true)
on conflict (id) do update set public = true;

-- Optional dedicated bucket (if you later switch app upload target)
insert into storage.buckets (id, name, public)
values ('sample-receipts', 'sample-receipts', true)
on conflict (id) do update set public = true;

-- 2) Policies for 'schools' bucket
drop policy if exists "authenticated_can_view_schools_bucket" on storage.objects;
create policy "authenticated_can_view_schools_bucket"
on storage.objects
for select
to authenticated
using (bucket_id = 'schools');

drop policy if exists "authenticated_can_upload_schools_bucket" on storage.objects;
create policy "authenticated_can_upload_schools_bucket"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'schools');

drop policy if exists "authenticated_can_update_schools_bucket" on storage.objects;
create policy "authenticated_can_update_schools_bucket"
on storage.objects
for update
to authenticated
using (bucket_id = 'schools')
with check (bucket_id = 'schools');

-- 3) Policies for dedicated 'sample-receipts' bucket
drop policy if exists "authenticated_can_view_sample_receipts_bucket" on storage.objects;
create policy "authenticated_can_view_sample_receipts_bucket"
on storage.objects
for select
to authenticated
using (bucket_id = 'sample-receipts');

drop policy if exists "authenticated_can_upload_sample_receipts_bucket" on storage.objects;
create policy "authenticated_can_upload_sample_receipts_bucket"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'sample-receipts');

drop policy if exists "authenticated_can_update_sample_receipts_bucket" on storage.objects;
create policy "authenticated_can_update_sample_receipts_bucket"
on storage.objects
for update
to authenticated
using (bucket_id = 'sample-receipts')
with check (bucket_id = 'sample-receipts');

commit;

-- END FILE: supabase/storage_policies_sample_receipts.sql

-- =================================================================
-- BEGIN FILE: supabase/schema_updates_phase3.sql
-- =================================================================
-- Create table for supervisor coaching notes
CREATE TABLE IF NOT EXISTS public.supervisor_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supervisor_id UUID NOT NULL REFERENCES public.users(id),
    user_id UUID NOT NULL REFERENCES public.users(id),
    region TEXT,
    context_type TEXT, -- e.g., 'task', 'route', 'general'
    context_id UUID,
    note TEXT NOT NULL,
    follow_up_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on supervisor_notes
ALTER TABLE public.supervisor_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "supervisors_can_manage_notes" ON public.supervisor_notes;
CREATE POLICY "supervisors_can_manage_notes"
ON public.supervisor_notes
FOR ALL
TO authenticated
USING (supervisor_id = auth.uid() OR public.is_manager_or_admin())
WITH CHECK (supervisor_id = auth.uid() OR public.is_manager_or_admin());

-- Create a view for Role 5 Performance Scorecard
-- (This aggregates data to make the UI queries faster and simpler)
CREATE OR REPLACE VIEW public.role5_performance_scorecard AS
SELECT 
    u.id AS user_id,
    u.full_name,
    u.region,
    COUNT(DISTINCT t.id) AS total_tasks,
    COUNT(DISTINCT CASE WHEN t.status = 'closed' THEN t.id END) AS completed_tasks,
    COUNT(DISTINCT r.id) AS total_routes,
    COUNT(DISTINCT CASE WHEN r.status = 'completed' THEN r.id END) AS completed_routes,
    COUNT(DISTINCT sv.id) AS total_visits
FROM public.users u
LEFT JOIN public.tasks t ON t.assigned_to = u.id AND t.created_at >= NOW() - INTERVAL '30 days'
LEFT JOIN public.route_plans r ON r.assigned_to = u.id AND r.created_at >= NOW() - INTERVAL '30 days'
LEFT JOIN public.school_visits sv ON sv.agent_id = u.id AND sv.visited_at >= NOW() - INTERVAL '30 days'
WHERE u.role = 5
GROUP BY u.id, u.full_name, u.region;

-- END FILE: supabase/schema_updates_phase3.sql

-- =================================================================
-- BEGIN FILE: supabase/schema_updates_dedup.sql
-- =================================================================
-- Create a function to find potential duplicates across the entire schools table
create or replace function public.get_potential_duplicates()
returns table (
  id uuid,
  name text,
  phone text,
  duplicate_id uuid,
  duplicate_name text,
  reason text
)
language plpgsql
security definer
as $$
begin
  return query
  select 
    s1.id, 
    s1.name, 
    s1.phone, 
    s2.id as duplicate_id, 
    s2.name as duplicate_name,
    case 
      when s1.phone = s2.phone then 'Matching Phone Number'
      when lower(s1.name) = lower(s2.name) then 'Matching Name'
      else 'High Similarity'
    end as reason
  from public.schools s1
  join public.schools s2 on s1.id < s2.id
  where s1.phone = s2.phone 
     or lower(s1.name) = lower(s2.name);
end;
$$;

-- END FILE: supabase/schema_updates_dedup.sql

-- =================================================================
-- BEGIN FILE: supabase/schema_updates_lead_scoring.sql
-- =================================================================
-- Add lead_score column to schools
do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'lead_score') then
    alter table public.schools add column lead_score integer not null default 0;
  end if;
end $$;

-- Create lead scoring function
create or replace function public.calculate_lead_score()
returns trigger
language plpgsql
security definer
as $$
declare
  v_score integer := 0;
  v_pop integer := coalesce(new.school_population, 0);
  v_cat text := lower(coalesce(new.book_category, ''));
  v_focus_count integer := 0;
begin
  -- Population scoring
  if v_pop > 1000 then
    v_score := v_score + 40;
  elsif v_pop >= 500 then
    v_score := v_score + 20;
  elsif v_pop > 0 then
    v_score := v_score + 10;
  end if;

  -- Category scoring
  if v_cat like '%book fund%' then
    v_score := v_score + 30;
  end if;

  -- Focus Areas scoring
  if new."focusAreas" is not null then
    v_focus_count := jsonb_array_length(new."focusAreas");
    v_score := v_score + least(v_focus_count * 10, 30);
  end if;

  new.lead_score := v_score;
  return new;
end;
$$;

-- Create trigger
drop trigger if exists update_lead_score_trigger on public.schools;
create trigger update_lead_score_trigger
before insert or update on public.schools
for each row execute procedure public.calculate_lead_score();

-- Backfill existing schools
update public.schools set updated_at = now();

-- END FILE: supabase/schema_updates_lead_scoring.sql

-- =================================================================
-- BEGIN FILE: supabase/schema_updates_onboarding_region.sql
-- =================================================================
-- Migration: role 1 region dashboard additions + role 5 onboarding field updates
-- Date: 2026-07-09

-- =============================================================================
-- 1. ROLE 5 ONBOARDING: Migrate existing Distributor records to Institution
-- =============================================================================
UPDATE public.schools
SET dealer_type = 'Institution'
WHERE lower(dealer_type) = 'distributor';

UPDATE public.schools
SET shop_category = 'Distributor'
WHERE lower(shop_category) = 'independent';

-- =============================================================================
-- 2. ROLE 5 ONBOARDING: Add new columns for expanded onboarding fields
-- =============================================================================
-- samples_to_be_returned: new Yes/No indicator for sample returns
ALTER TABLE public.schools
  ADD COLUMN IF NOT EXISTS samples_to_be_returned text;

-- learning_materials: multi-select stock for Bookshop / Institution (Course Books, ECD Books, Reference, Teacher Guides)
ALTER TABLE public.schools
  ADD COLUMN IF NOT EXISTS learning_materials jsonb DEFAULT '[]'::jsonb;

-- institution_category_other: free-text subcategory when partner_subtype = 'Others' for Institutions
ALTER TABLE public.schools
  ADD COLUMN IF NOT EXISTS institution_category_other text;

-- book_programs: expanded multi-select for School Book Program (Book List, Book Fund)
ALTER TABLE public.schools
  ADD COLUMN IF NOT EXISTS book_programs jsonb DEFAULT '[]'::jsonb;

-- =============================================================================
-- 3. ROLE 1 REGION SECTION: Index optimization for regional aggregation queries
-- =============================================================================
-- The new admin Regions page aggregates sales, visits, and schools by region.
-- It derives region from users.region or schools.county. Add composite indexes
-- to keep those queries fast as data grows.
CREATE INDEX IF NOT EXISTS idx_schools_county_captured_at
  ON public.schools (county, captured_at);

CREATE INDEX IF NOT EXISTS idx_school_visits_school_visited_at
  ON public.school_visits (school_id, visited_at);

CREATE INDEX IF NOT EXISTS idx_school_sales_school_created
  ON public.school_sales (school_id, created_at);

-- =============================================================================
-- 5. REGIONS TABLE: structured region/sub-region/county master data
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.regions (
  id uuid primary key default gen_random_uuid(),
  region text not null,
  sub_region text not null,
  counties text,
  assigned_to uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'regions' AND column_name = 'assigned_to') THEN
    ALTER TABLE public.regions ADD COLUMN assigned_to uuid references public.users (id) on delete set null;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'regions' AND column_name = 'counties') THEN
    ALTER TABLE public.regions ADD COLUMN counties text;
  END IF;
END $$;

DROP TRIGGER IF EXISTS touch_regions_updated_at ON public.regions;
CREATE TRIGGER touch_regions_updated_at
BEFORE UPDATE ON public.regions
FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

ALTER TABLE public.regions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "managers_can_manage_regions" ON public.regions;
CREATE POLICY "managers_can_manage_regions"
ON public.regions
FOR ALL
TO authenticated
USING (public.current_user_role_id() <= 2)
WITH CHECK (public.current_user_role_id() <= 2);

DROP POLICY IF EXISTS "authenticated_can_view_regions" ON public.regions;
CREATE POLICY "authenticated_can_view_regions"
ON public.regions
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "agents_can_view_assigned_region" ON public.regions;
CREATE POLICY "agents_can_view_assigned_region"
ON public.regions
FOR SELECT
TO authenticated
USING (
  assigned_to = auth.uid()
  OR public.current_user_role_id() <= 2
);

CREATE INDEX IF NOT EXISTS idx_regions_region_sub_region
  ON public.regions (region, sub_region);

CREATE INDEX IF NOT EXISTS idx_regions_assigned_to
  ON public.regions (assigned_to);

DO $$
BEGIN
  IF to_regclass('public.users') IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'region_id') THEN
      ALTER TABLE public.users ADD COLUMN region_id uuid references public.regions (id) on delete set null;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'sub_region') THEN
      ALTER TABLE public.users ADD COLUMN sub_region text;
    END IF;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_users_region_id
  ON public.users (region_id);

INSERT INTO public.regions (region, sub_region, counties) VALUES
('Nairobi North', 'Nairobi North', 'Kasarani, Embakasi East, Embakasi West, Kiambu'),
('Nairobi North', 'Embakasi', 'Embakasi North, Embakasi South, Embakasi Central'),
('Nairobi North', 'Kiambu East', 'Gatundu North, Gatundu South, Juja, Thika Town, Ruiru'),
('Nairobi North', 'Kiambu West', 'Kiambaa, Kikuyu, Kabete, Limuru, Lari, Githunguri'),
('Nairobi North', 'Murang''a', 'Murang''a County'),
('Nairobi South', 'Nairobi South', 'Starehe, Westlands, Dagoretti North, Dagoretti South'),
('Nairobi South', 'Kajiado', 'Kajiado County'),
('Nairobi South', 'Machakos', 'Machakos County'),
('Nairobi South', 'Nairobi Central', 'Kamukunji, Makadara, Lang''ata'),
('Lake', 'South Western', 'Bungoma, Busia'),
('Lake', 'South Nyanza', 'Kisii, Nyamira, Migori'),
('Lake', 'North Nyanza', 'Siaya, Homa Bay, Kisumu'),
('Lake', 'North Western', 'Kakamega, Vihiga'),
('South Rift', 'South Rift', 'Narok, Nyandarua, Laikipia, Samburu'),
('South Rift', 'Central Rift', 'Nakuru, Baringo'),
('South Rift', 'South Rift', 'Bomet, Kericho'),
('North Rift', 'North Rift', 'Turkana, Uasin Gishu'),
('North Rift', 'North Rift', 'Trans Nzoia, West Pokot'),
('Coast', 'North Coast', 'Kilifi, Tana River, Lamu'),
('Coast', 'South Coast', 'Taita Taveta, Kwale, Mombasa'),
('Coast', 'Lower Eastern', 'Makueni, Kitui, Garissa'),
('Mt Kenya', 'Mt Kenya East', 'Meru, Isiolo, Marsabit, Wajir'),
('Mt Kenya', 'Mt Kenya West', 'Nyeri, Kirinyaga'),
('Mt Kenya', 'Mt Kenya South', 'Embu, Tharaka Nithi'),
('National', 'National', 'National')
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- 6. ROLE 5 ONBOARDING: Backfill / cleanup notes
-- =============================================================================
-- Reset free-text fields for fresh onboarding data shape
UPDATE public.schools
SET institution_category_other = NULL
WHERE dealer_type = 'Institution';

-- Ensure nullsafe for new columns on existing rows
UPDATE public.schools
SET samples_to_be_returned = NULL,
    learning_materials = '[]'::jsonb,
    book_programs = '[]'::jsonb
WHERE samples_to_be_returned IS NULL
   OR learning_materials IS NULL
   OR book_programs IS NULL;

-- END FILE: supabase/schema_updates_onboarding_region.sql

-- =================================================================
-- BEGIN FILE: supabase/schema_updates_region_assignments.sql
-- =================================================================
-- Migration: multi-region assignments + regions.supervisor_id
-- Date: 2026-07-28

-- =============================================================================
-- 1. REGIONS: add supervisor_id for legacy single-supervisor assignment
-- =============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'regions'
      AND column_name = 'supervisor_id'
  ) THEN
    ALTER TABLE public.regions
      ADD COLUMN supervisor_id uuid references public.users (id) on delete set null;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_regions_supervisor_id
  ON public.regions (supervisor_id);

-- =============================================================================
-- 2. REGION_ASSIGNMENTS: many-to-many region <-> user assignments
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.region_assignments (
  region_id uuid not null references public.regions (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  role integer not null,
  assigned_at timestamptz not null default now(),
  PRIMARY KEY (region_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_region_assignments_user_id
  ON public.region_assignments (user_id);

CREATE INDEX IF NOT EXISTS idx_region_assignments_region_role
  ON public.region_assignments (region_id, role);

ALTER TABLE public.region_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "managers_can_manage_region_assignments" ON public.region_assignments;
CREATE POLICY "managers_can_manage_region_assignments"
ON public.region_assignments
FOR ALL
TO authenticated
USING (public.current_user_role_id() <= 4)
WITH CHECK (public.current_user_role_id() <= 4);

DROP POLICY IF EXISTS "users_can_view_own_region_assignments" ON public.region_assignments;
CREATE POLICY "users_can_view_own_region_assignments"
ON public.region_assignments
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  OR public.current_user_role_id() <= 4
);

-- =============================================================================
-- 3. REGIONS RLS: allow supervisors/agents to view regions they are assigned to
-- =============================================================================
DROP POLICY IF EXISTS "agents_can_view_assigned_region" ON public.regions;
CREATE POLICY "agents_can_view_assigned_region"
ON public.regions
FOR SELECT
TO authenticated
USING (
  assigned_to = auth.uid()
  OR supervisor_id = auth.uid()
  OR EXISTS (
    SELECT 1
    FROM public.region_assignments ra
    WHERE ra.region_id = regions.id
      AND ra.user_id = auth.uid()
  )
  OR public.current_user_role_id() <= 2
);

-- END FILE: supabase/schema_updates_region_assignments.sql

-- =================================================================
-- BEGIN FILE: supabase/schema_updates_sample_trigger.sql
-- =================================================================
-- schema_updates_sample_trigger.sql
-- Placeholder migration file. Intentionally empty.
-- (Sample-distribution trigger logic lives in schema.sql / other migrations.)

-- END FILE: supabase/schema_updates_sample_trigger.sql

-- =================================================================
-- BEGIN FILE: supabase/schema_updates_targets.sql
-- =================================================================
-- Migration: targets configuration for role 2 managers
-- Date: 2026-07-28

-- =============================================================================
-- 1. TARGETS TABLE
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.targets (
  id uuid primary key default gen_random_uuid(),
  scope text not null check (scope in ('regional', 'agent', 'business_advisor', 'sales_rep')),
  region_id uuid references public.regions (id) on delete set null,
  sub_region text,
  assigned_to uuid references public.users (id) on delete set null,
  target_type text not null check (target_type in (
    'product_sales',
    'customer_visits',
    'collections',
    'new_customers',
    'sample_distribution',
    'consignment'
  )),
  target_period text not null check (target_period in ('daily', 'weekly', 'monthly', 'quarterly', 'yearly', 'ytd')),
  target_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

CREATE INDEX IF NOT EXISTS idx_targets_scope_type
  ON public.targets (scope, target_type);

CREATE INDEX IF NOT EXISTS idx_targets_assigned_to
  ON public.targets (assigned_to);

CREATE INDEX IF NOT EXISTS idx_targets_region_id
  ON public.targets (region_id);

ALTER TABLE public.targets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "managers_can_manage_targets" ON public.targets;
CREATE POLICY "managers_can_manage_targets"
ON public.targets
FOR ALL
TO authenticated
USING (public.current_user_role_id() <= 2)
WITH CHECK (public.current_user_role_id() <= 2);

DROP POLICY IF EXISTS "users_can_view_own_targets" ON public.targets;
CREATE POLICY "users_can_view_own_targets"
ON public.targets
FOR SELECT
TO authenticated
USING (
  assigned_to = auth.uid()
  OR public.current_user_role_id() <= 2
);

-- END FILE: supabase/schema_updates_targets.sql

-- =================================================================
-- BEGIN FILE: supabase/schema_updates_region_enhancements.sql
-- =================================================================
-- Migration: region_id on orders/school_sales + role_ref on users
-- Date: 2026-07-30

-- =============================================================================
-- 1. USERS: add role_ref for legacy assignment tracking
-- =============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND column_name = 'role_ref'
  ) THEN
    ALTER TABLE public.users ADD COLUMN role_ref text;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_users_role_ref
  ON public.users (role_ref);

-- =============================================================================
-- 2. ORDERS: add region_id for region-filtered order queries
-- =============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'orders'
      AND column_name = 'region_id'
  ) THEN
    ALTER TABLE public.orders
      ADD COLUMN region_id uuid references public.regions (id) on delete set null;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_orders_region_id
  ON public.orders (region_id);

-- =============================================================================
-- 3. SCHOOL_SALES: add region_id for region-filtered pipeline
-- =============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'school_sales'
      AND column_name = 'region_id'
  ) THEN
    ALTER TABLE public.school_sales
      ADD COLUMN region_id uuid references public.regions (id) on delete set null;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_school_sales_region_id
  ON public.school_sales (region_id);

-- =============================================================================
-- 4. RLS: allow managers to update role_ref on users
-- =============================================================================
DROP POLICY IF EXISTS "managers_can_update_users" ON public.users;
CREATE POLICY "managers_can_update_users"
ON public.users
FOR UPDATE
TO authenticated
USING (public.current_user_role_id() <= 2)
WITH CHECK (public.current_user_role_id() <= 2);

-- END FILE: supabase/schema_updates_region_enhancements.sql

-- =================================================================
-- BEGIN FILE: supabase/rpc_scorecard.sql
-- =================================================================
-- RPC to fetch dynamic Role 5 Performance Scorecard data based on a date range
CREATE OR REPLACE FUNCTION public.get_role5_performance(p_start_date TIMESTAMPTZ, p_end_date TIMESTAMPTZ)
RETURNS TABLE (
    user_id UUID,
    full_name TEXT,
    region TEXT,
    total_tasks BIGINT,
    completed_tasks BIGINT,
    total_routes BIGINT,
    completed_routes BIGINT,
    total_visits BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id AS user_id,
        u.full_name,
        u.region,
        COUNT(DISTINCT t.id) AS total_tasks,
        COUNT(DISTINCT CASE WHEN t.status = 'closed' THEN t.id END) AS completed_tasks,
        COUNT(DISTINCT r.id) AS total_routes,
        COUNT(DISTINCT CASE WHEN r.status = 'completed' THEN r.id END) AS completed_routes,
        COUNT(DISTINCT sv.id) AS total_visits
    FROM public.users u
    LEFT JOIN public.tasks t ON t.assigned_to = u.id AND t.created_at >= p_start_date AND t.created_at <= p_end_date
    LEFT JOIN public.route_plans r ON r.assigned_to = u.id AND r.created_at >= p_start_date AND r.created_at <= p_end_date
    LEFT JOIN public.school_visits sv ON sv.agent_id = u.id AND sv.visited_at >= p_start_date AND sv.visited_at <= p_end_date
    WHERE u.role = 5
    GROUP BY u.id, u.full_name, u.region;
END;
$$;
-- END FILE: supabase/rpc_scorecard.sql

-- =================================================================
-- BEGIN FILE: supabase/schema_updates_outreach_report.sql
-- =================================================================
-- Migration: outreach report missing fields
-- Date: 2026-07-30

-- =============================================================================
-- 1. SCHOOLS: add outreach report fields
-- =============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'schools'
      AND column_name = 'competitor_analysis'
  ) THEN
    ALTER TABLE public.schools ADD COLUMN competitor_analysis text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'schools'
      AND column_name = 'school_level'
  ) THEN
    ALTER TABLE public.schools ADD COLUMN school_level text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'schools'
      AND column_name = 'designation'
  ) THEN
    ALTER TABLE public.schools ADD COLUMN designation text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'schools'
      AND column_name = 'projected_quantity'
  ) THEN
    ALTER TABLE public.schools ADD COLUMN projected_quantity integer;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'schools'
      AND column_name = 'contact_email'
  ) THEN
    ALTER TABLE public.schools ADD COLUMN contact_email text;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_schools_contact_email
  ON public.schools (contact_email);

-- =============================================================================
-- 2. INDEXES for outreach filtering
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_schools_captured_by
  ON public.schools (captured_by);

CREATE INDEX IF NOT EXISTS idx_schools_competitor_analysis
  ON public.schools (competitor_analysis);

CREATE INDEX IF NOT EXISTS idx_schools_school_level
  ON public.schools (school_level);

CREATE INDEX IF NOT EXISTS idx_schools_designation
  ON public.schools (designation);

CREATE INDEX IF NOT EXISTS idx_schools_projected_quantity
  ON public.schools (projected_quantity);

-- END FILE: supabase/schema_updates_outreach_report.sql
