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

## Pet api astral + Attack

Pet biru–ungu toon ber-outline melayang di samping bahu (offset sekitar 1,1 m),
node dunia terpisah dari rig mannequin. Bobbing, napas dan lidah api bergerak.
Jubah tetap dihapus; mannequin/ikon/loading/panel performa tidak diganti.

Tombol ATTACK kanan bawah menembakkan bola api ke reticle (+). Target berasal
ray kamera ke collider dunia; lintasan proyektil memakai gravitasi 12 m/s² dan
sweep sphere `move_and_collide`, bukan teleport ke target. Saat benturan,
inti api bulat membesar (radius inti maks 1,9 m), dengan lidah api berputar,
cincin energi, lalu menyusut; tanpa flash layar atau guncangan kamera paksa.
Ini VFX api stylized, bukan simulasi fluida, damage/AI musuh belum ada.

Budget: cooldown0,85s, maksimal3 proyektil (TTL4s), maksimal2 ledakan (1s).
Mesh/material dibagi, efek opaque, tidak ada lampu dinamis/particle shadow tambahan.
Biaya render tetap bertambah: tes FPS HP saat spam attack tetap diperlukan.
Tombol attack dikecualikan dari swipe/pinch kamera; joystick kiri tetap bekerja.

CI menguji hover, jarak pet, tombol/kamera, cooldown, gravitasi, benturan tanah,
pembersihan dan batas efek. Shader pet/ledakan juga ikut tes Mobile Vulkan.
HUD **PULAU 1K — pet api astral**, update lewat PCK tanpa APK baru.

### Koreksi pet: ambil visual spirit api project lama

Setelah pengguna menolak pet baru, visual dirujuk langsung ke
`KyokoApp/Unity` branch `archive`, commit `bca3e575fc26311ef5a43c0263e772a6d9fced20`:
`project/packs/character_player/fire_spirit.gd`, `fireball_core.gdshader`,
`fireball_shell.gdshader`, dan helper `fire_fx.gd`.

Dua shader core/shell disalin **utuh**, bukan perkiraan shader baru. Visualnya
inti lavender terang, selubung api ungu aditif dengan lidah menjilat ke atas,
halo lembut dan lima ember kecil. Ukuran/material mengikuti parameter pet lama;
bukan bola besar bermata. Nyala mendapat flow/trail dari kecepatan pemain,
serta pulse saat attack. Tidak membawa OmniLight tambahan demi menjaga beban.

Perbedaan sengaja: controller posisi tetap terpisah ±1,1 m di samping bahu sesuai
permintaan terbaru (arsip terakhir mendekatkannya ke bahu). Attack/proyektil/
ledakan tetap versi saat ini; ronde ini hanya mengoreksi visual pet. Tidak membawa
sistem combat, dunia, atau shader lainnya dari archive. HUD **spirit api lama**.
Hasil layar/FPS harus diuji kembali; glow lingkungan lama tidak ikut diaktifkan.

### Combat VFX v2 — ekor api + impact berlapis
Projectile memakai core/shell asli archive, ekor mengikuti kecepatan, 10 partikel
api world-space dan 16 sparks. Ekor tidak terpotong ketika membentur terrain.
Impact: dua selubung api berputar berlawanan, 18 flame petals GDQuest/MIT,
24 sparks, 8 bara, shockwave sesuai normal permukaan, flash tanpa shadow 0.28s.
Tidak ada lagi deretan bola / delapan lobe + torus padat. Pet tidak diubah.
TTL impact 1.9s, ekor 0.7s; cap tetap 3 proyektil / 2 impact, cooldown 0.85s.
HUD: **PULAU 1K — api v2 — trail + impact**. Update via restart online/PCK.
Tes Mobile Vulkan sekarang memeriksa pixel projectile, volume impact, peluruhan,
cleanup, dan menyimpan screenshot CI. Kualitas visual/FPS tetap perlu uji HP.

### HUD bersih + multitouch
HUD debug, FPS/posisi, petunjuk dan crosshair dihapus dari layar bermain.
Grafik dibuka melalui rune kecil 60px kanan atas; semua pengaturan/perbandingan
frame tetap tersedia di drawer. Attack 128px bulat dengan SVG api original,
feedback tekan dan ring cooldown tanpa teks. Tombol menangani index sentuh
secara independen, bukan emulasi mouse satu jari: jalan + attack + orbit dapat
bersamaan. Menu mereset/memblokir joystick dan kamera sementara dibuka.
Regresi `test_hud.gd` menginjeksi event lewat viewport pada Mobile/Vulkan.

