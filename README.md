# A-Sekai

Game 3D open-world untuk Android, dibangun dengan **Godot 4.5** (GDScript).

Project ini **dimulai ulang dari nol** pada 2026-09-29. Versi lama masih
tersimpan penuh di branch `archive` pada repo `KyokoApp/Unity` — tidak ada
yang hilang, termasuk 176 model Medieval Village (CC0) dan seluruh sistem
delta-update.

## Kenapa dimulai ulang

Project lama tumbuh jadi 46+ ronde pivot dan akumulasi masalah yang tidak
ketahuan sampai ke perangkat:

- **Compile error tak tertangkap.** Satu baris mematikan seluruh launcher;
  yang tersisa hanya warna latar boot — "layar biru polos tanpa loading
  screen". `gdparse` hanya cek sintaks, dan probe CI lama hanya memuat
  skrip di dalam satu folder sehingga skrip di luar folder itu **tidak
  pernah dikompilasi sama sekali**.
- **Kunci signing berubah tiap build**, sehingga Android menolak install di
  atas aplikasi lama ("bentrok") dan update mustahil tanpa uninstall.
- **Tidak pernah ada yang melihat game-nya berjalan** selama banyak ronde.

Yang dibawa ke sini: infra delta-update, aset, dan keystore permanen.
Yang dibuang: seluruh history pivot dan kode yang tidak pernah terbukti
jalan di HP.

## Prinsip

1. **Satu milestone = satu perubahan.** Tidak ada fitur yang digabung.
2. **Setiap milestone harus diuji di HP** sebelum milestone berikutnya.
3. **Tidak ada skrip yang gagal compile yang boleh terbit** — gerbang CI
   menolak build dengan satu skrip pun gagal.
4. **Tidak ada keputusan besar tanpa melihat hasilnya di layar.**

## Peta milestone

| # | Isi | Status |
|---|---|---|
| 1 | App terbuka, dunia + karakter, HUD "MILESTONE 1 OK" | selesai |
| 2 | Bergerak: joystick + swipe kamera | belum |
| 3 | Delta update: launcher mengunduh content pack | belum |
| 4 | Dunia: tanah, rumput, jalan berliku | belum |
| 5 | Karakter: model + animasi | belum |
| 6 | Build mode grid 2 m (menumpuk ke atas) | belum |

**Milestone 1 adalah yang paling penting justru karena paling sepele.**
Tujuannya satu: membuktikan aplikasi benar-benar bisa dibuka di HP.

## Struktur

```
├─ project/            # root proyek Godot
│  ├─ project.godot
│  └─ src/game/        # scene & skrip game
├─ tools/
│  ├─ check_scripts.py # cek lokal: tangkap bug inferensi tipe
│  └─ compile_check.gd # cek engine: load() semua .gd
├─ keystore/           # kunci signing debug (permanen, jangan dihapus)
└─ .github/workflows/  # build APK
```

## Develop

```bash
# cek lokal (cepat, tanpa Godot)
python3 tools/check_scripts.py .

# compile check (butuh Godot)
godot --headless --path project --import --editor --quit
godot --headless --path project --script ../tools/compile_check.gd
```

## Build APK

Push ke `main` → GitHub Actions otomatis build dan menerbitkan GitHub
Release dengan `asekai.apk` + SHA-256.

## Lisensi aset

Model dari *Medieval Village MegaKit* oleh Quaternius (CC0 1.0).
Detail atribusi di `docs/CREDITS.md`.

## Milestone 2A — joystick gerak (menunggu tes HP)

- Joystick analog kiri bawah, dead zone, satu jari pemilik input.
- Kapsul bergerak 5 m/detik, gravitasi dan collision; lepas joystick untuk berhenti.
- Kamera mengikuti dengan arah tetap. Swipe kamera belum masuk (tahap 2B).
- Input di-reset ketika aplikasi kehilangan fokus atau ukuran viewport berubah.
- Area gerak dibatasi ke tanah uji; HUD posisi membantu mengecek pergerakan.

