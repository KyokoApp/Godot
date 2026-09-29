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

## Koreksi screenshot rumput terbaru

Screenshot menunjukkan sisi daun hitam dan 32 FPS. V2: fragment normal view-space
world-up untuk cahaya dua sisi, AO akar dikurangi; lebar helai 8,5 cm, 24×24 rumpun
per tile (+44%). Turun 3→2 tris/helai sehingga budget 86.400 tris, bukan 90.000.
Tes Vulkan mengukur cahaya depan/belakang dan mereproduksi perbedaan shader lama.
HUD `rumput halus v2`. Jangan menjanjikan FPS tanpa tes perangkat.

## Padang lebat v3 (terbaru)

User ingin tanah tak terlihat di antara rumput (screenshot v2: 36 FPS). Near grid40
+4 helai/rumpun (~3,7× density v2), lapisan pendek opaque mengikuti lereng.
Far grid20 subset gridnear; fade detail8–11m, rumputdasar16–23m. Budget20.800rumpun,
112k tris; jangan klaim FPS naik. Tes cakupan near>=95% sampel + Vulkan tetap wajib.
HUD `padang lebat v3`; tunggu screenshot/FPS sebelum menambah fitur lain.

## Terbaru: soft light + outline + identitas launcher

User meminta sedikit lebih gelap, outline tipis, ikon anime, gambar loading,
dan penjelasan compile shaders. Ambient0,57/sun0,98; mannequin outline 6mm.
Shader dirender bersama mannequin pada tes Vulkan rumput, tes rig tetap jalan.
Art loading/ikon AI orisinal setelah penelusuran Pinterest; sumber di CREDITS.
APK version code2 diperlukan untuk art/ikon launcher, PCK visual tetap kompatibel
launcher1. Keystore tidak berubah. Tidak ada progress compile shader buatan.

## Ikon pengguna sudah tersedia lewat GitHub

File root `547d844ffaca3a9b862a3c20e929770d.jpg` diupload pada commit eea852f,
sudah dibaca dan digunakan untuk ikon 512/192/adaptive432. APK code4/name0.4.2-user-icon.
Loading art dan gameplay tidak diubah. Kredit sumber/izin belum terverifikasi
tercatat di docs/CREDITS.md. Keystore tetap; jangan merge main.

## Skin jubah api biru (permintaan terbaru)

Mannequin diberi outfit prosedural (flame_robe.gd + blue_flame_cloth.gdshader).
Rig tetap; mesh sumber disembunyikan hanya jika outfit berhasil. Torso/lengan/hood
mengikuti posisi tulang, skirt64partikel Verlet 3iterasi + kaki/lantai collision.
Toon pastel opaque dengan polaapi hem/cuff, bukan fluida. Buka ulang launcher
untuk konten, ikon/loading tetap. Tunggu uji clipping/gerak/FPS HP; jangan merge main.

## PERMINTAAN TERBARU: hapus jubah, investigasi FPS

Jubah DIBATALKAN pengguna. Mannequin asli + outline kembali; file robe/solver/test
robe dihapus. Panel kanan atas membandingkan render75/100%, rumput, bayangan,
cap60/bebas; default75%, bayanganmati, rumputnyala, cap60. Pengaturan tersimpan.
Frameavg/P95/drawcalls hanya indikator, bukan GPU timing. Tombol dikecualikan dari
input kamera. Perlu tipe HP/Hz + uji A/B lokasi sama. Jangan janjikan 60 FPS dari CI.

## Terbaru: pet api astral + attack

Permintaan pengguna: pet melayang sejajar bahu, terpisah dari karakter, gradasi
ungu/biru + outline; attack api kecil fisik dan ledakan bulat besar berupa api.
fire_pet/projectile/burst/visual + spirit_fire shader implementasi prosedural.
Cap3peluru/2ledakan, cooldown0,85, TTL4s/1s. Aimreticlekamera, sphere sweepworld.
Tidak ada damage/enemy/fluidfire. Jubah tetap dihapus. Wajib tes FPS HP; jangan
merge main. HUD pet api astral, distribusi PCK kompatibel launcher.

## Pet dikoreksi berdasarkan archive (terbaru)

