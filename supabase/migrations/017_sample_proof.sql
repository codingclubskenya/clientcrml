-- Add stamped sample proof fields on schools
begin;

alter table public.schools
  add column if not exists sample_proof_url text;

alter table public.schools
  add column if not exists sample_proof_path text;

commit;
