-- Migration: sync_expiry_tasks function
-- Replaces the client-side syncExpiryTasks() which had two problems:
--   1. DELETE ALL expiry tasks globally, causing data loss when department-filtered
--      clients only re-inserted their subset.
--   2. Only checked 3 of 5 vehicle date types (missed nextToDate, nextEquipmentToDate).
--
-- This function atomically replaces all expiry tasks from the full dataset:
--   Vehicles: Техосмотр, Страховка, Спец. разрешение, ТО автомобиля, ТО оборудования
--   Drivers:  Вод. удостоверение, Мед. справка
-- Within 30-day window. priority='high' if ≤7 days from today.
-- Advisory lock prevents concurrent DELETE+INSERT races.

CREATE OR REPLACE FUNCTION sync_expiry_tasks()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cutoff date := current_date + interval '30 days';
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('sync_expiry_tasks'));

  DELETE FROM tasks WHERE type = 'expiry';

  -- 1. Техосмотр
  INSERT INTO tasks (title, due_date, is_completed, priority, type, vehicle_id)
  SELECT
    'Техосмотр — ' || v.brand || ' ' || v.model || ' (' || v.gov_number || ')',
    v.inspection_date,
    false,
    CASE WHEN v.inspection_date <= current_date + interval '7 days' THEN 'high' ELSE 'normal' END,
    'expiry',
    v.id
  FROM vehicles v
  WHERE v.inspection_date IS NOT NULL
    AND v.inspection_date <= v_cutoff;

  -- 2. Страховка
  INSERT INTO tasks (title, due_date, is_completed, priority, type, vehicle_id)
  SELECT
    'Страховка — ' || v.brand || ' ' || v.model || ' (' || v.gov_number || ')',
    v.insurance_date,
    false,
    CASE WHEN v.insurance_date <= current_date + interval '7 days' THEN 'high' ELSE 'normal' END,
    'expiry',
    v.id
  FROM vehicles v
  WHERE v.insurance_date IS NOT NULL
    AND v.insurance_date <= v_cutoff;

  -- 3. Спец. разрешение
  INSERT INTO tasks (title, due_date, is_completed, priority, type, vehicle_id)
  SELECT
    'Спец. разрешение — ' || v.brand || ' ' || v.model || ' (' || v.gov_number || ')',
    v.special_permit_date,
    false,
    CASE WHEN v.special_permit_date <= current_date + interval '7 days' THEN 'high' ELSE 'normal' END,
    'expiry',
    v.id
  FROM vehicles v
  WHERE v.special_permit_date IS NOT NULL
    AND v.special_permit_date <= v_cutoff;

  -- 4. ТО автомобиля (computed: to_date + to_period_months months)
  INSERT INTO tasks (title, due_date, is_completed, priority, type, vehicle_id)
  SELECT
    'ТО автомобиля — ' || v.brand || ' ' || v.model || ' (' || v.gov_number || ')',
    (v.to_date + (v.to_period_months || ' months')::interval)::date,
    false,
    CASE WHEN (v.to_date + (v.to_period_months || ' months')::interval)::date
              <= current_date + interval '7 days' THEN 'high' ELSE 'normal' END,
    'expiry',
    v.id
  FROM vehicles v
  WHERE v.to_date IS NOT NULL
    AND v.to_period_months IS NOT NULL
    AND (v.to_date + (v.to_period_months || ' months')::interval)::date <= v_cutoff;

  -- 5. ТО оборудования (computed: equipment_to_date + equipment_to_period_months months)
  INSERT INTO tasks (title, due_date, is_completed, priority, type, vehicle_id)
  SELECT
    'ТО оборудования — ' || v.brand || ' ' || v.model || ' (' || v.gov_number || ')',
    (v.equipment_to_date + (v.equipment_to_period_months || ' months')::interval)::date,
    false,
    CASE WHEN (v.equipment_to_date + (v.equipment_to_period_months || ' months')::interval)::date
              <= current_date + interval '7 days' THEN 'high' ELSE 'normal' END,
    'expiry',
    v.id
  FROM vehicles v
  WHERE v.equipment_to_date IS NOT NULL
    AND v.equipment_to_period_months IS NOT NULL
    AND (v.equipment_to_date + (v.equipment_to_period_months || ' months')::interval)::date <= v_cutoff;

  -- 6. Вод. удостоверение
  INSERT INTO tasks (title, due_date, is_completed, priority, type, driver_id)
  SELECT
    'Вод. удостоверение — ' || d.last_name || ' ' || d.first_name || COALESCE(' ' || d.middle_name, ''),
    d.license_expiry,
    false,
    CASE WHEN d.license_expiry <= current_date + interval '7 days' THEN 'high' ELSE 'normal' END,
    'expiry',
    d.id
  FROM drivers d
  WHERE d.license_expiry IS NOT NULL
    AND d.license_expiry <= v_cutoff;

  -- 7. Мед. справка
  INSERT INTO tasks (title, due_date, is_completed, priority, type, driver_id)
  SELECT
    'Мед. справка — ' || d.last_name || ' ' || d.first_name || COALESCE(' ' || d.middle_name, ''),
    d.medical_expiry,
    false,
    CASE WHEN d.medical_expiry <= current_date + interval '7 days' THEN 'high' ELSE 'normal' END,
    'expiry',
    d.id
  FROM drivers d
  WHERE d.medical_expiry IS NOT NULL
    AND d.medical_expiry <= v_cutoff;
END;
$$;

GRANT EXECUTE ON FUNCTION sync_expiry_tasks() TO authenticated;
