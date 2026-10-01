-- Create table for supervisor coaching notes
CREATE TABLE IF NOT EXISTS public.supervisor_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supervisor_id UUID NOT NULL REFERENCES public.users(id),
    user_id UUID NOT NULL REFERENCES public.users(id),
    region TEXT,
    context_type TEXT, -- e.g., 'task', 'route', 'general'
    context_id UUID,
    note TEXT NOT NULL,
    follow_up_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on supervisor_notes
ALTER TABLE public.supervisor_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "supervisors_can_manage_notes"
ON public.supervisor_notes
FOR ALL
TO authenticated
USING (supervisor_id = auth.uid() OR public.is_manager_or_admin())
WITH CHECK (supervisor_id = auth.uid() OR public.is_manager_or_admin());

-- Create a view for Role 5 Performance Scorecard
-- (This aggregates data to make the UI queries faster and simpler)
CREATE OR REPLACE VIEW public.role5_performance_scorecard AS
SELECT 
    u.id AS user_id,
    u.full_name,
    u.region,
    COUNT(DISTINCT t.id) AS total_tasks,
    COUNT(DISTINCT CASE WHEN t.status = 'closed' THEN t.id END) AS completed_tasks,
    COUNT(DISTINCT r.id) AS total_routes,
    COUNT(DISTINCT CASE WHEN r.status = 'completed' THEN r.id END) AS completed_routes,
    COUNT(DISTINCT sv.id) AS total_visits
FROM public.users u
LEFT JOIN public.tasks t ON t.assigned_to = u.id AND t.created_at >= NOW() - INTERVAL '30 days'
LEFT JOIN public.route_plans r ON r.assigned_to = u.id AND r.created_at >= NOW() - INTERVAL '30 days'
LEFT JOIN public.school_visits sv ON sv.agent_id = u.id AND sv.visited_at >= NOW() - INTERVAL '30 days'
WHERE u.role = 5
GROUP BY u.id, u.full_name, u.region;
