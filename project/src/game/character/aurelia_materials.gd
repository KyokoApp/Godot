extends RefCounted
## Material untuk avatar Aurelia (FBX "Avatar_Boy_Pole_Lohen").
##
## Sumber kebenaran: berkas `Materials/*.json` dari paket aslinya (Unity). Setiap
## material di sana menunjuk teksturnya sendiri, dan FBX menyimpan urutan
## material per poligon lewat `LayerElementMaterial`. Importer Godot memecah
## mesh menjadi satu SURFACE per material dan menamai tiap surface dengan nama
## material FBX — jadi material di sini dipilih dari NAMA SURFACE, bukan dari
## tebakan nama mesh. Cara lama (satu material per nama mesh) menimpa tiga
## surface mesh "Body" dengan satu atlas, sehingga:
##   - rambut depan (surface Mat_Hair di dalam mesh Body, 20.798 poligon) ikut
##     memakai atlas jubah navy -> terlihat seperti helm biru tua,
##   - mata (Face_Eye/EyeStar) memakai atlas rambut -> bercak warna-warni.
##
## Angka penting dari berkas material:
##   Mat_Hair  -> Hair_Diffuse + Hair_Normalmap
##   Mat_Body  -> Body_Diffuse + Body_Normalmap
##   Mat_Dress -> Body_Diffuse (double-sided: _CullMode 0)
##   Mat_Face  -> Face_Diffuse     Mat_Brow -> Face_Diffuse
##   Mat_Pupil -> Hair_Diffuse (pulau iris kecil di atlas rambut)
##   Avatar_Default_Mat -> mesh efek, disembunyikan
##
## Catatan tekstur: `*_Lightmap` dan `Avatar_Tex_Face01_Shadow` adalah peta
## BAYANGAN toon (lavender/biru), bukan warna kulit. Versi lama memakainya
## sebagai pancaran sehingga wajah tampak kebiruan; sekarang tidak dipakai.

const OUTLINE = preload("res://src/game/character_outline.gdshader")
const TEXTURE_DIR := "res://assets/aurelia/Textures/"

const BODY_DIFFUSE := "Avatar_Boy_Pole_Lohen_Tex_Body_Diffuse.png"
const BODY_NORMAL := "Avatar_Boy_Pole_Lohen_Tex_Body_Normalmap.png"
const HAIR_DIFFUSE := "Avatar_Boy_Pole_Lohen_Tex_Hair_Diffuse.png"
const HAIR_NORMAL := "Avatar_Boy_Pole_Lohen_Tex_Hair_Normalmap.png"
const FACE_DIFFUSE := "Avatar_Boy_Pole_Lohen_Tex_Face_Diffuse.png"

## Kunci = nama material FBX dalam huruf kecil tanpa spasi/garis bawah/tanda "+".
##   cull : "single" (default, seperti _CullMode 2) atau "double" (_CullMode 0)
##   gloss: kilau logam bawaan game asal (rambut & kostum memakai MetalMap)
const RULES := {
	"avatarboypolelohenmathair": {"diffuse": HAIR_DIFFUSE, "normal": HAIR_NORMAL,
		"gloss": 0.32},
	"avatarboypolelohenmatbody": {"diffuse": BODY_DIFFUSE, "normal": BODY_NORMAL,
		"gloss": 0.24},
	"avatarboypolelohenmatdress": {"diffuse": BODY_DIFFUSE, "normal": BODY_NORMAL,
		"gloss": 0.24, "cull": "double"},
	"avatarboypolelohenmatface": {"diffuse": FACE_DIFFUSE},
	"avatarboypolelohenmatbrow": {"diffuse": FACE_DIFFUSE},
	# Iris: pulau kecil di atlas rambut, tanpa bayangan supaya matanya tidak gelap.
	"avatarboypolelohenmatpupil": {"diffuse": HAIR_DIFFUSE, "unshaded": true},
	"avatardefaultmat": {"hide": true},
}

## Material tambahan yang tidak punya tekstur di paket ini tetapi tetap muncul
## sebagai surface (mis. bulu mata). Dibuat polos gelap supaya tidak putih.
const FALLBACK := {"diffuse": BODY_DIFFUSE, "gloss": 0.2}


## Ubah nama apa pun (material, mesh, surface) menjadi kunci pencarian.
static func rule_key(name: String) -> String:
	var key := ""
	for index in range(name.length()):
		var code := name.to_lower().unicode_at(index)
		if (code >= 97 and code <= 122) or (code >= 48 and code <= 57):
			key += String.chr(code)
	return key


## Aturan untuk satu nama surface/material. Surface yang tidak dikenal memakai
## FALLBACK supaya tidak muncul putih polos.
static func rule_for(name: String) -> Dictionary:
	var key := rule_key(name)
	if RULES.has(key):
		return RULES[key]
	return FALLBACK


## Pasang material ke semua MeshInstance3D di bawah `root`, SATU material per
## surface (material_override hanya bisa satu untuk seluruh mesh — itu akar
## masalah sebelumnya). Mengembalikan jumlah mesh yang diproses.
static func apply(root: Node3D) -> int:
	var processed := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var mesh := instance.mesh
		if mesh == null:
			processed += 1
			continue
		var hidden := false
		for surface in range(mesh.get_surface_count()):
			var key := rule_key(mesh.surface_get_name(surface))
			var rule: Dictionary = RULES.get(key, FALLBACK)
			if bool(rule.get("hide", false)):
				hidden = true
				break
			instance.set_surface_override_material(surface, build(rule))
		instance.material_override = null
		instance.visible = not hidden
		processed += 1
	return processed


static func build(rule: Dictionary) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var diffuse: String = rule.get("diffuse", "")
	var texture := _texture(diffuse)
	if texture != null:
		material.albedo_texture = texture
	var normal: String = rule.get("normal", "")
	if not normal.is_empty():
		var normal_texture := _texture(normal)
		if normal_texture != null:
			material.normal_enabled = true
			material.normal_texture = normal_texture
			material.normal_scale = 0.6
	material.roughness = 0.78
	material.metallic_specular = float(rule.get("gloss", 0.2))
	# Sisi belakang hanya digambar kalau material aslinya memang double-sided.
	# Kalau semua dipaksa double-sided, bagian dalam rambut dan badan ikut
	# tergambar lewat wajah (terlihat seperti kain menembus badan).
	if String(rule.get("cull", "single")) == "double":
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	else:
		material.cull_mode = BaseMaterial3D.CULL_BACK
	if bool(rule.get("unshaded", false)):
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE
	outline.set_shader_parameter("outline_width", 0.0035)
	outline.set_shader_parameter("outline_color", Color(0.10, 0.11, 0.16))
	material.next_pass = outline
	return material


static func _texture(file_name: String) -> Texture2D:
	if file_name.is_empty():
		return null
	var path := TEXTURE_DIR + file_name
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
