extends SceneTree
## Chữ hướng dẫn theo ngày và thẻ nhiệm vụ một dòng (B2 + F1):
## - bảng "Cách chơi" mỗi ngày có phím chung + dòng riêng + "Giữ R", không còn "nhảy qua Chó Mực";
## - Thứ Bảy: bảng không có "giao bánh", menu Esc không ghi "Đơn 1/5", thẻ việc gọn một dòng;
## - Thứ Hai: thẻ đơn tự mở đủ khi sang đơn mới rồi gọn lại, Tab mở/gọn, dãy phím góc phải có "Giữ R".
## Chạy: godot --headless --path . -s tests/test_chu_huong_dan.gd

var fails := 0


func _init() -> void:
	GameState.use_test_save("user://luu_game_test_chu_huong_dan.cfg")
	_run.call_deferred()


func _run() -> void:
	_check_tables()
	await _check_thu_hai()
	await _check_thu_bay()
	if fails == 0:
		print("CHU HUONG DAN TEST OK")
	quit(0 if fails == 0 else 1)


func _check_tables() -> void:
	for id: String in Days.ORDER:
		var day := Days.get_day(id)
		var rows := ChuHuongDan.bang(day)
		var text := _rows_text(rows)
		_check(ChuHuongDan.PHIM_CUU_KET[0] in rows, "%s: bảng có dòng Giữ R" % id)
		_check(not "nhảy qua Chó Mực" in text, "%s: không còn \"nhảy qua Chó Mực\"" % id)
		_check(rows.size() <= 13, "%s: bảng vừa thẻ (%d dòng)" % [id, rows.size()])
		_check("Tay cầm" in ChuHuongDan.ghi_chu(day), "%s: ghi chú có dòng tay cầm" % id)
	var sat := _rows_text(ChuHuongDan.bang(Days.get_day("thu_bay")))
	_check(not "giao bánh" in sat and "Sổ hàng xóm" in sat, "Thứ Bảy: bảng không có giao bánh, có Sổ hàng xóm")
	_check(_rows_text(ChuHuongDan.BANG_GIAO).contains("giao bánh"), "bảng chung có giao bánh")


func _check_thu_hai() -> void:
	PlayMode.day = "thu_hai"
	PlayMode.mode = PlayMode.Mode.DELIVERY
	var m: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await _frames(30)
	var hud: Node = m.hud
	_check(_has_text(hud.pause_screen, "về chỗ an toàn khi bị kẹt"), "Thứ Hai: menu Esc có Giữ R")
	_check(_has_text(hud.hint, "về chỗ an toàn"), "Thứ Hai: dãy phím góc phải có Giữ R")
	_check(hud.order_more.visible, "Thứ Hai: thẻ đơn tự mở đủ lúc nhận việc")
	hud._card_open_t = 0.01
	await _frames(5)
	_check(not hud.order_more.visible and hud.order_label.clip_text, "Thứ Hai: hết giờ thì thẻ gọn một dòng")
	_check(hud.order_card.size.y < 90.0, "Thứ Hai: thẻ gọn thấp dưới 90 px (%.0f)" % hud.order_card.size.y)
	Input.action_press("the_nhiem_vu")
	await process_frame
	await process_frame
	Input.action_release("the_nhiem_vu")
	await _frames(3)
	_check(hud.order_more.visible, "Thứ Hai: Tab mở đủ thẻ")
	Input.action_press("the_nhiem_vu")
	await process_frame
	await process_frame
	Input.action_release("the_nhiem_vu")
	await _frames(3)
	_check(not hud.order_more.visible, "Thứ Hai: Tab lần nữa thì gọn")
	var shown: int = hud.dots.filter(func(d: Control) -> bool: return d.visible).size()
	_check(shown == m.orders.size(), "Thứ Hai: %d ổ tiến độ cho %d đơn" % [shown, m.orders.size()])
	_check(m._pause_info().begins_with("Đơn 1/"), "Thứ Hai: menu Esc ghi đơn đang làm")
	m.queue_free()
	await _frames(5)


func _check_thu_bay() -> void:
	PlayMode.day = "thu_bay"
	PlayMode.mode = PlayMode.Mode.DELIVERY
	var m: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await _frames(40)
	var info: String = m._pause_info()
	_check(not "Đơn" in info and "Dạo phố" in info, "Thứ Bảy: menu Esc ghi \"%s\"" % info)
	_check(not _has_text(m.hud.pause_screen, "giao bánh"), "Thứ Bảy: menu Esc không có giao bánh")
	_check(_has_text(m.hud.pause_screen, "Sổ hàng xóm"), "Thứ Bảy: menu Esc có Sổ hàng xóm")
	var ui: ThuBayHud = null
	for n in m.find_children("*", "CanvasLayer", true, false):
		if n is ThuBayHud:
			ui = n
	_check(ui != null, "Thứ Bảy: có thẻ dạo phố")
	if ui:
		ui._open_t = 0.01
		await _frames(5)
		_check(ui._line.clip_text and ui._line.autowrap_mode == TextServer.AUTOWRAP_OFF, "Thứ Bảy: thẻ việc gọn một dòng")
		_check(ui._card.size.y < 60.0, "Thứ Bảy: thẻ thấp dưới 60 px (%.0f)" % ui._card.size.y)
		_check(ui._now.text.contains(ui.line_text()), "Thứ Bảy: đầu sổ ghi đủ việc đang làm")
	m.queue_free()
	await _frames(5)


func _rows_text(rows: Array) -> String:
	return " | ".join(rows.map(func(r: Array) -> String: return "%s %s" % [r[0], r[1]]))


func _has_text(n: Node, s: String) -> bool:
	if n is Label and s in n.text:
		return true
	for c in n.get_children():
		if _has_text(c, s):
			return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  LỖI  ") + what)
	if not ok:
		fails += 1
