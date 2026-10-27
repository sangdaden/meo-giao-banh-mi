class_name DoiPhimPanel
extends Control
## F2: màn "Đổi phím và tay cầm", mở từ Cài đặt > Điều khiển. Mỗi việc một dòng: phím chính và nút tay cầm.
## Bấm ô rồi bấm phím (hoặc nút tay cầm) mới; Esc / Start để thôi. Trùng việc khác thì hai việc đổi chỗ cho nhau.
## Dữ liệu và luật trùng phím: scripts/ban_phim.gd (BanPhim). Tự lưu ngay.

signal closed

const T = preload("res://scripts/ui/ui_theme.gd")

var _cho := {}  # đang chờ phím: {"action":, "loai": "phim"|"nut", "btn": Button}
var _cho_t := 0.0
var _bao: Label
var _o := {}  # action -> [nút phím, nút tay cầm]
var _done: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = T.make_theme()
	T.full_rect(self)
	var dim := ColorRect.new()
	dim.color = Color(T.INK, 0.6)
	add_child(T.full_rect(dim))

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.box(T.PAPER, 28, 32, T.INK, 4, 8))
	T.place(panel, 0.5, 0.5, Rect2(-480, -330, 960, 660))
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)
	var back := T.icon_button("back", "Quay lại (Esc)")
	back.pressed.connect(close)
	head.add_child(back)
	head.add_child(T.label("Đổi phím và tay cầm", 36, T.INK, "display"))

	_bao = T.label("Bấm vào một ô rồi bấm phím mới. Esc hoặc Start để thôi.", 15, T.MUTED, "bold")
	_bao.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_bao)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	scroll.add_child(rows)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	var sp := Control.new()
	sp.custom_minimum_size.x = 320
	top.add_child(sp)
	for t in ["Bàn phím", "Tay cầm"]:
		var l := T.label(t, 18, T.INK, "display")
		l.custom_minimum_size.x = 200
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top.add_child(l)
	rows.add_child(top)

	for d in BanPhim.PHIM:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 14)
		var l := T.label(d[1], 17, T.INK, "bold")
		l.custom_minimum_size.x = 320
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(l)
		var kb := _o_phim(d[0], "phim")
		var pb := _o_phim(d[0], "nut")
		r.add_child(kb)
		r.add_child(pb)
		rows.add_child(r)
		_o[d[0]] = [kb, pb]

	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 14)
	col.add_child(foot)
	var note := T.label("Cần phải tay cầm xoay camera · Start mở menu", 14, T.MUTED, "bold")
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(note)
	var reset_btn := T.button("Phím mặc định", "secondary", 56, 17)
	reset_btn.pressed.connect(func():
		_thoi()
		BanPhim.mac_dinh()
		_bao.text = "Đã về phím mặc định."
		_lam_moi())
	foot.add_child(reset_btn)
	_done = T.button("Xong", "primary", 56, 19)
	_done.custom_minimum_size.x = 130
	_done.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_done.pressed.connect(close)
	foot.add_child(_done)

	T.wire_clicks(self)
	visibility_changed.connect(func():
		if visible:
			_lam_moi()
			_done.grab_focus.call_deferred())
	_lam_moi()


func _o_phim(action: String, loai: String) -> Button:
	var b := T.button("", "secondary", 44, 16)
	b.custom_minimum_size = Vector2(200, 44)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(func(): _bat_dau(action, loai, b))
	return b


func open() -> void:
	move_to_front()
	visible = true


func close() -> void:
	_thoi()
	visible = false
	closed.emit()


func _lam_moi() -> void:
	for a in _o:
		_o[a][0].text = BanPhim.ten_phim(BanPhim.phim(a))
		var can: bool = BanPhim.nut(a) < 0 and not BanPhim.dong(a)[7].is_empty()
		_o[a][1].text = "Cần trái" if can else BanPhim.ten_nut(BanPhim.nut(a))
		_o[a][1].disabled = can  # đi lại bằng cần trái, không đổi


func _bat_dau(action: String, loai: String, b: Button) -> void:
	_lam_moi()
	_cho = {"action": action, "loai": loai, "btn": b}
	_cho_t = 0.15  # bỏ qua chính lần bấm vừa chọn ô
	b.text = "Bấm phím..." if loai == "phim" else "Bấm nút..."
	_bao.text = "Đang chờ %s cho \"%s\". Esc hoặc Start để thôi." % [
		"phím" if loai == "phim" else "nút tay cầm", tr(BanPhim.dong(action)[1])]


func _thoi() -> void:
	_cho = {}
	_lam_moi()


func _process(delta: float) -> void:
	_cho_t = maxf(_cho_t - delta, 0.0)


func _input(event: InputEvent) -> void:
	if not visible or _cho.is_empty() or _cho_t > 0.0 or not event.is_pressed() or event.is_echo():
		return
	var huy: bool = (event is InputEventKey and event.physical_keycode == KEY_ESCAPE) \
		or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START)
	if huy:
		get_viewport().set_input_as_handled()
		var b: Button = _cho.btn
		_thoi()
		_bao.text = "Không đổi."
		b.grab_focus()
		return
	var bi_doi := []
	if _cho.loai == "phim" and event is InputEventKey:
		var k: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if k in [KEY_F1, KEY_F3, KEY_M, KEY_V]:
			_bao.text = "Phím %s đã dùng cho việc khác (F1 gợi ý, F3 FPS, M tắt tiếng, V góc nhìn). Chọn phím khác." % BanPhim.ten_phim(k)
			get_viewport().set_input_as_handled()
			return
		bi_doi = BanPhim.dat_phim(_cho.action, k)
	elif _cho.loai == "nut" and event is InputEventJoypadButton:
		bi_doi = BanPhim.dat_nut(_cho.action, event.button_index)
	else:
		return
	get_viewport().set_input_as_handled()
	var b: Button = _cho.btn
	var ten := tr(BanPhim.dong(_cho.action)[1])
	_cho = {}
	_lam_moi()
	if bi_doi.is_empty():
		_bao.text = "Đã đổi phím cho \"%s\"." % ten
	else:
		var khac := []
		for a in bi_doi:
			khac.append(tr(BanPhim.dong(a)[1]))
		_bao.text = "Đã đổi. \"%s\" nhận phím cũ của \"%s\"." % [", ".join(khac), ten]
	b.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and _cho.is_empty() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
