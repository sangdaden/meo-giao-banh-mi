class_name ThuBayHud
extends CanvasLayer
## Giao diện Thứ Bảy dạo phố (không đồng hồ, không thẻ đơn): một dòng việc đang làm ở góc trên, tim thân thiết,
## Sổ hàng xóm mở bằng Tab (mỗi người một trang: ảnh dán, việc nhờ, quà), bảng chọn (nhân bánh Cô Ba)
## và bảng cuối ngày. Trang sổ thật (giấy, ảnh dán, tim) chờ phác thảo G8; đây là bản giao diện tạm cùng màu UiTheme.

signal end_closed(action: String)   ## "menu" | "home" | "next" | "again" | "roam"

const T = preload("res://scripts/ui/ui_theme.gd")

var day: Node                       ## ThuBay
var book_open := false
var _line: Label
var _hearts: Label
var _keys: Label
var _book: Control
var _grid: GridContainer
var _cover: TextureRect
var _book_title: Label
var _choice: Control
var _choice_cb: Callable
var _choice_picked: Array = []
var _choice_need := 0
var _choice_label: Label
var _end: Control


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = T.make_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", T.box(T.PAPER, 16, 14))
	T.place(card, 0.0, 0.0, Rect2(24, 24, 560, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var title := T.label("Thứ Bảy · Dạo phố", 15, T.MUTED, "bold")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_hearts = T.label("", 17, T.RED, "bold")
	top.add_child(_hearts)
	_line = T.label("", 19, T.INK, "bold")
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_line)
	_keys = T.label("Tab mở sổ · P chụp ảnh · E giúp người có dấu !", 13, T.MUTED, "bold")
	v.add_child(_keys)
	root.add_child(card)

	_book = _build_book()
	_book.visible = false
	root.add_child(_book)
	_choice = Control.new()
	_choice.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice.visible = false
	root.add_child(_choice)
	_end = Control.new()
	_end.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end.visible = false
	root.add_child(_end)
	refresh()


func set_line(text: String) -> void:
	_line.text = text


func refresh() -> void:
	_hearts.text = "♥ %d/%d" % [SoHangXom.hearts(), SoHangXom.PEOPLE_PAGES]
	if book_open:
		_fill_book()


# ---------------------------------------------------------------- sổ

func _build_book() -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.12, 0.13, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var page := PanelContainer.new()
	page.add_theme_stylebox_override("panel", T.box(T.CREAM, 22, 22, T.INK, 4, 6))
	T.place(page, 0.5, 0.5, Rect2(-560, -330, 1120, 660))
	dim.add_child(page)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	page.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	_cover = TextureRect.new()
	_cover.custom_minimum_size = Vector2(150, 90)
	_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	head.add_child(_cover)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	_book_title = T.label("", 30, T.INK, "display")
	hv.add_child(_book_title)
	hv.add_child(T.label("Mỗi người một trang. Giúp xong thì dán ảnh chung, được một tim và một món quà.", 15, T.MUTED, "bold"))
	hv.add_child(T.label("Tab đóng sổ · ảnh tự do (P) dán lên bìa", 13, T.MUTED, "bold"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	return dim


func toggle_book() -> void:
	book_open = not book_open
	_book.visible = book_open
	if book_open:
		_fill_book()


func _fill_book() -> void:
	_book_title.text = "Sổ hàng xóm · ♥ %d/%d" % [SoHangXom.hearts(), SoHangXom.PEOPLE_PAGES]
	var cover := SoHangXom.photo("bia")
	_cover.texture = ImageTexture.create_from_image(cover) if cover else null
	_cover.visible = cover != null
	for c in _grid.get_children():
		c.queue_free()
	for p in SoHangXom.pages():
		_grid.add_child(_page_card(p.id, "%d. %s" % [p.page, p.who], p.place, p.task, "Quà: " + str(p.gift_name)))
	var muc_open: bool = day != null and day.muc_chapter_open()
	_grid.add_child(_page_card(SoHangXom.MUC, "11. Chó Mực", "Cuối hẻm 42",
		"Tìm thẻ tên đồng bị rơi" if muc_open else "Trang đặc biệt · giúp %d người rồi hỏi Bà Sáu" % int(DoKho.v("muc_chapter_after", 3)),
		"Mực đi theo Bơ"))


func _page_card(id: String, who: String, place: String, task: String, gift: String) -> Control:
	var done := SoHangXom.is_done(id)
	var active: bool = day != null and day.active_id() == id
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(260, 0)
	card.add_theme_stylebox_override("panel", T.box(T.PAPER if done else Color("#F4ECDA"), 14, 10, T.LEAF if done else (T.TEAL if active else T.INK), 3))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var img := SoHangXom.photo(id) if done else null
	var ph := TextureRect.new()
	ph.custom_minimum_size = Vector2(236, 96)
	ph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if img:
		ph.texture = ImageTexture.create_from_image(img)
		v.add_child(ph)
	else:
		var blank := PanelContainer.new()
		blank.custom_minimum_size = Vector2(236, 96)
		blank.add_theme_stylebox_override("panel", T.box(T.SAND, 10, 8, Color(0, 0, 0, 0), 0))
		var mark := T.label("♥ đã dán ảnh" if done else ("đang giúp" if active else "chỗ dán ảnh"), 16, T.LEAF if done else T.MUTED, "bold")
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		blank.add_child(mark)
		v.add_child(blank)
	v.add_child(T.label(who, 17, T.INK, "display"))
	v.add_child(T.label(place, 13, T.MUTED, "bold"))
	var t := T.label(task, 14, T.INK, "body")
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	v.add_child(T.label(("♥ " if done else "") + gift, 13, T.RED if done else T.MUTED, "bold"))
	return card


# ---------------------------------------------------------------- bảng chọn

## Chọn đủ `need` món trong `options` rồi gọi cb(mảng tên đã chọn). Không có sai.
func choose(title: String, options: Array, need: int, cb: Callable) -> void:
	_choice_cb = cb
	_choice_need = need
	_choice_picked = []
	for c in _choice.get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.12, 0.13, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice.add_child(dim)
	var page := PanelContainer.new()
	page.add_theme_stylebox_override("panel", T.box(T.CREAM, 22, 22, T.INK, 4, 6))
	T.place(page, 0.5, 0.5, Rect2(-380, -170, 760, 340))
	dim.add_child(page)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	page.add_child(v)
	v.add_child(T.label(title, 28, T.INK, "display"))
	_choice_label = T.label("", 16, T.MUTED, "bold")
	v.add_child(_choice_label)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var first: Button
	for o in options:
		var b := T.button(str(o), "secondary", 56, 18)
		b.toggle_mode = true
		b.custom_minimum_size.x = 170
		b.toggled.connect(func(on: bool):
			if on and not o in _choice_picked:
				_choice_picked.append(o)
			elif not on:
				_choice_picked.erase(o)
			_update_choice())
		grid.add_child(b)
		if first == null:
			first = b
	var ok := T.button("Xong · đưa Cô Ba nếm", "primary", 60)
	ok.name = "Xong"
	ok.pressed.connect(func():
		if _choice_picked.size() == _choice_need:
			var picked := _choice_picked.duplicate()
			close_choice()
			_choice_cb.call(picked))
	v.add_child(ok)
	_choice.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if day:
		day.player.can_move = false
	_update_choice()
	T.wire_clicks(_choice)
	if first:
		first.grab_focus.call_deferred()


func _update_choice() -> void:
	_choice_label.text = "Đã chọn %d/%d: %s" % [_choice_picked.size(), _choice_need, ", ".join(_choice_picked)]
	var ok := _choice.find_child("Xong", true, false) as Button
	if ok:
		ok.disabled = _choice_picked.size() != _choice_need


func close_choice() -> void:
	_choice.visible = false
	if day:
		day.player.can_move = true
		if not day.autotest:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func choosing() -> bool:
	return _choice.visible


# ---------------------------------------------------------------- cuối ngày

func show_end(lines: Array) -> void:
	for c in _end.get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.16, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end.add_child(dim)
	var page := PanelContainer.new()
	page.add_theme_stylebox_override("panel", T.box(T.CREAM, 22, 26, T.INK, 4, 6))
	T.place(page, 0.5, 0.5, Rect2(-400, -260, 800, 520))
	dim.add_child(page)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	page.add_child(v)
	v.add_child(T.label("Hết ngày dạo phố", 34, T.INK, "display"))
	for l in lines:
		var lab := T.label(str(l), 18, T.INK, "bold")
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(lab)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	# Chơi liền các ngày: nút chính sang ngày kế; chơi thử từ màn Chọn màn thì nút chính về đó.
	var menu: Button
	if PlayMode.continuous:
		menu = T.button(PlayMode.next_label(), "primary", 60)
		menu.pressed.connect(func(): end_closed.emit("next"))
	else:
		menu = T.button("Về chọn màn", "primary", 60)
		menu.pressed.connect(func(): end_closed.emit("menu"))
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(menu)
	var roam := T.button("Dạo tiếp", "secondary", 60)
	roam.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roam.pressed.connect(func():
		_end.visible = false
		end_closed.emit("roam"))
	h.add_child(roam)
	if PlayMode.continuous:
		var home := T.button("Về menu", "secondary", 60)
		home.pressed.connect(func(): end_closed.emit("home"))
		h.add_child(home)
	_end.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	T.wire_clicks(_end)
	menu.grab_focus.call_deferred()
