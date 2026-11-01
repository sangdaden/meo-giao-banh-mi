extends SceneTree
## Kiểm tra cửa sang kênh Mark học AI (Vũ Trụ Mark K1 + K2, scripts/ke_mark.gd): link gắn nguồn đúng chỗ bấm,
## màn hình chính có nút, màn hết tuần có nút, chữ có bản tiếng Anh. Không mở trình duyệt.
## Chạy: godot --headless --path . -s tests/test_ke_mark.gd

const EnGiaoDien := preload("res://scripts/dich/en_giao_dien.gd")

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


func _buttons(n: Node) -> Array:
	var out := []
	for c in n.find_children("*", "Button", true, false):
		out.append(c)
	return out


func _has_mark_button(n: Node) -> bool:
	for b: Button in _buttons(n):
		if b.text.strip_edges() == KeMark.NUT.strip_edges():
			return true
	return false


func _run() -> void:
	print("Link")
	var l := KeMark.link("menu")
	_check(l.begins_with("https://markhocai.com/?"), "link về markhocai.com")
	_check("utm_source=meo-giao-banh-mi" in l and "utm_medium=game" in l, "link có nguồn là game")
	_check(l.ends_with("utm_content=menu"), "link ghi chỗ bấm")
	_check(KeMark.link("het tuan").ends_with("utm_content=het%20tuan"), "chỗ bấm được mã hóa")
	_check(KeMark.link("menu", true).begins_with(KeMark.URL_EN + "?utm_source=meo-giao-banh-mi"), "bản tiếng Anh dẫn về Vũ Trụ Khác bản EN (D4)")
	_check(not KeMark.la_en(), "mặc định là tiếng Việt")

	print("Tiếng Anh")
	for chu in [KeMark.NUT, KeMark.NUT.strip_edges(), KeMark.LOI]:
		_check(EnGiaoDien.EN.has(chu), "có bản tiếng Anh: " + chu.strip_edges())

	print("Màn hình chính")
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate() if ResourceLoader.exists("res://scenes/main_menu.tscn") else null
	if menu == null:
		var s := load("res://scripts/ui/main_menu.gd")
		menu = s.new()
	root.add_child(menu)
	await _frames(3)
	_check(_has_mark_button(menu), "có nút " + KeMark.NUT.strip_edges())
	menu.queue_free()
	await _frames(2)

	print("Hết tuần")
	var tk := TongKetTuan.new()
	tk.autotest = true
	root.add_child(tk)
	await _frames(2)
	_check(not _has_mark_button(tk), "bảng tổng kết chưa có nút (chỉ hiện sau chữ chạy)")
	tk._start_credits()
	tk._end_credits()
	await _frames(2)
	_check(tk.is_finished() and _has_mark_button(tk), "màn hết tuần có nút")
	tk.queue_free()
	await _frames(2)

	print("KE MARK TEST OK" if fails == 0 else "KE MARK TEST LỖI: %d" % fails)
	quit(1 if fails else 0)
