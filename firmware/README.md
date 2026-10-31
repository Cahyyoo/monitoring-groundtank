# Panduan — Mengirim Data Ketinggian Air ke GroundTank

Dokumen ini adalah **kontrak** antara firmware perangkat (mis. ESP32 + sensor
ultrasonik) dan aplikasi GroundTank. Selama perangkat mengikuti aturan di sini,
aplikasi akan menampilkan ketinggian air dengan benar dan mengirim notifikasi
penuh/kosong ke pengguna.

Istilah yang dipakai:
- **WAJIB**: harus dipenuhi; bila dilanggar, data salah atau ditolak.
- **DILARANG**: tidak boleh dilakukan.
- **DISARANKAN**: praktik baik; boleh menyimpang dengan alasan yang jelas.

---

## 1. Gambaran sistem

```
[Sensor] ─▶ [Firmware] ──HTTPS POST──▶ Supabase: fungsi submit_reading
                                              │
                                              ├─▶ tabel sensor_readings  ──▶ Aplikasi (Realtime/polling)
                                              └─▶ devices.status / ip_address / updated_at
```

- Perangkat **hanya mengirim angka mentah sensor**. Semua perhitungan (persen,
  tinggi air, liter, status penuh/kosong) dilakukan oleh aplikasi berdasarkan
  dimensi tangki yang diatur pengguna.
- Perangkat **tidak menulis langsung ke tabel**. Satu-satunya pintu tulis
  adalah fungsi `submit_reading`, yang memeriksa token rahasia per perangkat.
- Waktu pembacaan diisi **oleh server** (`now()`), bukan oleh perangkat.

---

## 2. Yang Anda terima dari admin Supabase

