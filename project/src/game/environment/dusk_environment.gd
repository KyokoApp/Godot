extends RefCounted
## Preset dunia MALAM: langit biru tua berbintang dan berbulan, cahaya bulan biru
## bulan biru dingin, kabut tipis gelap, dan tanah yang tetap terbaca (bukan hitam
## pekat). Nama berkas masih "dusk" karena sejarah cicilan 8; isinya sudah malam.
##
## Dipakai bersama oleh permainan (main.gd), warmup shader, dan tes render, jadi
## warna di layar dan warna di gambar tes tidak pernah berbeda.

const SKY_SHADER = preload("res://src/game/environment/dusk_sky.gdshader")
## Arah BULAN: sekitar 20 derajat di atas ufuk barat daya (sisi laut). Tetap
## dekat horizon, namun sedikit lebih tinggi agar bayangan tidak memanjang
## berlebihan dan arah cahayanya terbaca jelas. Kamera tidak perlu menengadah.
## Arah ini dipakai bersama langit, kilau air, dan bayangan; panjangnya 1.
const SUN_DIRECTION := Vector3(-0.8895, 0.3420, -0.3032)


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
	# Cahaya sekitar malam: biru dingin dan redup. SENGaja tidak segelap langit —
	# kalau ambient terlalu kecil, rumput dan karakter jadi siluet hitam dan
	# "indah" berubah jadi "gelap gulita". Janji test_dusk: tanah tetap terbaca.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.24, 0.32, 0.55)
	environment.ambient_light_energy = 0.40
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# Kabut jarak (bukan volumetrik): bukit jauh memucat seperti cat air, langit
	# tidak ikut berkabut supaya awan dan pendar matahari tetap tajam.
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	# Pulau utama 100 m, dengan pulau terbang tetap jauh di horizon. Kabut
	# berakhir di 420 m supaya siluet latar memudar lembut, bukan terpotong; mulai
	# setelah 45 m agar bukit pemain sendiri tetap tajam.
	environment.fog_depth_begin = 45.0
	environment.fog_depth_end = 420.0
	environment.fog_density = 0.20
	environment.fog_depth_curve = 1.30
	# Kabut malam: biru tua, jadi bukit jauh memudar menjadi siluet gelap alih-alih
	# pucat seperti cat air. Laut sejauh 2 km ikut memudar ke warna yang sama.
	environment.fog_light_color = Color(0.09, 0.13, 0.24)
	environment.fog_light_energy = 0.55
	environment.fog_sky_affect = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Sedikit lebih jenuh supaya rumput tetap hijau segar di bawah cahaya hangat.
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.02
	environment.adjustment_contrast = 1.05
	# Glow (bloom) — satu-satunya efek "sinema" yang renderer Mobile dukung.
	# Yang mekar hanya bagian terang: piringan bulan, halo bulan, bintang paling
	# terang, dan kunang-kunang ungu. Tanpa ini bulan terlihat seperti stiker
	# kertas tempel, bukan benda yang memancarkan cahaya.
	#
	# TIGA penyetel yang menentukan apakah bulan tetap BERWARNA atau jadi gepeng:
	#   - blend SOFTLIGHT (bukan ADDITIVE). ADDITIVE menambahkan cahaya ke buffer
	#     HDR; pengukuran CI di cicilan 8 menunjukkan hasilnya menyaturasi jadi
	#     putih (1,1,1). Softlight melembutkan bagian terang tanpa menambah
	#     kecerahan, jadi piringan bulan tetap berwarna.
	#   - glow_normalized = TRUE. Dengan false, SETIAP level bloom (7 level
	#     default) menambah penuh sehingga glow bisa ~7x terlalu terang.
	#   - glow_hdr_threshold = 1,15: yang mekar hanya bulan (2,4 HDR) dan bintang
	#     terang (1,7 HDR); langit malam (± 0,05 HDR) tidak ikut mekar.
	# Nilai kekuatan DIPERBESAR atas permintaan ("tambahin bloom efek"):
	# 0,30 -> 0,50 dan bloom 0,08 -> 0,18. Ambang (1,15) dan blend mode
	# (SOFTLIGHT) sengaja TIDAK diubah supaya bulan tetap berwarna — bukan gepeng
	# putih — dan langit malam tidak ikut mekar. Dua hal itu yang dulu rusak saat
	# glow dipermainkan.
	environment.glow_enabled = true
	environment.glow_intensity = 0.50
	environment.glow_bloom = 0.18
	environment.glow_hdr_threshold = 1.15
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.glow_normalized = true
	return environment


static func make_sunlight() -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = "Moonlight"
	# Cahaya bulan dingin dengan bayangan diagonal yang lebih lembut. Jarak
	# shadow map dibatasi; skyline/hills jauh tidak ikut menghitung bayangan.
	light.light_color = Color(0.68, 0.76, 0.95)
	light.light_energy = 0.50
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 96.0
	return light
