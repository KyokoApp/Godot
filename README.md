# A-Sekai

Game 3D open-world untuk Android, dibangun dengan **Godot 4.5** (GDScript).

Project ini **dimulai ulang dari nol** pada 2026-09-29. Versi lama masih
tersimpan penuh di branch `archive` pada repo `KyokoApp/Unity` — tidak ada
yang hilang, termasuk 176 model Medieval Village dan seluruh sistem
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

Semua kredit, provenance, teks lisensi, dan catatan izin dikonsolidasikan dalam
`project/licenses/LICENSES.txt`.

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

Adaptasi shader rumput dari referensi pengguna; sumber, atribusi dan ketentuan
lisensinya tercatat di `project/licenses/LICENSES.txt`.
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
Impact: dua selubung api berputar berlawanan, 18 flame petals hasil adaptasi,
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
Pet memakai loop crackling terpisah selama 8 detik, lebih terdengar daripada
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

### Dunia senja seperti ilustrasi layar muat
Permintaan pengguna (2026-10-02): dunia dibuat semirip mungkin dengan
`project/launcher/art/loading.jpg`. Ilustrasi itu bukan malam pekat, jadi
environment malam diganti **senja terang**: langit biru lavender dengan awan
pita panjang, pendar krem-persik di ufuk barat tempat matahari baru terbenam,
dan tanah hijau yang tetap terbaca. Warna shader diambil dari piksel ilustrasi
(zenith `#5776C2`, tengah `#8099D4`, pita hangat `#B4B3D2`, pendar ufuk
`#FDCBB2`). Bulan dan bintang dihapus — di ilustrasi langitnya bersih; titik
cahaya yang tampak adalah kunang-kunang di dekat tanah.
- `environment/dusk_environment.gd` + `dusk_sky.gdshader` = preset bersama untuk
  permainan, warmup shader, dan tes render (jadi layar dan gambar tes tidak
  pernah berbeda). Kabut jarak tipis 60–420 m; langit tidak ikut berkabut.
- Pemandangan di luar pagar (`world/scenery.gd`, tanpa collision): dua sabuk
  bukit hijau, laut tosca + pulau kecil di barat, tebing batu di timur, dua
  gapura + tiga tiang batu, dan tiga kumpulan kunang-kunang.
- Jalan tanah berliku digambar `ground.gdshader` (bukan mesh terpisah), jadi
  tidak ada draw call atau collision tambahan.
- Satu directional light matahari rendah (`Dusk.SUN_DIRECTION`); pengaturan
  shadow tetap berlaku. Tidak ada siklus siang-malam atau post-process berat.
  UI, pet, outline, audio dan combat tidak diubah.

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
- Kabut depth tipis, langit tidak ditutupi, tanpa volumetric fog.
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


### Danau & sungai (histori desain; dunia sekarang padang 100 m + pemandangan luar pagar)
Danau di timur spawn memiliki garis pantai berlekuk/teluk kecil, tersambung sungai
berkelok ke laut tenggara. Terrain dan collider memakai cekungan yang sama;
jalan tetap utuh, rumput/pohon/batu besar menjauhi tepian. Belum ada berenang:
karakter ditahan sebelum masuk air, termasuk danau yang lebih tinggi dari laut.
Shader air adaptasi dengan kedalaman transparan,
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
`project/licenses/LICENSES.txt` adalah satu-satunya berkas konsolidasi untuk
hak karya orisinal, seluruh kredit/provenance, teks lisensi pihak ketiga, dan
catatan izin khusus. Berkas ini ikut APK/PCK. Viewer kredit/lisensi di dalam
game sengaja dihapus; bundling tidak menambah atau memperluas izin apa pun.
Baca bagian dan syarat yang berlaku sebelum menggunakan aset. Jalankan
`python3 tools/check_license_bundle.py` untuk memvalidasi bundel.


### Miku / Kanna / mannequin & HUD karakter
Miku memakai animasi UAL melalui retarget52 tulang setelah layer casting.
Switch melalui tiga kartu portrait di kanan; sumber mannequin tetap berjalan
tersembunyi, tidak membuat player/collider/pet baru dan tidak mereset cooldown.
Kanna dari arsip proyek lama juga tersedia; 50 tulang dipetakan untuk rig Kanna.
Miku menjadi pilihan awal gameplay; mannequin tetap tersedia sebagai fallback.
Attack128px kini berjarak132px dari kanan dan120px dari bawah (basis1280x720).
Kartu disembunyikan saat membuka pengaturan grafik dan dikecualikan dari input kamera.
Material mempertahankan tekstur model; tidak memakai plugin VRM atau physics
rambut. Model42,674 tris/24 material, tekstur <=1024px; perlu tes kinerja HP.
Warmup20 tahap mencakup Miku, Kanna, mannequin dan water.
Kanna194.476tris/43material lebih berat: gunakan Miku/mannequin bila FPS turun.

**Validasi:** import/compile Godot4.5.2, retarget/casting headless, pergantian skin,
multitouch, dan render skin Mobile Vulkan diuji oleh workflow sebelum export/rilis.
Tes aset/matematika offline: `tools/test_miku_asset.py`. Pengukuran HP tetap perlu.
Pemilik telah mengizinkan push dan build HP. Unggahan VRM duplikat di root dihapus
setelah import/render lolos; sumber historis ada di commit upload `c95925e`.
Aset runtime dalam `project/assets/characters/` dan bundel
`project/licenses/LICENSES.txt` tetap disertakan.


### Spring rambut Miku & jejak api tapak
Dua twintail Miku memakai16 sendi sekunder dengan pegas rotasi teredam, mengikuti
kecepatan, percepatan dan belokan. Panjang tulang asli tetap; ujung merespons
bertahap. Substep120Hz, batas sudut6,3°/sendi, reset saat teleport/hitch/switch.
Ini gerak sekunder stylized ringan, bukan simulasi tiap helai atau cloth penuh;
belum ada solver collision rambut-badan/lingkungan, clipping ekstrem masih mungkin.
Kanna/mannequin tidak diberi simulasi rambut Miku.

Jejak memakai pose ankle/toe skin aktif, ray lantai dan hysteresis kontak kaki.
Tidak muncul ketika diam, melayang, atau di air. Bentuk tapak asimetris dan lima
lidah mesh api3D (bukan billboard/decal saja), mengikuti arah kaki dan normal tanah.
Miku biru-putih-ungu, Kanna emas-kuning, mannequin ungu-cyan. Maks16 cap, lifetime
1,15s, tanpa lampu, bayangan, damage, atau suara tambahan; skin switch tidak
mewarnai ulang jejak lama. Teleport membersihkan cap. Suara langkah lama tetap.
Warmup21 tahap mencakup shader tapak api. Tes kontak/decay/pool dan Mobile Vulkan
untuk skin rambut, palet serta tampak samping api wajib; FPS tetap diuji di HP.


### HUD putih transparan
Nama karakter di kiri, portrait di kanan; tanpa panel/aksen berwarna/teks GANTI.
Rune, analog dan garis HUD putih transparan; portrait tetap memakai warna aslinya.
Tombol speed ×3 dan efek larinya sudah dihapus; gerak kembali 5 m/s.


## Kabut arena
Area arena terpisah di (-145, 140) mempertahankan tanah-batu retak dan aurora
abu-putih. Masuk ke arena: kabut luar berangsur menebal dari sekitar 8m luar
tepi hingga penuh 10m dalam tepi; dua lapis tembok kabut di batas dan kubah
kabut di atasnya menutup panorama luar. Di luar arena kabut ini tidak dirender;
keluar arena memudarkannya lagi. Lantai, karakter dan pertarungan tetap terlihat.
Dinding kabut hanya visual, bukan collision atau sistem teleport/musuh.

### Tantangan melee & pedang
Tantangan hanya dimulai lewat artefak di dalam arena. Bar HP musuh berupa garis
ramping di tengah atas; HP pemain berada di bawah minimap. Gaya bawaan **Melee**
memainkan klip UAL2 Standard non-root-motion `Melee_Hook` dengan reaksi `Hit_Knockback`;
gaya **Pedang** memainkan
`Sword_Regular_Combo`. Pedang latihan low-poly dibuat prosedural dan dipasang ke
tulang tangan kanan rig skin yang sedang aktif—hanya terlihat saat gaya Pedang
dipilih. Musuh dan damage hanya ada selama tantangan, tanpa gore; saat menang,
kalah, atau keluar arena, HUD dan pedang dibersihkan. Tombol gaya tidak memulai
geseran kamera sentuh.

Updater v2 kini memakai blok inkremental; lihat bagian berikut.


## Updater inkremental v2
**Pasang APK v0.5 sekali di atas aplikasi lama, jangan uninstall.** Launcher lama
tertanam di APK dan tidak bisa diperbarui oleh content.pck. Keystore tetap sama.
APK baru berisi data awal yang sama dengan release; tidak perlu mengunduh data
itu lagi setelah instalasi. Sesudahnya hanya blok yang berubah/hilang/rusak yang
diunduh, bukan seluruh 47–50 MB. Ukuran update tergantung perubahan; perubahan
model besar tetap bisa besar. Launcher lama tetap dilayani content.json/PCK penuh.

`content-v2.json` memetakan urutan blok SHA-256 dari PCK yang diekspor. Blok aset
besar dipotong pada batas file dan maksimal 1 MiB agar perubahan script kecil
tidak menggeser blok model. Launcher memakai ulang blok dari APK, versi aktif,
versi sebelumnya dan cache unduhan yang sudah lolos checksum. Blok baru berasal
dari URL release commit yang tetap. Progress menunjukkan byte yang perlu diunduh.

PCK baru disusun lokal dengan buffer maksimal 1 MiB; ukuran dan SHA-256 seluruh
PCK diverifikasi sebelum aktivasi atomik. Satu versi sebelumnya dipertahankan
untuk rollback saat boot terputus. Download putus: blok selesai tetap tersimpan,
blok yang sedang terputus diulang (bukan HTTP range resume). Main offline memakai
versi aktif yang valid atau data bawaan. Butuh ruang untuk paket baru + versi lama
+ cache, walau unduhan jaringan kecil. Cache dibatasi 256 MiB; pack selain aktif
atau rollback dibersihkan pada start berikutnya. Data legacy v1 tidak dihapus.

CI memeriksa format manifest, checksum, kerusakan, deduplikasi, retry, rollback,
APK seed/duplikasi aset, ekspor ulang deterministik, dan ukuran perubahan script
pada PCK asli. Cold boot dari aset APK saja belum diuji otomatis; perlu uji perangkat sebelum
menyatakan migrasi HP tervalidasi. Tidak mengklaim delta per-baris atau selalu ukuran KB.


