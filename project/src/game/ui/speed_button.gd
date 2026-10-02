extends "res://src/game/ui/rune_button.gd"
## Tombol lari (boost). Bulat seperti tombol lain; saat aktif cincinnya menyala
## dan angkanya berganti, jadi statusnya kelihatan tanpa label panjang.

var boosted := false


func _draw() -> void:
	caption = "LARI ×1,35" if boosted else "LARI"
	accent = Color(1, 0.83, 0.45, 0.95) if boosted else Color(1, 1, 1, 0.34)
	super._draw()