Tes HP: gerak empat arah dan diagonal, lepas jari di luar lingkaran,
letakkan jari kedua, pindah aplikasi lalu kembali. Pemain tidak boleh bergerak
sendiri. Periksa kapsul menapak tanah, kamera mengikuti, dan FPS stabil.
Jangan lanjut 2B sebelum hasil tes HP disetujui. Jangan merge ke main dulu.

## Milestone 3A — launcher + update konten (sebelum swipe kamera)

Install APK launcher sekali di atas app lama (keystore dan package ID sama).
Saat aplikasi dibuka, launcher memeriksa `releases/latest/download/content.json`.
Konten baru diunduh sebagai PCK penuh (bukan binary delta), diverifikasi ukuran dan
SHA-256, lalu dipasang sebelum scene gameplay dimuat. Progress unduhan nyata
terlihat di bar tipis bawah. Bila jaringan gagal, pilih **Main offline** untuk
memakai konten tersimpan yang valid atau gameplay bawaan APK.

- Manifest mengunci schema 1, engine 4.5.2, minimum launcher 1, URL release repo ini.
- Download sementara tidak mengganti metadata aktif sebelum verifikasi selesai.
- Boot konten memakai marker; boot yang tidak dikonfirmasi mengembalikan ke
  gameplay bawaan pada pembukaan berikutnya. Ini bukan jaminan bebas bug runtime.
- PCK hanya scene gameplay dan dependensinya; launcher tidak ikut diperbarui.
- Workflow menerbitkan APK + checksum + `content.pck` + `content.json` setelah tes.
- Update kode gameplay/aset yang kompatibel cukup melalui konten. Perubahan
  launcher, engine, native plugin atau izin Android tetap membutuhkan APK.
- Untuk sekarang, buka ulang aplikasi untuk mengecek update; tidak mengganti kode
  gameplay di tengah permainan. File pack lama belum dibersihkan otomatis.
- SHA-256 melindungi integritas file, bukan tanda tangan publisher terpisah;
  kepercayaan publikasi tetap pada HTTPS dan akses tulis GitHub repo ini.

### Tes HP tahap 3A

1. Install APK, buka online: loading → cek update → unduh → game joystick.
2. Tutup penuh lalu buka ulang: hash sama tidak mengunduh pack lagi.
3. Mode pesawat: setelah pemeriksaan gagal pilih Main offline, game tetap terbuka.
4. Putus koneksi saat download: tidak masuk file parsial, retry/offline tersedia.
5. Bukti update lintas versi perlu build konten berikutnya: APK tetap, tampilan
   versi gameplay berubah setelah buka ulang. Jangan klaim lulus sebelum tes HP.

Semua tetap di branch sesi; **jangan merge ke main**. Tahap 2B ditunda sampai
launcher dan update konten ini lolos pengujian pengguna.

## Milestone 5A — mannequin + analog mengambang

Urutan disesuaikan permintaan pengguna: karakter lebih dulu, dunia/kamera menyusul.
Mannequin rigged UAL1 Standard dari project lama, dengan klip Idle, Walk, Jog_Fwd
hasil import Godot. Tarikan analog mengatur kecepatan 0–5 m/detik; langkah dan
transisi animasi mengikuti kecepatan aktual dengan blend 0,18 detik dan histeresis.
Analog muncul di posisi sentuhan pertama pada separuh kiri layar, lebih transparan,
lenyap setelah dilepas/kehilangan fokus. Separuh kanan tidak mengaktifkan analog.

Cukup tutup penuh lalu buka launcher 3A online untuk mengunduh konten baru.
HUD harus berubah menjadi **MILESTONE 5A — mannequin + animasi**. Tidak ada perubahan
launcher/engine/native, jadi pengguna launcher 3A tidak perlu update APK.

Tes HP: idle bergerak halus, tarik dekat untuk jalan, jauh untuk lari, lepas kembali
idle; periksa karakter menghadap arah gerak dan kaki tidak terbenam/meluncur parah.
Periksa analog tak terlihat saat idle, muncul di titik sentuh kiri, transparan,
hilang saat dilepas, dan jari kedua tidak merebut kontrol. CI mengecek klip impor,
perubahan pose tulang, transisi state, dan aturan sentuhan; tampilan/performa tetap
perlu tes di perangkat. Tetap jangan merge ke main.

