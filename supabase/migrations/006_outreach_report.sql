-- Migration: outreach report missing fields
-- Date: 2026-07-30

-- =============================================================================
-- 1. SCHOOLS: add outreach report fields
-- =============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'schools'
      AND column_name = 'competitor_analysis'
  ) THEN
    ALTER TABLE public.schools ADD COLUMN competitor_analysis text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'schools'
      AND column_name = 'school_level'
  ) THEN
    ALTER TABLE public.schools ADD COLUMN school_level text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'schools'
      AND column_name = 'designation'
  ) THEN
    ALTER TABLE public.schools ADD COLUMN designation text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'schools'
      AND column_name = 'projected_quantity'
  ) THEN
    ALTER TABLE public.schools ADD COLUMN projected_quantity integer;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'schools'
      AND column_name = 'contact_email'
  ) THEN
    ALTER TABLE public.schools ADD COLUMN contact_email text;
  END IF;
END $$;

-- =============================================================================
-- 2. INDEXES for outreach filtering
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_schools_captured_by
  ON public.schools (captured_by);

CREATE INDEX IF NOT EXISTS idx_schools_competitor_analysis
  ON public.schools (competitor_analysis);

CREATE INDEX IF NOT EXISTS idx_schools_school_level
  ON public.schools (school_level);

CREATE INDEX IF NOT EXISTS idx_schools_designation
  ON public.schools (designation);

CREATE INDEX IF NOT EXISTS idx_schools_projected_quantity
  ON public.schools (projected_quantity);
