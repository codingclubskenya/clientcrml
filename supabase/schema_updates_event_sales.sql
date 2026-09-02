-- Event Sales table for recording product sales during events
-- Safe to rerun

create table if not exists public.event_sales (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  product_id uuid references public.catalog_items (id) on delete set null,
  agent_id uuid references public.users (id) on delete set null,
  quantity integer not null default 1,
  amount numeric(12,2) not null default 0,
  payment_method text not null default 'cash', -- cash | mpesa
  notes text,
  sold_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_event_sales_event on public.event_sales(event_id);
create index if not exists idx_event_sales_agent on public.event_sales(agent_id);

-- Enable RLS
alter table if exists public.event_sales enable row level security;

-- RLS Policies
drop policy if exists "admins_can_manage_event_sales" on public.event_sales;
drop policy if exists "authenticated_can_view_event_sales" on public.event_sales;
drop policy if exists "agents_can_manage_own_sales" on public.event_sales;

create policy "admins_can_manage_event_sales"
on public.event_sales
for all
to authenticated
using (public.current_user_role_id() = 1)
with check (public.current_user_role_id() = 1);

create policy "authenticated_can_view_event_sales"
on public.event_sales
for select
to authenticated
using (true);

create policy "agents_can_manage_own_sales"
on public.event_sales
for all
to authenticated
using (
  agent_id = auth.uid()
  or public.current_user_role_id() <= 4
)
with check (
  agent_id = auth.uid()
  or public.current_user_role_id() <= 4
);

-- Grant permissions
grant all on public.event_sales to authenticated;

-- End of migration
