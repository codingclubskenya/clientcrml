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
  sub_region text,
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
  contact_email text,
  contact_title text,
  feedback text,
  notes text,
samples_left text,
   sample_books text,
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
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'contact_email') then
    alter table public.schools add column contact_email text;
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

create or replace function public.create_school_sale_checkout(
  order_payload jsonb,
  items_payload jsonb default '[]'::jsonb,
  sale_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
as $$
declare
  v_now timestamptz := now();
  v_order_id uuid := coalesce(nullif(order_payload->>'id', '')::uuid, gen_random_uuid());
  v_order_number text := coalesce(nullif(order_payload->>'order_number', ''), 'ORD-' || to_char(v_now, 'YYYYMMDDHH24MISSMS') || '-' || upper(substring(replace(gen_random_uuid()::text, '-', '') from 1 for 8)));
  v_sale_id uuid := coalesce(nullif(sale_payload->>'id', '')::uuid, gen_random_uuid());
  v_order public.orders%rowtype;
  v_sale public.school_sales%rowtype;
begin
  insert into public.orders (
    id,
    school_id,
    school_name,
    school_phone,
    agent_id,
    order_number,
    payment_method,
    payment_reference,
    checkout_amount,
    status,
    notes,
    submitted_at,
    approved_at,
    "isSynced",
    created_at,
    updated_at
  ) values (
    v_order_id,
    nullif(order_payload->>'school_id', '')::uuid,
    coalesce(nullif(order_payload->>'school_name', ''), 'School'),
    nullif(order_payload->>'school_phone', ''),
    nullif(order_payload->>'agent_id', '')::uuid,
    v_order_number,
    coalesce(nullif(order_payload->>'payment_method', ''), 'cash'),
    nullif(order_payload->>'payment_reference', ''),
    coalesce((order_payload->>'checkout_amount')::numeric, 0),
    coalesce(nullif(order_payload->>'status', ''), 'pending'),
    nullif(order_payload->>'notes', ''),
    coalesce((order_payload->>'submitted_at')::timestamptz, v_now),
    (order_payload->>'approved_at')::timestamptz,
    coalesce((order_payload->>'isSynced')::boolean, false),
    coalesce((order_payload->>'created_at')::timestamptz, v_now),
    coalesce((order_payload->>'updated_at')::timestamptz, v_now)
  )
  returning * into v_order;

  if items_payload is not null and jsonb_typeof(items_payload) = 'array' then
    insert into public.order_items (
      id,
      order_id,
      product_name,
      category,
      sku,
      quantity,
      unit_price,
      line_total,
      notes,
      "isSynced",
      created_at,
      updated_at
    )
    select
      coalesce(nullif(item->>'id', '')::uuid, gen_random_uuid()),
      v_order.id,
      coalesce(nullif(item->>'product_name', ''), 'Item'),
      nullif(item->>'category', ''),
      nullif(item->>'sku', ''),
      coalesce((item->>'quantity')::integer, 1),
      coalesce((item->>'unit_price')::numeric, 0),
      coalesce((item->>'line_total')::numeric, 0),
      nullif(item->>'notes', ''),
      coalesce((item->>'isSynced')::boolean, false),
      coalesce((item->>'created_at')::timestamptz, v_now),
      coalesce((item->>'updated_at')::timestamptz, v_now)
    from jsonb_array_elements(items_payload) as item;
  end if;

  insert into public.school_sales (
    id,
    school_id,
    agent_id,
    package_name,
    expected_value,
    notes,
    sale_status,
    stage_updated_at,
    expected_close_date,
    probability,
    closed_at,
    "isSynced",
    created_at,
    updated_at
  ) values (
    v_sale_id,
    coalesce(nullif(sale_payload->>'school_id', '')::uuid, v_order.school_id),
    nullif(sale_payload->>'agent_id', '')::uuid,
    coalesce(nullif(sale_payload->>'package_name', ''), 'School Package'),
    coalesce((sale_payload->>'expected_value')::numeric, v_order.checkout_amount),
    nullif(sale_payload->>'notes', ''),
    coalesce(nullif(sale_payload->>'sale_status', ''), 'won'),
    coalesce((sale_payload->>'stage_updated_at')::timestamptz, v_now),
    (sale_payload->>'expected_close_date')::date,
    coalesce((sale_payload->>'probability')::integer, 100),
    coalesce((sale_payload->>'closed_at')::timestamptz, v_now),
    coalesce((sale_payload->>'isSynced')::boolean, false),
    coalesce((sale_payload->>'created_at')::timestamptz, v_now),
    coalesce((sale_payload->>'updated_at')::timestamptz, v_now)
  )
  on conflict (id) do update set
    school_id = excluded.school_id,
    agent_id = excluded.agent_id,
    package_name = excluded.package_name,
    expected_value = excluded.expected_value,
    notes = excluded.notes,
    sale_status = excluded.sale_status,
    stage_updated_at = excluded.stage_updated_at,
    expected_close_date = excluded.expected_close_date,
    probability = excluded.probability,
    closed_at = excluded.closed_at,
    "isSynced" = excluded."isSynced",
    updated_at = excluded.updated_at
  returning * into v_sale;

  return jsonb_build_object(
    'order', to_jsonb(v_order),
    'sale', to_jsonb(v_sale)
  );
end;
$$;

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
  client_type text,
  quantity integer not null default 1,
  returned_qty integer not null default 0,
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
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sample_distributions' and column_name = 'client_type') then
    alter table public.school_sample_distributions add column client_type text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sample_distributions' and column_name = 'returned_qty') then
    alter table public.school_sample_distributions add column returned_qty integer not null default 0;
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
  or assigned_to is null
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
    public.current_user_role_id() <= 4
    and assigned_to is null
  )
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
    public.current_user_role_id() <= 4
    and assigned_to is null
  )
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