## Koreksi batas arena (30 September 2026)
- Koreksi instruksi sebelumnya: speed ×3 tersedia hanya di luar arena. Saat melewati
  lingkaran aurora, boost dibatalkan, tombol disembunyikan, asap/pose echoes dibersihkan;
  gerak arena normal 5 m/s. Keluar: tombol kembali, boost harus diaktifkan manual.
- Kabut baru mulai setelah masuk footprint aurora, penuh 5 m ke dalam, nol di luar.
  Dua dinding asap berjarak 12/15 m di luar ring; tanpa dome putih yang menutup langit.
  Noise lembut abu-putih di belakang aurora, fade vertikal, bukan layar putih polos.
  Aurora tetap ada dan digambar setelah asap. Environment dunia normal tidak diubah.
- Efek speed luar arena mengembalikan versi pose echoes + asap ff178b2 (bukan kabel
  terang atau bola). Shader warmup kini 23 tahap. Tes batas, speed/HUD dan render wajib.


## Sinar matahari screen-space
Adaptasi metode radial scattering dari referensi pengguna, bukan volumetric fog. Memakai
kedalaman layar reverse-Z, 16 sampel, tanpa render ulang seluruh dunia lewat
SubViewport. Warna krem hangat halus mengikuti arah matahari senja di sky
(`Dusk.SUN_DIRECTION`, sama dengan arah kilau di air). Otomatis mati saat
matahari di belakang/luar kamera atau pemain di dalam arena. Efek berada di
bawah HUD dan transparansi, tidak menerangi terrain/karakter. Objek transparan
atau di luar layar tidak ikut menghalangi sinar. Toggle tersimpan “Sinar matahari”
ada di Grafik untuk tes A/B HP; tidak menjamin FPS. Renderer target Mobile 4.5.2.

## Minimap bulat
HUD kiri atas 176px, north-up, pemain di tengah dan arah karakter + kerucut kamera.
Kartografi original (bukan aset Genshin): tanah, pantai, jalan utama, danau/sungai,
dan lingkaran arena saat seluruhnya dalam jangkauan. Radius pandang 125m.
Tekstur 256px dibuat sekali dari terrain aktual; update posisi 10Hz, tanpa kamera
3D tambahan. Sentuhan peta tidak mengaktifkan joystick. Belum ada peta fullscreen,
quest marker atau teleport. HUD mengikuti skala viewport seperti kontrol lain.

## Padang 100 m + mannequin only + katalog 85 animasi (2026-10-01)

Permintaan pengguna: bangun ulang dunia jadi padang 100 m × 100 m berumput,
hapus karakter lain (Miku/Kanna), dan pakai SEMUA animasi yang tersedia dengan
animasi yang benar-benar diperbaiki.

- **Dunia**: `world/field.gd` (100 m × 100 m, gelombang ≤ 0,9 m, shader tanah +
  penutup rumput), `world/boundary_fence.gd`, `grass_field.gd` (tile 12 m,
  LOD grid 40/20, batas 25 tile hidup). Rumput hanya di dalam pagar.
- **Karakter**: hanya `mannequin.gd`. Miku, Kanna, skin switcher, kartu karakter,
  portrait, retarget, hair spring, minimap, arena, air, jalan batu dan model
  nature dihapus dari repo.
- **Animasi**: satu AnimationPlayer memuat UAL1 (43 klip) + pustaka `ual2` dari
  UAL2 (43 klip) = 85 nama di `animation/catalog.gd`, lengkap dengan label dan
  keterangan Indonesia serta flag loop/once/hold/gait.
- **Perbaikan animasi**: mode loop per klip disetel dari katalog; kecepatan main
  klip dicocokkan dengan langkah hasil ukur `animation/anim_metrics.gd` sehingga
  kaki tidak meluncur; offset tanah per klip menjaga pose rendah; cross-fade antar
  klip; aksi sekali jalan pakai timer `_action_left` (deterministik di headless).
- **Gerbang baru tanpa engine**: `python3 tools/check_animation_catalog.py`
  memverifikasi 85 klip ada di GLB, sumber & flag benar, lalu mengukur ulang
  langkah tiap klip gait (m/s) dan membandingkannya dengan rentang yang dijaga.
- **Tes engine** yang relevan: `test_mannequin` (katalog + state machine + casting),
  `test_movement`, `test_grass` (LOD + dua sisi terang), `test_hud`, `test_speed`
  (boost 1,35× + anti meluncur), `test_motion_flair` (tapak api), `test_dusk`, `test_skin_shell`,
  `test_scenery` (gerbang pemandangan) dan `render_world` (4 sudut dunia),
  `test_audio`, `test_pack` (85 klip + lisensi di PCK). Belum diuji di HP.

### Perbaikan 2026-10-02 — nama klip runtime + joystick

- **Importer glTF membuang akhiran `_Loop`** dari nama animasi di AnimationPlayer
  (`Walk_Loop` di berkas menjadi `Walk` di engine). Katalog memakai nama berkas,
  jadi `animation.play("Idle_Loop")` gagal, `_ready()` mannequin berhenti di
  tengah dan seluruh HUD (joystick, tombol, panel) tidak pernah terbangun —
  karakter tidak bisa digerakkan sama sekali. `Catalog.play_name()` sekarang
  membuang sufiks itu sebelum menambah prefiks `ual2/`; nama runtime tiap klip
  diuji `tools/test_clips.gd` dan aturan baru di `check_animation_catalog.py`
  (nama runtime wajib unik + daftar klip loop tanpa sufiks terpantau).
- **Joystick belum pernah tersambung** ke `player.joystick` di `main.gd`, jadi
  input sentuh tidak menggerakkan karakter meski HUD tampil.
- **CI sekarang memberi alasan**: `_check()` mencetak `::error::`, langkah tes
  memakai `tee`, dan langkah "Ringkasan kegagalan" menampilkan 24 baris terakhir
  tiap log sebagai anotasi.
- Hasil: CI hijau penuh (37 langkah, termasuk ekspor PCK + APK dan rilis
  `A-Sekai build-3b29806`). Menunggu tes di HP.

### 2026-10-02 — akar layar abu-abu di HP: paket APK kehilangan skrip launcher

Layar HP yang abu rata **tanpa teks apa pun** ternyata bukan masalah shader atau
HP: warna itu warna latar bawaan Godot, artinya tidak ada satu pun UI yang
digambar. Penyebabnya paket utama APK hanya berisi `launcher.gdc` dan ikon —
`backdrop.gd`, `chunk_policy.gd`, `chunk_store.gd` tidak ikut, sementara
`launcher.gd` mem-preload ketiganya, sehingga skrip launcher gagal dimuat dan
seluruh launcher mati sebelum menggambar apa pun. Filter ekspor `scenes` hanya
mengikuti dependensi *scene*, bukan dependensi *skrip*.

- `export_presets.cfg` (preset Android): berkas launcher masuk `export_files` +
  `include_filter`; `main.tscn` membawa ilustrasi sebagai ext_resource.
- `backdrop.gd` tidak lagi mem-preload tekstur; kalau teksturnya tidak ada,
  launcher memakai latar polos (bukan mati total).
- Gerbang baru di CI: `Audit isi APK` dan `tools/test_apk_launcher.gd` yang
  mem-boot launcher dari isi APK, bukan dari folder proyek — satu-satunya cara
  menangkap kelas bug ini.
- Konsekuensi penting: **perbaikan ini butuh install APK baru**; update konten
  lewat PCK tidak bisa memperbaiki launcher yang rusak.

### 2026-10-02 — kontrol & HUD: lompat langsung, combo, panel kecil, tombol bulat

- **Lompat langsung**: menekan LOMPAT memakai `velocity.y = JUMP_VELOCITY` saat
  itu juga (dulu ada jeda tolakan 0,22 s). Pose `Jump_Start` hanya menempel
  0,3 s, lalu klip melayang `Jump_Loop`, dan mendarat hanya sah saat badan
  benar-benar turun.
- **Combo serangan**: tiap tekan SERANG lanjut ke klip berikutnya
  (`Punch_Jab` → `Punch_Cross` → `Melee_Hook`) lalu berulang; combo kembali ke
  awal setelah 1,1 detik tanpa serangan.
- **Tombol bulat tanpa kotak** (`rune_button.gd`): label di dalam lingkaran +
  cincin aksen. Susunan HUD: SERANG (136) di kanan bawah, TEMBAK api pet (96),
  LOMPAT/LARI/JONGKOK (92) di atasnya, ANIM + GRAFIK (72) di kanan atas.
- **Panel animasi = jendela kecil** yang bisa discroll; scroll ditangani panel
  sendiri sehingga drag bisa dimulai di baris mana pun (dulu hanya dari pojok),
  ketukan pendek memilih klip, dan ketukan di luar jendela menutup panel.
- Tombol HUD tidak lagi ikut memulai analog (`input_exclusions`).

### 2026-10-02 — kulit mannequin: hitam gelap + outline putih tipis

Permintaan pengguna: skin mannequin diganti jadi **hitam gelap** dengan
**garis tepi putih tipis**. Hanya warna yang berubah — struktur kulit (salinan
mesh + `grow` 22 mm), mirror pose, denyut mengikuti kecepatan, dan gerbang tes
`tools/test_skin_shell.gd` tetap sama.

- `character/skin_shell.gdshader`: `skin_dark` 0,150/0,195/0,300 → 0,010 (nyaris
  hitam), `skin_light` 0,330/0,420/0,575 → 0,050 — gradasi gelap kaki→kepala
  dipertahankan supaya bentuk badan masih terbaca dari jauh. Garis energi
  `vein_color` dan rim `rim_color` jadi abu gelap: tubuh tetap terbaca hitam,
  tidak rata seperti plastik. Rim sekarang benar-benar memakai `rim_color`
  (sebelumnya uniform itu tidak terpakai).
- `character_outline.gdshader`: warna bawaan gelap → **PUTIH**, lebar bawaan
  6 mm → 5 mm (tipis). Putih dipasang eksplisit di `mannequin.gd`
  (`_apply_material`) dan `character/skin_shell.gd` (`_make_outline`) supaya
  outline mesh dalam dan salinan kulit tidak mungkin berbeda warna.
- Belum diuji di HP; gerbang CI (parse, compile, tes kulit/animasi) tidak
  mengunci warna lama, jadi tidak ada tes yang perlu diubah.

### 2026-10-02 — build CI diparalelkan: 12 menit jadi 4 menit

