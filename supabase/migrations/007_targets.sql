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
