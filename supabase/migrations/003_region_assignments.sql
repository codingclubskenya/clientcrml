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
