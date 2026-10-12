# HabitController — Phase 3–4

`habit_controller.dart` memakai `ChangeNotifier` dan disediakan oleh Provider.
Controller menyimpan habit, log, tanggal hari ini, loading/error, dan status sibuk.

View mengirim aksi lewat `context.read<HabitController>()`. Sesudah penulisan
berhasil, controller mengubah state dan memanggil `notifyListeners()`.
Dashboard/kalender/statistik yang memakai `context.watch<HabitController>()` ikut diperbarui.

Service menangani Hive; `HabitStreak` menangani aturan jadwal/streak murni Dart.
Timer dan lifecycle observer menyegarkan tanggal serta dilepas di `dispose()`.
State input form dan bulan kalender tetap dikelola lokal di widget masing-masing.

Phase 4 menambahkan `ReminderService` lewat dependency injection di `app.dart`.
Simpan/edit/hapus dan load/resume menyinkronkan pengingat lewat antrean terpisah.
Penulisan Hive harus berhasil terlebih dahulu; kegagalan notifikasi hanya mengisi
`reminderWarning`, tanpa mengubah simpan yang sudah berhasil menjadi gagal.
`retryReminders()` meminta izin dari aksi pengguna. Startup/resume tidak meminta
izin. Centang harian tidak mengubah jadwal pengingat yang berulang.

`reminderBusy` mengunci retry ganda. Operasi sinkronisasi berjalan berurutan dan
membaca daftar habit terbaru ketika mulai. `NoopReminderService` dipakai oleh
tes controller/widget lama; produksi menerima `LocalReminderService` dari app.

Panduan flow dan contoh streak ada di [README utama](../../README.md).
