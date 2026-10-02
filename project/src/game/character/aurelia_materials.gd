extends RefCounted
## Material untuk avatar Aurelia (FBX "Avatar_Boy_Pole_Lohen").
##
## Berkas FBX-nya memakai shader Unity (NyxStateOutline/MToon) yang tidak ada di
## Godot, dan tidak menyimpan harga/material per mesh dengan benar: seluruh
## geometri memakai satu material untuk semua poligon, jadi teksturnya tertukar
## (rambut putih memakai atlas badan, mata memakai tekstur yang sama, dll).
##
## Karena itu material di sini dipilih dari NAMA MESH, bukan dari isi FBX:
##   Body/Kostum -> atlas badan (jubah navy + motif berlian)
##   Bang        -> atlas rambut (putih/perak + iris mata + bintang)
##   Face/Brow   -> atlas wajah (kulit pucat, alis)
##   Pupil/Star  -> atlas rambut, tanpa bayangan, bintang diberi pancaran
##
## Tekstur "lightmap" dari game asalnya dipakai sebagai lapisan pancaran lembut
## (energy kecil). Hasilnya seperti bayangan toon: bagian gelap tidak menjadi
## hitam legap waktu malam, tanpa perlu LightmapGI yang berat untuk HP.

const OUTLINE = preload("res://src/game/character_outline.gdshader")
const TEXTURE_DIR := "res://assets/aurelia/textures/"

const BODY_DIFFUSE := "Avatar_Boy_Pole_Lohen_Tex_Body_Diffuse.png"
const BODY_NORMAL := "Avatar_Boy_Pole_Lohen_Tex_Body_Normalmap.png"
const BODY_LIGHTMAP := "Avatar_Boy_Pole_Lohen_Tex_Body_Lightmap.png"
const HAIR_DIFFUSE := "Avatar_Boy_Pole_Lohen_Tex_Hair_Diffuse.png"
const HAIR_NORMAL := "Avatar_Boy_Pole_Lohen_Tex_Hair_Normalmap.png"
const HAIR_LIGHTMAP := "Avatar_Boy_Pole_Lohen_Tex_Hair_Lightmap.png"
const FACE_DIFFUSE := "Avatar_Boy_Pole_Lohen_Tex_Face_Diffuse.png"
const FACE_LIGHTMAP := "Avatar_Boy01_Tex_FaceLightmap.png"

## Kunci = nama mesh dalam huruf kecil tanpa spasi/garis bawah.
const RULES := {
	"body": {"diffuse": BODY_DIFFUSE, "normal": BODY_NORMAL,
		"lightmap": BODY_LIGHTMAP, "energy": 0.30},
	"dress": {"diffuse": BODY_DIFFUSE, "normal": BODY_NORMAL,
		"lightmap": BODY_LIGHTMAP, "energy": 0.30},
	"skin": {"diffuse": BODY_DIFFUSE, "lightmap": BODY_LIGHTMAP, "energy": 0.30},
	"bang": {"diffuse": HAIR_DIFFUSE, "normal": HAIR_NORMAL,
		"lightmap": HAIR_LIGHTMAP, "energy": 0.26},
	"hair": {"diffuse": HAIR_DIFFUSE, "normal": HAIR_NORMAL,
		"lightmap": HAIR_LIGHTMAP, "energy": 0.26},
	"face": {"diffuse": FACE_DIFFUSE, "lightmap": FACE_LIGHTMAP, "energy": 0.22},
	"brow": {"diffuse": FACE_DIFFUSE, "lightmap": FACE_LIGHTMAP, "energy": 0.18},
	"faceeye": {"diffuse": HAIR_DIFFUSE, "lightmap": FACE_LIGHTMAP,
		"energy": 0.30, "shaded": false},
	"pupil": {"diffuse": HAIR_DIFFUSE, "lightmap": FACE_LIGHTMAP,
		"energy": 0.30, "shaded": false},
	"eyestar": {"diffuse": HAIR_DIFFUSE, "energy": 1.6, "shaded": false},
	# Mesh efek (kilau) tidak perlu ikut digambar.
	"effectmesh": {"hide": true},
}

## Nama mesh yang tidak dikenal tetap dapat material dasar supaya tidak muncul
## sebagai putih polos.
const FALLBACK := {"diffuse": BODY_DIFFUSE, "lightmap": BODY_LIGHTMAP, "energy": 0.2}


static func rule_for(mesh_name: String) -> Dictionary:
	var key := ""
	for index in range(mesh_name.length()):
		var code := mesh_name.to_lower().unicode_at(index)
		if (code >= 97 and code <= 122) or (code >= 48 and code <= 57):
			key += String.chr(code)
	if RULES.has(key):
		return RULES[key]
	for prefix: String in RULES:
		if key.begins_with(prefix):
			return RULES[prefix]
	return FALLBACK


## Pasang material ke semua MeshInstance3D di bawah `root`.
## Mengembalikan jumlah mesh yang diproses.
static func apply(root: Node3D) -> int:
	var processed := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var rule := rule_for(mesh.name)
		if bool(rule.get("hide", false)):
			mesh.visible = false
			processed += 1
			continue
		mesh.material_override = build(rule)
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
	material.roughness = 0.82
	material.metallic_specular = 0.25
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not bool(rule.get("shaded", true)):
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var lightmap: String = rule.get("lightmap", "")
	var energy := float(rule.get("energy", 0.0))
	if not lightmap.is_empty() and energy > 0.0:
		var light_texture := _texture(lightmap)
		if light_texture != null:
			material.emission_enabled = true
			material.emission_texture = light_texture
			material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			material.emission_energy_multiplier = energy
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
