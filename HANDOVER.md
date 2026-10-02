# STATUS TERBARU — prioritas dari pengguna

- Terbaru (2026-10-01): dunia dirombak jadi **padang rumput 100 m × 100 m**
  (`world/field.gd` + `grass_field.gd` + `world/boundary_fence.gd`). Pulau 1 km,
  laut, sungai, arena, jalan batu dan aset nature model DIHAPUS dari repo.
- Karakter hanya **mannequin UAL**. Miku, Kanna, skin switcher, kartu karakter,
  portrait, retarget, hair spring, minimap dan combat library dihapus.
- Animasi: SATU AnimationPlayer memuat UAL1 (43 klip) + pustaka `ual2`
  (43 klip) = 85 nama di `animation/catalog.gd` (label + keterangan Indonesia,
  flag loop/once/hold/gait). Semua klip bisa diputar dari panel "ANIMASI (85)".
- Perbaikan animasi: mode loop per klip dari katalog, kecepatan klip dicocokkan
  dengan langkah hasil ukur `animation/anim_metrics.gd` (anti kaki meluncur),
  offset tanah per klip untuk pose rendah, transisi cross-fade, dan aksi sekali
  jalan memakai timer `_action_left` (bukan sinyal) supaya deterministik.
- Gerbang tanpa engine baru: `python3 tools/check_animation_catalog.py` — 85 klip
  wajib ada, sumber/flag benar, dan langkah tiap klip gait diukur ulang.
- Perubahan sesi ini tetap di branch sesi (sekarang `arena/01a0f97d-godot`);
  integrasi ke main tidak dilakukan dari sesi ini.
- Perubahan gameplay dikirim lewat PCK yang kompatibel launcher 1; jangan minta
  install APK lagi kalau launcher 3A sudah terpasang.
- Keystore debug permanen: jangan regenerate.
- 2026-10-02 — **CI HIJAU PENUH** (run 36940453606, commit `3b29806`): 37 langkah
  lulus, termasuk ekspor PCK + APK dan rilis `A-Sekai build-3b29806`
  (`asekai.apk`, `content.pck`, potongan `.bin`, `content-v2.json`).
  Yang menunggu sekarang hanya tes di HP, bukan fitur baru.
- Dua bug besar yang membuat semuanya tampak mati sudah dibereskan:
  1. **Importer glTF membuang akhiran `_Loop`** dari nama animasi di
     AnimationPlayer (`Walk_Loop` -> `Walk`), sedangkan katalog memanggil nama
     berkas. Akibatnya `animation.play("Idle_Loop")` gagal, `_ready()` mannequin
     berhenti dan SELURUH HUD (joystick, tombol) tidak pernah terbangun.
     `Catalog.play_name()` sekarang membuang sufiks itu; nama runtime diuji
     `tools/test_clips.gd` + aturan baru di `check_animation_catalog.py`
     (nama runtime wajib unik, klip loop tanpa sufiks terpantau).
  2. **Joystick tidak pernah tersambung ke pemain** (`_player.joystick` tidak
     pernah di-set di `main.gd`), jadi sentuhan tidak menggerakkan karakter.
- 2026-10-02 (sore) — **AKAR "layar abu polos" DI HP DITEMUKAN**: paket utama
  APK hanya memuat `launcher.gdc` + ikon. `backdrop.gd`, `chunk_policy.gd`, dan
  `chunk_store.gd` TIDAK ikut, padahal `launcher.gd` mem-preload ketiganya →
  skrip launcher gagal dimuat → UI tidak pernah digambar → yang tampak di HP
  hanya warna latar bawaan Godot (abu rata, tanpa teks, app tetap hidup).
  Penyebab: filter ekspor `scenes` hanya mengikuti dependensi *scene*, bukan
  dependensi *skrip*. Diperbaiki dengan `export_files` + `include_filter` untuk
  seluruh berkas launcher, `main.tscn` membawa tekstur ilustrasi sebagai
  ext_resource, dan `backdrop.gd` tidak lagi mem-preload tekstur (preload yang
  gagal mematikan seluruh launcher).
  Karena CI selama ini menjalankan tes dari **folder proyek** (semua berkas
  sumber masih ada), bug ini tidak pernah terdeteksi. Sekarang ada dua gerbang
  baru: `Audit isi APK` (memastikan berkas launcher/bootstrap benar-benar ada,
  menerima bentuk `.gd` maupun `.gdc`+`.remap`) dan `tools/test_apk_launcher.gd`
  yang mem-boot launcher dari **isi APK** (`--path build/apk-audit/assets`).
  Catatan: ilustrasi `loading.jpg` masih belum ikut ke APK, jadi launcher memakai
  latar polos; fungsional, tinggal kosmetik.