## Pulau 1K + kamera dekat (permintaan berikutnya)

- Kamera default 4 m (sebelumnya offset sekitar 7,7 m), FOV 65 derajat.
- Geser separuh kanan untuk orbit; dua jari yang mulai di kanan untuk zoom 2,4–8 m.
  Joystick kiri tetap independen. Gerak mengikuti arah kamera. SpringArm dengan
  sphere cast memendekkan jarak saat terhalang tanah/batu/tebing.
- Terrain 1.000 × 1.000 meter: pulau berpantai tidak persegi, laut biru muda,
  perbukitan, dataran tebing berbatu di timur, batu-batu, jalan tanah berliku.
  Jalan menyatu dengan terrain dan dihaluskan elevasinya, bukan grid lurus.
- Terrain deterministik dibagi 16 chunk, grid 5 m, 80.000 segitiga dengan collision.
  Warna vertex tanpa shader khusus/tekstur; batu low-poly. Belum ada pohon/rumput
  individual, ombak atau berenang. Pemain berhenti di air dangkal.
- Perubahan dikirim melalui content pack; pengguna launcher 3A cukup buka ulang
  online. HUD baru **PULAU 1K — kamera dekat**.

Tes HP: swipe kanan sambil jalan dengan kiri, cubit kanan, lihat karakter dari
berbagai sudut, mendekat ke tebing untuk uji kamera, jalan menanjak/menurun,
jelajahi pantai, cek FPS dan durasi persiapan dunia. Belum diklaim performa stabil
pada HP sebelum pengguna menguji. Main tetap tidak di-merge.

### Revisi visual — hijau, tanah polos, tebing batu

Permintaan setelah tes HP: versi sebelumnya tampak seperti salju. Palet terrain
kini hijau solid, jalan cokelat tanah, pantai pasir hangat, sisi curam abu-abu batu.
Material vertex color ditandai sRGB sesuai warna hex; ambient dikurangi agar tidak
terlalu pucat. Sisi tebing memakai normal per bidang (flat shaded) dan batu low-poly
juga flat shaded. Puncak datar tetap hijau, tidak berubah putih karena ketinggian.
Tidak memakai gambar tekstur/noise salju. Geometri/collision pulau dan kontrol tetap.
HUD: **PULAU 1K — hijau + tebing batu**. Warna akhir perlu konfirmasi ulang di HP.

## Rumput tebal dengan angin (uji HP berikutnya)

Adaptasi shader CC0 Malido dari referensi pengguna (kredit di docs/CREDITS.md).
Rumpun terdiri dari tiga helai meruncing, gradasi hijau, angin Perlin lembut dan
reaksi menyingkir di sekitar kaki pemain. Tanpa texture alpha/transparency.

- Streaming sekitar pemain: 25 tile × 12 m, maksimal 400 rumpun per tile
  (10.000 rumpun / 90.000 segitiga sebelum mask); satu tile dibangun tiap frame.
- Rumput menyusut halus pada jarak 16–23 m. Tile jauh dilepas, bukan menanam
  jutaan rumpun di seluruh pulau. Shadow casting dimatikan untuk rumput.
- Hanya tanah hijau: mask jalan + margin angin, pantai/laut, lereng curam, dan batu.
  Akar mengikuti interpolasi mesh terrain; tidak menggunakan tinggi perkiraan.
- CI menguji mask/streaming dan renderer **Mobile Vulkan melalui Mesa/Xvfb**;
  ini bukan benchmark GPU Android. FPS, flicker, pop-in dan ketebalan akhir tetap
  harus diuji di HP.
- Update lewat launcher yang sama, tanpa APK baru. HUD **PULAU 1K — rumput angin**.
  Dari jalan awal, berjalan ke sisi hijau untuk melihat rumput. Jalan tetap bersih.

