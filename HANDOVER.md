# STATUS TERBARU — prioritas dari pengguna

- Terbaru: swipe/pinch kamera kanan, default dekat 4 m, gerak relatif kamera.
- Pulau prosedural 1.000 × 1.000 m (bentang terrain termasuk pesisir), perbukitan,
  dataran tebing timur, batu collision, jalan tanah berliku dan laut. Warna terang.
- Cakupan gabungan kamera + dunia diminta langsung pengguna. Belum ada berenang,
  bangunan atau vegetasi detail. Pemain dibatasi di garis air dangkal.
- Tes otomatis mencakup ray tanah, elevasi jalan, swipe/pinch, isolasi kiri-kanan,
  dan SpringArm menghadapi tembok. Performa/tampilan tetap harus diuji di HP.


- Permintaan terbaru: mannequin asli + idle/jalan/lari didahulukan (5A), analog
  transparan mengambang hanya saat disentuh di kiri layar. Kamera tetap dulu.
- Aset UAL1 Standard diambil utuh dari archive (asal + hash di docs/CREDITS.md).
- Perubahan gameplay ini dikirim melalui PCK kompatibel launcher 1; jangan
  meminta install APK lagi jika launcher 3A sudah terpasang.
- Menunggu tes HP: update otomatis benar masuk, arah hadap, kaki tidak meluncur,
  idle/walk/run, analog muncul/hilang. Jangan lanjut fitur lain sebelum tes.


- Jangan push/merge ke main. Kerja di `arena/01a0eaf5-godot`.
- Milestone 2A joystick sudah dibuat; tes otomatis lolos, hasil tes HP belum dicatat.
- Pengguna mendahulukan launcher/update dalam game sebelum swipe kamera 2B.
- Implementasi 3A: launcher bawaan APK, manifest release, PCK gameplay tervalidasi,
  loading bar tipis bawah, retry/offline, marker pemulihan boot. Lihat README.
- Satu update APK diperlukan untuk memasang launcher. Update berikutnya yang
  kompatibel bisa lewat PCK; bukan janji semua perubahan bebas update APK.
- Konfirmasi tes HP dan uji dua versi konten sebelum lanjut milestone lain.

---

# SERAH TERIMA — untuk sesi AI berikutnya

Ditulis: 2026-09-29. Kamu (agent baru) sedang bekerja di repo **KyokoApp/Godot**.
Project ini dibuat dari nol oleh sesi sebelumnya yang terkunci di repo
`KyokoApp/Unity` (token-nya hanya bisa tulis ke sana). File-file ini datang dari
branch `asekai-fresh` repo `KyokoApp/Unity` — diambil lalu di-push ke `main` repo ini.

## TUGAS PERTAMA (paling penting)

1. Ambil isi branch `asekai-fresh` dari `https://github.com/KyokoApp/Unity`
   (repo publik, bisa dibaca siapa saja):

   ```bash
   git fetch https://github.com/KyokoApp/Unity.git refs/heads/asekai-fresh
   git checkout -b main FETCH_HEAD
   git push -u origin main
   ```

   Kalau kamu membaca file ini, kemungkinan langkah ini sudah dilakukan.

2. Pastikan workflow **apk** di Actions jalan hijau. Workflow-nya otomatis
   build APK + terbitkan GitHub Release berisi `asekai.apk` + SHA-256.

3. Beri tahu user: link release, dan bahwa ini **Milestone 1** — layar harus
   memunculkan langit + tanah + kapsul ungu + teks "MILESTONE 1 — app hidup".

## KONDISI PROJECT

- **Milestone 1 (selesai):** app terbuka, dunia sederhana (langit prosedural,
  tanah hijau, cahaya matahari), karakter kapsul, kamera berputar, HUD FPS.
  Semua dibangun dari kode di `project/src/game/main.gd` — tanpa .tscn rumit,
  tanpa shader kustom. Sengaja sepele: tujuannya membuktikan app bisa dibuka
  di HP pengguna.
- **Belum ada:** kontrol gerak, delta-update, dunia, karakter, build mode.

## PETA MILESTONE (satu per satu, masing-masing diuji di HP)