Pengguna menolak bentuk pet baru dan meminta cek project lama. Archive fire_spirit
ternyata spirit api kecil tanpa mata: core terang + shell aditif noise, halo,5embers.
Core/shellshader sekarang disalin utuh ke src/game/legacy_spirit; visualcontroller
porttyped. Anchor terbaru tetap terpisah dari bahu; OmniLight lama tidak dibawa.
Attack/ledakan belum dipindah dari archive. HUD spirit api lama, uji shaderVulkan
wajib karena transparansi/noise berbeda. Tunggu screenshot sebelum revisi lain.

## Combat VFX v2 (2026-09-29)
- User rejected prior projectile/burst, not just pet: replace orb beads/lobes
  with archived core/shell velocity trail and dual-shell fire volume.
- `attack_fx/`: shared resource factory, GDQuest MIT billboard shader (noise
  erosion), exact archived shockwave. Runtime-generated noise and masks only;
  no third-party demo artwork. MIT notice exported; `test_pack` verifies it.
- Gameplay/aim/swept collision unchanged; expired projectiles stop collisions
  and emissions, hide meshes, then retain particles 0.7s before freeing.
- Budget: 26 particles/projectile, 50/impact, max 3 shots/2 bursts. Impact TTL
  1.9s, 2 shell draws hidden by 0.9s, one shadowless flash hidden at 0.28s.
  No new glow/post-processing, no pet/grass/lighting/icon changes.
- Added isolated Mobile Vulkan `test_fire_render.gd` + screenshot artifact;
  lifecycle tests include normal-aligned shockwave, tail retirement and budgets.
- Verify on phone: fire while moving/turning, near ground and cliff impacts,
  fast repeat attacks, disappearing sparks, readability on grass, mean/P95 FPS.
  CI shader success/pixel tests are NOT visual approval or a 60FPS guarantee.

## HUD cleanup + simultaneous move/attack (2026-09-29)
- User approved VFX v2; do not alter combat appearance in this UI milestone.
- Removed debug label/instructions/crosshair. Settings hidden by default behind
  original 60px rune top-right. Existing graphics.cfg options preserved.
- Original flame SVG, round 128px attack, cooldown arc, press feedback. UI uses
  RuneButton (Button subclass, no native mouse GUI handling) with independent
  raw ScreenTouch finger ownership, release-anywhere/cancel/focus/resize reset,
  and explicit rejection of emulated mouse events to avoid double attacks.
- Drawer blocks movement/camera, hides attack; icon/outside tap closes it.
  No world pause. Invisible exclusions no longer reserve camera touch regions.
- `test_hud.gd`: viewport input dispatch, move+attack both press orders, third
  finger orbit, unrelated release, cancellation, emulation duplicate rejection,
  focus reset and drawer open/close; actual Mobile Vulkan + HUD screenshots.

## Gameplay audio milestone (2026-09-29)
User explicitly prioritizes sound before dummy/enemies. Keep approved UI/VFX.
`audio/world_audio.gd`: 16 pooled 3D voices, camera listener, inverse distance,
24m footsteps / 65m shot / 140m explosion, distance low-pass and world-mask
occlusion every .12s, smoothed -10dB/1400Hz obstruction, WorldSFX limiter.
Own scene-root voices preserve explosion tails beyond burst lifetime; loops
track pet/projectile and terminate when source disappears/projectile finishes.
`audio/footsteps.gd`: actual movement + floor gate, two contacts per animated
cycle, 120ms retrigger guard, small landing accent, side alternation. Road/coast
use designed dirt blend; steep/raised rock uses stone; other land grass.
Kenney CC0 recordings (4 per bank) + original archived procedural fire samples.
No new HUD, music or indoor reverb. Phone speaker/headphone listening still
required; CI validates routing and relative levels, not subjective realism.

## Pet flame correction — both visuals AND sound
User clarified via choice that both aspects felt unlike fire. Pet-only changes:
- New original `legacy_spirit/pet_flame.gdshader` on one 0.58x0.78m facing card;
  three tapered tongues, upward contour erosion, hot cyan core, movement lean.
  Opaque orb removed; halo reduced, 5 rising embers retained. Shoulder gap same.
