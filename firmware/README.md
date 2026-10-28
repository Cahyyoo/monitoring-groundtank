# Mengunggah data ESP32 ke Supabase

Panduan agar perangkat sensor (mis. ESP32 dengan sensor ultrasonik) mengirim
ketinggian air ke Supabase, lalu tampil di aplikasi GroundTank. Panduan ini
hanya membahas **sisi Supabase dan format request**; firmware bebas ditulis
dengan bahasa/library apa pun yang bisa mengirim HTTPS POST.

```
ESP32 ──HTTPS POST──▶ /rest/v1/rpc/submit_reading ──▶ sensor_readings ──Realtime──▶ App GroundTank
        (apikey + token perangkat)        │
                                          └──▶ devices.status / ip_address / updated_at
```

**Kenapa lewat fungsi (RPC), bukan insert langsung ke tabel?** Publishable/anon
key ikut tertanam di aplikasi dan bisa diekstrak dari APK, sedangkan UUID
perangkat & sensor bisa dibaca siapa pun lewat aplikasi. Kalau tabel
`sensor_readings` dibuka untuk insert, siapa saja bisa mengirim data palsu.
Dengan cara ini tabel tetap **read-only** bagi aplikasi, dan hanya perangkat
yang memegang **token rahasianya sendiri** yang bisa menulis. Token disimpan
sebagai hash bcrypt, tidak pernah dalam bentuk asli.

Prasyarat: tabel `devices`, `sensors`, `device_sensors`, `sensor_readings`
sudah ada dan [`supabase/setup.sql`](../supabase/setup.sql) sudah dijalankan.

---

## Langkah 1 — Siapkan Supabase (sekali saja)

Buka **SQL Editor**, tempel blok di bawah ini, lalu **Run**. Aman dijalankan
ulang.

```sql
-- Token per perangkat. Hanya hash yang disimpan; tidak terbaca oleh aplikasi
-- (RLS aktif tanpa satu pun policy).
create table if not exists public.device_tokens (
  device_id  uuid primary key references public.devices (id) on delete cascade,
  token_hash text not null,
  created_at timestamptz not null default now()
);
alter table public.device_tokens enable row level security;
revoke all on public.device_tokens from anon, authenticated;

-- Satu-satunya pintu tulis untuk perangkat.
create or replace function public.submit_reading(
  p_device_id uuid,
  p_sensor_id uuid,
  p_value     text,
  p_token     text,
  p_ip        text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_hash  text;
  v_value text := btrim(p_value);
begin
  select token_hash into v_hash
  from public.device_tokens
  where device_id = p_device_id;

  -- 28000 -> HTTP 403
  if v_hash is null or p_token is null
     or extensions.crypt(p_token, v_hash) <> v_hash then
    raise exception 'invalid device token' using errcode = '28000';
  end if;

  -- 22023 -> HTTP 400
  if not exists (
    select 1 from public.device_sensors
    where device_id = p_device_id and sensor_id = p_sensor_id
  ) then
    raise exception 'sensor is not attached to this device' using errcode = '22023';
  end if;

  if v_value is null or length(v_value) > 32
     or v_value !~ '^-?[0-9]+([.,][0-9]+)?$' then
    raise exception 'value must be a number' using errcode = '22023';
  end if;

  -- Waktu dari server, bukan dari ESP32 yang jamnya bisa melenceng.
  insert into public.sensor_readings (id, device_id, sensor_id, value, "timestamp")
  values (extensions.gen_random_uuid(), p_device_id, p_sensor_id, v_value, now());

  -- Heartbeat: aplikasi menampilkan status & IP perangkat dari sini.
  update public.devices
     set status     = true,
         ip_address = coalesce(nullif(btrim(p_ip), ''), ip_address),
         updated_at = now()
   where id = p_device_id;
end;
$$;

revoke all on function public.submit_reading(uuid, uuid, text, text, text) from public;
grant execute on function public.submit_reading(uuid, uuid, text, text, text)
  to anon, authenticated;
```

