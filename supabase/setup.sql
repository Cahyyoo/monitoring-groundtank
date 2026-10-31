-- GroundTank: what the app needs from the Supabase project.
-- Run once in the SQL Editor. Safe to re-run.
--
-- The app only READS these tables, with the project's publishable (anon)
-- key. Devices write readings through submit_reading (firmware/README.md);
-- the shared tank settings change only through update_tank_settings, with
-- the admin PIN (section 4).

-- 1. Fast "newest reading of this sensor" and history queries.
create index if not exists sensor_readings_device_sensor_time_idx
  on public.sensor_readings (device_id, sensor_id, "timestamp" desc);

-- 2. Row-level security: read-only access for the app.
--    If RLS is already enabled with other policies, only the SELECT policies
--    below are added; nothing existing is dropped.
alter table public.devices         enable row level security;
alter table public.sensors         enable row level security;
alter table public.device_sensors  enable row level security;
alter table public.sensor_readings enable row level security;

drop policy if exists "groundtank app reads devices" on public.devices;
create policy "groundtank app reads devices"
  on public.devices for select to anon, authenticated using (true);

drop policy if exists "groundtank app reads sensors" on public.sensors;
create policy "groundtank app reads sensors"
  on public.sensors for select to anon, authenticated using (true);

drop policy if exists "groundtank app reads device_sensors" on public.device_sensors;
create policy "groundtank app reads device_sensors"
  on public.device_sensors for select to anon, authenticated using (true);

drop policy if exists "groundtank app reads sensor_readings" on public.sensor_readings;
create policy "groundtank app reads sensor_readings"
  on public.sensor_readings for select to anon, authenticated using (true);

-- NOTE: with RLS on and no INSERT policy, nothing can insert into
-- sensor_readings with the app's publishable/anon key — on purpose, since that
-- key ships inside the APK. Devices write through the submit_reading function
-- with a per-device token instead: see firmware/README.md. Do not add an
-- "insert ... with check (true)" policy, and never put the service-role key on
-- a device.

-- 3. Realtime: push new readings to the dashboard as they are inserted.
--    Without this the app still works, polling every few seconds.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'sensor_readings'
  ) then
    alter publication supabase_realtime add table public.sensor_readings;
  end if;
end $$;

-- 4. Shared tank settings: one row every phone reads, so all of them watch
--    the same device and sensors with the same dimensions and thresholds.
--    Per-phone choices (notifications, polling, theme) stay on the phone.
create table if not exists public.tank_settings (
  id                  smallint primary key default 1 check (id = 1),
  device_id           uuid references public.devices (id) on delete set null,
  level_sensor_id     uuid references public.sensors (id) on delete set null,
  float_sensor_id     uuid references public.sensors (id) on delete set null,
  value_kind          text not null default 'distanceCm'
                      check (value_kind in ('percent', 'levelCm', 'distanceCm')),
  tank_height_cm      numeric not null default 200,
  sensor_to_bottom_cm numeric not null default 220,
  capacity_liters     numeric not null default 5000,
  full_threshold      integer not null default 90,
  empty_threshold     integer not null default 15,
  updated_at          timestamptz not null default now()
);
alter table public.tank_settings enable row level security;

drop policy if exists "groundtank app reads tank_settings" on public.tank_settings;
create policy "groundtank app reads tank_settings"
  on public.tank_settings for select to anon, authenticated using (true);
-- No insert/update policy: the publishable key ships inside the APK.
revoke insert, update, delete, truncate on public.tank_settings
  from anon, authenticated;

-- The admin PIN that unlocks the settings. Only its bcrypt hash is kept, and
-- the table has RLS on with no policy at all, so the app cannot read it.
-- Set or change the PIN (at least 6 characters) in the SQL Editor:
--
--   insert into public.settings_pin (id, pin_hash)
--   values (1, extensions.crypt('<PIN-BARU>', extensions.gen_salt('bf')))
--   on conflict (id) do update
--     set pin_hash = excluded.pin_hash, failed_attempts = 0, locked_until = null;
create table if not exists public.settings_pin (
  id              smallint primary key default 1 check (id = 1),
  pin_hash        text not null,
  failed_attempts integer not null default 0,
  locked_until    timestamptz
);
alter table public.settings_pin enable row level security;
revoke all on public.settings_pin from anon, authenticated;

