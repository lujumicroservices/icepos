-- One occurrence per template per store per local calendar day (Mexico store timezone).

drop index if exists staff_tasks_template_day_uniq;

create unique index staff_tasks_template_day_uniq
  on public.staff_tasks (
    template_id,
    store_id,
    ((scheduled_at AT TIME ZONE 'America/Mexico_City')::date)
  )
  where template_id is not null and cancelled_at is null;

comment on index public.staff_tasks_template_day_uniq is
  'Una ocurrencia por plantilla/tienda/día calendario local (America/Mexico_City).';