Update project ini nyicil (satu perubahan kecil = satu push), tapi build lama ± 8 menit
dan hampir seluruhnya di render Mobile Vulkan software (lavapipe, runner 2 core).
Dari data run `36999636319`: render = 302 s dari total 467 s, sisanya lint 32 s,
apt 29 s, tes headless 34 s, ekspor 27 s.

- Workflow `apk` dipecah jadi 6 pekerjaan: **gate** (lint + compile + semua tes
  headless, ± 2 menit), **render-a/b/c** (render Mobile Vulkan dibagi berimbang
  ± 100 s masing-masing, jalan bersamaan), **package** (PCK + APK + audit + rilis,
  TUNGGU gate hijau), **ringkasan** (komentar angka/pratinjau/log gagal, selalu
  jalan), dan **build** (gerbang agregat).
- Aturan lama **"compile lolos dulu, baru ekspor APK"** tetap dijaga: `package`
  menunggu `gate`. Render sengaja tidak menunggu gate supaya push kecil tidak
  menunggu dua kali.
- Setiap gerbang/periksa yang lama TIDAK dihapus — hanya dipindah; audit otomatis
  membandingkan 60 blok perintah lama vs baru (0 langkah hilang, 0 beda isi).
- Komentar commit pindah ke pekerjaan `ringkasan` yang `if: always()`: dulu kalau
  tes gagal di tengah, angka diagnostik ikut hilang. Log tiap pekerjaan kini
  diunggah sebagai artefak `logs-*`, pratinjau JPEG dibuat di pekerjaan render.
- Job `build` agregat mempertahankan nama status check lama (`apk / build`)
  supaya required check di Settings tidak perlu diubah.
- Verifikasi lokal: YAML valid, 60/60 blok `run:` lolos `bash -n`.

Hasil ukur setelah dipecah (run `37002663347`, semuanya hijau):

| Pekerjaan | Durasi | Isi |
|---|---|---|
| render-c | 3,6 menit | avatar dekat + pemandangan dunia |
| render-b | 3,1 menit | HUD + warmup GPU |
| render-a | 2,1 menit | rumput, api, casting, tapak, sinar, senja |
| gate | 1,8 menit | lint + compile + tes headless |
| package | 1,1 menit | PCK + APK + audit + rilis (jalan setelah gate) |
| ringkasan | 0,3 menit | komentar angka/pratinjau/log |

**Waktu yang dirasakan pengguna (push → run selesai): 11 menit 59 s → 4 menit 6 s.**
Bottleneck sekarang render-c (render avatar); kalau nanti mau lebih cepat lagi,
langkah termurah adalah memindah "Render pemandangan dunia" ke render-a yang
masih punya ruang, atau memecah render-c jadi dua pekerjaan.

### 2026-10-02 — kulit mannequin: hitam POLOS (garis energi dibuang)

Lanjutan permintaan "hitam gelap + outline putih tipis": kali ini garis energi
yang mengalir dan percikan kecil DIHAPUS, jadi tubuh benar-benar hitam polos.

- `character/skin_shell.gdshader`: perhitungan `band`/`vein`/`sparkle` dan
  `vein_speed` dibuang. Yang tersisa: gradasi sangat gelap kaki→kepala
  (`skin_dark` 0,010 → `skin_light` 0,050), satu bercak hash halus supaya tidak
  seperti plastik, dan rim abu tipis di pinggir siluet yang menguat saat lari
  (`pulse`) atau menyerang (`charge`) — tanpa gelombang yang berjalan, jadi
  tubuhnya tetap polos.
- Uniform `vein_color`/`vein_scale`/`vein_width` sengaja MASIH dideklarasikan
  supaya `set_light_cloth()` (mode grafis Ringan) tidak menyetel parameter yang
  tidak ada; nilainya sudah tidak dipakai shader.
- `set_light_cloth()` di `mannequin.gd` tetap ada (dipakai `performance_panel.gd`)
  tapi tidak lagi mengubah tampilan — mode Ringan kini hanya memengaruhi
  resolusi/bayangan/rumput seperti sebelumnya.
- Outline putih tipis (5 mm) tidak berubah. Belum diuji di HP.

### 2026-10-02 — dunia jadi PULAU 1 km × 1 km, garis pantai bergelombang

Permintaan pengguna: "world nya 1km, pinggirannya jangan bulat atau kotak tapi
kayak pulau gitu bergelombang". Cicilan ini HANYA ukuran dunia + bentuk garis
pantai (palet gelap, rumput rapat, partikel ungu, sinar senja, dan shader air
adalah cicilan berikutnya — belum dikerjakan).

- `src/game/world/field.gd` ditulis ulang: dunia 1000 × 1000 m (dulu 100 m).
  Bentuk pulau dari **satu fungsi tinggi** (`terrain_height`) yang dipakai mesh,
  collider, karakter, rumput, tapak api, dan langkah kaki — itu sebabnya fungsi
  itu `static` dan murni (tidak boleh bergantung node/frame/urutan build).
- Garis pantai TIDAK bulat dan TIDAK kotak: radius pulau per sudut dihitung dari
  noise rendah di sepanjang lingkaran plus dua lekukan sinus. Hasil terukur
  radius **285-368 m** (berubah **22%** antar arah), luas daratan ± 0,35 km².
- Medan: dataran ± 6 m di pedalaman, tanjakan pantai 6 m / 70 m (± 8,5% — bisa
  dilalui), dasar laut turun sampai -9 m supaya pantai tidak terlihat seperti
  potongan. Perbukitan halus ± 4 m yang melemah mendekati garis air.
- **Chunk streaming** (bukan satu mesh 1 km): chunk 128 m × 128 m (32 × 32 sel
  4 m) dibangun SATU per frame mengelilingi pemain, maksimal 7 × 7 = 49 chunk
  (± 448 m). Grid chunk dipusatkan di (0,0) supaya jangkauannya simetris; chunk
  yang seluruhnya di laut tidak pernah dibangun (hemat draw call). Terukur
  ± 36 chunk hidup, selisih tinggi grid vs fungsi analitik 0,014 m.
- `ground.gdshader`: cincin "tepi padang" (yang butuh jarak ke pusat) dibuang,
  diganti **pita pasir berbasis ketinggian** (`shore_low` 0,35 → `shore_high`
  2,6 m). Karena memakai tinggi, pasir mengikuti garis air yang berliku tanpa
  perlu tahu bentuk pulau. Jalan tanah dilebarkan (lebar 3 m, lekuk 55 m) dan
  fasanya diganti supaya melintas tepat di titik spawn pemain (0, 7).
- `world/scenery.gd`: laut jadi SATU bidang 4200 × 4200 m di y = -0,15 yang
  mengelilingi seluruh pulau (dulu di sisi barat saja). Bukit dipindah ke
  520-780 m dan 820-1250 m, tebing ke x = 513 m, pulau batu ke x = -760/-905 —
  semuanya di LUAR garis pantai supaya tidak tumbuh di tanah pemain.
- `orbit_camera.gd`: zoom terjauh 8 m → **620 m** (pemain harus bisa melihat
  pulau yang mereka minta). `ARM_COLLISION_LIMIT` 30 m: di atas itu SpringArm
  berhenti menabrak tanah, kalau tidak kamera terjepit di bukit pertama.
- `environment/dusk_environment.gd`: kabut 60-420 m → **200-1400 m**. Bukit di
  kaki langit kini berdiri 520-1250 m dari pemain; dengan kabut lama bukit itu
  lenyap seluruhnya. Garis horizon air (`horizon_fade`) ikut jadi 1400 m.
- **Pagar kayu (`world/boundary_fence.gd`) DIHAPUS** — batas dunia sekarang
  garis pantai. `player.gd`: `_keep_inside()` memakai `Field.clamp_inside()`
  dengan `SHORE_MARGIN` 14 m (proyeksi radial balik ke darat), bukan lagi
  klamping kotak. `audio/footsteps.gd`: suara "tanah" bukan lagi cincin di tepi
  pagar melainkan pita pasir (tinggi tanah < 2,6 m), sama dengan shader.
- Gerbang baru `tools/test_island.gd` (7 janji): ukuran 1 km, garis pantai
  bergelombang (bukan bulat/kotak), darat di dalam & air di luar, tinggi mesh =
  tinggi collider = tinggi pemain, `clamp_inside` selalu balik ke darat, chunk
  streaming hidup & chunk laut tidak dibuang, rumput tidak menempel pantai.
  Gerbang lama diperbarui (test_scenery/test_grass/test_audio/render_world) dan
  satu langkah CI baru menambahkan tes pulau ke `gate`.

Hasil CI (run `37011157491`, 7/7 pekerjaan hijau, push → selesai 4 menit 30 s):
gate 104 s (termasuk tes pulau baru `[island-test] gagal=0`), render-c 209 s,
render-a 189 s, render-b 175 s, package 90 s. Belum diuji di HP — sandbox tidak
bisa menjalankan Godot, jadi bentuk pulau dinilai dari gambar render CI
(`world-pulau/pantai/pemandangan/jalan/laut`) dan dari HP pengguna.

### 2026-10-02 — palet senja: tanah & rumput gelap tapi tetap terbaca

Lanjutan permintaan "tanah dan rumput jadi gelap tapi tetap kelihatan, dan
rumput satu warna dengan tanah". Cicilan ini HANYA warna (rumput rapat, partikel
ungu, sinar cahaya, dan shader air menyusul).

- `world/field.gd` — satu sumber warna untuk shader tanah: `GRASS_COLOR`
  `8fce63 → 3f6b34`, `GRASS_DARK` `6aa845 → 2d4f27` (± 45% lebih gelap),
  `SAND_COLOR` `c9a873 → 9a8260` (± 25%, senja bukan siang). Angkanya dipilih
  supaya kanal hijau tanah tetap di atas 0,22 setelah dicahaya senja — batas
  gerbang `test_dusk`.
- `grass.gdshader` dan `world/grass_distance.gdshader` — warna helai
  (`top_color`/`bottom_color`) diambil dari warna tanah yang sama, jadi rumput
  dan tanah terbaca sebagai SATU warna. Ujung helai sedikit lebih terang dari
  akarnya; itu yang masih membuat helai terbaca sebagai benda 3D setelah
  warnanya disamakan.
- `tools/test_dusk.gd` — gerbang "tanah hijau terbaca" dulu memakai hijau muda
  `8fce63` yang ditulis ulang di dalam tes, padangkan dunianya sudah berubah:
  tesnya menguji warna yang tidak dipakai lagi. Sekarang warnanya diambil dari
  `Field.GRASS_COLOR`, jadi janjinya jadi "tanah GELAP pun masih terbaca".
