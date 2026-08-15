-- Señal desde admin para que una caja compruebe / aplique actualización (consulta pull desde la app).

alter table public.pos_devices
  add column if not exists remote_update_requested_at timestamptz,
  add column if not exists remote_update_message text;

comment on column public.pos_devices.remote_update_requested_at is
  'Marca de tiempo establecida por admin; la app compara con la última vista en el dispositivo y puede mostrar aviso.';
comment on column public.pos_devices.remote_update_message is
  'Mensaje opcional para mostrar en la caja (ej. motivo o instrucciones).';

notify pgrst, 'reload schema';