### Audio gameplay spasial
Langkah rumput/tanah/batu: empat variasi tanpa pengulangan berturut-turut,
variasi pitch/gain, dua kontak per siklus animasi, berhenti saat diam/di udara.
Api: suara tembak, desis peluru bergerak, ledakan, dan crackle pet sangat pelan.
SFX memakai posisi dunia dengan listener kamera: stereo panning, falloff jarak,
Doppler peluru, treble meredup jauh, dan occlusion collider dunia (cek 8Hz).
Pool 16 suara, limiter bus khusus; ekor ledakan tidak dipotong saat VFX hilang.
Tes audio merekam output mixer untuk membandingkan dekat/jauh dan kiri/kanan;
cek occlusion, variasi langkah, pool, cleanup, serta audio dalam PCK.
Tanpa musik/reverb indoor atau simulasi akustik penuh. Penyetelan akhir tetap
perlu didengar di speaker HP dan earphone; bukan klaim suara foto-realistis.

### Pet lebih terbaca sebagai api — visual dan suara
Pet kini memakai siluet lidah api tinggi, tiga ujung bergerak independen,
inti panas cyan-putih dan tepian ungu, tanpa bola padat. Bentuk menghadap kamera,
meruncing/terkoyak ke atas dan condong mengikuti gerakan; lima bara tetap ringan.
Posisi/jarak bahu, attack, projectile, explosion, UI dan langkah tidak berubah.
Pet memakai loop crackling CC0 terpisah selama 8 detik, lebih terdengar daripada
loop sintetis lama: -22dB, jangkauan18m, tetap spatial/occluded. Peluru tetap
memakai loop lamanya. Uji render mencakup pet dari depan/samping serta animasi;
uji audio/PCK memeriksa loop pet baru. Tampilan/mix akhir perlu konfirmasi HP.

### Outline pet tipis + jalan tanah lebih mulus
Siluet/gerak api yang disetujui tetap; contour indigo di dalam tepi api ~0.55
pixel render, tanpa pass tambahan. Jalan tetap tanah polos berkelok, tetapi
batas warnanya kini dihitung per-pixel, bukan blok warna antarsegitiga 5m.
Lebar jalur mengikuti arah tikungan, dengan gelombang elevasi panjang/lembut;
mesh dan collider tetap satu permukaan. Rumput, batu, dan foley memakai ukuran
jalur yang sama. Budget terrain tetap 80k triangles, tanpa mesh jalan tumpang tindih.

### Malam biru, bintang jarang, bulan kecil
Environment malam statis: gradasi indigo/biru tua, horizon lembut, sedikit
bintang tanpa kedip agresif, bulan kecil (~0.63 derajat) dengan halo tipis.
Moonlight mengikuti posisi bulan; ambient biru dipisahkan dari sky agar jalan,
rumput dan karakter tetap terbaca. Satu directional light yang sama, pengaturan
shadow tetap berlaku. Tidak memasang color-reducer/post-process, kabut volumetrik,
atau siklus siang-malam. UI, pet, outline, audio dan combat tidak diubah.

### World dressing, kabut tipis, dan rumput LOD tiga lapis
- Aset asli archive: 3 jenis pohon, semak/semak bunga, pakis, bunga, 2 batu,
  kerikil dan model setapak batu mengikuti jalur tanah berkelok. Trunk/batu
  punya collider sederhana; semak/bunga dekorasi tanpa collider.
- Nature deterministik di seluruh daratan yang layak, bukan spawn di air/jalan.
  Streaming 49 sel x40m (max 6 kandidat pohon +12 detail/sel), satu sel/frame.
  Mesh/material dibagi via MultiMesh per jenis/per sel; imported mesh LOD,
  visibility range pohon110m/detail65m; foliage tanpa shadow tambahan.
- Rumput dekat yang disetujui tetap (max112k tris); kartu silang 2D dari14–90m
  menambah max28,224 tris/49 sel x32m. Setelah itu corak penutup rumput menyatu
  dengan terrain sampai horizon; bukan jutaan helai di seluruh pulau sekaligus.
  Toggle rumput juga menghentikan streaming jauh dan corak terrain.
- Frustum culling bawaan tetap. Occlusion culling kini aktif dengan patch
  konservatif di DALAM bukit/terrain, <=5k tris; tidak menganggap daun transparan
  sebagai dinding. Ini bukan janji semua objek yang tertutup apa saja pasti dicull.
- Kabut depth ringan32–230m, langit/bulan tidak ditutupi, tanpa volumetric fog.
  Tes aset/mask/budget/determinisme/cleanup/occluder/PCK + Mobile Vulkan wajib;
  FPS/overdraw/CPU occlusion tetap perlu pengukuran HP nyata.

### Percobaan warmup shader/material saat loading
Saat gameplay dibuka oleh launcher, overlay loading menyiapkan resource lewat
render nyata di SubViewport kecil: karakter berskin, rumput/MultiMesh, partikel
api/impact, lalu seluruh variasi aset alam. World asli juga dirender di belakang
UI agar pipeline sky/terrain sesuai viewport aktual. Input, simulasi dan audio
sementara ditahan, lalu dipulihkan; objek uji tidak tinggal di world.
Bar menunjukkan tahap material (bukan persentase semua shader GPU). Ada tombol
"Lanjut tanpa menunggu" dan batas lunak20s, diperiksa antartahap; kompilasi driver
sinkron tetap dapat membuat satu tahap lebih lama. Tidak ada cache flag palsu
"sudah compile semua"; Godot/driver mengelola cache perangkat sendiri.
Ini upaya mengurangi first-use stutter, bukan peningkatan FPS rata-rata atau
jaminan seluruh pipeline/shadow/setting masa depan sudah hangat. Diagnostik
lokal: user://shader_warmup_last.json. Headless melewati render warmup.
Tidak mengubah launcher/updater bawaan APK: tahap ini berada di konten PCK;
boot marker dikonfirmasi setelah warmup/skip selesai.


