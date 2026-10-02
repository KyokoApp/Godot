extends Control
## Vignette UI di atas ilustrasi dari main.tscn.
##
## Ilustrasi sengaja TIDAK di-preload di sini: preload yang gagal membuat seluruh
## skrip ini tidak termuat, launcher ikut mati, dan layar HP jadi abu polos tanpa
## teks. Sekarang tekstur direferensikan scene (dependensi yang memang diikuti
## eksportir) dan kalau tidak ada, skrip ini hanya menyediakan latar polos.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ilustrasi datang dari scene (main.tscn). Kalau teksturnya tidak ikut ke paket,
	# sediakan latar polos supaya layar tidak pernah kosong.
	var art: TextureRect = null
	var parent := get_parent()
	if parent != null:
		art = parent.find_child("LoadingArt", true, false) as TextureRect
	if art == null or art.texture == null:
		push_warning("Loader: ilustrasi loading tidak tersedia, memakai latar polos")
		var base := ColorRect.new()
		base.color = Color(0.05, 0.07, 0.14)
		base.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(base)
		base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(0.04, 0.06, 0.12, 0.12),
		Color(0.04, 0.06, 0.12, 0.06), Color(0.04, 0.06, 0.12, 0.72)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0)
	texture.fill_to = Vector2(0.5, 1)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
