# GroundTank — Monitoring Air Ground Tank

Aplikasi Flutter untuk memantau ketinggian air di ground tank secara
real-time, lengkap dengan notifikasi saat air **penuh** atau **kosong**. Data
dibaca dari sensor ultrasonik (mis. ESP32 + JSN-SR04T) yang tersimpan di
Supabase, atau dari mode **Demo** untuk mencoba tanpa perangkat.

## Isi aplikasi

### Dashboard
- **Gauge tangki** beranimasi dengan permukaan air bergelombang dan dua garis
  putus-putus penanda batas penuh dan kosong.
- **Persentase** terisi, **status** (Normal / Penuh / Kosong), tinggi air
  terhadap tinggi maksimum, dan waktu pembaruan terakhir.
- **Kartu ringkasan**:
  - *Volume air*: liter saat ini dari kapasitas total.
  - *Ketinggian*: tinggi air dalam cm (satu desimal, mis. `109,8 cm`).
  - *Ruang kosong*: liter yang belum terisi.
  - *Tren*: Mengisi / Berkurang / Stabil, laju %/menit, dan perkiraan waktu
    sampai penuh atau kosong.
- **Grafik riwayat ketinggian** dengan garis batas penuh dan kosong.
- **Banner peringatan** bila sensor tidak terhubung atau perangkat berhenti
  mengirim data.
- Tarik ke bawah untuk memperbarui.

Pill di kanan atas menunjukkan asal dan kesegaran data:

| Pill | Arti |
|---|---|
| **Demo** | Data simulasi |
| **Live** | Membaca Supabase, data terbaru berumur < 2 menit |
| **Tidak aktif** | Membaca Supabase, tetapi perangkat tidak mengirim data > 2 menit |
| **Offline** | Gagal menghubungi Supabase (alasannya tampil di banner) |

### Notifikasi
- Notifikasi sistem muncul **sekali** setiap kali air *masuk* ke status penuh
  atau kosong. Status baru dilepas setelah air bergeser 3% dari batasnya
  (histeresis), sehingga riak air tidak memicu notifikasi berulang.
- Saat aplikasi terbuka, peringatan juga tampil sebagai toast di layar.
- Tab **Notifikasi** menyimpan riwayatnya per hari (maks. 50), dengan badge
  untuk yang belum dibaca.
- Di Android, tangki tetap diperiksa saat aplikasi ditutup, paling cepat tiap
  ±15 menit.

### Pengaturan

| Bagian | Isi |
|---|---|
| **Sumber data** | *Demo* atau *Database (Supabase)*. Untuk Database: pilih **Perangkat**, **Sensor ketinggian**, **arti nilai**, lalu **Uji koneksi** |
| **Dimensi tangki** | Tinggi air maksimum (cm), jarak sensor ke dasar (cm), kapasitas (L) |
| **Ambang & pembaruan** | Batas penuh (default 90%), batas kosong (default 15%), interval pembaruan (default 5 detik) |
| **Notifikasi** | Aktif/nonaktif peringatan, pantau di latar belakang (Android), kirim notifikasi uji |
| **Tampilan** | Ikuti sistem / Terang / Gelap |

> Perubahan Sumber data, Dimensi tangki, Ambang, dan Notifikasi baru berlaku
> setelah menekan **Simpan pengaturan** di bagian bawah. Tampilan berlaku
> langsung.

#### Arti nilai: Persen, Tinggi air, atau Jarak
Menentukan arti angka `value` yang dikirim perangkat. Pilihannya ditebak
otomatis dari `sensors.unit` dan nama sensor, dan bisa diubah:

| Pilihan | Pilih ketika perangkat mengirim… | Ciri datanya |
|---|---|---|
| **Jarak** | jarak sensor ke permukaan air, dari sensor ultrasonik/laser di atas tangki | makin **kecil** saat air makin penuh |
| **Tinggi air** | tinggi air dari dasar (sudah dihitung di perangkat, atau sensor tekanan) | makin **besar** saat penuh, dalam cm |
| **Persen** | persen terisi yang sudah dihitung perangkat | selalu 0–100 |

Disarankan perangkat mengirim **jarak mentah** dan memilih **Jarak**. Ukuran
tangki cukup diatur di aplikasi, tanpa mengubah firmware.

#### Dimensi tangki

```
  ┌──── sensor ────┐  ─┬─
  │                │   │ ≥ zona mati sensor (JSN-SR04T ±25 cm)
  │~~~~ penuh ~~~~~│  ─┼─            ─┬─
  │                │   │ jarak       │
  │      air       │   │ sensor      │ tinggi air maksimum (= 100%)
  │                │   │ ke dasar    │
  └────────────────┘  ─┴─            ─┴─
```

- **Jarak sensor ke dasar**: dari permukaan sensor sampai lantai tangki. Hanya
  dipakai bila arti nilai = Jarak.
- **Tinggi air maksimum**: tinggi air dari lantai saat dianggap penuh 100%.
- **Kapasitas**: liter pada tinggi maksimum. Balok: panjang × lebar × tinggi
  (cm) ÷ 1000; tabung: 3,14 × r² × tinggi (cm) ÷ 1000.
