-- GroundTank: dummy data for trying the app against Supabase.
-- Run in the SQL Editor (it runs as postgres, so RLS does not apply).
-- Safe to re-run: fixed ids, and only the dummy devices' readings are replaced.
--
-- Matches the app's default tank settings: 200 cm of water at 100%, and an
-- ultrasonic sensor 220 cm above the tank floor. So for the JSN-SR04T sensor:
--   tinggi air = 220 − distance;  persen = tinggi air / 200 × 100
--   full  (>= 90%) : distance <= 40 cm
--   empty (<= 15%) : distance >= 190 cm

begin;

-- 1. Devices --------------------------------------------------------------
insert into public.devices
  (id, name, project, mac_address, ip_address, link, status, created_at, updated_at)
values
  ('a1000000-0000-4000-8000-000000000001', 'ESP32 Ground Tank', 'GroundTank',
   'AA:BB:CC:00:00:01', '192.168.1.50', 'http://192.168.1.50', true,  now(), now()),
  ('a1000000-0000-4000-8000-000000000002', 'ESP32 Toren Atas',  'GroundTank',
   'AA:BB:CC:00:00:02', '192.168.1.51', 'http://192.168.1.51', false, now(), now() - interval '1 day')
on conflict (id) do update set
  name = excluded.name, project = excluded.project, ip_address = excluded.ip_address,
  link = excluded.link, status = excluded.status, updated_at = excluded.updated_at;

-- 2. Sensors --------------------------------------------------------------
insert into public.sensors (id, name, unit, data_type, created_at)
values
  -- "Ultrasonic" in the name + unit cm  -> the app reads value as a distance.
  ('b2000000-0000-4000-8000-000000000001', 'Ultrasonic JSN-SR04T', 'cm', 'float', now()),
  -- Not a level unit -> marked "bukan satuan ketinggian" in the sensor picker.
  ('b2000000-0000-4000-8000-000000000002', 'Suhu air DS18B20',     '°C', 'float', now()),
  -- Unit % -> the app reads value as a fill percentage.
  ('b2000000-0000-4000-8000-000000000003', 'Level toren',          '%',  'float', now())
on conflict (id) do update set
  name = excluded.name, unit = excluded.unit, data_type = excluded.data_type;

-- 3. Which sensor sits on which device ---------------------------------------
insert into public.device_sensors (id, device_id, sensor_id, pin_config, created_at)
values
  ('c3000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001',
   'b2000000-0000-4000-8000-000000000001', 'TRIG=GPIO5, ECHO=GPIO18', now()),
  ('c3000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001',
   'b2000000-0000-4000-8000-000000000002', 'DATA=GPIO4', now()),
  ('c3000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000002',
   'b2000000-0000-4000-8000-000000000003', 'ADC=GPIO34', now())
on conflict (id) do update set
  device_id = excluded.device_id, sensor_id = excluded.sensor_id, pin_config = excluded.pin_config;

-- 4. Readings -------------------------------------------------------------
delete from public.sensor_readings
where device_id in ('a1000000-0000-4000-8000-000000000001',
                    'a1000000-0000-4000-8000-000000000002');

-- Ground tank, last 2 hours, one reading a minute: the water rises to nearly
-- full (~97%), drains to nearly empty (~12%), and ends at about half (55%)
-- "now", so the chart shows both thresholds being crossed.
insert into public.sensor_readings (id, device_id, sensor_id, value, "timestamp")
select
  gen_random_uuid(),
  'a1000000-0000-4000-8000-000000000001',
  'b2000000-0000-4000-8000-000000000001',
  round((220 - (110 + 85 * sin(2 * pi() * i / 120)) + (random() - 0.5))::numeric, 1)::text,
  now() - make_interval(mins => 120 - i)
from generate_series(0, 120) as i;

-- Water temperature on the same device, every 5 minutes.
insert into public.sensor_readings (id, device_id, sensor_id, value, "timestamp")
select
  gen_random_uuid(),
  'a1000000-0000-4000-8000-000000000001',
  'b2000000-0000-4000-8000-000000000002',
  round((27 + 1.5 * sin(2 * pi() * i / 24) + (random() - 0.5) * 0.4)::numeric, 1)::text,
  now() - make_interval(mins => (24 - i) * 5)
from generate_series(0, 24) as i;

-- Roof tank: last readings a day old, so the app shows it as "Tidak aktif".
insert into public.sensor_readings (id, device_id, sensor_id, value, "timestamp")
select
  gen_random_uuid(),
  'a1000000-0000-4000-8000-000000000002',
  'b2000000-0000-4000-8000-000000000003',
  round((60 + i * 0.5)::numeric, 1)::text,
  now() - interval '1 day' - make_interval(mins => 30 - i)
from generate_series(0, 30) as i;

commit;

-- 5. Testing alerts -------------------------------------------------------
-- With the app open on "ESP32 Ground Tank / Ultrasonic JSN-SR04T", run one of
-- these to see the dashboard change and the notification fire. Run the other
-- one afterwards to cross back.
--
-- Penuh (distance 25 cm -> 195 cm = 97.5%):
-- insert into public.sensor_readings (id, device_id, sensor_id, value, "timestamp")
-- values (gen_random_uuid(), 'a1000000-0000-4000-8000-000000000001',
--         'b2000000-0000-4000-8000-000000000001', '25.0', now());
--
-- Kosong (distance 205 cm -> 15 cm = 7.5%):
-- insert into public.sensor_readings (id, device_id, sensor_id, value, "timestamp")
-- values (gen_random_uuid(), 'a1000000-0000-4000-8000-000000000001',
--         'b2000000-0000-4000-8000-000000000001', '205.0', now());
--
-- Remove all dummy data:
-- delete from public.sensor_readings where device_id::text like 'a1000000-%';
-- delete from public.device_sensors  where id::text like 'c3000000-%';
-- delete from public.sensors         where id::text like 'b2000000-%';
-- delete from public.devices         where id::text like 'a1000000-%';
