# GroundTank — Monitoring Air Ground Tank

Aplikasi Flutter untuk memantau ketinggian air di ground tank secara
real-time, lengkap dengan notifikasi saat air **penuh** atau **kosong**. Semua
data dibaca dari Supabase, yang diisi oleh perangkat sensor (mis. ESP32 +
JSN-SR04T, dan opsional sensor pelampung). Pengaturan tangki disimpan
terpusat di Supabase dan dikunci dengan PIN admin, sehingga semua HP memantau
tangki yang sama dengan cara yang sama. Untuk mencoba tanpa perangkat, isi
data dummy dari [`supabase/seed.sql`](supabase/seed.sql).

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
- **Grafik riwayat ketinggian** dengan garis batas penuh dan kosong. Rentangnya
  bisa dipilih: **12 jam** (bawaan), **24 jam**, **7 hari**, **1 bulan** (30 hari
  terakhir), atau **rentang tanggal** sendiri. Tiap rentang dirangkum menjadi
  paling banyak 240 titik rata-rata (1 bulan: 1 titik ±3 jam), jadi kenaikan
  singkat bisa tidak terlihat di rentang panjang.
- **Sensor pelampung** (bila dipakai): status *Penuh* / *Belum penuh* dan
  kapan terakhir diperbarui.
- **Banner peringatan** bila sensor tidak terhubung, perangkat berhenti
  mengirim data, atau pelampung dan sensor ketinggian **tidak sepakat**
  (mis. pelampung penuh tetapi ketinggian jauh di bawah batas penuh).
- Tarik ke bawah untuk memperbarui.

Bila perangkat dan sensor belum dipilih, dashboard menampilkan pesan
**Sensor belum dipilih** dan belum membaca apa pun.

Pill di kanan atas menunjukkan kesegaran data:

| Pill | Arti |
|---|---|
| **Belum diatur** | Perangkat dan sensor belum dipilih di Pengaturan |
| **Menghubungkan** | Sedang mengambil data pertama |
| **Live** | Membaca Supabase, data terbaru berumur < 2 menit |
| **Tidak aktif** | Membaca Supabase, tetapi perangkat tidak mengirim data > 2 menit |
| **Offline** | Gagal menghubungi Supabase (alasannya tampil di banner) |

### Notifikasi
- Notifikasi sistem muncul **sekali** setiap kali air *masuk* ke status penuh
  atau kosong. Status baru dilepas setelah air bergeser 3% dari batasnya
  (histeresis), sehingga riak air tidak memicu notifikasi berulang.
- **Pelampung terangkat = penuh**, apa pun angka sensor ketinggian. Isi
  notifikasinya menyebut bahwa pelampung yang mendeteksi.
- Saat aplikasi terbuka, peringatan juga tampil sebagai toast di layar.
- Tab **Notifikasi** menyimpan riwayatnya per hari (maks. 50), dengan badge
  untuk yang belum dibaca.
- Di Android, tangki tetap diperiksa saat aplikasi ditutup, paling cepat tiap
  ±15 menit.

### Pengaturan
Pengaturan terbagi dua:

| Bagian | Isi | Berlaku untuk | Disimpan di |
|---|---|---|---|
| **Pengaturan tangki** | Perangkat, sensor ketinggian, **arti nilai**, sensor pelampung (opsional), dimensi tangki, batas penuh (default 90%) dan kosong (default 15%) | **Semua HP** | Supabase (`tank_settings`) |
| **HP ini** | Interval pembaruan (default 5 detik), notifikasi aktif/nonaktif, pantau di latar belakang (Android), kirim notifikasi uji | HP ini saja | HP |
| **Tampilan** | Ikuti sistem / Terang / Gelap | HP ini saja | HP, langsung berlaku |

**Pengaturan tangki terkunci.** Semua orang bisa melihatnya, tetapi untuk
mengubahnya tekan **Buka kunci untuk mengubah**, masukkan **PIN admin**, ubah
isinya, lalu tekan **Simpan untuk semua HP**. HP lain ikut berubah seketika
(Realtime) atau saat aplikasi dibuka lagi. Setelah disimpan, kunci tertutup
kembali.

- PIN diperiksa oleh server, bukan oleh aplikasi, dan tidak disimpan di HP.
- Setelah **5 kali PIN salah**, kunci tertahan **5 menit**.
- Sebelum ada pengaturan bersama, tiap HP memakai pengaturannya sendiri.
- Perubahan **HP ini** berlaku setelah menekan **Simpan pengaturan HP ini**.

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