create table if not exists public.sample_requests (
  id uuid primary key default gen_random_uuid(),
  request_code text not null unique,
  school_id uuid references public.schools (id) on delete cascade,
  client_type text,
  requested_by uuid references public.users (id) on delete set null,
  purpose text,
  notes text,
  status text not null default 'PENDING',
  rejection_reason text,
  needed_by timestamptz,
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.users (id) on delete set null,
  items jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists touch_sample_requests_updated_at on public.sample_requests;
create trigger touch_sample_requests_updated_at
before update on public.sample_requests
for each row execute procedure public.set_updated_at();

alter table public.sample_requests enable row level security;

drop policy if exists "users_can_manage_sample_requests" on public.sample_requests;
create policy "users_can_manage_sample_requests"
on public.sample_requests
for all
to authenticated
using (requested_by = auth.uid() or public.is_manager_or_admin())
with check (requested_by = auth.uid() or public.is_manager_or_admin());

create table if not exists public.regions (
  id uuid primary key default gen_random_uuid(),
  region text not null,
  sub_region text not null,
  counties text,
  assigned_to uuid references public.users (id) on delete set null,
  supervisor_id uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'regions' and column_name = 'assigned_to') then
    alter table public.regions add column assigned_to uuid references public.users (id) on delete set null;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'regions' and column_name = 'counties') then
    alter table public.regions add column counties text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'regions' and column_name = 'supervisor_id') then
    alter table public.regions add column supervisor_id uuid references public.users (id) on delete set null;
  end if;
end $$;

drop trigger if exists touch_regions_updated_at on public.regions;
create trigger touch_regions_updated_at
before update on public.regions
for each row execute procedure public.set_updated_at();

alter table public.regions enable row level security;

drop policy if exists "managers_can_manage_regions" on public.regions;
create policy "managers_can_manage_regions"
on public.regions
for all
to authenticated
using (public.current_user_role_id() <= 2)
with check (public.current_user_role_id() <= 2);

drop policy if exists "authenticated_can_view_regions" on public.regions;
create policy "authenticated_can_view_regions"
on public.regions
for select
to authenticated
using (true);

drop policy if exists "agents_can_view_assigned_region" on public.regions;
create policy "agents_can_view_assigned_region"
on public.regions
for select
to authenticated
using (
  assigned_to = auth.uid()
  or public.current_user_role_id() <= 2
);

create index if not exists idx_regions_region_sub_region
  on public.regions (region, sub_region);

create index if not exists idx_regions_assigned_to
  on public.regions (assigned_to);

do $$
begin
  if to_regclass('public.users') is not null then
    if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'users' and column_name = 'region_id') then
      alter table public.users add column region_id uuid references public.regions (id) on delete set null;
    end if;
    if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'users' and column_name = 'sub_region') then
      alter table public.users add column sub_region text;
    end if;
  end if;
end $$;

create index if not exists idx_users_region_id
  on public.users (region_id);

insert into public.regions (region, sub_region, counties) values
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
on conflict (id) do nothing;
