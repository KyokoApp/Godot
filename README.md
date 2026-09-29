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
