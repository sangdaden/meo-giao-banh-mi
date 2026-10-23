extends SceneTree
## Bản tiếng Anh (F3, scripts/ngon_ngu.gd + scripts/dich/):
## - bảng dịch nạp được, mẫu %s/%d dịch đúng câu đã ghép, tên món viết thường vẫn dịch, câu nhiều dòng dịch từng dòng;
## - tiếng Việt (mặc định) không bị dịch nhầm, kể cả khi vừa đổi qua English rồi đổi lại;
## - Label trong menu chính, Cài đặt, Chọn màn, Tủ đồ hiện tiếng Anh;
## - dò mọi chuỗi có dấu trong scripts/ chưa có trong bảng: chỉ in ra (không làm đỏ), để luồng thêm chữ mới nhớ thêm bản dịch.
## Chạy: godot --headless --path . -s tests/test_ngon_ngu.gd

const BanDich := preload("res://scripts/dich/ban_dich.gd")
## File không phải chữ hiện cho người chơi (bảng âm tiết giọng ú ớ, chính bảng dịch).
const BO_QUA_FILE := ["res://scripts/giong_uo.gd", "res://scripts/dich/"]
## Dòng có những chữ này là ghi chú test/debug, không hiện cho người chơi.
const BO_QUA_DONG := ["print(", "push_warning(", "push_error(", "printerr(", "_expect(", "notes.append(", "skipped.append(", "why = ", "_fits_group(", "@export_group", "\"mieu:"]

var fails := 0
var ng: Node


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	ng = root.get_node("NgonNgu")
	_check_engine()
	await _check_menu()
	_scan_scripts()
	ng.dat("vi", false)
	if fails == 0:
		print("NGON NGU TEST OK")
	quit(0 if fails == 0 else 1)


func _check_engine() -> void:
	ng.dat("en", false)
	var cases := {
		"Thứ Hai": "Monday",
		"Đơn 3/5": "Order 3/5",
		"  Chơi lại ca": "  Replay shift",
		"Còn thiếu: bánh nướng, Ngò": "Still missing: baked bread, Coriander",
		"Lò bánh Cô Ba · còn 12 m": "Cô Ba's bakery · 12 m to go",
		"Chơi tiếp · Thứ Ba · tuần 2": "Continue · Tuesday · week 2",
		"Giao xong cho Chú Tư! 3 sao · boa 15.000đ": "Delivered to Chú Tư! 3 stars · 15.000đ tip",
		"Đã mua nơ bướm! Bấm vào ô để đeo khi muốn.": "Bought bow tie! Click the tile to wear it whenever you like.",
		"★ Làm đủ 2 ổ trước giờ\n☆ Bánh bị cháy\n": "★ Made both loaves in time\n☆ The bread got burnt\n",
		"Ráp ổ 2 ở bàn giữa": "Assemble loaf 2 at the middle table",
	}
	for vi in cases:
		var got := TranslationServer.translate(vi)
		_check(got == cases[vi], "dịch \"%s\" -> \"%s\" (được \"%s\")" % [vi.c_escape(), cases[vi].c_escape(), got.c_escape()])
	# Mỗi khóa có %s/%d thì bản Anh cũng đủ chỗ trống.
	for bang in BanDich.BANG:
		for vi: String in bang.EN:
			var en: String = bang.EN[vi]
			if en.find("{0}") == -1:
				_check(_so_cho_trong(vi) == _so_cho_trong(en), "số %%s/%%d khớp: \"%s\"" % vi.c_escape())
	ng.dat("vi", false)
	_check(TranslationServer.translate("Đơn 3/5") == "Đơn 3/5", "tiếng Việt giữ nguyên sau khi đổi lại")
	_check(TranslationServer.translate("Thứ Hai") == "Thứ Hai", "tiếng Việt không rơi về bản Anh dự phòng")


