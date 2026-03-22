-- PELIGRO: borra TODAS las recetas en la nube.
-- Usar solo si vas a volver a poblar recipes desde la app (import + sync por producto)
-- o si tienes un proceso controlado de carga.
--
-- NO ejecutar en producción sin backup.

-- begin;
-- delete from public.recipes;
-- commit;

-- Descomenta las 3 líneas de arriba cuando estés seguro.

select 'Script deshabilitado por defecto. Edita el archivo y descomenta delete.' as notice;
