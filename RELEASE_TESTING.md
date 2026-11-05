# Pembaruan pengujian — 1.0.1 (19)

Bundle baru: `build/app/outputs/bundle/release/app-release.aab`.
Unggah build dengan versionCode **19** ke jalur pengujian yang dipakai tester,
lalu perbarui aplikasi dari akun Play Store yang terdaftar sebagai tester.
Bundle ini belum diunggah ke Play Console.

Kode login sudah menyertakan tombol mata untuk menampilkan/menyembunyikan
password. Registrasi menyertakan Password dan Ulangi Password, masing-masing
dengan tombol mata. Password berbeda ditolak sebelum permintaan ke Firebase.

Verifikasi: 28 tes Flutter lulus, termasuk 2 tes widget baru untuk visibilitas
password registrasi dan validasi kesamaan (termasuk setelah password diubah).
Analisis statis: 0 error, 0 warning, 44 info lint yang sudah ada.

Uji perangkat setelah update: logout untuk membuka login, sentuh ikon mata,
buka pendaftaran dan gulir sampai Ulangi Password, lalu coba password berbeda.
Pastikan versi terpasang adalah build 19 melalui informasi aplikasi/Play Console.
Jangan hapus data aplikasi untuk memperbarui versi.

---

# Rilis pengujian Android — 1.0.1 (17)

Artefak Google Play: `build/app/outputs/bundle/release/app-release.aab`.
Application ID tetap `com.dukeduk.dompet_harian_dukeduk`, target SDK 36.
Gunakan Internal testing atau Closed testing terlebih dahulu. Build belum
diunggah ke Play Console oleh perubahan ini.

## Perubahan perilaku

- Navigasi bawah memperhitungkan area aman tombol sistem Android.
- Izin notifikasi diminta setelah tampilan login terbuka. Android sebelum
  versi 13 tidak memerlukan dialog izin notifikasi tersebut.
- Profil menyediakan **Uji notifikasi pengingat** untuk meminta izin dan
  menampilkan contoh notifikasi langsung.
- Reminder merupakan **notifikasi lokal**, bukan pesan FCM dari server.
- Satu alarm native Android memeriksa seluruh reminder setiap hari sekitar
  pukul 08.00 waktu perangkat. Reminder dimulai H-3, menampilkan cicilan
  tertua yang belum dibayar, berlanjut setiap hari sampai dibayar/dimatikan,
  dan berpindah ke cicilan berikutnya setelah pembayaran.
- Pengulangan tidak dibatasi 11 hari dan tidak bergantung pada proses Flutter.
  Jadwal dipasang kembali setelah reboot, pembaruan aplikasi, serta perubahan
  waktu/zona waktu. Alarm menggunakan `setAndAllowWhileIdle`, sehingga tidak
  memerlukan izin exact alarm. Android/OEM dapat menunda waktu pengiriman.
- Logout menghapus alarm dan notifikasi akun lama sebelum mengakhiri sesi.
- Edit hutang/piutang mempertahankan nominal, tanggal, dan riwayat cicilan
  yang telah dibayar. Tenor yang menghapus cicilan lunas ditolak.
- Tanggal akhir bulan dibatasi ke tanggal valid bulan tujuan.
- Aksi keuangan diserialkan dan memiliki journal rollback lokal untuk
  mencegah status pembayaran/transaksi berbeda setelah kegagalan penulisan.
- ID baru tidak lagi memakai penghitung berdasarkan isi daftar, sehingga ID
  tidak digunakan ulang setelah penghapusan dan risiko benturan antarperangkat
  berkurang.
- Sinkronisasi menggunakan antrean perubahan per akun yang tersimpan lokal.
  Perubahan yang belum dikonfirmasi server tetap di antrean untuk dicoba ulang
  saat aplikasi dibuka kembali atau saat penyimpanan berikutnya.
- Pemulihan cloud menggabungkan data, mempertahankan perubahan lokal yang
  tertunda, dan mencakup hutang/piutang beserta status pembayaran cicilannya.
- Penghapusan dicatat dengan tombstone supaya data tidak muncul lagi setelah
  sinkronisasi. ID transaksi lama dibaca dari ID dokumen jika field-nya hilang.
- Sebelum migrasi sinkronisasi pertama, snapshot data keuangan lokal disimpan
  sebagai `pre_sync_backup_v1_<uid>` di penyimpanan aplikasi. Snapshot ini ikut
  hilang bila pengguna menghapus data aplikasi/uninstall; ini bukan backup
  eksternal.
- Switch cloud/offline disimpan per akun dan digunakan oleh penyimpanan
  keuangan serta profil. Mematikan switch mempertahankan perubahan lokal.
- Foto/logo baru disimpan sebagai gambar kecil yang portabel, bukan path file
  dari ponsel asal. Gambar dibatasi agar dokumen profil tidak terlalu besar.
- Remember Me digunakan oleh login Firebase. Biometrik yang aktif diperiksa
  sebelum pemulihan sesi pada pembukaan aplikasi.
