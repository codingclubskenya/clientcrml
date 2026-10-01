-- Updates for newly added Dashboard, Analytics, Geofencing, and Assignment features

-- 0. Update Tasks Table for Individual Assignment and Time Filtering
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS assigned_to UUID REFERENCES public.users(id) ON DELETE SET NULL;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS due_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS target_role INTEGER NOT NULL DEFAULT 2;

-- 0b. Schools table updates for onboarding tracking + external discovery
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'manual';
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS external_place_id TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS external_vicinity TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS contact_name TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS contact_phone TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS contact_title TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS feedback TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS samples_left TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS sample_books TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS school_ownership TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS school_ownership_other TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS school_population INTEGER;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS school_lifecycle_status TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS engagement_type TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS dealer_type TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS shop_category TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS selected_product TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS partner_subtype TEXT;
ALTER TABLE public.school_sample_distributions ADD COLUMN IF NOT EXISTS stamped_receipt_url TEXT;
ALTER TABLE public.school_sample_distributions ADD COLUMN IF NOT EXISTS stamped_receipt_path TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_schools_external_place_id
ON public.schools (external_place_id)
WHERE external_place_id IS NOT NULL;

DO $$ BEGIN
    ALTER TABLE public.schools
    DROP CONSTRAINT IF EXISTS schools_source_check;
    ALTER TABLE public.schools
    ADD CONSTRAINT schools_source_check CHECK (source IN ('manual', 'google'));
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- 1. Route Plans Table
CREATE TABLE IF NOT EXISTS public.route_plans (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL DEFAULT 'Route Plan',
    route_date DATE NOT NULL DEFAULT CURRENT_DATE,
    assigned_to UUID REFERENCES public.users(id) ON DELETE CASCADE,
    school_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'assigned',
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    "isSynced" BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Geofences Table
CREATE TABLE IF NOT EXISTS public.geofences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    coordinates JSONB NOT NULL DEFAULT '[]'::jsonb,
    assigned_to UUID REFERENCES public.users(id) ON DELETE CASCADE,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. School Sample Distributions Table
CREATE TABLE IF NOT EXISTS public.school_sample_distributions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    agent_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    sample_name TEXT NOT NULL,
    sample_category TEXT,
    quantity INTEGER NOT NULL DEFAULT 1,
    notes TEXT,
    distributed_at TIMESTAMP WITH TIME ZONE,
    "isSynced" BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3b. Debt Collections Table
CREATE TABLE IF NOT EXISTS public.debt_collections (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    collected_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    payment_method TEXT NOT NULL DEFAULT 'cash',
    payment_reference TEXT,
    notes TEXT,
    collected_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Catalog Items Table
CREATE TABLE IF NOT EXISTS public.catalog_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT,
    sku TEXT UNIQUE,
    item_type TEXT NOT NULL DEFAULT 'sale',
    unit_price NUMERIC(12,2) NOT NULL DEFAULT 0,
    stock_qty INTEGER NOT NULL DEFAULT 0,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    "isSynced" BOOLEAN NOT NULL DEFAULT false,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Orders Table (For Revenue Analytics)
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID REFERENCES public.schools(id) ON DELETE SET NULL,
    school_name TEXT NOT NULL,
    school_phone TEXT,
    agent_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    order_number TEXT UNIQUE,
    payment_method TEXT NOT NULL DEFAULT 'cash',
    payment_reference TEXT,
    checkout_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending',
    notes TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE,
    approved_at TIMESTAMP WITH TIME ZONE,
    "isSynced" BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE OR REPLACE FUNCTION public.create_school_sale_checkout(
    order_payload jsonb,
    items_payload jsonb DEFAULT '[]'::jsonb,
    sale_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    v_now timestamptz := now();
    v_order_id uuid := coalesce(nullif(order_payload->>'id', '')::uuid, gen_random_uuid());
    v_order_number text := coalesce(nullif(order_payload->>'order_number', ''), 'ORD-' || to_char(v_now, 'YYYYMMDDHH24MISSMS') || '-' || upper(substring(replace(gen_random_uuid()::text, '-', '') from 1 for 8)));
    v_sale_id uuid := coalesce(nullif(sale_payload->>'id', '')::uuid, gen_random_uuid());
    v_order public.orders%rowtype;
    v_sale public.school_sales%rowtype;
BEGIN
    INSERT INTO public.orders (
        id,
        school_id,
        school_name,
        school_phone,
        agent_id,
        order_number,
        payment_method,
        payment_reference,
        checkout_amount,
        status,
        notes,
        submitted_at,
        approved_at,
        "isSynced",
        created_at,
        updated_at
    ) VALUES (
        v_order_id,
        nullif(order_payload->>'school_id', '')::uuid,
        coalesce(nullif(order_payload->>'school_name', ''), 'School'),
        nullif(order_payload->>'school_phone', ''),
        nullif(order_payload->>'agent_id', '')::uuid,
        v_order_number,
        coalesce(nullif(order_payload->>'payment_method', ''), 'cash'),
        nullif(order_payload->>'payment_reference', ''),
        coalesce((order_payload->>'checkout_amount')::numeric, 0),
        coalesce(nullif(order_payload->>'status', ''), 'pending'),
        nullif(order_payload->>'notes', ''),
        coalesce((order_payload->>'submitted_at')::timestamptz, v_now),
        (order_payload->>'approved_at')::timestamptz,
        coalesce((order_payload->>'isSynced')::boolean, false),
        coalesce((order_payload->>'created_at')::timestamptz, v_now),
        coalesce((order_payload->>'updated_at')::timestamptz, v_now)
    )
    RETURNING * INTO v_order;

    IF items_payload IS NOT NULL AND jsonb_typeof(items_payload) = 'array' THEN
        INSERT INTO public.order_items (
            id,
            order_id,
            product_name,
            category,
            sku,
            quantity,
            unit_price,
            line_total,
            notes,
            "isSynced",
            created_at,
            updated_at
        )
        SELECT
            coalesce(nullif(item->>'id', '')::uuid, gen_random_uuid()),
            v_order.id,
            coalesce(nullif(item->>'product_name', ''), 'Item'),
            nullif(item->>'category', ''),
            nullif(item->>'sku', ''),
            coalesce((item->>'quantity')::integer, 1),
            coalesce((item->>'unit_price')::numeric, 0),
            coalesce((item->>'line_total')::numeric, 0),
            nullif(item->>'notes', ''),
            coalesce((item->>'isSynced')::boolean, false),
            coalesce((item->>'created_at')::timestamptz, v_now),
            coalesce((item->>'updated_at')::timestamptz, v_now)
        FROM jsonb_array_elements(items_payload) AS item;
    END IF;

    INSERT INTO public.school_sales (
        id,
        school_id,
        agent_id,
        package_name,
        expected_value,
        notes,
        sale_status,
        stage_updated_at,
        expected_close_date,
        probability,
        closed_at,
        "isSynced",
        created_at,
        updated_at
    ) VALUES (
        v_sale_id,
        coalesce(nullif(sale_payload->>'school_id', '')::uuid, v_order.school_id),
        nullif(sale_payload->>'agent_id', '')::uuid,
        coalesce(nullif(sale_payload->>'package_name', ''), 'School Package'),
        coalesce((sale_payload->>'expected_value')::numeric, v_order.checkout_amount),
        nullif(sale_payload->>'notes', ''),
        coalesce(nullif(sale_payload->>'sale_status', ''), 'won'),
        coalesce((sale_payload->>'stage_updated_at')::timestamptz, v_now),
        (sale_payload->>'expected_close_date')::date,
        coalesce((sale_payload->>'probability')::integer, 100),
        coalesce((sale_payload->>'closed_at')::timestamptz, v_now),
        coalesce((sale_payload->>'isSynced')::boolean, false),
        coalesce((sale_payload->>'created_at')::timestamptz, v_now),
        coalesce((sale_payload->>'updated_at')::timestamptz, v_now)
    )
    ON CONFLICT (id) DO UPDATE SET
        school_id = EXCLUDED.school_id,
        agent_id = EXCLUDED.agent_id,
        package_name = EXCLUDED.package_name,
        expected_value = EXCLUDED.expected_value,
        notes = EXCLUDED.notes,
        sale_status = EXCLUDED.sale_status,
        stage_updated_at = EXCLUDED.stage_updated_at,
        expected_close_date = EXCLUDED.expected_close_date,
        probability = EXCLUDED.probability,
        closed_at = EXCLUDED.closed_at,
        "isSynced" = EXCLUDED."isSynced",
        updated_at = EXCLUDED.updated_at
    RETURNING * INTO v_sale;

    RETURN jsonb_build_object(
        'order', to_jsonb(v_order),
        'sale', to_jsonb(v_sale)
    );
END;
$$;

-- 6. School Sales Pipeline migrations
-- Source of truth schema lives in schema.sql; keep only ALTER/DO migrations here.

DO $$ BEGIN
    ALTER TABLE public.school_sales
        ADD COLUMN IF NOT EXISTS stage_contact_person TEXT,
        ADD COLUMN IF NOT EXISTS sample_quantity INTEGER,
        ADD COLUMN IF NOT EXISTS quotation_reference TEXT,
        ADD COLUMN IF NOT EXISTS decision_owner TEXT,
        ADD COLUMN IF NOT EXISTS negotiation_topic TEXT,
        ADD COLUMN IF NOT EXISTS loss_reason TEXT,
        ADD COLUMN IF NOT EXISTS dormant_reason TEXT,
        ADD COLUMN IF NOT EXISTS stage_updated_at TIMESTAMP WITH TIME ZONE,
        ADD COLUMN IF NOT EXISTS expected_close_date DATE,
        ADD COLUMN IF NOT EXISTS probability INTEGER NOT NULL DEFAULT 0;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.pipeline_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    pipeline_id UUID NOT NULL REFERENCES public.school_sales(id) ON DELETE CASCADE,
    old_stage TEXT,
    new_stage TEXT NOT NULL,
    changed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    changed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_pipeline_history_pipeline_id
ON public.pipeline_history (pipeline_id);

CREATE INDEX IF NOT EXISTS idx_pipeline_history_changed_at
ON public.pipeline_history (changed_at DESC);

CREATE OR REPLACE FUNCTION public.log_pipeline_stage_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.pipeline_history (pipeline_id, old_stage, new_stage, changed_by, notes)
        VALUES (NEW.id, NULL, NEW.sale_status, auth.uid(), NEW.notes);
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND coalesce(NEW.sale_status, '') <> coalesce(OLD.sale_status, '') THEN
        INSERT INTO public.pipeline_history (pipeline_id, old_stage, new_stage, changed_by, notes)
        VALUES (NEW.id, OLD.sale_status, NEW.sale_status, auth.uid(), NEW.notes);
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_school_sales_stage_change ON public.school_sales;
CREATE TRIGGER log_school_sales_stage_change
AFTER INSERT OR UPDATE ON public.school_sales
FOR EACH ROW EXECUTE PROCEDURE public.log_pipeline_stage_change();

DO $$ BEGIN
    UPDATE public.school_sales
    SET sale_status = 'lead'
    WHERE sale_status IN ('draft', 'pipeline') OR sale_status IS NULL;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE public.school_sales
    ALTER COLUMN sale_status SET DEFAULT 'lead';
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE public.school_sales
    DROP CONSTRAINT IF EXISTS school_sales_sale_status_check;
    ALTER TABLE public.school_sales
    DROP CONSTRAINT IF EXISTS school_sales_sample_quantity_check;
    ALTER TABLE public.school_sales
    ADD CONSTRAINT school_sales_sale_status_check CHECK (
        sale_status IN (
            'lead',
            'contacted',
            'meeting_scheduled',
            'sample_issued',
            'quotation_sent',
            'decision_pending',
            'negotiation',
            'won',
            'lost',
            'dormant'
        )
    );
    ALTER TABLE public.school_sales
    ADD CONSTRAINT school_sales_sample_quantity_check CHECK (
        sample_quantity IS NULL OR sample_quantity >= 0
    );
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- Enable Row Level Security (RLS) on all new tables
ALTER TABLE public.route_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.geofences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_sample_distributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalog_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pipeline_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.debt_collections ENABLE ROW LEVEL SECURITY;

-- Optional: Re-create missing permissive policies if needed
-- (Your schema.sql handles granular RLS policies already, these act as fallbacks if missing)
DO $$ BEGIN
    CREATE POLICY "Allow authenticated full access on route_plans" ON public.route_plans FOR ALL TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "authenticated_can_view_pipeline_history"
    ON public.pipeline_history
    FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1
        FROM public.school_sales s
        WHERE s.id = pipeline_id
          AND (s.agent_id = auth.uid() OR public.is_manager_or_admin())
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "authenticated_can_delete_messages"
    ON public.messages
    FOR DELETE
    TO authenticated
    USING (
      sender_id = auth.uid()
      OR recipient_id = auth.uid()
      OR public.is_manager_or_admin()
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "authenticated_can_manage_debt_collections"
    ON public.debt_collections
    FOR ALL
    TO authenticated
    USING (collected_by = auth.uid() OR public.is_manager_or_admin())
    WITH CHECK (collected_by = auth.uid() OR public.is_manager_or_admin());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Social inbox sync tables for Facebook + WhatsApp bot
CREATE TABLE IF NOT EXISTS public.social_conversations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    channel text NOT NULL CHECK (channel IN ('facebook', 'whatsapp')),
    external_conversation_id text NOT NULL,
    participant_display text,
    participant_phone text,
    last_message_preview text,
    last_message_at timestamptz,
    raw_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    UNIQUE (channel, external_conversation_id)
);

CREATE TABLE IF NOT EXISTS public.social_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id uuid NOT NULL REFERENCES public.social_conversations(id) ON DELETE CASCADE,
    channel text NOT NULL CHECK (channel IN ('facebook', 'whatsapp')),
    external_message_id text NOT NULL,
    sender_name text,
    sender_id text,
    body text,
    sent_at timestamptz,
    raw_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    UNIQUE (channel, external_message_id)
);

ALTER TABLE public.social_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_messages ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "authenticated_can_view_social_conversations"
    ON public.social_conversations
    FOR SELECT
    TO authenticated
    USING (public.is_manager_or_admin());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "service_role_can_manage_social_conversations"
    ON public.social_conversations
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "authenticated_can_view_social_messages"
    ON public.social_messages
    FOR SELECT
    TO authenticated
    USING (public.is_manager_or_admin());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "service_role_can_manage_social_messages"
    ON public.social_messages
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Stamped sample proof fields on schools
ALTER TABLE public.schools
ADD COLUMN IF NOT EXISTS sample_proof_url TEXT;

ALTER TABLE public.schools
ADD COLUMN IF NOT EXISTS sample_proof_path TEXT;

-- ROI support for sample distribution (Role 5 and admin analytics)
CREATE INDEX IF NOT EXISTS idx_sample_distributions_agent_school
ON public.school_sample_distributions (agent_id, school_id, distributed_at DESC);

CREATE INDEX IF NOT EXISTS idx_orders_agent_status
ON public.orders (agent_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_school_sales_agent_stage
ON public.school_sales (agent_id, sale_status, created_at DESC);

CREATE OR REPLACE VIEW public.v_agent_sample_roi AS
WITH sample_stats AS (
  SELECT
    d.agent_id,
    COALESCE(SUM(d.quantity), 0)::int AS samples_given,
    COUNT(DISTINCT d.school_id)::int AS schools_reached
  FROM public.school_sample_distributions d
  WHERE d.agent_id IS NOT NULL
  GROUP BY d.agent_id
),
revenue_stats AS (
  SELECT
    o.agent_id,
    COALESCE(
      SUM(
        CASE
          WHEN LOWER(COALESCE(o.status, '')) IN ('approved', 'paid')
          THEN COALESCE(o.checkout_amount, 0)
          ELSE 0
        END
      ),
      0
    )::numeric(12,2) AS revenue_earned
  FROM public.orders o
  WHERE o.agent_id IS NOT NULL
  GROUP BY o.agent_id
),
won_stats AS (
  SELECT
    s.agent_id,
    COALESCE(
      SUM(
        CASE
          WHEN LOWER(COALESCE(s.sale_status, '')) = 'won'
          THEN COALESCE(s.expected_value, 0)
          ELSE 0
        END
      ),
      0
    )::numeric(12,2) AS won_value
  FROM public.school_sales s
  WHERE s.agent_id IS NOT NULL
  GROUP BY s.agent_id
)
SELECT
  u.id AS agent_id,
  COALESCE(u.full_name, u.email, 'Unknown User') AS agent_name,
  COALESCE(ss.samples_given, 0) AS samples_given,
  COALESCE(ss.schools_reached, 0) AS schools_reached,
  COALESCE(rs.revenue_earned, 0)::numeric(12,2) AS revenue_earned,
  COALESCE(ws.won_value, 0)::numeric(12,2) AS won_value
FROM public.users u
LEFT JOIN sample_stats ss ON ss.agent_id = u.id
LEFT JOIN revenue_stats rs ON rs.agent_id = u.id
LEFT JOIN won_stats ws ON ws.agent_id = u.id
WHERE u.role IN (4, 5);