- 8s crossfaded CC0 AntumDeluge crackling loop, distinct from projectile loop,
  -22dB/18m range vs previous -32dB/28m. Source hash + license exported.
- Do not alter approved projectile/impact shaders, audio or clean HUD.
- New render tests front/side/time; audio test checks pet-specific loop/level;
  pack boot test loads it. Pixel/mixer tests do not constitute visual/listening
  approval: ask user to compare still pet and moving pet on phone.

## Approved pet + very thin outline / smoother rolling dirt road
User LOVES current flame appearance: preserve silhouette/palette/motion/audio.
Only added internal ~0.55-render-pixel indigo contour, same single pass.
Road: terrain shader draws continuous analytic dirt mask (no grid-triangle edge),
retains solid dirt/no textures, original winding centerline. Perpendicular width
approximation shared by CPU grading, grass exclusion, rock clearance and steps.
Added gentle 1.1*(1-cos(z/28)) elevation on existing broad road profile; maximum
slope <.11 and curvature <.0025/m tested, existing mesh/collision interpolation
still authoritative. No added geometry beyond existing 80k triangles.
Tests: terrain shader/material colors, centerline/curvature/slope, grass bounds,
pet outline budget, real Mobile Vulkan road color render and pet regressions.

## Night scene milestone
User declined color-reducer for now; requested beautiful night, sparse stars,
small moon. `environment/night_environment.gd` is a shared static preset used
by main and renderer test. `night_sky.gdshader` is original procedural art,
no external textures, TIME, dynamic sky rebakes or additional world lights.
Small 0.0055rad moon radius at (-.31,.24,-.92), faint halo/crater marks;
sparse seeded stars, low horizon fade. Camera-facing sky directions are world-stable.
Ambient COLOR .38 / blue .48,.57,.78 preserves navigation; directional moon
energy .48, aligned to sky moon; existing shadows/graphics.cfg still work.
`test_night.gd` real Vulkan: moon on/off pixel area, stars on/off sparse area,
blue night tone, moonlight alignment and ground readability; saves screenshots.
User approval of brightness still requires HP check. Approved pet/audio/road
and clean UI remain untouched; no new color grading/post-process filter.

## World dressing + grass distance LOD + thin haze
User requested ACTUAL former trees/bushes/rocks/path, thin fog, camera/occlusion
culling, and whole-world grass appearance without full dense geometry.
Nature source found in Unity/archive build_mode/objects/nature (Quaternius CC0),
not procedural substitutes. 11 glTF/bin originals + <=512px textures, ~3.3MB.
No build-mode UI/buildings restored. Stone path model flattened vertically and
slope-aligned over existing dirt centerline; 24m render batches, 72m visibility.
Central footstep surface updated to stone; shoulders remain dirt.
NatureField: seeded 40m cells, 49 resident max, one built/frame, 6 tree +12 detail
candidates/cell. Small fern/flower authoring scales corrected. Native imported
mesh LOD and type-per-cell MultiMeshes; trees110m/details65m. Simple solid trunk/
rock colliders stay with cells; shrub/flower non-solid. No foliage shadows.
Grass: approved near system untouched; DistantGrass child adds 49x32m cells,
12x12 crossed cards/tile (4 tris/clump), 14–23m grow-in /65–90m shrink-out.
Max extra28,224 tris; terrain-only grass pattern beyond that, masked off dirt,
coast/cliff; no actual far blades beyond90m. Parent drives far streaming so the
existing grass toggle stops both, and toggles terrain cover uniform too.
Viewport occlusion enabled/restored on exit. Occluder patches y=min of ALL
source5m-grid vertices in each20m patch minus.5m: inside terrain, no false valley
bridges. <=5000 triangles. Transparent foliage is NOT an occluder. Frustum bounds
are per tile/type, not one island-wide MultiMesh. Conservative occlusion may miss
some hidden objects; real-device cost/benefit and pop-in still need measurement.
Night depth fog32–230m strength.48, sky_affect0; not volumetric, near pet unchanged.
New test_world_details headless+Vulkan verifies sources/textures, deterministic
safe placement, tile budgets/teleport cleanup, occluder containment, haze and PCK.
