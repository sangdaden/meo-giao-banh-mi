extends SceneTree
## Kiểm tra gói tải sau của bản web (Q1, scripts/goi_web.gd): không có danh sách gói (bản desktop) thì mọi
## thứ chạy thẳng; có gói thì GoiWeb.then hiện màn chờ, nạp gói rồi mới gọi tiếp; ngày nào cần gói nào;
## tủ đồ chưa về thì không làm mất giống mèo đang mặc. Phần tải HTTP chỉ chạy trên web, ở đây gói đã nằm
## sẵn trong user://goi/ như lần mở game thứ hai.
## Chạy: godot --headless --path . -s tests/test_goi_web.gd

var fails := 0


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  LỖI  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _screens() -> int:
	return root.get_children().filter(func(n: Node) -> bool: return n is ManChoTai and not n.is_queued_for_deletion()).size()


func _run() -> void:
	print("Không có gói (desktop)")
	_check(GoiWeb.manifest().is_empty(), "bản chạy từ thư mục project không có res://goi_web.json")
	_check(GoiWeb.for_day("thu_ba").is_empty(), "vào Thứ Ba không phải chờ gói nào")
	var called := [false]
	GoiWeb.then(["thu_ba"] as Array[String], func(): called[0] = true)
	_check(called[0], "GoiWeb.then gọi tiếp ngay")

	print("Có gói")
	var src := "user://test_goi_web_src.txt"
	var f := FileAccess.open(src, FileAccess.WRITE)
	f.store_string("banh mi")
	f.close()
	var tmp := "user://test_goi_web.pck"
	var pk := PCKPacker.new()
	pk.pck_start(tmp)
	pk.add_file("res://goi_thu/banh.txt", src)
	pk.flush()
	var bytes := FileAccess.get_file_as_bytes(tmp)
	var md5 := FileAccess.get_md5(tmp)
	GoiWeb._manifest = {
		"thu_ba": {"file": "goi/thu_ba.pck", "size": bytes.size(), "md5": md5},
		"tu_do": {"file": "goi/tu_do.pck", "size": 999, "md5": "0123456789abcdef"},
	}
	DirAccess.make_dir_recursive_absolute(GoiWeb.DIR)
	DirAccess.copy_absolute(tmp, GoiWeb._local("thu_ba"))
	_check(Array(GoiWeb.for_day("thu_ba")) == ["thu_ba"], "Thứ Ba cần gói thu_ba")
	_check("tu_do" in GoiWeb.for_day("thu_bay"), "Thứ Bảy cần thêm gói tủ đồ")
	_check(not "thu_hai" in GoiWeb.for_day("thu_hai"), "Thứ Hai không có gói riêng")
	_check(not FileAccess.file_exists("res://goi_thu/banh.txt"), "chưa nạp thì chưa thấy file trong gói")

	called[0] = false
	GoiWeb.then(["thu_ba"] as Array[String], func(): called[0] = true)
	_check(_screens() == 1 and not called[0], "đang nạp thì hiện màn chờ, chưa gọi tiếp")
	await _frames(10)
	_check(called[0], "nạp xong gói thì gọi tiếp")
	_check(FileAccess.get_file_as_string("res://goi_thu/banh.txt") == "banh mi", "file trong gói đọc được qua res://")
	_check(GoiWeb.loaded("thu_ba") and GoiWeb.for_day("thu_ba").is_empty(), "nạp rồi thì lần sau không chờ")
	_check(_screens() == 0, "màn chờ đã đóng")

	print("Tủ đồ chưa về")
	_check(GoiWeb.pending("tu_do"), "gói tủ đồ còn chờ")
	var cfg := ConfigFile.new()
	var had := cfg.load(Outfit.PATH) == OK
	var keep := ConfigFile.new()
	keep.load(Outfit.PATH)
	cfg.set_value("giong", "dang_dung", "xiem")
	cfg.save(Outfit.PATH)
	Outfit._loaded = false
	_check(Outfit.breed() == "xiem", "giống đang mặc giữ nguyên khi model còn trong gói tủ đồ")
	_check(GoiWeb.wears_skin(), "Bơ mặc giống khác thì ngày nào cũng cần gói tủ đồ")
	if had:
		keep.save(Outfit.PATH)
	else:
		DirAccess.remove_absolute(Outfit.PATH)
	Outfit._loaded = false

	for p in [src, tmp, GoiWeb._local("thu_ba")]:
		DirAccess.remove_absolute(p)
	print("GOI WEB TEST OK" if fails == 0 else "GOI WEB TEST FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