func _check_menu() -> void:
	ng.dat("en", false)
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	var thieu := []
	for panel in [menu, menu.settings, menu.level_select, menu.wardrobe]:
		if panel != menu:
			panel.visible = true
			await process_frame
		_gom_label(panel, thieu)
	var bd: Object = ng.ban_dich
	var con := []
	for s in thieu:
		if not bd.xong(menu.atr(s)):
			con.append(s)
	for s in con:
		print("  menu chưa dịch: ", s.c_escape())
	_check(con.is_empty(), "menu, Cài đặt, Chọn màn, Tủ đồ dịch hết (%d chữ còn tiếng Việt)" % con.size())
	_check(menu.atr("Cài đặt") == "Settings", "Label tự dịch qua atr")
	# Chọn màn: chữ dài (nhất là tiếng Anh) không được đẩy giờ, sao, nhãn ra ngoài nút (Sang báo 23/10).
	for lang in ["vi", "en"]:
		ng.dat(lang, false)
		for d in Days.ORDER:
			menu.level_select._select(d, false)
			await process_frame
			await process_frame
			for b in _nut(menu.level_select, []):
				_check(_trong_nut(b, b), "Chọn màn %s %s: nút \"%s\" có chữ tràn ra ngoài" % [lang, d, b.tooltip_text.get_slice("\n", 0)])
	ng.dat("en", false)
	menu.queue_free()
	await process_frame


func _nut(n: Node, out: Array) -> Array:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return out
	if n is Button:
		out.append(n)
	for c in n.get_children():
		_nut(c, out)
	return out


## Mọi Control con đang hiện nằm gọn trong bề ngang của nút (cho lệch 1 px).
func _trong_nut(b: Control, n: Node) -> bool:
	for c in n.get_children():
		if c is Control and (c as Control).visible:
			var r := (c as Control).get_global_rect()
			var br := b.get_global_rect()
			if r.position.x < br.position.x - 1.0 or r.end.x > br.end.x + 1.0:
				return false
			if not _trong_nut(b, c):
				return false
	return true


func _gom_label(n: Node, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if (n is Label or n is Button or n is RichTextLabel) and str(n.text).strip_edges() != "":
		if n.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
			out.append(str(n.text))
	for c in n.get_children():
		_gom_label(c, out)


## Dò chuỗi có dấu trong scripts/ chưa có trong bảng dịch. Chỉ in, không làm đỏ test.
func _scan_scripts() -> void:
	ng.dat("en", false)
	var bd: Object = ng.ban_dich
	var thieu := {}
	for path in _gd_files("res://scripts/"):
		var skip := false
		for b in BO_QUA_FILE:
			if path.begins_with(b):
				skip = true
		if skip:
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for s in _strings(lines):
			s = s.trim_prefix("#")  # tiêu đề mục trong lời cảm ơn (tong_ket.gd) bỏ "#" trước khi hiện
			if not bd.co_dau(s) or bd.xong(bd.dich(s, 0)):
				continue
			thieu[s] = path
	for s in thieu:
		print("  chưa dịch (%s): %s" % [thieu[s].get_file(), s.c_escape()])
	print("NGON NGU: %d chuỗi có dấu chưa có trong scripts/dich/en_*.gd" % thieu.size())


func _strings(lines: PackedStringArray) -> Array:
	var out := []
	for line in lines:
		var t := line.strip_edges()
		if t.begins_with("#"):
			continue
		var bo := false
		for b in BO_QUA_DONG:
			if t.find(b) != -1:
				bo = true
		if bo:
			continue
		var i := 0
		while i < line.length():
			var c := line[i]
			if c == "#":
				break
			if c == "\"" or c == "'":
				var j := i + 1
				var buf := ""
				while j < line.length() and line[j] != c:
					if line[j] == "\\" and j + 1 < line.length():
						var e := line[j + 1]
						buf += {"n": "\n", "t": "\t"}.get(e, e)
						j += 2
						continue
					buf += line[j]
					j += 1
				out.append(buf)
				i = j + 1
				continue
			i += 1
	return out


func _gd_files(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + f)
	for sub in d.get_directories():
		out.append_array(_gd_files(dir + sub + "/"))
	return out


func _so_cho_trong(s: String) -> int:
	var re := RegEx.new()
	re.compile("%[-+ 0#]*[0-9]*(?:\\.[0-9]+)?[sdf]")
	return re.search_all(s).size()


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("LỖI: ", what)