- Registrasi baru memakai email aktif untuk mendukung pemulihan password.
  Username akun lama tetap dapat dipakai untuk login. Akun lama dengan alamat
  sintetis `@dukeduk.com` perlu dibantu administrator untuk pemulihan akun.
- `mobile_scanner` diperbarui ke 7.4.3, termasuk library native beralignment
  16 KB dan pengelolaan lifecycle kamera.

## Pengujian manual yang diperlukan

Lakukan pada Infinix yang dilaporkan bermasalah dan F11 Pro. Catat model,
versi Android, mode navigasi (gesture/3 tombol), dan apakah instalasi baru
atau pembaruan dari versi 16.

1. **Pembaruan tanpa menghapus data:** pasang rilis melalui jalur pengujian
   Play sebagai update versi sebelumnya. Periksa transaksi, budget, master,
   hutang/piutang dan cicilan lunas masih ada.
2. **Navigasi:** uji semua tab, gesture dan navigasi 3 tombol, keyboard terbuka,
   serta ukuran font sistem besar. Menu bawah harus tetap dapat disentuh.
3. **Izin:** di instalasi baru Android 13+, izinkan notifikasi. Ulangi dengan
   menolak izin; aplikasi tetap bisa dibuka dan menyimpan data.
4. **Tes langsung:** buka Profil → Uji notifikasi pengingat. Jika izin ditolak
   permanen, aktifkan lewat pengaturan aplikasi Android kemudian ulangi.
5. **Reminder harian:** buat hutang dan piutang yang memasuki H-3 dengan
   reminder aktif. Tunggu jadwal sekitar 08.00; uji aplikasi di background,
   layar terkunci, reboot, serta penggantian zona waktu. Reminder tertunda
   akibat penghemat baterai perlu dibedakan dari izin yang ditolak.
6. **Hutang dan piutang bersamaan:** buat keduanya, lalu hapus/matikan salah
   satunya. Reminder pihak lain tidak boleh ikut hilang.
7. **Pembayaran:** bayar cicilan pertama, edit nama/tenor, lalu buka kalender.
   Cicilan yang lunas tetap lunas dan transaksi pembayaran tidak tercatat dua
   kali. Bayar seluruh cicilan lalu periksa reminder berhenti.
8. **Pergantian akun:** logout A, login B. Data dan reminder A tidak boleh
   tampil pada B. Login A kembali harus memuat data A.
9. **Offline:** matikan switch cloud, ubah data, tutup/buka aplikasi. Data lokal
   harus tetap ada. Aktifkan cloud dan periksa perubahan terkirim.
10. **Pemulihan:** setelah sinkronisasi berhasil, login akun yang sama pada
    perangkat pengujian kedua. Periksa seluruh modul, status cicilan, dan foto.
    Hapus satu transaksi, sinkronkan kembali, dan pastikan tidak muncul lagi.
11. **Scanner:** izin kamera diterima/ditolak, scan barcode, keluar/masuk
    halaman scanner, pindah aplikasi dan kembali, torch serta ganti kamera.
12. **Sesi:** uji Remember Me aktif/tidak aktif dan biometrik aktif, batal,
    gagal, serta login manual sebagai pemulihan.

## Hasil verifikasi

26 tes Flutter dan 4 tes unit Android lulus. Analisis statis: 0 error,
0 warning, 44 info lint. Build AAB release berhasil, ditandatangani dengan
konfigurasi release proyek, dan 14 library native 64-bit lolos pemeriksaan
alignment minimal 16 KB. Hasil ini belum menggantikan pengujian perangkat.

## Validasi otomatis

- `flutter test`: tes reminder, kalender cicilan, ID, outbox, rollback lokal,
  penggabungan cloud, retry offline, tombstone, dan isolasi akun.
- `cd android && ./gradlew :app:testDebugUnitTest`: tes waktu alarm native.
- `flutter analyze --no-fatal-infos`: error/warning harus nol. Masih ada info
  lint pada kode UI lama (API deprecated dan guard BuildContext); bukan bukti
  bahwa semua kombinasi interaksi perangkat sudah diuji.
- `flutter build appbundle --release`: build release dengan signing proyek.
- `jarsigner -verify build/app/outputs/bundle/release/app-release.aab`.
- Hasil checksum dan pemeriksaan alignment ELF library native 64-bit disimpan
  di `build/release-verification.json`.

## Batas verifikasi

Tes sinkronisasi memakai transport cloud tiruan dan tidak mengubah data Firebase
produksi. Firestore Security Rules, konfigurasi akun Firebase, dan kondisi data
historis sebenarnya masih harus diverifikasi lewat jalur pengujian. Jangan
menghapus data aplikasi sebagai langkah diagnosis sebelum backup terkonfirmasi.

Rilis ini ditujukan untuk Android. Konfigurasi Firebase iOS yang sudah tersedia
di proyek telah dihubungkan dan usage descriptions ditambahkan, tetapi build
iOS belum diuji. Firebase web/desktop memerlukan registrasi dan konfigurasi app
masing-masing; platform tersebut belum dinyatakan siap rilis.
