-- Migration script to ensure tasks, visitations, and route_plans tables are correctly set up
-- These tables back the agent route plan checklist and the dynamic route plan selector.

CREATE TABLE IF NOT EXISTS public.tasks (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    target_role INT DEFAULT 2,
    due_at TIMESTAMPTZ,
    status TEXT DEFAULT 'open',
    assigned_to UUID REFERENCES auth.users(id),
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.visitations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    assigned_to UUID REFERENCES auth.users(id),
    visit_date DATE,
    status TEXT DEFAULT 'pending',
    notes TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- route_plans are created by supervisors/agents (see role2_route_plan_page.dart)
-- and store the ordered list of school ids (school_ids JSONB) for a given route date.
-- The agent route plan checklist selector loads these dynamically so an agent can
-- apply an existing plan (turning its school_ids into visitations) or create a new one.
CREATE TABLE IF NOT EXISTS public.route_plans (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    route_date DATE NOT NULL,
    assigned_to UUID REFERENCES auth.users(id),
    school_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'assigned',
    created_by UUID REFERENCES auth.users(id),
    "isSynced" BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Helper columns used for review workflows
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'route_plans'
          AND column_name = 'reviewed_by'
    ) THEN
        ALTER TABLE public.route_plans ADD COLUMN reviewed_by UUID REFERENCES public.users (id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'route_plans'
          AND column_name = 'reviewed_at'
    ) THEN
        ALTER TABLE public.route_plans ADD COLUMN reviewed_at TIMESTAMPTZ;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'route_plans'
          AND column_name = 'review_note'
    ) THEN
        ALTER TABLE public.route_plans ADD COLUMN review_note TEXT;
    END IF;
END $$;

-- Status constraint to keep route plan state consistent
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'route_plans_status_check'
          AND conrelid = 'public.route_plans'::regclass
    ) THEN
        ALTER TABLE public.route_plans
            ADD CONSTRAINT route_plans_status_check
            CHECK (status IN ('draft', 'submitted', 'approved', 'rejected', 'assigned', 'in_progress', 'completed'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_visitations_assigned_date
    ON public.visitations(assigned_to, visit_date);

CREATE INDEX IF NOT EXISTS idx_route_plans_assigned_date_status
    ON public.route_plans(assigned_to, route_date, status);

-- Note: Ensure policies and privileges are set for all tables based on your RLS setup.
