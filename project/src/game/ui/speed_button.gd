extends "res://src/game/ui/rune_button.gd"
## Tombol lari (boost). Bulat seperti tombol lain; saat aktif cincinnya menyala
## oranye dan ikon diperbesar sedikit, jadi statusnya kelihatan tanpa label
## panjang (label "LARI ×1,35" dulu bikin tombol berisik dan kecil).

var boosted := false


func _draw() -> void:
	# Label tetap pendek: yang menandakan boost adalah warna cincin aksen.
	caption = "LARI"
	accent = Color(1, 0.83, 0.45, 0.95) if boosted else Color(1, 1, 1, 0.34)
	super._draw()
