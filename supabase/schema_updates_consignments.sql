-- Migration: Product Catalog & Consignment Assignment Flow
-- Adds book/school-item metadata to catalog_items, introduces
-- consignments / consignment_items, links event_sales to a
-- consignment allocation and keeps stock + units_sold in sync
-- atomically via a database trigger.
--
-- Safe to re-run (idempotent). No demo data inserted.

-- =====================================================================
-- 1. Extend catalog_items with book / school-item metadata
-- =====================================================================
do $$
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='catalog_items' and column_name='supplier_id') then
    alter table public.catalog_items add column supplier_id uuid;
  end if;
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='catalog_items' and column_name='supplier_name') then
    alter table public.catalog_items add column supplier_name text;
  end if;
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='catalog_items' and column_name='barcode') then
    alter table public.catalog_items add column barcode text;
  end if;
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='catalog_items' and column_name='wholesale_price') then
    alter table public.catalog_items add column wholesale_price numeric(12,2) not null default 0;
  end if;
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='catalog_items' and column_name='unit') then
    alter table public.catalog_items add column unit text not null default 'pieces';
  end if;
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='catalog_items' and column_name='min_stock') then
    alter table public.catalog_items add column min_stock integer not null default 0;
  end if;
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='catalog_items' and column_name='max_stock') then
    alter table public.catalog_items add column max_stock integer not null default 0;
  end if;
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='catalog_items' and column_name='image_url') then
    alter table public.catalog_items add column image_url text;
  end if;

  -- Book / school-item metadata
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='catalog_items' and column_name='author') then
    alter table public.catalog_items add column author text;
  end if;
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='catalog_items' and column_name='publisher') then
    alter table public.catalog_items add column publisher text;
  end if;
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='catalog_items' and column_name='isbn') then
    alter table public.catalog_items add column isbn text;
  end if;
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='catalog_items' and column_name='edition') then
    alter table public.catalog_items add column edition text;
  end if;
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='catalog_items' and column_name='grade_level') then
    alter table public.catalog_items add column grade_level text;
  end if;
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='catalog_items' and column_name='subject') then
    alter table public.catalog_items add column subject text;
  end if;
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='catalog_items' and column_name='language') then
    alter table public.catalog_items add column language text;
  end if;
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='catalog_items' and column_name='page_count') then
    alter table public.catalog_items add column page_count integer;
  end if;
end $$;

create index if not exists idx_catalog_items_supplier on public.catalog_items(supplier_id);
create index if not exists idx_catalog_items_category on public.catalog_items(category);
create index if not exists idx_catalog_items_isbn on public.catalog_items(isbn);

-- =====================================================================
-- 2. Consignments (stock assignments to business associates)
-- =====================================================================
create table if not exists public.consignments (
  consignment_id text primary key,                          -- e.g. CON-2526
  business_associate_id uuid not null references public.users (id) on delete restrict,
  business_associate_name text not null,
  status text not null default 'pending',                   -- pending | active | completed | cancelled
  notes text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint consignments_status_chk check (status in ('pending','active','completed','cancelled'))
);

create index if not exists idx_consignments_ba on public.consignments(business_associate_id);
create index if not exists idx_consignments_status on public.consignments(status);

create table if not exists public.consignment_items (
  id uuid primary key default gen_random_uuid(),
  consignment_id text not null references public.consignments (consignment_id) on delete cascade,
  product_id uuid not null references public.catalog_items (id) on delete restrict,
  units_to_assign integer not null check (units_to_assign > 0),
  units_sold integer not null default 0 check (units_sold >= 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Prevent assigning more units than are currently in stock at the time
  -- of insert.  This is re-checked atomically when sales are recorded.
  constraint consignment_items_units_chk check (units_sold <= units_to_assign)
);

create unique index if not exists uq_consignment_items_product
  on public.consignment_items (consignment_id, product_id);
create index if not exists idx_consignment_items_product
  on public.consignment_items (product_id);

-- updated_at triggers
DO $$
BEGIN
  IF to_regclass('public.set_updated_at') IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger t JOIN pg_class c ON t.tgrelid = c.oid
                   WHERE c.relname = 'consignments' AND t.tgname = 'consignments_set_updated_at') THEN
      CREATE TRIGGER consignments_set_updated_at
      BEFORE UPDATE ON public.consignments
      FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger t JOIN pg_class c ON t.tgrelid = c.oid
                   WHERE c.relname = 'consignment_items' AND t.tgname = 'consignment_items_set_updated_at') THEN
      CREATE TRIGGER consignment_items_set_updated_at
      BEFORE UPDATE ON public.consignment_items
      FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
    END IF;
  END IF;
END $$;

-- =====================================================================
-- 3. Link event_sales to a consignment allocation
--    (skipped silently if event_sales hasn't been created yet — apply
--     supabase/schema_updates_event_sales.sql first, then re-run this
--     file to wire the FKs and the sale trigger.)
-- =====================================================================
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

