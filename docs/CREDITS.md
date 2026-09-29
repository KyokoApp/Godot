# Kredit & Lisensi Aset

## Aset 3D

### Medieval Village MegaKit [Standard]
- **Autor:** Quaternius — https://quaternius.com
- **Lisensi:** CC0 1.0 Universal (Public Domain Dedication)
  https://creativecommons.org/publicdomain/zero/1.0/
- **Isi:** 176 model glTF (dinding, lantai, pintu, jendela, atap, tangga,
  kios, perabot) dalam format modular 2 m x 1 m.
- **Status:** masih ada di repo `KyokoApp/Unity` branch `archive` (folder
  `Mediavel/`). Belum dipakai di project ini — akan masuk saat milestone
  "Build mode grid".

## Kode

Semua kode dalam repo ini ditulis khusus untuk project ini.

## Mannequin + animasi (Milestone 5A)

**Universal Animation Library [Standard]**, Quaternius — CC0 1.0 Universal.
- https://quaternius.com/packs/universalanimationlibrary.html
- https://creativecommons.org/publicdomain/zero/1.0/
- Sumber migrasi: `KyokoApp/Unity`, branch `archive`, commit
  `bca3e575fc26311ef5a43c0263e772a6d9fced20`.
- File asli: `project/packs/char_assets/mannequin/UAL1_Standard.glb`.
- Git blob asli (diverifikasi saat migrasi): `473e59080288428d0b6da826ba19324d07b191f0`.
- Model rigged dan animasi asli; bukan mannequin prosedural. Klip Godot:
  `Idle`, `Walk`, `Jog_Fwd`, serta upper-body `Spell_Simple_Shoot`. Material diubah menjadi lavender pastel.

## Rumput angin — adaptasi shader Malido (CC0)

- Pembuat shader referensi: **@_Malido / Malidos**.
- Halaman: https://godotshaders.com/shader/stylized-multimesh-grass-shader/
- Demo sumber: https://github.com/Malidos/Grass-Shader-Example
- File referensi `grass_shader.gdshader`, commit
  `13bb96e556b6b80ccdcb9fa42e116770ede8dcc8`.
- Halaman menyatakan kode shader/snippet berlisensi **CC0 1.0**:
  https://creativecommons.org/publicdomain/zero/1.0/ . Gambar/video pada halaman
  tidak termasuk lisensi tersebut dan tidak disalin ke proyek ini.
- `project/src/game/grass.gdshader` mengadaptasi gradien ujung/akar, wind noise
  berfase UV, displacement pemain dan AO akar. Perubahan: ruang vertex dunia,
  normalisasi aman, batas jarak dengan penyusutan opaque, material matte untuk
  mobile. Noise Perlin dibuat dalam kode; mesh tiga helai dan streaming tile
  dibuat khusus proyek ini. Tidak menyalin model/tekstur demo.

## Ikon dan ilustrasi loading A-Sekai

`project/launcher/art/loading.jpg` adalah ilustrasi AI orisinal
untuk proyek ini, bukan karakter/aset resmi Genshin/HoYoverse. Ikon AI sebelumnya telah diganti gambar pilihan pengguna (lihat bagian berikut).
Loading art tetap sama.

Penelusuran referensi visual yang diminta pengguna:
- https://pinterest.com/pin/582512533028994284
- https://www.pinterest.com/animae_jw/blue-pfp/

Referensi tersebut bukan sumber aset yang dibundel; izin redistribusinya belum
terverifikasi. Jangan menyebut ilustrasi AI ini sebagai karya seniman Pinterest
atau mengklaimnya berlisensi CC0. Shader outline mannequin ditulis untuk proyek.


## Ikon pilihan pengguna (menggantikan ikon AI)

`project/launcher/art/icon.png`, `icon-192.png`, dan `icon-foreground.png` dibuat
melalui crop persegi tengah minimal dan resize dari gambar yang diunggah pengguna:
`547d844ffaca3a9b862a3c20e929770d.jpg` (commit upload `eea852f`).
Referensi yang diberikan: https://pin.it/39gUpFwmd . Tidak digambar ulang AI.
`icon-background.png` adalah ungu gelap polos untuk adaptive icon.
Nama seniman dan lisensi sumber belum terverifikasi. Jangan menyebutnya CC0 atau
karya orisinal proyek; hak distribusi komersial/store perlu diverifikasi tersendiri.

## Jubah api biru

Mesh pakaian, tudung/aksesori prosedural, solver kain ringan dan shader api toon
pastel ditulis untuk proyek ini; tidak menyalin pakaian/aset karakter eksternal.
Animasi dan skeleton penggerak tetap UAL1 Standard Quaternius (kredit di atas).

## Pet api astral

Model pet prosedural, shader gradien api toon, proyektil gravitasi dan VFX ledakan
bulat ditulis untuk proyek ini. Tidak memakai model, tekstur atau suara dari
Naruto/game lain. Referensi pengguna hanya berupa bentuk ledakan bulat berputar.

## Spirit api dari project lama pengguna

`project/src/game/legacy_spirit/fireball_core.gdshader` dan
`fireball_shell.gdshader` disalin utuh dari `KyokoApp/Unity`, commit archive
`bca3e575fc26311ef5a43c0263e772a6d9fced20`, folder `project/packs/character_player/`.
`spirit_visual.gd` memport bagian visual/animasi `fire_spirit.gd` serta helper
halo/particle dari `fire_fx.gd` ke fondasi baru. Ini kode project lama pengguna,
bukan aset Naruto atau interpretasi baru dari ingatan.

