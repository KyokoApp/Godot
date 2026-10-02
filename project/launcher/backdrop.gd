extends Control
## Ilustrasi orisinal + vignette UI; tetap memakai loading bar nyata dari launcher.

## Jalur, bukan preload: dengan preload, satu tekstur yang hilang dari APK membuat
## SELURUH skrip ini gagal dimuat, launcher ikut mati, dan layar jadi abu polos
## tanpa teks. Di HP itu tampak seperti aplikasi rusak total.
const ART_PATH := "res://launcher/art/loading.jpg"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Latar polos dulu supaya layar tidak pernah kosong walau tekstur tak ada.
	var base := ColorRect.new()
	base.color = Color(0.05, 0.07, 0.14)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(ART_PATH):
		var picture := TextureRect.new()
		picture.name = "LoadingArt"
		picture.texture = load(ART_PATH) as Texture2D
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(picture)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		push_warning("Loader: ilustrasi loading tidak ada di paket, memakai latar polos")
		var art := TextureRect.new()
		art.name = "LoadingArt"  # nama tetap ada supaya tes/UI tidak pecah
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