### Buat token untuk setiap perangkat

Jalankan per perangkat. Langkah (a) menghasilkan token — **salin dan simpan**,
karena setelah ini hanya hash-nya yang tersimpan.

```sql
-- (a) buat token acak 48 karakter
select encode(extensions.gen_random_bytes(24), 'hex') as token;

-- (b) simpan hash-nya (ganti <DEVICE_ID> dan <TOKEN>)
insert into public.device_tokens (device_id, token_hash)
values ('<DEVICE_ID>', extensions.crypt('<TOKEN>', extensions.gen_salt('bf')))
on conflict (device_id) do update
  set token_hash = excluded.token_hash, created_at = now();
```

Menjalankan (a) dan (b) lagi untuk perangkat yang sama akan **mengganti**
token lama. Gunakan ini bila token bocor atau perangkat hilang.

### Uji tanpa perangkat

```bash
curl -i -X POST "https://<PROJECT_REF>.supabase.co/rest/v1/rpc/submit_reading" \
  -H "apikey: <PUBLISHABLE_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"p_device_id":"<DEVICE_ID>","p_sensor_id":"<SENSOR_ID>","p_value":"75.3","p_token":"<TOKEN>"}'
```

Berhasil: `HTTP/2 204` (tanpa isi). Aplikasi yang sedang terbuka akan langsung
menampilkan nilai baru. Contoh penolakan: `403 {"message":"invalid device token"}`.

---

## Langkah 2 — Kumpulkan data untuk perangkat

| Nilai | Dari mana |
|---|---|
| `SUPABASE_URL` | Project Settings → API → Project URL (`https://<ref>.supabase.co`) |
| `SUPABASE_KEY` | Project Settings → API Keys → **publishable** key (`sb_publishable_…`) atau anon key lama (`eyJ…`). **Jangan** pakai `service_role`/secret key. |
| `DEVICE_ID`, `SENSOR_ID` | Query di bawah |
| `DEVICE_TOKEN` | Hasil Langkah 1 (a) |

```sql
select d.name as device, d.id as device_id, s.name as sensor, s.id as sensor_id, s.unit
from public.device_sensors ds
join public.devices d on d.id = ds.device_id
join public.sensors s on s.id = ds.sensor_id
order by d.name, s.name;
```

Pasangan device/sensor **harus** ada di `device_sensors`. Untuk sensor
ultrasonik, beri `unit = 'cm'` dan nama yang memuat kata *Ultrasonic*,
*JSN-SR04T*, atau *jarak*, agar aplikasi otomatis membaca nilainya sebagai
**jarak sensor ke permukaan air**.

---

## Langkah 3 — Format request dari perangkat

Setiap pembacaan dikirim sebagai **satu request HTTPS**:

```
POST https://<PROJECT_REF>.supabase.co/rest/v1/rpc/submit_reading
```

### Header

| Header | Nilai | Keterangan |
|---|---|---|
| `apikey` | `<SUPABASE_KEY>` | Wajib |
| `Content-Type` | `application/json` | Wajib |
| `Authorization` | `Bearer <SUPABASE_KEY>` | **Hanya** bila memakai anon key lama berformat JWT (`eyJ…`). Publishable key baru (`sb_publishable_…`) bukan JWT dan tidak boleh dikirim di header ini. |

### Body (JSON)

```json
{
  "p_device_id": "a1000000-0000-4000-8000-000000000001",
  "p_sensor_id": "b2000000-0000-4000-8000-000000000001",
  "p_value": "75.3",
  "p_token": "token-48-karakter-dari-langkah-1",
  "p_ip": "192.168.1.50"
}
```

| Field | Wajib | Keterangan |
|---|---|---|
| `p_device_id` | ya | `devices.id` |
| `p_sensor_id` | ya | `sensors.id`, harus terhubung ke perangkat itu di `device_sensors` |
| `p_value` | ya | Angka **dalam bentuk string**, karena kolom `value` bertipe `text`. Pemisah desimal titik atau koma, maks. 32 karakter. |
| `p_token` | ya | Token perangkat dari Langkah 1 |
| `p_ip` | tidak | IP lokal perangkat; mengisi `devices.ip_address`. Boleh dihilangkan. |

