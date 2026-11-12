extends SceneTree
## Kiểm tra chuyện tuần "Bí mật cho Cô Ba" (scripts/chuyen/): dữ liệu kịch bản đủ khóa, mọi câu có bản tiếng Anh,
## tranh/thiệp có ảnh, câu cảm ơn mới cho khoảnh khắc giao, thư Hùng–Mây (+2.000đ một lần, không đụng sao),
## và giao diện phụ đề dựng được. Dùng file lưu riêng, không đụng file thật.
## Chạy: godot --headless --path . -s tests/test_chuyen.gd

const KB := preload("res://scripts/chuyen/kich_ban.gd")
const EnChuyen := preload("res://scripts/dich/en_chuyen.gd")
const HudChuyen := preload("res://scripts/chuyen/hud_chuyen.gd")
const KINDS := ["giao", "bimat", "thu", "tranh", "l1", "l5", "coba", "toast", "phim"]

var fails := 0


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  LỖI  ") + what)
	if not ok:
		fails += 1


func _en_has(s: String) -> bool:
	if EnChuyen.EN.has(s):
		return true
	for f in ["res://scripts/dich/en_choi.gd", "res://scripts/dich/en_ngay.gd", "res://scripts/dich/en_giao_dien.gd"]:
		if (load(f) as GDScript).get_script_constant_map().get("EN", {}).has(s):
			return true
	return false


func _run() -> void:
	GameState.use_test_save("user://luu_game_test_chuyen.cfg")

	print("Kịch bản")
	_check(KB.NGAY.keys() == Days.ORDER, "đủ 7 ngày theo thứ tự tuần")
	var n_lines := 0
	var thieu: Array = []
	for d: String in KB.NGAY:
		var day: Dictionary = KB.NGAY[d]
		_check((day.get("bao", []) as Array).size() == 2, "%s có tít báo + góc đếm ngược (O1)" % d)
		_check((day.get("buu", []) as Array).size() == 2, "%s có bưu thiếp 2 dòng (O2)" % d)
		for s in day.get("bao", []) + day.get("buu", []) + ([day.buu_khac] if day.has("buu_khac") else []):
			if not _en_has(s):
				thieu.append(s)
		for key in day.nhip:
			for l: Dictionary in day.nhip[key]:
				n_lines += 1
				if not (l.has("k") and l.has("ai") and l.has("c") and l.k in KINDS):
					_check(false, "%s/%s câu thiếu khóa: %s" % [d, key, l])
				if not l.get("co_san", false) and not _en_has(str(l.c)):
					thieu.append(l.c)
				if l.has("anh"):
					_check(ResourceLoader.exists("res://assets/chuyen/%s.jpg" % l.anh), "có ảnh %s" % l.anh)
				var dk := str(l.get("dk", ""))
				if dk != "":
					_check(dk == "lan" or dk.begins_with("co:") or dk.begins_with("da:"), "điều kiện hợp lệ: " + dk)
	_check(n_lines > 90, "đủ câu (%d)" % n_lines)
	_check(thieu.is_empty(), "mọi câu có bản tiếng Anh %s" % [thieu])
	for t in Chuyen.THIEP.values():
		_check(ResourceLoader.exists("res://assets/chuyen/%s.jpg" % t), "có ảnh thiệp " + t)
	for s in ["Mèo mới của Cô Ba hả? Tới đúng tuần này là hay lắm à nghen.", "Về rồi đó hả! Con mèo giữ bí mật giỏi nhất xóm!",
			"Bảng của ông Sáu treo trên cửa, thiệp của cả xóm treo cạnh Bơ."]:
		_check(_en_has(s), "có bản tiếng Anh: " + s)

	print("Câu cảm ơn khi giao (O3)")
	_check(Chuyen.cau_giao("thu_hai", 0, "x") == "Mèo giao bánh hả? Mai tui đăng hình lên báo luôn.", "Thứ Hai đơn 1 Chú Tư có câu mới")
	_check(Chuyen.cau_giao("thu_hai", 2, "x") == "x", "câu có sẵn thì giữ câu theo tính cách")
	_check(Chuyen.cau_giao("ngay_la", 0, "x") == "x", "ngày lạ không đổi gì")

	print("Thư Hùng–Mây (L3)")
	var vi0 := int(GameState.get_global("vi_tien_boa", 0))
	_check(not Chuyen.co_thu(1) and not Chuyen.da_thu(1), "chưa có thư")
	Chuyen.nhan_thu(1)
	_check(Chuyen.co_thu(1), "nhận thư 1")
	_check(Chuyen.thu_toi(1), "thư 1 tới lần đầu")
	_check(int(GameState.get_global("vi_tien_boa", 0)) == vi0 + Chuyen.THU_BOA, "+2.000đ")
	_check(Chuyen.da_thu(1) and Chuyen.co_thu(2), "Mây gửi lại thư 2")
	_check(not Chuyen.thu_toi(1) and int(GameState.get_global("vi_tien_boa", 0)) == vi0 + Chuyen.THU_BOA, "giao lại không cộng thêm")
	_check(GameState.SAVE_KEYS.has(Chuyen.THU_KEY), "khóa lưu đã đăng ký")

	print("Giao diện")
	var ui: CanvasLayer = HudChuyen.new()
	root.add_child(ui)
	await process_frame
	ui.noi("Chị Mây", "Suỵt, Bơ. Chủ Nhật này lò bánh Cô Ba tròn 30 năm.", "bimat")
	ui.noi("", "Tranh thứ hai: Bơ ôm túi trứng, trứng to hơn đầu Bơ.", "tranh", "tranh_2")
	ui.hoi(1)
	ui.bao("Thứ Hai", "LÒ BÁNH CÔ BA CÓ PHỤ VIỆC MỚI?", "Còn 6 ngày ★", 1.0)
	ui.buu_thiep("dòng 1", "dòng 2", "3 chữ ký", "thiep_trong_3")
	await process_frame
	_check(ui.dang_noi(), "phụ đề đang hiện")
	ui.an()
	_check(not ui.dang_noi(), "tắt phụ đề")
	ui.queue_free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://luu_game_test_chuyen.cfg"))
	print("CHUYEN TEST OK" if fails == 0 else "CHUYEN TEST FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
