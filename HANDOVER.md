# STATUS TERBARU — prioritas dari pengguna

- 2026-10-02 (sesi ini, cicilan 5) — **PALET SENJA: TANAH & RUMPUT GELAP TAPI
  TETAP TERBACA** (lanjutan "tanah dan rumput jadi gelap tapi tetap kelihatan,
  dan rumput satu warna dengan tanah"). HANYA warna.
  - `src/game/world/field.gd`: `GRASS_COLOR` 8fce63 → **3f6b34**,
    `GRASS_DARK` 6aa845 → **2d4f27** (± 45% lebih gelap), `SAND_COLOR` c9a873 →
    **9a8260** (± 25%). Dipilih supaya kanal hijau tanah tetap > 0,22 setelah
    dicahaya senja (batas gerbang `test_dusk`).
  - `src/game/grass.gdshader` + `src/game/world/grass_distance.gdshader`:
    `top_color`/`bottom_color` helai = warna tanah yang sama → rumput dan tanah
    SATU warna. Ujung tetap sedikit lebih terang dari akar supaya helai masih
    terbaca 3D.
  - `tools/test_dusk.gd`: warna uji diambil dari `Field.GRASS_COLOR` (dulu
    ditulis ulang `8fce63` di dalam tes, jadi menguji warna yang sudah tidak
    dipakai). Janji gerbang jadi "tanah GELAP pun masih terbaca".
  - `world/scenery.gd`: `DIRT_COLOR` (konstanta mati) ikut meredup.
  - Sisa antrian cicilan (JANGAN digabung): rumput rapat menutupi seluruh
    jangkauan kamera, partikel ungu, suasana senja + sinar cahaya, shader air.

- 2026-10-02 (sesi ini, cicilan 4) — **DUNIA JADI PULAU 1 KM × 1 KM, GARIS
  PANTAI BERGELOMBANG** (permintaan: "world nya 1km, pinggirannya jangan bulat
  atau kotak tapi kayak pulau gitu bergelombang"). Cicilan ini HANYA ukuran dunia
  + bentuk garis pantai. Yang DITUNDA (urutan yang disepakati pengguna, jangan
  digabung): palet gelap, rumput rapat satu warna dengan tanah, partikel ungu,
  suasana senja/sinar cahaya, shader air.
  - `src/game/world/field.gd` DITULIS ULANG: dunia 1000 × 1000 m (dulu 100 m).
    Satu fungsi tinggi `terrain_height()` (static, murni) dipakai mesh, collider,
    karakter, rumput, tapak api, dan langkah kaki — itulah syarat "pemain tidak
    mengambang/menembus".
  - Bentuk pulau: radius per sudut = noise rendah di sepanjang lingkaran +
    dua lekukan sinus (`COAST_WAVE` 20 m, `COAST_WAVE_B` 10 m). Terukur radius
    **285-368 m**, berubah **22%** antar arah (lingkaran sempurna = 0%), luas
    ± 0,35 km². Sengaja radial (bukan bentuk bebas) supaya `clamp_inside()` bisa
    memakai proyeksi radial dan selalu mengembalikan titik yang benar di darat.
  - Medan: dataran ± 6 m, tanjakan pantai 6 m / 70 m (± 8,5%), dasar laut -9 m,
    perbukitan ± 4 m yang melemah di dekat garis air.
  - Chunk streaming: chunk 128 m (32 × 32 sel 4 m), SATU per frame, radius 3 →
    49 kandidat, terukur ± 36 hidup. Grid chunk dipusatkan di (0,0)
    (`_chunk_key(x,z) = floori(x/CHUNK + 0.5)`) supaya jangkauan ± 448 m
    simetris — tanpa itu sisi barat hanya 384 m dan garis pantai bisa jatuh di
    luar chunk yang dimuat. Chunk yang seluruhnya di laut dilewati.
  - `ground.gdshader`: `edge_color`/`half_size`/`edge_begin` DIHAPUS, diganti
    pita pasir berbasis KETINGGIAN (`shore_low` 0,35 → `shore_high` 2,6 m):
    pasir mengikuti garis air yang berliku tanpa perlu tahu bentuk pulau. Jalan
    tanah: lebar 3 m, lekuk 55 m, fasa 0,37 supaya melintas di titik spawn.
  - `world/scenery.gd`: laut = satu bidang 4200 × 4200 m di y = -0,15
    mengelilingi SELURUH pulau. Bukit 520-780 m & 820-1250 m, tebing x = 513 m,
    pulau batu x = -760/-905 (semuanya di luar garis pantai). Motes sekarang
    di-offset `Field.terrain_height()` — dataran ± 6 m akan menenggelamkannya
    kalau y-nya tetap.
  - `orbit_camera.gd`: `MAX_DISTANCE` 8 → **620 m** (pemain harus bisa melihat
    pulau). `ARM_COLLISION_LIMIT` 30 m: `arm.collide_with_bodies` dimatikan di
    atas jarak itu, kalau tidak kamera terjepit di bukit pertama dan zoom jauh
    terasa rusak.
  - `environment/dusk_environment.gd`: kabut 60-420 → **200-1400 m**, dan
    `horizon_fade` air 380 → 1400 m. Bukit kaki langit kini 520-1250 m dari
    pemain; dengan kabut lama bukit itu lenyap seluruhnya.
  - **`world/boundary_fence.gd` DIHAPUS.** Batas dunia = garis pantai.
    `player.gd`: `BOUNDARY` 0,9 → `SHORE_MARGIN` 14 m, `_keep_inside()` memakai
    `Field.clamp_inside()` (proyeksi radial balik ke darat).
    `audio/footsteps.gd`: `EDGE_DIRT` 45 → `SHORE_HEIGHT` 2,6 m (tinggi tanah),
    sama dengan `shore_high` shader.
  - `main.gd`: preload `Fence` dan `add_child(Fence.new())` dibuang;
    `_field.player = _player` ditambah (tanpa ini chunk tidak pernah mengikuti
    pemain dan tanahnya berlubang di belakangnya).
  - Gerbang BARU `tools/test_island.gd` (7 janji) + satu langkah CI baru di
    `gate`. Gerbang lama diperbarui: `test_scenery.gd` (laut mengelilingi pulau,
    bukit/tebing/pulau batu diperiksa per-VERTEX dengan `Field.is_inside()`),
    `test_grass.gd` (titik ± 56/± 49,6 yang dulu "di luar pagar" sekarang di
    dalam pulau), `test_audio.gd` (titik pesisir dicari dari bentuk pulau),
    `render_world.gd` (lima sudut: pulau dari udara, pantai, jalan, laut).
  - Verifikasi: `gdparse` + `gdlint project tools` bersih, `check_scripts.py`
    bersih (72 berkas), dan seluruh angka gerbang disimulasikan ulang di Python
    (radius 285-368 m, luas 0,35 km², garis pantai tepat 0,000 m, 36 chunk hidup,
    selisih grid vs analitik 0,014 m). Godot TIDAK bisa dijalankan di sandbox.
  - Run `37010302393`: gerbang `gate` hampir hijau (compile, scenery, grass,
    movement, skin, clips, zoom semua lolos) — dua tes masih salah asumsi:
    `test_island` membandingkan titik dengan `is_equal_approx` (cos/sin ->
    atan2 beda ~4e-6 rad, dikali radius 150 m jadi ~3e-5 m: di atas batas 1e-5),
    dan `test_hud` mengukur ketinggian SEBELUM lari — pulau bergelombang jadi
    lari menurun memang mendarat lebih rendah. Keduanya diperbaiki jadi
    toleransi jarak 1 cm dan tinggi tepat sebelum lompat.
  - Dua bug yang HANYA ketahuan di CI (pelajaran untuk cicilan berikutnya):
    1. `var blend := t - floor(t)` — fungsi global `floor()` mengembalikan
       Varian, dan `:=` dari Varian adalah COMPILE ERROR di Godot 4.5 (persis
       pelajaran di kepala `tools/compile_check.gd`). Pakai `floorf()`.
    2. `arm.collide_with_bodies` TIDAK ADA di `SpringArm3D` — cara mematikan
       tabrakan SpringArm adalah `arm.collision_mask = 0`. Keduanya membuat
       gerbang `gate` gagal dan render ikut gagal.
  - Run `37011157491`: 7/7 pekerjaan HIJAU (4 menit 30 s push → selesai).
    `[island-test] gagal=0`, `[scenery-test] gagal=0`, `[world-render-test]
    HASIL: OK`, gate 104 s, render-c 209 s, render-a 189 s, render-b 175 s.
    Gambar render CI tersedia: world-pulau, world-pemandangan, world-pantai,
    world-jalan, world-laut.
  - BELUM diuji di HP (sandbox tidak bisa render Godot) — itulah pemeriksaan
    visual yang perlu dilakukan pengguna.

- 2026-10-02 (sesi ini, cicilan 2) — **KULIT MANNEQUIN: HITAM POLOS** (garis
  energi & percikan dibuang; lanjutan "hitam gelap + outline putih tipis").
  - `src/game/character/skin_shell.gdshader`: perhitungan `band`/`vein`/
    `sparkle` dan uniform `vein_speed` DIHAPUS. Sisa: gradasi sangat gelap
    kaki→kepala (`skin_dark` 0,010 → `skin_light` 0,050), satu bercak hash
    halus, dan rim abu tipis di pinggir siluet yang menguat saat lari/attacks
    (`pulse`/`charge`) TANPA gelombang berjalan — tubuh tetap polos.
  - Uniform `vein_color`/`vein_scale`/`vein_width` sengaja masih dideklarasikan
    supaya `set_light_cloth()` (mode grafis Ringan, dipanggil
    `performance_panel.gd`) tidak menyetel parameter yang tidak ada di shader.
  - `set_light_cloth()` di `mannequin.gd` tetap ada tapi sudah tidak mengubah
    tampilan kulit; mode Ringan kini hanya soal resolusi/bayangan/rumput.
  - Outline putih tipis (5 mm) tidak berubah. Belum diuji di HP.

- 2026-10-02 (sesi ini) — **BUILD CI DIPARALELKAN: 12 MENIT JADI 4 MENIT**
  (keluhan pengguna: "build di github lama banget dah kan update nya nyicil
  nyicil" — tiap perubahan kecil membayar build penuh).
  - Hasil ukur: run lama `36999636319` 11 menit 59 s (push → selesai), run baru
    `37002663347` 4 menit 6 s. Durasi pekerjaan: render-c 3,6 menit (bottleneck,
    render avatar), render-b 3,1, render-a 2,1, gate 1,8, package 1,1,
    ringkasan 0,3. Semua hijau.
  - Data run lama `36999636319`: total langkah 467 s, dan **302 s di antaranya
    render Mobile Vulkan software** (lavapipe, runner 2 core): avatar 67 s, HUD
    50 s, warmup 49 s, dunia 37 s, rumput 31 s, sinar 20 s, tapak 15 s, senja
    15 s, api 9 s, casting 9 s. Sisanya lint 32 s, apt 29 s, tes headless 34 s,
    ekspor APK/PCK 27 s.
  - `.github/workflows/apk.yml` dipecah jadi 6 pekerjaan paralel: **gate** (lint +
    compile + SEMUA tes headless), **render-a/b/c** (render dibagi berimbang
    ± 100 s masing-masing), **package** (PCK + APK + audit + rilis), **ringkasan**
    (komentar commit), **build** (gerbang agregat).
  - Aturan lama "compile lolos dulu, baru ekspor APK" DIPERTAHANKAN: `package`
    `needs: gate`. Render sengaja jalan bersamaan dengan gate supaya push kecil
    tidak menunggu dua kali.
  - Tidak ada gerbang yang dihapus: audit otomatis membandingkan 60 blok perintah
    lama vs baru (0 langkah hilang, 0 beda isi), YAML valid, 60/60 blok `run:`
    lolos `bash -n`.
  - Komentar commit (angka penting, pratinjau, log gagal) pindah ke pekerjaan
    `ringkasan` yang `if: always()` — dulu kalau tes gagal di tengah, angka
    diagnostik ikut hilang. Log tiap pekerjaan diunggah sebagai artefak `logs-*`;
    JPEG pratinjau dibuat di pekerjaan render (bukan di ringkasan) supaya
    ringkasan tidak perlu mengunduh Godot lagi.
  - Job `build` agregat mempertahankan nama status check lama (`apk / build`)
    untuk required check di Settings.

- 2026-10-02 (sesi ini, lanjutan) — **KULIT MANNEQUIN: HITAM GELAP + OUTLINE
  PUTIH TIPIS**. Hanya ganti warna; struktur kulit, mirror pose, denyut, dan
  gerbang tes (`tools/test_skin_shell.gd`) tidak berubah.
  - `src/game/character/skin_shell.gdshader`: `skin_dark` 0,150/0,195/0,300 →
    0,010 (nyaris hitam), `skin_light` 0,330/0,420/0,575 → 0,050 — gradasi
    gelap kaki→kepala tetap ada supaya bentuk badan masih terbaca. Garis energi
    `vein_color` dan rim `rim_color` jadi abu gelap, jadi tubuh tetap terbaca
    hitam dan tidak rata seperti plastik; rim sekarang benar-benar memakai
    `rim_color` (dulu uniform itu tidak terpakai sama sekali).
  - `src/game/character_outline.gdshader`: warna bawaan gelap → PUTIH, lebar
    bawaan 6 mm → 5 mm (tipis). Putih itu juga dipasang eksplisit di
    `src/game/mannequin.gd` (`_apply_material`) dan
    `src/game/character/skin_shell.gd` (`_make_outline`) supaya kedua jalur
    outline (mesh dalam + salinan kulit) tidak mungkin berbeda.
  - Belum diuji di HP; tidak ada tes yang mengunci warna lama.

- 2026-10-02 (sesi ini) — **KARAKTER: MANNEQUIN POLOS + KULIT BERANIMASI**,
  lalu **DUNIA: SENJA SEPERTI ILUSTRASI LAYAR MUAT**.
  - Permintaan pengguna: avatar FBX Aurelia dibuang SELURUHNYA ("jangan tersisa")
    karena terlalu sulit dianimasikan; kembali ke mannequin UAL, tetapi seluruh
    tubuhnya ditutup **kulit beranimasi** (mirip afterimage, tapi selalu menimpa)
    supaya tulang/badan mannequin polos tidak pernah terlihat; dan dunia dibuat
    semirip mungkin dengan `project/launcher/art/loading.jpg`.
  - **Kulit**: `src/game/character/skin_shell.gd` + `skin_shell.gdshader`.
    Setiap mesh mannequin disalin (`SkinMirror` + salinan bertipe sama), salinan
    digelembungkan 22 mm (`grow`), berdenyut mengikuti kecepatan badan
    (`PULSE_SPEED` 6,0), bergaris tepi tipis, dan posenya disalin pada sinyal
    `skeleton_updated` DITAMBAH sekali per frame (`_process`) — di headless
    sinyal itu tidak berbunyi; sebelum cadangan itu ada, kulit tertinggal
    0,43 m dan gerbang CI yang menangkapnya (`worst_pose_gap`).
  - **Dibuang tanpa sisa**: `aurelia_visual.gd`, `aurelia_materials.gd`,
    `humanoid_map.gd`, `retarget_modifier.gd`, `cloth_springs.gd`,
    `cloth_dynamics.gd`, `tools/test_aurelia.gd`, `tools/fbx_inspect.py`, folder
    `aurelia-debug/`; 17 berkas dialihkan ke `src/game/mannequin.gd`, dan CI
    menolak build kalau berkas itu muncul lagi.
  - **Pemandangan** (`src/game/world/scenery.gd`): dua sabuk bukit (puncak 26 m
    dan 62 m) dengan kabut warna, laut tosca + pulau kecil di barat, 9 blok
    tebing di timur, 2 gapura + 3 tiang batu, 3 titik kunang-kunang; semuanya
    TANPA collision. Jalan tanah berliku digambar di `ground.gdshader` —
    sekaligus memperbaiki varying `world_position` yang tidak pernah diisi
    sehingga semua pola tanah (dan jalan) membaca satu titik nol.
  - **Langit senja** menggantikan malam: `environment/dusk_environment.gd` +
    `dusk_sky.gdshader`. Warna diambil dari piksel ilustrasi (zenith #7C95CD,
    tengah #9DB0D6, pita hangat #D1C2CC, pendar ufuk #F7CEC1), awan pita panjang
    dari fbm 4+2 oktav yang bergerak pelan, ambient/kabut jauh lebih terang,
    saturasi 1,08. Bulan dan bintang DIHAPUS (ilustrasinya bersih); sinar bulan
    menjadi sinar matahari (`god_rays/sun_rays.gd`) dari `Dusk.SUN_DIRECTION`
    yang sama dengan kilau air, dan tombol panel performa kini berbunyi
    "Sinar matahari".
  - **Perbaikan dari pratinjau** (dari gambar, bukan dari error): pita kulit
    lebar terlihat seperti perban/mumi -> dasar dinaikkan (lavender terang),
    bercak hash halus, dan garis energi memakai ambang dekat 1,0 sehingga hanya
    puncak gelombang yang menyala; mode grafis Ringan (12,0/0,130) hanya sedikit
    lebih kasar dari Normal (16,5/0,105).
  - **Gerbang casting diperbaiki**: pemulihan pose dinilai dari POSISI TULANG
    (selisih < 1 mm), bukan piksel — bahan kulit berdenyut mengikuti TIME dan
    awan bergerak, jadi hitungan piksel berubah walau posenya sama.
  - **`Dusk.SUN_DIRECTION` dinormalkan** (dulu 0,997): uji `test_dusk` baru
    benar-benar berjalan setelah casting hijau, dan cek dot > 0,999 mustahil
    lulus dengan vektor yang tidak panjang 1.
  - **Bersih-bersih**: folder pratinjau `worldpass/` (18 gambar) dikeluarkan dari
    git + masuk `.gitignore` (pernah ikut ter-commit oleh `git add -A`).
  - **Gerbang baru**: `tools/test_skin_shell.gd` (selisih pose < 0,0005 m,
    denyut, klip bergerak), `tools/test_scenery.gd` (bagian lengkap, tata letak,
    nol collision, parameter jalan tanah, tebing benar-benar di luar padang),
    `tools/render_world.gd` (4 sudut lebar: pemandangan/jalan/tebing/laut),
    `tools/test_dusk.gd` (pendar matahari, awan, zenith biru terang, arah
    cahaya, keterbacaan tanah), `tools/test_sun_rays.gd`. Langkah CI, artefak,
    dan ringkasan angka ikut berganti nama.

- 2026-10-02 (malam, **HISTORI — sudah dibatalkan pengguna**, lihat entri di atas)
  — MANNEQUIN DIGANTI AVATAR AURELIA (FBX
  `Avatar_Boy_Pole_Lohen` dari folder `aurelia-debug/`, 209 tulang Biped) dan
  **kain + rambut diberi simulasi goyangan** seperti permintaan pengguna.
  - `src/game/character/aurelia_visual.gd` = pengganti `mannequin.gd` (berkas itu
    DIHAPUS). API-nya sama persis (set_locomotion, play_action, foot_pose,
    metrics, cast_layer, ...), jadi pemain, HUD, tapak api, bayangan kecepatan,
    dan panel animasi tidak perlu diubah.
  - Animasi tetap dimainkan di **rig UAL yang disembunyikan** (85 klip utuh),
    lalu pose-nya disalin ke tulang avatar oleh
    `src/game/animation/retarget_modifier.gd` (SkeletonModifier3D, anak ke-2 rig
    sumber supaya gerakan casting ikut tersalin).
  - **Penting: retarget ini BUKAN rumus "selisih rest" bawaan Godot.** Mannequin
    UAL berdiri T-pose, avatar Aurelia A-pose (lengan ±50° ke bawah). Kalau
    selisih-rest yang dipakai, lengan avatar selalu 50° lebih rendah dan tangan
    masuk ke badan. Rumus yang dipakai = arah tulang avatar disamakan dengan
    arah tulang animasi (swing terpendek) + puntiran global diurai swing/twist
    (`_twist_angle`). Diverifikasi gerbang `tools/test_aurelia.gd`
    (`dot(arah avatar, arah animasi) > 0,97` untuk lengan, betis, tangan).
  - Peta tulang UAL ↔ Biped ada di `src/game/animation/humanoid_map.gd`
    (54 pasangan, termasuk jari). Nama dibandingkan setelah dinormalisasi, jadi
    spasi/tanda `+` dari importer tidak merusak peta.
  - Goyangan kain/rambut: `animation/cloth_springs.gd` (inti verlet, bisa diuji
    headless) + `animation/cloth_dynamics.gd` (pembungkus SkeletonModifier3D
    pada kerangka avatar). Angka terukur dari gerbang CI: **44 rantai, 71 tulang,
    16 kapsul** (rambut 20 rantai, syal/rok 15, kerah 3, leher/kalung/anting/
    pinggul/ikat 7). Rantai dibentuk dari tulang asli avatar
    (Bone_Hair*, Bone_Shawl*, Bone_Collar*, Bone_Hip*, Bone_Pendant*,
    Bone_Earrings*, Bone_Neck*, +Flycloak).
    - Kain disimulasikan **di ruang dunia**, jadi punya kelembaman: saat badan
      berbalik/berlari, kain tertinggal di belakang lalu menyusul. Kain yang
      hanya mengikuti tulang (tanpa simulasi) akan terlihat kaku seperti karton.
    - Ada kekakuan (kembali ke bentuk rest di ruang tulang penggantung), angin
      berkecepatan relatif (mengembang saat berlari), tabrakan kapsul badan
      (kepala, dada, pinggul, lengan, kaki) dan gesekan tanah.
    - Catatan teknis: `_keep_shape` menarik POSISI ke rest (`rest_basis *
      rest_local`) dan `_write_chain` selalu memakai rumus yang sama untuk kedua
      tulang rantai — kalau hanya tulang kedua yang dipaksa ke arah rest, akan
      muncul patahan di sambungan.
  - Material: FBX ini memakai shader Unity dan hanya menyimpan SATU material
    untuk semua poligon (tekstur tertukar semua). Material dipilih dari NAMA
    MESH di `character/aurelia_materials.gd` (Body/Bang/Face/Brow/Pupil/
    EyeStar), plus tekstur lightmap dipakai sebagai pancaran lembut supaya
    jubah navy tidak jadi hitam legap di malam hari. Mesh `EffectMesh`
    disembunyikan.
  - **Importer FBX memecah avatar menjadi BEBERAPA Skeleton3D** (badan, rambut,
    mata) karena himpunan tulangnya tidak bersambung. `aurelia_visual.gd`
    mendata SEMUA Skeleton3D di bawah akar avatar, mengurutkannya berdasarkan
    jumlah tulang (terbanyak = kerangka utama, dipakai pemain/HUD/tapak api),
    lalu memberi satu retarget + satu pembungkus kain per kerangka
    (`retargets[]`, `cloths[]`). Kalau nanti jumlah kerangkanya berubah, dua
    array itu sudah menanganinya — jangan kembali ke satu `avatar` saja.
  - **Path tekstur peka huruf besar-kecil di Linux**: folder dari unggahan
    bernama `Textures` (huruf T besar). `aurelia_materials.gd` sempat memakai
    `textures/` sehingga seluruh material tampil tanpa tekstur di CI walau
    jalan di Windows.
  - Aset biner (±24 MB) TIDAK lagi di git: `tools/fetch_assets.sh` mengunduhnya
    dari lampiran rilis `assets-v1` (workflow `publish-assets`, sumbernya riwayat
    commit `0d56df0`), dengan cadangan `--from-git` kalau rilis belum ada. CI
    menjalankan langkah ini sebelum `--import`; **tanpa langkah itu import pasti
    gagal** karena FBX & GLB tidak ada.
  - Gerbang baru: `tools/test_aurelia.gd` (peta tulang lengkap 52 pasangan yang
    ada, arah tulang avatar = arah animasi, tidak T-pose, telapak tidak menembus
    tanah, kain tertinggal-saat-badan-bergerak lalu menyusul, rambut tidak
    menembus kepala/badan). Waktu tunggu langkah tes yang memuat seluruh game
    dinaikkan 90/120 → 180 detik karena avatar menambah beban boot.
  - **Pelajaran rumus retarget** (semuanya pernah salah dan ketangkap gerbang):
    (1) `_measure()` TIDAK BOLEH memakai `resize()` lalu `append()` — array jadi
    dua kali panjang dan tiap tulang membaca nilai tulang lain; (2) rumus letak
    harus memakai rest/pose **LOKAL** (relatif induk), persis seperti
    `RetargetModifier3D::_retarget_pose` bawaan engine — versi global membuat
    seluruh kerangka melar; (3) sumbu tulang = anak yang DIPETAKAN (bukan anak
    pertama, yang bisa tulang puntir seperti `Bone_ForearmTwistA01_L`); (4) tes
    dan retarget harus memilih anak dengan urutan yang sama, kalau tidak tes
    mengukur jari manis sementara retarget mengarahkan jari telunjuk.
  - **Pelajaran kain**: `_keep_shape` harus memakai transformasi LENGKAP tulang
    penggantung (rotasi + letak), bukan hanya rotasinya — kalau tidak, kain
    selalu tertarik ke titik nol dunia dan tidak pernah menyusul badan yang
    berpindah. Rantai satu tulang (rambut tipis, anting, liontin) dulu berujung
    tepat di pangkal sehingga panjangnya nol dan dibuang: ujungnya sekarang
    mengikuti arah tulang induk.
  - **Kaki 4 % lebih pendek daripada mannequin**: retarget memindahkan bentuk
    pose, jadi telapak berhenti ~3 cm di atas tanah dan efek tapak api tidak
    pernah melihat kontak. `aurelia_visual._update_plant()` menurunkan avatar
    (maks 6 cm) selama badan menapak; `foot_clearance()`/`foot_stride_lift()`
    dihitung di ruang dunia dan `foot_fire_trail.gd` memakai tebal telapak
    karakter sebagai ambang (bukan angka 0.035/0.04 yang disetel untuk UAL).
  - **Log CI**: langkah "Ringkasan kegagalan" sekarang mengirim SELURUH log
    sebagai komentar commit (anotasi hanya memuat 25-60 baris terakhir, dan log
    GitHub tidak bisa diunduh dari luar CI). Diagnostik yang perlu dibaca saat
    gagal dicetak di AKHIR log tes.


- 2026-10-02 (lanjutan) — **material avatar diperbaiki dari sumber aslinya**.
  Keluhan pengguna: "model karakter masih banyak bug" (rambut tampak seperti
  helm navy, wajah/mata bercak warna, kain menembus badan). Akarnya ketemu di
  paket aslinya, folder `aurelia-debug/`:
  - Ada **berkas material Unity** (`Materials/*.json`) yang selama ini terlewat:
    masing-masing menunjuk tekstur resminya (`_MainTex`, `_BumpMap`). Peta:
    Mat_Hair→Hair_Diffuse, Mat_Body→Body_Diffuse, Mat_Dress→Body_Diffuse,
    Mat_Face/Mat_Brow→Face_Diffuse, Mat_Pupil→**Hair_Diffuse** (pulau iris kecil
    di atlas rambut), Avatar_Default_Mat→mesh efek (disembunyikan).
  - `LayerElementMaterial` di FBX memang menunjuk material per poligon (bukan
    [0,...] seperti dugaan lama): mesh **Body punya 3 surface** —
    Mat_Hair 20.798 poligon, Mat_Body 12.871, Mat_Dress 1.123 (urutan koneksi
    material ke mesh: Hair, Body, Dress). Versi lama menimpa ketiganya dengan
    satu material, jadi rambut depan memakai atlas jubah navy.
  - Importer FBX Godot menamai tiap **surface** dengan nama material FBX
    (`mat_name` di `modules/fbx/fbx_document.cpp`), jadi material sekarang
    dipilih dari nama surface dan dipasang dengan `set_surface_override_material`
    (satu mesh boleh beda material per surface; `material_override` hanya bisa
    satu dan itulah sumber bug).
  - `_CullMode` dari material Unity: Body/Hair/Face/Brow/Pupil = 2 (single
    sided), hanya **Dress = 0 (double sided)**. Versi lama memaksa semua
    `CULL_DISABLED`, sehingga sisi dalam rambut tergambar menembus wajah.
  - Tekstur `*_Lightmap` dan `Avatar_Tex_Face01_Shadow` adalah peta BAYANGAN
    toon (lavender), bukan warna kulit. Versi lama memakainya sebagai pancaran
    -> wajah tampak kebiruan. Sekarang tidak dipakai.
  - Gerbang `tools/test_aurelia.gd` memeriksa per surface: tekstur ada, garis
    luar ada, cull mode sesuai material aslinya, dan **mesh Body wajib punya
    surface rambut + badan** (penjaga regresi untuk bug helm navy).
  - **Kain menembus badan**: filter kapsul `MAX_COLLIDER_MARGIN` 0,22 → 0,55,
    supaya panel rok/rambut juga bertabrakan dengan kapsul kaki yang baru
    mengayun. Ditambah `penetration_report()` (rantai tanpa kapsul + kedalaman
    tembus terburuk) yang diperiksa gerbang saat diam dan saat lari.
  - **Angka akhir sesudah perbaikan** (komentar commit "angka penting" di CI,
    selalu dikirim): peta material terbaca tepat — Mat_Hair→Hair_Diffuse (2
    surface), Mat_Body→Body_Diffuse, Mat_Dress→Body_Diffuse, Mat_Brow/Mat_Face→
    Face_Diffuse (3 surface), Mat_Pupil→Hair_Diffuse; arah tulang avatar
    dot=1,0000 untuk lengan bawah, betis, dan tangan di keempat klip uji;
    tembus kain diam 0,0011 m dan lari 0,0035 m (sebelumnya 0,034 m gagal);
    biaya kain+retarget 2,50 ms/frame; gerbang lain semua lulus sampai rilis APK.
  - **Pelajaran**: `material_override` hanya satu untuk seluruh mesh — untuk
    mesh dengan beberapa material (di sini Body: rambut + badan + dress) WAJIB
    `set_surface_override_material(index, ...)`, dan nama materialnya bisa dibaca
    dari `mesh.surface_get_name(index)` karena importer FBX Godot menamai surface
    dengan nama material FBX.
  - **Pratinjau render di CI**: artefak/log GitHub tidak bisa diunduh dari
    lingkungan agen, jadi langkah baru merender avatar dari kamera pemain
    (`tools/render_avatar.gd`: 0,4 m / 0,85 m / 2,2 m + pose jalan & lari),
    mengecilkannya jadi JPEG (`tools/make_preview.gd`) dan menempelkannya
    sebagai base64 di komentar commit. Ini cara memeriksa bug yang hanya
    terlihat mata.
- 2026-10-02 (lanjutan) — **zoom kamera bisa menempel ke karakter**. Batas
  terdekat dulu 2,4 m (seluruh badan saja). Sekarang `MIN_DISTANCE = 0,35 m`:
  karena titik pandang kamera ada di setinggi kepala (1,45 m), pada jarak itu
  yang tampak hanya wajah/rambut. Tambahan:
  - `camera.near` mengikuti jarak (`jarak * 0,15`, dibatasi 0,03-0,1 m). Dengan
    nilai tetap 0,1 m, kamera yang sudah menempel masih memotong wajah dan
    rambut; kalau dikecilkan permanen, kejauhan jadi z-fighting.
  - `zoom_by(factor)` = satu tempat untuk semua masukan (cubit dua jari, roda
    tetikus untuk main di desktop/editor, dan tes), jadi batasnya konsisten.
  - Gerbang baru `tools/test_camera_zoom.gd`: mencubit dua jari di separuh kanan
    layar sampai mentok, lalu memeriksa di RUANG DUNIA — jarak kamera ke tulang
    kepala < 0,9 m, kepala di tengah pandangan (dot > 0,85), kamera tidak di
    bawah tanah (y > 0,2), bidang dekat ikut mengecil, roda tetikus sepadan, dan
    setelah dicubit menjauh kamera benar-benar berhenti di 8 m.
  - Kalau nanti ingin lebih menempel lagi, ubah `MIN_DISTANCE` di
    `orbit_camera.gd`; tesnya otomatis ikut (tidak ada angka 2,4 yang tertanam
    di tempat lain).
- 2026-10-02 (lanjutan) — **CI HIJAU PENUH dengan avatar Aurelia** (run
  36968488634, commit `02f1d13`): 25 langkah lulus, termasuk Tes avatar Aurelia
  (retarget + kain), tapak api, semua render Vulkan, ekspor PCK + APK, audit isi
  APK, boot launcher, dan rilis `A-Sekai build-21a54e1`. Sisa langkah yang belum
  diverifikasi di HP pengguna: tes main di perangkat.
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
- 2026-10-02 (malam) — kontrol & HUD dirombak sesuai permintaan pengguna:
  - **Lompat langsung**: `player.gd` tidak lagi menahan badan 0,22 s; dorongan
    dipasang saat tombol ditekan, pose `Jump_Start` menempel 0,3 s lalu klip
    melayang. Dua jebakan yang ikut diperbaiki: logika lantai yang menolkan
    kecepatan vertikal di frame pertama, dan `_update_air_state` yang salah
    membaca "mendarat" selagi badan masih naik (kini wajib `velocity.y <= 0`).
  - **Combo serangan**: `player.attack()` memutar Punch_Jab → Punch_Cross →
    Melee_Hook lalu berulang, reset otomatis setelah 1,1 s tanpa serangan.
  - **Tombol tembak api terpisah** dari tombol serang: `_fire_button` (pet) vs
    `_attack` (combo).
  - **HUD bulat gaya game aksi**: `rune_button.gd` kini punya `caption` +
    `accent` dan menggambar cakram berisi; tidak ada tombol kotak. Susunan:
    SERANG 136 px di kanan bawah, TEMBAK 96, lalu LOMPAT/LARI/JONGKOK 92 di
    baris atasnya; ANIM + GRAFIK 72 di kanan atas (laci grafik turun ke y=196).
  - **Panel animasi jadi jendela kecil** (maks 620×520, ±90%/78% layar) di
    tengah, dengan backdrop yang menutup saat diketuk di luar jendela.
  - **Scroll panel ditangani sendiri**: `ScrollContainer` bawaan tidak menerima
    drag kalau jari mendarat di atas tombol baris, sehingga scroll hanya jalan
    dari celah/pojok (keluhan langsung di HP). Panel sekarang menangani
    `InputEventScreenDrag` sendiri: drag di titik mana pun menggeser daftar,
    ketukan pendek (<14 px) memilih klip.
  - **Analog tidak lagi ikut aktif saat tombol HUD ditekan**
    (`virtual_joystick.input_exclusions`), karena tombol bulat dan analog
    sama-sama mendengar `_input` langsung.
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

## Dusk sky (2026-10-02) — pengganti malam
`environment/dusk_environment.gd` + `dusk_sky.gdshader` (dulu `night_environment.gd`
dan `night_sky.gdshader`). Palette diambil dari ilustrasi layar muat: zenith
#7C95CD, tengah #9DB0D6, pita hangat #D1C2CC, pendar ufuk #F7CEC1. Awan memakai
value-noise fbm 4 oktav (bentuk) + 2 oktav (bayangan) dan bergerak pelan lewat
TIME; `glow_enabled`/`clouds_enabled` bisa dimatikan supaya `tools/test_dusk.gd`
membuktikan pendar dan awan benar-benar terlihat. Bulan, bintang, dan uniformnya
dihapus — di ilustrasi langitnya bersih. Sinar bulan menjadi
`god_rays/sun_rays.gd` (arah `Dusk.SUN_DIRECTION`), panel performa berbunyi
"Sinar matahari", dan tes render malam menjadi
"Render langit senja, awan, matahari dan keterbacaan tanah".

## Night scene milestone (DIHAPUS 2026-10-02, lihat bagian di atas)
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

## Alur lompat: lari -> lompat -> lari tanpa jeda (2026-10-02, lanjutan)
Keluhan pengguna: "selesai loncat dia berhenti, gak ada animasi dalam sekejap,
trus lanjut lagi jalan… jangan jongkok dulu dan jeda patung."
Kontrak sekarang di `player.gd` + `mannequin.gd`:
- `JUMP_POSE_TIME` 0,16 s lalu `Jump_Loop` (loop) selama di udara; klip
  `Jump_Start` 1,33 s tidak pernah diputar penuh.
- Mendarat sambil bergerak (`move_speed > LANDING_SKIP_SPEED` 1,2 m/s) memutar
  klip mendarat **nol frame**; gait langsung menyambung di frame sentuh tanah.
  Klip mendarat hanya untuk pendaratan pelan/diam (`LAND_RECOVERY` 0,28 s).
- Di udara laju horizontal tidak dibuang (`AIR_STEER` 6 rad/s untuk belok,
  `AIR_ACCEL` 4 untuk lompatan dari diam). Ini akar keluhan sebenarnya: jempol
  yang lepas dari analog saat menekan LOMPAT dulu membuat badan mengerem di
  udara, mendarat pelan, lalu memutar pose jongkok.
- Gait dipilih dari `max(input, laju badan)`, jadi saat analog dilepas badan
  melambat lewat Sprint -> Jog -> Walk -> Idle, bukan langsung berpose Idle
  sambil meluncur.
Bukti per-frame: `tools/test_jump_trace.gd` (step CI "Rekam alur animasi lompat").
Alurnya sengaja melepas analog tepat saat menekan LOMPAT, lalu memeriksa laju
minimum di udara, jarak terbang, klip saat mendarat, dan klip saat melambat.

## Leher & kain Aurelia: akurasi kerangka + kain tidak menembus baju (2026-10-02)
Keluhan pengguna: "leher nya kurus banget kayaknya modelnya kurang akurat dan
juga kain baju masih banyak yang kliatan kaku dan nembus di baju lain."
Semua akarnya ada di `animation/cloth_springs.gd`:
- **Leher ternyata disimulasikan sebagai kain.** Geometri leher digerakkan
  `Bone_NeckA01_M` (476 titik; anak `Bip001 Neck` yang hanya 9 titik), dan grup
  `Bone_Neck` ikut verlet — tiap frame kulit leher ditarik gravitasi sehingga
  leher tampak kurus dan memanjang. Grup itu DIHAPUS; leher sekarang mengikuti
  animasi badan seperti tulang lain. Bukti lama: laporan tembus menunjuk
  partikel `Bone_NeckA01_M` vs kapsul `Bip001 Neck`.
- **Urutan mask tabrakan salah.** `allowed` ditulis per kapsul lalu per
  partikel, tapi dibaca per partikel (`index * jumlah_kapsul + slot`) — jadi
  simulasi mendorong partikel yang salah (mask hanya kebetulan benar kalau
  jumlah partikel = jumlah kapsul). Sekarang penulisan dan pembacaan sama-sama
  kolom-kapsul; ini juga salah satu sebab kain masih menembus badan.
- **Kain vs kain (aturan baru).** Tiap rantai dihitung lapisannya (rata-rata
  jarak titik rest ke kapsul badan). Rantai yang lebih luar tidak boleh masuk ke
  kapsul rantai yang lebih dalam: `WEAVE_RADIUS` 2 cm, kapsul dibuat dari segmen
  terdekat di rest pose (maksimum 6 per rantai). Ini yang menghentikan panel
  menembus baju lain, dan sekarang ada angkanya (`weave_report()`, digerbang di
  `tools/test_aurelia.gd`).
- **Kain yang dipasang di lengan tidak digoyang.** `Bone_ShawlJ01_L`/`K01_L`
  menggantung di `Bone_ShawlArmTwistA01_L` (anak `Bip001 L UpperArm`); goyangan
  gravitasi membuatnya menyayat jubah badan setiap lengan diangkat. Ketiganya
  masuk `SKIP_BONES` dan kaku mengikuti lengan seperti aslinya.
- **Kain tidak kaku lagi**: kekakuan grup Shawl 15 → 9,5 /detik, redaman
  1,7 → 1,45.
- Angka CI terakhir (commit `de3ed0a`, run 36975703931; kerangka/kain tidak
  berubah setelahnya): rantai 40, kain 67 tulang, **tembus kain** diam 0,0044 m
  dan lari 0,0038 m (gerbang 0,02/0,03), **tembus kain vs kain** diam 0,0000 m
  dan lari 0,0031 m (gerbang 0,012/0,02), biaya kain+retarget 2,99 ms/frame dari
  anggaran 6,0 ms, zoom kamera OK.
- **Pratinjau baru** supaya mata bisa memeriksa bagian ini: `leher` (bidik
  `Bip001 Neck` dari sedikit bawah), `kain` (samping, bidik `Bip001 Pelvis`),
  `kain_belakang` (tiga-perempat belakang, bidik `Bip001 Spine1`), dan pose
  jalan/lari/jongkok kini dibidik pinggul pada 1,6-1,8 m. Titik bidik diambil
  dari POSISI TULANG, bukan angka meter: percobaan pertama memakai tinggi
  tebakan dan bidikan leher mengarah ke langit. `orbit_camera.gd` sekarang
  menyimpan `focus_offset` (dulu angka 0,55 ditulis di `main.gd`).
- **Alat baru**: `tools/fbx_inspect.py` (baca FBX tanpa Godot: `bones`,
  `extras`, `mats`, `bonesize` — tulang mana menggerakkan berapa titik dan
  sebesar apa geometrinya) dan `tools/fetch_previews.sh` (menyusun ulang JPEG
  pratinjau dari komentar commit CI; unduhan artefak sering gagal EOF).
- Catatan model: leher asli memang 9 cm (`Bone_NeckA01_M` x ±0,045) sementara
  kepalanya 23 cm — setelah simulasi dilepas, leher tampil seperti aslinya. Bila
  pengguna tetap ingin lebih tebal, itu koreksi bentuk (skala tulang leher),
  bukan bug simulasi.

## Kain jatuh seperti kain + pose "kayak difoto" (2026-10-02, lanjutan)
Keluhan: "kain belakang nya belom smooth bukan kayak kain malah kaku banget…
bagian bokong masih ada yang blom diperbaiki… pas make animasi jongkok malah
kayak difoto." Tiga akar terpisah, semuanya sudah ada gerbang/angkanya:
- **Cape kaku seperti papan.** Pose rest FBX ini pose patung: cape terbentang ke
  belakang. Penjaga bentuk (`_keep_shape`) menarik tiap partikel kembali ke sudut
  itu dengan kaku ~50× gravitasi, jadi berapa pun angin/gravitasi ditambah panel
  tetap terbentang. Sekarang arah acuan tiap segmen diputar ke arah gravitasi
  sebesar `hang` (naik dari pangkal ke ujung lewat `HANG_RAMP_FROM`), dan arah
  datar panel dipertahankan `HANG_SPREAD` 0,45 supaya panel dari dada tidak
  semuanya jatuh ke satu titik (jubah berubah jadi tenda kalau 0). Setelan:
  Shawl 0,80; Flycloak 0,90; Hip 0,75; Collar 0,40; Hair 0,30; Pendant 0,60.
- **"Kayak difoto" ada bug nyata.** Sesudah klip aksi yang menahan frame terakhir
  (mis. menyerang), mode `HELD` membuat `set_locomotion` menolak mengganti klip —
  badan berjalan/meluncur sambil benar-benar membeku, dan HUD tetap menulis nama
  gait sehingga tidak terlihat seperti pose tahan. Sekarang `HELD` dilepas begitu
  pemain meminta gait; gerbangnya di `tools/test_aurelia.gd` (`_test_hold_release`).
- **Jongkok memang bergerak.** Diagnosa baru "gerak klip" mengukur jarak tulang
  avatar per frame: Crouch_Idle 0,1705 m/frame (2,311 m total), Crouch_Fwd 0,0118
  m/frame — jadi klipnya hidup; yang dulu terlihat "difoto" adalah dua sebab di
  atas (kain kaku + mode tahan). Pelajaran nama: nama klip runtime BUKAN nama
  katalog — importer glTF membuang akhiran `_Loop` dan klip UAL2 ada di pustaka
  `ual2`; diagnosa pertama mencari nama katalog mentah sehingga melaporkan 0,000
  untuk semua klip. Selalu ukur lewat `current_animation`.
- **Angka akhir** (commit `4e0fc09`, CI hijau): tembus kain diam 0,0002 m / lari
  0,0001 m; tembus kain vs kain 0,0000 / 0,0073 m (gerbang 0,012/0,02); biaya
  kain+retarget 4,30 ms/frame (anggaran 6,0); pose tahan lepas; zoom OK.
- **Pratinjau baru**: `avatar-bokong` (dari belakang, 1,05 m) dan
  `avatar-jongkok_jalan` (merangkak) — dua sudut yang diminta pengguna.
- **Pelajaran proses**: satu commit pernah membawa indeks klon yang rusak
  (pekerjaan Aurelia hilang, `mannequin.gd` lama kembali) dan baru ketahuan di
  langkah "Ambil aset biner" dengan pesan `No such file or directory`. Sekarang
  langkah lint memeriksa daftar berkas wajib dalam hitungan detik. Sebelum
  push, selalu `git diff --stat <commit-hijau>` dan pastikan hanya berkas yang
  diniatkan yang berubah; kalau pohon ter-revert, `git checkout <commit-hijau>
  -- .` lalu tulis ulang hanya perubahan yang diniatkan (tanpa force-push).
- Log langkah "Ambil aset biner" sekarang di-`tee` ke `fetch-assets.log` dan
  ekornya ikut dikirim di komentar "angka penting".