Waktu pembacaan **tidak dikirim**. Server memakai `now()`, sehingga jam
perangkat yang belum sinkron tidak mengacaukan urutan data.

### Respons

| Status | Arti |
|---|---|
| `204 No Content` | Tersimpan |
| `4xx` + JSON `{"code": "...", "message": "..."}` | Ditolak; lihat [Troubleshooting](#troubleshooting) |

### Nilai apa yang dikirim

Kirim **nilai mentah sensor** dalam satuan yang tertulis di `sensors.unit`.
Aplikasi yang mengubahnya menjadi persen, cm, dan liter, memakai dimensi tangki
di **Pengaturan**. Untuk sensor ultrasonik, kirim **jarak sensor ke permukaan
air** (cm). Tidak perlu menghitung tinggi air atau persen di perangkat.

### Aturan pengiriman

- **Interval paling lambat 60 detik.** Aplikasi menandai perangkat "Tidak
  aktif" bila tidak ada data baru selama lebih dari 2 menit.
- **Wajib HTTPS.** Verifikasi sertifikat server untuk pemakaian sungguhan.
  Melewati verifikasi (mis. `setInsecure()` di ESP32) hanya untuk uji coba.
- **Respons `4xx` berarti konfigurasi salah** (key, token, ID, atau nilai).
  Mengulang cepat tidak akan berhasil, jadi kirim lagi pada jadwal berikutnya.
- **Gagal koneksi atau `5xx`:** coba lagi dengan jeda yang makin lama (mis.
  5 s, 10 s, 20 s, … maks. 5 menit) agar tidak membanjiri server.
- **Saring pembacaan yang jelas salah** (mis. nilai tengah dari beberapa
  pengukuran, buang nilai di luar jangkauan sensor) sebelum dikirim, supaya
  riak air tidak tampil di grafik.

---

## Troubleshooting

| Respons | Penyebab | Solusi |
|---|---|---|
| Tidak ada respons / koneksi gagal | Jaringan, URL, atau TLS gagal | Cek koneksi internet perangkat, `SUPABASE_URL` (harus `https://`), dan sertifikat root bila verifikasi diaktifkan |
| `401` | `apikey` salah atau tidak ada | Salin ulang publishable key |
| `403` `invalid device token` | Token salah, atau belum didaftarkan untuk `DEVICE_ID` ini | Ulangi Langkah 1 (a)+(b) |
| `400` `sensor is not attached to this device` | Pasangan `DEVICE_ID`/`SENSOR_ID` tidak ada di `device_sensors` | Cek dengan query Langkah 2 |
| `400` `value must be a number` | Nilai kosong atau bukan angka | Periksa sensor dan pembacaannya |
| `404` `PGRST202` | Fungsi belum dibuat, atau nama field body salah | Jalankan ulang SQL Langkah 1 dan cocokkan nama field dengan tabel Body. Bila fungsi baru dibuat, jalankan `notify pgrst, 'reload schema';` |

Cek apakah data masuk:

```sql
select value, "timestamp"
from public.sensor_readings
where device_id = '<DEVICE_ID>' and sensor_id = '<SENSOR_ID>'
order by "timestamp" desc
limit 10;
```

## Catatan keamanan

- **Jangan pernah** menaruh `service_role`/secret key di perangkat. Key itu
  melewati semua RLS dan tidak bisa dibatasi.
- Satu token untuk satu perangkat. Bila perangkat hilang atau token bocor,
  ganti tokennya (Langkah 1 a+b) atau hapus barisnya di `device_tokens`.
- Token hanya tersimpan sebagai hash bcrypt. Token asli memang akan terlihat
  di riwayat SQL Editor saat dibuat, jadi batasi siapa yang punya akses ke
  dashboard Supabase.
