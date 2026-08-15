-- Close every shift with end_time IS NULL, optionally add an admin_remote shift_closure
-- if that shift has no closure row yet, then insert one new open shift.
--
-- Use when cloud state has multiple "open" shifts or after bad sync. Run as database owner
-- (Supabase Dashboard → SQL Editor), or: psql $SUPABASE_DB_URL -f this_file.sql
--
-- Edit the DECLARE block below before running.

DO $$
DECLARE
  v_store_id int := 1;              -- active store for the NEW shift (must exist in public.stores)
  v_starting_fund real := 0;        -- starting fund for the NEW shift
  v_device_id text := null;         -- optional UUID string for new shift; null = unknown device
  v_device_name text := 'admin_script';  -- label for the new shift row
  v_now timestamptz := now();
  r record;
BEGIN
  FOR r IN
    SELECT id FROM public.shifts WHERE end_time IS NULL ORDER BY id
  LOOP
    UPDATE public.shifts
    SET end_time = v_now
    WHERE id = r.id;

    -- Reports that join shift_closures: add a synthetic admin row only if none exists.
    IF NOT EXISTS (SELECT 1 FROM public.shift_closures WHERE shift_id = r.id) THEN
      INSERT INTO public.shift_closures (
        shift_id,
        closing_time,
        system_expected_cash,
        declared_cash,
        difference,
        notes,
        closure_kind,
        closed_by_device_id
      ) VALUES (
        r.id,
        v_now,
        0,
        0,
        0,
        'Bulk close via close_all_open_shifts_and_open_new.sql',
        'admin_remote',
        NULL
      );
    END IF;
  END LOOP;

  INSERT INTO public.shifts (
    start_time,
    end_time,
    starting_fund,
    store_id,
    device_id,
    device_name
  ) VALUES (
    v_now,
    NULL,
    v_starting_fund,
    v_store_id,
    v_device_id,
    v_device_name
  );
END $$;

-- Optional: inspect result
-- SELECT id, start_time, end_time, starting_fund, store_id, device_name FROM public.shifts ORDER BY id DESC LIMIT 5;