### Danau & sungai malam
Danau di timur spawn memiliki garis pantai berlekuk/teluk kecil, tersambung sungai
berkelok ke laut tenggara. Terrain dan collider memakai cekungan yang sama;
jalan tetap utuh, rumput/pohon/batu besar menjauhi tepian. Belum ada berenang:
karakter ditahan sebelum masuk air, termasuk danau yang lebih tinggi dari laut.
Shader adaptasi MIT Marcel Bankmann/GodotSSRWater: kedalaman transparan,
refraction tipis, riak bergerak, busa tepian redup dan pantulan langit/bulan malam.
Mode bawaan **Pantulan air: Ringan**. Pilihan **SSR (uji)** di pengaturan hanya
untuk air pedalaman dekat kamera (<65m), max12 probe/18m; laut tetap fallback.
SSR hanya bisa memantulkan opaque yang ada di layar, bukan semua pohon/partikel
transparan atau benda di luar kamera; miss memakai warna air/langit, bukan hitam.
Mesh dibagi tile40m agar frustum/terrain occlusion tetap bekerja; tanpa simulasi
fluida, planar reflection, atau viewport refleksi tambahan. Warmup menjadi18 tahap,
termasuk air ringan dan SSR. Gerbang headless + Mobile Vulkan menguji collision,
vegetasi/jalan, depth/refraction, pantulan SSR nyata dan fallback. Ini bukan
benchmark HP: biaya screen/depth copy dan overdraw tetap perlu diuji di perangkat.
Update ini berupa PCK; launcher, keystore, package dan ikon tidak berubah.


### Casting attack sambil bergerak
Attack memakai klip asli Universal Animation Library `Spell_Simple_Shoot` (0,5s).
Layer badan atas saja, dengan fade masuk/keluar; kaki tetap diam/jalan/jog sesuai
input. Clock locomotion dan timing langkah tidak diganti. Tembakan/suara/pulse pet
keluar setelah windup0,16s; cooldown0,85s mulai sejak input diterima. Spam selama
windup tidak menambah peluru atau mengulang pose. Pet/warna/ledakan tetap sama.
Tidak menambah target latihan, damage, senjata atau multiplayer pada tahap ini.


### Kredit, lisensi dan izin aset
Karya orisinal A-Sekai: all rights reserved; lihat `LICENSE`. Ini bukan lisensi
ulang atas aset pihak ketiga. Model, animasi, audio, shader dan engine tetap
mengikuti ketentuan pembuatnya masing-masing. Daftar sumber/status di
`docs/CREDITS.md`; salinan pemberitahuan di `project/licenses/` ikut APK/PCK.
Di game: ikon grafik → **Kredit & lisensi**, pilih dokumen lalu scroll.
Pembaca bekerja offline; URL sumber ditampilkan sebagai teks yang bisa disalin.
Setelah mengedit kredit/hak orisinal, jalankan `python3 tools/sync_credits.py`.
Catatan Miku merekam izin khusus yang dilaporkan pemilik, bukan lisensi bebas;
skin tersebut baru terintegrasi sebagai prototipe lokal, belum dirilis. Izin tidak otomatis berlaku untuk
Kanna, ikon, atau model lain. Simpan percakapan asli dengan pembuat.


### Prototipe lokal: Miku / mannequin & HUD karakter
Miku memakai animasi CC0 UAL melalui retarget52 tulang setelah layer casting.
Switch melalui dua kartu portrait di kanan; sumber mannequin tetap berjalan
tersembunyi, tidak membuat player/collider/pet baru dan tidak mereset cooldown.
Miku menjadi pilihan awal gameplay; mannequin tetap tersedia sebagai fallback.
Attack128px kini berjarak132px dari kanan dan120px dari bawah (basis1280x720).
Kartu disembunyikan saat membuka grafik/kredit dan dikecualikan dari input kamera.
Material mempertahankan tekstur model; tidak memakai plugin VRM atau physics
rambut. Model42,674 tris/24 material, tekstur <=1024px; perlu tes kinerja HP.
Warmup19 tahap mencakup skin Miku selain mannequin dan water.

**Status validasi:** tes aset/matematika offline + parser/lint bisa dijalankan
lokal. Godot4.5.2 import/compile, retarget headless, HUD/render Mobile, PCK/APK
belum dijalankan untuk perubahan ini karena engine tidak tersedia di workspace.
Jangan melewati gerbang compile/render. Jangan push/rilis publik tanpa persetujuan.
Upload VRM di root baru dihapus sesudah gerbang engine lolos; aset runtime tetap ada.
