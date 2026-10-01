-- Create a function to find potential duplicates across the entire schools table
create or replace function public.get_potential_duplicates()
returns table (
  id uuid,
  name text,
  phone text,
  duplicate_id uuid,
  duplicate_name text,
  reason text
)
language plpgsql
security definer
as $$
begin
  return query
  select 
    s1.id, 
    s1.name, 
    s1.phone, 
    s2.id as duplicate_id, 
    s2.name as duplicate_name,
    case 
      when s1.phone = s2.phone then 'Matching Phone Number'
      when lower(s1.name) = lower(s2.name) then 'Matching Name'
      else 'High Similarity'
    end as reason
  from public.schools s1
  join public.schools s2 on s1.id < s2.id
  where s1.phone = s2.phone 
     or lower(s1.name) = lower(s2.name);
end;
$$;
