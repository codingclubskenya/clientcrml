-- Project forms persistence for Admin publish -> Role 5 quick actions
-- Schema-only portion; seed data is in 015b_project_forms_seed.sql

create table if not exists public.project_forms (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  questions jsonb not null default '[]'::jsonb,
  assigned_user_ids uuid[] not null default '{}',
  published_at timestamptz not null default now(),
  created_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'project_forms'
      and column_name = 'assigned_user_ids'
  ) then
    alter table public.project_forms
      add column assigned_user_ids uuid[] not null default '{}';
  end if;
end $$;

create index if not exists idx_project_forms_published_at
  on public.project_forms (published_at desc);

alter table public.project_forms enable row level security;

drop policy if exists "authenticated_can_view_project_forms" on public.project_forms;
create policy "authenticated_can_view_project_forms"
on public.project_forms
for select
to authenticated
using (
  public.is_manager_or_admin()
  or auth.uid() = any (assigned_user_ids)
);

drop policy if exists "managers_can_publish_project_forms" on public.project_forms;
create policy "managers_can_publish_project_forms"
on public.project_forms
for insert
to authenticated
with check (public.is_manager_or_admin());

create table if not exists public.project_form_responses (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references public.project_forms (id) on delete cascade,
  form_title text not null,
  respondent_id uuid not null references public.users (id) on delete cascade,
  answers jsonb not null default '{}'::jsonb,
  submitted_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_project_form_responses_form_title
  on public.project_form_responses (form_title);

create index if not exists idx_project_form_responses_submitted_at
  on public.project_form_responses (submitted_at desc);

alter table public.project_form_responses enable row level security;

drop policy if exists "assigned_users_can_submit_project_form_responses" on public.project_form_responses;
create policy "assigned_users_can_submit_project_form_responses"
on public.project_form_responses
for insert
to authenticated
with check (
  exists (
    select 1
    from public.project_forms f
    where f.id = project_form_responses.form_id
      and (
        auth.uid() = any (f.assigned_user_ids)
        or coalesce(array_length(f.assigned_user_ids, 1), 0) = 0
        or public.is_manager_or_admin()
      )
  )
  and respondent_id = auth.uid()
);

drop policy if exists "managers_can_view_project_form_responses" on public.project_form_responses;
create policy "managers_can_view_project_form_responses"
on public.project_form_responses
for select
to authenticated
using (public.is_manager_or_admin());

drop policy if exists "respondents_can_view_their_project_form_responses" on public.project_form_responses;
create policy "respondents_can_view_their_project_form_responses"
on public.project_form_responses
for select
to authenticated
using (respondent_id = auth.uid());