### Rumput v2 — revisi dari screenshot HP (32 FPS)

Bidang gelap diperbaiki dengan normal world-up **di fragment/view space**, bukan
hanya di vertex: normal sisi belakang tidak lagi menerima cahaya berlawanan.
Akar memakai AO lebih ringan dan gradasi hijau lebih dekat agar tidak berkontras
hitam. Tes renderer kini membandingkan pixel kartu depan/belakang dengan winding
berlawanan, termasuk A/B shader lama, bukan hanya memeriksa gambar tidak kosong.

Helai dipersempit dari 20 cm menjadi 8,5 cm, tinggi dasar 55 cm. Sebaran dari
20×20 menjadi 24×24 per tile (+44% rumpun), tetap 25 tile. Mesh disederhanakan
3→2 segitiga per helai: maksimum 14.400 rumpun / **86.400 segitiga**, dibanding
90.000 sebelumnya. Ini batas geometri, bukan jaminan FPS lebih tinggi di Android.
Tetap opaque, tanpa shadow casting rumput, dan mask jalan/pantai/tebing/batu.
HUD: **PULAU 1K — rumput halus v2**. Minta video/FPS untuk penilaian ulang.

### Padang lebat v3 — menutup celah tanah dekat pemain

Dari screenshot v2 (36 FPS), celah antar-rumpun masih jelas. V3 memakai dua tingkat:
9 tile dekat grid 40×40, 16 tile luar grid 20×20. Empat helai tipis per rumpun
(sebelumnya tiga); kepadatan dekat sekitar **3,7× helai/m²** dibanding v2.
Lapisan pendek opaque ±5 cm di atas tanah menutup sela, mengikuti kemiringan
terrain dan memakai corak daun kecil. Bukan sekadar memperlebar helai atas.

Detail dekat + lapisan pendek memudar pada 8–11 m, sebelum batas pergantian tile;
rumput dasar tetap sampai 23 m. Akar far adalah subset tetap dari grid dekat,
sehingga tidak bergeser ketika ganti LOD. Maksimal 20.800 rumpun / 112.000 segitiga
(sebelumnya 86.400); satu tile dibangun tiap frame. Ada tambahan beban geometri,
meski dibatasi—FPS HP wajib diuji ulang. Mask jalan/pantai/tebing/batu tetap.

CI mencakup tes sampel cakupan penutup tanah dekat (target >=95% area hijau yang
disampel), streaming, batas geometri, dan render pencahayaan dua sisi. Ini bukan
jaminan tidak ada satu pixel celah dari semua sudut. HUD **PULAU 1K — padang lebat v3**.
Update lewat launcher, tidak perlu APK baru.

## Soft light + outline, ikon anime dan loading art

- Cahaya dunia diredupkan sedikit: ambient 0,65→0,57; matahari 1,10→0,98.
  Kepadatan rumput v3 dan warna hijau tetap.
- Mannequin mendapat outline inverted-hull tipis (6 mm), mengikuti rig/animasi.
  Tidak memberi outline ke seluruh rumput agar tidak menggandakan draw rumput.
- Ikon Android anime orisinal (legacy + adaptive) dan ilustrasi pulau aesthetic
  baru di loading. Art dibuat AI; Pinterest hanya referensi, bukan aset salinan.
- Loading mempertahankan status/progres unduhan nyata serta retry/offline.
- **Perlu update APK satu kali** untuk ikon dan loading (keduanya di launcher).
  Install di atas aplikasi lama: package ID/keystore sama; version code kini 2.
  Dunia soft light + outline tetap tersedia lewat PCK untuk launcher lama.
- HUD **PULAU 1K — soft light + outline**. Tetap jangan merge main.

Shader compilation = menyiapkan kode efek grafis/pipeline agar sesuai GPU/driver.
Cache/pre-warm dapat mengurangi stutter saat efek pertama digunakan. CI render
Mobile/Vulkan mengecek shader dapat dirender, tetapi hasil compile di CI bukan
cache untuk GPU HP. Build ini tidak menambah layar/progres compile shader palsu;
perilaku precompilation/cache tetap mengikuti Godot dan driver perangkat.

