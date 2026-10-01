extends RefCounted
## Katalog LENGKAP animasi mannequin: seluruh isi UAL1_Standard.glb (43 klip) dan
## UAL2_Standard.glb (43 klip) = 85 nama unik (A_TPose ada di kedua berkas).
## Setiap entri menyimpan label, keterangan, sumber berkas, mode loop, dan apakah
## klip punya dorongan maju (gait) sehingga kecepatan alaminya bisa diukur.
##
## Urutan array flags: "loop" (diputar berulang), "once" (sekali lalu kembali),
## "hold" (berhenti di frame terakhir), "gait" (siklus gerak maju).

const UAL1 := "ual1"
const UAL2 := "ual2"

const GROUPS := [
	{
		"id": "diam",
		"label": "Diam & Pose",
		"clips": [
			["A_TPose", "Pose T", UAL1, "loop",
				"Pose referensi T-pose; berguna untuk memeriksa rig."],
			["Idle_Loop", "Diam santai", UAL1, "loop",
				"Napas pelan berdiri; loop 2,5 s. Dipakai saat berhenti."],
			["Idle_Talking_Loop", "Diam mengobrol", UAL1, "loop",
				"Berdiri sambil gestur bicara ringan."],
			["Idle_Torch_Loop", "Diam memegang obor", UAL1, "loop",
				"Berdiri dengan obor di tangan kanan."],
			["Idle_FoldArms_Loop", "Diam melipat tangan", UAL2, "loop",
				"Berdiri tegap dengan tangan terlipat."],
			["Idle_Lantern_Loop", "Diam memegang lentera", UAL2, "loop",
				"Berdiri sambil menggoyang lentera."],
			["Idle_No_Loop", "Diam menggeleng", UAL2, "loop",
				"Berdiri lalu menggeleng pelan sebagai isyarat tidak."],
			["Idle_Rail_Call", "Diam menunggu kereta", UAL2, "once",
				"Melihat jauh sambil melambai memanggil."],
			["Idle_Rail_Loop", "Diam di peron", UAL2, "loop",
				"Berdiri santai menunggu, loop tenang."],
			["Idle_TalkingPhone_Loop", "Diam menelepon", UAL2, "loop",
				"Berdiri sambil memegang telepon ke telinga."],
			["Yes", "Mengangguk setuju", UAL2, "once",
				"Anggukan tegas tanda setuju; sekali lalu kembali."],
			["Dance_Loop", "Menari", UAL1, "loop",
				"Goyangan dansa pendek 1 s yang mengulang."],
			["Sword_Idle", "Diam memegang pedang", UAL1, "loop",
				"Kuda-kuda siaga dengan pedang terhunus."],
		],
	},
	{
		"id": "gerak",
		"label": "Jalan, Lari & Geser",
		"clips": [
			["Walk_Loop", "Jalan santai", UAL1, "gait",
				"Siklus jalan 1,33 s; kecepatan alami diukur otomatis."],
			["Walk_Formal_Loop", "Jalan formal", UAL1, "gait",
				"Langkah rapi dan lambat, seperti jalan resmi."],
			["Jog_Fwd_Loop", "Joging", UAL1, "gait",
				"Lari santai 0,93 s per siklus; dipakai untuk kecepatan sedang."],
			["Sprint_Loop", "Lari cepat", UAL1, "gait",
				"Sprint 0,67 s per siklus; dipakai pada kecepatan tertinggi."],
			["Walk_Carry_Loop", "Jalan membawa", UAL2, "gait",
				"Jalan pelan sambil membawa barang di depan badan."],
			["Zombie_Walk_Fwd_Loop", "Jalan zombie", UAL2, "gait",
				"Langkah terseret khas zombie."],
			["Crouch_Fwd_Loop", "Merangkak maju", UAL1, "gait",
				"Berjalan jongkok menuju depan, lambat dan hati-hati."],
			["Crouch_Idle_Loop", "Diam jongkok", UAL1, "loop",
				"Bertahan dalam posisi jongkok."],
			["Slide_Start", "Mulai meluncur", UAL2, "once",
				"Awal gerakan menggeser rendah ke tanah."],
			["Slide_Loop", "Meluncur", UAL2, "loop",
				"Posisi meluncur rendah yang ditahan."],
			["Slide_Exit", "Selesai meluncur", UAL2, "once",
				"Bangkit kembali berdiri setelah meluncur."],
		],
	},
	{
		"id": "lompat",
		"label": "Lompat & Akrobat",
		"clips": [
			["Jump_Start", "Awal lompat", UAL1, "once",
				"Jongkok lalu menolak; dipakai saat tombol lompat ditekan."],
			["Jump_Loop", "Melayang di udara", UAL1, "loop",
				"Pose bertahan saat badan berada di udara."],
			["Jump_Land", "Mendarat", UAL1, "once",
				"Menyerap hentakan mendarat lalu berdiri."],
			["Roll", "Berguling", UAL1, "once",
				"Guling depan cepat 1,47 s."],
			["NinjaJump_Start", "Lompat ninja", UAL2, "once",
				"Tolakan lompat gaya ninja yang lebih dramatis."],
			["NinjaJump_Idle_Loop", "Melayang gaya ninja", UAL2, "loop",
				"Pose melayang dengan kaki tertekuk."],
			["NinjaJump_Land", "Pendaratan ninja", UAL2, "once",
				"Mendarat dengan satu kaki menyentuh dulu."],
			["ClimbUp_1m", "Memanjat 1 m", UAL2, "once",
				"Mengangkat badan naik melewati tembok setinggi 1 m."],
		],
	},
	{
		"id": "tangan",
		"label": "Tangan & Interaksi",
		"clips": [
			["Punch_Jab", "Pukulan jab", UAL1, "once",
				"Jab pendek tangan depan; 0,87 s."],
			["Punch_Cross", "Pukulan cross", UAL1, "once",
				"Pukulan lurus tangan belakang dengan putaran badan."],
			["Push_Loop", "Mendorong", UAL1, "loop",
				"Mendorong benda berat, tenaga berulang."],
			["Interact", "Berinteraksi", UAL1, "once",
				"Meraih dan menekan sesuatu setinggi dada."],
			["PickUp_Table", "Mengambil barang", UAL1, "once",
				"Membungkuk mengambil benda dari meja."],
			["Chest_Open", "Membuka peti", UAL2, "once",
				"Menutup lalu membuka tutup peti di depan."],
			["Consume", "Makan / minum", UAL2, "once",
				"Menyuap sesuatu ke mulut lalu menelan."],
			["OverhandThrow", "Melempar", UAL2, "once",
				"Lemparan atas satu tangan, bisa untuk melempar barang."],
			["TreeChopping_Loop", "Menebang pohon", UAL2, "loop",
				"Ayunan kapak berulang ke arah pohon."],
		],
	},
	{
		"id": "pedang",
		"label": "Pedang",
		"clips": [
			["Sword_Attack", "Serangan pedang", UAL1, "once",
				"Tebasan dasar dengan langkah maju singkat."],
			["Sword_Regular_A", "Tebasan A", UAL2, "once",
				"Tebasan pertama kombo; bisa disambung ke A_Rec."],
			["Sword_Regular_A_Rec", "Pemulihan A", UAL2, "once",
				"Mengembalikan pedang setelah tebasan A."],
			["Sword_Regular_B", "Tebasan B", UAL2, "once",
				"Tebasan kedua, arah berlawanan."],
			["Sword_Regular_B_Rec", "Pemulihan B", UAL2, "once",
				"Pemulihan setelah tebasan B."],
			["Sword_Regular_C", "Tebasan C", UAL2, "once",
				"Tebasan penutup kombo 2 s."],
			["Sword_Regular_Combo", "Kombo pedang", UAL2, "once",
				"Rangkaian tiga tebasan sekaligus, 3 s."],
			["Sword_Heavy_Combo", "Kombo berat", UAL2, "once",
				"Kombo panjang 4,33 s dengan putaran badan penuh."],
			["Sword_Block", "Menangkis", UAL2, "once",
				"Menahan serangan dengan pedang di depan dada."],
			["Sword_Dash", "Serangan menerjang", UAL2, "once",
				"Menerjang ke depan sambil menebas."],
		],
	},
	{
		"id": "perisai",
		"label": "Perisai",
		"clips": [
			["Idle_Shield_Loop", "Diam berperisai", UAL2, "loop",
				"Berdiri siaga dengan perisai terangkat."],
			["Idle_Shield_Break", "Perisai terpukul", UAL2, "once",
				"Perisai terlempar ke belakang lalu pulih."],
			["Shield_Dash", "Menerjang perisai", UAL2, "once",
				"Menerjang maju sambil menahan perisai."],
			["Shield_OneShot", "Tebasan perisai", UAL2, "once",
				"Ayunan perisai satu kali."],
		],
	},
	{
		"id": "tempur",
		"label": "Tempur & Reaksi",
		"clips": [
			["Melee_Hook", "Pukulan hook", UAL2, "once",
				"Hook cepat 0,47 s dari sisi badan."],
			["Melee_Hook_Rec", "Pemulihan hook", UAL2, "once",
				"Menarik tangan kembali setelah hook."],
			["Zombie_Scratch", "Cakaran zombie", UAL2, "once",
				"Cakaran dua tangan khas zombie."],
			["Hit_Head", "Terkena kepala", UAL1, "once",
				"Kepala terpukul ke belakang, 0,43 s."],
			["Hit_Chest", "Terkena dada", UAL1, "once",
				"Badan terpukul dan terhuyung singkat."],
			["Hit_Knockback", "Terpental", UAL2, "once",
				"Terpental ke belakang lalu jatuh 0,83 s."],
			["Death01", "Mati", UAL1, "hold",
				"Jatuh tersungkur 2,4 s dan berhenti di lantai."],
			["LayToIdle", "Bangun dari berbaring", UAL2, "once",
				"Dari posisi berbaring bangkit ke berdiri."],
		],
	},
	{
		"id": "senjata",
		"label": "Senjata Api & Sihir",
		"clips": [
			["Pistol_Aim_Down", "Bidik bawah", UAL1, "loop",
				"Pose bidik ke arah bawah."],
			["Pistol_Aim_Neutral", "Bidik lurus", UAL1, "loop",
				"Pose bidik ke depan lurus."],
			["Pistol_Aim_Up", "Bidik atas", UAL1, "loop",
				"Pose bidik ke arah atas."],
			["Pistol_Idle_Loop", "Diam memegang pistol", UAL1, "loop",
				"Berdiri siaga dengan pistol."],
			["Pistol_Reload", "Isi ulang pistol", UAL1, "once",
				"Melepas magasin dan memasang yang baru."],
			["Pistol_Shoot", "Menembak", UAL1, "once",
				"Satu tembakan dengan hentakan tangan."],
			["Spell_Simple_Enter", "Mulai sihir", UAL1, "once",
				"Mengangkat tangan untuk mulai merapal."],
			["Spell_Simple_Idle_Loop", "Diam merapal", UAL1, "loop",
				"Menahan pose sihir dengan tangan terangkat."],
			["Spell_Simple_Shoot", "Melepas sihir", UAL1, "once",
				"Lepasan sihir 0,5 s; juga dipakai lapisan tubuh atas pet api."],
			["Spell_Simple_Exit", "Selesai sihir", UAL1, "once",
				"Menurunkan tangan dan kembali santai."],
		],
	},
	{
		"id": "duduk",
		"label": "Duduk & Pekerjaan",
		"clips": [
			["Sitting_Enter", "Mulai duduk", UAL1, "once",
				"Turun ke posisi duduk di lantai."],
			["Sitting_Idle_Loop", "Duduk diam", UAL1, "loop",
				"Duduk tenang sambil bernapas."],
			["Sitting_Talking_Loop", "Duduk mengobrol", UAL1, "loop",
				"Duduk sambil bercakap dan bergestur."],
			["Sitting_Exit", "Bangkit dari duduk", UAL1, "once",
				"Berdiri kembali dari posisi duduk."],
			["Fixing_Kneeling", "Memperbaiki sambil berlutut", UAL1, "once",
				"Berlutut mengerjakan sesuatu di lantai, 5,2 s."],
			["Driving_Loop", "Menyetir", UAL1, "loop",
				"Tangan di kemudi dan kaki bekerja, loop mengemudi."],
		],
	},
	{
		"id": "renang",
		"label": "Renang",
		"clips": [
			["Swim_Idle_Loop", "Diam di air", UAL1, "loop",
				"Berusaha bertahan di permukaan air."],
			["Swim_Fwd_Loop", "Renang maju", UAL1, "gait",
				"Gaya bebas menuju depan."],
		],
	},
	{
		"id": "tani",
		"label": "Pertanian",
		"clips": [
			["Farm_Harvest", "Panen", UAL2, "once",
				"Membungkuk memanen tanaman."],
			["Farm_PlantSeed", "Menanam benih", UAL2, "once",
				"Jongkok menanam lalu menutup tanah."],
			["Farm_Watering", "Menyiram", UAL2, "once",
				"Menyiram tanaman dengan gembor, 3,8 s."],
		],
	},
	{
		"id": "zombie",
		"label": "Zombie",
		"clips": [
			["Zombie_Idle_Loop", "Diam zombie", UAL2, "loop",
				"Berdiri miring dengan tangan menjuntai."],
		],
	},
]