-- (CREATE INDEX IF NOT EXISTS still raises on a missing table, so we
-- issue it dynamically inside a DO block guarded on the table's existence.)

do $$
begin
  if to_regclass('public.event_sales') is not null then
    execute 'create index if not exists idx_event_sales_consignment
             on public.event_sales(consignment_id, consignment_item_id)
             where consignment_id is not null';
  end if;
end $$;
-- =====================================================================
-- 4. Atomic sale recorder: when a row is inserted into event_sales
--    referencing a consignment_item, increment units_sold and
--    decrement stock_qty on the underlying catalog_items row in the
--    same transaction.  Raises an exception if the allocation is
--    exhausted or stock is insufficient.
-- =====================================================================
create or replace function public.apply_consignment_sale()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_remaining integer;
  v_alloc     public.consignment_items%rowtype;
begin
  -- Only act when the sale is tied to a consignment allocation.
  if new.consignment_item_id is null then
    return new;
  end if;

  -- Lock the allocation row for update.
  select * into v_alloc
    from public.consignment_items
   where id = new.consignment_item_id
   for update;

  if not found then
    raise exception 'Consignment allocation % not found', new.consignment_item_id;
  end if;

  v_remaining := v_alloc.units_to_assign - v_alloc.units_sold;
  if new.quantity > v_remaining then
    raise exception 'Sale of % units exceeds remaining consignment allocation (%)',
      new.quantity, v_remaining;
  end if;

  -- Lock the catalog row and verify stock.
  if v_alloc.product_id is not null then
    perform 1 from public.catalog_items
      where id = v_alloc.product_id
      for update;
    if not found then
      raise exception 'Catalog item % not found', v_alloc.product_id;
    end if;
    update public.catalog_items
       set stock_qty = greatest(stock_qty - new.quantity, 0),
           updated_at = now()
     where id = v_alloc.product_id
       and stock_qty >= new.quantity;
    if not found then
      raise exception 'Insufficient stock for product %', v_alloc.product_id;
    end if;
  end if;

  -- Increment units_sold.
  update public.consignment_items
     set units_sold = units_sold + new.quantity,
         updated_at = now()
   where id = new.consignment_item_id;

  return new;
end;
$$;

-- (DROP TRIGGER IF EXISTS on a missing table also raises, so wrap the
-- whole thing in a DO block guarded on the table's existence.)

do $$
begin
  if to_regclass('public.event_sales') is not null then
    drop trigger if exists trg_apply_consignment_sale on public.event_sales;
    create trigger trg_apply_consignment_sale
      before insert on public.event_sales
      for each row execute procedure public.apply_consignment_sale();
  end if;
end $$;

-- =====================================================================
-- 5. RLS for the new tables
-- =====================================================================
alter table if exists public.consignments enable row level security;
alter table if exists public.consignment_items enable row level security;

drop policy if exists "admins_can_manage_consignments" on public.consignments;
drop policy if exists "authenticated_can_view_consignments" on public.consignments;
drop policy if exists "agents_can_view_own_consignments" on public.consignments;
drop policy if exists "agents_can_create_pending_consignments" on public.consignments;
drop policy if exists "managers_can_manage_consignments" on public.consignments;

create policy "admins_can_manage_consignments"
  on public.consignments
  for all
  to authenticated
  using (public.current_user_role_id() = 1)
  with check (public.current_user_role_id() = 1);

create policy "authenticated_can_view_consignments"
  on public.consignments
  for select
  to authenticated
  using (true);

create policy "managers_can_manage_consignments"
  on public.consignments
  for all
  to authenticated
  using (public.current_user_role_id() between 2 and 4)
  with check (public.current_user_role_id() between 2 and 4);

drop policy if exists "admins_can_manage_consignment_items" on public.consignment_items;
drop policy if exists "authenticated_can_view_consignment_items" on public.consignment_items;
drop policy if exists "managers_can_manage_consignment_items" on public.consignment_items;

create policy "admins_can_manage_consignment_items"
  on public.consignment_items
  for all
  to authenticated
  using (public.current_user_role_id() = 1)
  with check (public.current_user_role_id() = 1);

create policy "authenticated_can_view_consignment_items"
  on public.consignment_items
  for select
  to authenticated
  using (true);

create policy "managers_can_manage_consignment_items"
  on public.consignment_items
  for all
  to authenticated
  using (public.current_user_role_id() between 2 and 4)
  with check (public.current_user_role_id() between 2 and 4);

grant all on public.consignments to authenticated;
grant all on public.consignment_items to authenticated;

-- =====================================================================
-- 6. Stock validation when creating consignment items
-- =====================================================================
create or replace function public.check_consignment_item_stock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_available integer;
begin
  select stock_qty into v_available
    from public.catalog_items
   where id = new.product_id;
  if not found then
    raise exception 'Catalog item % not found', new.product_id;
  end if;
  if new.units_to_assign > v_available then
    raise exception 'Cannot assign % units; only % in stock', new.units_to_assign, v_available;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_check_consignment_item_stock on public.consignment_items;
create trigger trg_check_consignment_item_stock
  before insert or update on public.consignment_items
  for each row execute procedure public.check_consignment_item_stock();

-- End of migration
