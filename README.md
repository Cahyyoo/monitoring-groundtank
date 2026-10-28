# GroundTank — Monitoring Air Ground Tank

Aplikasi Flutter untuk memantau ketinggian air di ground tank: dashboard
ketinggian secara real-time dan notifikasi saat air **penuh** atau **kosong**.

Struktur, gaya, dan pola kodenya mengikuti `Atara/mobile` (antarmuka Cupertino
di dalam `MaterialApp`, Riverpod `StateNotifier`, font Plus Jakarta Sans yang
dibundel, `InsetSection`/`AppButton`/`AppToast`), dengan palet yang diganti
menjadi tema air: navy → biru → cyan.

## Fitur

- **Dashboard** — gauge tangki beranimasi (gelombang + garis ambang), persentase,
  status (Normal / Penuh / Kosong), volume (L), ketinggian (cm), ruang kosong,
  tren pengisian + perkiraan waktu sampai penuh/kosong, dan grafik riwayat.
- **Notifikasi** — notifikasi sistem sekali setiap kali air *masuk* ke status
  penuh atau kosong, dengan histeresis 3% agar riak air tidak memicu notifikasi
  berulang. Riwayatnya tersimpan di tab Notifikasi (badge belum dibaca).
- **Latar belakang (Android)** — WorkManager memeriksa tangki tiap ~15 menit
  saat aplikasi ditutup. Saat aplikasi terbuka, pembacaan setiap 5 detik
  (bisa diatur), ditambah Realtime untuk mode Database.
- **Database Supabase** — membaca `sensor_readings` untuk satu perangkat dan
  sensor pilihan; riwayat grafik diisi dari database, pembacaan baru masuk
  lewat Realtime dengan polling sebagai cadangan, dan perangkat yang berhenti
  mengirim ditandai "Tidak aktif".
- **Pengaturan** — sumber data (Demo / Database) dengan pemilih perangkat &
  sensor + uji koneksi, dimensi tangki, ambang penuh/kosong, interval,
  notifikasi, tampilan terang/gelap.
- **Mode Demo** — tangki simulasi yang terisi dan terkuras dalam siklus 6 menit,
  untuk mencoba aplikasi sebelum sensor terpasang.

## Menjalankan

```bash
flutter pub get
cp env.example.json env.json      # isi URL proyek + publishable/anon key Supabase
flutter run --dart-define-from-file=env.json
flutter test
flutter build apk --release --dart-define-from-file=env.json
```

Di VS Code cukup pilih konfigurasi **GroundTank** (`.vscode/launch.json` sudah
membawa flag tersebut). Tanpa `env.json`, aplikasi tetap berjalan dalam mode
**Demo** dan opsi Database ditandai "Belum dikonfigurasi".

`env.json` diabaikan git. Kunci *publishable/anon* memang aman berada di
aplikasi klien — yang menentukan apa yang boleh dibaca adalah kebijakan RLS —
tetapi **jangan pernah** memakai `service_role` key di sini.

## Setup Supabase

Aplikasi membaca empat tabel yang sudah ada: `devices`, `sensors`,
`device_sensors`, dan `sensor_readings`. Jalankan
[`supabase/setup.sql`](supabase/setup.sql) sekali di **SQL Editor**:

1. **Index** `(device_id, sensor_id, timestamp desc)` agar query "pembacaan
   terbaru" dan riwayat tetap cepat saat `sensor_readings` membesar.
2. **RLS** + kebijakan `SELECT` (read-only) untuk aplikasi. ⚠️ Jika perangkat
   saat ini meng-*insert* `sensor_readings` memakai anon key, mengaktifkan RLS
   akan memblokir insert tersebut. Pindahkan perangkat ke fungsi
   `submit_reading` (lihat [`firmware/README.md`](firmware/README.md)), jangan
   membuka policy `insert` untuk anon.
3. **Realtime** pada `sensor_readings`, supaya dashboard langsung berubah saat
   baris baru masuk. Tanpa ini aplikasi tetap jalan dengan polling.

Lalu di aplikasi: **Pengaturan → Sumber data → Database → Perangkat → Sensor
ketinggian → Uji koneksi → Simpan pengaturan**.

