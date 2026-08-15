-- Borra todas las tareas del personal (respuestas, ocurrencias y plantillas recurrentes).
-- Ejecutar: supabase db query --linked -f supabase/scripts/clear_all_staff_tasks.sql

truncate table
  public.staff_task_responses,
  public.staff_tasks,
  public.staff_task_templates
restart identity cascade;