- PERINGATAN: memperbaiki paket APK **butuh install APK baru**; update konten
  (PCK) tidak bisa memperbaiki launcher yang rusak.
- Tes yang diperketat: `_check()` mencetak `::error::` supaya CI memberi alasan;
  step tes memakai `tee` + langkah "Ringkasan kegagalan" menampilkan 24 baris
  terakhir tiap log sebagai anotasi.


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
Shader + streaming ada di src/game/grass*; sumber/lisensi di
`project/licenses/LICENSES.txt`.
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
Art loading/ikon AI orisinal setelah penelusuran Pinterest; sumber dicatat di
bundel LICENSES.
APK version code2 diperlukan untuk art/ikon launcher, PCK visual tetap kompatibel
launcher1. Keystore tidak berubah. Tidak ada progress compile shader buatan.

## Ikon pengguna sudah tersedia lewat GitHub

File root `547d844ffaca3a9b862a3c20e929770d.jpg` diupload pada commit eea852f,
sudah dibaca dan digunakan untuk ikon 512/192/adaptive432. APK code4/name0.4.2-user-icon.
Loading art dan gameplay tidak diubah. Kredit sumber/izin belum terverifikasi
tercatat di `project/licenses/LICENSES.txt`. Keystore tetap; arahan integrasi
main pada milestone lama ini bersifat historis.

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
- First integrated render run: HUD assertions printed OK but engine failed to
  exit within180s on Mesa. Add explicit scene teardown before quit and simplify
  shared nature materials to vertex lighting / no specular or normal map, keeping
  original base textures/colors/alpha cutout. Do not bypass renderer gate.

## Shader/material warmup experiment
User approved trying precompile before rivers/lake work (now implemented below).
main._confirm_boot now optionally runs ShaderWarmup after two frames if this is
SceneTree.current_scene (normal launcher entry) or warmup_requested test flag.
Headless skips GPU work; existing isolated unit setups keep previous timing.
Production Vulkan test forces warmup and checks boot marker/lifecycle/skip.
CanvasLayer100 ALWAYS overrides disabled gameplay process mode; HUD hidden,
input ownership reset, audio streams paused/restored. Existing launcher loading
art reused dynamically if available; no dependency on it in standalone PCK.
18 real rendered stages via 320x180 own-world SubViewport; same current MSAA,
scale and shadows. Character/grass/combat first; nature afterward. Root scene
continues rendering below cover to warm actual viewport sky/terrain variants.
4 post-draw frames per stage; user skip +20s SOFT deadline between stages, not a
hard GPU watchdog. Native driver compile may block a frame beyond this limit.
Stages/elapsed/partial/skipped/draw-pipeline-counter delta logged and saved to
user://shader_warmup_last.json. No persistent skip flag; no shader cache deletion,
no claim cache can be shipped universally to different GPUs. Shadow/quality
changes can still compile new variants. Confirm perceived improvement on phone.


