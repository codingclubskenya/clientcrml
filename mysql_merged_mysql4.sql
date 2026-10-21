-- DEHUS Unified PostgreSQL Schema + Seed (regenerated)

-- Built from the verified PostgreSQL sources in supabase/ plus the

-- convertible seed rows from mysql_unified.sql.

-- Run this entire script in the Supabase SQL Editor.

-- It is idempotent: safe to re-run.



-- =========================================================

-- BEGIN FILE: schema.sql

-- =========================================================




begin
  new.updated_at = now();
  return new;
end;
$$;


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

create table if not exists users (
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
    alter table users add column region text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'users' and column_name = 'phone') then
    alter table users add column phone text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'users' and column_name = 'isSynced') then
    alter table users add column "isSynced" boolean not null default false;
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
    alter table users
      alter column role drop default;
    alter table users
      alter column role type integer using role_id_from_text(role::text);
    alter table users
      alter column role set default 5;
  end if;
end $$;

alter table users
  alter column role set default 5;


  select exists (
    select 1
    from users
    where id = auth.uid()
      and role = 1
  );
$$;


  select exists (
    select 1
    from users
    where id = auth.uid()
      and role <= 3
  );
$$;


  select exists (
    select 1
    from users
    where id = auth.uid()
      and role <= 2
  );
$$;


  select exists (
    select 1
    from users
    where id = auth.uid()
      and role <= 3
  );
$$;


  select coalesce(
    (select role from users where id = auth.uid() limit 1),
    5
  );
$$;


  select role_id_from_text(
    coalesce(
      auth.jwt() -> 'user_metadata' ->> 'role',
      auth.jwt() -> 'app_metadata' ->> 'role'
    )
  );
$$;


  select coalesce(
    auth.jwt() -> 'user_metadata' ->> 'region',
    auth.jwt() -> 'app_metadata' ->> 'region'
  );
$$;


  select coalesce(
    (select nullif(btrim(region), '') from users where id = auth.uid() limit 1),
    nullif(btrim(current_user_region_from_jwt()), '')
  );
$$;

create table if not exists schools (
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
  captured_by uuid references users (id) on delete set null,
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
    alter table schools add column source text not null default 'manual';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'external_place_id') then
    alter table schools add column external_place_id text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'external_vicinity') then
    alter table schools add column external_vicinity text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'isSynced') then
    alter table schools add column "isSynced" boolean not null default false;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'book_category') then
    alter table schools add column book_category text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'dealer_type') then
    alter table schools add column dealer_type text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'shop_category') then
    alter table schools add column shop_category text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'selected_product') then
    alter table schools add column selected_product text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'partner_subtype') then
    alter table schools add column partner_subtype text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'gps_accuracy_meters') then
    alter table schools add column gps_accuracy_meters double precision;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'photo_url') then
    alter table schools add column photo_url text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'photo_path') then
    alter table schools add column photo_path text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'captured_by') then
    alter table schools add column captured_by uuid references users (id) on delete set null;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'captured_at') then
    alter table schools add column captured_at timestamptz;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'capture_status') then
    alter table schools add column capture_status text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'contact_name') then
    alter table schools add column contact_name text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'contact_phone') then
    alter table schools add column contact_phone text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'contact_title') then
    alter table schools add column contact_title text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'contact_email') then
    alter table schools add column contact_email text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'feedback') then
    alter table schools add column feedback text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'notes') then
    alter table schools add column notes text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'samples_left') then
    alter table schools add column samples_left text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'sample_book') then
    alter table schools add column sample_book text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'school_ownership') then
    alter table schools add column school_ownership text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'school_ownership_other') then
    alter table schools add column school_ownership_other text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'school_population') then
    alter table schools add column school_population integer;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'school_lifecycle_status') then
    alter table schools add column school_lifecycle_status text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'engagement_type') then
    alter table schools add column engagement_type text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'sample_proof_url') then
    alter table schools add column sample_proof_url text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'sample_proof_path') then
    alter table schools add column sample_proof_path text;
  end if;
end $$;

do $$
begin
  if to_regclass('users') is not null then
    create index if not exists idx_users_role_region on users(role, region);
  end if;
  if to_regclass('tasks') is not null then
    create index if not exists idx_tasks_assigned_status_due on tasks(assigned_to, status, due_at);
  end if;
  if to_regclass('geofences') is not null then
    create index if not exists idx_geofences_region_assigned on geofences(region, assigned_to);
  end if;
  if to_regclass('route_plans') is not null then
    create index if not exists idx_route_plans_assigned_date_status on route_plans(assigned_to, route_date, status);
  end if;
end $$;

create unique index if not exists idx_schools_external_place_id
  on schools (external_place_id)
  where external_place_id is not null;

create table if not exists tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  target_role integer not null default 2,
  due_at timestamptz,
  status text not null default 'open',
  created_by uuid references auth.users (id) on delete set null,
  assigned_to uuid references users (id) on delete set null,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Ensure isSynced column exists in tasks
do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'tasks' and column_name = 'isSynced') then
    alter table tasks add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists geofences (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  region text,
  coordinates jsonb not null default '[]'::jsonb,
  assigned_to uuid references users (id) on delete set null,
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
    alter table geofences add column region text;
  end if;
end $$;

create table if not exists route_plans (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  route_date date not null,
  assigned_to uuid references users (id) on delete set null,
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
    alter table route_plans add column reviewed_by uuid references users (id) on delete set null;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'route_plans' and column_name = 'reviewed_at') then
    alter table route_plans add column reviewed_at timestamptz;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'route_plans' and column_name = 'review_note') then
    alter table route_plans add column review_note text;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'route_plans_status_check'
      and conrelid = 'route_plans'::regclass
  ) then
    alter table route_plans
      add constraint route_plans_status_check
      check (status in ('draft', 'submitted', 'approved', 'rejected', 'assigned', 'in_progress', 'completed'));
  end if;
end $$;

create table if not exists geofence_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  geofence_id uuid references geofences (id) on delete set null,
  event_type text not null,
  region text,
  lat double precision,
  lng double precision,
  reason text,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table if not exists supervisor_alerts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
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

create table if not exists supervisor_incidents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  region text,
  incident_type text not null,
  severity text not null default 'high',
  status text not null default 'open',
  notes text,
  created_by uuid references users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists supervisor_notes (
  id uuid primary key default gen_random_uuid(),
  supervisor_id uuid not null references users (id) on delete cascade,
  user_id uuid not null references users (id) on delete cascade,
  region text,
  context_type text,
  context_id uuid,
  note text not null,
  follow_up_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references users (id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text not null,
  region text,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);

create table if not exists task_completion_evidence (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references tasks (id) on delete cascade,
  submitted_by uuid not null references users (id) on delete cascade,
  gps_lat double precision,
  gps_lng double precision,
  proof_url text,
  proof_type text,
  created_at timestamptz not null default now()
);

create table if not exists supervisor_notifications (
  id uuid primary key default gen_random_uuid(),
  supervisor_id uuid not null references users (id) on delete cascade,
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
  on supervisor_alerts(status, created_at);
create index if not exists idx_supervisor_alerts_region
  on supervisor_alerts(region);
create index if not exists idx_supervisor_notifications_supervisor_scheduled
  on supervisor_notifications(supervisor_id, scheduled_for);
create index if not exists idx_supervisor_notifications_read_at
  on supervisor_notifications(read_at);


declare
  affected_count integer := 0;
begin
  -- Mark open red alerts older than 15 minutes as SLA-breached for ack.
  update supervisor_alerts
  set ack_sla_met = false
  where status = 'open'
    and lower(coalesce(severity, '')) = 'red'
    and created_at <= now() - interval '15 minutes'
    and coalesce(ack_sla_met, true) = true;
  get diagnostics affected_count = row_count;

  -- Escalate unresolved red alerts older than 2 hours.
  with to_escalate as (
    update supervisor_alerts
    set escalated_to_admin = true
    where status = 'open'
      and lower(coalesce(severity, '')) = 'red'
      and created_at <= now() - interval '2 hours'
      and coalesce(escalated_to_admin, false) = false
    returning id, user_id, region, alert_type
  )
  insert into supervisor_notifications (
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
  join users u
    on u.role = 3
   and lower(coalesce(u.region, '')) = lower(coalesce(e.region, ''));

  return affected_count;
end;
$$;


declare
  inserted_count integer := 0;
  batch_count integer := 0;
begin
  -- Morning digest at 07:00 local DB time.
  if to_char(now(), 'HH24:MI') between '07:00' and '07:10' then
    insert into supervisor_notifications (
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
          from supervisor_alerts a
          where lower(coalesce(a.region, '')) = lower(coalesce(s.region, ''))
            and a.status = 'open'
        ),
        'overdue_tasks', (
          select count(*)
          from tasks t
          join users u on u.id = t.assigned_to
          where u.role = 5
            and lower(coalesce(u.region, '')) = lower(coalesce(s.region, ''))
            and t.due_at < now()
            and lower(coalesce(t.status, '')) not in ('closed', 'completed')
        )
      ),
      now()
    from users s
    where s.role = 3;
    get diagnostics batch_count = row_count;
    inserted_count := inserted_count + batch_count;
  end if;

  -- Evening digest at 18:00 local DB time.
  if to_char(now(), 'HH24:MI') between '18:00' and '18:10' then
    insert into supervisor_notifications (
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
          from supervisor_alerts a
          where lower(coalesce(a.region, '')) = lower(coalesce(s.region, ''))
            and a.status = 'resolved'
            and a.resolved_at >= date_trunc('day', now())
        ),
        'completed_routes', (
          select count(*)
          from route_plans r
          join users u on u.id = r.assigned_to
          where u.role = 5
            and lower(coalesce(u.region, '')) = lower(coalesce(s.region, ''))
            and lower(coalesce(r.status, '')) = 'completed'
            and r.route_date = current_date
        )
      ),
      now()
    from users s
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
    alter table route_plans add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists catalog_items (
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
    alter table catalog_items add column "isSynced" boolean not null default false;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'catalog_items' and column_name = 'is_active') then
    alter table catalog_items add column is_active boolean not null default true;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'catalog_items' and column_name = 'item_type') then
    alter table catalog_items add column item_type text not null default 'sale';
  end if;
end $$;

create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references schools (id) on delete set null,
  school_name text not null,
  school_phone text,
  agent_id uuid references users (id) on delete set null,
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
    alter table orders add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders (id) on delete cascade,
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
    alter table order_items add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references users (id) on delete cascade,
  recipient_id uuid not null references users (id) on delete cascade,
  subject text not null,
  body text not null,
  related_school_id uuid references schools (id) on delete set null,
  related_task_id uuid references tasks (id) on delete set null,
  is_read boolean not null default false,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'messages' and column_name = 'isSynced') then
    alter table messages add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists school_visits (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools (id) on delete cascade,
  agent_id uuid references users (id) on delete set null,
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
    alter table school_visits add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists school_follow_ups (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools (id) on delete cascade,
  agent_id uuid references users (id) on delete set null,
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
    alter table school_follow_ups add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists debt_collections (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools (id) on delete cascade,
  collected_by uuid references users (id) on delete set null,
  amount numeric(12,2) not null check (amount > 0),
  payment_method text not null default 'cash',
  payment_reference text,
  notes text,
  collected_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists school_sales (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools (id) on delete cascade,
  agent_id uuid references users (id) on delete set null,
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
    alter table school_sales add column "isSynced" boolean not null default false;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'next_action') then
    alter table school_sales add column next_action text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'next_action_date') then
    alter table school_sales add column next_action_date date;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'last_activity_at') then
    alter table school_sales add column last_activity_at timestamptz;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'forecast_category') then
    alter table school_sales add column forecast_category text default 'pipeline';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'risk_level') then
    alter table school_sales add column risk_level text default 'low';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'weighted_forecast') then
    alter table school_sales add column weighted_forecast numeric(12,2) default 0;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'stage_sla_due_at') then
    alter table school_sales add column stage_sla_due_at timestamptz;
  end if;
end $$;

create index if not exists idx_school_sales_stage_sla_due_at
  on school_sales (stage_sla_due_at);
create index if not exists idx_school_sales_next_action_date
  on school_sales (next_action_date);
create index if not exists idx_school_sales_risk_level
  on school_sales (risk_level);


declare
  v_now timestamptz := now();
  v_order_id uuid := coalesce(nullif(order_payload->>'id', '')::uuid, gen_random_uuid());
  v_order_number text := coalesce(nullif(order_payload->>'order_number', ''), 'ORD-' || to_char(v_now, 'YYYYMMDDHH24MISSMS') || '-' || upper(substring(replace(gen_random_uuid()::text, '-', '') from 1 for 8)));
  v_sale_id uuid := coalesce(nullif(sale_payload->>'id', '')::uuid, gen_random_uuid());
  v_order orders%rowtype;
  v_sale school_sales%rowtype;
