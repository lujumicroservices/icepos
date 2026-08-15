-- Recurring staff tasks: templates that generate dated staff_tasks occurrences.

create table if not exists public.staff_task_templates (
  id bigserial primary key,
  store_id int not null references public.stores(id),
  title text not null,
  description text,
  -- Local time (store/device) to schedule the task occurrence.
  scheduled_time time not null default '09:00',
  -- Minutes before scheduled_time to notify (e.g. 15).
  notify_minutes_before int not null default 15,
  -- Recurrence:
  -- daily: every day
  -- weekly: only on selected weekdays
  recurrence_kind text not null default 'daily' check (recurrence_kind in ('daily', 'weekly')),
  -- 1..7 = Mon..Sun (Postgres extract(dow) uses 0..6, but we store 1..7 for readability)
  weekdays int[] ,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by_user_id text,
  created_by_username text,
  updated_at timestamptz not null default now()
);

comment on table public.staff_task_templates is
  'Plantillas de tareas repetitivas; generan ocurrencias en staff_tasks.';

create index if not exists staff_task_templates_store_active_idx
  on public.staff_task_templates (store_id)
  where is_active = true;

alter table public.staff_task_templates enable row level security;

drop policy if exists "anon_all_staff_task_templates" on public.staff_task_templates;
create policy "anon_all_staff_task_templates" on public.staff_task_templates
  for all to anon using (true) with check (true);

drop policy if exists "auth_all_staff_task_templates" on public.staff_task_templates;
create policy "auth_all_staff_task_templates" on public.staff_task_templates
  for all to authenticated using (true) with check (true);

-- Link occurrences back to template and prevent duplicates per day.
alter table public.staff_tasks
  add column if not exists template_id bigint references public.staff_task_templates(id) on delete set null;

-- One occurrence per template per store per calendar day (UTC).
create unique index if not exists staff_tasks_template_day_uniq
  on public.staff_tasks (template_id, store_id, ((scheduled_at AT TIME ZONE 'UTC')::date))
  where template_id is not null and cancelled_at is null;

