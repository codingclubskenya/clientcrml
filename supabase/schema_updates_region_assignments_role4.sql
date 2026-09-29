-- Migration: Grant role 4 (agent) permission to assign regions
-- Applies to an already-deployed database. Idempotent (DROP IF EXISTS).
--
-- Previously only managers (current_user_role_id() <= 2) could manage rows in
-- `region_assignments`, which blocked role 4 agents from assigning a region on
-- the Regions Management page. This migration extends manage/read access to
-- roles 1-4 (admin, sales manager, BAS, agent) so agents can assign regions.

-- Allow roles <= 4 to manage (insert/update/delete) region assignments.
DROP POLICY IF EXISTS "managers_can_manage_region_assignments" ON public.region_assignments;
CREATE POLICY "managers_can_manage_region_assignments"
ON public.region_assignments
FOR ALL
TO authenticated
USING (public.current_user_role_id() <= 4)
WITH CHECK (public.current_user_role_id() <= 4);

-- Allow roles <= 4 to read region assignments (not only their own).
DROP POLICY IF EXISTS "users_can_view_own_region_assignments" ON public.region_assignments;
CREATE POLICY "users_can_view_own_region_assignments"
ON public.region_assignments
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  OR public.current_user_role_id() <= 4
);


-- Allow role 4 agents to create a region when they do not yet have one.
DROP POLICY IF EXISTS "managers_can_manage_regions" ON public.regions;
CREATE POLICY "managers_can_manage_regions"
ON public.regions
FOR ALL
TO authenticated
USING (public.current_user_role_id() <= 4)
WITH CHECK (public.current_user_role_id() <= 4);


-- Let role 4 users create and assign route-plan to-do items to role 4/5
-- members in their region.
DROP POLICY IF EXISTS "authenticated_can_view_route_plans" ON public.route_plans;
CREATE POLICY "authenticated_can_view_route_plans"
ON public.route_plans FOR SELECT TO authenticated
USING (
  assigned_to = auth.uid()
  OR assigned_to IS NULL
  OR public.current_user_role_id() <= 2
  OR (
    public.current_user_role_id() <= 4
    AND EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = public.route_plans.assigned_to
        AND u.role IN (4, 5)
        AND lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
    )
  )
);

DROP POLICY IF EXISTS "managers_can_manage_route_plans" ON public.route_plans;
CREATE POLICY "managers_can_manage_route_plans"
ON public.route_plans FOR ALL TO authenticated
USING (
  public.current_user_role_id() <= 2
  OR (
    public.current_user_role_id() <= 4
    AND assigned_to IS NULL
  )
  OR (
    public.current_user_role_id() <= 4
    AND EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = public.route_plans.assigned_to
        AND u.role IN (4, 5)
        AND lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
    )
  )
)
WITH CHECK (
  public.current_user_role_id() <= 2
  OR (
    public.current_user_role_id() <= 4
    AND assigned_to IS NULL
  )
  OR (
    public.current_user_role_id() <= 4
    AND EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = public.route_plans.assigned_to
        AND u.role IN (4, 5)
        AND lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
    )
  )
);

DROP POLICY IF EXISTS "managers_can_manage_tasks" ON public.tasks;
CREATE POLICY "managers_can_manage_tasks"
ON public.tasks FOR ALL TO authenticated
USING (
  public.current_user_role_id() <= 2
  OR assigned_to = auth.uid()
  OR (
    public.current_user_role_id() <= 4
    AND EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = public.tasks.assigned_to
        AND u.role IN (4, 5)
        AND lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
    )
  )
)
WITH CHECK (
  public.current_user_role_id() <= 2
  OR assigned_to = auth.uid()
  OR (
    public.current_user_role_id() <= 4
    AND EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = public.tasks.assigned_to
        AND u.role IN (4, 5)
        AND lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
    )
  )
);