#### Sensor pelampung
Opsional, sebagai penanda tangki penuh. Perangkat mengirim `1` saat pelampung
terangkat dan `0` saat turun, ke sensor tersendiri pada perangkat yang sama
(aturannya di [`firmware/README.md`](firmware/README.md#41-sensor-pelampung-opsional)).
Pilih di **Pengaturan tangki → Sensor pelampung**. Sensor pelampung harus
berbeda dari sensor ketinggian. Di data dummy, sensor pelampung adalah
*Float switch* dengan `sensor_id` `b2000000-0000-4000-8000-000000000004`.

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
- **Pengaturan bersama**: tabel `tank_settings` (satu baris, hanya-baca bagi
  aplikasi), tabel `settings_pin` (hash PIN, tidak terbaca aplikasi), dan
  fungsi `verify_settings_pin` / `update_tank_settings` yang memeriksa PIN dan
  memvalidasi isinya di server.
- **`sensor_readings_buckets`**: fungsi baca untuk grafik, yang merangkum data di
  server karena satu request tidak bisa mengambil puluhan ribu baris.

⚠️ Bila perangkat saat ini meng-*insert* `sensor_readings` memakai anon key,
RLS akan memblokirnya. Pindahkan perangkat ke fungsi `submit_reading`.

### 2. Buat PIN admin
Jalankan di **SQL Editor** (ganti `<PIN-BARU>`, minimal 6 karakter). Jalankan
lagi untuk mengganti PIN.

```sql
insert into public.settings_pin (id, pin_hash)
values (1, extensions.crypt('<PIN-BARU>', extensions.gen_salt('bf')))
on conflict (id) do update
  set pin_hash = excluded.pin_hash, failed_attempts = 0, locked_until = null;
```

PIN asli terlihat di riwayat SQL Editor, jadi batasi siapa yang punya akses ke
dashboard Supabase.

### 3. Kirim data dari perangkat
Panduan fungsi `submit_reading`, token per perangkat, dan format request ada
di [`firmware/README.md`](firmware/README.md).

### 4. Data dummy (opsional)
[`supabase/seed.sql`](supabase/seed.sql) mengisi 2 perangkat, 4 sensor
(termasuk pelampung), ±300 pembacaan (2 jam naik hampir penuh lalu turun
hampir kosong), dan pengaturan bersama contoh bila belum ada. Aman dijalankan
ulang. Di bagian bawahnya ada contoh `insert` untuk memicu notifikasi dan
perintah untuk menghapus data dummy.

ID tetap di data dummy:

| Baris | Nama | ID |
|---|---|---|
| Perangkat | ESP32 Ground Tank | `a1000000-0000-4000-8000-000000000001` |
| Perangkat | ESP32 Toren Atas | `a1000000-0000-4000-8000-000000000002` |
| Sensor ketinggian | Ultrasonic JSN-SR04T (cm) | `b2000000-0000-4000-8000-000000000001` |
| Sensor lain | Suhu air DS18B20 (°C) | `b2000000-0000-4000-8000-000000000002` |
| Sensor ketinggian | Level toren (%) | `b2000000-0000-4000-8000-000000000003` |
| **Sensor pelampung** | Float switch (1 = penuh, 0 = belum) | `b2000000-0000-4000-8000-000000000004` |

Ultrasonic, suhu, dan pelampung terpasang di **ESP32 Ground Tank**; Level
toren di **ESP32 Toren Atas**.

### 5. Hubungkan aplikasi
**Pengaturan → Buka kunci untuk mengubah (PIN admin) → Perangkat → Sensor
ketinggian → (Sensor pelampung) → Uji koneksi → Simpan untuk semua HP.**
Subjudul di dashboard berubah menjadi nama perangkat, di semua HP.

## Menjalankan

```bash
flutter pub get
cp env.example.json env.json      # isi URL proyek + publishable key Supabase
flutter run --dart-define-from-file=env.json
flutter test
```

- Di VS Code, pilih konfigurasi **GroundTank** (`.vscode/launch.json`).
- `env.json` wajib: tanpa kunci Supabase aplikasi tidak punya sumber data, dan
  Pengaturan menampilkan "Supabase belum dikonfigurasi".
- Setelah mengubah `env.json`, hentikan lalu jalankan ulang aplikasi; hot
  reload tidak membaca ulang kunci.
- `env.json` diabaikan git. Publishable/anon key aman berada di aplikasi
  karena akses diatur RLS, dan perubahan pengaturan bersama butuh PIN yang
  diperiksa server. **Jangan pernah** memakai `service_role` key.

### Build rilis (ukuran kecil)
Untuk mencoba APK rilis di laptop. Rilis ke pengguna dilakukan lewat
[GitHub Actions](#merilis-versi-baru).

```bash
# APK per arsitektur, untuk dipasang langsung
flutter build apk --release --split-per-abi --obfuscate \
  --split-debug-info=build/symbols --dart-define-from-file=env.json

# Untuk Google Play
flutter build appbundle --release --obfuscate \
  --split-debug-info=build/symbols --dart-define-from-file=env.json
```

Hasilnya ada di `build/app/outputs/flutter-apk/`:

| File | Untuk |
|---|---|
| `app-arm64-v8a-release.apk` | Hampir semua HP Android sejak ±2017 (pilih ini bila ragu) |
| `app-armeabi-v7a-release.apk` | HP Android lama (32-bit) |
| `app-x86_64-release.apk` | Emulator |

APK gabungan tanpa `--split-per-abi` membawa ketiga arsitektur sekaligus,
sehingga ukurannya hampir 3×. `build/symbols` berisi simbol untuk membaca
stack trace dari build `--obfuscate`; simpan bersama rilisnya dan jangan
dibagikan.

Build rilis butuh `android/key.properties` dan `android/upload-keystore.jks`
(keduanya diabaikan git). Tanpa itu build berhenti dengan pesan error.

### Merilis versi baru
Aplikasi Android memeriksa
[GitHub Release](https://github.com/Cahyyoo/monitoring-groundtank/releases) saat
dibuka, dan saat kembali aktif bila cek terakhir lebih dari 12 jam. Bila ada versi
lebih baru, muncul modal untuk mengunduh dan memasangnya. Android tetap meminta
konfirmasi pemasangan, dan pertama kali juga meminta izin memasang aplikasi dari
sumber ini.

Rilis dibuat oleh [GitHub Actions](.github/workflows/release.yml). Setelah
perubahan di-push, cukup kirim tag `vX.Y.Z`. Pesan tag menjadi catatan rilis di
modal aplikasi.

```bash
git push
git tag -a v2.0.1 -m "Isi catatan rilis"
git push origin v2.0.1
```

Workflow lalu menjalankan test, membangun ketiga APK, dan membuat release.
Prosesnya terlihat di tab **Actions** di GitHub. Test gagal berarti tidak ada
rilis.

- **Nama versi** diambil dari tag, dan **`versionCode`** dari nomor run + 100.
  Keduanya tidak perlu diubah di `pubspec.yaml`, yang hanya berlaku untuk build di
  laptop.
- **Nomor tag harus lebih tinggi dari release terbaru.** Tag yang sudah dipakai
  tidak bisa dikirim ulang.
- Simbol untuk membaca stack trace tersimpan 90 hari di artifact tiap run.

#### Persiapan (sekali saja)
Simpan keystore dan `env.json` sebagai secret repo. Jalankan di Git Bash dari folder
proyek:

```bash
base64 -w0 android/upload-keystore.jks | gh secret set KEYSTORE_BASE64
gh secret set KEY_PROPERTIES < android/key.properties
gh secret set ENV_JSON < env.json
```

Setelah mengganti keystore atau isi `env.json`, jalankan lagi perintah yang
bersangkutan.

#### Yang tidak boleh terlewat
- **Jangan mengunggah APK dari laptop ke release.** `versionCode`-nya lebih kecil
  dari hasil Actions, sehingga ditolak Android sebagai versi lebih lama.
- **Backup `android/upload-keystore.jks` dan `android/key.properties`** ke tempat
  aman di luar repo. Secret tidak bisa diunduh lagi dari GitHub. Bila keduanya hilang,
  HP yang sudah terpasang tidak bisa di-update lagi dan harus uninstall.
- HP yang masih memakai APK sebelum versi 1.1.0 (ditandatangani debug key) harus
  **uninstall sekali** lalu memasang APK baru secara manual. Setelah itu update
  berjalan otomatis. Pengaturan tangki aman di Supabase; yang hilang hanya data di
  HP, seperti interval dan riwayat notifikasi.
- Release bersifat publik: siapa pun bisa mengunduh APK dan **membaca** data sensor
  dengan kunci di dalamnya, tetapi tidak bisa mengubah apa pun tanpa token perangkat
  atau PIN admin.

## Struktur kode

```
lib/
  background/   # pemeriksaan berkala Android (WorkManager) saat app ditutup
  config/       # kunci Supabase dari --dart-define-from-file
  models/       # konfigurasi tangki, pengaturan bersama, rentang grafik,
                # pembacaan, status, baris tabel Supabase
  services/     # konversi nilai & aturan status (logika murni, diuji),
                # query Supabase (TankRepository), sumber data,
                # evaluasi notifikasi, cek pembaruan, penyimpanan lokal, format teks
  providers/    # state: konfigurasi, sinkron pengaturan bersama, monitor
                # (riwayat + Realtime + polling), database, notifikasi, tema
  screens/      # Dashboard, Notifikasi, Pengaturan, pemilih perangkat & sensor
  widgets/      # komponen UI, gauge tangki, grafik, kartu ringkasan
  theme/        # warna (terang + gelap), tipografi, animasi
supabase/       # setup.sql (index, RLS, Realtime, pengaturan bersama + PIN),
                # seed.sql (data dummy)
firmware/       # panduan unggah data perangkat ke Supabase
tool/           # make_icon.py: menggambar ulang ikon aplikasi
```

## Catatan
- Pemeriksaan saat aplikasi ditutup hanya di Android, dengan interval minimum
  15 menit (bisa lebih lama saat HP hemat daya). Peringatan instan saat
  aplikasi tertutup memerlukan push dari server (mis. Edge Function Supabase →
  Firebase Cloud Messaging). Fitur ini belum ada.
- Di iOS, notifikasi dikirim selama aplikasi terbuka.
