-- =====================================================================
-- Quick Apply: Event Sales table + Consignment link
-- 
-- Copy and paste this into your Supabase SQL Editor to add the missing
-- event_sales table and the apply_consignment_sale trigger to your
-- remote project (nlikgeqoocimbbqyaegq).
--
-- This is idempotent — safe to re-run.
-- =====================================================================

-- 1. Create event_sales table
create table if not exists public.event_sales (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  product_id uuid references public.catalog_items (id) on delete set null,
  agent_id uuid references public.users (id) on delete set null,
  quantity integer not null default 1,
  amount numeric(12,2) not null default 0,
  payment_method text not null default 'cash',
  notes text,
  sold_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_event_sales_event on public.event_sales(event_id);
create index if not exists idx_event_sales_agent on public.event_sales(agent_id);

alter table if exists public.event_sales enable row level security;

drop policy if exists "admins_can_manage_event_sales" on public.event_sales;
drop policy if exists "authenticated_can_view_event_sales" on public.event_sales;
drop policy if exists "agents_can_manage_own_sales" on public.event_sales;

create policy "admins_can_manage_event_sales"
on public.event_sales for all
to authenticated using (public.current_user_role_id() = 1)
with check (public.current_user_role_id() = 1);

create policy "authenticated_can_view_event_sales"
on public.event_sales for select
to authenticated using (true);

create policy "agents_can_manage_own_sales"
on public.event_sales for all
to authenticated using (
  agent_id = auth.uid()
  or public.current_user_role_id() <= 4
)
with check (
  agent_id = auth.uid()
  or public.current_user_role_id() <= 4
);

grant all on public.event_sales to authenticated;

-- 2. Link event_sales to consignment allocations
do $$
begin
  if to_regclass('public.event_sales') is not null then
    if not exists (select 1 from information_schema.columns
                   where table_schema='public' and table_name='event_sales' and column_name='consignment_id') then
      alter table public.event_sales
        add column consignment_id text references public.consignments (consignment_id) on delete set null;
    end if;
    if not exists (select 1 from information_schema.columns
                   where table_schema='public' and table_name='event_sales' and column_name='consignment_item_id') then
      alter table public.event_sales
        add column consignment_item_id uuid references public.consignment_items (id) on delete set null;
    end if;
  end if;
end $$;

do $$
begin
  if to_regclass('public.event_sales') is not null then
    execute 'create index if not exists idx_event_sales_consignment
             on public.event_sales(consignment_id, consignment_item_id)
             where consignment_id is not null';
  end if;
end $$;

-- 3. Atomic sale recorder trigger function
create or replace function public.apply_consignment_sale()
returns trigger language plpgsql security definer set search_path = public
as $$
declare
  v_remaining integer;
  v_alloc     public.consignment_items%rowtype;
begin
  if new.consignment_item_id is null then
    return new;
  end if;
  select * into v_alloc from public.consignment_items
   where id = new.consignment_item_id for update;
  if not found then
    raise exception 'Consignment allocation % not found', new.consignment_item_id;
  end if;
  v_remaining := v_alloc.units_to_assign - v_alloc.units_sold;
  if new.quantity > v_remaining then
    raise exception 'Sale of % units exceeds remaining consignment allocation (%)', new.quantity, v_remaining;
  end if;
  if v_alloc.product_id is not null then
    perform 1 from public.catalog_items where id = v_alloc.product_id for update;
    if not found then
      raise exception 'Catalog item % not found', v_alloc.product_id;
    end if;
    update public.catalog_items
       set stock_qty = greatest(stock_qty - new.quantity, 0), updated_at = now()
     where id = v_alloc.product_id and stock_qty >= new.quantity;
    if not found then
      raise exception 'Insufficient stock for product %', v_alloc.product_id;
    end if;
  end if;
  update public.consignment_items
     set units_sold = units_sold + new.quantity, updated_at = now()
   where id = new.consignment_item_id;
  return new;
end;
$$;

do $$
begin
  if to_regclass('public.event_sales') is not null then
    drop trigger if exists trg_apply_consignment_sale on public.event_sales;
    create trigger trg_apply_consignment_sale
      before insert on public.event_sales
      for each row execute procedure public.apply_consignment_sale();
  end if;
end $$;

-- 4. Stock validation trigger for consignment_items
drop trigger if exists trg_check_consignment_item_stock on public.consignment_items;
create trigger trg_check_consignment_item_stock
  before insert or update on public.consignment_items
  for each row execute function public.check_consignment_item_stock();
