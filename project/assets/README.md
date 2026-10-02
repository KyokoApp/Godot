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
| `mannequin/UAL1_Standard.glb` | Universal Animation Library 1 (43 klip) | 7,6 MB |
| `combat/UAL2_Standard.glb` | Universal Animation Library 2 (43 klip) | 8,1 MB |

Karakter di game adalah **mannequin UAL** itu sendiri: klip animasinya diputar
langsung di rig-nya, jadi tidak ada retarget, tidak ada rig bayangan, dan tidak
ada aset karakter tambahan. Tubuhnya dilapisi **kulit beranimasi** —
`src/game/character/skin_shell.gd` + `skin_shell.gdshader` — yaitu salinan mesh
yang digelembungkan sedikit, memakai bahan kulit yang sama dengan mesh di
dalamnya, jadi sambungan/tulang mannequin tidak pernah terlihat polos.
