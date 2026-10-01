-- Migration: role 1 region dashboard additions + role 5 onboarding field updates
-- Date: 2026-07-09

-- =============================================================================
-- 1. ROLE 5 ONBOARDING: Migrate existing Distributor records to Institution
-- =============================================================================
UPDATE public.schools
SET dealer_type = 'Institution'
WHERE lower(dealer_type) = 'distributor';

UPDATE public.schools
SET shop_category = 'Distributor'
WHERE lower(shop_category) = 'independent';

-- =============================================================================
-- 2. ROLE 5 ONBOARDING: Add new columns for expanded onboarding fields
-- =============================================================================
-- samples_to_be_returned: new Yes/No indicator for sample returns
ALTER TABLE public.schools
  ADD COLUMN IF NOT EXISTS samples_to_be_returned text;

-- learning_materials: multi-select stock for Bookshop / Institution (Course Books, ECD Books, Reference, Teacher Guides)
ALTER TABLE public.schools
  ADD COLUMN IF NOT EXISTS learning_materials jsonb DEFAULT '[]'::jsonb;

-- institution_category_other: free-text subcategory when partner_subtype = 'Others' for Institutions
ALTER TABLE public.schools
  ADD COLUMN IF NOT EXISTS institution_category_other text;

-- book_programs: expanded multi-select for School Book Program (Book List, Book Fund)
ALTER TABLE public.schools
  ADD COLUMN IF NOT EXISTS book_programs jsonb DEFAULT '[]'::jsonb;

-- =============================================================================
-- 3. ROLE 1 REGION SECTION: Index optimization for regional aggregation queries
-- =============================================================================
-- The new admin Regions page aggregates sales, visits, and schools by region.
-- It derives region from users.region or schools.county. Add composite indexes
-- to keep those queries fast as data grows.
CREATE INDEX IF NOT EXISTS idx_schools_county_captured_at
  ON public.schools (county, captured_at);

CREATE INDEX IF NOT EXISTS idx_school_visits_school_visited_at
  ON public.school_visits (school_id, visited_at);

CREATE INDEX IF NOT EXISTS idx_school_sales_school_created
  ON public.school_sales (school_id, created_at);

-- =============================================================================
-- 5. REGIONS TABLE: structured region/sub-region/county master data
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.regions (
  id uuid primary key default gen_random_uuid(),
  region text not null,
  sub_region text not null,
  counties text,
  assigned_to uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'regions' AND column_name = 'assigned_to') THEN
    ALTER TABLE public.regions ADD COLUMN assigned_to uuid references public.users (id) on delete set null;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'regions' AND column_name = 'counties') THEN
    ALTER TABLE public.regions ADD COLUMN counties text;
  END IF;
END $$;

DROP TRIGGER IF EXISTS touch_regions_updated_at ON public.regions;
CREATE TRIGGER touch_regions_updated_at
BEFORE UPDATE ON public.regions
FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

ALTER TABLE public.regions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "managers_can_manage_regions" ON public.regions;
CREATE POLICY "managers_can_manage_regions"
ON public.regions
FOR ALL
TO authenticated
USING (public.current_user_role_id() <= 2)
WITH CHECK (public.current_user_role_id() <= 2);

DROP POLICY IF EXISTS "authenticated_can_view_regions" ON public.regions;
CREATE POLICY "authenticated_can_view_regions"
ON public.regions
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "agents_can_view_assigned_region" ON public.regions;
CREATE POLICY "agents_can_view_assigned_region"
ON public.regions
FOR SELECT
TO authenticated
USING (
  assigned_to = auth.uid()
  OR public.current_user_role_id() <= 2
);

CREATE INDEX IF NOT EXISTS idx_regions_region_sub_region
  ON public.regions (region, sub_region);

CREATE INDEX IF NOT EXISTS idx_regions_assigned_to
  ON public.regions (assigned_to);

DO $$
BEGIN
  IF to_regclass('public.users') IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'region_id') THEN
      ALTER TABLE public.users ADD COLUMN region_id uuid references public.regions (id) on delete set null;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'sub_region') THEN
      ALTER TABLE public.users ADD COLUMN sub_region text;
    END IF;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_users_region_id
  ON public.users (region_id);

INSERT INTO public.regions (region, sub_region, counties) VALUES
('Nairobi North', 'Nairobi North', 'Kasarani, Embakasi East, Embakasi West, Kiambu'),
('Nairobi North', 'Embakasi', 'Embakasi North, Embakasi South, Embakasi Central'),
('Nairobi North', 'Kiambu East', 'Gatundu North, Gatundu South, Juja, Thika Town, Ruiru'),
('Nairobi North', 'Kiambu West', 'Kiambaa, Kikuyu, Kabete, Limuru, Lari, Githunguri'),
('Nairobi North', 'Murang''a', 'Murang''a County'),
('Nairobi South', 'Nairobi South', 'Starehe, Westlands, Dagoretti North, Dagoretti South'),
('Nairobi South', 'Kajiado', 'Kajiado County'),
('Nairobi South', 'Machakos', 'Machakos County'),
('Nairobi South', 'Nairobi Central', 'Kamukunji, Makadara, Lang''ata'),
('Lake', 'South Western', 'Bungoma, Busia'),
('Lake', 'South Nyanza', 'Kisii, Nyamira, Migori'),
('Lake', 'North Nyanza', 'Siaya, Homa Bay, Kisumu'),
('Lake', 'North Western', 'Kakamega, Vihiga'),
('South Rift', 'South Rift', 'Narok, Nyandarua, Laikipia, Samburu'),
('South Rift', 'Central Rift', 'Nakuru, Baringo'),
('South Rift', 'South Rift', 'Bomet, Kericho'),
('North Rift', 'North Rift', 'Turkana, Uasin Gishu'),
('North Rift', 'North Rift', 'Trans Nzoia, West Pokot'),
('Coast', 'North Coast', 'Kilifi, Tana River, Lamu'),
('Coast', 'South Coast', 'Taita Taveta, Kwale, Mombasa'),
('Coast', 'Lower Eastern', 'Makueni, Kitui, Garissa'),
('Mt Kenya', 'Mt Kenya East', 'Meru, Isiolo, Marsabit, Wajir'),
('Mt Kenya', 'Mt Kenya West', 'Nyeri, Kirinyaga'),
('Mt Kenya', 'Mt Kenya South', 'Embu, Tharaka Nithi'),
('National', 'National', 'National')
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- 6. ROLE 5 ONBOARDING: Backfill / cleanup notes
-- =============================================================================
-- Reset free-text fields for fresh onboarding data shape
UPDATE public.schools
SET institution_category_other = NULL
WHERE dealer_type = 'Institution';

-- Ensure nullsafe for new columns on existing rows
UPDATE public.schools
SET samples_to_be_returned = NULL,
    learning_materials = '[]'::jsonb,
    book_programs = '[]'::jsonb
WHERE samples_to_be_returned IS NULL
   OR learning_materials IS NULL
   OR book_programs IS NULL;
