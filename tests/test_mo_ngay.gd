extends SceneTree
## GC1 + GC5 + bản demo W2: ngày mở theo thứ tự, "Mở hết các ngày", "Mới mở!" chỉ hiện một lần,
## bản demo chỉ có Thứ Hai và Thứ Ba, thẻ nhắc ở màn kết ngày (món để dành, ngày mai có gì mới).
## Chạy: godot --headless --path . -s tests/test_mo_ngay.gd
## In "MO NGAY TEST OK" và thoát mã 0 nếu mọi tình huống đúng.

var fails := 0
## Nạp lúc chạy (không dùng class_name) để script test biên dịch được trước khi autoload Sound có mặt.
var LS: Script
var NK: Script


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	LS = load("res://scripts/ui/level_select.gd")
	NK = load("res://scripts/ui/nhac_ket_ngay.gd")
	GameState.use_test_save("user://test_mo_ngay.cfg")
	GameSettings.set_value("mo_het_ngay", false)
	GameSettings.set_value("mo_khoa_da_xem", "")
	var week := Days.ORDER.filter(func(d): return Days.playable(d))

	# GC1: hồ sơ mới chỉ mở Thứ Hai
	_check("hồ sơ mới: Thứ Hai mở", Days.unlocked("thu_hai"))
	_check("hồ sơ mới: các ngày sau còn khóa", week.slice(1).all(func(d): return not Days.unlocked(d)))
	_check("hồ sơ mới: chưa có ngày nào 'Mới mở!'", week.all(func(d): return not LS.just_unlocked(d)))

	# Chơi xong Thứ Hai thì Thứ Ba mở và hiện "Mới mở!"
	GameState.set_day("so_lan_choi", 1, "thu_hai")
	_check("xong Thứ Hai thì Thứ Ba mở", Days.unlocked("thu_ba"))
	_check("ngày sau Thứ Ba vẫn khóa", week.slice(2).all(func(d): return not Days.unlocked(d)))
	_check("Thứ Ba hiện 'Mới mở!'", LS.just_unlocked("thu_ba"))
	LS._mark_seen("thu_ba")
	_check("xem rồi thì không nhấp nháy nữa", not LS.just_unlocked("thu_ba"))

	# Mở hết các ngày (người chơi thử)
	GameSettings.set_value("mo_het_ngay", true)
	_check("Mở hết các ngày: mọi ngày đã làm đều mở", week.all(func(d): return Days.unlocked(d)))
	_check("Mở hết các ngày: không ngày nào 'Mới mở!'", week.all(func(d): return not LS.just_unlocked(d)))
	GameSettings.set_value("mo_het_ngay", false)

	# Màn Chọn màn dựng được với ngày khóa (không còn PREVIEW Thứ Năm)
	var ls: Node = LS.new()
	root.add_child(ls)
	await process_frame
	ls.open()
	for d in Days.ORDER:
		ls._select(d, false)
	_check("Chọn màn: Thứ Năm khóa thì hiện 'Chưa mở', không còn nút leo thử riêng",
		_has_text(_after_select(ls, "thu_nam"), "Chưa mở") and not _has_text(ls._detail, "Leo chung cư"))
	ls.queue_free()

	# GC5: thẻ nhắc màn kết ngày
	GameState.set_global("vi_tien_boa", 10000)
	GameState.set_global("de_danh", ["kinhram"])  # 15.000đ
	var w: Dictionary = NK.wish_line()
	_check("để dành kính râm: còn thiếu 5.000đ (%s)" % w.get("text", ""), str(w.get("text", "")).contains("5.000đ"))
	GameState.set_global("vi_tien_boa", 20000)
	_check("đủ tiền thì báo mua được", str(NK.wish_line().get("text", "")).begins_with("Đủ tiền"))
	GameState.set_global("de_danh", [])
	_check("không để dành gì thì không nhắc", NK.wish_line().is_empty())
	var n: Dictionary = NK.next_line("thu_hai")
	_check("hết Thứ Hai nhắc Thứ Ba có gì mới (%s)" % n.get("head", ""),
		str(n.get("head", "")).contains("Thứ Ba") and str(n.get("body", "")).contains("Chợ"))
	_check("ngày ngoài tuần không nhắc ngày mai", NK.next_line("day_choi").is_empty())
	_check("ngày nào cũng có câu 'moi'", Days.ORDER.all(func(d): return str(Days.data(d).get("moi", "")) != ""))

	# Bản demo: chỉ Thứ Hai, Thứ Ba
	ProjectSettings.set_setting("meo/ban_demo", true)
	_check("demo bật", Days.demo())
	_check("demo: chỉ Thứ Hai, Thứ Ba chơi được",
		Days.ORDER.filter(func(d): return Days.playable(d)) == Days.DEMO_DAYS)
	_check("demo: Thứ Tư ghi 'Bản đầy đủ'", Days.full_only("thu_tu") and not Days.full_only("thu_ba"))
	_check("demo: hết Thứ Ba báo hết bản demo", NK.next_line("thu_ba").get("demo_end", false))
	ProjectSettings.set_setting("meo/ban_demo", false)
	_check("tắt demo thì Thứ Tư chơi được lại", Days.playable("thu_tu") and not Days.demo())

	GameSettings.set_value("mo_khoa_da_xem", "")
	print("MO NGAY TEST OK" if fails == 0 else "MO NGAY TEST FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


func _after_select(ls: Node, d: String) -> Node:
	ls._select(d, false)
	return ls._detail


func _has_text(n: Node, s: String) -> bool:
	if n is Label and (n as Label).text.contains(s):
		return true
	if n is Button and (n as Button).text.contains(s):
		return true
	for c in n.get_children():
		if _has_text(c, s):
			return true
	return false


func _check(what: String, ok: bool) -> void:
	print(("  ok   " if ok else "  SAI  ") + what)
	if not ok:
		fails += 1