-- Checks a PIN. Returns 'ok', 'wrong_pin', 'locked' or 'no_pin' instead of
-- raising, so the failed-attempt count is committed: five wrong PINs in a
-- row lock it for five minutes, which keeps guessing over the public API slow.
create or replace function public.check_settings_pin(p_pin text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pin public.settings_pin%rowtype;
begin
  select * into v_pin from public.settings_pin where id = 1 for update;
  if not found then
    return 'no_pin';
  end if;
  if v_pin.locked_until is not null and v_pin.locked_until > now() then
    return 'locked';
  end if;

  if p_pin is null or extensions.crypt(p_pin, v_pin.pin_hash) <> v_pin.pin_hash then
    update public.settings_pin
       set failed_attempts = case when failed_attempts + 1 >= 5
                                  then 0 else failed_attempts + 1 end,
           locked_until    = case when failed_attempts + 1 >= 5
                                  then now() + interval '5 minutes' end
     where id = 1;
    return 'wrong_pin';
  end if;

  update public.settings_pin
     set failed_attempts = 0, locked_until = null
   where id = 1;
  return 'ok';
end;
$$;

-- Internal: only the two functions below may call it.
revoke all on function public.check_settings_pin(text) from public, anon, authenticated;

-- Lets the app tell a wrong PIN apart before anything is edited.
create or replace function public.verify_settings_pin(p_pin text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  return public.check_settings_pin(p_pin);
end;
$$;

revoke all on function public.verify_settings_pin(text) from public;
grant execute on function public.verify_settings_pin(text) to anon, authenticated;

-- The only way to change the shared settings. Checked again here, not only in
-- the app: 'invalid:<field>' names the first field that is wrong.
create or replace function public.update_tank_settings(
  p_pin                 text,
  p_device_id           uuid,
  p_level_sensor_id     uuid,
  p_float_sensor_id     uuid,
  p_value_kind          text,
  p_tank_height_cm      numeric,
  p_sensor_to_bottom_cm numeric,
  p_capacity_liters     numeric,
  p_full_threshold      integer,
  p_empty_threshold     integer
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text := public.check_settings_pin(p_pin);
begin
  if v_status <> 'ok' then
    return v_status;
  end if;

  if p_device_id is null
     or not exists (select 1 from public.devices where id = p_device_id) then
    return 'invalid:device_id';
  end if;
  if p_level_sensor_id is null or not exists (
    select 1 from public.device_sensors
    where device_id = p_device_id and sensor_id = p_level_sensor_id
  ) then
    return 'invalid:level_sensor_id';
  end if;
  if p_float_sensor_id is not null and (
    p_float_sensor_id = p_level_sensor_id or not exists (
      select 1 from public.device_sensors
      where device_id = p_device_id and sensor_id = p_float_sensor_id
    )
  ) then
    return 'invalid:float_sensor_id';
  end if;
  if p_value_kind is null
     or p_value_kind not in ('percent', 'levelCm', 'distanceCm') then
    return 'invalid:value_kind';
  end if;
  if p_tank_height_cm is null or p_tank_height_cm <= 0 then
    return 'invalid:tank_height_cm';
  end if;
  if p_sensor_to_bottom_cm is null or p_sensor_to_bottom_cm < p_tank_height_cm then
    return 'invalid:sensor_to_bottom_cm';
  end if;
  if p_capacity_liters is null or p_capacity_liters <= 0 then
    return 'invalid:capacity_liters';
  end if;
  if p_full_threshold is null or p_full_threshold not between 1 and 100
     or p_empty_threshold is null or p_empty_threshold not between 0 and 99
     or p_full_threshold - p_empty_threshold < 7 then
    return 'invalid:thresholds';
  end if;

  insert into public.tank_settings as t (
    id, device_id, level_sensor_id, float_sensor_id, value_kind,
    tank_height_cm, sensor_to_bottom_cm, capacity_liters,
    full_threshold, empty_threshold, updated_at
  ) values (
    1, p_device_id, p_level_sensor_id, p_float_sensor_id, p_value_kind,
    p_tank_height_cm, p_sensor_to_bottom_cm, p_capacity_liters,
    p_full_threshold, p_empty_threshold, now()
  )
  on conflict (id) do update set
    device_id           = excluded.device_id,
    level_sensor_id     = excluded.level_sensor_id,
    float_sensor_id     = excluded.float_sensor_id,
    value_kind          = excluded.value_kind,
    tank_height_cm      = excluded.tank_height_cm,
    sensor_to_bottom_cm = excluded.sensor_to_bottom_cm,
    capacity_liters     = excluded.capacity_liters,
    full_threshold      = excluded.full_threshold,
    empty_threshold     = excluded.empty_threshold,
    updated_at          = now();
  return 'ok';
end;
$$;

revoke all on function public.update_tank_settings(
  text, uuid, uuid, uuid, text, numeric, numeric, numeric, integer, integer
) from public;
grant execute on function public.update_tank_settings(
  text, uuid, uuid, uuid, text, numeric, numeric, numeric, integer, integer
) to anon, authenticated;

-- Realtime, so a change made on one phone reaches the others at once.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'tank_settings'
  ) then
    alter publication supabase_realtime add table public.tank_settings;
  end if;
end $$;
