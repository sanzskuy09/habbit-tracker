# Product Requirement Document (PRD) — Habit Tracker App

## 1. Ringkasan Produk
* **Nama Produk (Sementara):** Routine Craft / Habitify Lite
* **Tujuan:** Aplikasi *mobile* pelacak kebiasaan harian (*habit tracker*) untuk membantu pengguna membangun rutinitas positif dengan visualisasi progres dan sistem pengingat.
* **Platform Target:** Android & iOS (Dikembangkan dengan **Flutter & Dart**).
* **Target Pengguna:** Individu yang ingin mengelola produktivitas, membangun kebiasaan baru, serta memantau konsistensi secara *offline-first*.

---

## 2. Ruang Lingkup & Fitur Utama

| Fitur | Deskripsi Fitur | Implementasi Teknis (Flutter / Dart) |
| :--- | :--- | :--- |
| **Pengelolaan Kebiasaan (CRUD)** | Pengguna dapat **membuat**, **melihat**, **mengedit**, dan **menghapus** target kebiasaan (misal: "Baca Buku 15 Menit", "Minum Air 2L"). | • `StatefulWidget` / `Provider` / `Bloc` / `Riverpod`.<br>• Custom Form dengan `TextFormField` & `DropdownButton`. |
| **Penyimpanan Lokal (*Offline First*)** | Data kebiasaan dan riwayat penyelesaian tersimpan aman di perangkat tanpa butuh *internet*. | Integrasi library **`Hive`**, **`Isar`**, atau **`sqflite`** untuk penyimpanan data lokal yang cepat. |
| **Pelacakan Streak & Kalender** | Menampilkan jumlah hari beruntun (*streak*) serta tampilan matriks kalender bulanan. | • Logika perhitungan *streak* di Dart.<br>• UI rendering menggunakan `table_calendar` atau custom grid widget. |
| **Notifikasi Pengingat (*Local Push Notifications*)** | Notifikasi terjadwal harian sesuai jam yang diatur pengguna untuk tiap kebiasaan. | Integrasi library **`flutter_local_notifications`** & `timezone` package. |
| **Dashboard & Statistik Sederhana** | Ringkasan persentase penyelesaian mingguan/bulanan disertai grafik statistik. | Custom widget atau menggunakan library grafik seperti **`fl_chart`**. |

---

## 3. Arsitektur Komponen & Tech Stack Flutter

### A. Widget Utama Flutter
* **`ListView.builder` / `GridView.builder`**: Menampilkan daftar kebiasaan secara performan.
* **`Dismissible`**: Fitur *swipe-to-delete* atau *swipe-to-complete* pada item kebiasaan.
* **`AnimatedContainer` / `Implicit Animations`**: Memberikan animasi halus saat pengguna menyelesaikan *habit*.
* **`ShowDatePicker` / `ShowTimePicker`**: Widget bawaan Flutter untuk memilih tanggal dan waktu pengingat.

### B. Dependencies / Packages yang Direkomendasikan
Add paket berikut di file `pubspec.yaml`:
* **State Management:** `flutter_riverpod` atau `provider` (Sangat cocok untuk level pembelajaran menengah).
* **Local Database:** `hive` + `hive_flutter` (Database Key-Value super cepat) ATAU `sqflite`.
* **Local Notifications:** `flutter_local_notifications`.
* **Charts:** `fl_chart` (Untuk visualisasi grafik progres).
* **Icons & Styling:** `google_fonts`, `flutter_iconpicker`.

---

## 4. Alur Pengguna (*User Flow*)

1. **Inisialisasi Aplikasi:**
   * Aplikasi membuka *Dashboard*, memuat data kebiasaan dari database lokal (`Hive`/`SQLite`).
2. **Tambah Kebiasaan Baru:**
   * Pengguna menekan tombol Floating Action Button (`FAB`).
   * Memasukkan nama kebiasaan, ikon/warna, frekuensi, dan waktu notifikasi.
   * Menekan tombol "Simpan" $\rightarrow$ Data masuk database & *local notification* didaftarkan.
3. **Pencatatan Harian:**
   * Pengguna menandai centang (*check*) pada kebiasaan hari ini.
   * Efek animasi muncul, hitungan *streak* bertambah +1.
4. **Melihat Progress:**
   * Pengguna membuka tab *Analytics* untuk melihat ringkasan grafik mingguan/bulanan.

---

## 5. Struktur Data (*Data Model*)

Data kebiasaan (*Habit*) dan riwayat penyelesaian (*HabitLog*) direpresentasikan dalam struktur Dart Object / Class berikut:

```dart
// Model Kebiasaan
class Habit {
  final String id;
  final String title;
  final String description;
  final int colorHex;
  final String iconKey;
  final String? reminderTime; // Format: "HH:mm"
  final DateTime createdAt;

  Habit({
    required this.id,
    required this.title,
    this.description = '',
    required this.colorHex,
    required this.iconKey,
    this.reminderTime,
    required this.createdAt,
  });
}

// Model Riwayat Penyelesaian Harian
class HabitLog {
  final String id;
  final String habitId;
  final DateTime completedAt; // Menyimpan tanggal penyelesaian (YYYY-MM-DD)

  HabitLog({
    required this.id,
    required this.habitId,
    required this.completedAt,
  });
}
```

---

## 6. Rencana Tahapan Pembelajaran & Eksekusi (*Milestones*)

* [x] **Phase 1: Setup & UI Basic**
  * [x] Buat proyek Flutter langsung di folder ini (`flutter create --project-name habit_tracker --platforms=android,ios --no-pub .`).
  * [x] Setup struktur folder (`lib/models`, `lib/views`, `lib/controllers`, `lib/services`).
  * [x] Buat tampilan UI statis untuk Dashboard dan Form Tambah Habit.
  * Panduan flow dan pembelajaran tersedia di [README.md](README.md). UI phase 1 sudah dihubungkan ke database pada phase 2.
* [x] **Phase 2: Local Database Integration**
  * [x] Pasang package `hive` dan `hive_flutter`.
  * [x] Buat CRUD Service untuk menyimpan, membaca, mengedit, dan menghapus kebiasaan.
  * [x] Hubungkan Dashboard serta form tambah/edit ke penyimpanan lokal; hapus melalui menu kartu dengan konfirmasi.
  * Persistensi habit diuji dengan menutup dan membuka ulang database. Riwayat centang serta streak masih mengikuti phase 3.
* [ ] **Phase 3: State Management & Logic Streak**
  * Sambungkan UI dengan State Management (`Riverpod` / `Provider`).
  * Buat fungsi perhitungan *streak* (hari berurutan) dan logika tanggal harian.
* [ ] **Phase 4: Local Notifications & Polish UI**
  * Setup `flutter_local_notifications` untuk memunculkan pengingat di jam yang ditentukan.
  * Tambahkan animasi (*Lottie* / *Implicit Animations*) saat habit dicentang.
  * Integrasikan `fl_chart` untuk halaman statistik.

---

## 7. Kriteria Keberhasilan (*Definition of Done*)
* [ ] Aplikasi dapat dijalankan di Emulator/HP tanpa *error* saat *compile*.
* [ ] Data *habit* dan riwayat centang tidak hilang saat aplikasi ditutup penuh (*killed*) lalu dibuka kembali.
* [ ] Pengingat (*push notification*) muncul sesuai jam yang dijadwalkan.
* [ ] Tampilan UI menarik, bersih, dan responsif di berbagai ukuran layar HP.
```

eof
