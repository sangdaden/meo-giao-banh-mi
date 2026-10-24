extends SceneTree
## File lưu có phiên bản (Q2): mở file lưu của bản trước bằng bản hiện tại.
## - mọi file mẫu tests/luu_game_cu/v<N>.cfg lên được GameState.SAVE_VERSION, giữ nguyên dữ liệu, có bản sao .bak;
## - file v0 (trước Q2): ví, tuần, ngày kế, tem, bóng mờ còn nguyên; Mực đã dán Sổ thì có trong "Bạn bốn chân";
## - khóa sai kiểu bị bỏ (dùng mặc định), số thực ở khóa số nguyên đổi về số nguyên;
## - file của bản game mới hơn: giữ nguyên, không hạ phiên bản, không mất khóa lạ;
## - file hỏng: cất thành .hong, bắt đầu file mới; chưa có file: file mới mang số phiên bản;
## - mọi khóa lưu trong scripts/ đã đăng ký trong GameState.SAVE_KEYS (thêm khóa thì tăng phiên bản, xem CLAUDE.md).
## Chạy: godot --headless --path . -s tests/test_luu_game.gd              (in "LUU GAME TEST OK")
##       godot --headless --path . -s tests/test_luu_game.gd -- --ghi-mau (ghi file mẫu phiên bản hiện tại, trước khi tăng số)

const MAU_DIR := "res://tests/luu_game_cu"
const PATH := "user://test_luu_game.cfg"

var fails := 0


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  SAI ") + what)
	if not ok:
		fails += 1


## Chép file mẫu vào user:// rồi mở bằng GameState như lúc vào game.
func _open(src_text: String) -> ConfigFile:
	for p in [PATH, PATH + ".hong"] + range(GameState.SAVE_VERSION + 2).map(func(v): return "%s.v%d.bak" % [PATH, v]):
		DirAccess.remove_absolute(p)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(src_text)
	f.close()
	GameState.save_path = PATH
	GameState._save = null
	return GameState.save_file()


func _mau_files() -> Array:
	var out := []
	for f in DirAccess.get_files_at(MAU_DIR):
		if f.begins_with("v") and f.ends_with(".cfg"):
			out.append(f)
	return out