## Inland water milestone
WaterShape is the single deterministic watershed source for terrain carving,
mesh selection, vegetation/rock clearance and no-swimming shoreline checks.
Irregular harmonic lake centered(105,-50), axes54x38, level4.5; variable-width
sine-bend outlet descends smoothly to sea atz320, never crossing the old road.
Terrain lowered only, smooth22m bank shoulders; exact same triangulated collider.
Visual water tiles40m/2.5m grid, <=12000 triangles; no walkable water collider.
Ocean retains its plane but now uses same lightweight water shader, never SSR.
Shader adapted from marcelb/GodotSSRWater391b2f9 (MIT copied): two wave/normal
samplers, inverse projection reverse-Z, safe refraction, screen border fade,
bounded12-step/18m SSR under65m. Correct world-to-view normals; miss fallback;
no hardcoded camera near/far; unshaded final mix avoids double-lighting the screen.
Original periodic128px height/normal maps generated by tools/make_water_textures.py.
SSR is opt-in saved graphics.water_ssr, independent from resolution; default false.
Fake night sky/moon reflection remains when disabled/missing/offscreen. Transparent
objects aren't SSR sources; no promise desktop/mobile parity or phone60FPS.
Warmup18 stages with both water modes. test_water headless+actual Mobile Vulkan
asserts dry road, wet-zone exclusions, centerline flow and matching collider,
budgets, visible lake, transparent bottom, actual SSR difference, miss nonblack,
near/far invariance; screenshots artifact water-screenshots. Do not bypass gates.
Multiplayer explicitly deferred until user is happy with the world. No network work.


## Upper-body casting (UAL original)
Character adds native SkeletonModifier3D CastLayer under imported Skeleton3D.
Samples only ROTATION_3D tracks for spine_01 and descendants from original
Spell_Simple_Shoot; never root/pelvis/legs, translation or scale. Native modifier
influence fades .08s in/.14s out; 0.5s clip. Skeleton restores locomotion poses
following modifier processing. Existing AnimationPlayer + footsteps clock unchanged.
Pet.attack reserves one pending cast and cooldown0.85, emits cast_started to visual,
then releases existing projectile/audio/pulse after0.16s physics windup using current
pet/camera positions. No detached timer, rejected attacks don't restart animation.
Both clocks pause with gameplay/warmup; pending cast owned by pet, freed with game.
Unit tests check excluded bones, upper-body movement for idle/walk/run and return;
HUD multitouch + fire lifecycle tests updated to assert windup, movement, release.
Mobile render test compares actual skinned idle/run with casting and verifies
pose restoration/native modifier callback; artifacts casting-screenshots.
No target dummy/damage/multiplayer yet; one tested milestone at a time.


## Rights / credits work (historical first implementation; superseded)
User chose original work reserved, NOT MIT. The earlier version kept separate root
and exported notices, added an offline CreditsPanel and sync_credits.py parity check.
That UI and multi-file layout have since been removed; current design and bundle
validation are documented in the final “Consolidated notices” entry below. The
Miku/Kanna replies remain reported by the owner, not independently authenticated;
no general redistribution/commercial license was invented.


## Miku skin / party switch prototype (local, not engine-verified)
Runtime assets/characters/miku/miku.glb generated from root868295879255555982.vrm:
19,542,632 ->10,311,744 bytes; full42,674tris, 24base-color maps<=1024, 52bone mapping.
prepare_miku.py preserves mesh/skin/accessor bytes, metadata extras and author
thumbnail portrait. No VRM plugin, springbones, external art or MToon dependency.
SkinRetarget is LAST SkeletonModifier on hidden UAL skeleton, after CastLayer;
reads weighted final pose (not restored base), conjugates rest delta180Y like
old Kanna, keeps target lengths, scales hip bob only. 52 mappings include fingers.
Miku starts gameplay; standalone Character defaults mannequin for existing tests.
Switch caches one Miku node; hidden model stops retarget, player/pet/cooldown intact.
Party cards original design, author thumbnail + original mannequin vector portrait.
Raw finger support inherited RuneButton; camera excludes entire party control,
menu hides/reset-touches. Attack moved84px inward/68px up at1280x720, still128px.
Warmup19 includes Miku; test_cast_render now both skins; newtest_skin_switch plus
HUD/PCK assertions. test_miku_asset.py verifies byte-preserved geometry, textures,
rest correction and sampled idle/walk/jog/cast math. These are NOT engine proof.
Local download attempts from SourceForge and official object storage failed TLS35.
Historical note: the local-only restriction and root-VRM warning below were
superseded by later user authorization and successful engine validation (see the
following entries). Preserve model permission scope and source links.


