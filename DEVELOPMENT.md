# Panduan Developer GroundTank

Untuk developer yang baru bergabung di proyek ini. Isi aplikasi dan cara memakainya
ada di [`README.md`](README.md), sedangkan aturan untuk perangkat sensor ada di
[`firmware/README.md`](firmware/README.md).

1. [Persiapan](#1-persiapan)
2. [Supabase untuk pengembangan](#2-supabase-untuk-pengembangan)
3. [Mengembangkan](#3-mengembangkan)
4. [Update versi](#4-update-versi)

## 1. Persiapan

### Alat yang perlu dipasang

| Alat | Catatan |
|---|---|
| Flutter **3.44.6** | Samakan dengan versi yang dipakai rilis di [`release.yml`](.github/workflows/release.yml) |
| Android SDK + emulator atau HP | Lewat Android Studio |
| JDK 17 atau lebih baru | Rilis memakai JDK 21 |
| Git | Di Windows, perintah di panduan ini dijalankan di Git Bash |
| [GitHub CLI](https://cli.github.com/) (`gh`) | Hanya untuk merilis. Masuk dengan `gh auth login` |
| VS Code atau Android Studio | VS Code sudah punya konfigurasi **GroundTank** |

Periksa dengan `flutter doctor`, lalu pastikan baris Flutter dan Android tidak bermasalah.

### Akses yang perlu diminta ke pemilik proyek
- **Hak tulis** ke repo [Cahyyoo/monitoring-groundtank](https://github.com/Cahyyoo/monitoring-groundtank).
- **URL proyek dan publishable key Supabase**, atau buat proyek sendiri
  ([bagian 2](#2-supabase-untuk-pengembangan)).
- **PIN admin**, hanya bila memang perlu mengubah pengaturan tangki.

### Menjalankan untuk pertama kali

```bash
git clone https://github.com/Cahyyoo/monitoring-groundtank.git
cd monitoring-groundtank
flutter pub get
cp env.example.json env.json      # lalu isi URL dan publishable key
flutter test
flutter run --dart-define-from-file=env.json
```

Di VS Code, pilih konfigurasi **GroundTank** (F5). Setelah mengubah `env.json`, hentikan lalu
jalankan ulang aplikasi, karena hot reload tidak membaca ulang kunci.

Berhasil bila tab **Pengaturan** tidak menampilkan "Supabase belum dikonfigurasi", dan daftar
perangkat bisa terbuka.

### File rahasia
Semuanya diabaikan git. Jangan pernah meng-commit file ini, dan terima atau kirim lewat jalur
aman (mis. password manager), bukan lewat repo atau chat grup.

| File | Siapa yang butuh | Untuk apa |
|---|---|---|
| `env.json` | Semua developer | Kunci Supabase untuk menjalankan aplikasi |
| `android/key.properties` | Hanya yang build rilis di laptop | Sandi dan alias keystore |
| `android/upload-keystore.jks` | Hanya yang build rilis di laptop | Kunci tanda tangan APK |

`flutter run` dan `flutter test` tidak butuh keystore. Merilis lewat tag juga tidak butuh keystore
di laptop, karena GitHub Actions memakai salinannya di secret repo.

Isi `android/key.properties`:

```properties
storeFile=upload-keystore.jks
storePassword=<sandi keystore>
keyAlias=<alias>
keyPassword=<sandi key>
```

## 2. Supabase untuk pengembangan

### Pilih proyek yang dipakai

| | Proyek bersama (produksi) | Proyek sendiri |
|---|---|---|
| Cocok untuk | Mengubah tampilan atau logika, tanpa mengubah database | Mengubah SQL, mencoba data dummy |
| Persiapan | Cukup `env.json` | Perlu skema tabel dasar, lihat di bawah |
| Risiko | Lihat peringatan di bawah | Tidak mengganggu HP pengguna |

⚠️ **Bila memakai proyek produksi:**
- **Simpan untuk semua HP** benar-benar mengubah pengaturan tangki di semua HP pengguna.
- **Jangan jalankan [`seed.sql`](supabase/seed.sql).** Perangkat dummy akan muncul di daftar perangkat
  semua orang.
- **Jangan pernah memakai `service_role` key**, di aplikasi maupun di perangkat. Key ini melewati RLS.

### Membuat proyek sendiri
1. Buat proyek baru di Supabase.
2. **Buat 4 tabel dasar**: `devices`, `sensors`, `device_sensors`, dan `sensor_readings`. Definisinya
   **belum ada di repo**, dan `setup.sql` hanya menambahkan index, RLS, dan fungsi pada tabel yang
   sudah ada. Minta pemilik proyek mengambil skemanya dari proyek produksi, dengan
   `supabase db dump` (Supabase CLI, butuh Docker) atau `pg_dump --schema-only`, lalu jalankan
   hasilnya di proyek baru.
3. Jalankan [`supabase/setup.sql`](supabase/setup.sql) di **SQL Editor**.
4. [Buat PIN admin](README.md#2-buat-pin-admin).
5. Jalankan [`supabase/seed.sql`](supabase/seed.sql) untuk mengisi data dummy.
6. Isi `env.json` dengan URL dan publishable key proyek baru.

Fungsi `submit_reading` untuk perangkat ada di
[`firmware/README.md`](firmware/README.md), bukan di `setup.sql`. Fungsi ini hanya perlu bila ingin
mencoba mengirim data seperti perangkat sungguhan.

### Mengubah database
- Tulis perubahan di `setup.sql` dengan pola yang aman dijalankan ulang: `create ... if not exists`,
  `create or replace function`, `drop policy if exists` lalu `create policy`.
- Akses aplikasi tetap **hanya baca**. Penulisan selalu lewat fungsi `security definer` yang memeriksa
  token atau PIN.
- **Jalankan SQL di produksi sebelum merilis aplikasi.**
- **Jangan merusak aplikasi versi lama.** HP tidak ter-update serempak, jadi kolom dan fungsi lama
  harus tetap ada sampai semua HP sudah pindah.

## 3. Mengembangkan

### Alur data

```
Perangkat ──submit_reading──▶ Supabase ──query + Realtime──▶ TankRepository, TankSource
                                                                      │
                                     monitor_provider (riwayat, Realtime, polling)
                                                                      │
                              ┌───────────────────────────────────────┴───┐
                         Dashboard                                 Notifikasi
```

Database hanya menyimpan nilai mentah sensor. Persen, volume, dan status selalu dihitung di aplikasi,
sehingga mengubah ukuran tangki tidak mengubah data. Rumusnya ada di
[README](README.md#cara-angka-di-dashboard-dihitung), dan peta foldernya di
[Struktur kode](README.md#struktur-kode).

### Di mana menaruh perubahan

| Mengubah | Tempatnya | Catatan |
|---|---|---|
| Konversi nilai sensor | `lib/services/reading_conversion.dart` | Logika murni, wajib ada test |
| Aturan penuh/kosong, pelampung | `lib/services/tank_rules.dart` | Logika murni, wajib ada test |
| Kapan notifikasi muncul | `lib/services/tank_evaluator.dart` | Dipakai juga oleh pemeriksaan latar belakang |
| Query Supabase | `lib/services/tank_repository.dart` | Satu request PostgREST dibatasi ±1000 baris |
| State | `lib/providers/` | Riverpod |
| Tampilan | `lib/screens/`, `lib/widgets/` | Warna lewat `AppColors`, lalu cek tema terang dan gelap |
| Cek pembaruan | `lib/services/update_service.dart`, `lib/widgets/update_dialog.dart` | |

`lib/background/background_monitor.dart` berjalan terpisah dari aplikasi dan tidak punya akses ke
provider. Karena itu, logika yang dipakai bersama harus berada di `lib/services/`.

### Yang mudah terlewat
- **Ikon hanya Cupertino.** Font Material Icons tidak dibawa (`uses-material-design: false`), jadi
  `Icons.*` tidak akan tampil.
- **Font hanya berisi huruf Latin, angka, dan beberapa simbol** (lihat komentar di `pubspec.yaml`).
  Karakter lain, seperti emoji, tampil dengan font cadangan.
- **Coba APK rilis di HP sebelum membuat tag.** Pernah ada bug yang hanya muncul di build rilis,
  yaitu pengaturan gagal disimpan karena `shared_preferences_android` lama bermasalah dengan R8.
  Cara build ada di [README](README.md#build-rilis-ukuran-kecil), dan lognya bisa dibaca dengan
  `adb logcat`.
- **Modal pembaruan tidak muncul saat debug.** Cek pembaruan hanya berjalan di build rilis Android.

### Memasang di HP yang sudah berisi aplikasi
Android menolak pemasangan yang tanda tangannya beda atau `versionCode`-nya lebih kecil:

| Dipasang di atas APK dari GitHub | Hasil |
|---|---|
| `flutter run` (debug) | Tanda tangan berbeda, jadi Flutter **otomatis meng-uninstall** aplikasi lama lalu memasang yang baru |
| APK rilis dari laptop, dengan `adb install` | Ditolak, `versionCode` lebih kecil |

Pakai emulator atau HP khusus pengembangan. Di HP lain, uninstall berarti data di HP itu (interval,
riwayat notifikasi) hilang, tetapi pengaturan tangki aman di Supabase. HP yang sudah terpasang build
debug juga tidak bisa menerima update dari GitHub sampai aplikasinya di-uninstall.

### Sebelum push

```bash
dart format lib test
flutter analyze
flutter test
```

Rilis berhenti bila `flutter test` gagal. `flutter analyze` dan `dart format` tidak dijalankan oleh
rilis, jadi jalankan sendiri.

## 4. Update versi

### Cara membaca nomor versi
Format tag: `vMAJOR.MINOR.PATCH`, mis. `v2.0.4`.

| Naikkan | Ketika | Contoh |
|---|---|---|
| **PATCH** | Perbaikan bug, tanpa fitur baru | `v2.0.4` → `v2.0.5` |
| **MINOR** | Fitur baru, cara pakai lama tetap sama | `v2.0.5` → `v2.1.0` |
| **MAJOR** | Perubahan besar, atau pengguna perlu melakukan sesuatu secara manual | `v2.1.0` → `v3.0.0` |

### Langkah merilis

```bash
# 1. Pastikan kode terbaru sudah ada di main dan test lulus
git checkout main
git pull
flutter test

# 2. Lihat nomor terakhir, lalu pilih nomor yang lebih tinggi
gh release list --limit 3

# 3. Buat tag. Pesannya menjadi catatan rilis di modal aplikasi
git tag -a v2.0.5 -m "Grafik kini lebih cepat dimuat"

# 4. Kirim tag. Langkah ini yang memulai rilis
git push origin v2.0.5

# 5. Pantau sampai selesai (±7 menit)
gh run watch
```

Workflow akan menjalankan test, membangun tiga APK, lalu membuat release. Setelah itu buka aplikasi di
HP: modal **Pembaruan tersedia** harus muncul dengan catatan yang Anda tulis, dan setelah terpasang,
**Pengaturan → Versi aplikasi** harus menampilkan nomor baru.

Yang perlu diingat:
- **Rilis langsung sampai ke semua HP**, saat aplikasi dibuka berikutnya. Tidak ada tahap uji coba.
- **Tidak ada rollback.** Bila ada rilis yang bermasalah, rilis perbaikannya dengan nomor lebih tinggi.
- **Harus memakai `git tag -a ... -m`.** Tag tanpa pesan membuat modal menampilkan pesan commit.
- **Catatan rilis dibaca pengguna**, jadi tulis dampaknya bagi mereka, bukan istilah teknis. Modal
  menampilkan teks apa adanya, jadi hindari Markdown.
- **Nomor tag harus tiga angka.** Tag seperti `v2.0.5-beta` tidak memulai rilis.

Untuk memperbaiki catatan rilis yang sudah terbit:

```bash
gh release edit v2.0.5 --notes "Catatan yang benar"
```

### Dari mana angka versinya

| Angka | Sumber | Dipakai untuk |
|---|---|---|
| Nama versi (`2.0.5`) | Tag | Ditampilkan di aplikasi, dan dibandingkan saat cek pembaruan |
| Build number | Nomor run Actions + 100 | Selalu naik, tidak perlu diatur |
| `versionCode` Android | (kode arsitektur × 1000) + build number | Android menolak angka yang lebih kecil dari yang terpasang |

Kode arsitektur: `armeabi-v7a` = 1, `arm64-v8a` = 2, `x86_64` = 4. Contoh, run ke-30 di HP arm64:
`2 × 1000 + (30 + 100)` = `2130`.

**Untuk rilis, `version` di `pubspec.yaml` tidak perlu diubah.** Nilai itu hanya berlaku untuk build di
laptop. APK laptop yang nomornya lebih rendah dari release terbaru akan menampilkan modal pembaruan,
dan itu wajar.

**Jangan mengunggah APK dari laptop ke release.** `versionCode`-nya lebih kecil dari hasil Actions,
sehingga Android menolaknya sebagai versi lebih lama. Aplikasi juga memilih APK berdasarkan namanya,
jadi nama file di release tidak boleh diganti:

| Nama file | Untuk |
|---|---|
| `app-arm64-v8a-release.apk` | Hampir semua HP Android |
| `app-armeabi-v7a-release.apk` | HP Android lama (32-bit) |
| `app-x86_64-release.apk` | Emulator |

### Secret repo
Workflow membutuhkan tiga secret. Semuanya sudah terisi di repo ini, jadi bagian ini hanya perlu saat
ada yang diganti. Jalankan di Git Bash dari folder proyek:

```bash
base64 -w0 android/upload-keystore.jks | gh secret set KEYSTORE_BASE64
gh secret set KEY_PROPERTIES < android/key.properties
gh secret set ENV_JSON < env.json
```

Isi secret tidak bisa dibaca lagi dari GitHub, jadi **backup keystore dan `key.properties`** di tempat aman
di luar repo. Bila keduanya hilang, HP yang sudah terpasang tidak bisa di-update dan harus uninstall.

Saat menaikkan versi Flutter, ubah juga `flutter-version` di
[`release.yml`](.github/workflows/release.yml) dan coba dulu di laptop.

Simbol untuk membaca stack trace tersimpan 90 hari di artifact tiap run Actions. Release bersifat publik:
siapa pun bisa mengunduh APK dan **membaca** data sensor dengan kunci di dalamnya, tetapi tidak bisa
mengubah apa pun tanpa token perangkat atau PIN admin.

### Bila ada masalah

| Gejala | Penyebab | Solusi |
|---|---|---|
| Run gagal di tahap test atau build | Test gagal atau secret salah, sehingga release tidak dibuat | Perbaiki, push, lalu pakai **nomor tag berikutnya** |
| Tag ditolak saat `git push` | Nomor tag sudah pernah dipakai | Pakai nomor tag yang lebih tinggi |
| Modal muncul terus setelah memasang | APK di release punya nomor versi lebih rendah dari tag-nya | Rilis lewat tag, jangan unggah APK manual |
| "Sudah ada versi lebih baru" saat memasang | `versionCode` APK lebih kecil dari yang terpasang | Rilis lewat tag, jangan unggah APK manual |
| Catatan rilis berisi pesan commit | Tag dibuat tanpa `-a -m` | Perbaiki dengan `gh release edit`. Tag berikutnya pakai `-a -m` |
| Gagal pasang atau konflik tanda tangan | APK ditandatangani key lain (debug atau keystore lain) | Uninstall sekali, lalu pasang lagi |
| Modal tidak muncul | Bukan build rilis, belum ada koneksi, atau aplikasi baru cek ulang setelah 12 jam | Tutup penuh lalu buka lagi aplikasinya |

HP yang masih memakai APK sebelum versi 1.1.0 (ditandatangani debug key) harus **uninstall sekali** lalu
memasang APK baru secara manual. Setelah itu update berjalan otomatis.

### Bila repo pindah atau di-fork
1. Ganti URL di `fetchNewerRelease` ([`lib/services/update_service.dart`](lib/services/update_service.dart)).
2. Isi ketiga secret di repo baru.
3. **Pakai keystore yang sama** bila HP lama masih harus bisa update. Keystore baru hanya untuk aplikasi
   yang benar-benar baru, dan HP lama harus uninstall dulu:

   ```bash
   keytool -genkey -v -keystore android/upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
