-- Schema updates: Visit check-ins (school visit tracking)
-- Adds visit_checkins table to track agent check-in/out with geolocation

-- Step 1: create table if missing (without agent_name to keep this idempotent)
create table if not exists public.visit_checkins (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid not null references public.users (id) on delete cascade,
  checkin_at timestamptz not null,
  checkout_at timestamptz,
  gps_lat double precision,
  gps_lng double precision,
  location_text text,
  duration_seconds integer,
  auto_checkout boolean not null default false,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Step 2: ensure all expected columns exist (idempotent for re-runs)
alter table public.visit_checkins
  add column if not exists agent_name text;

-- Step 3: now that the column is guaranteed to exist, build indexes
create index if not exists idx_visit_checkins_agent
  on public.visit_checkins(agent_id, checkin_at desc);

create index if not exists idx_visit_checkins_open
  on public.visit_checkins(agent_id)
  where checkout_at is null;

create index if not exists idx_visit_checkins_agent_name
  on public.visit_checkins(agent_name);

-- (agent_id, checkin_at desc) already covers day-range scans for a given agent.
-- The composite index above is sufficient for per-day queries.
-- A separate (checkin_at) index speeds up "all agents in a day" reads:
create index if not exists idx_visit_checkins_checkin_at
  on public.visit_checkins(checkin_at);

-- Step 4: backfill agent_name from public.users
update public.visit_checkins v
set agent_name = u.full_name
from public.users u
where v.agent_id = u.id
  and (v.agent_name is null or v.agent_name = '');

-- Step 5: trigger to keep agent_name in sync with the user's full_name
create or replace function public.visit_checkins_sync_agent_name()
returns trigger
language plpgsql
as $$
begin
  if new.agent_name is null or new.agent_name = '' then
    select full_name into new.agent_name
    from public.users
    where id = new.agent_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_visit_checkins_sync_agent_name on public.visit_checkins;
create trigger trg_visit_checkins_sync_agent_name
  before insert on public.visit_checkins
  for each row
  execute function public.visit_checkins_sync_agent_name();

-- Step 6: RLS
alter table if exists public.visit_checkins enable row level security;

drop policy if exists "agents_can_create_visit_checkins" on public.visit_checkins;
drop policy if exists "agents_can_view_own_visit_checkins" on public.visit_checkins;
drop policy if exists "agents_can_update_own_visit_checkins" on public.visit_checkins;
drop policy if exists "admins_can_view_all_visit_checkins" on public.visit_checkins;

create policy "agents_can_create_visit_checkins"
  on public.visit_checkins
  for insert
  to authenticated
  with check (auth.uid() = agent_id);

create policy "agents_can_view_own_visit_checkins"
  on public.visit_checkins
  for select
  to authenticated
  using (auth.uid() = agent_id);

create policy "agents_can_update_own_visit_checkins"
  on public.visit_checkins
  for update
  to authenticated
  using (auth.uid() = agent_id)
  with check (auth.uid() = agent_id);

create policy "admins_can_view_all_visit_checkins"
  on public.visit_checkins
  for select
  to authenticated
  using (
    exists (
      select 1 from public.users
      where users.id = auth.uid()
      and users.role in (1, 2, 3, 4)
    )
  );

-- Step 7: convenience view (joins users for full_name / email / role)
create or replace view public.visit_checkins_with_agent as
  select
    v.*,
    u.full_name as user_full_name,
    u.email     as user_email,
    u.role      as user_role
  from public.visit_checkins v
  left join public.users u on u.id = v.agent_id;

grant select on public.visit_checkins_with_agent to authenticated;