## Kanna + publishing authorization (2026-09-29)
User explicitly authorized push/build for phone, superseding the prior local-only
restriction, and relayed an additional Kanna permission requiring account credit.
Preserve Animeit original metadata and Naxzed reported permission-account credit.
Kanna converted from archive blob070e5725, 194476tris/43materials, base-color1024.
52-bone Miku /50-bone Kanna share UAL driver, per-skin cached native retargets;
only selected skin visible/driver active. Third party card, warmup20 stages.
All engine gates must pass before claiming release ready or removing root VRM.

## Engine verification / root cleanup
Actions36562331346 (581f7ae) passed actual Godot4.5.2 import/compile, both rig
retarget/gesture tests, HUD multitouch/credits/switch, all three skin render/cast
and pose restoration. Root868295879255555982.vrm removed only AFTER these passed.
Generated runtime GLBs remain; original upload c95925e retained in git history.
test_miku_asset reads historical upload if root file absent. User expressly
authorized branch push/build; older local-only notes are historical, superseded.

Kanna portrait correction: VRM meta.texture43 points to body atlas source0,
not a portrait. Replaced wrong preview with offline orthographic render of
actual skinned bind-pose mesh/base textures (tools/render_character_portrait.py).
prepare_miku.py --skin kanna invokes renderer; requires numpy + Pillow. No new
runtime viewport or frame cost. Miku keeps its valid embedded author thumbnail.


## Motion flair (Miku hair + per-skin 3D footprints)
HairSpring native SkeletonModifier on Miku destination skeleton only. Actual
J_Sec_Hair1..8_07/_08 (16 joints; tips9 follow), local rest rotations plus bounded
angular spring chain. Head-world horizontal velocity/acceleration + signed turn
feed drive; 120Hz substeps capped.067s, angularlimit.11rad, damping9. Anchor hitch
>.12s/teleport>2.5m and skin switch reset history. No positional stretch. NOT a
full VRM spring-bone importer or body/world collision solver; extreme clips remain.
Cast render regression explicitly disables secondary motion to isolate its pose
restoration assertion; separate motion renderer checks live hair deformation.
FootFireTrail separate from unchanged audio contacts. Two ankle/toe bone poses,
terrain/body raymask1, sole rest-height threshold+hysteresis and per-foot.18s rate.
Actual horizontal travel/floor gates prevent startup fall/idle/air spam; wet guard.
Shared original shoe+5 volumetric tongue mesh, 16 preallocated stamps, 1.15s life,
per-stamp captured palette (Miku bluewhitepurple/Kanna gold/UAL violetcyan).
No billboarding, lights, shadows, physics actors, sounds or damage. Clear teleport.
Tests test_motion_flair + test_motion_flair_render, screenshot motion-flair-screenshots.
Warmup21 stages. Existing pet/attack/casting/updater remain unchanged; the
in-game notice viewer is handled in the final entry.

Contact follow-up: all-three-rig repeated-walk gate found Kanna's .035m stance
band too strict: its jog ankle is .135-.156m high versus .074m rest height,
before player floor offset. This is inherited retarget geometry, not a missing
bone or a timing-only issue. Kanna uses .11m tolerance; other rigs retain .035m.
All rigs additionally require actual mocap foot stance (.04m) and re-arm on swing
(.075m), with active-skin ankle/toe ground rays. No foot IK or existing animations
changed. Sole length scales from rig ankle-to-toe distance (20–34cm) and center
shifts toward toe, rather than centering the heel on ankle. Keep all-three repeated
contacts/idle/teleport gates; do not weaken their >=5-step check. Native diagnostic
annotations report min/max gaps, rest clearance, source swing and stamp count.


## HUD and isolated battle arena (latest)
Speed ×3 button, speed boost, afterimages, smoke and colored speed wash removed
as requested. Player remains at MOVE_SPEED 5m/s, standard locomotion. HUD cards
still name-left/portrait-right and white transparent. No hidden speed toggle.
BattleArena at (-145,140), ~84m across, unchanged cracked rocky ground and
thin grey-white perimeter aurora. ArenaFog owns four lightweight unlit shells:
two irregular boundary walls following ArenaShape.radius_at, from terrain-8m
through +62m; two enclosing domes cover sky beyond. No gameplay collision.
Fog opacity ramps spatially between 8m outside and 10m inside boundary, then
exponentially across time; outside it becomes invisible and has no global fog
setting changes. Exposed update_for_position for rendered transition tests;
warmup stage21 renders the new shader. Neither the sky nor ordinary island fog
is modified, world normal outside arena. Updater now uses incremental v2 (see below).
Native arena render checks exterior, partial edge, interior occlusion, and exit.


