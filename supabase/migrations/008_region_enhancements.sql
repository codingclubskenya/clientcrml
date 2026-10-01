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
