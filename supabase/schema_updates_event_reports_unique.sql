-- Add unique constraint to event_reports for proper upsert support
-- This ensures each event can only have one report

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'event_reports_event_id_key'
      and conrelid = 'public.event_reports'::regclass
  ) then
    alter table public.event_reports
      add constraint event_reports_event_id_key unique (event_id);
  end if;
end $$;

-- End of migration