const LOOPS := ["loop", "gait"]
const HOLDS := ["hold"]


static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for group: Dictionary in GROUPS:
		var category: String = group["id"]
		var category_label: String = group["label"]
		for item: Array in group["clips"]:
			result.append({
				"name": item[0],
				"label": item[1],
				"source": item[2],
				"flags": item[3],
				"desc": item[4],
				"category": category,
				"category_label": category_label,
			})
	return result


static func clip_count() -> int:
	var total := 0
	for group: Dictionary in GROUPS:
		total += (group["clips"] as Array).size()
	return total


static func find(clip: String) -> Dictionary:
	for entry in entries():
		if entry["name"] == clip:
			return entry
	return {}


static func names() -> PackedStringArray:
	var result := PackedStringArray()
	for entry in entries():
		result.append(entry["name"])
	return result


static func label_for(clip: String) -> String:
	var entry := find(clip)
	return entry["label"] if not entry.is_empty() else clip


static func is_loop(clip: String) -> bool:
	var entry := find(clip)
	if entry.is_empty():
		return true
	return LOOPS.has(entry["flags"])


static func holds_last_frame(clip: String) -> bool:
	var entry := find(clip)
	return not entry.is_empty() and HOLDS.has(entry["flags"])


static func is_gait(clip: String) -> bool:
	var entry := find(clip)
	return not entry.is_empty() and entry["flags"] == "gait"


static func play_name(clip: String) -> String:
	# Klip UAL2 berada di pustaka bernama "ual2" pada AnimationPlayer yang sama.
	var entry := find(clip)
	if entry.is_empty() or entry["source"] == UAL1:
		return clip
	return "ual2/" + clip
