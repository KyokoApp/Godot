extends RefCounted
## Preset dunia senja seperti ilustrasi layar muat (project/launcher/art/loading.jpg):
## langit lavender-hangat, cahaya matahari rendah berwarna krem, kabut tipis yang
## membuat perbukitan jauh tampak pucat, dan tanah yang tetap terang dibaca.
##
## Dipakai bersama oleh permainan (main.gd), warmup shader, dan tes render, jadi
## warna di layar dan warna di gambar tes tidak pernah berbeda.

const SKY_SHADER = preload("res://src/game/environment/dusk_sky.gdshader")
## Matahari rendah di barat (sisi laut), sedikit di atas ufuk — sama dengan pendar
## di ilustrasi. Arah ini juga dipakai sinar matahari (god rays) dan kilau air.
## Vektornya sudah panjang 1 (diuji `test_dusk`): kalau tidak, hasil dot dengan
## basis lampu selalu < 1 dan gerbang arah cahaya gagal tanpa sebab nyata.
const SUN_DIRECTION := Vector3(-0.942785, 0.090267, -0.320948)


static func make_environment() -> Environment:
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER
	material.set_shader_parameter("sun_direction", SUN_DIRECTION)
	var sky := Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	# Senja yang terang: cahaya sekitar biru lavender, bukan biru malam pekat.
	# Sedikit lebih dingin dan lebih redup dari siang hari supaya terbaca SENJA,
	# tapi jangan turun jauh: janji test_dusk adalah "bukan malam pekat".
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.61, 0.82)
	environment.ambient_light_energy = 0.52
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# Kabut jarak (bukan volumetrik): bukit jauh memucat seperti cat air, langit
	# tidak ikut berkabut supaya awan dan pendar matahari tetap tajam.
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	# Dunia sekarang pulau 1 km: bukit di kaki langit berdiri 520-1250 m dari
	# pemain. Kabut dulu berakhir di 420 m (dunia 100 m), jadi sekarang bukit itu
	# akan lenyap seluruhnya. 200-1400 m membuat pantai seberang (± 700 m) tetap
	# terlihat sementara bukit terjauh memucat seperti cat air.
	environment.fog_depth_begin = 200.0
	environment.fog_depth_end = 1400.0
	environment.fog_density = 0.20
	environment.fog_depth_curve = 1.30
	# Kabut senja menghangat: sampah cahaya matahari yang rendah.
	environment.fog_light_color = Color(0.76, 0.70, 0.80)
	environment.fog_light_energy = 0.55
	environment.fog_sky_affect = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Sedikit lebih jenuh supaya rumput tetap hijau segar di bawah cahaya hangat.
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.12
	environment.adjustment_contrast = 1.06
	# Glow (bloom) — satu-satunya efek "sinema" yang renderer Mobile dukung.
	# Yang mekar hanya bagian terang: pendar matahari, kunang-kunang ungu, dan
	# tepi bercahaya. Tanpa ini suasana senja terlihat datar seperti siang hari.
	#
	# TIGA penyetel yang menentukan apakah pendar ufuk tetap BERWARNA atau jadi
	# putih (1,1,1):
	#   - blend SOFTLIGHT (bukan ADDITIVE). ADDITIVE menambahkan cahaya ke buffer
	#     HDR, dan pengukuran CI menunjukkan pendar ufuk jadi (1,1,1) — putih
	#     murni — sehingga gerbang test_dusk "ufuk harus hangat (merah > biru)"
	#     gagal. Softlight justru melembutkan bagian terang tanpa menambah
	#     kecerahan, jadi pita persik tetap berwarna (0,98/0,90/0,93 terukur).
	#   - glow_normalized = TRUE. Dengan false, SETIAP level bloom (7 level
	#     default) menambah penuh sehingga glow bisa ~7x terlalu terang.
	#   - glow_hdr_threshold = 1,15: yang mekar hanya inti matahari (~1,3 HDR).
	environment.glow_enabled = true
	environment.glow_intensity = 0.25
	environment.glow_bloom = 0.08
	environment.glow_hdr_threshold = 1.15
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.glow_normalized = true
	return environment


static func make_sunlight() -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = "Sunlight"
	# Matahari senja: lebih jingga dan lebih kuat dari siang hari, bayangan
	# memanjang karena sudutnya rendah.
	light.light_color = Color(1.0, 0.83, 0.64)
	light.light_energy = 1.05
	light.shadow_enabled = true
	return light
