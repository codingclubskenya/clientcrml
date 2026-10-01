-- Task + pipeline SQL updates for dashboard filtering and consistency

begin;

-- 1) Normalize task statuses before adding constraint
update public.tasks
set status = 'closed'
where lower(status) in ('complete', 'completed', 'done');

update public.tasks
set status = 'in_progress'
where lower(status) in ('in progress', 'progress');

update public.tasks
set status = 'open'
where lower(status) not in ('open', 'in_progress', 'closed');

-- 2) Enforce allowed task statuses
alter table public.tasks
  drop constraint if exists tasks_status_check;

alter table public.tasks
  add constraint tasks_status_check
  check (status in ('open', 'in_progress', 'closed'));

-- 3) Helpful indexes for admin dashboard filters
create index if not exists idx_tasks_status_due_at
  on public.tasks (status, due_at);

create index if not exists idx_tasks_target_role_status
  on public.tasks (target_role, status);

create index if not exists idx_school_sales_stage_updated_at
  on public.school_sales (sale_status, stage_updated_at desc);

commit;