## Incremental updater v2 (launcher APK migration required)
- launcher.gd uses chunk_policy.gd/chunk_store.gd; legacy update_policy.gd remains
  for v1 compatibility tests. Old content.json/PCK still published unchanged.
- Content exported first, unencrypted PCK v2/v3 directory parsed by chunk_content.py.
  File-aligned blocks (large files >=64KiB, max1MiB blocks) hashed and published
  as SHA.bin in SAME immutable commit release. No chains or dependency on old releases.
- APK export scenes-only launcher; include bootstrap/base.pck + base.json. Same
  tested content export is embedded once; raw gameplay/assets must not be duplicated.
  Generated bootstrap ignored. version/code5, existing keystore preserved.
- Store stages whole packs in user://updates-v2; reads at most1MiB per frame while
  planning/assembling. Never mount chunks or load gameplay before choosing pack.
  SHA+size each chunk AND whole pack; atomic active.json with previous.json rollback.
  PENDING boot marker only for downloaded packs, main clears after warmup as before.
- Failed requests retain good cache blocks, retry recalculates plan. Partial current
  chunk discarded. Source corruption makes blocks missing, not blindly reused.
  Cleanup keeps active+previous packs, up to256MiB .bin cache; legacy data untouched.
- No runtime launcher updates via PCK. User must install APK once over old app.
  APK seed reused without network; subsequent updates fetch only missing blocks.
- Tests: Python synthetic PCK split/rebuild/stability; GDScript store corruption,
  retry and rollback; actual repeat export and script-only delta <=4MiB gate;
  APK ZIP stored seed, no duplicated assets. Cold boot APK/device remains unverified.


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


## Sinar bulan screen-space
Adaptasi metode radial scattering Qtan1 (CC0), bukan volumetric fog. Memakai
kedalaman layar reverse-Z, 16 sampel, tanpa render ulang seluruh dunia lewat
SubViewport. Warna biru pucat halus mengikuti arah bulan di sky. Otomatis mati
saat bulan di belakang/luar kamera atau pemain di dalam arena. Efek berada di
bawah HUD dan transparansi, tidak menerangi terrain/karakter. Objek transparan
atau di luar layar tidak ikut menghalangi sinar. Toggle tersimpan “Sinar bulan”
ada di Grafik untuk tes A/B HP; tidak menjamin FPS. Renderer target Mobile 4.5.2.

Moon rays included in shader warmup (24 stages); Vulkan regression tests also verify
opaque blocker, behind-camera/arena exclusion and graphics toggle persistence.

## Circular minimap
`ui/minimap.gd` + shader: cached 256² CPU cartography via existing Island sampled
surface heights, road mask and shared Water/Arena shapes; one texture, no viewport.
North is -Z. 125m radius, 176px at (24,24), center follows player at 10Hz; character
arrow and camera cone independent. Joystick excludes circular minimap touches.
Original visual treatment, no Genshin assets. HUD regression includes center/north,
layout and touch-exclusion assertions. No fullscreen map/teleport introduced.


## Consolidated notices and removal of in-game viewer (2026-10-01)
The user chose to remove the in-game “Kredit & lisensi” panel and keep one
consolidated notice file. `project/licenses/LICENSES.txt` now holds the original
rights notice, project credits/provenance, full third-party license texts, and
reported Miku/Kanna permission records with their conditions. The APK/PCK filter
continues to include this file. No third-party terms or permissions were removed;
metadata, source tools, tests, export checks and docs point to the bundle.
The offline CreditsPanel script and former separate notice files are removed.
Run `python3 tools/check_license_bundle.py` for the repository-side bundle gate;
Godot pack tests verify the bundle is present in the exported PCK. This consolidates
notices; it does not relicense third-party assets or grant broad redistribution
rights.
