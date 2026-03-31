-- Modo de conteo de inventario: cantidad numérica o nivel cualitativo.
ALTER TABLE public.supplies
  ADD COLUMN IF NOT EXISTS stock_count_mode text NOT NULL DEFAULT 'quantity'
    CHECK (stock_count_mode IN ('quantity', 'qualitative'));

ALTER TABLE public.supplies
  ADD COLUMN IF NOT EXISTS qualitative_level text NULL;

COMMENT ON COLUMN public.supplies.stock_count_mode IS 'quantity | qualitative';
COMMENT ON COLUMN public.supplies.qualitative_level IS 'alto | medio | bajo | resurtir cuando stock_count_mode = qualitative';