- `world/scenery.gd` — konstanta `DIRT_COLOR` yang tidak terpakai ikut meredup
  supaya tidak menyesatkan.

Belum diuji di HP — sandbox tidak bisa menjalankan Godot.

### 2026-10-02 — rumput rapat: helai kecil, menutupi sampai 32 m, kartu LOD sampai 128 m

Lanjutan permintaan "rumput jadi kecil, rapat, benar-benar terlihat helainya,
menutupi semua yang terlihat di jangkauan kamera". Cicilan ini hanya rumput.

- `grass_field.gd` — helai mengecil supaya terbaca sebagai helai, bukan semak:
  tinggi 0,55 → 0,34 m, lebar 0,085 → 0,055 m, lapisan bawah 0,25 → 0,22 m.
  Kerapatan naik: `GRID` 40 → 44 (13,4 rumpun/m², 54 helai/m²) dan `FAR_GRID`
  20 → 22.
- Cakupan helai rapat + lapisan bawah naik dari 12 m ke 24 m (`NEAR_SPAN`
  1 → 2, jadi 5×5 tile), lalu makin renggang sampai 36 m (`RADIUS` 2 → 3).
  Sebelumnya lapisan bawah tanah hilang sudah di 8–11 m dari pemain, jadi
  rumput tampak berhenti tak jauh dari pemain.
- `grass.gdshader` — fade helai 23 → 32 m; fade detail/lapisan bawah 8–11 →
  18–25 m.
- `world/distant_grass.gd` — kartu LOD mengambil alih dari 27 m sampai 128 m
  (`RADIUS` 3 → 4, `GRID` 12 → 14, dua tile per frame supaya 81 tile tetap
  cepat terisi saat spawn); `world/grass_distance.gdshader` fade masuk 19–27 m,
  fade keluar 100–130 m.
- Anggaran gambar: helai asli 336.864 tris + kartu 63.504 tris = 400.368 tris
  (sebelumnya 140.224). Batas ini dijaga `tools/test_grass.gd`, dan tile penuh
  sekarang 49 (tes menunggu 60 frame, bukan 35).

Belum diuji di HP — sandbox tidak bisa menjalankan Godot.

### 2026-10-02 — partikel ungu

Lanjutan permintaan "partikel ungu". Cicilan ini hanya partikel.

- `world/scenery.gd` — `MOTE_COLOR` `ffe9b0` (krem) → `c9a6ff` (ungu). Ini
  satu-satunya partikel yang masih hangat: jejak api kaki, aura kecepatan, roh,
  dan efek serangan sudah ungu semua.
- Titik cahaya melayang sekarang menyebar di sepanjang jalan (10 titik, 220
  partikel) — dulu hanya 3 titik dekat spawn, jadi partikelnya hampir tidak
  pernah terlihat saat pemain berjalan. Posisi mengikuti lik jalan yang sama
  dengan `ground.gdshader`, digeser 6 m ke samping supaya melayang di atas
  rumput, dan tingginya dihitung dari terrain pulau.
- `tools/test_scenery.gd` — gerbang baru: partikel harus ungu (kanal biru >
  merah dan > hijau), dan jumlah titik ikut tercetak di diagnostik.

Belum diuji di HP — sandbox tidak bisa menjalankan Godot.

### 2026-10-02 — suasana senja: glow, matahari lebih jingga, contact shadow ala ray tracing

Lanjutan permintaan "suasana senja dengan sinar cahaya dan kesan seperti ray
tracing". Cicilan ini hanya suasana/pencahayaan.

- `environment/dusk_environment.gd` — glow (bloom) dinyalakan: satu-satunya efek
  "sinema" yang didukung renderer Mobile. Yang mekar hanya bagian terang (pendar
  matahari, kunang-kunang ungu, tepi bercahaya). Tiga penyetel penting supaya pendar
  ufuk TIDAK jadi putih (1,1,1) — kalau putih, gerbang `test_dusk` "ufuk harus hangat
  (merah > biru)" gagal: `glow_normalized = true` (dengan false, 7 level bloom menambah
  penuh jadi ~7x terlalu terang), ambang 1,15 (hanya inti matahari mekar), intensitas
  0,25. Matahari jadi lebih jingga dan
  sedikit lebih kuat (1,0 / 0,83 / 0,64, energi 1,05), cahaya sekitar lebih
  dingin dan redup supaya terbaca senja — tapi tidak turun jauh, karena janji
  `test_dusk` adalah "bukan malam pekat". Kabut ikut menghangat.
- `environment/dusk_sky.gdshader` — zenith lavender lebih dalam, ufuk lebih
  persik. Warna sengaja tidak dibuat gelap sekali.
- `god_rays/sun_rays.gd(+shader)` — sinar matahari sedikit lebih kuat
  (0,16 → 0,22) dan lebih hangat.
- `god_rays/contact_shadows.gd(+shader)` (BARU) — sinar ditembakkan dari setiap
  piksel ke arah matahari lalu dibandingkan dengan buffer kedalaman: bayangan
  KONTAK di kaki objek yang selalu hilang dari shadow map. Inilah "kesan ray
  tracing"-nya, karena SSAO/SSR/SSIL/volumetric fog di Godot hanya ada di
  Forward+, sementara proyek ini memakai renderer Mobile. 14 sampel sepanjang
  21 m, hanya untuk piksel di depan kamera (hemat ± setengah layar), memudar di
  tepi layar, memakai `blend_mix` ke warna bayangan ungu kebiruan (0,06/0,05/0,11)
  dengan kekuatan 0,55 — bukan `blend_mul`, karena di proyek ini yang terbukti tampil
  di renderer Mobile hanya blend_add dan blend_mix. Adaptasi teknik Screen Space
  Shadows dari forum Godot (kreditnya di LICENSES.txt).
- Tombol baru di panel grafis: **Contact shadow: Nyala/Mati (tes FPS)** —
  kalau HP terasa berat, matikan dulu yang ini.
- `tools/test_contact_shadows.gd` (gerbang baru) — render A/B (efek nyala vs
  mati) memastikan bayangan jatuh di sisi BERLAWANAN dari matahari, bukan
  terbalik. Ini menangkap bug flip NDC Y dan salah baca reverse-Z.

Belum diuji di HP — sandbox tidak bisa menjalankan Godot.

### 2026-10-03 — perbaikan bayangan karakter, sinar matahari shaft panjang, pohon raksasa