Untuk mengirim data dari ESP32 ke Supabase (fungsi `submit_reading`, token per
perangkat, format request), lihat [`firmware/README.md`](firmware/README.md).

### Data dummy

[`supabase/seed.sql`](supabase/seed.sql) mengisi 2 perangkat, 3 sensor, dan
±180 pembacaan untuk mencoba aplikasi tanpa ESP32: "ESP32 Ground Tank" dengan
sensor ultrasonik (2 jam terakhir, naik hampir penuh lalu turun hampir kosong,
berakhir ±55%) dan sensor suhu, serta "ESP32 Toren Atas" (nonaktif, data
sehari lalu). Aman dijalankan ulang. Di bagian bawah file ada contoh `insert`
untuk memicu notifikasi penuh/kosong dan perintah untuk menghapus semua data
dummy.

### Arti `sensor_readings.value`

Kolom `value` bertipe `text`; aplikasi menerima `"75.3"`, `"75,3"`, atau
`" 75 "`, dan melewati baris yang bukan angka. Artinya ditebak dari
`sensors.unit` saat sensor dipilih, dan bisa diubah di Pengaturan:

| `sensors.unit` | Nama / `data_type` sensor | Dibaca sebagai |
|---|---|---|
| `%`, `percent`, `persen` | apa saja | Persen terisi |
| `cm`, `mm`, `m` | memuat *jarak, distance, ultrasonic, sonar, sr04* | Jarak sensor ke permukaan air → tinggi air = *jarak sensor ke dasar* − nilai |
| `cm`, `mm`, `m` | lainnya | Tinggi air dari dasar tangki |

`mm` dan `m` dikonversi ke cm. Bila pembacaan terbaru lebih tua dari 3× interval
(minimal 2 menit), dashboard menandai perangkat **Tidak aktif**.

## Struktur kode

```
lib/
  background/   # WorkManager: pemeriksaan berkala Android saat app ditutup
  config/       # Env: kunci Supabase dari --dart-define-from-file
  models/       # TankConfig, TankReading, TankLevel/AlertEntry,
                # Device, Sensor, SensorReading (baris tabel Supabase)
  services/     # reading_conversion + tank_rules (logika murni, diuji),
                # tank_repository (semua query Supabase), tank_source
                # (Demo/Database), tank_evaluator (status → notifikasi),
                # notification_service, settings_service, format
  providers/    # config, monitor (riwayat + Realtime + polling), database
                # (client, repository, daftar perangkat/sensor), alerts, theme
  screens/      # HomeShell, Dashboard, Notifikasi, Pengaturan,
                # pemilih perangkat & sensor
  widgets/      # ios/ (AppPage, AsyncListPage, InsetSection, AppButton, AppToast),
                # dashboard/ (TankGauge, LevelChart, StatTile), brand/, motion/
  theme/        # AppColors (palet air, terang + gelap), AppText, AppMotion
supabase/setup.sql  # index, RLS read-only, Realtime untuk tabel sensor
tool/make_icon.py   # menggambar ulang ikon launcher Android & iOS
```

Seperti di Atara, **keputusan yang layak diuji diangkat keluar dari layar**
menjadi fungsi murni (`inferValueKind`, `readingFrom`, `classifyLevel`,
`alertFor`, `validateConfig`, `isStale`, `trendOf`). Semua query Supabase
hanya ada di `TankRepository`, sehingga layar dan provider tidak pernah
menyentuh nama tabel atau kolom. Dashboard dan pemeriksaan latar belakang memakai
jalur yang sama (`TankEvaluator`), dan status terakhir disimpan di
SharedPreferences, sehingga tangki yang penuh saat aplikasi ditutup hanya
diumumkan sekali.

## Catatan

- Pemeriksaan latar belakang hanya di Android; interval minimum WorkManager
  adalah 15 menit dan bisa lebih lama saat HP dalam mode hemat daya. Untuk
  peringatan instan saat aplikasi tertutup, perlu push dari server (mis.
  Database Webhook/Edge Function Supabase → Firebase Cloud Messaging) — belum
  termasuk.
- `workmanager_android` saat ini masih memakai Kotlin Gradle Plugin; Flutter
  memberi peringatan bahwa versi mendatang akan menolaknya. Perbarui plugin
  saat versi yang mendukung *Built-in Kotlin* tersedia.
