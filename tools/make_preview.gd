extends SceneTree
## Perkecil screenshot hasil tes jadi JPEG kecil untuk pratinjau CI.
##
## Dipakai langkah "Pratinjau render": artefak GitHub tidak bisa diunduh dari
## luar CI (blob storage diblokir) dan anotasi hanya memuat teks, jadi gambar
## dikecilkan lalu ditempel sebagai base64 di komentar commit. Godot dipakai
## sebagai pengolah gambar supaya tidak perlu ImageMagick/PIL di runner.
##
## Pakai: godot --headless --path project --script tools/make_preview.gd -- <dir> [lebar]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("make_preview: butuh direktori masukan")
		quit(1)
		return
	var dir := args[0]
	var width := int(args[1]) if args.size() > 1 else 560
	var folder := DirAccess.open(dir)
	if folder == null:
		push_error("make_preview: direktori tidak bisa dibuka: " + dir)
		quit(1)
		return
	var count := 0
	for file in folder.get_files():
		if not file.ends_with(".png"):
			continue
		var source := Image.load_from_file(dir.path_join(file))
		if source == null:
			continue
		var target := source.duplicate() as Image
		if target.get_width() > width:
			var height := int(round(float(target.get_height()) * width / target.get_width()))
			target.resize(width, maxi(height, 1), Image.INTERPOLATE_BILINEAR)
		target.convert(Image.FORMAT_RGB8)
		var out := dir.path_join(file.get_basename() + ".jpg")
		target.save_jpg(out, 0.62)
		print("[preview] ", out, " ", target.get_width(), "x", target.get_height())
		count += 1
	print("[preview] %d gambar" % count)
	quit(0)
