-- Allow in_progress status on staff task responses (pending → in_progress → done | skipped).

alter table public.staff_task_responses
  drop constraint if exists staff_task_responses_status_check;

alter table public.staff_task_responses
  add constraint staff_task_responses_status_check
  check (status in ('pending', 'in_progress', 'done', 'skipped'));

comment on column public.staff_task_responses.status is
  'pending | in_progress | done | skipped (omitida, requiere comentario)';