### Ikon pilihan pengguna — APK 0.4.2

Gambar anime ungu yang diunggah pengguna ke root repo kini digunakan untuk ikon
Android (legacy + adaptive). Tidak digambar ulang. APK version code 4, agar tetap
lebih tinggi dari build sementara code 3 yang sudah ditarik. Install di atas
aplikasi lama tanpa uninstall; package ID dan keystore sama. Loading/gameplay
Tidak berubah. Mengganti ikon memerlukan APK, bukan hanya content pack.

## Jubah api biru pastel (skin mannequin)

Rig dan animasi UAL1 tetap dipakai. Skin luar prosedural menutup torso, lengan dan
kaki, dengan tudung, sarung tangan dan sepatu. Mesh mannequin di bawahnya hanya
disembunyikan setelah pemasangan jubah berhasil agar tidak menembus kain; skeleton
asli tidak diubah. Jika tulang wajib tidak ditemukan, mannequin asli tetap tampil.

- Kain opaque tipis, toon biru pastel, pola lidah api lembut di ujung dan manset,
  emisi rendah, outline tipis. Bukan api volumetrik atau simulasi fluida.
- Rok: 64 partikel Verlet, pin pinggang, 3 iterasi constraint, gravitasi/inersia,
  angin, tumbukan kapsul kaki dan tinggi tanah. Torso/lengan mengikuti pose rig.
- Teleport mereset kain; pergeseran tiap titik dibatasi untuk menghindari ledakan.
  Tidak memakai cloth/self-collision penuh atau ragdoll seluruh badan.
- CI: pin, gerak, lantai, teleport, finite coordinates; tes renderer Mobile Vulkan
  juga menggambar skin beserta shader. Kualitas gerak, clipping dan FPS tetap
  harus diuji saat jalan/lari/belok di HP.
- Konten kompatibel launcher lama: buka ulang online, tidak perlu install APK.
  HUD **PULAU 1K — jubah api biru**. Ikon/loading/map tidak diubah.

## Jubah dibatalkan + alat pembanding performa di HP

Atas permintaan pengguna, skin jubah beserta solver kain/shader dihapus dan
mannequin asli dengan outline dikembalikan. Ikon, loading, dunia, dan rumput v3 tetap.

Panel kanan atas (tersimpan ke user://graphics.cfg):
- Resolusi 3D 75% / 100%, UI tetap tajam. Default baru 75% (Ringan).
- Bayangan Nyala/Mati, default Mati. Tidak mengubah warna/arah pencahayaan.
- Rumput Nyala/Mati untuk diagnosis; Mati juga menghentikan streaming CPU.
- Batas FPS 60 / Bebas. Bebas menghapus cap aplikasi saja; VSync/Hz layar/OS tetap
  berlaku. Tidak memaksa refresh rate, tidak menjanjikan 60/90/120 FPS.
- Frame time rata-rata/P95 dari 120 frame terakhir dan total draw calls.
  Ini bukan GPU timer; P95 tinggi dapat mengindikasikan hitch, bukan diagnosis pasti.

Cara A/B: berdiri di tempat sama, kamera sama, tunggu streaming selesai, catat
FPS/frame-time 15–30 detik; ubah satu kontrol saja. Jika 75% jauh lebih cepat,
biaya rendering pixel kemungkinan berpengaruh. Bandingkan rumput dan bayangan
secara terpisah. 60 FPS perlu sekitar 16,7 ms/frame; 120 FPS sekitar 8,3 ms/frame.
Tes durasi beberapa menit juga diperlukan untuk panas/throttling.

Untuk diagnosis lanjut: Godot Profiler/Visual Profiler pada perangkat, Android
GPU Inspector (device/driver yang kompatibel), serta Perfetto. Hasil CI/Mesa bukan
benchmark HP. Minta tipe HP/chipset, Hz layar dan hasil A/B sebelum menyimpulkan
CPU/GPU bottleneck. HUD **PULAU 1K — mannequin + mode FPS**. Update lewat PCK.
