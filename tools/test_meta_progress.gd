extends SceneTree
## Tes koin, harga bertahap, penyimpanan lokal, dan panel upgrade atribut.

const MetaProgress = preload("res://src/game/survival/meta_progress.gd")
const UpgradeMenu = preload("res://src/game/ui/attribute_upgrade_menu.gd")
const TEST_SAVE_PATH := "user://survival_meta_test.cfg"

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
	print("::error::", message)


func _run() -> void:
	_remove_test_save()
	var progress := MetaProgress.new(TEST_SAVE_PATH)
	_check(progress.call("get_upgrades").size() >= 12,
		"Panel meta belum punya banyak pilihan upgrade")
	_check(progress.call("upgrade_cost", "damage") == 50,
		"Harga level awal tidak sesuai nilai dasar yang ringan")
	_check(not bool(progress.call("purchase_upgrade", "unknown")),
		"Upgrade ID yang tidak dikenal berhasil dibeli")
	_check(not bool(progress.call("purchase_upgrade", "damage")),
		"Upgrade bisa dibeli tanpa koin")
	progress.call("add_coins", 2400)
	var starting_balance := int(progress.get("coins"))
	_check(bool(progress.call("purchase_upgrade", "damage")),
		"Pembelian upgrade pertama gagal")
	_check(int(progress.get("coins")) == starting_balance - 50
		and int(progress.call("get_upgrade_level", "damage")) == 1,
		"Pembelian tidak mengurangi koin/menaikkan level")
	var second_cost := int(progress.call("upgrade_cost", "damage"))
	_check(second_cost > 50 and second_cost <= 66,
		"Harga upgrade naik terlalu ekstrem: %d" % second_cost)
	_check(bool(progress.call("purchase_upgrade", "damage")),
		"Pembelian upgrade level kedua gagal")
	var modifiers: Dictionary = progress.call("get_modifiers")
	_check(float(modifiers.get("damage_multiplier", 1.0)) > 1.03,
		"Peningkatan damage tidak diterapkan ke modifier meta")

	var max_health_definition: Dictionary
	for upgrade: Dictionary in progress.call("get_upgrades"):
		if str(upgrade.get("id", "")) == "max_health":
			max_health_definition = upgrade
	_check(not max_health_definition.is_empty(), "Upgrade HP maksimum tidak tersedia")
	while int(progress.call("get_upgrade_level", "max_health")) \
			< int(max_health_definition.get("max_level", 0)):
		if not bool(progress.call("purchase_upgrade", "max_health")):
			break
	_check(int(progress.call("get_upgrade_level", "max_health"))
		<= int(max_health_definition.get("max_level", 0)),
		"Level upgrade HP melewati batas")
	_check(not bool(progress.call("purchase_upgrade", "max_health")),
		"Upgrade maksimum masih bisa dibeli")
	progress.call("save")

	var menu := UpgradeMenu.new()
	menu.set("meta_progress", progress)
	root.add_child(menu)
	await process_frame
	menu.call("open")
	var grid: GridContainer = menu.get("_grid")
	var coin_label: Label = menu.get("_coins_label")
	_check(menu.visible and grid != null and grid.get_child_count() >= 12,
		"Panel upgrade tidak merender daftar atribut")
	_check(coin_label != null and coin_label.text.contains("KOIN"),
		"Panel upgrade tidak menampilkan saldo koin")
	menu.call("_purchase_upgrade", "move_speed")
	_check(int(progress.call("get_upgrade_level", "move_speed")) == 1,
		"Tombol upgrade UI tidak membeli atribut")

	var restored := MetaProgress.new(TEST_SAVE_PATH)
	_check(int(restored.get("coins")) == int(progress.get("coins")),
		"Saldo koin tidak bertahan setelah dibaca ulang")
	_check(int(restored.call("get_upgrade_level", "damage")) == 2
		and int(restored.call("get_upgrade_level", "max_health"))
			== int(max_health_definition.get("max_level", 0)),
		"Level atribut tidak tersimpan setelah dibaca ulang")
	menu.queue_free()
	await process_frame
	_remove_test_save()
	print("[meta-progress-test] pilihan=%d koin=%d gagal=%d" % [
		progress.call("get_upgrades").size(), restored.get("coins"), _failures])
	quit(0 if _failures == 0 else 1)


func _remove_test_save() -> void:
	var path := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
