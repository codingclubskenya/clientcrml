-- Schema updates: Event module (safe to rerun)
-- Adds events, assignments, checkins, tasks, leads, event_orders, samples, photos, expenses, reports

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  event_type text,
  organization text,
  venue text,
  region text,
  subregion text,
  start_at timestamptz,
  end_at timestamptz,
  expected_attendance integer,
  budget numeric(12,2),
  objectives text,
  products jsonb default '[]'::jsonb,
  notes text,
  status text not null default 'scheduled',
  created_by uuid references auth.users (id) on delete set null,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Assign sales agents to events with targets and materials
create table if not exists public.event_assignments (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  agent_id uuid not null references public.users (id) on delete cascade,
  assigned_by uuid references auth.users (id) on delete set null,
  schedule jsonb default '{}'::jsonb,
  products jsonb default '[]'::jsonb,
  samples jsonb default '[]'::jsonb,
  marketing_materials jsonb default '[]'::jsonb,
  targets jsonb default '{}'::jsonb,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_event_assignments_event_agent on public.event_assignments(event_id, agent_id);

-- Check-ins for attendance verification
create table if not exists public.event_checkins (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  agent_id uuid not null references public.users (id) on delete cascade,
  checkin_at timestamptz not null default now(),
  gps_lat double precision,
  gps_lng double precision,
  geofence_verified boolean default false,
  qr_verified boolean default false,
  selfie_url text,
  checkin_type text not null default 'checkin', -- checkin | checkout
  location_text text,
  notes text
);

create index if not exists idx_event_checkins_event_agent on public.event_checkins(event_id, agent_id);

-- Event task list
create table if not exists public.event_tasks (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  title text not null,
  description text,
  required boolean not null default true,
  completed boolean not null default false,
  completed_by uuid references public.users (id) on delete set null,
  completed_at timestamptz,
  evidence_url text,
  sort_order integer default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_event_tasks_event_completed on public.event_tasks(event_id, completed);

-- Leads captured at events
create table if not exists public.event_leads (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  agent_id uuid references public.users (id) on delete set null,
  lead_name text,
  school_id uuid references public.schools (id) on delete set null,
  phone text,
  email text,
  interested_products jsonb default '[]'::jsonb,
  purchase_timeline text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_event_leads_event_agent on public.event_leads(event_id, agent_id);

-- Record orders created during events: link into existing orders table
create table if not exists public.event_orders (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  order_id uuid not null references public.orders (id) on delete cascade,
  agent_id uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists idx_event_orders_event on public.event_orders(event_id);

-- Sample distribution
create table if not exists public.event_samples (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  product_id uuid references public.catalog_items (id) on delete set null,
  quantity integer not null default 0,
  recipient text,
  recipient_signature text,
  distributed_by uuid references public.users (id) on delete set null,
  distributed_at timestamptz not null default now(),
  notes text
);
create index if not exists idx_event_samples_event_prod on public.event_samples(event_id, product_id);

-- Photos / evidence
create table if not exists public.event_photos (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  agent_id uuid references public.users (id) on delete set null,
  photo_url text,
  photo_path text,
  photo_type text,
  caption text,
  uploaded_at timestamptz not null default now()
);
create index if not exists idx_event_photos_event on public.event_photos(event_id);

-- Expenses submitted by agents
create table if not exists public.event_expenses (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  submitted_by uuid references public.users (id) on delete set null,
  expense_type text,
  amount numeric(12,2) not null default 0,
  currency text default 'KES',
  receipt_url text,
  status text not null default 'pending', -- pending | approved | rejected
  approved_by uuid references public.users (id) on delete set null,
  approved_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_event_expenses_event_status on public.event_expenses(event_id, status);

-- Event reports
create table if not exists public.event_reports (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  created_by uuid references public.users (id) on delete set null,
  summary text,
  attendance_count integer default 0,
  visitors_count integer default 0,
  schools_count integer default 0,
  qualified_leads_count integer default 0,
  orders_count integer default 0,
  revenue numeric(14,2) default 0,
  photos jsonb default '[]'::jsonb,
  gps_logs jsonb default '[]'::jsonb,
  expenses_summary jsonb default '{}'::jsonb,
  products_sold jsonb default '[]'::jsonb,
  challenges text,
  recommendations text,
  exported_pdf_url text,
  exported_xlsx_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_event_reports_event on public.event_reports(event_id);

-- Refresh updated_at via existing public.set_updated_at trigger if present
DO $$
BEGIN
  IF to_regclass('public.set_updated_at') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_trigger t
      JOIN pg_class c ON t.tgrelid = c.oid
      WHERE c.relname = 'events' AND t.tgname = 'events_set_updated_at'
    ) THEN
      CREATE TRIGGER events_set_updated_at
      BEFORE UPDATE ON public.events
      FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_trigger t
      JOIN pg_class c ON t.tgrelid = c.oid
      WHERE c.relname = 'event_assignments' AND t.tgname = 'event_assignments_set_updated_at'
    ) THEN
      CREATE TRIGGER event_assignments_set_updated_at
      BEFORE UPDATE ON public.event_assignments
      FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_trigger t
      JOIN pg_class c ON t.tgrelid = c.oid
      WHERE c.relname = 'event_tasks' AND t.tgname = 'event_tasks_set_updated_at'
    ) THEN
      CREATE TRIGGER event_tasks_set_updated_at
      BEFORE UPDATE ON public.event_tasks
      FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_trigger t
      JOIN pg_class c ON t.tgrelid = c.oid
      WHERE c.relname = 'event_reports' AND t.tgname = 'event_reports_set_updated_at'
    ) THEN
      CREATE TRIGGER event_reports_set_updated_at
      BEFORE UPDATE ON public.event_reports
      FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
    END IF;
  END IF;
END$$;

-- Optional: basic privilege guidance (owners may ALTER as needed)

-- Dummy event for testing (safe to rerun)
INSERT INTO public.events (
  id, name, event_type, organization, venue, region, subregion,
  start_at, end_at, expected_attendance, budget, objectives, products, notes, status, "isSynced", created_at, updated_at
) VALUES (
  '11111111-1111-4111-8111-111111111111',
  'Back to School Activation (Dummy)',
  'Activation',
  'ACME Books',
  'Green Valley School',
  'Nairobi',
  'West',
  '2026-08-20T09:00:00+03:00'::timestamptz,
  '2026-08-20T15:00:00+03:00'::timestamptz,
  300,
  50000.00,
  'Promote textbooks',
  '[{"product":"Mathematics Books","qty":40},{"product":"English Books","qty":20}]'::jsonb,
  'Dummy event for testing',
  'scheduled',
  false,
  now(), now()
) ON CONFLICT (id) DO NOTHING;

-- End of event module schema updates