Lanjutan umpan balik di HP: "bayangan karakter ada banyak amat", minta god rays
mengikuti shader [Screen Space God Rays](https://godotshaders.com/shader/screen-space-god-rays-godot-4-3/),
dan minta pohon raksasa realistis di tengah world.

- `god_rays/contact_shadows.gdshader` — **batas dekat `min_distance = 8 m`**.
  Kamera orbit default 4 m dan bisa dizoom sampai 0,35 m, jadi karakter (dan tanah
  tepat di kakinya) ada di zona dekat. Tanpa batas ini setiap piksel badan
  karakter menembakkan sinar ke arah matahari yang kena BADANNYA SENDIRI —
  hasilnya karakter penuh tambalan bayangan kecil, dan bayangan tanahnya jadi
  dobel (shadow map + contact shadow). Keduanya sudah dikerjakan shadow map, jadi
  lapisan ini sekarang sengaja hanya mengisi jarak menengah (8–55 m).
- `god_rays/sun_rays.gdshader` — shaft radial lembut, 40 sampel (dulu 16) dan
  cakram matahari diperbesar (`light_scale 0,55`, `light_feather 0,45`) supaya
  sinar memanjang ke seluruh langit, bukan cuma bercak di dekat matahari. Parameternya
  diberi nama sama seperti shader yang diminta (Ray Length / Light Source Scale /
  Light Source Feather).
  **Tidak memakai SubViewport**: shader aslinya me-render scene KEDUA kali hanya
  untuk occlusion mask dan memakai ~200 sampel (penulisnya sendiri memperingatkan
  soal FPS). Proyek ini punya 400 ribu segitiga rumput, jadi mask dibaca dari
  buffer kedalaman yang SUDAH ada dan cukup 40 sampel.
- `world/world_tree.gd` (BARU) — pohon raksasa 28 m di (0, tanah, −95): batang
  runcing + 5 cabang bercabang + 11 bola tajuk, semua dalam SATU ArrayMesh dengan
  warna per vertex (gaya `scenery.gd`), ± 3 ribu segitiga. Dibangun **prosedural
  karena di repo tidak ada aset model pohon sama sekali** — `project/assets` hanya
  berisi dua GLB mannequin (UAL1/UAL2) dan dua tekstur nature. Kalau nanti ada GLB
  pohon, node ini bisa diganti tanpa mengubah apa pun yang lain.
- `tools/test_world_tree.gd` (gerbang baru) — pohon harus menempel tanah, berdiri
  di darat, > 20 m, < 20 ribu segitiga, dan tajuknya harus terbaca HIJAU serta
  tidak hitam pekat (winding segitiga terbalik = cahaya datang dari dalam = pohon
  hitam, dan itu gampang terjadi saat menulis bola tangan pertama).

### 2026-10-03 — sinar matahari diganti total dengan god rays gaya pend00

Umpan balik: "jelek ah itu ray nya hapus total trus ganti pake ini" +
tautan [God Rays shader — inspired by pend00 (Godot 4.5)](https://godotshaders.com/shader/god-rays-shader-inspired-by-pend00-godot-4-5/).

- `god_rays/sun_rays.gd` + `sun_rays.gdshader` **DIHAPUS TOTAL** (bukan disimpan di
  samping) — dua versi depth-march sebelumnya sudah ditolak dua kali.
- `god_rays/light_shafts.gd` + `light_shafts.gdshader` (BARU) — shader
  `canvas_item` pend00 (CC0) yang bekerja di ColorRect layar penuh: value noise
  dua lapisan membentuk sinar, lalu dicampur dengan layar pakai mode "screen".
  Tidak ada tekstur noise, tidak ada render scene kedua, tidak ada ray marching —
  jadi murah di HP.
- Dipasang sebagai **anak pertama CanvasLayer HUD**, jadi digambar paling bawah:
  tombol dan panel tetap di atas sinar, dan sinar tidak ikut ter-zoom kamera.
- Setiap frame `light_shafts.gd` menghitung posisi matahari di layar
  (`camera.unproject_position`) lalu mengisi dua parameter shader:
  - `ray_origin` (vec2) — pusat pantulan sinar. Aslinya hanya `position` (satu
    skalar = geser vertikal), jadi sinar selalu memantul dari tengah layar;
    diubah menjadi vec2 supaya sinar bisa memantul TEPAT dari matahari.
  - `ray_angle` — arah sinar, dihitung dari arah matahari ke pusat layar.
- Efek memudar saat matahari keluar layar dan hilang total saat matahari ada di
  belakang kamera, jadi tidak ada "sinar nyangkut" saat menoleh.
- Tombol panel grafis tetap ada: **Sinar matahari: Nyala/Mati (tes FPS)**.
- `tools/test_light_shafts.gd` (gerbang baru, menggantikan `test_sun_rays.gd`) —
  render A/B: sinar harus menambah cahaya, harus hilang saat dimatikan, harus
  hilang saat matahari di belakang kamera, dan tombol grafis harus mengubah efek.
  Pemeriksaan "sinar menembus geometri" DIHAPUS karena efek ini memang overlay
  layar penuh di atas scene, bukan depth-march lagi.
- `warmup_samples.gd` memanaskan shader baru; `render_world.gd` /
  `render_mannequin.gd` menyembunyikannya biar gambar world tidak kena sinar.
- Kredit pend00 + CC0 tercatat di `project/licenses/LICENSES.txt`.

Belum diuji di HP — sandbox tidak bisa menjalankan Godot.

### 2026-10-03 — sinar matahari, contact shadow, dan pohon raksasa DIHAPUS

Umpan balik: "ternyata jelek ih hapus total ajh lah trus yang ray tracing awal aku
request juga hapus ajh trus lanjut pohon hilangin ajh".

- `god_rays/light_shafts.gd` + `.gdshader` (sinar pend00) **DIHAPUS** — efeknya
  sendiri tidak disukai.
- `god_rays/contact_shadows.gd` + `.gdshader` **DIHAPUS** — ini efek "kesan ray
  tracing" yang diminta di cicilan 8. Seluruh folder `god_rays/` kini kosong dan
  hilang dari repo.
- `world/world_tree.gd` **DIHAPUS** — pohon raksasa prosedural 31 m di
  (0, tanah, −95) beserta pemasangannya di `main.gd`. Pulau sekarang kembali
  bersih: hanya tanah, rumput, pemandangan, air, dan karakter.
- `performance_panel.gd` — dua tombol hilang (**Sinar matahari** dan **Contact
  shadow**), kunci config `sun_rays` dan `contact_shadow` juga dibuang. Sisa
  tombol: Resolusi 3D, Rumput, Bayangan, Batas FPS.
- `loading/warmup_samples.gd` — STAGES 14 → 13 (tahap pemanasan sinar + contact
  shadow dibuang), jadi layar muat sedikit lebih cepat.
- Gerbang CI yang dihapus: `test_light_shafts.gd`, `test_contact_shadows.gd`,
  `test_world_tree.gd`, beserta langkah render, artefak screenshot, daftar berkas
  wajib, dan grep ringkasan commit di `apk.yml`.
- `render_world.gd` / `render_mannequin.gd` — `_shafts` dikeluarkan dari daftar
  efek yang disembunyikan.
- Catatan riwayat + kredit pend00 (CC0) tetap ada di `LICENSES.txt`, ditandai
  "sudah dihapus".

Yang TIDAK berubah: pulau 1 km berbentuk bergelombang, palet gelap senja, rumput
padat, partikel ungu, langit senja + glow, dan bayangan shadow map biasa.

Belum diuji di HP — sandbox tidak bisa menjalankan Godot.

### 2026-10-03 — langit jadi MALAM: bintang, bulan bercratere, cahaya bulan

Permintaan: "sky nya juga buat malam hari tapi visual indah bintang langin dan bulan".

- `environment/dusk_sky.gdshader` (nama berkas dibiarkan, isinya sudah malam):
  - **Bintang** — grid hash di koordinat bola langit (azimut/polar), satu
    bintang per sel di posisi acak yang tetap, kelip pelan ±15%. Tanpa tekstur.
    Koordinat hash dibungkus `mod(...,128)` karena `sin()` float 32-bit kehilangan
    presisi di angka ratusan dan hasilnya belang. Bintang memudar dekat ufuk
    supaya tidak "menempel" di garis pantai.
  - **Bulan purnama** — 2,6° jari-jari (± 24 px di render CI), warnanya HDR 1,8
    supaya mekar di glow engine (2,4 memotong jadi putih dan kawahnya hilang). Ada **6 kawah analitik** di basis lokal
    piringan bulan (posisi dari hash, jadi bentuknya tetap tapi tidak seperti
    lingkaran susun), **limb darkening** di tepi, dan **dua lapis halo**
    (cincin rapat ±1 jari-jari + lembar lebar ±30°).
  - Gradien malam: zenith (0,022/0,038/0,095) → ufuk (0,085/0,110/0,190). Sengaja
    gelap tapi bukan hitam pekat (tonemap filmik menekan nilai kecil sekali).
- `environment/dusk_environment.gd`: arah cahaya utama pindah ke **bulan** —
  `SUN_DIRECTION` jadi arah bulan (awalnya 40° di atas ufuk barat daya, sisi laut,
  lalu diturunkan ke 15° — lihat entri di bawah), jadi jalur kilau bulan membentang di air sampai ke pemain. Cahaya
  bulan biru dingin (0,68/0,76/0,95), ambient biru tua (0,24/0,32/0,55), kabut biru gelap (0,09/0,13/0,24), saturasi turun ke 1,02 (cahaya
  bulan memang memucat warna), glow intensity 0,30 dengan ambang HDR 1,15 supaya
  yang mekar hanya bulan + bintang terang.
- `world/water.gdshader`: kilau air jadi **jalur bulan** biru dingin, warna laut
  digelapkan (tosca senja → biru malam) supaya tidak menyengat di bawah langit
  gelap.
- `tools/test_dusk.gd` — gerbang baru: bulan terang di tengah layar, bulan hilang
  saat dimatikan, bintang terlihat, halo terlihat, zenith biru TUA (bukan biru
  senja terang), arah cahaya = arah bulan, dan tanah tetap terbaca (hijau > 0,10,
  bukan hitam).

Catatan aset: **tidak ada model pohon atau batu di repo ini** — lihat HANDOVER.

Belum diuji di HP — sandbox tidak bisa menjalankan Godot.

### 2026-10-03 — malam direvisi: awan dibuang, bintang dikurangi, bulan diturunkan, jalan bersih dari rumput

Permintaan: "terlalu rame banget itu awannya ilangin trus bintang nya buat lebih
sedikit jangan terlalu rame dan juga bulannya jangan diatas soalnya aku gk mungkin
trus trusan arah kamera di atas dan juga optimalisasi fps dan juga jalanan malah
ketutupun rumput pas di deketin".

- `environment/dusk_sky.gdshader`:
  - **Awan dibuang total** — bukan cuma dimatikan. Fungsi `fbm4`/`fbm2`/
    `value_noise` dan semua uniform `cloud_*` dihapus, bersama gerbang awan di
    `tools/test_dusk.gd`. Ini juga hemat FPS terbesar: awan dulu memakai ± 24-36
    pemanggilan `sin()` per piksel di layar penuh, dan itu yang membuat langit
    berat di HP.
  - **Bintang dikurangi** — `star_amount` 0,045 → 0,016 (± 4,4x lebih sedikit,
    dari ± 1.600 bintang terlihat menjadi ± 360) dan `star_density` 42 → 34.
  - **Hemat bintang**: empat pemanggilan `wrapped_hash` per piksel jadi **satu**
    — offset dan kecerahan bintang diturunkan dari hash yang sama
    (`fract(roll*73.17)`, `fract(roll*191.31)`, `fract(roll*331.79)`).
  - **Hemat lain**: bintang hanya dihitung kalau `elevation > 0.03` (setengah
    bawah layar = tanah/pantai langsung dilewati), kawah bulan hanya dihitung
    kalau sudut < 1,7x jari-jari bulan (menghemat 6 hash + `smoothstep`), dan
    cincin halo rapat hanya kalau sudut < 0,25 rad.
- `environment/dusk_environment.gd`: bulan diturunkan dari **40° ke 15°** di atas
  ufuk barat daya (`SUN_DIRECTION` → `(-0.914, 0.259, -0.311)`) supaya terlihat
  dari posisi bermain biasa tanpa mengarahkan kamera ke atas terus. Karena cos
  sudut bulan jauh lebih kecil, energi cahaya bulan dinaikkan 0,35 → 0,50 dan
  ambient 0,35 → 0,40 supaya tanah tetap terbaca (gerbang tanah dilonggarkan ke
  hijau > 0,10).
- `world/water.gdshader`: default `sun_direction` disamakan dengan arah bulan baru.
- `world/field.gd`: **jalan tanah tidak lagi ditutupi rumput**. `can_grow()` kini
  menolak klumpe rumput yang jaraknya ke garis tengah jalan < 5 m
  (`GRASS_PATH_MARGIN`), memakai `path_centre()` yang memakai rumus yang sama
  persis dengan shader tanah (karena jalan itu digambar shader, bukan mesh).
  Berlaku untuk rumput dekat maupun rumput jauh, karena keduanya memakai
  `can_grow()`.

Belum diuji di HP — sandbox tidak bisa menjalankan Godot.

### 2026-10-03 — langit malam diperbaiki (bintang oval + pola garis) dan HUD gaya game aksi

Permintaan: "masih kurang realistis langit nya kalo bulan dah cakep banget tapi
bintang dan langit kayak png ada garis garis gitu dan juga rapih kan ui kamu bisa
tiru ui attack,lompat dan lain lain kayak genshin atau wuwa".

- `environment/dusk_sky.gdshader`:
  - **Penyebab bintang kayak garis/oval ditemukan**: sel grid azimut selebar 2x
    sel polar DALAM SUDUT (azimut keliling = 2π, polar = π), tapi jarak ke pusat
    bintang tidak dikoreksi. Akibatnya setiap bintang jadi oval horizontal —
    persis "garis garis" yang terlihat. Diperbaiki dengan
    `length((local - offset) * vec2(2.0, 1.0))`.
  - **Pola grid hilang**: versi hemat (1 hash untuk offset + kecerahan) membuat
    posisi bintang terkurung di satu kurva `fract(roll*K)`. Kembali ke 3 hash
    terpisah. Tiga `sin()` per piksel masih jauh lebih murah daripada awan yang
    sudah dihapus (24-36 `sin()`).
  - **Bintang tidak lagi seperti sprite PNG**: distribusi magnitudo
    (`pow(bright, 2.6)` — kebanyakan redup, sedikit terang), bintang terang lebih
    besar, inti tajam + halo lembut, dan sedikit variasi warna (biru dingin →
    kuning hangat).
  - **Banding gradasi hilang**: dither ± setengah level 8-bit ditambahkan, jadi
    gradasi biru tua tidak lagi pecah jadi garis-garis horizontal.
- HUD (`main.gd`, `ui/rune_button.gd`, `ui/speed_button.gd`) jadi gaya game aksi:
  - tombol aksi pakai **ikon besar di tengah + label kecil di bawah** (bukan
    huruf besar menempati tombol). Ikon baru: `ui/sword.svg` (serang),
    `ui/jump.svg` (lompat), `ui/crouch.svg` (jongkok); ikon lama flame/speed/
    settings tetap dipakai.
  - gambar tombol dirapikan: cakram gelap lembut + kilau atas + cincin tepi
    tipis + cincin dalam detail + sapuan cooldown.
  - tata letak tombol kanan bawah disusun melengkung mengelilingi tombol serang
    (serang besar di ujung, tembak/jongkok/lari di sekitarnya) dan tidak saling
    tumpang tindih.
  - **bug sekalian diperbaiki**: tombol LARI (`SpeedButton`) tidak pernah
    diberi `custom_minimum_size`, jadi `_place()` menghitung diameter 0 dan
    tombolnya berukuran nol piksel — tidak bisa ditekan sama sekali.
  - petunjuk debug di banner kiri atas ("geser kiri = jalan/lari · ...")
    dihapus; banner cukup menampilkan nama klip + progres.

Belum diuji di HP — sandbox tidak bisa menjalankan Godot.

### 2026-10-03 — gerak diperbaiki (lambat & kaki meluncur), dash Melee_Hook, posisi UI, kaki tidak tenggelam

Permintaan: "animasi jalan tolong diperbaikin lagi gk sesuai jalan dan jaraknya
jadi masa jalan gerak nya lambat banget ... ada animasi jalan kanan kiri depan
belakang ,miring juga ada ... rapihin posisi ui ... masa attack pojok bawah
susah nekennya ... animasi melee hook ... bisa di modif buat dash ... fix juga
kaki jalan atau jongkok kaki nya masih ada yang tenggelam sedikit ketanah".

- **Kenapa jalan terasa lambat** (`player.gd`): kecepatan badan dulu DIPOTONG ikut
  kecepatan alami klip (`natural x skala` dengan skala maksimal 1,5). Kalau klip
  jalannya lambat, badan ikut lambat — dan karena gait dipilih dari kecepatan
  badan, band gait tidak pernah naik ke lari (lingkaran setan yang membuat analog
  terasa lemas). Sekarang badan bergerak secepat yang diminta analog, dan
  kecepatan main animasi yang menyesuaikan.
- **Band gait tidak lagi angka tebak** (`player.gd`): batas band dihitung dari
  kecepatan alami tiap klip yang diukur dari tulang kaki (batas atas = 1,5x
  kecepatan alaminya). Kecepatan tertinggi pun ikut klip lari tercepat
  (`max_speed()`), jadi badan tidak pernah lebih cepat dari yang bisa ditandingi
  klip tercepat — kaki tidak meluncur.
- **Dash** (`player.gd` + `main.gd`): tombol DASH baru memakai klip
  **Melee_Hook** (0,47 s, gerakannya memang seperti dash game aksi): dorongan
  12 m/s selama 0,22 s, cooldown 0,85 s dengan sapuan busur di tombol, tidak bisa
  di udara. Combo serang jadi dua pukulan (Punch_Jab -> Punch_Cross) karena
  Melee_Hook dipindah ke dash.
- **Jalan mundur** memakai klip berbeda (`Walk_Formal_Loop`) supaya arah gerak
  terbaca; deteksi "mundur" dibaca dari arah analog relatif hadapan kamera
  (`orbit.camera_forward()`).
- **Animasi strafe kiri/kanan/depan/belakang TIDAK ADA di UAL** — sudah diperiksa
  langsung dari isi GLB: UAL1 (43 klip) dan UAL2 (43 klip) sama-sama tidak punya
  klip strafe (tidak ada `Walk_Left/Right/Back`). Yang paling mendekati: jalan
  depan (`Walk/Jog/Sprint`), jalan formal (dipakai untuk mundur), `Sword_Dash`,
  `Shield_Dash`, dan `Slide_*`.
- **Kaki tidak tenggelam lagi** (`anim_metrics.gd`): tiga sebab diperbaiki —
  (1) tulang `foot_l/foot_r` ada di ATAS sol, jadi ditambah margin sol 3,5 cm;
  (2) sampling klip gait dinaikkan 30 -> 60 Hz supaya titik terendah sesungguhnya
  tidak terlewat di antara sampel; (3) batas koreksi naik dinaikkan 25 -> 45 cm
  (klip jongkok menurunkan kaki jauh lebih dari 25 cm).
- **Posisi UI** (`main.gd`): tombol SERANG tidak lagi nempel pojok — berhenti
  ±130 px dari tepi kanan/bawah (zona nyaman ibu jari), tombol lain disebar
  melengkung di sekitarnya dengan jarak lega supaya tidak salah pencet. Ikon
  baru `ui/dash.svg`.

Belum diuji di HP — sandbox tidak bisa menjalankan Godot.

### 2026-10-03 — dunia dikecilkan ke 500 × 500 m, transisi animasi tanpa jeda

Permintaan: "ukuran map ubah jadi 500m x 500m ajh" dan "perbaikin setiap animasi
pergantian ke animasi lain jangan ada jeda ... biar gk ada patah patahan per
animasi" (setelah dash kadang ada jeda sebelum kaki lanjut ke animasi lari).

- **Dunia 500 m × 500 m** (`world/field.gd` + semua yang bergantung padanya):
  setiap PANJANG ditulis setengahnya supaya bentuk dunianya tetap sama — radius
  pulau 292-380 → 146-190 m, lekukan pantai 20/10 → 10/5 m, tanjakan pantai
  70 → 35 m, jarak rumput dari pantai 5 → 2,5 m. Ikut mengecil: jarak pandang
  kabut 200-1400 → 100-700 m, laut 4200 → 2100 m, cincin bukit 520-1250 →
  260-625 m, pulau batu di laut, batas rumput pantai pemain 14 → 7 m, zoom
  kamera terjauh 620 → 310 m, dan panjang gelombang jalan tanah (biar jalannya
  masih berliku ± 2 kali, bukan lurus).
- **Perbukitan disetel ulang**: panjang gelombang diperpendek 1,5× dan amplitudo
  diturunkan 4,2 → 3,4 m. Ini penting — kalau bukit dibuat lebih curam, garis
  pantainya melewati batas kemiringan `MAX_SLOPE` dan rumput TIDAK tumbuh di
  puncak bukit (pulau jadi botak bergaris). Diukur: amplitudo lama dengan
  gelombang pendek = 3,8% daratan terlalu curam; sekarang 2,1% (sama seperti
  dunia 1 km dulu).
- **Jalan tanah**: lekukan 42 → 24 m, panjang gelombang 524 → 300 m. Fasa
  lekukan kedua digeser supaya jalan tetap melintas TEPAT di titik muncul
  pemain (0, 7) — kalau bergeser, pemain muncul di tengah rumput atau di luar
  jalan, dan tes `test_island` gagal.
- **Transisi animasi tanpa jeda** (`mannequin.gd` + `player.gd`), tiga sebab:
  1. serah-terima aksi → lokomosi dulu 0,24 s cross-fade; sekarang **0,08 s**.
     Selama cross-fade badan masih memakai pose akhir klip aksi — itu "jeda"-nya.
  2. klip aksi kini boleh dibatasi durasinya (`play_action(name, max_time)`).
     Dash memakainya: klip Melee_Hook 0,47 s tapi dorongannya cuma 0,22 s, jadi
     dulu kakinya berdiam 0,25 s di sisa pose pukulan sebelum kembali lari.
  3. gait tidak lagi berhenti dilacak saat menyerang/dash. Dulu `_apply_animation`
     langsung `return` ketika `is_busy()`, sehingga saat dash selesai badan
     memakai gait SEBELUM dash (mis. jalan pelan) selama satu frame selagi masih
     12 m/s — kaki meluncur sesaat, terbaca patah. Skala kecepatan lokomosi
     terakhir juga diingat supaya tidak ada frame dengan kecepatan main 1×.
- **Catatan jujur soal animasi dash dari Mixamo**: akun/layanan Mixamo butuh
  login dan jaringan sandbox ini tertutup (mixamo.com pun tidak bisa dihubungi),
  jadi aku TIDAK bisa mengunduh klip dash dari sana. Aku periksa isi UAL1 + UAL2
  (43 + 43 klip) dan ukur gerak pelvis tiap klip: satu-satunya klip dengan
  dorongan MAJU yang cepat adalah `Melee_Hook` (jongkok + luncur maju 0,33 m
  dalam 0,27 s). `NinjaJump_Start` melompat ke ATAS, `Shield_Dash` melompat,
  `Slide_Start` justru menjatuhkan badan ke tanah — tidak cocok untuk dash.
  Kalau kamu bisa mengunduh sendiri dari Mixamo (FBX, Without Skin, 30 fps),
  taruh di `project/assets/combat/` dan bilang aku — aku sambungkan ke katalog,
  mannequin, dan tombol DASH.

Belum diuji di HP — sandbox tidak bisa menjalankan Godot.

### 2026-10-03 — dash dari Mixamo (dash.fbx) + occlusion culling biar ringan

Dua permintaan: memakai teknik culling/LOD bawaan Godot biar game ringan, dan
memasang animasi dash dari Mixamo (`Female Locomotion Pose.fbx` yang diunggah ke
repo).

- **Occlusion culling dinyalakan** (`project.godot`:
  `occlusion_culling/use_occlusion_culling=true`). Dokumentasi Godot menyebut
  backend **Mobile** justru yang paling diuntungkan karena tidak punya depth
  prepass — dan project ini memang memakai renderer Mobile.
- **Penutup occlusion** (`world/scenery.gd`): kedua cincin bukit jauh diberi
  kotak `BoxOccluder3D` (24 per cincin). Bukit dipilih karena besar, statis, dan
  berdiri minimal 70 m dari pemain — kalau ukurannya meleset sedikit pun tidak
  mungkin menyembunyikan apa pun di dekat pemain. Tinggi kotak memakai puncak
  **terendah** di sepanjang lebarnya (bukan tertinggi): kotak tidak boleh lebih
  tinggi dari puncak bukit, kalau tidak rumput di balik bukit ikut hilang
  padahal sebenarnya terlihat. Sudah diuji angka: 0 dari 1518 pemeriksaan kotak
  melebihi mesh bukit.
- **Klip dash dari Mixamo** (`assets/combat/dash.fbx`, 16 MB): nama tulang
  `mixamorig:*` **diterjemahkan** ke tulang UAL mannequin saat pustakanya
  digabung (`mannequin.gd` → `_merge_dash_library`, 55 tulang + jari). Tanpa
  terjemahan ini klip Mixamo tidak akan pernah terlihat: kerangka Mixamo dan
  kerangka UAL berbeda nama. Animasi diberi nama tetap `dash/Dash`, jadi kode
  tidak bergantung pada nama stack di dalam berkas Mixamo.
- **PENTING — berkas itu isinya POSE, bukan animasi.** Semua 327 kurva animasi
  di dalamnya bernilai KONSTAN (tidak ada satu pun yang berubah), jadi
  karakternya akan diam dalam satu pose selama dash. Kalau mau kakinya gerak,
  unduh **animasinya**: di Mixamo buka tab *Animations*, cari "dash", pilih
  salah satu, baru tekan DOWNLOAD (FBX → *Without Skin*, 30 fps), lalu timpa
  `project/assets/combat/dash.fbx`. Tidak perlu ubah kode — nama klip tetap sama.
- Yang dari saran AI **sudah terpasang sebelumnya**: frustum culling (otomatis di
  Godot), dan rumput memakai `MultiMeshInstance3D` (helai rapat + kartu LOD
  jauh). Yang **tidak berlaku** di project ini: `VisibleOnScreenNotifier2D`
  (itu 2D, game ini 3D) dan Auto Mesh LOD (medan/rumput dibuat prosedural, bukan
  model impor).

### 2026-10-03 — dash pakai animasi lari (satu langkah diperlambat), bloom, dunia 100 m, dedaunan Quaternius kembali

Empat permintaan sekaligus: hapus FBX dash Mixamo, tambah bloom, map jadi
100 m × 100 m, dan carikan aset Quaternius Stylized Nature MegaKit.

- **FBX dash Mixamo DIHAPUS.** Alasannya dua: isinya pose statis (semua 327 kurva
  animasinya bernilai konstan — sudah diperiksa), dan sekarang ada cara yang jauh
  lebih murah.
- **Dash = animasi LARI, satu langkah diperlambat.** Badan tetap didorong
  12 m/s, tapi kecepatan main animasi turun ke 0,8× selama 0,40 s — pas satu
  langkah siklus Sprint_Loop (0,335 s / 0,8 ≈ 0,42 s). Jadi kaki melakukan satu
  langkah besar yang pelan sambil badan melesat, menapak lagi tepat saat
  dorongan habis, lalu kecepatan main kembali normal. **Klipnya tidak diganti
  sama sekali** (tetap gait lari), jadi tidak ada jeda/perpindahan animasi —
  sekalian memperbaiki keluhan "patah-patah" dari ronde sebelumnya.
- **Bloom diperbesar**: `glow_intensity` 0,30 → 0,50 dan `glow_bloom` 0,08 →
  0,18. Ambang (1,15) dan blend mode (SOFTLIGHT) sengaja TIDAK diubah: bulan
  harus tetap berwarna, bukan gepeng putih, dan langit malam tidak ikut mekar.
- **Dunia 100 m × 100 m.** Semua panjang ditulis sepersepuluh: radius pulau
  146-190 → 29-38 m, lekukan pantai 10/5 → 2/1 m, tanjakan pantai 35 → 7 m,
  kabut 100-700 → 20-140 m, laut 2100 → 420 m, cincin bukit 260-625 → 52-125 m,
  bukit batu di laut ikut mendekat, batas pantai pemain 7 → 1,4 m, zoom kamera
  terjauh 310 → 62 m, chunk tanah 128 → 32 m. Dua angka TIDAK ikut mengecil
  karena harus menjaga kemiringan: dataran 6 → 1,8 m dan tanjakan pantai
  35 → 7 m (1,8/7 = 0,26, masih di bawah batas rumput 0,30 — kalau lebih curam,
  pantainya botak), serta amplitudo bukit 3,4 → 0,7 m.
- **Aset Quaternius DITEMUKAN dan DIPASANG.** Yang kamu lupa itu ada di repo
  lamamu: **`KyokoApp/Unity` → `Assets/WorldSrc/`** (11 model glTF: pohon, pinus,
  semak, pakis, bunga, batu + teksturnya, CC0). Dulu sempat ada di project ini
  lalu dihapus; sekarang kembali di `project/assets/nature/models/` dan
  disebarkan oleh `world/forest.gd` — 16 pohon, 26 semak, 18 batu, 44
  pakis/bunga, semuanya `MultiMeshInstance3D` (satu panggilan gambar per model),
  tanpa collision. Skala pohon diturunkan (model aslinya 7-9 m; di pulau 100 m
  itu terbaca seperti menara).

Belum diuji di HP — sandbox tidak bisa menjalankan Godot.

## Ronde 18 — pulau 300 m, kolam berpintu, pulau terbang, air bergelombang, jejak dash

- **Bukit tajam tiga segitiga DIHAPUS.** Permintaan: *"hapus itu pemandangan di
  depan apaan dah kayak bantuk gunung tajam sama gelombang"*. Seluruh
  `_build_hills()`/`_add_ridge()`/`_build_occluders()` beserta konstanta
  `HILL_*`/`FAR_*` dibuang dari `world/scenery.gd`.
- **Gantinya: PULAU TERBANG yang terbaca 2D tapi terasa 3D.** Enam bongkahan
  batu rendah-poli (`_floater_mesh()`: cakram rumput + kerucut batu yang
  meruncing ke satu titik) melayang 150-290 m dari pusat, tinggi 18-44 m.
  Bentuk pipih + warna rata bikin terbaca seperti ilustrasi; miring
  (`rotation.z`), berbayang, dan mengapung naik-turun (`FLOAT_BOB` 1,6 m,
  periode 7 s) bikin tetap terasa 3D. Semuanya di luar garis pantai, tanpa
  collision.
- **Air diganti total** memakai shader **"Simple Water"** (dairycultist,
  godotshaders.com, CC0) yang diminta: tiga gelombang sinus berjalan
  (vertex), normal dari **turunan analitik per piksel** (fragment) supaya riak
  tetap terlihat walau sel mesh air selebar 7 m, transparansi menurut
  kedalaman layar (`DEPTH_TEXTURE` + `INV_PROJECTION_MATRIX`) supaya air cetek
  tembus pandang, `METALLIC`/`ROUGHNESS` untuk pantulan langit+bulan, dan kilau
  bulan mengikuti riak. Laut ikut diperhalus: sel 24 → 128 (33 ribu segitiga).
- **Kolam besar di tengah dengan pintu + air CETek** (`world/pond.gd`, baru):
  mangkuk ber-dasar datar — dasar rata sampai 16 m dari pusat (tinggi 3,4 m),
  lalu dinding naik LURUS sampai 36 m tempat dataran (5 m) mengambil alih.
  Permukaan air 4,3 m → **dalam 0,9 m** (dasar kolam terlihat), garis air tepat
  di r = 27,3 m sehingga bidang airnya 27 m (kolam 54 m lebar). Di tengah
  berdiri **pintu ala Suzume no Tojimari** (bingkai, ambang, dua daun sedikit
  terbuka, celah cahaya emissif yang mekar) plus **pantulan tiruan** di bawah
  air — salinan terbalik yang dimampatkan, karena renderer Mobile tidak punya
  SSR. Ramp-nya sengaja LINEAR (bukan smoothstep): lekukan smoothstep membuat
  grid tanah 4 m tidak bisa mengikutinya (selisih 0,17 m → 0,027 m dengan
  linear), dan perbukitan dimatikan total di dalam kolam supaya garis airnya
  bulat bersih, bukan berlekuk-lekuk.
- **Efek dash = JEJAK + BLOOM, bukan afterimage.** Permintaan: *"kalo pas lari
  nari bakal ada efek ny di character seperti blur/glow ... bkan hanya setelah
  gambar doank"* dan *"jangan polos polos banget"*. Bekas pose beku
  (`speed/afterimage_trail.gd` + shader-nya) **DIHAPUS** dan diganti
  `speed/speed_trail.gd`: pita aditif 22 ruas yang mengikuti jejak posisi
  karakter — lebar dan hampir putih di dekat karakter, menyempit dan memudar ke
  belakang, selalu tegak lurus arah pandang kamera. Ditambah pancaran bloom di
  pinggir siluet karakter (`skin_shell.gdshader`: uniform `bloom` baru yang
  nilainya sengaja melewati ambang glow 1,15), menyala 1,0 saat dash dan 0,25
  saat boost biasa, memudar pelan sesudahnya.
- **Dunia 300 m × 300 m.** Semua panjang ×3 dari versi 100 m: `SIZE` 300,
  radius pulau 87-114 m, lekukan pantai 9/4,5 m, tanjakan pantai 30 m, dataran
  5 m, dasar laut -8 m, chunk 96 m (sel tetap 4 m), jalan ± 14,4 m dengan
  lebar 2,5 m. Ikut naik: batas pantai pemain 1,4 → 3 m, zoom kamera terjauh
  62 → 190 m, laut 420 → 900 m, kabut 20-140 → 45-420 m (harus berakhir JAUH di
  belakang pulau terbang supaya bentuknya terlihat utuh), pulau batu di laut
  ×3.
- **Titik spawn pindah** dari (0, 7) — yang kini tepat di tengah kolam — ke
  (-26, 16): pinggir barat daya kolam, daratan kering dan rata. `forest.gd`
  memakai titik yang sama dan sekarang juga menolak area kolam lewat
  `can_grow()`.

## Ronde 19 — danau bener-bener cetek: pintu DI ATAS air + jalan di atas air + riak

Permintaan pemain atas lingkaran tengah ronde 18: *"airnya itu gk dalem bener
bener pendek"*, *"pintunya harus ada di tengah dan di ATAS air danau"*, dan
*"efek air nya berasa kalo kita jalan di atas nya"*.

- **Airnya jadi danau cetek, bukan kolam 0,9 m.** `BASIN_DEPTH` 1,6 → 1,15 m
  jadi dasar kolam 3,85 m; dengan permukaan air tetap 4,3 m dalamnya **0,45 m**
  — lutut orang dewasa. Dasar kolam jelas terlihat lewat air (alpha kedalaman
  `mix(0,30, 1,0, 0,45/2,6)` = 0,42). Karena garis air ikut turun ke
  r = 23,8 m, `POND_RADIUS` 27 → 23,5 m (danau 47 m lebar) supaya bidang air
  tetap tidak menjorok ke daratan kering.
- **Pintunya berdiri DI ATAS air.** `pond.gd` menambah **pulau batu kecil** di
  tengah: kerucut pendek (`CylinderMesh`, puncak rata r = 2,8 m setinggi
  4,8 m, lereng turun sampai menyentuh garis air di r = 5,2 m — lereng 23%,
  bisa didaki). Pintunya pindah dari dasar kolam ke puncak batu itu, jadi
  kakinya 0,5 m di atas permukaan air dan tidak tenggelam lagi.
- **Permukaan air BISA DIAKI.** Pijakannya collider terrain itu sendiri:
  `field.gd _build_chunk()` menaikkan setiap sel yang jatuh di dalam danau
  (`Field.is_water`) ke `Field.POND_LEVEL` lalu memakai mesh itu sebagai collider
  chunk tersebut. Pemain benar-benar berjalan DI ATAS air (bukan menyelam ke
  dasar kolam) — kakinya menapak tepat di garis air, loncat dan mendarat jalan
  seperti biasa. Sel yang menyeberangi tepi jadi tanjakan halus, jadi masuk/keluar
  danau tidak ada langkah tegas.
- **Catatan perbaikan**: rancangan awal memakai cakram trimesh DATAR terpisah
  setinggi air (`WaterBody` di `pond.gd`). Itu DIBUANG setelah render-b gagal:
  bidang nol-ketebalan menyangkut badan pemain — `is_on_floor()` true tapi
  `velocity.y > 0`, animasi terkunci di klip lompat dan pemain berhenti di
  tempat. Pijakan yang sama dengan daratan (collider terrain) tidak punya masalah
  itu.
- **Riak setiap langkah terasa.** `world/water_ripple.gd` + `water_ripple.gdshader`
  (baru): pool 8 cincin aditif (satu quad masing-masing, tanpa tekstur, tanpa
  bayangan) yang lahir di titik kontak kaki, melebar 1,2–2,4 m dan meredam
  dalam 1 detik. Kekuatannya mengikuti keras langkah (jalan pelan kecil, lari
  besar, mendarat paling besar) dan posisinya dikunci ke garis air. Dipanggil
  `footsteps.gd` setiap kali kaki menapak air; kalau tidak ada yang berjalan di
  air semua cincin tidur (0 panggilan gambar).
- **Suara ikut basah.** `footsteps.gd` memakai permukaan baru `"water"` di dalam
  danau (puncak batu tetap `"stone"`); air tidak punya bank suara sendiri jadi
  dipakai sampel tanah sebagai langkah basah.
- `player.gd spawn()` ikut: kalau muncul di dalam danau, pijakannya permukaan
  air, bukan dasar kolam.
- Pantulan tiruan pintu ikut menyesuaikan: air sekarang cuma 0,45 m, jadi
  faktor penampasannya dihitung dari tinggi pintu di atas garis air
  (squash 0,098) supaya pantulannya tetap muat di antara dasar kolam dan
  permukaan air.
- Gerbang: `test_scenery.gd` (`_test_pond()` menuntut dalam < 0,7 m, pintu di
  atas air, seluruh bidang air ada di dalam kolam; `_test_ripple()` baru),
  `test_audio.gd` (titik tengah danau = "water", puncak batu = "stone").
- **Koreksi gate gerak** (`37113303786`): tes pijakan gagal karena kaki
  pemain terkunci di `POND_LEVEL` saat di daratan. Loop collider keliru memakai
  `is_inside()` (cek pulau), sehingga vertex daratan pada chunk sekitar danau
  ikut diratakan ke 4,3 m. Kini hanya `is_water()` yang menaikkan vertex di
  dalam `POND_RADIUS`. Pemeriksaan lokal lulus; run `37124361906` hijau 7/7 (gate,
  render-a/b/c, package).

Belum diuji di HP — sandbox tidak bisa menjalankan Godot.

## Ronde 20 — padang 100 m bergulir, Mira, dan layar interaksi pop-art

Permintaan terbaru membatalkan lake/door dan efek berjalan di atas air dari ronde 18–19.

- **Dunia kembali 100 × 100 m.** `Field.SIZE` kembali ke 100 m dengan pulau
  bertepi berlekuk. Bukit di pedalaman memakai beberapa frekuensi gelombang
  (relief sampel sekitar 1,9 m di area tengah), melandai ke pantai, dan berbagi
  satu fungsi tinggi untuk mesh, collider, rumput, serta pemain. Grid collider
  dirapatkan ke sel 2 m agar bukit tetap halus.
- **Danau, pintu danau, serta umpan balik khusus air dihapus.** Sistem
  `pond.gd`, riak langkah (`water_ripple.gd` dan shader-nya), cekungan, dan
  pijakan air sudah tidak dipakai. Laut luar tetap ada; langkah kini hanya
  memakai permukaan rumput, pasir, atau batu.
- **NPC Mira ditambahkan.** Pose diam utamanya berbeda dari pemain
  (`Idle_FoldArms_Loop`), lalu ia kadang berjalan beberapa meter dengan
  `Walk_Formal_Loop`. Area sekitar titik muncul dan rumah Mira dibiarkan kosong
  dari dedaunan.
- **Interaksi dan menu bergaya Persona 4.** Tombol bicara muncul saat dekat;
  transisi modal menggeser layar pilihan, menampilkan potret 3D Mira di kiri,
  dan menu aktivitas di kanan. Aktivitas yang belum tersedia menampilkan
  **COMING SOON**; `E`/`Esc` dan tombol kembali menutup layar, lalu kontrol
  permainan dipulihkan.
- Regresi diperbarui untuk ukuran dan relief pulau, surface langkah, serta
  interaksi/wander NPC (`tools/test_npc.gd` dan gerbang CI baru).

Validasi statis lokal: `gdlint project tools`, `python3 tools/check_scripts.py .`,
dan `git diff --check` lulus. Godot 4.5.2 CI run **37126825496** hijau **7/7**:
compile, seluruh tes headless (termasuk NPC), tiga render regresi, dan packaging.

## Ronde 21 — Mira berjalan lurus + menu bersudut dengan karakter bergeser

- **Arah jalan Mira diperbaiki.** Ia kini memakai `Walk_Loop` (bukan `Walk_Formal_Loop`, yang dipakai pemain untuk berjalan mundur), menghadap sasaran dulu sambil berputar di tempat, baru mulai melangkah. Ini mencegah animasi jalan tampak menyamping/miring.
- **UI interaksi mengikuti referensi gambar.** Kartu dua kolom diganti halaman asimetris: panel hitam bertepi diagonal di kiri, pilihan tersusun vertikal, aksen merah/emas, dan area terang di kanan.
- **Mira bergeser ke sisi kanan saat menu masuk.** Potret 3D bergerak dari tengah ke samping seiring panel menu dan footer masuk; saat ditutup, gerakannya kembali dengan transisi halus. Pilihan yang belum tersedia tetap menampilkan **COMING SOON**.
- Tes NPC kini memeriksa klip jalan depan, keselarasan arah badan dengan sasaran, dan animasi geser potret.

Validasi statis lokal: `gdlint project tools`, `python3 tools/check_scripts.py .`, dan
`git diff --check` lulus. Godot 4.5.2 CI run **37128597905** hijau **7/7**,
termasuk tes compile, wander/arah NPC, UI interaksi, render regresi, dan packaging.

## Ronde 22 — dunia terlihat di menu interaksi, kamera fokus ke Mira

Koreksi pengguna: layar harus benar-benar penuh, bidang putih di sisi kanan
harus hilang agar dunia permainan tetap terlihat, dan karakter diperbesar di
area kanan. Panel/menu kiri yang sebelumnya disetujui dipertahankan.

- **Menu memenuhi viewport tanpa margin.** Latar kertas dan panggung `SubViewport`
  dihapus. Bidang dunia sekarang tetap terlihat di belakang UI dengan dimmer
  gelap transparan; panel diagonal kiri dan pilihan vertikal tetap seperti
  rancangan yang disetujui.
- **Karakter berasal dari dunia aktif.** Saat interaksi dimulai, kamera berputar
  ke sisi yang menempatkan Mira di kanan pemain, mendekat, dan menggeser titik
  fokus ke arah percakapan. Ini juga menghindari panggung kosong yang sebelumnya
  tampak seperti bidang krem/putih.
- **Kamera dipulihkan saat menu ditutup.** Yaw, pitch, jarak, dan titik fokus
  awal disimpan lalu dianimasikan kembali bersamaan dengan transisi keluar.
- Tes NPC diperluas untuk memeriksa halaman tanpa margin, dimmer yang transparan,
  kamera zoom/komposisi, dan pemulihan state kamera; pilihan yang belum tersedia
  tetap menampilkan **COMING SOON**.

`gdlint project tools`, `python3 tools/check_scripts.py .`, dan
`git diff --check` lulus. Sandbox ini tidak menyediakan Godot runtime; uji
headless/render dilakukan oleh workflow CI.

## Ronde 23 — Gameplay, Survival tanpa batas, pedang, dan tata letak HUD

- Opsi pertama dialog Mira sekarang **Gameplay**. Selector mode beranimasi
  menempatkan **Survival** sebagai pilihan pertama yang dapat dimainkan; mode
  berikutnya tetap diberi label **COMING SOON**.
- Dunia Survival berupa bidang datar tanpa batas pulau. Zombie muncul berkala
  (maksimal lima zombie hidup bersamaan) dan memakai klip idle, jalan, serang,
  reaksi kena pukul, serta mati dari animasi UAL yang tersedia.
- Serangan memakai `Sword.glb` Quaternius CC0 yang ditemukan di sumber GitHub,
  terpasang pada tangan kanan. Tebasan A/B/C bervariasi per input dan tidak
  otomatis menjadi kombo; lapisan animasi upper-body membiarkan langkah kaki
  tetap mengikuti gerak pemain.
- Editor HUD dapat mengubah ukuran dan posisi tombol Serang, Tembak, Lompat,
  Jongkok, Lari, serta Dash. Pengaturan disimpan di perangkat; saat editor aktif,
  tombol gameplay tetap terlihat sebagai pratinjau tetapi tidak bisa dipicu.
- Ditambah tes Survival, selector mode, editor HUD, dan render Mobile Vulkan yang
  menyimpan screenshot selector serta gameplay untuk pemeriksaan CI.

Validasi statis lokal lulus: `gdlint project tools`, parse seluruh GDScript,
`tools/check_scripts.py`, katalog animasi, tes chunk, bundle lisensi, parse YAML
workflow, dan `git diff --check`. Godot runtime tidak tersedia di sandbox; CI
render/build belum dijalankan, jadi tampilan dan runtime belum dinyatakan lolos.
