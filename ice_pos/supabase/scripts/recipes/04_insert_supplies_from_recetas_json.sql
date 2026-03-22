-- =============================================================================
-- Insumos usados en assets/data/recetas_formato.json (ingredientes base).
-- Idempotente: no inserta si ya existe un supply con el mismo name.
--
-- Uso: Supabase → SQL Editor → pegar y ejecutar.
-- Ajusta unit / category / current_stock según tu operación real.
-- Después: sincroniza desde la app (nube → local) o ejecuta rpc sync_sequences
--          si insertaste vía SQL y necesitas alinear serials (ver nota abajo).
-- =============================================================================

-- ERROR 23505 duplicate key (id)=(...) en supplies_pkey: la secuencia del serial
-- quedó por debajo del max(id) real. Esto la alinea antes de insertar.
select setval(
  pg_get_serial_sequence('public.supplies', 'id'),
  coalesce((select max(id) from public.supplies), 0),
  true
);

insert into public.supplies (name, unit, current_stock, cost_per_unit, reorder_point, category)
select v.name, v.unit, v.current_stock, 0::real, 0::real, v.category
from (
  values
    -- Empaque / desechables
    ('Aderezo', 'pcs', 0::real, 'Empaque'),
    ('Aderezo frambuesa', 'pcs', 0::real, 'Empaque'),
    ('Agua mineral', 'lt', 0::real, 'Bebidas'),
    ('Aluminio', 'pcs', 0::real, 'Empaque'),
    ('Baguetera', 'pcs', 0::real, 'Empaque'),
    ('Bolsa', 'pcs', 0::real, 'Empaque'),
    ('Bote 1/2 litro', 'pcs', 0::real, 'Empaque'),
    ('Bote litro', 'pcs', 0::real, 'Empaque'),
    ('Canasta', 'pcs', 0::real, 'Empaque'),
    ('Canasta cartón', 'pcs', 0::real, 'Empaque'),
    ('Concentrado soda', 'lt', 0::real, 'Bebidas'),
    ('Cono', 'pcs', 0::real, 'Empaque'),
    ('Cuchara', 'pcs', 0::real, 'Empaque'),
    ('Papel encerado', 'pcs', 0::real, 'Empaque'),
    ('Plato cartón', 'pcs', 0::real, 'Empaque'),
    ('Platanitos', 'pcs', 0::real, 'Empaque'),
    ('Popote', 'pcs', 0::real, 'Empaque'),
    ('Servilleta', 'pcs', 0::real, 'Empaque'),
    ('Tapa domo', 'pcs', 0::real, 'Empaque'),
    ('Tapa lisa', 'pcs', 0::real, 'Empaque'),
    ('Tapa litro', 'pcs', 0::real, 'Empaque'),
    ('Topping', 'pcs', 0::real, 'Empaque'),
    ('Vaso Chico', 'pcs', 0::real, 'Empaque'),
    ('Vaso Grande', 'pcs', 0::real, 'Empaque'),
    ('Vaso Mediano', 'pcs', 0::real, 'Empaque'),
    ('Vaso Mini', 'pcs', 0::real, 'Empaque'),
    -- Pan / misc comida preparada
    ('Cuernito', 'pcs', 0::real, 'Panadería'),
    ('Galletas', 'pcs', 0::real, 'Panadería'),
    ('Muffin', 'pcs', 0::real, 'Panadería'),
    ('Pan baguette', 'pcs', 0::real, 'Panadería'),
    ('Waffle', 'pcs', 0::real, 'Panadería'),
    -- Lácteos / líquidos / helado
    ('Crema batida', 'ml', 0::real, 'Lácteos'),
    ('Leche', 'lt', 0::real, 'Lácteos'),
    ('Nieve', 'kg', 0::real, 'Helados'),
    ('Nutella', 'kg', 0::real, 'Dulces'),
    ('Polvo base malteada', 'kg', 0::real, 'Bebidas'),
    ('Queso cheddar', 'kg', 0::real, 'Lácteos'),
    ('Queso gouda', 'kg', 0::real, 'Lácteos'),
    ('Queso panela', 'kg', 0::real, 'Lácteos'),
    -- Carnes / embutidos
    ('Jamón selva negra', 'kg', 0::real, 'Embutidos'),
    ('Lomo canadiense', 'kg', 0::real, 'Carnes'),
    ('Pechuga de pavo', 'pcs', 0::real, 'Carnes'),
    ('Pechuga pollo', 'pcs', 0::real, 'Carnes'),
    ('Pepperoni', 'pcs', 0::real, 'Embutidos'),
    ('Tiras pollo', 'pcs', 0::real, 'Carnes'),
    -- Verduras / condimentos
    ('Cebolla', 'pcs', 0::real, 'Verduras'),
    ('Chile serrano', 'pcs', 0::real, 'Verduras'),
    ('Cilantro', 'pcs', 0::real, 'Verduras'),
    ('Jitomate', 'pcs', 0::real, 'Verduras'),
    ('Jalapeños', 'pcs', 0::real, 'Verduras'),
    ('Lechuga', 'pcs', 0::real, 'Verduras'),
    ('Mayonesa', 'ml', 0::real, 'Condimentos'),
    ('Pepino', 'pcs', 0::real, 'Verduras'),
    ('Salsa chipotle', 'ml', 0::real, 'Condimentos'),
    -- Otros
    ('Hielo', 'kg', 0::real, 'Bebidas')
) as v(name, unit, current_stock, category)
where not exists (
  select 1 from public.supplies s where s.name = v.name
);

-- Ver cuántos quedaron
select count(*) as supplies_total from public.supplies;

-- Tras cualquier carga masiva, vuelve a alinear por si acaso:
select setval(
  pg_get_serial_sequence('public.supplies', 'id'),
  coalesce((select max(id) from public.supplies), 0),
  true
) as supplies_id_sequence_next_will_be;

-- Opcional: si tu proyecto define rpc sync_sequences() (recreate_database.sql):
-- select sync_sequences();
