# Aset biner (tidak disimpan di git)

Berkas besar di folder ini diunduh dengan satu perintah:

```bash
tools/fetch_assets.sh            # unduh dari lampiran rilis (tag assets-v1)
tools/fetch_assets.sh --from-git # ambil dari riwayat git lokal (tanpa internet)
```

CI menjalankan langkah ini sendiri sebelum `--import`, jadi tidak ada yang perlu
dilakukan kalau proyek hanya dibangun lewat Actions.

| Folder | Isi | Ukuran |
| --- | --- | --- |
| `aurelia/Avatar_Boy_Pole_Lohen.fbx` | avatar Aurelia, 209 tulang (Biped) | 4,9 MB |
| `aurelia/Textures/*.png` | 15 tekstur asli avatar (diffuse/normal/lightmap) | 3,7 MB |
| `mannequin/UAL1_Standard.glb` | Universal Animation Library 1 (43 klip) | 7,6 MB |
| `combat/UAL2_Standard.glb` | Universal Animation Library 2 (43 klip) | 8,1 MB |

Catatan penting untuk FBX: tekstur **harus** ada di `aurelia/Textures/` karena
nama di dalam FBX berbentuk `Textures\Nama.png`. Importer Godot mencari ke folder
`Textures/` di sebelah berkas FBX, jadi menaruhnya di tempat lain membuat importer
menyimpan gambar kosong.

Klip animasi diputar di rig UAL (tidak digambar) lalu pose-nya disalin ke tulang
avatar; lihat `src/game/character/aurelia_visual.gd` dan
`src/game/animation/retarget_modifier.gd`.
