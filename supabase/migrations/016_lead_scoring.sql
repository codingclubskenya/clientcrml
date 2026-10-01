-- Add lead_score column to schools
do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'lead_score') then
    alter table public.schools add column lead_score integer not null default 0;
  end if;
end $$;

-- Create lead scoring function
create or replace function public.calculate_lead_score()
returns trigger
language plpgsql
security definer
as $$
declare
  v_score integer := 0;
  v_pop integer := coalesce(new.school_population, 0);
  v_cat text := lower(coalesce(new.book_category, ''));
  v_focus_count integer := 0;
begin
  -- Population scoring
  if v_pop > 1000 then
    v_score := v_score + 40;
  elsif v_pop >= 500 then
    v_score := v_score + 20;
  elsif v_pop > 0 then
    v_score := v_score + 10;
  end if;

  -- Category scoring
  if v_cat like '%book fund%' then
    v_score := v_score + 30;
  end if;

  -- Focus Areas scoring
  if new."focusAreas" is not null then
    v_focus_count := jsonb_array_length(new."focusAreas");
    v_score := v_score + least(v_focus_count * 10, 30);
  end if;

  new.lead_score := v_score;
  return new;
end;
$$;

-- Create trigger
drop trigger if exists update_lead_score_trigger on public.schools;
create trigger update_lead_score_trigger
before insert or update on public.schools
for each row execute procedure public.calculate_lead_score();

-- Backfill existing schools
update public.schools set updated_at = now();