| Nama | Contoh | Keterangan |
|---|---|---|
| `SUPABASE_URL` | `https://abcd1234.supabase.co` | URL proyek |
| `SUPABASE_KEY` | `sb_publishable_…` | Publishable key (atau anon key lama `eyJ…`) |
| `DEVICE_ID` | `a1000000-0000-4000-8000-000000000001` | `devices.id` perangkat ini |
| `SENSOR_ID` | `b2000000-0000-4000-8000-000000000001` | `sensors.id` sensor ketinggian pada perangkat ini |
| `FLOAT_SENSOR_ID` | `b2000000-0000-4000-8000-000000000004` | Opsional: `sensors.id` sensor pelampung (float switch), lihat [4.1](#41-sensor-pelampung-opsional) |
| `DEVICE_TOKEN` | 48 karakter hex | Token rahasia **khusus perangkat ini** |
| Satuan sensor | `cm` | Isi kolom `sensors.unit`; nilai harus dikirim dalam satuan ini |

Bila salah satu belum tersedia, minta ke admin. Langkah untuk admin ada di
[Lampiran A](#lampiran-a--setup-supabase-untuk-admin).

---

## 3. Kontrak API

### 3.1 Request

```
POST {SUPABASE_URL}/rest/v1/rpc/submit_reading
```

| Header | Nilai | Aturan |
|---|---|---|
| `apikey` | `{SUPABASE_KEY}` | **WAJIB** |
| `Content-Type` | `application/json` | **WAJIB** |
| `Authorization` | `Bearer {SUPABASE_KEY}` | **Hanya** bila key berformat JWT (diawali `eyJ`). **DILARANG** untuk publishable key `sb_publishable_…`, karena key itu bukan JWT dan request akan ditolak. |

Body:

```json
{
  "p_device_id": "a1000000-0000-4000-8000-000000000001",
  "p_sensor_id": "b2000000-0000-4000-8000-000000000001",
  "p_value": "110.2",
  "p_token": "<DEVICE_TOKEN>",
  "p_ip": "192.168.1.50"
}
```

| Field | Tipe | Aturan |
|---|---|---|
| `p_device_id` | string (UUID) | **WAJIB** |
| `p_sensor_id` | string (UUID) | **WAJIB**; harus terdaftar untuk perangkat ini |
| `p_value` | **string** | **WAJIB**; lihat [Aturan data](#4-aturan-data) |
| `p_token` | string | **WAJIB** |
| `p_ip` | string | DISARANKAN; IP lokal perangkat, ditampilkan di aplikasi |

Nama field dan tipenya adalah bagian dari kontrak. **DILARANG** mengubah,
menambah, atau menghilangkan field tanpa koordinasi dengan pengelola aplikasi.

### 3.2 Respons

| Status | Arti | Tindakan firmware |
|---|---|---|
| `204 No Content` | Tersimpan | Lanjut ke jadwal berikutnya |
| `400` `sensor is not attached to this device` | `SENSOR_ID` bukan milik `DEVICE_ID` | Jangan ulangi cepat; laporkan ke admin |
| `400` `value must be a number` | Format `p_value` salah | Perbaiki firmware |
| `401` | `apikey` salah/hilang | Jangan ulangi cepat; periksa konfigurasi |
| `403` `invalid device token` | Token salah atau dicabut | Jangan ulangi cepat; minta token baru |
| `404` `PGRST202` | Fungsi belum dibuat, atau nama field salah | Laporkan ke admin |
| `5xx`, timeout, gagal koneksi | Gangguan jaringan/server | Ulangi dengan backoff (lihat 5.3) |

### 3.3 Uji cepat dengan curl

```bash
curl -i -X POST "https://<PROJECT_REF>.supabase.co/rest/v1/rpc/submit_reading" \
  -H "apikey: <SUPABASE_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"p_device_id":"<DEVICE_ID>","p_sensor_id":"<SENSOR_ID>","p_value":"110.2","p_token":"<DEVICE_TOKEN>"}'
```

Hasil yang benar: `HTTP/2 204`.

---

## 4. Aturan data

1. **WAJIB** mengirim **nilai mentah** sensor dalam satuan `sensors.unit`. Untuk
   sensor ultrasonik: **jarak dari sensor ke permukaan air**, dalam cm.
   **DILARANG** mengonversi ke tinggi air atau persen di perangkat. Ukuran
   tangki diatur di aplikasi, sehingga firmware tidak perlu diubah bila tangki
   atau posisi sensor berubah.
2. **WAJIB** dikirim sebagai **string angka**, dengan titik sebagai pemisah
   desimal dan **satu angka desimal**: `"110.2"`, `"35.0"`.
   - Pola yang diterima server: `^-?[0-9]+([.,][0-9]+)?$`, maks. 32 karakter.
   - **DILARANG** menyertakan satuan, spasi, atau notasi ilmiah: `"110 cm"`,
     `"1.1e2"`.
3. **DILARANG mengirim nilai pengganti** untuk pembacaan gagal, seperti `0`,
   `-1`, `999`, atau `"ERR"`. Aplikasi memperlakukan setiap angka sebagai
   pembacaan nyata. Contohnya, jarak `0` dibaca sebagai **tangki penuh** dan
   memicu notifikasi palsu. Bila pembacaan tidak valid, **lewati pengiriman**.
4. **WAJIB** membuang pembacaan di luar jangkauan fisik sensor. Untuk
   JSN-SR04T: < 20 cm atau > 450 cm.
5. **DISARANKAN** memfilter noise: ambil **median dari 5 pengukuran** (jeda
   ±60–70 ms antar pengukuran ultrasonik), lalu kirim mediannya.
6. **DILARANG** mengirim timestamp. Waktu diisi server.
7. Satu perangkat dengan beberapa sensor (mis. ultrasonik + suhu) memakai
   **token yang sama** dengan `p_sensor_id` berbeda. Aplikasi hanya
   menampilkan sensor yang dipilih sebagai sensor ketinggian dan sensor
   pelampung.

### 4.1 Sensor pelampung (opsional)

Pelampung (float switch) adalah penanda **tangki penuh**. Bila pelampung
terangkat, aplikasi menganggap tangki **penuh** dan mengirim notifikasi,
walaupun sensor ultrasonik menunjukkan angka di bawah batas penuh.

1. **WAJIB** kirim ke `FLOAT_SENSOR_ID` dengan nilai **`"1"` saat pelampung
   terangkat (air penuh)** dan **`"0"` saat turun**. Arti ini tetap, apa pun
   cara pemasangannya. Untuk pelampung NC (normally closed) atau input
   dengan pull-up, **balik logikanya di firmware** sehingga tetap 1 = penuh.
2. **DILARANG** mengirim `"HIGH"`, `"ON"`, `"true"`, dan sejenisnya. Server
   hanya menerima angka.
3. **WAJIB** dikirim **setiap siklus**, bersama pembacaan ketinggian dengan
   interval yang sama (bagian 5.1), bukan hanya saat berubah. Dengan begitu
   aplikasi tahu status pelampung masih terbaru.
4. **WAJIB** debounce: baca pin beberapa kali selama ±1 detik dan kirim hanya
   bila hasilnya stabil. Riak air membuat kontak pelampung bergetar.
5. Pakai `p_device_id` dan `p_token` yang sama dengan sensor ketinggian. Yang
   berbeda hanya `p_sensor_id`.

Contoh body untuk pelampung terangkat. ID-nya milik data dummy
(`supabase/seed.sql`); di produksi pakai `FLOAT_SENSOR_ID` dari admin.

```json
{
  "p_device_id": "a1000000-0000-4000-8000-000000000001",
  "p_sensor_id": "b2000000-0000-4000-8000-000000000004",
  "p_value": "1",
  "p_token": "<DEVICE_TOKEN>",
  "p_ip": "192.168.1.50"
}
```

---

## 5. Aturan pengiriman

### 5.1 Interval
- **WAJIB** mengirim paling lambat **tiap 60 detik**. Aplikasi menandai
  perangkat **"Tidak aktif"** bila tidak ada data baru selama lebih dari
  2 menit.
- **DISARANKAN** **30 detik**.
- **DILARANG** lebih cepat dari **5 detik**. Pengiriman terlalu sering hanya
  membebani database tanpa menambah informasi.

### 5.2 Koneksi
- **WAJIB** HTTPS. Untuk produksi, **WAJIB** memverifikasi sertifikat server
  (pasang sertifikat root CA). Melewati verifikasi (mis. `setInsecure()`)
  hanya boleh saat pengembangan.
- **WAJIB** timeout request ±10 detik.
- **WAJIB** menyambung ulang Wi-Fi secara otomatis tanpa memblokir loop utama.
  **DISARANKAN** memasang watchdog agar perangkat restart bila macet.

### 5.3 Saat gagal
- `4xx`: kesalahan konfigurasi, jadi **DILARANG** mengulang cepat. Coba lagi
  pada jadwal normal berikutnya, dan tampilkan kodenya di log.
- `5xx` / timeout / gagal koneksi: ulangi dengan **exponential backoff**,
  misalnya 5 s → 10 s → 20 s → … maks. 5 menit, lalu kembali ke interval
  normal setelah berhasil.
- **DILARANG** menyimpan pembacaan saat offline lalu mengirimnya belakangan.
  Server memberi waktu `now()` saat diterima, sehingga data lama akan tercatat
  dengan waktu yang salah. Buang pembacaan yang gagal dikirim.

### 5.4 Status perangkat
Setiap `submit_reading` yang berhasil otomatis memperbarui `devices.status`,
`ip_address`, dan `updated_at`. Tidak perlu (dan tidak ada) endpoint
heartbeat terpisah.

---

## 6. Keamanan

- **DILARANG** memakai `service_role` / secret key di perangkat. Key itu
  melewati semua aturan keamanan database.
- **WAJIB** satu token untuk satu perangkat. **DILARANG** memakai token yang
  sama di beberapa perangkat.
- **DILARANG** menulis token, key, atau password Wi-Fi ke log/Serial, dan
  **DILARANG** meng-commit-nya ke repository. Simpan di file konfigurasi
  terpisah yang diabaikan git (mis. `secrets.h`) atau di NVS/flash.
- Bila perangkat hilang atau token bocor, minta admin **mengganti token**
  (Lampiran A). Token lama langsung tidak berlaku.

---

## 7. Pemasangan sensor (ultrasonik)

```
  ┌──── sensor ────┐  ─┬─
  │                │   │ ≥ zona mati sensor
  │~~~~ penuh ~~~~~│  ─┼─            ─┬─
  │                │   │ jarak       │
  │      air       │   │ sensor      │ tinggi air maksimum (= 100%)
  │                │   │ ke dasar    │
  └────────────────┘  ─┴─            ─┴─
```

- **WAJIB** memasang sensor di atas tangki, menghadap tegak lurus ke permukaan
  air, dan jauh dari dinding, pipa masuk, dan pelampung.
- **WAJIB** memberi jarak antara sensor dan permukaan air saat penuh minimal
  sebesar zona mati sensor:

  | Sensor | Zona mati (perkiraan, cek datasheet) |
  |---|---|
  | JSN-SR04T | ±20–25 cm → pasang ≥ 25–30 cm di atas level penuh |
  | HC-SR04 / A02YYUW | ±3 cm → pasang ≥ 5–10 cm |

- Bila modul sensor diberi daya 5V, **WAJIB** memasang pembagi tegangan pada
  pin ECHO, karena pin ESP32 hanya tahan 3,3V.
- Bila memakai pelampung, **DISARANKAN** memasangnya sedikit di atas batas
  penuh (mis. setara 95%), agar pelampung menjadi pengaman terakhir sebelum
  meluap. Laporkan ketinggiannya ke admin.
- Setelah pemasangan, **WAJIB** melaporkan ke admin aplikasi:
  - **Jarak sensor ke dasar** tangki (cm), diukur dari permukaan sensor ke
    lantai tangki.
  - **Tinggi air maksimum** yang dianggap 100% (cm).
  - **Kapasitas** tangki pada tinggi itu (liter).

  Ketiga angka ini diisi admin di aplikasi: **Pengaturan → Buka kunci (PIN
  admin) → Dimensi tangki → Simpan untuk semua HP**. Nilainya berlaku untuk
  semua HP.

---

## 8. Checklist sebelum serah terima

- [ ] `curl` (3.3) menghasilkan `204`.
- [ ] Data masuk ke database (query di bawah), dengan nilai masuk akal dan
      interval sesuai.
- [ ] Aplikasi menampilkan nama perangkat dengan pill **"Live"**, dan
      persentasenya sesuai kondisi tangki nyata.
- [ ] Saat sensor dicabut atau terhalang, **tidak ada** data yang terkirim
      (bukan `0`/`-1`).
- [ ] Saat Wi-Fi dimatikan lalu dinyalakan, perangkat tersambung dan mengirim
      lagi tanpa di-restart manual.
- [ ] Saat token sengaja diubah, perangkat mendapat `403` dan tidak mengulang
      cepat.
- [ ] Sertifikat server diverifikasi (bukan `setInsecure()`).
- [ ] Token dan password tidak tercetak di log dan tidak ada di repository.
- [ ] Bila ada pelampung: mengangkat pelampung dengan tangan mengirim `"1"`
      dan aplikasi menjadi **Penuh**; melepasnya mengirim `"0"`.
- [ ] Dimensi tangki (bagian 7) sudah diserahkan ke admin aplikasi.

Query untuk memeriksa data masuk:

```sql
select value,
       "timestamp" at time zone 'Asia/Makassar' as waktu_wita,
       "timestamp" - lag("timestamp") over (order by "timestamp") as jarak_waktu
from public.sensor_readings
where device_id = '<DEVICE_ID>' and sensor_id = '<SENSOR_ID>'
order by "timestamp" desc
limit 20;
```

---

## Lampiran A — Setup Supabase (untuk admin)

Bagian ini dijalankan oleh pengelola Supabase, **bukan** di perangkat.
Prasyarat: tabel `devices`, `sensors`, `device_sensors`, `sensor_readings`
sudah ada dan [`supabase/setup.sql`](../supabase/setup.sql) sudah dijalankan.

### A.1 Fungsi `submit_reading` (sekali saja)

Tempel di **SQL Editor**, lalu **Run**. Aman dijalankan ulang.

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

### A.2 Daftarkan perangkat & sensor

Pastikan perangkat ada di `devices`, sensor ada di `sensors`, dan keduanya
terhubung di `device_sensors`. Untuk sensor ultrasonik, isi `unit = 'cm'` dan
nama yang memuat *Ultrasonic*, *JSN-SR04T*, atau *jarak*, agar aplikasi
otomatis membaca nilainya sebagai jarak. Untuk pelampung, daftarkan sebagai
sensor tersendiri (mis. `name = 'Float switch'`, `unit` kosong,
`data_type = 'boolean'`) dan hubungkan ke perangkat yang sama. Daftar ID untuk
diserahkan ke IoT engineer:

```sql
select d.name as device, d.id as device_id, s.name as sensor, s.id as sensor_id, s.unit
from public.device_sensors ds
join public.devices d on d.id = ds.device_id
join public.sensors s on s.id = ds.sensor_id
order by d.name, s.name;
```

### A.3 Buat / ganti token perangkat

Jalankan per perangkat. Langkah (a) menghasilkan token: **salin dan serahkan
ke IoT engineer lewat saluran aman**, karena setelah ini hanya hash-nya yang
tersimpan.

```sql
-- (a) buat token acak 48 karakter
select encode(extensions.gen_random_bytes(24), 'hex') as token;

-- (b) simpan hash-nya (ganti <DEVICE_ID> dan <TOKEN>)
insert into public.device_tokens (device_id, token_hash)
values ('<DEVICE_ID>', extensions.crypt('<TOKEN>', extensions.gen_salt('bf')))
on conflict (device_id) do update
  set token_hash = excluded.token_hash, created_at = now();
```

Menjalankan (a)+(b) lagi untuk perangkat yang sama **mengganti** token lama.
Token asli akan terlihat di riwayat SQL Editor, jadi batasi siapa yang punya
akses ke dashboard Supabase.

### A.4 Mencabut akses perangkat

```sql
delete from public.device_tokens where device_id = '<DEVICE_ID>';
```