begin
  insert into orders (
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
    insert into order_items (
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

  insert into school_sales (
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

create table if not exists opportunity_activities (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references school_sales (id) on delete cascade,
  school_id uuid references schools (id) on delete set null,
  actor_id uuid references users (id) on delete set null,
  activity_type text not null,
  activity_outcome text,
  notes text,
  next_action text,
  next_action_date date,
  created_at timestamptz not null default now()
);

create index if not exists idx_opportunity_activities_opportunity
  on opportunity_activities (opportunity_id, created_at desc);


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

drop trigger if exists derive_school_sale_metrics on school_sales;



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

drop trigger if exists enforce_school_sale_followup_trigger on school_sales;


update school_sales
set
  next_action = coalesce(nullif(btrim(next_action), ''), 'Follow up call'),
  next_action_date = coalesce(next_action_date, current_date + 2)
where lower(coalesce(sale_status, 'lead')) not in ('won', 'lost', 'dormant')
  and (
    nullif(btrim(coalesce(next_action, '')), '') is null
    or next_action_date is null
  );


begin
  if nullif(btrim(coalesce(new.next_action, '')), '') is null then
    raise exception 'next_action is required when logging opportunity activity';
  end if;
  if new.next_action_date is null then
    raise exception 'next_action_date is required when logging opportunity activity';
  end if;

  update school_sales
  set
    last_activity_at = new.created_at,
    next_action = new.next_action,
    next_action_date = new.next_action_date,
    stage_updated_at = now()
  where id = new.opportunity_id;

  return new;
end;
$$;

drop trigger if exists sync_opportunity_activity_to_sale_trigger on opportunity_activities;



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
    select 1 from users u
    where u.id = new.assigned_to
      and u.role = 5
  ) into v_is_role5;

  if not v_is_role5 then
    return new;
  end if;

  select exists (
    select 1
    from task_completion_evidence e
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

drop trigger if exists enforce_role5_task_completion_evidence_trigger on tasks;



declare
  inserted_count integer := 0;
begin
  insert into supervisor_alerts (
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
  from school_sales s
  join users u on u.id = s.agent_id
  where u.role = 5
    and s.next_action_date is not null
    and s.next_action_date < current_date
    and lower(coalesce(s.sale_status, '')) not in ('won', 'lost', 'dormant')
    and not exists (
      select 1
      from supervisor_alerts a
      where a.user_id = s.agent_id
        and a.alert_type = 'overdue_followup'
        and a.status = 'open'
        and a.created_at >= now() - interval '24 hours'
    );

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;

create table if not exists pipeline_history (
  id uuid primary key default gen_random_uuid(),
  pipeline_id uuid not null references school_sales (id) on delete cascade,
  old_stage text,
  new_stage text not null,
  changed_by uuid references users (id) on delete set null,
  changed_at timestamptz not null default now(),
  notes text
);

create index if not exists idx_pipeline_history_pipeline_id
  on pipeline_history (pipeline_id);

create index if not exists idx_pipeline_history_changed_at
  on pipeline_history (changed_at desc);


begin
  if tg_op = 'INSERT' then
    insert into pipeline_history (pipeline_id, old_stage, new_stage, changed_by, notes)
    values (new.id, null, new.sale_status, auth.uid(), new.notes);
    return new;
  end if;

  if tg_op = 'UPDATE' and coalesce(new.sale_status, '') <> coalesce(old.sale_status, '') then
    insert into pipeline_history (pipeline_id, old_stage, new_stage, changed_by, notes)
    values (new.id, old.sale_status, new.sale_status, auth.uid(), new.notes);
  end if;

  return new;
end;
$$;

create table if not exists school_sample_distributions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools (id) on delete cascade,
  agent_id uuid references users (id) on delete set null,
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
    alter table school_sample_distributions add column "isSynced" boolean not null default false;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sample_distributions' and column_name = 'stamped_receipt_url') then
    alter table school_sample_distributions add column stamped_receipt_url text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sample_distributions' and column_name = 'stamped_receipt_path') then
    alter table school_sample_distributions add column stamped_receipt_path text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sample_distributions' and column_name = 'client_type') then
    alter table school_sample_distributions add column client_type text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sample_distributions' and column_name = 'returned_qty') then
    alter table school_sample_distributions add column returned_qty integer not null default 0;
  end if;
end $$;


begin
  insert into users (id, email, full_name, phone, role, region)
  values (
    new.id,
    new.email,
    coalesce(nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''), 'Not Captured'),
    coalesce(nullif(btrim(new.raw_user_meta_data ->> 'phone'), ''), 'Not Captured'),
    role_id_from_text(new.raw_user_meta_data ->> 'role'),
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


begin
  update users
  set email = new.email,
      full_name = coalesce(nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''), full_name, 'Not Captured'),
      phone = coalesce(nullif(btrim(new.raw_user_meta_data ->> 'phone'), ''), phone, 'Not Captured'),
      region = coalesce(nullif(btrim(new.raw_user_meta_data ->> 'region'), ''), region, 'Not Captured')
      -- Keep role untouched so admin changes in users are not overwritten by auth metadata.
  where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;


drop trigger if exists on_auth_user_updated on auth.users;


-- Backfill existing auth users into users so current accounts are linked too.
insert into users (id, email, full_name, phone, role, region)
select
  u.id,
  u.email,
  coalesce(nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''), 'Not Captured'),
  coalesce(nullif(btrim(u.raw_user_meta_data ->> 'phone'), ''), 'Not Captured'),
  role_id_from_text(u.raw_user_meta_data ->> 'role'),
  coalesce(nullif(btrim(u.raw_user_meta_data ->> 'region'), ''), 'Not Captured')
from auth.users u
on conflict (id) do update
set email = excluded.email,
    full_name = excluded.full_name,
    phone = excluded.phone,
    role = excluded.role,
    region = excluded.region;

drop trigger if exists touch_users_updated_at on users;


drop trigger if exists touch_schools_updated_at on schools;


drop trigger if exists touch_tasks_updated_at on tasks;


drop trigger if exists touch_geofences_updated_at on geofences;


drop trigger if exists touch_route_plans_updated_at on route_plans;


drop trigger if exists touch_catalog_items_updated_at on catalog_items;


drop trigger if exists touch_orders_updated_at on orders;


drop trigger if exists touch_order_items_updated_at on order_items;


drop trigger if exists touch_messages_updated_at on messages;


drop trigger if exists touch_school_visits_updated_at on school_visits;


drop trigger if exists touch_school_follow_ups_updated_at on school_follow_ups;


drop trigger if exists touch_debt_collections_updated_at on debt_collections;


drop trigger if exists touch_school_sales_updated_at on school_sales;


drop trigger if exists log_school_sales_stage_change on school_sales;


drop trigger if exists touch_school_sample_distributions_updated_at on school_sample_distributions;


alter table users enable row level security;
alter table schools enable row level security;
alter table tasks enable row level security;
alter table geofences enable row level security;
alter table route_plans enable row level security;
alter table catalog_items enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table messages enable row level security;
alter table school_visits enable row level security;
alter table school_follow_ups enable row level security;
alter table debt_collections enable row level security;
alter table school_sales enable row level security;
alter table pipeline_history enable row level security;
alter table school_sample_distributions enable row level security;
alter table opportunity_activities enable row level security;
alter table geofence_events enable row level security;
alter table supervisor_alerts enable row level security;
alter table supervisor_incidents enable row level security;
alter table supervisor_notes enable row level security;
alter table audit_events enable row level security;
alter table task_completion_evidence enable row level security;
alter table supervisor_notifications enable row level security;

drop policy if exists "users_can_manage_own_row" on users;
DROP POLICY IF EXISTS "users_can_manage_own_row" ON users;
create policy "users_can_manage_own_row"
on users
for all
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "authenticated_can_view_users" on users;
DROP POLICY IF EXISTS "authenticated_can_view_users" ON users;
create policy "authenticated_can_view_users"
on users
for select
to authenticated
using (
  auth.uid() = id
  or current_user_role_id() <= 2
  or (
    current_user_role_id() = 3
    and role = 5
    and lower(coalesce(region, '')) = lower(coalesce(current_user_region(), ''))
  )
);

drop policy if exists "admins_can_manage_users" on users;
DROP POLICY IF EXISTS "admins_can_manage_users" ON users;
create policy "admins_can_manage_users"
on users
for all
to authenticated
using (is_admin())
with check (is_admin());

drop policy if exists "authenticated_can_manage_schools" on schools;
DROP POLICY IF EXISTS "authenticated_can_manage_schools" ON schools;
create policy "authenticated_can_manage_schools"
on schools
for all
to authenticated
using (true)
with check (true);

drop policy if exists "authenticated_can_view_assigned_tasks" on tasks;
DROP POLICY IF EXISTS "authenticated_can_view_assigned_tasks" ON tasks;
create policy "authenticated_can_view_assigned_tasks"
on tasks
for select
to authenticated
using (
  target_role = 0
  or target_role >= current_user_role_id()
  or assigned_to = auth.uid()
  or current_user_role_id() <= 2
  or (
    current_user_role_id() = 3
    and exists (
      select 1
      from users u
      where u.id = tasks.assigned_to
        and u.role = 5
        and lower(coalesce(u.region, '')) = lower(coalesce(current_user_region(), ''))
    )
  )
);

drop policy if exists "admins_can_manage_tasks" on tasks;
drop policy if exists "managers_can_manage_tasks" on tasks;
DROP POLICY IF EXISTS "managers_can_manage_tasks" ON tasks;
create policy "managers_can_manage_tasks"
on tasks
for all
to authenticated
using (
  current_user_role_id() <= 2
  or (
    current_user_role_id() = 3
    and exists (
      select 1
      from users u
      where u.id = tasks.assigned_to
        and u.role = 5
        and lower(coalesce(u.region, '')) = lower(coalesce(current_user_region(), ''))
    )
  )
)
with check (
  current_user_role_id() <= 2
  or (
    current_user_role_id() = 3
    and exists (
      select 1
      from users u
      where u.id = tasks.assigned_to
        and u.role = 5
        and lower(coalesce(u.region, '')) = lower(coalesce(current_user_region(), ''))
    )
  )
);

drop policy if exists "authenticated_can_view_geofences" on geofences;
DROP POLICY IF EXISTS "authenticated_can_view_geofences" ON geofences;
create policy "authenticated_can_view_geofences"
on geofences
for select
to authenticated
using (
  assigned_to = auth.uid()
  or current_user_role_id() <= 2
  or (
    current_user_role_id() = 3
    and (
      lower(coalesce(geofences.region, '')) = lower(coalesce(current_user_region(), ''))
      or exists (
        select 1
        from users u
        where u.id = geofences.assigned_to
          and u.role = 5
          and lower(coalesce(u.region, '')) = lower(coalesce(current_user_region(), ''))
      )
    )
  )
);

drop policy if exists "managers_can_manage_geofences" on geofences;
DROP POLICY IF EXISTS "managers_can_manage_geofences" ON geofences;
create policy "managers_can_manage_geofences"
on geofences
for all
to authenticated
using (
  current_user_role_id() <= 2
  or (
    current_user_role_id() = 3
    and (
      lower(coalesce(geofences.region, '')) = lower(coalesce(current_user_region(), ''))
      or exists (
        select 1
        from users u
        where u.id = geofences.assigned_to
          and u.role = 5
          and lower(coalesce(u.region, '')) = lower(coalesce(current_user_region(), ''))
      )
    )
  )
)
with check (
  current_user_role_id() <= 2
  or (
    current_user_role_id() = 3
    and (
      lower(coalesce(geofences.region, '')) = lower(coalesce(current_user_region(), ''))
      or exists (
        select 1
        from users u
        where u.id = geofences.assigned_to
          and u.role = 5
          and lower(coalesce(u.region, '')) = lower(coalesce(current_user_region(), ''))
      )
    )
  )
);

drop policy if exists "authenticated_can_view_route_plans" on route_plans;
DROP POLICY IF EXISTS "authenticated_can_view_route_plans" ON route_plans;
create policy "authenticated_can_view_route_plans"
on route_plans
for select
to authenticated
using (
  assigned_to = auth.uid()
  or current_user_role_id() <= 2
  or (
    current_user_role_id() = 3
    and exists (
      select 1
      from users u
      where u.id = route_plans.assigned_to
        and u.role = 5
        and lower(coalesce(u.region, '')) = lower(coalesce(current_user_region(), ''))
    )
  )
);

drop policy if exists "managers_can_manage_route_plans" on route_plans;
DROP POLICY IF EXISTS "managers_can_manage_route_plans" ON route_plans;
create policy "managers_can_manage_route_plans"
on route_plans
for all
to authenticated
using (
  current_user_role_id() <= 2
  or (
    current_user_role_id() = 3
    and exists (
      select 1
      from users u
      where u.id = route_plans.assigned_to
        and u.role = 5
        and lower(coalesce(u.region, '')) = lower(coalesce(current_user_region(), ''))
    )
  )
)
with check (
  current_user_role_id() <= 2
  or (
    current_user_role_id() = 3
    and exists (
      select 1
      from users u
      where u.id = route_plans.assigned_to
        and u.role = 5
        and lower(coalesce(u.region, '')) = lower(coalesce(current_user_region(), ''))
    )
  )
);

drop policy if exists "role5_can_submit_route_plans" on route_plans;
DROP POLICY IF EXISTS "role5_can_submit_route_plans" ON route_plans;
create policy "role5_can_submit_route_plans"
on route_plans
for update
to authenticated
using (assigned_to = auth.uid())
with check (
  assigned_to = auth.uid()
  and status in ('submitted', 'in_progress', 'completed')
);

drop policy if exists "authenticated_can_view_geofence_events" on geofence_events;
DROP POLICY IF EXISTS "authenticated_can_view_geofence_events" ON geofence_events;
create policy "authenticated_can_view_geofence_events"
on geofence_events
for select
to authenticated
using (
  user_id = auth.uid()
  or current_user_role_id() <= 2
  or (
    current_user_role_id() = 3
    and lower(coalesce(region, '')) = lower(coalesce(current_user_region(), ''))
  )
);

drop policy if exists "authenticated_can_manage_geofence_events" on geofence_events;
DROP POLICY IF EXISTS "authenticated_can_manage_geofence_events" ON geofence_events;
create policy "authenticated_can_manage_geofence_events"
on geofence_events
for all
to authenticated
using (
  user_id = auth.uid()
  or current_user_role_id() <= 2
  or (
    current_user_role_id() = 3
    and lower(coalesce(region, '')) = lower(coalesce(current_user_region(), ''))
  )
)
with check (
  user_id = auth.uid()
  or current_user_role_id() <= 2
  or (
    current_user_role_id() = 3
    and lower(coalesce(region, '')) = lower(coalesce(current_user_region(), ''))
  )
);

drop policy if exists "authenticated_can_view_supervisor_alerts" on supervisor_alerts;
DROP POLICY IF EXISTS "authenticated_can_view_supervisor_alerts" ON supervisor_alerts;
create policy "authenticated_can_view_supervisor_alerts"
on supervisor_alerts
for select
to authenticated
using (
  user_id = auth.uid()
  or current_user_role_id() <= 2
  or (
    current_user_role_id() = 3
    and lower(coalesce(region, '')) = lower(coalesce(current_user_region(), ''))
  )
);

drop policy if exists "managers_can_manage_supervisor_alerts" on supervisor_alerts;
DROP POLICY IF EXISTS "managers_can_manage_supervisor_alerts" ON supervisor_alerts;
create policy "managers_can_manage_supervisor_alerts"
on supervisor_alerts
for all
to authenticated
using (current_user_role_id() <= 3)
with check (current_user_role_id() <= 3);

drop policy if exists "authenticated_can_view_supervisor_incidents" on supervisor_incidents;
DROP POLICY IF EXISTS "authenticated_can_view_supervisor_incidents" ON supervisor_incidents;
create policy "authenticated_can_view_supervisor_incidents"
on supervisor_incidents
for select
to authenticated
using (
  user_id = auth.uid()
  or current_user_role_id() <= 2
  or (
    current_user_role_id() = 3
    and lower(coalesce(region, '')) = lower(coalesce(current_user_region(), ''))
  )
);

drop policy if exists "managers_can_manage_supervisor_incidents" on supervisor_incidents;
DROP POLICY IF EXISTS "managers_can_manage_supervisor_incidents" ON supervisor_incidents;
create policy "managers_can_manage_supervisor_incidents"
on supervisor_incidents
for all
to authenticated
using (current_user_role_id() <= 3)
with check (current_user_role_id() <= 3);

drop policy if exists "authenticated_can_view_supervisor_notes" on supervisor_notes;
DROP POLICY IF EXISTS "authenticated_can_view_supervisor_notes" ON supervisor_notes;
create policy "authenticated_can_view_supervisor_notes"
on supervisor_notes
for select
to authenticated
using (
  user_id = auth.uid()
  or supervisor_id = auth.uid()
  or current_user_role_id() <= 2
  or (
    current_user_role_id() = 3
    and lower(coalesce(region, '')) = lower(coalesce(current_user_region(), ''))
  )
);

drop policy if exists "managers_can_manage_supervisor_notes" on supervisor_notes;
DROP POLICY IF EXISTS "managers_can_manage_supervisor_notes" ON supervisor_notes;
create policy "managers_can_manage_supervisor_notes"
on supervisor_notes
for all
to authenticated
using (supervisor_id = auth.uid() or current_user_role_id() <= 2)
with check (supervisor_id = auth.uid() or current_user_role_id() <= 2);

drop policy if exists "admins_can_view_audit_events" on audit_events;
DROP POLICY IF EXISTS "admins_can_view_audit_events" ON audit_events;
create policy "admins_can_view_audit_events"
on audit_events
for select
to authenticated
using (current_user_role_id() <= 2);

drop policy if exists "managers_can_insert_audit_events" on audit_events;
DROP POLICY IF EXISTS "managers_can_insert_audit_events" ON audit_events;
create policy "managers_can_insert_audit_events"
on audit_events
for insert
to authenticated
with check (current_user_role_id() <= 3);

drop policy if exists "authenticated_can_view_task_completion_evidence" on task_completion_evidence;
DROP POLICY IF EXISTS "authenticated_can_view_task_completion_evidence" ON task_completion_evidence;
create policy "authenticated_can_view_task_completion_evidence"
on task_completion_evidence
for select
to authenticated
using (
  submitted_by = auth.uid()
  or exists (
    select 1
    from tasks t
    where t.id = task_id
      and (t.assigned_to = auth.uid() or current_user_role_id() <= 3)
  )
);

drop policy if exists "authenticated_can_manage_task_completion_evidence" on task_completion_evidence;
DROP POLICY IF EXISTS "authenticated_can_manage_task_completion_evidence" ON task_completion_evidence;
create policy "authenticated_can_manage_task_completion_evidence"
on task_completion_evidence
for all
to authenticated
using (submitted_by = auth.uid() or current_user_role_id() <= 3)
with check (submitted_by = auth.uid() or current_user_role_id() <= 3);

drop policy if exists "authenticated_can_view_supervisor_notifications" on supervisor_notifications;
DROP POLICY IF EXISTS "authenticated_can_view_supervisor_notifications" ON supervisor_notifications;
create policy "authenticated_can_view_supervisor_notifications"
on supervisor_notifications
for select
to authenticated
using (
  supervisor_id = auth.uid()
  or current_user_role_id() <= 2
);

drop policy if exists "authenticated_can_update_supervisor_notifications" on supervisor_notifications;
DROP POLICY IF EXISTS "authenticated_can_update_supervisor_notifications" ON supervisor_notifications;
create policy "authenticated_can_update_supervisor_notifications"
on supervisor_notifications
for update
to authenticated
using (
  supervisor_id = auth.uid()
  or current_user_role_id() <= 2
)
with check (
  supervisor_id = auth.uid()
  or current_user_role_id() <= 2
);

drop policy if exists "managers_can_insert_supervisor_notifications" on supervisor_notifications;
DROP POLICY IF EXISTS "managers_can_insert_supervisor_notifications" ON supervisor_notifications;
create policy "managers_can_insert_supervisor_notifications"
on supervisor_notifications
for insert
to authenticated
with check (current_user_role_id() <= 3);

drop policy if exists "authenticated_can_view_catalog_items" on catalog_items;
DROP POLICY IF EXISTS "authenticated_can_view_catalog_items" ON catalog_items;
create policy "authenticated_can_view_catalog_items"
on catalog_items
for select
to authenticated
using (is_active = true or is_manager_or_admin());

drop policy if exists "admins_can_manage_catalog_items" on catalog_items;
drop policy if exists "managers_can_manage_catalog_items" on catalog_items;
DROP POLICY IF EXISTS "managers_can_manage_catalog_items" ON catalog_items;
create policy "managers_can_manage_catalog_items"
on catalog_items
for all
to authenticated
using (is_manager_or_admin())
with check (is_manager_or_admin());

drop policy if exists "authenticated_can_view_orders" on orders;
DROP POLICY IF EXISTS "authenticated_can_view_orders" ON orders;
create policy "authenticated_can_view_orders"
on orders
for select
to authenticated
using (
  agent_id = auth.uid()
  or is_manager_or_admin()
);

drop policy if exists "authenticated_can_manage_orders" on orders;
DROP POLICY IF EXISTS "authenticated_can_manage_orders" ON orders;
create policy "authenticated_can_manage_orders"
on orders
for all
to authenticated
using (
  agent_id = auth.uid()
  or is_manager_or_admin()
)
with check (
  agent_id = auth.uid()
  or is_manager_or_admin()
);

drop policy if exists "authenticated_can_view_order_items" on order_items;
DROP POLICY IF EXISTS "authenticated_can_view_order_items" ON order_items;
create policy "authenticated_can_view_order_items"
on order_items
for select
to authenticated
using (
  exists (
    select 1
    from orders
    where orders.id = order_id
      and (orders.agent_id = auth.uid() or is_manager_or_admin())
  )
);

drop policy if exists "authenticated_can_manage_order_items" on order_items;
DROP POLICY IF EXISTS "authenticated_can_manage_order_items" ON order_items;
create policy "authenticated_can_manage_order_items"
on order_items
for all
to authenticated
using (
  exists (
    select 1
    from orders
    where orders.id = order_id
      and (orders.agent_id = auth.uid() or is_manager_or_admin())
  )
)
with check (
  exists (
    select 1
    from orders
    where orders.id = order_id
      and (orders.agent_id = auth.uid() or is_manager_or_admin())
  )
);

drop policy if exists "authenticated_can_view_messages" on messages;
DROP POLICY IF EXISTS "authenticated_can_view_messages" ON messages;
create policy "authenticated_can_view_messages"
on messages
for select
to authenticated
using (
  sender_id = auth.uid()
  or recipient_id = auth.uid()
  or is_manager_or_admin()
);

drop policy if exists "authenticated_can_send_messages" on messages;
DROP POLICY IF EXISTS "authenticated_can_send_messages" ON messages;
create policy "authenticated_can_send_messages"
on messages
for insert
to authenticated
with check (
  sender_id = auth.uid()
  or is_manager_or_admin()
);

drop policy if exists "authenticated_can_update_messages" on messages;
DROP POLICY IF EXISTS "authenticated_can_update_messages" ON messages;
create policy "authenticated_can_update_messages"
on messages
for update
to authenticated
using (
  sender_id = auth.uid()
  or recipient_id = auth.uid()
  or is_manager_or_admin()
)
with check (
  sender_id = auth.uid()
  or recipient_id = auth.uid()
  or is_manager_or_admin()
);

drop policy if exists "authenticated_can_delete_messages" on messages;
DROP POLICY IF EXISTS "authenticated_can_delete_messages" ON messages;
create policy "authenticated_can_delete_messages"
on messages
for delete
to authenticated
using (
  sender_id = auth.uid()
  or recipient_id = auth.uid()
  or is_manager_or_admin()
);

drop policy if exists "agents_can_manage_school_visits" on school_visits;
DROP POLICY IF EXISTS "agents_can_manage_school_visits" ON school_visits;
create policy "agents_can_manage_school_visits"
on school_visits
for all
to authenticated
using (agent_id = auth.uid() or is_manager_or_admin())
with check (agent_id = auth.uid() or is_manager_or_admin());

drop policy if exists "agents_can_manage_school_follow_ups" on school_follow_ups;
DROP POLICY IF EXISTS "agents_can_manage_school_follow_ups" ON school_follow_ups;
create policy "agents_can_manage_school_follow_ups"
on school_follow_ups
for all
to authenticated
using (agent_id = auth.uid() or is_manager_or_admin())
with check (agent_id = auth.uid() or is_manager_or_admin());

drop policy if exists "authenticated_can_manage_debt_collections" on debt_collections;
DROP POLICY IF EXISTS "authenticated_can_manage_debt_collections" ON debt_collections;
create policy "authenticated_can_manage_debt_collections"
on debt_collections
for all
to authenticated
using (collected_by = auth.uid() or is_manager_or_admin())
with check (collected_by = auth.uid() or is_manager_or_admin());

drop policy if exists "agents_can_manage_school_sales" on school_sales;
DROP POLICY IF EXISTS "agents_can_manage_school_sales" ON school_sales;
create policy "agents_can_manage_school_sales"
on school_sales
for all
to authenticated
using (agent_id = auth.uid() or is_manager_or_admin())
with check (agent_id = auth.uid() or is_manager_or_admin());

drop policy if exists "authenticated_can_view_opportunity_activities" on opportunity_activities;
DROP POLICY IF EXISTS "authenticated_can_view_opportunity_activities" ON opportunity_activities;
create policy "authenticated_can_view_opportunity_activities"
on opportunity_activities
for select
to authenticated
using (
  actor_id = auth.uid()
  or exists (
    select 1
    from school_sales s
    where s.id = opportunity_id
      and (s.agent_id = auth.uid() or current_user_role_id() <= 3)
  )
);

drop policy if exists "authenticated_can_manage_opportunity_activities" on opportunity_activities;
DROP POLICY IF EXISTS "authenticated_can_manage_opportunity_activities" ON opportunity_activities;
create policy "authenticated_can_manage_opportunity_activities"
on opportunity_activities
for all
to authenticated
using (
  actor_id = auth.uid()
  or current_user_role_id() <= 3
)
with check (
  actor_id = auth.uid()
  or current_user_role_id() <= 3
);

drop policy if exists "authenticated_can_view_pipeline_history" on pipeline_history;
DROP POLICY IF EXISTS "authenticated_can_view_pipeline_history" ON pipeline_history;
create policy "authenticated_can_view_pipeline_history"
on pipeline_history
for select
to authenticated
using (
  exists (
    select 1
    from school_sales s
    where s.id = pipeline_id
      and (s.agent_id = auth.uid() or is_manager_or_admin())
  )
);

drop policy if exists "agents_can_manage_school_sample_distributions" on school_sample_distributions;
DROP POLICY IF EXISTS "agents_can_manage_school_sample_distributions" ON school_sample_distributions;
create policy "agents_can_manage_school_sample_distributions"
on school_sample_distributions
for all
to authenticated
using (agent_id = auth.uid() or is_manager_or_admin())
with check (agent_id = auth.uid() or is_manager_or_admin());

create table if not exists sample_requests (
  id uuid primary key default gen_random_uuid(),
  request_code text not null unique,
  school_id uuid references schools (id) on delete cascade,
  client_type text,
  requested_by uuid references users (id) on delete set null,
  purpose text,
  notes text,
  status text not null default 'PENDING',
  rejection_reason text,
  needed_by timestamptz,
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references users (id) on delete set null,
  items jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists touch_sample_requests_updated_at on sample_requests;


alter table sample_requests enable row level security;

drop policy if exists "users_can_manage_sample_requests" on sample_requests;
DROP POLICY IF EXISTS "users_can_manage_sample_requests" ON sample_requests;
create policy "users_can_manage_sample_requests"
on sample_requests
for all
to authenticated
using (requested_by = auth.uid() or is_manager_or_admin())
with check (requested_by = auth.uid() or is_manager_or_admin());

-- END FILE: schema.sql


-- =========================================================

-- BEGIN FILE: schema_updates.sql

-- =========================================================

-- Updates for newly added Dashboard, Analytics, Geofencing, and Assignment features

-- 0. Update Tasks Table for Individual Assignment and Time Filtering
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS assigned_to UUID REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS due_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS target_role INTEGER NOT NULL DEFAULT 2;

-- 0b. Schools table updates for onboarding tracking + external discovery
ALTER TABLE schools ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'manual';
ALTER TABLE schools ADD COLUMN IF NOT EXISTS external_place_id TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS external_vicinity TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS contact_name TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS contact_phone TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS contact_title TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS feedback TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS samples_left TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS sample_books TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS school_ownership TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS school_ownership_other TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS school_population INTEGER;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS school_lifecycle_status TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS engagement_type TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS dealer_type TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS shop_category TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS selected_product TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS partner_subtype TEXT;
ALTER TABLE school_sample_distributions ADD COLUMN IF NOT EXISTS stamped_receipt_url TEXT;
ALTER TABLE school_sample_distributions ADD COLUMN IF NOT EXISTS stamped_receipt_path TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_schools_external_place_id
ON schools (external_place_id)
WHERE external_place_id IS NOT NULL;

DO $$ BEGIN
    ALTER TABLE schools
    DROP CONSTRAINT IF EXISTS schools_source_check;
    ALTER TABLE schools
    ADD CONSTRAINT schools_source_check CHECK (source IN ('manual', 'google'));
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- 1. Route Plans Table
CREATE TABLE IF NOT EXISTS route_plans (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL DEFAULT 'Route Plan',
    route_date DATE NOT NULL DEFAULT CURRENT_DATE,
    assigned_to UUID REFERENCES users(id) ON DELETE CASCADE,
    school_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'assigned',
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    "isSynced" BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Geofences Table
CREATE TABLE IF NOT EXISTS geofences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    coordinates JSONB NOT NULL DEFAULT '[]'::jsonb,
    assigned_to UUID REFERENCES users(id) ON DELETE CASCADE,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. School Sample Distributions Table
CREATE TABLE IF NOT EXISTS school_sample_distributions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE,
    agent_id UUID REFERENCES users(id) ON DELETE CASCADE,
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
CREATE TABLE IF NOT EXISTS debt_collections (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    collected_by UUID REFERENCES users(id) ON DELETE SET NULL,
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    payment_method TEXT NOT NULL DEFAULT 'cash',
    payment_reference TEXT,
    notes TEXT,
    collected_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Catalog Items Table
CREATE TABLE IF NOT EXISTS catalog_items (
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
CREATE TABLE IF NOT EXISTS orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID REFERENCES schools(id) ON DELETE SET NULL,
    school_name TEXT NOT NULL,
    school_phone TEXT,
    agent_id UUID REFERENCES users(id) ON DELETE SET NULL,
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


DECLARE
    v_now timestamptz := now();
    v_order_id uuid := coalesce(nullif(order_payload->>'id', '')::uuid, gen_random_uuid());
    v_order_number text := coalesce(nullif(order_payload->>'order_number', ''), 'ORD-' || to_char(v_now, 'YYYYMMDDHH24MISSMS') || '-' || upper(substring(replace(gen_random_uuid()::text, '-', '') from 1 for 8)));
    v_sale_id uuid := coalesce(nullif(sale_payload->>'id', '')::uuid, gen_random_uuid());
    v_order orders%rowtype;
    v_sale school_sales%rowtype;
BEGIN
    INSERT INTO orders (
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
    ) VALUES (
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
    RETURNING * INTO v_order;

    IF items_payload IS NOT NULL AND jsonb_typeof(items_payload) = 'array' THEN
        INSERT INTO order_items (
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
        SELECT
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
        FROM jsonb_array_elements(items_payload) AS item;
    END IF;

    INSERT INTO school_sales (
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
    ) VALUES (
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
    ON CONFLICT (id) DO UPDATE SET
        school_id = EXCLUDED.school_id,
        agent_id = EXCLUDED.agent_id,
        package_name = EXCLUDED.package_name,
        expected_value = EXCLUDED.expected_value,
        notes = EXCLUDED.notes,
        sale_status = EXCLUDED.sale_status,
        stage_updated_at = EXCLUDED.stage_updated_at,
        expected_close_date = EXCLUDED.expected_close_date,
        probability = EXCLUDED.probability,
        closed_at = EXCLUDED.closed_at,
        "isSynced" = EXCLUDED."isSynced",
        updated_at = EXCLUDED.updated_at
    RETURNING * INTO v_sale;

    RETURN jsonb_build_object(
        'order', to_jsonb(v_order),
        'sale', to_jsonb(v_sale)
    );
END;
$$;

-- 6. School Sales Pipeline migrations
-- Source of truth schema lives in schema.sql; keep only ALTER/DO migrations here.

DO $$ BEGIN
    ALTER TABLE school_sales
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

CREATE TABLE IF NOT EXISTS pipeline_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    pipeline_id UUID NOT NULL REFERENCES school_sales(id) ON DELETE CASCADE,
    old_stage TEXT,
    new_stage TEXT NOT NULL,
    changed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    changed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_pipeline_history_pipeline_id
ON pipeline_history (pipeline_id);

CREATE INDEX IF NOT EXISTS idx_pipeline_history_changed_at
ON pipeline_history (changed_at DESC);


BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO pipeline_history (pipeline_id, old_stage, new_stage, changed_by, notes)
        VALUES (NEW.id, NULL, NEW.sale_status, auth.uid(), NEW.notes);
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND coalesce(NEW.sale_status, '') <> coalesce(OLD.sale_status, '') THEN
        INSERT INTO pipeline_history (pipeline_id, old_stage, new_stage, changed_by, notes)
        VALUES (NEW.id, OLD.sale_status, NEW.sale_status, auth.uid(), NEW.notes);
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_school_sales_stage_change ON school_sales;


DO $$ BEGIN
    UPDATE school_sales
    SET sale_status = 'lead'
    WHERE sale_status IN ('draft', 'pipeline') OR sale_status IS NULL;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE school_sales
    ALTER COLUMN sale_status SET DEFAULT 'lead';
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE school_sales
    DROP CONSTRAINT IF EXISTS school_sales_sale_status_check;
    ALTER TABLE school_sales
    DROP CONSTRAINT IF EXISTS school_sales_sample_quantity_check;
    ALTER TABLE school_sales
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
    ALTER TABLE school_sales
    ADD CONSTRAINT school_sales_sample_quantity_check CHECK (
        sample_quantity IS NULL OR sample_quantity >= 0
    );
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- Enable Row Level Security (RLS) on all new tables
ALTER TABLE route_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE geofences ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_sample_distributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE debt_collections ENABLE ROW LEVEL SECURITY;

-- Optional: Re-create missing permissive policies if needed
-- (Your schema.sql handles granular RLS policies already, these act as fallbacks if missing)
DO $$ BEGIN
    CREATE POLICY "Allow authenticated full access on route_plans" ON route_plans FOR ALL TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    DROP POLICY IF EXISTS "authenticated_can_view_pipeline_history" ON pipeline_history;
CREATE POLICY "authenticated_can_view_pipeline_history"
    ON pipeline_history
    FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1
        FROM school_sales s
        WHERE s.id = pipeline_id
          AND (s.agent_id = auth.uid() OR is_manager_or_admin())
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    DROP POLICY IF EXISTS "authenticated_can_delete_messages" ON messages;
CREATE POLICY "authenticated_can_delete_messages"
    ON messages
    FOR DELETE
    TO authenticated
    USING (
      sender_id = auth.uid()
      OR recipient_id = auth.uid()
      OR is_manager_or_admin()
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    DROP POLICY IF EXISTS "authenticated_can_manage_debt_collections" ON debt_collections;
CREATE POLICY "authenticated_can_manage_debt_collections"
    ON debt_collections
    FOR ALL
    TO authenticated
    USING (collected_by = auth.uid() OR is_manager_or_admin())
    WITH CHECK (collected_by = auth.uid() OR is_manager_or_admin());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Social inbox sync tables for Facebook + WhatsApp bot
CREATE TABLE IF NOT EXISTS social_conversations (
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

CREATE TABLE IF NOT EXISTS social_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id uuid NOT NULL REFERENCES social_conversations(id) ON DELETE CASCADE,
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

ALTER TABLE social_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE social_messages ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    DROP POLICY IF EXISTS "authenticated_can_view_social_conversations" ON social_conversations;
CREATE POLICY "authenticated_can_view_social_conversations"
    ON social_conversations
    FOR SELECT
    TO authenticated
    USING (is_manager_or_admin());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    DROP POLICY IF EXISTS "service_role_can_manage_social_conversations" ON social_conversations;
CREATE POLICY "service_role_can_manage_social_conversations"
    ON social_conversations
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    DROP POLICY IF EXISTS "authenticated_can_view_social_messages" ON social_messages;
CREATE POLICY "authenticated_can_view_social_messages"
    ON social_messages
    FOR SELECT
    TO authenticated
    USING (is_manager_or_admin());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    DROP POLICY IF EXISTS "service_role_can_manage_social_messages" ON social_messages;
CREATE POLICY "service_role_can_manage_social_messages"
    ON social_messages
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Stamped sample proof fields on schools
ALTER TABLE schools
ADD COLUMN IF NOT EXISTS sample_proof_url TEXT;

ALTER TABLE schools
ADD COLUMN IF NOT EXISTS sample_proof_path TEXT;

-- ROI support for sample distribution (Role 5 and admin analytics)
CREATE INDEX IF NOT EXISTS idx_sample_distributions_agent_school
ON school_sample_distributions (agent_id, school_id, distributed_at DESC);

CREATE INDEX IF NOT EXISTS idx_orders_agent_status
ON orders (agent_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_school_sales_agent_stage
ON school_sales (agent_id, sale_status, created_at DESC);

CREATE OR REPLACE VIEW v_agent_sample_roi AS
WITH sample_stats AS (
  SELECT
    d.agent_id,
    COALESCE(SUM(d.quantity), 0)::int AS samples_given,
    COUNT(DISTINCT d.school_id)::int AS schools_reached
  FROM school_sample_distributions d
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
  FROM orders o
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
  FROM school_sales s
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
FROM users u
LEFT JOIN sample_stats ss ON ss.agent_id = u.id
LEFT JOIN revenue_stats rs ON rs.agent_id = u.id
LEFT JOIN won_stats ws ON ws.agent_id = u.id
WHERE u.role IN (4, 5);

-- END FILE: schema_updates.sql


-- =========================================================

-- BEGIN FILE: schema_updates_dedup.sql

-- =========================================================

-- Create a function to find potential duplicates across the entire schools table

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
  from schools s1
  join schools s2 on s1.id < s2.id
  where s1.phone = s2.phone 
     or lower(s1.name) = lower(s2.name);
end;
$$;

-- END FILE: schema_updates_dedup.sql


-- =========================================================

-- BEGIN FILE: schema_updates_lead_scoring.sql

-- =========================================================

-- Add lead_score column to schools
do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'lead_score') then
    alter table schools add column lead_score integer not null default 0;
  end if;
end $$;

-- Create lead scoring function

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

-- 


-- Backfill existing schools
update schools set updated_at = now();

-- END FILE: schema_updates_lead_scoring.sql


-- =========================================================

-- BEGIN FILE: schema_updates_onboarding_region.sql

-- =========================================================

-- Migration: role 1 region dashboard additions + role 5 onboarding field updates
-- Date: 2026-07-09

-- =============================================================================
-- 1. ROLE 5 ONBOARDING: Migrate existing Distributor records to Institution
-- =============================================================================
UPDATE schools
SET dealer_type = 'Institution'
WHERE lower(dealer_type) = 'distributor';

UPDATE schools
SET shop_category = 'Distributor'
WHERE lower(shop_category) = 'independent';

-- =============================================================================
-- 2. ROLE 5 ONBOARDING: Add new columns for expanded onboarding fields
-- =============================================================================
-- samples_to_be_returned: new Yes/No indicator for sample returns
ALTER TABLE schools
  ADD COLUMN IF NOT EXISTS samples_to_be_returned text;

-- learning_materials: multi-select stock for Bookshop / Institution (Course Books, ECD Books, Reference, Teacher Guides)
ALTER TABLE schools
  ADD COLUMN IF NOT EXISTS learning_materials jsonb DEFAULT '[]'::jsonb;

-- institution_category_other: free-text subcategory when partner_subtype = 'Others' for Institutions
ALTER TABLE schools
  ADD COLUMN IF NOT EXISTS institution_category_other text;

-- book_programs: expanded multi-select for School Book Program (Book List, Book Fund)
ALTER TABLE schools
  ADD COLUMN IF NOT EXISTS book_programs jsonb DEFAULT '[]'::jsonb;

-- =============================================================================
-- 3. ROLE 1 REGION SECTION: Index optimization for regional aggregation queries
-- =============================================================================
-- The new admin Regions page aggregates sales, visits, and schools by region.
-- It derives region from users.region or schools.county. Add composite indexes
-- to keep those queries fast as data grows.
CREATE INDEX IF NOT EXISTS idx_schools_county_captured_at
  ON schools (county, captured_at);

CREATE INDEX IF NOT EXISTS idx_school_visits_school_visited_at
  ON school_visits (school_id, visited_at);

CREATE INDEX IF NOT EXISTS idx_school_sales_school_created
  ON school_sales (school_id, created_at);

-- =============================================================================
-- 4. ROLE 5 ONBOARDING: Backfill / cleanup notes
-- =============================================================================
-- Reset free-text fields for fresh onboarding data shape
UPDATE schools
SET institution_category_other = NULL
WHERE dealer_type = 'Institution';

-- Ensure nullsafe for new columns on existing rows
UPDATE schools
SET samples_to_be_returned = NULL,
    learning_materials = '[]'::jsonb,
    book_programs = '[]'::jsonb
WHERE samples_to_be_returned IS NULL
   OR learning_materials IS NULL
   OR book_programs IS NULL;

-- END FILE: schema_updates_onboarding_region.sql


-- =========================================================

-- BEGIN FILE: schema_updates_phase3.sql

-- =========================================================

-- Create table for supervisor coaching notes
CREATE TABLE IF NOT EXISTS supervisor_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supervisor_id UUID NOT NULL REFERENCES users(id),
    user_id UUID NOT NULL REFERENCES users(id),
    region TEXT,
    context_type TEXT, -- e.g., 'task', 'route', 'general'
    context_id UUID,
    note TEXT NOT NULL,
    follow_up_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on supervisor_notes
ALTER TABLE supervisor_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "supervisors_can_manage_notes" ON supervisor_notes;
CREATE POLICY "supervisors_can_manage_notes"
ON supervisor_notes
FOR ALL
TO authenticated
USING (supervisor_id = auth.uid() OR is_manager_or_admin())
WITH CHECK (supervisor_id = auth.uid() OR is_manager_or_admin());

-- Create a view for Role 5 Performance Scorecard
-- (This aggregates data to make the UI queries faster and simpler)
CREATE OR REPLACE VIEW role5_performance_scorecard AS
SELECT 
    u.id AS user_id,
    u.full_name,
    u.region,
    COUNT(DISTINCT t.id) AS total_tasks,
    COUNT(DISTINCT CASE WHEN t.status = 'closed' THEN t.id END) AS completed_tasks,
    COUNT(DISTINCT r.id) AS total_routes,
    COUNT(DISTINCT CASE WHEN r.status = 'completed' THEN r.id END) AS completed_routes,
    COUNT(DISTINCT sv.id) AS total_visits
FROM users u
LEFT JOIN tasks t ON t.assigned_to = u.id AND t.created_at >= NOW() - INTERVAL '30 days'
LEFT JOIN route_plans r ON r.assigned_to = u.id AND r.created_at >= NOW() - INTERVAL '30 days'
LEFT JOIN school_visits sv ON sv.agent_id = u.id AND sv.visited_at >= NOW() - INTERVAL '30 days'
WHERE u.role = 5
GROUP BY u.id, u.full_name, u.region;

-- END FILE: schema_updates_phase3.sql


-- =========================================================

-- BEGIN FILE: schema_updates_project_forms.sql

-- =========================================================

-- Project forms persistence for Admin publish -> Role 5 quick actions

create table if not exists project_forms (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  questions jsonb not null default '[]'::jsonb,
  assigned_user_ids uuid[] not null default '{}',
  published_at timestamptz not null default now(),
  created_by uuid references users (id) on delete set null,
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
    alter table project_forms
      add column assigned_user_ids uuid[] not null default '{}';
  end if;
end $$;

create index if not exists idx_project_forms_published_at
  on project_forms (published_at desc);

alter table project_forms enable row level security;

drop policy if exists "authenticated_can_view_project_forms" on project_forms;
DROP POLICY IF EXISTS "authenticated_can_view_project_forms" ON project_forms;
create policy "authenticated_can_view_project_forms"
on project_forms
for select
to authenticated
using (
  is_manager_or_admin()
  or auth.uid() = any (assigned_user_ids)
);

drop policy if exists "managers_can_publish_project_forms" on project_forms;
DROP POLICY IF EXISTS "managers_can_publish_project_forms" ON project_forms;
create policy "managers_can_publish_project_forms"
on project_forms
for insert
to authenticated
with check (is_manager_or_admin());

create table if not exists project_form_responses (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references project_forms (id) on delete cascade,
  form_title text not null,
  respondent_id uuid not null references users (id) on delete cascade,
  answers jsonb not null default '{}'::jsonb,
  submitted_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_project_form_responses_form_title
  on project_form_responses (form_title);

create index if not exists idx_project_form_responses_submitted_at
  on project_form_responses (submitted_at desc);

alter table project_form_responses enable row level security;

drop policy if exists "assigned_users_can_submit_project_form_responses" on project_form_responses;
DROP POLICY IF EXISTS "assigned_users_can_submit_project_form_responses" ON project_form_responses;
create policy "assigned_users_can_submit_project_form_responses"
on project_form_responses
for insert
to authenticated
with check (
  exists (
    select 1
    from project_forms f
    where f.id = project_form_responses.form_id
      and (
        auth.uid() = any (f.assigned_user_ids)
        or coalesce(array_length(f.assigned_user_ids, 1), 0) = 0
        or is_manager_or_admin()
      )
  )
  and respondent_id = auth.uid()
);

drop policy if exists "managers_can_view_project_form_responses" on project_form_responses;
DROP POLICY IF EXISTS "managers_can_view_project_form_responses" ON project_form_responses;
create policy "managers_can_view_project_form_responses"
on project_form_responses
for select
to authenticated
using (is_manager_or_admin());

drop policy if exists "respondents_can_view_their_project_form_responses" on project_form_responses;
DROP POLICY IF EXISTS "respondents_can_view_their_project_form_responses" ON project_form_responses;
create policy "respondents_can_view_their_project_form_responses"
on project_form_responses
for select
to authenticated
using (respondent_id = auth.uid());

-- Dummy data for testing (safe to re-run)
-- Assumes seeded users exist:
-- admin:   11111111-1111-1111-1111-111111111111
-- role 5:  bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb

insert into project_forms (
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

insert into project_form_responses (
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

-- END FILE: schema_updates_project_forms.sql


-- =========================================================

-- BEGIN FILE: schema_updates_sample_proof.sql

-- =========================================================

-- Add stamped sample proof fields on schools
begin;

alter table schools
  add column if not exists sample_proof_url text;

alter table schools
  add column if not exists sample_proof_path text;

commit;

-- END FILE: schema_updates_sample_proof.sql


-- =========================================================

-- BEGIN FILE: schema_updates_sample_trigger.sql

-- =========================================================

-- schema_updates_sample_trigger.sql
-- Placeholder migration file. Intentionally empty.
-- (Sample-distribution trigger logic lives in schema.sql / other migrations.)

-- END FILE: schema_updates_sample_trigger.sql


-- =========================================================

-- BEGIN FILE: schema_updates_tasks_pipeline.sql

-- =========================================================

-- Task + pipeline SQL updates for dashboard filtering and consistency

begin;

-- 1) Normalize task statuses before adding constraint
update tasks
set status = 'closed'
where lower(status) in ('complete', 'completed', 'done');

update tasks
set status = 'in_progress'
where lower(status) in ('in progress', 'progress');

update tasks
set status = 'open'
where lower(status) not in ('open', 'in_progress', 'closed');

-- 2) Enforce allowed task statuses
alter table tasks
  drop constraint if exists tasks_status_check;

alter table tasks
  add constraint tasks_status_check
  check (status in ('open', 'in_progress', 'closed'));

-- 3) Helpful indexes for admin dashboard filters
create index if not exists idx_tasks_status_due_at
  on tasks (status, due_at);

create index if not exists idx_tasks_target_role_status
  on tasks (target_role, status);

create index if not exists idx_school_sales_stage_updated_at
  on school_sales (sale_status, stage_updated_at desc);

commit;

-- END FILE: schema_updates_tasks_pipeline.sql


-- =========================================================

-- BEGIN FILE: seed.sql

-- =========================================================

-- ==========================================
-- Dummy Data Seed Script for Dehus App
-- Run this in your Supabase SQL Editor
-- ==========================================

-- 1. Insert Dummy Schools
INSERT INTO schools (
  id,
  name,
  phone,
  county,
  "focusAreas",
  book_category,
  latitude,
  longitude,
  photo_url,
  photo_path,
  capture_status,
  captured_by,
  captured_at,
  "isSynced"
)
VALUES 
  ('22222222-2222-2222-2222-222222222222', 'Nairobi Primary School', '0712345678', 'Nairobi', '["Mathematics", "Science"]'::jsonb, 'Book List', -1.2921, 36.8219, 'https://images.unsplash.com/photo-1503676260728-1c00da094a0b', 'schools/nairobi-primary.jpg', 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '1 day', true),
  ('33333333-3333-3333-3333-333333333333', 'Mombasa High School', '0723456789', 'Mombasa', '["Languages", "Arts"]'::jsonb, 'Book Fund', -4.0435, 39.6682, 'https://images.unsplash.com/photo-1523050854058-8df90110c9f1', 'schools/mombasa-high.jpg', 'Photo captured successfully', '11111111-1111-1111-1111-111111111111', now() - interval '1 day', true),
  ('44444444-4444-4444-4444-444444444444', 'Kisumu Boys', '0734567890', 'Kisumu', '["Sports", "Science"]'::jsonb, NULL, -0.1022, 34.7617, NULL, NULL, 'Location not captured yet', '11111111-1111-1111-1111-111111111111', now() - interval '1 day', true),
  ('55555555-5555-5555-5555-555555555555', 'Nakuru Girls', '0745678901', 'Nakuru', '["Mathematics", "Business"]'::jsonb, 'Book List', -0.3031, 36.0800, 'https://images.unsplash.com/photo-1497486751825-1233686d5d80', 'schools/nakuru-girls.jpg', 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '1 day', true),
  ('66666666-6666-6666-6666-666666666666', 'Eldoret Academy', '0756789012', 'Uasin Gishu', '["Agriculture", "Science"]'::jsonb, NULL, 0.5143, 35.2698, NULL, NULL, 'Photo captured successfully', '11111111-1111-1111-1111-111111111111', now() - interval '1 day', true)
ON CONFLICT (id) DO UPDATE
SET name = excluded.name,
    phone = excluded.phone,
    county = excluded.county,
    "focusAreas" = excluded."focusAreas",
    book_category = excluded.book_category,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    photo_url = excluded.photo_url,
    photo_path = excluded.photo_path,
    capture_status = excluded.capture_status,
    captured_by = excluded.captured_by,
    captured_at = excluded.captured_at,
    "isSynced" = excluded."isSynced";

-- 1b. Extra geocoded schools for stronger map coverage
-- Coordinates are seeded as ready-to-pin values.
INSERT INTO schools (
  id,
  name,
  phone,
  county,
  "focusAreas",
  book_category,
  latitude,
  longitude,
  capture_status,
  captured_by,
  captured_at,
  "isSynced"
)
VALUES
  ('a1000000-0000-0000-0000-000000000001', 'Westlands Academy', '0701000001', 'Nairobi', '["Mathematics","Languages"]'::jsonb, 'Book List', -1.2676, 36.8108, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000002', 'Thika Road School', '0701000002', 'Kiambu', '["Science","ICT"]'::jsonb, 'Book Fund', -1.2037, 36.8931, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000003', 'Machakos Township School', '0701000003', 'Machakos', '["Business","Mathematics"]'::jsonb, 'Book List', -1.5177, 37.2634, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000004', 'Kajiado Central School', '0701000004', 'Kajiado', '["Languages","Arts"]'::jsonb, 'Book Fund', -1.8521, 36.7768, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000005', 'Meru Greenhill School', '0701000005', 'Meru', '["Science","Agriculture"]'::jsonb, 'Book List', 0.0463, 37.6559, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000006', 'Kakamega East School', '0701000006', 'Kakamega', '["Mathematics","Science"]'::jsonb, 'Book Fund', 0.2827, 34.7519, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000007', 'Kisii Hills School', '0701000007', 'Kisii', '["Languages","Business"]'::jsonb, 'Book List', -0.6773, 34.7796, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000008', 'Nyeri Highlands Academy', '0701000008', 'Nyeri', '["Science","ICT"]'::jsonb, 'Book Fund', -0.4201, 36.9476, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000009', 'Kericho Springs School', '0701000009', 'Kericho', '["Agriculture","Mathematics"]'::jsonb, 'Book List', -0.3687, 35.2831, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000010', 'Bungoma Ridge School', '0701000010', 'Bungoma', '["Science","Sports"]'::jsonb, 'Book Fund', 0.5635, 34.5606, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000011', 'Garissa Model School', '0701000011', 'Garissa', '["Languages","Mathematics"]'::jsonb, 'Book List', -0.4532, 39.6401, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000012', 'Malindi Coast Academy', '0701000012', 'Kilifi', '["Arts","Languages"]'::jsonb, 'Book Fund', -3.2175, 40.1169, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true)
ON CONFLICT (id) DO UPDATE
SET name = excluded.name,
    phone = excluded.phone,
    county = excluded.county,
    "focusAreas" = excluded."focusAreas",
    book_category = excluded.book_category,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    capture_status = excluded.capture_status,
    captured_by = excluded.captured_by,
    captured_at = excluded.captured_at,
    "isSynced" = excluded."isSynced";

-- 2. Insert Dummy Tasks
-- Note: We assign these to roles (e.g., target_role = 2, 3, or 4) so they show up for everyone in those roles
INSERT INTO tasks (title, description, target_role, status, due_at, "isSynced")
VALUES
  ('Follow up with Nairobi Primary', 'Discuss the new curriculum books.', 2, 'open', now() + interval '2 days', true),
  ('Deliver supplies to Mombasa High', 'Ensure all requested materials are delivered.', 3, 'open', now() + interval '5 days', true),
  ('Check in on Kisumu Boys', 'Monthly routine check-in.', 3, 'in_progress', now() + interval '1 day', true),
  ('Nakuru Girls Evaluation', 'Evaluate the newly introduced testing methods.', 2, 'open', now() + interval '7 days', true),
  ('Eldoret Academy Proposal', 'Present the new business proposal to the principal.', 3, 'closed', now() - interval '1 day', true),
  ('Quarterly Regional Review', 'Review quarterly numbers for all coastal schools.', 2, 'open', now() + interval '14 days', true);

-- 3. Insert Dummy Geofences
-- Coordinates are stored as a JSONB array of objects matching your flutter map data structure
INSERT INTO geofences (name, description, region, coordinates)
VALUES
  ('Nairobi CBD Zone', 'Cover all schools within the central business district.', 'Nairobi', '[{"lat": -1.286389, "lng": 36.817223, "radius": 2000}]'::jsonb),
  ('Mombasa Island Area', 'Target coastal schools.', 'Mombasa', '[{"lat": -4.043477, "lng": 39.668206, "radius": 3500}]'::jsonb),
  ('Kisumu Lakefront', 'Schools near the lake area.', 'Kisumu', '[{"lat": -0.102210, "lng": 34.761713, "radius": 1500}]'::jsonb),
  ('Nakuru Town Center', 'Coverage area for central Nakuru.', 'Nakuru', '[{"lat": -0.303099, "lng": 36.080025, "radius": 2500}]'::jsonb);

-- ==========================================
-- 4. Insert Dummy Users with Different Roles
-- ==========================================
-- We insert directly into Supabase's auth.users table so they can actually log in.
-- Your database triggers will automatically map them into the users table.
--
-- All generated users use the password: password123
-- Add "region" to raw_user_meta_data if you want the trigger to populate users.region.

INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'alice.manager@example.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name": "Alice Manager", "role": 2, "region": "Nairobi"}', now(), now()),
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'bob.bas@example.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name": "Bob BAS", "role": 3, "region": "Coast"}', now(), now()),
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'charlie.agent@example.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name": "Charlie Agent", "role": 4, "region": "Rift Valley"}', now(), now()),
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'diana.sales@example.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name": "Diana Sales", "role": 2, "region": "Western"}', now(), now()),
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'edward.other@example.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name": "Edward Grounds", "role": 5, "region": "Nyanza"}', now(), now())
ON CONFLICT DO NOTHING;

-- 4b. Dedicated field-agent workload data
-- Fixed UUID keeps the agent-linked tasks and geofence references stable across reruns.
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'faith.agent@example.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name": "Faith Agent", "role": 4, "region": "Nairobi"}', now(), now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO tasks (title, description, target_role, assigned_to, status, due_at, "isSynced")
VALUES
  ('Visit Nairobi Primary School', 'Confirm the current book list and capture the headteacher feedback.', 4, '11111111-1111-1111-1111-111111111111', 'open', now() + interval '1 day', true),
  ('Follow up with Makueni High School', 'Call the school and confirm the book fund decision.', 4, '11111111-1111-1111-1111-111111111111', 'open', now() + interval '2 days', true),
  ('Sell book fund package to Bora Education Centre', 'Present the offer and record the response.', 4, '11111111-1111-1111-1111-111111111111', 'in_progress', now() + interval '3 days', true),
  ('Check sample delivery for Green Pastures Academy', 'Make sure sample books were received and logged.', 4, '11111111-1111-1111-1111-111111111111', 'open', now() + interval '4 days', true);

INSERT INTO geofences (name, description, region, coordinates, assigned_to)
VALUES
  ('Nairobi Field Agent Zone', 'Primary school coverage for the Nairobi field agent.', 'Nairobi', '[{"lat": -1.2921, "lng": 36.8219, "radius": 4000}]'::jsonb, '11111111-1111-1111-1111-111111111111'),
  ('Kiambu Visit Corridor', 'Support schools along the Kiambu route.', 'Kiambu', '[{"lat": -1.1714, "lng": 36.8356, "radius": 2500}]'::jsonb, '11111111-1111-1111-1111-111111111111');

INSERT INTO route_plans (
  id,
  title,
  route_date,
  assigned_to,
  school_ids,
  notes,
  status,
  created_by,
  "isSynced"
)
VALUES
  (
    '77777777-7777-7777-7777-777777777777',
    'Faith Agent Route Plan',
    current_date,
    '11111111-1111-1111-1111-111111111111',
    '["22222222-2222-2222-2222-222222222222", "33333333-3333-3333-3333-333333333333", "55555555-5555-5555-5555-555555555555"]'::jsonb,
    'Morning route covering Nairobi Primary, Mombasa High and Nakuru Girls.',
    'assigned',
    '11111111-1111-1111-1111-111111111111',
    true
  ),
  (
    '88888888-8888-8888-8888-888888888888',
    'BAS Coastal Route Plan',
    current_date + 1,
    '11111111-1111-1111-1111-111111111111',
    '["33333333-3333-3333-3333-333333333333", "44444444-4444-4444-4444-444444444444"]'::jsonb,
    'Follow-up route with Mombasa and Kisumu school visits.',
    'draft',
    '11111111-1111-1111-1111-111111111111',
    true
  )
ON CONFLICT (id) DO UPDATE
SET title = excluded.title,
    route_date = excluded.route_date,
    assigned_to = excluded.assigned_to,
    school_ids = excluded.school_ids,
    notes = excluded.notes,
    status = excluded.status,
    "isSynced" = excluded."isSynced";

INSERT INTO school_visits (
  school_id,
  agent_id,
  outcome,
  notes,
  photo_url,
  photo_path,
  latitude,
  longitude,
  visit_status,
  visited_at,
  "isSynced"
)
VALUES
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Principal interested in book list', 'Reviewed the English and Mathematics book list and captured follow-up needs.', 'https://images.unsplash.com/photo-1524178232363-1fb2b075b655', 'visits/nairobi-primary-2026-05-09.jpg', -1.292100, 36.821900, 'completed', now() - interval '1 day', true),
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Book fund discussed', 'The school requested a formal package presentation next week.', 'https://images.unsplash.com/photo-1504384308090-c894fdcc538d', 'visits/mombasa-high-2026-05-08.jpg', -4.043500, 39.668200, 'completed', now() - interval '3 days', true),
  ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'Sample delivery confirmed', 'Sample books delivered and logged by the librarian.', NULL, NULL, -0.303100, 36.080000, 'completed', now() - interval '5 days', true),
  ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Initial introduction visit', 'Met the deputy principal and left a price list for the book list package.', 'https://images.unsplash.com/photo-1488190211105-8b0e65b80b4e', 'visits/kisumu-boys-2026-05-06.jpg', -0.102200, 34.761700, 'completed', now() - interval '7 days', true),
  ('66666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', 'Follow-up visit on proposal', 'Reviewed the book fund quotation and answered questions about delivery timelines.', NULL, 'visits/eldoret-academy-2026-05-04.jpg', 0.514300, 35.269800, 'completed', now() - interval '9 days', true);

INSERT INTO school_follow_ups (
  school_id,
  agent_id,
  contact_person,
  next_step,
  due_at,
  notes,
  follow_up_status,
  completed_at,
  "isSynced"
)
VALUES
  ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Deputy Principal', 'Confirm book list choice and pricing.', now() + interval '2 days', 'Left the school with a brochure and sample request form.', 'open', NULL, true),
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Procurement Lead', 'Send book fund proposal via email.', now() + interval '1 day', 'Awaiting budget approval.', 'open', NULL, true),
  ('66666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', 'Head Teacher', 'Schedule a follow-up call after the staff meeting.', now() + interval '4 days', 'Initial visit was positive.', 'open', NULL, true),
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Head of Department', 'Confirm teacher sample feedback and next steps.', now() + interval '3 days', 'Waiting for the head teacher to approve the quote.', 'open', NULL, true),
  ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'Library Assistant', 'Check if the book list order can be placed this week.', now() + interval '5 days', 'The library team asked for a revised package summary.', 'open', NULL, true);

INSERT INTO school_sales (
  school_id,
  agent_id,
  package_name,
  expected_value,
  notes,
  sale_status,
  stage_contact_person,
  quotation_reference,
  decision_owner,
  closed_at,
  "isSynced"
)
VALUES
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Book Fund Starter Package', 15000.00, 'Proposal shared during visit; awaiting confirmation.', 'decision_pending', 'Procurement Chair', NULL, 'Principal', NULL, true),
  ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'Book List Bundle', 9800.00, 'Request received from the principal for a refined quote.', 'quotation_sent', 'Deputy Principal', 'QT-2026-0555', NULL, NULL, true),
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Core Reader Package', 7200.00, 'Sale agreed in principle, waiting on payment date.', 'won', 'HOD English', NULL, NULL, now() - interval '2 hours', true),
  ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Starter School Bundle', 5600.00, 'Quoted during the first school visit and shared with the department head.', 'contacted', 'Deputy Principal', NULL, NULL, NULL, true),
  ('66666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', 'Premium Book Fund Package', 22000.00, 'Proposal delivered after the follow-up meeting.', 'lead', NULL, NULL, NULL, NULL, true);

INSERT INTO school_sample_distributions (
  school_id,
  agent_id,
  sample_name,
  sample_category,
  quantity,
  notes,
  distributed_at,
  "isSynced"
)
VALUES
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Grade 1 Reader Pack', 'Primary', 2, 'Handed to the English panel lead.', now() - interval '1 day', true),
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Teacher Guide Kit', 'Reference', 1, 'Left with the procurement desk.', now() - interval '3 days', true),
  ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'Story Books Pack', 'Primary', 3, 'Sample set used for classroom demo.', now() - interval '5 days', true),
  ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Science Reader Sample', 'Secondary', 2, 'Used during the deputy principal demonstration.', now() - interval '7 days', true),
  ('66666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', 'Book Fund Overview Pack', 'Proposal', 1, 'Left with the head teacher after the presentation.', now() - interval '9 days', true);

-- 4c. Role 5 / grounds person demo data
-- This lets the same alerts view render with real assignments for role 5 users too.
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'grounds.role5@example.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name": "Grounds Role5", "role": 5, "region": "Nyanza"}', now(), now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO tasks (title, description, target_role, assigned_to, status, due_at, "isSynced")
VALUES
  ('Inspect Nyanza school route', 'Verify access roads and confirm the route timing for the day.', 5, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'open', now() + interval '1 day', true),
  ('Check delivery point at Kisumu Boys', 'Confirm the unloading area and school contact point.', 5, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'open', now() + interval '2 days', true);

INSERT INTO geofences (id, name, description, region, coordinates, assigned_to)
VALUES
  (
    '99999999-9999-9999-9999-999999999999',
    'Nyanza Grounds Coverage',
    'Coverage area for the role 5 demo user.',
    'Kisumu',
    '[{"lat": -0.102210, "lng": 34.761713, "radius": 3000}]'::jsonb,
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
  )
ON CONFLICT (id) DO UPDATE
SET name = excluded.name,
    description = excluded.description,
    region = excluded.region,
    coordinates = excluded.coordinates,
    assigned_to = excluded.assigned_to;

INSERT INTO route_plans (
  id,
  title,
  route_date,
  assigned_to,
  school_ids,
  notes,
  status,
  created_by,
  "isSynced"
)
VALUES
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Role 5 Daily Route',
    current_date,
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '["44444444-4444-4444-4444-444444444444", "55555555-5555-5555-5555-555555555555"]'::jsonb,
    'Grounds run covering Kisumu Boys and Nakuru Girls.',
    'assigned',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    true
  )
ON CONFLICT (id) DO UPDATE
SET title = excluded.title,
    route_date = excluded.route_date,
    assigned_to = excluded.assigned_to,
    school_ids = excluded.school_ids,
    notes = excluded.notes,
    status = excluded.status,
    "isSynced" = excluded."isSynced";

INSERT INTO school_visits (
  school_id,
  agent_id,
  outcome,
  notes,
  photo_url,
  photo_path,
  latitude,
  longitude,
  visit_status,
  visited_at,
  "isSynced"
)
VALUES
  (
    '44444444-4444-4444-4444-444444444444',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Route checked and marked safe',
    'Confirmed the road condition and left a message with the school contact.',
    NULL,
    'visits/kisumu-boys-route-check.jpg',
    -0.102200,
    34.761700,
    'completed',
    now() - interval '1 day',
    true
  );

-- Additional pipeline demo records for role-based viewing (roles 1, 2, and 5 dashboards)
INSERT INTO school_sales (
  school_id,
  agent_id,
  package_name,
  expected_value,
  notes,
  sale_status,
  stage_contact_person,
  sample_quantity,
  quotation_reference,
  decision_owner,
  negotiation_topic,
  loss_reason,
  dormant_reason,
  stage_updated_at,
  expected_close_date,
  probability,
  closed_at,
  "isSynced"
)
VALUES
  (
    '33333333-3333-3333-3333-333333333333',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'Upper Primary Bundle',
    18400.00,
    'Manager review requested after quotation submission.',
    'quotation_sent',
    'Board Secretary',
    NULL,
    'QT-2026-0333',
    NULL,
    NULL,
    NULL,
    NULL,
    now() - interval '4 days',
    (current_date + 14),
    65,
    NULL,
    true
  ),
  (
    '44444444-4444-4444-4444-444444444444',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'Secondary Exam Pack',
    26200.00,
    'Budget committee requested a final discount pass.',
    'negotiation',
    'Bursar',
    NULL,
    NULL,
    NULL,
    'Final unit price and delivery terms',
    NULL,
    NULL,
    now() - interval '2 days',
    (current_date + 10),
    85,
    NULL,
    true
  ),
  (
    '55555555-5555-5555-5555-555555555555',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Grounds Delivery Companion Kit',
    4200.00,
    'Reactivated after dormancy for a new term cycle.',
    'contacted',
    'Grounds Supervisor',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    now() - interval '1 day',
    (current_date + 20),
    20,
    NULL,
    true
  ),
  (
    '66666666-6666-6666-6666-666666666666',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Operations Support Bundle',
    3100.00,
    'No response after multiple follow-ups.',
    'dormant',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    'No school response for 30+ days',
    now() - interval '35 days',
    NULL,
    0,
    NULL,
    true
  ),
  (
    '22222222-2222-2222-2222-222222222222',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'Literacy Expansion Package',
    28900.00,
    'Order confirmed and handover planned.',
    'won',
    'Head Teacher',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    now() - interval '6 hours',
    current_date,
    100,
    now() - interval '6 hours',
    true
  ),
  (
    '33333333-3333-3333-3333-333333333333',
    '11111111-1111-1111-1111-111111111111',
    'Teacher Demo Samples Pack',
    6400.00,
    'Samples issued to panel for review.',
    'sample_issued',
    'English HOD',
    12,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    now() - interval '3 days',
    (current_date + 18),
    50,
    NULL,
    true
  ),
  (
    '44444444-4444-4444-4444-444444444444',
    '11111111-1111-1111-1111-111111111111',
    'Budget Saver Bundle',
    9300.00,
    'Opportunity closed after budget freeze.',
    'lost',
    'Deputy Principal',
    NULL,
    NULL,
    NULL,
    NULL,
    'Budget redirected to infrastructure repairs',
    NULL,
    now() - interval '20 days',
    NULL,
    0,
    NULL,
    true
  );

INSERT INTO school_follow_ups (
  school_id,
  agent_id,
  contact_person,
  next_step,
  due_at,
  notes,
  follow_up_status,
  completed_at,
  "isSynced"
)
VALUES
  (
    '55555555-5555-5555-5555-555555555555',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Grounds Supervisor',
    'Confirm the school gate opening time.',
    now() + interval '2 days',
    'Follow-up needed before the delivery truck leaves.',
    'open',
    NULL,
    true
  );

INSERT INTO school_sales (
  school_id,
  agent_id,
  package_name,
  expected_value,
  notes,
  sale_status,
  closed_at,
  "isSynced"
)
VALUES
  (
    '44444444-4444-4444-4444-444444444444',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Grounds Support Log',
    1500.00,
    'Logged the route support cost for the day.',
    'lead',
    NULL,
    true
  );

-- Pipeline history demo records for timeline view
INSERT INTO pipeline_history (
  pipeline_id,
  old_stage,
  new_stage,
  changed_by,
  changed_at,
  notes
)
SELECT
  s.id,
  NULL,
  'contacted',
  s.agent_id,
  now() - interval '10 days',
  'Initial outreach completed with procurement office.'
FROM school_sales s
WHERE s.package_name = 'Upper Primary Bundle'
LIMIT 1;

INSERT INTO pipeline_history (
  pipeline_id,
  old_stage,
  new_stage,
  changed_by,
  changed_at,
  notes
)
SELECT
  s.id,
  'contacted',
  'meeting_scheduled',
  s.agent_id,
  now() - interval '8 days',
  'School requested a formal meeting with board secretary.'
FROM school_sales s
WHERE s.package_name = 'Upper Primary Bundle'
LIMIT 1;

INSERT INTO pipeline_history (
  pipeline_id,
  old_stage,
  new_stage,
  changed_by,
  changed_at,
  notes
)
SELECT
  s.id,
  'meeting_scheduled',
  'quotation_sent',
  s.agent_id,
  now() - interval '4 days',
  'Quotation QT-2026-0333 submitted by email and hard copy.'
FROM school_sales s
WHERE s.package_name = 'Upper Primary Bundle'
LIMIT 1;

INSERT INTO pipeline_history (
  pipeline_id,
  old_stage,
  new_stage,
  changed_by,
  changed_at,
  notes
)
SELECT
  s.id,
  NULL,
  'quotation_sent',
  s.agent_id,
  now() - interval '6 days',
  'Initial quote delivered after sample feedback.'
FROM school_sales s
WHERE s.package_name = 'Book List Bundle'
LIMIT 1;

INSERT INTO pipeline_history (
  pipeline_id,
  old_stage,
  new_stage,
  changed_by,
  changed_at,
  notes
)
SELECT
  s.id,
  'quotation_sent',
  'decision_pending',
  s.agent_id,
  now() - interval '3 days',
  'Moved to decision pending awaiting principal sign-off.'
FROM school_sales s
WHERE s.package_name = 'Book Fund Starter Package'
LIMIT 1;

INSERT INTO pipeline_history (
  pipeline_id,
  old_stage,
  new_stage,
  changed_by,
  changed_at,
  notes
)
SELECT
  s.id,
  'decision_pending',
  'won',
  s.agent_id,
  now() - interval '6 hours',
  'Order approved and ready for checkout.'
FROM school_sales s
WHERE s.package_name = 'Literacy Expansion Package'
LIMIT 1;

INSERT INTO pipeline_history (
  pipeline_id,
  old_stage,
  new_stage,
  changed_by,
  changed_at,
  notes
)
SELECT
  s.id,
  'contacted',
  'lost',
  s.agent_id,
  now() - interval '20 days',
  'Budget redirected to infrastructure, deal closed lost.'
FROM school_sales s
WHERE s.package_name = 'Budget Saver Bundle'
LIMIT 1;

INSERT INTO pipeline_history (
  pipeline_id,
  old_stage,
  new_stage,
  changed_by,
  changed_at,
  notes
)
SELECT
  s.id,
  'contacted',
  'dormant',
  s.agent_id,
  now() - interval '35 days',
  'No response after repeated follow-ups.'
FROM school_sales s
WHERE s.package_name = 'Operations Support Bundle'
LIMIT 1;

INSERT INTO school_sample_distributions (
  school_id,
  agent_id,
  sample_name,
  sample_category,
  quantity,
  notes,
  distributed_at,
  "isSynced"
)
VALUES
  (
    '55555555-5555-5555-5555-555555555555',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Delivery Check Sheet',
    'Operations',
    1,
    'Left with the school office for confirmation.',
    now() - interval '2 days',
    true
);


INSERT INTO order_items (
  id,
  order_id,
  product_name,
  category,
  sku,
  quantity,
  unit_price,
  line_total,
  notes
)
VALUES
  (
    'ddddddd1-dddd-dddd-dddd-dddddddddddd',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'Grade 1 Reader Pack',
    'Primary',
    'SET-PR-01',
    2,
    2850.00,
    5700.00,
    'Included in the school visit order.'
  ),
  (
    'ddddddd2-dddd-dddd-dddd-dddddddddddd',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'Teacher Guide Kit',
    'Reference',
    'SET-RF-03',
    1,
    2700.00,
    2700.00,
    'Support material for the head teacher.'
  ),
  (
    'd1111112-d111-d111-d111-d11111111111',
    'd1111111-d111-d111-d111-d11111111111',
    'High School Biology Form 1',
    'Secondary',
    'SL-SEC-01',
    10,
    1200.00,
    12000.00,
    'Form 1 Biology Class Set'
  ),
  (
    'd1111113-d111-d111-d111-d11111111111',
    'd1111111-d111-d111-d111-d11111111111',
    'High School Chemistry Form 1',
    'Secondary',
    'SL-SEC-02',
    10,
    1250.00,
    12500.00,
    'Form 1 Chemistry Class Set'
  ),
  (
    'eeeeeee1-eeee-eeee-eeee-eeeeeeeeeeee',
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    'Delivery Check Sheet',
    'Operations',
    'CUSTOM',
    1,
    1500.00,
    1500.00,
    'Grounds support order.'
  )
ON CONFLICT (id) DO UPDATE
SET
  order_id = excluded.order_id,
  product_name = excluded.product_name,
  category = excluded.category,
  sku = excluded.sku,
  quantity = excluded.quantity,
  unit_price = excluded.unit_price,
  line_total = excluded.line_total,
  notes = excluded.notes;

INSERT INTO messages (
  id,
  sender_id,
  recipient_id,
  subject,
  body,
  related_school_id,
  related_task_id,
  is_read
)
VALUES
  (
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '11111111-1111-1111-1111-111111111111',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Route plan ready',
    'Your route plan for today is ready. Please check the route list and geofence coverage before departure.',
    '44444444-4444-4444-4444-444444444444',
    NULL,
    false
  ),
  (
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '11111111-1111-1111-1111-111111111111',
    'Route check complete',
    'I have confirmed the Kisumu Boys stop and the gate access point. The area is safe for the delivery team.',
    '44444444-4444-4444-4444-444444444444',
    NULL,
    true
  ),
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    '11111111-1111-1111-1111-111111111111',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Follow up reminder',
    'Please remember to update me after the Nakuru Girls stop with the school feedback.',
    '55555555-5555-5555-5555-555555555555',
    NULL,
    false
  )
ON CONFLICT (id) DO UPDATE
SET sender_id = excluded.sender_id,
    recipient_id = excluded.recipient_id,
    subject = excluded.subject,
    body = excluded.body,
    related_school_id = excluded.related_school_id,
    related_task_id = excluded.related_task_id,
    is_read = excluded.is_read;

UPDATE schools
SET
  captured_by = '11111111-1111-1111-1111-111111111111',
  captured_at = now() - interval '1 day',
  capture_status = coalesce(capture_status, 'GPS updated successfully')
WHERE id IN (
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333',
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555',
  '66666666-6666-6666-6666-666666666666'
);

-- (Optional Failsafe) 
-- If your trigger does not automatically map the 'role' and 'full_name' 
-- from auth.users over to the users table, run this update manually:
UPDATE users 
SET full_name = auth.users.raw_user_meta_data->>'full_name',
    role = (auth.users.raw_user_meta_data->>'role')::int,
    region = auth.users.raw_user_meta_data->>'region'
FROM auth.users 
WHERE users.id = auth.users.id AND users.full_name IS NULL;

-- ==========================================
-- 4d. Role 2 / Sales Manager Demo Data
-- ==========================================

INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES
  ('22222222-aaaa-aaaa-aaaa-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'manager.role2@example.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name": "Demo Sales Manager", "role": 2, "region": "Nairobi"}', now(), now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO tasks (title, description, target_role, assigned_to, status, due_at, "isSynced")
VALUES
  ('Approve pending field orders', 'Review and approve all pending orders submitted by agents this week.', 2, '22222222-aaaa-aaaa-aaaa-222222222222', 'open', now() + interval '1 day', true),
  ('Review Nairobi route plans', 'Ensure all Nairobi schools have assigned agents for the upcoming week.', 2, '22222222-aaaa-aaaa-aaaa-222222222222', 'open', now() + interval '2 days', true);

-- Add an extra pending order for the manager to approve
INSERT INTO orders (
  id, school_id, school_name, school_phone, agent_id, order_number, payment_method, payment_reference, checkout_amount, status, notes, submitted_at, approved_at, "isSynced"
)
VALUES
  (
    'f0000000-f000-f000-f000-f00000000000',
    '33333333-3333-3333-3333-333333333333',
    'Mombasa High School',
    '0723456789',
    '11111111-1111-1111-1111-111111111111',
    'ORD-20260510-FAITH-002',
    'bank_transfer',
    'BANK-REF-9999',
    12500.00,
    'pending',
    'Large book fund order, pending manager approval.',
    now() - interval '2 hours',
    NULL,
    true
  )
ON CONFLICT (id) DO UPDATE
SET status = excluded.status,
    "isSynced" = excluded."isSynced";

-- Add a message to the manager
INSERT INTO messages (
  id, sender_id, recipient_id, subject, body, related_school_id, is_read, "isSynced"
)
VALUES
  (
    'f1111111-f111-f111-f111-f11111111111',
    '11111111-1111-1111-1111-111111111111',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'Order Approval Request',
    'Hi Manager, I have submitted a large order for Mombasa High School. Please review and approve the bank slip when possible.',
    '33333333-3333-3333-3333-333333333333',
    false,
    true
  )
ON CONFLICT (id) DO NOTHING;

-- Distribute some of the new dummy sample books
INSERT INTO school_sample_distributions (
  school_id, agent_id, sample_name, sample_category, quantity, notes, distributed_at, "isSynced"
)
VALUES
  (
    '55555555-5555-5555-5555-555555555555', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Secondary Science Sample Pack', 'Secondary', 1, 'Dropped off by Grounds Personnel alongside the main delivery.', now() - interval '2 hours', true
  )
ON CONFLICT DO NOTHING;


-- After running this script:
-- Refresh your Admin Dashboard screen in the app.
-- You should now see 10 Tasks and 6 Geofences listed in the counters!
-- Your Agent Tracker and Assign Task dropdowns will now have 6 users in them!


-- ==========================================
-- 5. Additional Mock Data for Geofence Polygons & Filterable Tasks
-- ==========================================

-- Insert proper Polygon geofences (requires >= 3 points to render a shape on the map)
INSERT INTO geofences (id, name, description, region, coordinates, assigned_to)
VALUES
  (gen_random_uuid(), 'Nairobi South Polygon', 'Detailed polygon mapping for southern Nairobi.', 'Nairobi', '[{"lat": -1.30, "lng": 36.80}, {"lat": -1.30, "lng": 36.85}, {"lat": -1.35, "lng": 36.85}, {"lat": -1.35, "lng": 36.80}]'::jsonb, '11111111-1111-1111-1111-111111111111'),
  (gen_random_uuid(), 'Mombasa North Coast', 'Polygon for northern coastal region coverage.', 'Mombasa', '[{"lat": -3.95, "lng": 39.70}, {"lat": -3.95, "lng": 39.75}, {"lat": -4.00, "lng": 39.75}, {"lat": -4.00, "lng": 39.70}]'::jsonb, '22222222-aaaa-aaaa-aaaa-222222222222'),
  (gen_random_uuid(), 'Kisumu Central Grid', 'Triangular grid for Kisumu central field operations.', 'Kisumu', '[{"lat": -0.09, "lng": 34.75}, {"lat": -0.09, "lng": 34.77}, {"lat": -0.11, "lng": 34.76}]'::jsonb, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');

-- Insert dummy tasks designed to test the Daily, Weekly, and Monthly dashboard filters
INSERT INTO tasks (title, description, target_role, assigned_to, status, due_at, "isSynced")
VALUES
  -- Faith Agent (Role 4)
  ('Daily: Submit EOD Report', 'Submit end-of-day sales report for Nairobi schools.', 4, '11111111-1111-1111-1111-111111111111', 'open', now(), true),
  ('Weekly: Restock Samples', 'Pick up new sample books from the regional warehouse.', 4, '11111111-1111-1111-1111-111111111111', 'open', now() + interval '3 days', true),
  ('Monthly: School Inventory Check', 'Perform a full inventory check of sample distributions for the month.', 4, '11111111-1111-1111-1111-111111111111', 'open', now() + interval '20 days', true),
  
  -- Sales Manager (Role 2)
  ('Daily: Morning Briefing', 'Quick sync with the sales team to review yesterday''s figures.', 2, '22222222-aaaa-aaaa-aaaa-222222222222', 'closed', now(), true),
  ('Monthly: Pipeline Review', 'Review all pipeline sales for the month and close out drafts.', 2, '22222222-aaaa-aaaa-aaaa-222222222222', 'in_progress', now() + interval '14 days', true),

  -- Grounds Person (Role 5)
  ('Daily: Inspect Vehicle', 'Perform daily routine check on delivery vehicle.', 5, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'open', now(), true),
  ('Weekly: Service Route Validation', 'Validate newly added schools on the route map.', 5, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'open', now() + interval '4 days', true),
  ('Monthly: Log Book Audit', 'Submit the monthly physical log book for audit.', 5, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'open', now() + interval '25 days', true);

-- ==========================================
-- 6. Role 3 Supervision Demo Data
-- ==========================================
INSERT INTO supervisor_alerts (user_id, region, alert_type, severity, status, message, acked_at, resolved_at, ack_sla_met, resolve_sla_met, escalated_to_admin)
VALUES
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Kisumu', 'missed_checkin', 'red', 'open', 'Grounds user missed first check-in.', null, null, false, false, false),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Kisumu', 'late_start', 'amber', 'resolved', 'Route start was delayed by 40 minutes.', now() - interval '5 hours', now() - interval '3 hours', true, true, false)
ON CONFLICT DO NOTHING;

INSERT INTO geofence_events (user_id, geofence_id, event_type, region, lat, lng, reason, status, created_at)
VALUES
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '99999999-9999-9999-9999-999999999999', 'breach', 'Kisumu', -0.0981, 34.7742, 'Detour due to road closure', 'open', now() - interval '2 hours')
ON CONFLICT DO NOTHING;

INSERT INTO supervisor_incidents (user_id, region, incident_type, severity, status, notes, created_by)
VALUES
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Kisumu', 'boundary_breach', 'high', 'open', 'Repeated breach on western corridor.', '22222222-aaaa-aaaa-aaaa-222222222222')
ON CONFLICT DO NOTHING;

INSERT INTO supervisor_notes (supervisor_id, user_id, region, context_type, note, follow_up_at)
VALUES
  ('22222222-aaaa-aaaa-aaaa-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Kisumu', 'weekly_review', 'Improve first check-in discipline and submit route evidence by 9 AM.', now() + interval '7 days')
ON CONFLICT DO NOTHING;

INSERT INTO supervisor_notifications (
  supervisor_id, region, notification_type, title, body, payload, scheduled_for, sent_at
)
VALUES
  (
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'Nairobi',
    'daily_digest',
    'Morning Supervision Digest',
    'You have 2 open alerts and 3 overdue tasks in your region.',
    '{"open_alerts": 2, "overdue_tasks": 3}'::jsonb,
    now() - interval '2 hours',
    now() - interval '2 hours'
  ),
  (
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'Nairobi',
    'escalation',
    'Escalated Red Alert',
    'A red alert has remained unresolved beyond SLA.',
    '{"alert_type": "missed_checkin"}'::jsonb,
    now() - interval '30 minutes',
    now() - interval '30 minutes'
  )
ON CONFLICT DO NOTHING;

-- Dummy sample catalog items for onboarding/sample pages

-- Limited to 70 catalog items as requested
INSERT INTO catalog_items (id, name, category, sku, item_type, unit_price, stock_qty, description, is_active, created_by, "isSynced") VALUES
('ad6a61ec-427d-4ec3-84a9-f229979cf473', 'Language Activities LB', 'Pre-Primary', '9879966645180', 'sale', 715.01, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('ae529b24-787b-4e2f-b472-85a760c5a086', 'Language Activities LB (Sample)', 'Pre-Primary', 'SMPL-9879966645180', 'sample', 715.01, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('db8f2153-7d4c-4a55-9a09-f29f3a587832', 'Environmental Activities LB', 'Pre-Primary', '9879966645203', 'sale', 627.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('681789a2-7c01-4d2a-bf64-53a06b0aa8b4', 'Environmental Activities LB (Sample)', 'Pre-Primary', 'SMPL-9879966645203', 'sample', 627.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('85f599f8-e44a-4529-aeff-62350c4f96ef', 'Mathematics Activities LB', 'Pre-Primary', '9879966645227', 'sale', 682.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('1d7bf13b-3da6-4073-8e26-e284d8f4da1b', 'Mathematics Activities LB (Sample)', 'Pre-Primary', 'SMPL-9879966645227', 'sample', 682.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('926fc7dc-2394-4213-a3ff-e489836aa658', 'Creative Activities LB', 'Pre-Primary', '9789966645241', 'sale', 643.5, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('50c3ea63-c578-421a-925a-280e7a4702c8', 'Creative Activities LB (Sample)', 'Pre-Primary', 'SMPL-9789966645241', 'sample', 643.5, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('933efcc3-7385-4e0a-a13a-cc9dc4efedf1', 'Christian Religious Education Activities LB', 'Pre-Primary', '9789966645265', 'sale', 682.01, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('72f23288-bdfd-4902-8548-d72dc11884dc', 'Christian Religious Education Activities LB (Sample)', 'Pre-Primary', 'SMPL-9789966645265', 'sample', 682.01, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('6471444d-f190-4ad6-869e-97f01328976c', 'Language Activities TG', 'Pre-Primary', '9789966645197', 'sale', 825.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('fcb4e0ce-07db-448f-b1c3-5bef7c75cd58', 'Language Activities TG (Sample)', 'Pre-Primary', 'SMPL-9789966645197', 'sample', 825.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('a06beaf0-0f23-46b9-977e-378feb83290c', 'Environmental Activities TG', 'Pre-Primary', '9789966645210', 'sale', 825.01, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('d1598551-b4d5-4d4b-aacf-633b0ac99c8e', 'Environmental Activities TG (Sample)', 'Pre-Primary', 'SMPL-9789966645210', 'sample', 825.01, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('c6099e52-4d42-4f4a-b6c2-06419a974b42', 'Mathematics Activities TG', 'Pre-Primary', '9789966645234', 'sale', 774.35, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('6fe1f6d9-2d8b-4fe7-bfaa-0157b6ede689', 'Mathematics Activities TG (Sample)', 'Pre-Primary', 'SMPL-9789966645234', 'sample', 774.35, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('f8227578-f8d0-4bd8-a7c3-1a6d787d8801', 'Creative Activities TG', 'Pre-Primary', '9789966645258', 'sale', 730.38, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('d1ee9936-888b-494c-88fe-b262250c4c10', 'Creative Activities TG (Sample)', 'Pre-Primary', 'SMPL-9789966645258', 'sample', 730.38, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('4d8d7948-4e92-4b89-af11-0a4a4643fb32', 'Christian Religious Education Activities TG', 'Pre-Primary', '9789966645272', 'sale', 697.7, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('5d38e05c-0c88-4467-a360-991a73e812d4', 'Christian Religious Education Activities TG (Sample)', 'Pre-Primary', 'SMPL-9789966645272', 'sample', 697.7, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('cd1bfecd-66aa-4b3a-86aa-aba7ac0995cb', 'Language Activities LB', 'Pre-Primary', '9789966645289', 'sale', 715.01, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('bf19d014-b409-4e60-a4d4-f7990a1683a9', 'Language Activities LB (Sample)', 'Pre-Primary', 'SMPL-9789966645289', 'sample', 715.01, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('ea41b7c3-bf34-457f-80fd-618bbfdb4b69', 'Environmental Activities LB', 'Pre-Primary', '9789966645302', 'sale', 698.51, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('d90b5512-252e-422c-800b-02160d9ddb55', 'Environmental Activities LB (Sample)', 'Pre-Primary', 'SMPL-9789966645302', 'sample', 698.51, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('0072345d-a738-46df-a9de-3a71b90a68c7', 'Mathematics Activities LB', 'Pre-Primary', '9789966645326', 'sale', 682.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('130b5936-e079-4c87-9019-a2b6fcc6cf00', 'Mathematics Activities LB (Sample)', 'Pre-Primary', 'SMPL-9789966645326', 'sample', 682.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('ec70aec1-a1f2-4c81-814f-befbc2436b2e', 'Creative Activities LB', 'Pre-Primary', '9789966645340', 'sale', 649.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('65b2d327-9fd6-48d7-a196-dc708d51ec6d', 'Creative Activities LB (Sample)', 'Pre-Primary', 'SMPL-9789966645340', 'sample', 649.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('48b6f230-dee2-49eb-95ae-1937810a06e8', 'Christian Religious Education Activities LB', 'Pre-Primary', '9789966644701', 'sale', 616.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('92c6a996-0a06-46d2-a218-055705ea412c', 'Christian Religious Education Activities LB (Sample)', 'Pre-Primary', 'SMPL-9789966644701', 'sample', 616.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('912832cf-8b78-456f-882a-5d4c84cec60a', 'Language Activities TG', 'Pre-Primary', '9789966645296', 'sale', 825.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('be3370a3-5b91-4b31-ad64-715e54c39e75', 'Language Activities TG (Sample)', 'Pre-Primary', 'SMPL-9789966645296', 'sample', 825.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('853aed80-dd14-479e-b530-7c46c75d90f3', 'Longhorn charts: Insects [Approved]', 'Wall Charts', '9789966315311', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('ea35a87d-229b-4905-8df1-5f3e409dbe4e', 'Longhorn charts: Insects [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315311', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('dbe77e0e-5dfc-4530-8be9-a8d6f3e9c210', 'Longhorn charts Numbers 1-10 [Approved]', 'Wall Charts', '9789966315335', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('91a4fd9a-8a47-4efd-b481-647b0f26fd86', 'Longhorn charts Numbers 1-10 [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315335', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('cc60c918-9448-4191-8b92-3bb5dd0c2cd3', 'Longhorn charts: Plants [Approved]', 'Wall Charts', '9789966315359', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('bdb47b18-2e0f-40cc-bad8-578aa893d26a', 'Longhorn charts: Plants [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315359', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('dd101da1-e303-4b66-914e-6c5ff380190f', 'Longhorn charts: Parts Of The Body [Approved]', 'Wall Charts', '9789966315342', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('e56a4beb-8b2b-43b8-9ce1-cf8af0630299', 'Longhorn charts: Parts Of The Body [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315342', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('9a162458-ed07-497b-acff-554a07c2fe1f', 'Longhorn charts: Shapes [Approved]', 'Wall Charts', '9789966744118', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('5aa5dc95-f9ac-4e0a-987b-dbfc8c7f98f7', 'Longhorn charts: Shapes [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966744118', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('9dbbcbc6-1951-4e39-b3db-94e0a0bf7e1f', 'Longhorn charts: Furniture Use At Home [Approved]', 'Wall Charts', '9789966315304', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('bd598dbd-3f58-48eb-bdb0-bb3263b6d85d', 'Longhorn charts: Furniture Use At Home [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315304', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('8cf665eb-45fa-4cf1-a70d-feb8eab533eb', 'Longhorn charts: Food Eaten At Home [Approved]', 'Wall Charts', '9789966315274', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('db160dee-892e-43cd-ae9c-994a2606ede7', 'Longhorn charts: Food Eaten At Home [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315274', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('3268553e-543c-4fee-a235-aa131fe799af', 'Longhorn charts: Family Members [Approved]', 'Wall Charts', '9789966315267', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('4c0d644e-a877-4624-a54a-2a53a7582fdd', 'Longhorn charts: Family Members [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315267', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('a1bcbbd9-c11d-4291-96f0-614a69ff925f', 'Longhorn charts: Clothes Worn By Family Members [Approved]', 'Wall Charts', '9789966315236', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('cc226b29-0d6b-4a9c-9a99-95b1f2128ab9', 'Longhorn charts: Clothes Worn By Family Members [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315236', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('2330f0bf-a563-4e76-974f-0c9872af297a', 'Longhorn charts: Utensils Use At Home [Approved]', 'Wall Charts', '9789966315380', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('8e62e6f1-ce73-4e5d-9a06-68a126b933d8', 'Longhorn charts: Utensils Use At Home [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315380', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('c3731399-a271-4d66-aad9-bc8c3b980837', 'Longhorn charts: Means Of Transport [Approved]', 'Wall Charts', '9789966315328', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('b0cfd845-2bc0-4345-8251-bf368c68a1dd', 'Longhorn charts: Means Of Transport [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315328', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('78996551-8da1-4670-a02f-5f339d1b3e7d', 'Longhorn charts: Fruits We Eat [Approved]', 'Wall Charts', '9789966315298', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('ffe471db-e3ba-4f54-8429-cc8923e08b7e', 'Longhorn charts: Fruits We Eat [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315298', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('9f9364de-88e2-482b-92d2-088b5e43f490', 'Longhorn charts: Fruit Trees [Approved]', 'Wall Charts', '9789966315281', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('43414ca0-85d2-4306-8e32-631dd22d3528', 'Longhorn charts: Fruit Trees [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315281', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('a27c2a71-f4de-4fa5-9426-2ecd5103f2cd', 'Longhorn charts: Domestic Animals [Approved]', 'Wall Charts', '9789966315250', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('24ce4db8-9701-4c6e-ad57-3095466d732b', 'Longhorn charts: Domestic Animals [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315250', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('fd255863-69cf-4e1b-909b-3aa560ee6b18', 'Longhorn charts: Weather [Approved]', 'Wall Charts', '9789966315397', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('4fcf987d-fa2f-435d-8588-0e8c7603ffb9', 'Longhorn charts: Weather [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315397', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('612598bd-f92d-4e3c-a243-1a0f974d43b4', 'Longhorn charts: Wild Animals [Approved]', 'Wall Charts', '9789966315403', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('ed81e3d2-34e9-4663-b006-441e84a6738f', 'Longhorn charts: Wild Animals [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315403', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('57668f56-f5d6-40ee-a3b8-14ec7351b258', 'Longhorn charts: Colours [Approved]', 'Wall Charts', '9789966315243', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('aec46e28-e700-4dd1-a12a-1b9a2f573555', 'Longhorn charts: Colours [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315243', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('227bfcec-0547-44e6-8c90-8de91247bd6d', 'Balaam and the Donkey', 'General', '9789966314383', 'sale', 267.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('9e0a31f0-9597-46e8-b621-09579dbcfb99', 'Balaam and the Donkey (Sample)', 'General', 'SMPL-9789966314383', 'sample', 267.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('ddd9785a-07ac-469e-9b5d-96f731b4e90c', 'Battle of Jericho', 'General', '9789966314390', 'sale', 267.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('94b4d1bd-579b-49b2-9357-67a937a5f45c', 'Battle of Jericho (Sample)', 'General', 'SMPL-9789966314390', 'sample', 267.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true)
ON CONFLICT (sku) DO NOTHING;

-- END FILE: seed.sql


-- =========================================================

-- BEGIN FILE: seed_dynamic_crm_data.sql

-- =========================================================

-- 1. Clean up existing mock data to avoid conflicts (Optional, but recommended for a clean start)
-- TRUNCATE school_sales, school_visits, opportunity_activities, schools CASCADE;

-- 2. Insert realistic Schools
INSERT INTO schools (id, name, phone, county, school_ownership, school_population, book_category, "focusAreas", lead_score, created_at)
VALUES 
  (gen_random_uuid(), 'St. Andrews Academy', '0711222333', 'Nairobi', 'Private', 1200, 'Book Fund', '["Mathematics", "Science"]', 85, now() - interval '45 days'),
  (gen_random_uuid(), 'Sunshine Primary School', '0722333444', 'Kiambu', 'Public', 800, 'Government Supply', '["Literacy"]', 45, now() - interval '32 days'),
  (gen_random_uuid(), 'Greenwood High', '0733444555', 'Mombasa', 'Private', 1500, 'Book Fund', '["Technology", "Art"]', 95, now() - interval '10 days'),
  (gen_random_uuid(), 'Hillcrest International', '0744555666', 'Nairobi', 'Private', 600, 'Premium', '["All Subjects"]', 60, now() - interval '5 days'),
  (gen_random_uuid(), 'Riverbank School', '0755666777', 'Nakuru', 'Public', 450, 'Standard', '["Physical Ed"]', 20, now() - interval '65 days')
ON CONFLICT DO NOTHING;

-- 3. Insert Sales Opportunities (linked to the schools we just made)
-- We use a subquery to get IDs to ensure they match
INSERT INTO school_sales (id, school_id, package_name, expected_value, sale_status, probability, next_action, next_action_date, risk_level, created_at)
SELECT 
  gen_random_uuid(), 
  id, 
  'Annual Book Subscription', 
  CASE 
    WHEN name = 'St. Andrews Academy' THEN 500000 
    WHEN name = 'Greenwood High' THEN 750000 
    ELSE 150000 
  END,
  CASE 
    WHEN name = 'St. Andrews Academy' THEN 'negotiation'
    WHEN name = 'Sunshine Primary School' THEN 'sample_issued'
    WHEN name = 'Greenwood High' THEN 'won'
    WHEN name = 'Hillcrest International' THEN 'lead'
    ELSE 'lost'
  END,
  CASE 
    WHEN name = 'St. Andrews Academy' THEN 70
    WHEN name = 'Greenwood High' THEN 100
    ELSE 20
  END,
  'Finalize contract signature',
  current_date + 3,
  'low',
  now() - interval '20 days'
FROM schools
WHERE name IN ('St. Andrews Academy', 'Sunshine Primary School', 'Greenwood High', 'Hillcrest International', 'Riverbank School');

-- 4. Insert some Field Visits
INSERT INTO school_visits (school_id, outcome, notes, visited_at)
SELECT id, 'Positive meeting with Headteacher', 'Discussed new curriculum requirements.', now() - interval '2 days'
FROM schools WHERE name = 'St. Andrews Academy';

INSERT INTO school_visits (school_id, outcome, notes, visited_at)
SELECT id, 'Dropped off sample books', 'Librarian was very impressed.', now() - interval '5 days'
FROM schools WHERE name = 'Sunshine Primary School';

-- 5. Insert Opportunity Activities (to populate the timeline)
INSERT INTO opportunity_activities (opportunity_id, school_id, activity_type, activity_outcome, notes, next_action, next_action_date, created_at)
SELECT s.id, s.school_id, 'Call', 'Answered', 'Followed up on the quotation sent last week.', 'Send revised invoice', current_date + 1, now() - interval '1 day'
FROM school_sales s 
JOIN schools sch ON s.school_id = sch.id
WHERE sch.name = 'St. Andrews Academy';

-- 6. Insert some Orders for Financials
with demo_greenwood as (
  select id, name
  from schools
  where name = 'Greenwood High'
  order by created_at desc nulls last, id
  limit 1
)
INSERT INTO orders (school_id, school_name, order_number, checkout_amount, status, created_at)
SELECT id, name, 'ORD-1001', 450000, 'completed', now() - interval '1 year'
FROM demo_greenwood
ON CONFLICT (order_number) DO UPDATE SET
  school_id = excluded.school_id,
  school_name = excluded.school_name,
  checkout_amount = excluded.checkout_amount,
  status = excluded.status,
  created_at = excluded.created_at;

with demo_st_andrews as (
  select id, name
  from schools
  where name = 'St. Andrews Academy'
  order by created_at desc nulls last, id
  limit 1
)
INSERT INTO orders (school_id, school_name, order_number, checkout_amount, status, created_at)
SELECT id, name, 'ORD-1002', 25000, 'pending', now() - interval '1 month'
FROM demo_st_andrews
ON CONFLICT (order_number) DO UPDATE SET
  school_id = excluded.school_id,
  school_name = excluded.school_name,
  checkout_amount = excluded.checkout_amount,
  status = excluded.status,
  created_at = excluded.created_at;

-- 6b. Seed order items for the demo orders so itemized views render properly
INSERT INTO order_items (
  id, order_id, product_name, category, sku, quantity, unit_price, line_total, notes, "isSynced"
)
SELECT
  '97100000-0000-0000-0000-000000000001',
  o.id,
  'Annual Reader Pack',
  'Primary',
  'DR-AP-01',
  30,
  5000.00,
  150000.00,
  'Seeded line item for demo order.',
  true
FROM orders o
WHERE o.order_number = 'ORD-1001'
ON CONFLICT (id) DO UPDATE SET
  order_id = excluded.order_id,
  product_name = excluded.product_name,
  category = excluded.category,
  sku = excluded.sku,
  quantity = excluded.quantity,
  unit_price = excluded.unit_price,
  line_total = excluded.line_total,
  notes = excluded.notes,
  "isSynced" = excluded."isSynced";

INSERT INTO order_items (
  id, order_id, product_name, category, sku, quantity, unit_price, line_total, notes, "isSynced"
)
SELECT
  '97100000-0000-0000-0000-000000000002',
  o.id,
  'Teacher Guide Bundle',
  'Reference',
  'DG-TG-01',
  5,
  15000.00,
  75000.00,
  'Seeded line item for demo order.',
  true
FROM orders o
WHERE o.order_number = 'ORD-1001'
ON CONFLICT (id) DO UPDATE SET
  order_id = excluded.order_id,
  product_name = excluded.product_name,
  category = excluded.category,
  sku = excluded.sku,
  quantity = excluded.quantity,
  unit_price = excluded.unit_price,
  line_total = excluded.line_total,
  notes = excluded.notes,
  "isSynced" = excluded."isSynced";

INSERT INTO order_items (
  id, order_id, product_name, category, sku, quantity, unit_price, line_total, notes, "isSynced"
)
SELECT
  '97100000-0000-0000-0000-000000000003',
  o.id,
  'Revision Books',
  'Secondary',
  'DG-RB-01',
  10,
  1800.00,
  18000.00,
  'Seeded line item for demo order.',
  true
FROM orders o
WHERE o.order_number = 'ORD-1002'
ON CONFLICT (id) DO UPDATE SET
  order_id = excluded.order_id,
  product_name = excluded.product_name,
  category = excluded.category,
  sku = excluded.sku,
  quantity = excluded.quantity,
  unit_price = excluded.unit_price,
  line_total = excluded.line_total,
  notes = excluded.notes,
  "isSynced" = excluded."isSynced";

-- 7. Add Lead Scores explicitly if the trigger didn't backfill
UPDATE schools SET lead_score = 85 WHERE name = 'St. Andrews Academy';
UPDATE schools SET lead_score = 95 WHERE name = 'Greenwood High';
UPDATE schools SET lead_score = 45 WHERE name = 'Sunshine Primary School';

-- 8. Add explicit sales demo rows for admin dashboards and ROI screens
with demo_schools as (
  select id, name, phone, row_number() over (order by created_at desc nulls last, id) as rn
  from schools
  where name in (
    'St. Andrews Academy',
    'Sunshine Primary School',
    'Greenwood High',
    'Hillcrest International',
    'Riverbank School'
  )
)
insert into school_sales (
  id, school_id, agent_id, package_name, expected_value, notes,
  sale_status, stage_updated_at, expected_close_date, probability, closed_at, "isSynced"
)
select
  ('96000000-0000-0000-0000-' || lpad(rn::text, 12, '0'))::uuid,
  id,
  case when rn % 2 = 0
    then '92000000-0000-0000-0000-000000000002'::uuid
    else '92000000-0000-0000-0000-000000000001'::uuid
  end,
  'Sales Demo Package',
  case
    when name = 'St. Andrews Academy' then 210000
    when name = 'Greenwood High' then 340000
    when name = 'Hillcrest International' then 185000
    when name = 'Sunshine Primary School' then 125000
    else 90000
  end,
  'Seeded sales demo row',
  case
    when name = 'St. Andrews Academy' then 'negotiation'
    when name = 'Greenwood High' then 'won'
    when name = 'Hillcrest International' then 'quotation_sent'
    when name = 'Sunshine Primary School' then 'contacted'
    else 'lead'
  end,
  now() - interval '2 days',
  current_date + 14,
  case
    when name = 'Greenwood High' then 100
    when name = 'St. Andrews Academy' then 80
    when name = 'Hillcrest International' then 65
    when name = 'Sunshine Primary School' then 40
    else 25
  end,
  case
    when name = 'Greenwood High' then now() - interval '2 days'
    else null
  end,
  true
from demo_schools
on conflict (id) do nothing;

with demo_schools as (
  select id, name, phone, row_number() over (order by created_at desc nulls last, id) as rn
  from schools
  where name in (
    'St. Andrews Academy',
    'Sunshine Primary School',
    'Greenwood High',
    'Hillcrest International',
    'Riverbank School'
  )
)
insert into orders (
  id, school_id, school_name, school_phone, agent_id, order_number,
  payment_method, payment_reference, checkout_amount, status, notes, submitted_at, approved_at, "isSynced"
)
select
  ('97000000-0000-0000-0000-' || lpad(rn::text, 12, '0'))::uuid,
  id,
  name,
  coalesce(phone, '0700000000'),
  case when rn % 2 = 0
    then '92000000-0000-0000-0000-000000000002'::uuid
    else '92000000-0000-0000-0000-000000000001'::uuid
  end,
  'SALES-DEMO-' || rn,
  case
    when name = 'Greenwood High' then 'mpesa'
    when name = 'Hillcrest International' then 'bank'
    else 'cash'
  end,
  case
    when name = 'Greenwood High' then 'MPESA-DEMO-9001'
    when name = 'Hillcrest International' then 'BANK-DEMO-9002'
    else null
  end,
  case
    when name = 'St. Andrews Academy' then 210000
    when name = 'Greenwood High' then 340000
    when name = 'Hillcrest International' then 185000
    when name = 'Sunshine Primary School' then 125000
    else 90000
  end,
  case
    when name = 'Greenwood High' then 'approved'
    when name = 'Hillcrest International' then 'pending'
    else 'paid'
  end,
  'Seeded sales order',
  now() - interval '2 days',
  case
    when name = 'Hillcrest International' then null
    else now() - interval '1 day'
  end,
  true
from demo_schools
on conflict (id) do nothing;

-- END FILE: seed_dynamic_crm_data.sql


-- =========================================================

-- BEGIN FILE: seed_role5_performance.sql

-- =========================================================

-- Seed script to populate Role 5 Performance Scorecard data
-- This script will find existing Role 5 users and assign them some tasks, route plans, and school visits.

DO $$
DECLARE
  v_user_id UUID;
  v_school_id UUID;
  v_user_count INT := 0;
BEGIN
  -- We need a school ID to log visits against.
  SELECT id INTO v_school_id FROM schools LIMIT 1;

  -- Loop through up to 3 existing Role 5 users
  FOR v_user_id IN (SELECT id FROM users WHERE role = 5 LIMIT 3) LOOP
    v_user_count := v_user_count + 1;

    -- 1. Insert Tasks (Mix of closed, open, and in_progress)
    INSERT INTO tasks (assigned_to, title, description, status, due_at, target_role, created_at)
    VALUES 
      (v_user_id, 'Follow up with ' || v_user_count || ' priority schools', 'Call headteachers to confirm orders.', 'closed', now() - interval '2 days', 5, now() - interval '10 days'),
      (v_user_id, 'Deliver Book Samples', 'Deliver new syllabus samples.', 'in_progress', now() + interval '1 day', 5, now() - interval '2 days'),
      (v_user_id, 'Submit Weekly Field Report', 'Submit expense and field report.', 'closed', now() - interval '5 days', 5, now() - interval '15 days'),
      (v_user_id, 'Review Geofence Compliance', 'Review exceptions with supervisor.', 'open', now() - interval '1 day', 5, now() - interval '4 days');
      
    -- 2. Insert Route Plans (Mix of completed, approved, and assigned)
    INSERT INTO route_plans (assigned_to, route_date, status, title, created_at)
    VALUES 
      (v_user_id, current_date - 2, 'completed', 'Route Plan - ' || to_char(current_date - 2, 'YYYY-MM-DD'), now() - interval '3 days'),
      (v_user_id, current_date - 1, 'completed', 'Route Plan - ' || to_char(current_date - 1, 'YYYY-MM-DD'), now() - interval '2 days'),
      (v_user_id, current_date, 'assigned', 'Route Plan - ' || to_char(current_date, 'YYYY-MM-DD'), now() - interval '1 day'),
      (v_user_id, current_date + 1, 'approved', 'Route Plan - ' || to_char(current_date + 1, 'YYYY-MM-DD'), now() - interval '12 hours');
      
    -- 3. Insert School Visits (If we found a school)
    IF v_school_id IS NOT NULL THEN
      INSERT INTO school_visits (school_id, agent_id, outcome, notes, visited_at)
      VALUES 
        (v_school_id, v_user_id, 'Met with principal', 'Discussed new curriculum rollout', now() - interval '1 day'),
        (v_school_id, v_user_id, 'Dropped samples', 'Left 5 books for review', now() - interval '3 days');
        
      -- Add a 3rd visit for the first user to give them a slightly higher score
      IF v_user_count = 1 THEN
         INSERT INTO school_visits (school_id, agent_id, outcome, notes, visited_at)
         VALUES (v_school_id, v_user_id, 'Follow up', 'Checking on order status', now() - interval '5 days');
      END IF;
    END IF;
  END LOOP;

  -- Optional: If no Role 5 users exist, we could create dummy users, but since the system relies on auth.users, 
  -- it is safer to only attach data to existing users created via the UI.
END;
$$;

-- END FILE: seed_role5_performance.sql


-- =========================================================

-- BEGIN FILE: seed_sample_roi_dummy.sql

-- =========================================================

-- Dummy data for sample ROI testing (Role 5 + Admin)
-- Safe-ish rerun via fixed IDs + upserts where possible.

begin;

-- 1) Ensure demo users exist (role 5 grounds + role 4 agent)
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '92000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'grounds.demo@dehus.com',
    crypt('password123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Grounds Demo User","role":5,"region":"Nairobi"}',
    now(),
    now()
  ),
  (
    '92000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'agent.demo@dehus.com',
    crypt('password123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Agent Demo User","role":4,"region":"Nakuru"}',
    now(),
    now()
  )
on conflict (id) do nothing;

insert into users (id, email, full_name, phone, role, region)
values
  ('92000000-0000-0000-0000-000000000001', 'grounds.demo@dehus.com', 'Grounds Demo User', '0711000001', 5, 'Nairobi'),
  ('92000000-0000-0000-0000-000000000002', 'agent.demo@dehus.com', 'Agent Demo User', '0711000002', 4, 'Nakuru')
on conflict (id) do update set
  email = excluded.email,
  full_name = excluded.full_name,
  phone = excluded.phone,
  role = excluded.role,
  region = excluded.region;

-- 2) Pick up to 4 schools for linking data
with s as (
  select id, row_number() over (order by created_at desc nulls last, id) rn
  from schools
  limit 4
)
insert into school_sample_distributions (
  id, school_id, agent_id, sample_name, sample_category, quantity,
  stamped_receipt_url, stamped_receipt_path, notes, distributed_at, "isSynced"
)
select
  ('93000000-0000-0000-0000-' || lpad(rn::text, 12, '0'))::uuid,
  s.id,
  case when s.rn % 2 = 0
    then '92000000-0000-0000-0000-000000000002'::uuid
    else '92000000-0000-0000-0000-000000000001'::uuid
  end,
  case when s.rn % 2 = 0 then 'Teacher Guide Kit' else 'Grade 1 Reader Pack' end,
  case when s.rn % 2 = 0 then 'Reference' else 'Primary' end,
  (s.rn % 3) + 1,
  'https://images.unsplash.com/photo-1455390582262-044cdead277a?w=1200',
  'sample_receipts/demo_' || s.rn || '.jpg',
  'Dummy ROI receipt seed',
  now() - ((s.rn::text || ' days')::interval),
  true
from s
on conflict (id) do update set
  school_id = excluded.school_id,
  agent_id = excluded.agent_id,
  sample_name = excluded.sample_name,
  sample_category = excluded.sample_category,
  quantity = excluded.quantity,
  stamped_receipt_url = excluded.stamped_receipt_url,
  stamped_receipt_path = excluded.stamped_receipt_path,
  notes = excluded.notes,
  distributed_at = excluded.distributed_at,
  "isSynced" = excluded."isSynced";

-- 3) Orders for revenue earned metric
insert into orders (
  id, school_id, school_name, school_phone, agent_id, order_number,
  payment_method, payment_reference, checkout_amount, status, notes, submitted_at, approved_at, "isSynced"
)
select
  ('94000000-0000-0000-0000-' || lpad(rn::text, 12, '0'))::uuid,
  s.id,
  coalesce(sc.name, 'School ' || s.rn),
  coalesce(sc.phone, '0700000000'),
  case when s.rn % 2 = 0
    then '92000000-0000-0000-0000-000000000002'::uuid
    else '92000000-0000-0000-0000-000000000001'::uuid
  end,
  'DEMO-ROI-' || s.rn,
  'mpesa',
  'MPESA-DEMO-' || s.rn,
  (50000 + (s.rn * 10000))::numeric,
  case when s.rn % 3 = 0 then 'pending' else 'approved' end,
  'Dummy ROI order',
  now() - ((s.rn::text || ' days')::interval),
  now() - (((s.rn + 1)::text || ' days')::interval),
  true
from (
  select id, row_number() over (order by created_at desc nulls last, id) rn
  from schools
  limit 4
) s
left join schools sc on sc.id = s.id
on conflict (id) do update set
  school_id = excluded.school_id,
  school_name = excluded.school_name,
  school_phone = excluded.school_phone,
  agent_id = excluded.agent_id,
  checkout_amount = excluded.checkout_amount,
  status = excluded.status,
  notes = excluded.notes,
  submitted_at = excluded.submitted_at,
  approved_at = excluded.approved_at,
  "isSynced" = excluded."isSynced";

-- 4) School sales for won value metric
insert into school_sales (
  id, school_id, agent_id, package_name, expected_value, notes,
  sale_status, stage_updated_at, probability, closed_at, "isSynced"
)
select
  ('95000000-0000-0000-0000-' || lpad(rn::text, 12, '0'))::uuid,
  s.id,
  case when s.rn % 2 = 0
    then '92000000-0000-0000-0000-000000000002'::uuid
    else '92000000-0000-0000-0000-000000000001'::uuid
  end,
  'ROI Demo Package',
  (90000 + (s.rn * 12000))::numeric,
  'Dummy ROI pipeline',
  case when s.rn % 2 = 0 then 'won' else 'negotiation' end,
  now() - ((s.rn::text || ' days')::interval),
  case when s.rn % 2 = 0 then 100 else 70 end,
  case when s.rn % 2 = 0 then now() - ((s.rn::text || ' days')::interval) else null end,
  true
from (
  select id, row_number() over (order by created_at desc nulls last, id) rn
  from schools
  limit 4
) s
on conflict (id) do update set
  school_id = excluded.school_id,
  agent_id = excluded.agent_id,
  package_name = excluded.package_name,
  expected_value = excluded.expected_value,
  notes = excluded.notes,
  sale_status = excluded.sale_status,
  stage_updated_at = excluded.stage_updated_at,
  probability = excluded.probability,
  closed_at = excluded.closed_at,
  "isSynced" = excluded."isSynced";

commit;

-- END FILE: seed_sample_roi_dummy.sql


-- =========================================================

-- BEGIN FILE: generate_mock_data.sql

-- =========================================================

-- Generate mock tasks + pipeline data for dashboard testing
-- Safe to rerun: uses deterministic IDs and upserts.

begin;

-- 1) Ensure task status normalization in existing rows
update tasks
set status = 'closed'
where lower(status) in ('complete', 'completed', 'done');

update tasks
set status = 'in_progress'
where lower(status) in ('in progress', 'progress');

update tasks
set status = 'open'
where lower(status) not in ('open', 'in_progress', 'closed');

-- 2) Insert/update demo tasks across statuses and due dates
insert into tasks (
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
  from schools
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
insert into school_sales (
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

-- END FILE: generate_mock_data.sql


-- =========================================================

-- BEGIN FILE: demo_geofences.sql

-- =========================================================

-- Demo county geofences for admin map visualization
-- Run this after schema/seed setup.

insert into geofences (name, description, region, coordinates)
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

-- END FILE: demo_geofences.sql


-- =========================================================

-- BEGIN FILE: storage_policies_sample_receipts.sql

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
DROP POLICY IF EXISTS "authenticated_can_view_schools_bucket" ON storage.objects;
create policy "authenticated_can_view_schools_bucket"
on storage.objects
for select
to authenticated
using (bucket_id = 'schools');

drop policy if exists "authenticated_can_upload_schools_bucket" on storage.objects;
DROP POLICY IF EXISTS "authenticated_can_upload_schools_bucket" ON storage.objects;
create policy "authenticated_can_upload_schools_bucket"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'schools');

drop policy if exists "authenticated_can_update_schools_bucket" on storage.objects;
DROP POLICY IF EXISTS "authenticated_can_update_schools_bucket" ON storage.objects;
create policy "authenticated_can_update_schools_bucket"
on storage.objects
for update
to authenticated
using (bucket_id = 'schools')
with check (bucket_id = 'schools');

-- 3) Policies for dedicated 'sample-receipts' bucket
drop policy if exists "authenticated_can_view_sample_receipts_bucket" on storage.objects;
DROP POLICY IF EXISTS "authenticated_can_view_sample_receipts_bucket" ON storage.objects;
create policy "authenticated_can_view_sample_receipts_bucket"
on storage.objects
for select
to authenticated
using (bucket_id = 'sample-receipts');

drop policy if exists "authenticated_can_upload_sample_receipts_bucket" on storage.objects;
DROP POLICY IF EXISTS "authenticated_can_upload_sample_receipts_bucket" ON storage.objects;
create policy "authenticated_can_upload_sample_receipts_bucket"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'sample-receipts');

drop policy if exists "authenticated_can_update_sample_receipts_bucket" on storage.objects;
DROP POLICY IF EXISTS "authenticated_can_update_sample_receipts_bucket" ON storage.objects;
create policy "authenticated_can_update_sample_receipts_bucket"
on storage.objects
for update
to authenticated
using (bucket_id = 'sample-receipts')
with check (bucket_id = 'sample-receipts');

commit;

-- END FILE: storage_policies_sample_receipts.sql


-- =========================================================

-- BEGIN FILE: rpc_scorecard.sql

-- =========================================================

-- RPC to fetch dynamic Role 5 Performance Scorecard data based on a date range

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
    FROM users u
    LEFT JOIN tasks t ON t.assigned_to = u.id AND t.created_at >= p_start_date AND t.created_at <= p_end_date
    LEFT JOIN route_plans r ON r.assigned_to = u.id AND r.created_at >= p_start_date AND r.created_at <= p_end_date
    LEFT JOIN school_visits sv ON sv.agent_id = u.id AND sv.visited_at >= p_start_date AND sv.visited_at <= p_end_date
    WHERE u.role = 5
    GROUP BY u.id, u.full_name, u.region;
END;
$$;

-- END FILE: rpc_scorecard.sql


-- =========================================================

-- BEGIN FILE: mysql_unified.sql (converted seed-only additions)

-- =========================================================

-- Tables are already created by schema.sql above; only the seed rows are added.

-- users.id is a FK to auth.users(id); insert into auth.users

-- so the handle_new_user() trigger populates users automatically.

INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)

VALUES

  ('a1a1a1a1-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@dehus.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name": "System Admin", "role": 1, "region": "Nairobi"}', now(), now()),

  ('a2a2a2a2-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'agent@dehus.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name": "Field Agent 1", "role": 5, "region": "Nairobi"}', now(), now())

ON CONFLICT (id) DO NOTHING;


INSERT INTO geofences (id, name, region, coordinates)

VALUES

  ('b1b1b1b1-1111-1111-1111-111111111111', 'Nairobi Central', 'Nairobi', '[{"lat": -1.28, "lng": 36.82}]'::jsonb)

ON CONFLICT (id) DO NOTHING;

-- END FILE: mysql_unified.sql (converted seed-only additions)