| # | Isi | Status |
|---|---|---|
| 1 | App terbuka, dunia + karakter, HUD | selesai |
| 2 | Bergerak: joystick + swipe kamera | berikutnya |
| 3 | Delta update: launcher mengunduh content pack | belum |
| 4 | Dunia: tanah, rumput, jalan berliku | belum |
| 5 | Karakter: model + animasi | belum |
| 6 | Build mode grid 2 m (menumpuk ke atas) | belum |

## ATURAN WAJIB (dari user + pelajaran project lama)

1. **Standar kode:** GDScript 4.5.2 typed, max line length 100, `gdparse` +
   `gdlint` bersih, `python3 tools/check_scripts.py .` harus BERSIH.
2. **Jangan pernah lewati gerbang compile.** `tools/compile_check.gd` load()
   semua `.gd`; kalau CI menolak, berarti memang ada yang salah.
3. **Satu milestone = satu perubahan**, diuji di HP sebelum lanjut.
4. **Keystore `keystore/debug.keystore` JANGAN diganti/di-regenerate.**
   Password `android`, alias `androiddebugkey`. Kunci ini sama dengan app
   yang sudah terpasang di HP user — kalau berubah, Android menolak update
   ("bentrok") dan user harus uninstall dulu.
5. **Jawab dalam Bahasa Indonesia, singkat dan langsung.** User casual.
6. **Jangan percaya klaim bug dari AI lain tanpa verifikasi** — user suka
   menguji diagnosis lewat screenshot.
7. Preferensi visual (untuk milestone dunia nanti): **pastel & lebih terang**,
   bukan gelap/mossy. Jalan **bergelombang/winding**, bukan grid lurus.
   Rumput hanya di tanah hijau, tidak di aspal/pesisir. Grid bangunan
   **2 m × 1 m native kit** (MegaKit modular).
8. File besar → **GitHub web uploader**, jangan Drive/release-asset.

## ASET (belum masuk repo ini)

- **Medieval Village MegaKit** (Quaternius, CC0) — 176 model glTF, ada di
  `KyokoApp/Unity` branch `archive` folder `Mediavel/`. Belum diperlukan
  sampai milestone 4-6.

## RIWAYAT SINGKAT (biar tidak mengulang kesalahan)

Project lama di `KyokoApp/Unity` (46+ ronde pivot: pulau → tank → mage →
stickman → mannequin → Kanna → open world) gagal karena:
- **Compile error tak tertangkap** — satu baris di `home_menu.gd`
  (`var lbl := [ "VERSI", ...][k2]` → Variant → `:=` ditolak) mematikan
  seluruh launcher; user hanya melihat layar biru polos. Probe CI lama
  tidak pernah mengompilasi skrip di luar folder pack.
- **Signing key berubah tiap build** → update "bentrok", mustahil tanpa
  uninstall.
- **Tidak ada yang pernah melihat game jalan** — tidak ada GPU di sandbox.

Makanya project baru ini: gerbang compile ketat, checker inferensi tipe,
keystore permanen, milestone kecil yang diuji di HP. Versi lama tersimpan
penuh di branch `archive` repo `KyokoApp/Unity` (1.552 file).

## Revisi visual terbaru

User melaporkan pulau terlihat putih/salju. Revisi menjadi rumput hijau solid,
jalan cokelat polos, sisi tebing abu-abu batu flat-shaded; puncak tetap hijau.
Material vertex color sekarang sRGB, ambient 0,65. HUD `hijau + tebing batu`.
Tidak mengubah bentuk pulau/kontrol. Tunggu screenshot/konfirmasi HP.

## Tahap rumput (permintaan terbaru)

Rumput rapat/angin diadaptasi dari shader CC0 Malido yang dikirim pengguna.
Shader + streaming ada di src/game/grass*; sumber/lisensi di docs/CREDITS.md.
Maksimal 25 tile / 10k rumpun, satu tile/frame, fade geometris 16–23 m,
mask jalan/pantai/tebing/batu. Tidak mengubah launcher atau kontrol. Tes render
CI memakai Mobile Vulkan/Mesa (bukan dummy headless). Tunggu hasil FPS/visual HP
sebelum menambah aset/shader dunia lain. HUD `PULAU 1K — rumput angin`.