- Aplikasi hanya mensyaratkan jarak sensor ke dasar ≥ tinggi maksimum. Namun
  sensor punya **jarak minimum** yang tidak bisa diukur, jadi beri selisih
  minimal sebesar zona mati sensor (JSN-SR04T ±25 cm, HC-SR04 ±5 cm). Bila
  sensor sudah terpasang terlalu dekat, turunkan tinggi maksimum.

### Cara angka di dashboard dihitung
Database menyimpan nilai mentah sensor. Semua angka di dashboard dihitung dari
nilai itu dan Dimensi tangki:

```
Jarak       : persen = (jarak sensor ke dasar − value) / tinggi maksimum × 100
Tinggi air  : persen = value / tinggi maksimum × 100
Persen      : persen = value
                         (dibatasi 0–100%)
tinggi air  = persen × tinggi maksimum
volume      = persen × kapasitas
ruang kosong = kapasitas − volume
```

Contoh (Jarak, 220 cm ke dasar, maks. 200 cm, 5.000 L), `value = 110.2`:
tinggi air 109,8 cm → **54,9%** → 2.745 L.

Karena yang disimpan nilai mentah, mengubah Dimensi tangki langsung
menghitung ulang dashboard dan grafik tanpa mengubah data di Supabase.

## Memakai data Supabase

### 1. Siapkan database
Aplikasi membaca tabel `devices`, `sensors`, `device_sensors`, dan
`sensor_readings`. Jalankan [`supabase/setup.sql`](supabase/setup.sql) sekali
di **SQL Editor**. Isinya:
- **Index** agar query pembacaan terbaru dan riwayat tetap cepat.
- **RLS read-only**: aplikasi hanya bisa membaca.
- **Realtime** pada `sensor_readings`, agar dashboard berubah saat data baru
  masuk. Tanpa ini aplikasi tetap jalan dengan polling.

⚠️ Bila perangkat saat ini meng-*insert* `sensor_readings` memakai anon key,
RLS akan memblokirnya. Pindahkan perangkat ke fungsi `submit_reading`.

### 2. Kirim data dari perangkat
Panduan fungsi `submit_reading`, token per perangkat, dan format request ada
di [`firmware/README.md`](firmware/README.md).

### 3. Data dummy (opsional)
[`supabase/seed.sql`](supabase/seed.sql) mengisi 2 perangkat, 3 sensor, dan
±180 pembacaan (2 jam naik hampir penuh lalu turun hampir kosong) untuk
mencoba tanpa perangkat. Aman dijalankan ulang. Di bagian bawahnya ada contoh
`insert` untuk memicu notifikasi dan perintah untuk menghapus data dummy.

### 4. Hubungkan aplikasi
**Pengaturan → Sumber data → Database (Supabase) → Perangkat → Sensor
ketinggian → Uji koneksi → Simpan pengaturan.** Subjudul di dashboard berubah
menjadi nama perangkat.

## Menjalankan

```bash
flutter pub get
cp env.example.json env.json      # isi URL proyek + publishable key Supabase
flutter run --dart-define-from-file=env.json
flutter test
flutter build apk --release --dart-define-from-file=env.json
```

- Di VS Code, pilih konfigurasi **GroundTank** (`.vscode/launch.json`).
- Tanpa `env.json`, aplikasi berjalan dalam mode Demo, dan opsi Database
  ditandai "Belum dikonfigurasi".
- Setelah mengubah `env.json`, hentikan lalu jalankan ulang aplikasi; hot
  reload tidak membaca ulang kunci.
- `env.json` diabaikan git. Publishable/anon key aman berada di aplikasi
  karena akses diatur RLS. **Jangan pernah** memakai `service_role` key.

## Struktur kode

```
lib/
  background/   # pemeriksaan berkala Android (WorkManager) saat app ditutup
  config/       # kunci Supabase dari --dart-define-from-file
  models/       # konfigurasi tangki, pembacaan, status, baris tabel Supabase
  services/     # konversi nilai & aturan status (logika murni, diuji),
                # query Supabase (TankRepository), sumber data Demo/Database,
                # evaluasi notifikasi, penyimpanan lokal, format teks
  providers/    # state: konfigurasi, monitor (riwayat + Realtime + polling),
                # database, riwayat notifikasi, tema
  screens/      # Dashboard, Notifikasi, Pengaturan, pemilih perangkat & sensor
  widgets/      # komponen UI, gauge tangki, grafik, kartu ringkasan
  theme/        # warna (terang + gelap), tipografi, animasi
supabase/       # setup.sql (index, RLS, Realtime), seed.sql (data dummy)
firmware/       # panduan unggah data perangkat ke Supabase
tool/           # make_icon.py: menggambar ulang ikon aplikasi
```

## Catatan
- Pemeriksaan saat aplikasi ditutup hanya di Android, dengan interval minimum
  15 menit (bisa lebih lama saat HP hemat daya). Peringatan instan saat
  aplikasi tertutup memerlukan push dari server (mis. Edge Function Supabase →
  Firebase Cloud Messaging). Fitur ini belum ada.
- Di iOS, notifikasi dikirim selama aplikasi terbuka.