func _run() -> void:
	var v0_text := FileAccess.get_file_as_string(MAU_DIR + "/v0.cfg")
	_check(v0_text != "", "có file mẫu v0.cfg")

	if "--ghi-mau" in OS.get_cmdline_user_args():
		var cf := _open(v0_text)
		var out := ProjectSettings.globalize_path("%s/v%d.cfg" % [MAU_DIR, GameState.SAVE_VERSION])
		print("ghi ", out, ": ", error_string(cf.save(out)))
		quit()
		return

	print("File v0 (bản trước Q2):")
	var cf := _open(v0_text)
	_check(GameState.version_of(cf) == GameState.SAVE_VERSION, "lên phiên bản %d" % GameState.SAVE_VERSION)
	_check(FileAccess.file_exists(PATH + ".v0.bak"), "giữ bản sao .v0.bak")
	var on_disk := ConfigFile.new()
	on_disk.load(PATH)
	_check(GameState.version_of(on_disk) == GameState.SAVE_VERSION, "file trên đĩa đã ghi số phiên bản")
	_check(Shop.wallet() == 73000, "ví tiền boa còn 73.000đ")
	_check(Shop.total_stars() == 61, "tổng sao còn 61")
	_check(PlayMode.week() == 2 and PlayMode.current_day() == "chu_nhat", "tuần 2, chơi tiếp Chủ Nhật")
	_check(GameState.stamps_all() == 3, "3 tem Thứ Hai")
	_check(Shop.owned("kinhram") and "khanlen" in Shop.wishlist(), "đồ đã mua và để dành")
	_check(Tiem.shown("chau_mai"), "chậu mai còn bày ở tiệm")
	var ghosts: Dictionary = GameState.get_day("bong_mo", {}, "thu_hai")
	_check(ghosts.has(0) and (ghosts[0] as PackedVector3Array).size() == 3, "bóng mờ đơn 1 còn đường chạy")
	_check(GameState.get_day("ky_luc_don", [], "thu_hai")[0] == 41.2, "kỷ lục đơn 1 còn 41,2 s")
	_check((GameState.get_day("ky_luc", {}, "chu_nhat") as Dictionary).get("dua_mai") == 31.4, "kỷ lục đua mái Hội mèo")
	_check(GameState.get_global("ban_bon_chan", []) == ["ga", "bo_cau", "muc"], "đã dán trang Mực → Mực vào Bạn bốn chân")
	_check(ConVat.met("muc") and ConVat.met("ga"), "ConVat thấy Mực và gà")
	GameState.set_global("vi_tien_boa", 74000)
	GameState.write_save()
	on_disk.load(PATH)
	_check(on_disk.get_value("chung", "vi_tien_boa") == 74000 and on_disk.get_value("thu_hai", "sao_bep") == 2,
		"lưu tiếp sau khi chuyển đổi")

	print("Mọi file mẫu của bản trước:")
	var files := _mau_files()
	for v in GameState.SAVE_VERSION:
		_check("v%d.cfg" % v in files, "có file mẫu v%d.cfg" % v)
	for f in files:
		var orig := ConfigFile.new()
		orig.load(MAU_DIR + "/" + f)
		var got := _open(FileAccess.get_file_as_string(MAU_DIR + "/" + f))
		var same := true
		for sec in orig.get_sections():
			for key in orig.get_section_keys(sec):
				if sec != GameState.VERSION_SECTION and got.get_value(sec, key) != orig.get_value(sec, key) \
						and not (sec == "chung" and key == "ban_bon_chan"):
					same = false
					print("    khác: [%s] %s" % [sec, key])
		_check(GameState.version_of(got) == GameState.SAVE_VERSION and same, "%s mở được, giữ nguyên dữ liệu" % f)

	print("Khóa sai kiểu:")
	cf = _open("[luu_game]\nphien_ban=%d\n[chung]\nvi_tien_boa=\"nhieu lam\"\ntuan=3.0\nda_mua=\"kinhram\"\nkhoa_la=5\n"
		% GameState.SAVE_VERSION)
	_check(Shop.wallet() == 0 and not cf.has_section_key("chung", "vi_tien_boa"), "ví chữ → bỏ, ví 0đ")
	_check(typeof(cf.get_value("chung", "tuan")) == TYPE_INT and PlayMode.week() == 3, "tuan 3.0 → 3")
	_check(Shop.bought() == [], "da_mua sai kiểu → danh sách rỗng")
	_check(cf.get_value("chung", "khoa_la") == 5, "khóa lạ giữ nguyên")

	print("File của bản mới hơn:")
	var newer := GameState.SAVE_VERSION + 1
	cf = _open("[luu_game]\nphien_ban=%d\n[chung]\nvi_tien_boa=5000\nda_mua={\"kieu_moi\": 1}\nkhoa_moi=[1, 2]\n" % newer)
	_check(GameState.save_from_newer, "nhận ra file mới hơn")
	GameState.write_save()
	on_disk.load(PATH)
	_check(GameState.version_of(on_disk) == newer, "không hạ phiên bản")
	_check(on_disk.get_value("chung", "khoa_moi") == [1, 2] and on_disk.get_value("chung", "da_mua") is Dictionary,
		"không mất, không bỏ khóa của bản mới")
	_check(Shop.wallet() == 5000, "vẫn đọc được ví")

	print("File hỏng / chưa có file:")
	cf = _open("[chung\nvi_tien_boa=====\n")
	_check(FileAccess.file_exists(PATH + ".hong"), "cất file hỏng thành .hong")
	_check(GameState.version_of(cf) == GameState.SAVE_VERSION and Shop.wallet() == 0, "bắt đầu file mới")
	DirAccess.remove_absolute(PATH)
	GameState._save = null
	_check(GameState.version_of(GameState.save_file()) == GameState.SAVE_VERSION, "file mới mang số phiên bản")
	GameState.use_test_save(PATH)
	_check(GameState.version_of(GameState.save_file()) == GameState.SAVE_VERSION, "use_test_save mang số phiên bản")

	print("Khóa lưu đã đăng ký:")
	var used := {}
	_scan("res://scripts", used)
	var missing := used.keys().filter(func(k): return not GameState.SAVE_KEYS.has(k))
	for k in missing:
		print("    chưa đăng ký: \"%s\" (%s) → thêm vào GameState.SAVE_KEYS, tăng SAVE_VERSION" % [k, used[k]])
	_check(used.size() > 20 and missing.is_empty(), "%d khóa trong scripts/ đều có trong SAVE_KEYS" % used.size())
	var bad := GameState.SAVE_KEYS.keys().filter(func(k):
		var s: Array = GameState.SAVE_KEYS[k]
		return s.size() != 3 or not s[1] in ["chung", "ngay"] or int(s[2]) > GameState.SAVE_VERSION)
	_check(bad.is_empty(), "SAVE_KEYS đúng dạng [kiểu, chung|ngay, phiên bản ≤ %d] %s" % [GameState.SAVE_VERSION, bad])

	for p in [PATH, PATH + ".hong", PATH + ".v0.bak"]:
		DirAccess.remove_absolute(p)
	print("LUU GAME TEST OK" if fails == 0 else "LUU GAME TEST FAIL (%d)" % fails)
	quit(1 if fails else 0)


## Gom khóa lưu viết thẳng trong code: GameState.get_day/set_day/get_global/set_global("khóa"…)
## và const SAVE_KEY := "khóa" ở file gọi GameState bằng SAVE_KEY.
func _scan(dir: String, used: Dictionary) -> void:
	var call := RegEx.create_from_string("(?:^|[^.\\w]|GameState\\.)(?:get|set)_(?:day|global)\\(\\s*\"(\\w+)\"")
	var konst := RegEx.create_from_string("const SAVE_KEY := \"(\\w+)\"")
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd"):
			continue
		var path := dir + "/" + f
		var text := FileAccess.get_file_as_string(path)
		for m in call.search_all(text):
			used[m.get_string(1)] = path
		if "_day(SAVE_KEY" in text or "_global(SAVE_KEY" in text:
			for m in konst.search_all(text):
				used[m.get_string(1)] = path
	for d in DirAccess.get_directories_at(dir):
		_scan(dir + "/" + d, used)
