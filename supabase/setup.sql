-- GroundTank: what the app needs from the Supabase project.
-- Run once in the SQL Editor. Safe to re-run.
--
-- The app only READS these tables, with the project's publishable (anon)
-- key. Devices keep writing sensor_readings with whatever key they use now.

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
