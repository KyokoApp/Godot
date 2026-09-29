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
  `Idle`, `Walk`, `Jog_Fwd`. Material diubah menjadi lavender pastel.

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
