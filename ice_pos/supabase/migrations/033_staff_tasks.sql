-- Staff tasks: scheduled work items for employees (done / skipped + comments).

create table if not exists public.staff_tasks (
  id serial primary key,
  store_id int not null references public.stores(id),
  title text not null,
  description text,
  scheduled_at timestamptz not null,
  notify_at timestamptz not null default now(),
  notification_sent_at timestamptz,
  created_at timestamptz not null default now(),
  created_by_user_id text,
  created_by_username text,
  cancelled_at timestamptz
);

comment on table public.staff_tasks is
  'Tareas programadas para personal de tienda; notificación en notify_at.';

create index if not exists staff_tasks_store_scheduled_idx
  on public.staff_tasks (store_id, scheduled_at desc)
  where cancelled_at is null;

create table if not exists public.staff_task_responses (
  id serial primary key,
  task_id int not null references public.staff_tasks(id) on delete cascade,
  user_id text not null,
  status text not null check (status in ('pending', 'done', 'skipped')),
  comment text,
  responded_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (task_id, user_id)
);

comment on table public.staff_task_responses is
  'Respuesta por usuario: hecho, omitido, comentario opcional.';

create index if not exists staff_task_responses_task_idx
  on public.staff_task_responses (task_id);

alter table public.staff_tasks enable row level security;
alter table public.staff_task_responses enable row level security;

drop policy if exists "anon_all_staff_tasks" on public.staff_tasks;
create policy "anon_all_staff_tasks" on public.staff_tasks
  for all to anon using (true) with check (true);

drop policy if exists "auth_all_staff_tasks" on public.staff_tasks;
create policy "auth_all_staff_tasks" on public.staff_tasks
  for all to authenticated using (true) with check (true);

drop policy if exists "anon_all_staff_task_responses" on public.staff_task_responses;
create policy "anon_all_staff_task_responses" on public.staff_task_responses
  for all to anon using (true) with check (true);

drop policy if exists "auth_all_staff_task_responses" on public.staff_task_responses;
create policy "auth_all_staff_task_responses" on public.staff_task_responses
  for all to authenticated using (true) with check (true);