### Projectile / impact v2
- Bolt core/shell and surface shockwave: adapted from this user's archived
  `KyokoApp/Unity`, archive commit `bca3e575fc26311ef5a43c0263e772a6d9fced20`,
  `project/packs/character_player/arcane_bolt.gd`, `fire_explosion.gd`,
  `fireball_core.gdshader`, `fireball_shell.gdshader`, `shockwave.gdshader`.
  Core/shell remain the exact archived shaders shared with the pet. Controllers
  retain the new swept sphere physics; damage/audio/world-system dependencies
  from the archived project are not imported.
- Flame billboard shader: GDQuest, based on MinionsArt's stylized fire technique.
  https://godotshaders.com/shader/stylized-fire-3d/
  Source: https://github.com/GDQuest/godot-shaders/blob/05a3931acc85513b67b80b6e88671a596a3f9693/godot/Shaders/stylized_fire.gdshader
  MIT, Copyright (c) 2020-present GDQuest. Notice included in shader and
  `project/licenses/GDQuest-MIT.txt` (also exported in APK/PCK).
  Changes: unshaded, double-sided/shadowless material, reduced emission.
  All noise/mask textures are generated by our code; **no demo images/models**
  under the repository's separate CC-BY-NC-SA license are included.
- Cartoon 3D Fire by erBimo was also inspected on GodotShaders; no code or
  artwork from that page was imported.

### HUD rune icons
`project/src/game/ui/flame.svg` and `settings.svg`: original vector artwork
created for A-Sekai, not copied from an icon pack or third-party image.

### Positional gameplay audio
- Fire shoot/explode/loop: byte-for-byte original procedural SFX from
  `KyokoApp/Unity` archive `bca3e575fc26311ef5a43c0263e772a6d9fced20`,
  `project/packs/audio_sfx/`. Original generator: `tools/synth_fire.py` there.
- Footsteps: Kenney **Impact Sounds** (2019), CC0:
  https://kenney.nl/assets/impact-sounds . Source grass/concrete variations
  000–003 retrieved from `iree-gd/iree.gd`, commit
  `9db7d7069a9ad75c77e9b5657d1ae5bdf615a6bc`, `sample/assets/audio/impact/`.
  Converted/downmixed/trimmed/gain-adjusted by `tools/prepare_footsteps.py`.
  Dirt is a designed blend of these recordings, not a separate dirt recording.
  Attribution/provenance also exported in `licenses/Kenney-Impact.txt`.

### Pet flame correction (visual + sound)
- `legacy_spirit/pet_flame.gdshader`: original pet-only tapered flame silhouette,
  three independently moving tongues, rising noise erosion, small cyan-hot center.
  No opaque sphere; shared archived projectile/explosion shaders unchanged.
- `assets/audio/pet_crackle.wav`: adapted **Fire Crackling**, AntumDeluge, CC0.
  https://opengameart.org/content/fire-crackling . Retrieved from the explicitly
  credited mirror `pawelkwaczynski/coffee-paladin`, commit
  `c74798f0bc905dc8aad6a429c683fe746373194d`, `sounds/critical.wav`.
  Full source hash, modifications and attribution: `licenses/Pet-Fire-CC0.txt`.
  `tools/prepare_pet_fire.py` rebuilds the 8-second crossfaded companion loop.

### Night environment
`environment/night_sky.gdshader`: original procedural sky for A-Sekai,
seeded sparse stars, small moon with analytic crater marks and subtle halo.
No downloaded sky image, shader-site code, or third-party celestial artwork.

### Archived nature and stone footpath
Eleven actual glTF models from the user's `KyokoApp/Unity` archive
`bca3e575fc26311ef5a43c0263e772a6d9fced20`,
`project/packs/build_mode/objects/nature/`: trees, bushes, fern, flowers,
rocks, pebble and RockPath_Round_Wide. The archive credits identify these as
**Quaternius Stylized Nature MegaKit, CC0**:
https://quaternius.com/packs/stylizednaturemegakit.html .
Full list/provenance exported in `licenses/Quaternius-Nature.txt`.
Original glTF/bin geometry preserved; referenced PNGs resized to <=512px.
`tools/fetch_nature_assets.py` reproduces retrieval and resizing.
`grass_cards.png` and `meadow_cover.png` are original deterministic textures;
regenerate with `tools/make_meadow_textures.py` (Pillow).


## Water shader
- Marcel Bankmann, **GodotSSRWater**, MIT ©2023–present.
- https://godotshaders.com/shader/transparent-water-shader-supporting-ssr/
- https://github.com/marcelb/GodotSSRWater
- Source pinned at `391b2f9f9fc289c8ef0ccc2889cf53b5d3cfdaec` (`shaders/water.gdshader`).
- License: `project/licenses/MarcelBankmann-Water-MIT.txt`.
- Adapted projection/depth, wave/normal blend, refraction and SSR functions for
  Godot4.5.2 Mobile: fixed12-probe loop, corrected normal spaces, reverse-Z
  near/far-independent reconstruction, disabled/miss fallback and night palette.
- Water maps and watershed geometry are original procedural work. No upstream
  demo textures/models/media copied. Generator: `tools/make_water_textures.py`.
