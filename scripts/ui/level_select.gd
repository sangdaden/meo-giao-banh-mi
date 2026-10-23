class_name LevelSelectPanel
extends Control
## Màn Chọn màn: game chơi liền các ngày (Chơi tiếp ở trang chủ), muốn chọn ngày thì bấm Chọn màn hay Esc ở trang chủ
## hoặc "Chọn màn" trong menu tạm dừng. "Cả ca" của một ngày chơi tiếp mạch tuần từ ngày đó;
## chỉ bếp, chỉ giao, một đơn là chơi tập, xong không sang ngày kế.
## Bên trái là bảy ngày trong tuần (theo trang thiết kế màn chơi), bên phải là các cách chơi của ngày đang chọn.
## Ngày đã làm (Days.playable) có: cả ca, chỉ bếp, chỉ giao (mọi đơn của ngày), hoặc giao một đơn. Ngày chưa làm hiện "Sắp có".
## Dữ liệu ngày và đơn lấy từ scripts/days.gd. Bản chơi thử mở sẵn mọi ngày đã làm (Days.PLAYTEST_UNLOCK_ALL).
## Sao và kỷ lục đọc từ file lưu (GameState), mỗi ngày một mục.

signal closed

const T = preload("res://scripts/ui/ui_theme.gd")
const Main = preload("res://scripts/main.gd")

## Ngày chưa làm xong nhưng đã có cảnh chơi thử riêng.
const PREVIEW := ["thu_nam"]

var _day := "thu_hai"
var _day_buttons := {}  # mã ngày -> Button
var _week: VBoxContainer
var _detail: VBoxContainer
var _first_focus: Control
var _note: Label


func _ready() -> void:
	theme = T.make_theme()
	T.full_rect(self)
	var dim := ColorRect.new()
	dim.color = Color(T.INK, 0.6)
	add_child(T.full_rect(dim))

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.box(T.PAPER, 28, 32, T.INK, 4, 8))
	T.place(panel, 0.5, 0.5, Rect2(-580, -334, 1160, 668))
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)
	var back := T.icon_button("back", "Quay lại (Esc)")
	back.pressed.connect(close)
	head.add_child(back)
	head.add_child(T.label("Chọn màn", 42, T.INK, "display"))
	_note = T.label("", 15, T.MUTED, "bold")
	var note := _note
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(note)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	# Bảy ngày trong tuần
	_week = VBoxContainer.new()
	_week.custom_minimum_size.x = 300
	_week.add_theme_constant_override("separation", 9)
	body.add_child(_week)

	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	body.add_child(_detail)

	visibility_changed.connect(func():
		if visible:
			_note.text = "Tuần %d · Bắt đầu sẽ chơi tiếp %s · Esc để quay lại" % [PlayMode.week(),
				GameState.DAY_NAMES.get(PlayMode.current_day(), "")]
			_build_week()
			var cur := PlayMode.current_day()
			_select(cur if Days.unlocked(cur) else "thu_hai"))


func open() -> void:
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## grab = false khi đang đi phím trong cột ngày: đổi nội dung bên phải nhưng giữ focus ở cột ngày.
func _select(day: String, grab := true) -> void:
	_day = day
	for k in _day_buttons:
		_style_day(_day_buttons[k], k == day)
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	if Days.unlocked(day):
		_build_day(day)
	elif day == "thu_nam":
		_build_thursday()
	else:
		_build_soon(day)
	T.wire_clicks(self)
	if grab and _first_focus:
		_first_focus.grab_focus.call_deferred()


# ---------------------------------------------------------------- cột ngày

## Dựng lại mỗi lần mở để kỷ lục trên từng ngày luôn mới.
func _build_week() -> void:
	for c in _week.get_children():
		_week.remove_child(c)
		c.queue_free()
	_day_buttons.clear()
	_day = ""
	for id in Days.ORDER:
		var b := _day_button(id, Days.get_day(id).title)
		_week.add_child(b)
		_day_buttons[id] = b


func _day_button(day: String, theme_name: String) -> Button:
	var b := T.button("", "secondary", 66)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	T.full_rect(h)
	h.offset_left = 18
	h.offset_right = -14
	b.add_child(h)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var playable := Days.unlocked(day)
	v.add_child(_co_chu(T.label(GameState.DAY_NAMES[day], 22, T.INK if playable else T.MUTED, "display"), 16))
	v.add_child(_co_chu(T.label(theme_name, 14, T.MUTED, "bold"), 11))
	if playable:
		var best := int(GameState.get_day("sao_cao_nhat", -1, day))
		if best >= 0:
			h.add_child(_pill("%d/15 sao" % best, T.AMBER, T.ON_CRUST))
		else:
			h.add_child(_pill("Mới", T.LEAF, T.PAPER))
	elif day in PREVIEW:
		h.add_child(_pill("Chơi thử", T.LEAF, T.PAPER))
	elif Days.playable(day):
		h.add_child(_pill("Chưa mở", T.SAND, T.MUTED))
	else:
		h.add_child(_pill("Sắp có", T.SAND, T.MUTED))
	b.pressed.connect(_select.bind(day))
	b.focus_entered.connect(func():
		if _day != day:
			_select(day, false))
	return b


func _style_day(b: Button, selected: bool) -> void:
	var bg := T.CREAM if selected else T.PAPER
	var border := T.TEAL if selected else T.INK
	var w := 4 if selected else 3
	b.add_theme_stylebox_override("normal", T.box(bg, 18, 22, border, w, 5))
	b.add_theme_stylebox_override("hover", T.box(bg.lightened(0.3), 18, 22, border, w, 5))


func _pill(text: String, bg: Color, fg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.box(bg, 999, 12, T.INK, 2))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(T.label(text, 14, fg, "bold"))
	return p


# ---------------------------------------------------------------- Thứ Hai

func _build_day(id: String) -> void:
	if Days.is_free(id):
		_build_free_day(id)
		return
	var d := Days.get_day(id)
	_detail.add_child(T.label("%s · %s" % [d.name, d.title], 30, T.INK, "display"))
	var desc := T.label(d.blurb, 15, T.MUTED, "body")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(desc)
	_detail.add_child(_record_line(id))

	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 14)
	_detail.add_child(modes)
	var kitchen_best := int(GameState.get_day("sao_bep", -1, id))
	var full := _mode_button(id, "Cả ca", "Chơi tiếp tuần từ ngày này", "primary", PlayMode.Mode.FULL,
		func(): PlayMode.start_day(get_tree(), id))
	modes.add_child(full)
	modes.add_child(_mode_button(id, "Chỉ làm bếp", "Kỷ lục bếp %d/3 sao" % kitchen_best if kitchen_best >= 0 else "Chưa làm bếp lần nào", "secondary", PlayMode.Mode.KITCHEN))
	var n := Days.orders(id).size()
	modes.add_child(_mode_button(id, "Chỉ giao %d đơn" % n if n > 1 else "Chỉ đi giao", "Bỏ qua phần bếp", "secondary", PlayMode.Mode.DELIVERY))
	if id == Days.ORDER[0] and ResourceLoader.exists(PlayMode.TAP_SCENE):  # màn dạy chơi B1
		modes.add_child(_mode_button(id, "Tập chơi", "3 phút ở sân sau lò bánh", "secondary", PlayMode.Mode.ORDER,
			func(): PlayMode.start_tutorial(get_tree(), "select")))
	_first_focus = full

	var h := T.label("Giao một đơn · vào thẳng đơn đó, không tính kỷ lục ca", 20, T.INK, "display")
	_detail.add_child(h)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	_detail.add_child(list)
	var orders := Days.orders(id)
	for i in orders.size():
		list.add_child(_order_button(id, i, orders[i]))


## Ngày tự do (Thứ Bảy dạo phố): không bếp, không đơn, một nút vào chơi; dòng kỷ lục là số trang Sổ hàng xóm.
func _build_free_day(id: String) -> void:
	var d := Days.get_day(id)
	_detail.add_child(T.label("%s · %s" % [d.name, d.title], 30, T.INK, "display"))
	var desc := T.label(d.blurb, 15, T.MUTED, "body")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(desc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.box(T.CREAM, 14, 14, Color(0, 0, 0, 0), 0))
	p.add_child(T.label(SoHangXom.summary_line(), 15, T.INK, "bold"))
	_detail.add_child(p)
	var go := _mode_button(id, "Đi dạo phố", "Không đồng hồ · giúp hàng xóm, chụp ảnh, làm bạn với Chó Mực", "primary", PlayMode.Mode.DELIVERY,
		func(): PlayMode.start_day(get_tree(), id))
	_detail.add_child(go)
	_first_focus = go


func _record_line(id: String) -> Control:
	var best := int(GameState.get_day("sao_cao_nhat", -1, id))
	var text := "Chưa chơi ca nào · chơi cả ca để lập kỷ lục"
	if best >= 0:
		var parts := ["Kỷ lục ca %d/15 sao" % best]
		var rank := str(GameState.get_day("hang_cao_nhat", "", id))
		if rank != "":
			parts.append(Scoring.rank_name(rank))
		var tip := int(GameState.get_day("boa_cao_nhat", 0, id))
		if tip > 0:
			parts.append("boa cao nhất %s" % Main._money(tip))
		parts.append("đã chơi %d lần" % int(GameState.get_day("so_lan_choi", 0, id)))
		text = " · ".join(parts)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.box(T.CREAM, 14, 14, Color(0, 0, 0, 0), 0))
	p.add_child(T.label(text, 15, T.INK, "bold"))
	return p


## on_press: bấm thì làm việc khác thay cho PlayMode.start(mode) (vd. vào cảnh chung cư Thứ Năm).
func _mode_button(id: String, title: String, sub: String, style: String, mode: PlayMode.Mode, on_press := Callable()) -> Button:
	var b := T.button("", style, 72)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	T.full_rect(v)
	v.offset_left = 20
	v.offset_right = -12
	v.offset_bottom = -4
	b.add_child(v)
	var fg := T.ON_CRUST if style == "primary" else T.INK
	v.add_child(_co_chu(T.label(title, 22, fg, "display"), 15))
	v.add_child(_co_chu(T.label(sub, 13, fg if style == "primary" else T.MUTED, "bold"), 11))
	b.tooltip_text = "%s · %s" % [title, sub]
	if on_press.is_valid():
		b.pressed.connect(on_press)
	else:
		b.pressed.connect(func(): PlayMode.start(get_tree(), mode, 0, id))
	return b


func _order_button(id: String, i: int, o: Dictionary) -> Button:
	var b := T.button("", "secondary", 52)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	T.full_rect(h)
	h.offset_left = 12
	h.offset_right = -16
	h.offset_bottom = -4
	b.add_child(h)

	var num := PanelContainer.new()
	num.add_theme_stylebox_override("panel", T.box(o.color, 999, 0, T.INK, 2))
	num.custom_minimum_size = Vector2(32, 32)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl := T.label(str(i + 1), 18, T.PAPER, "display")
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_child(nl)
	h.add_child(num)

	# Tên khách và món xếp hai dòng, tự co chữ: nhãn, giờ và sao bên phải luôn nằm trong khung.
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -3)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(words)
	words.add_child(_co_chu(T.label("%s · %s" % [o.who, o.place], 17, T.INK, "bold"), 13))
	words.add_child(_co_chu(T.label(Main._item_text(o), 13, T.MUTED, "body"), 11))
	if o.get("boss", false):
		h.add_child(_pill("Chó Mực", T.RED, T.PAPER))
	elif Main._is_errand(o):
		h.add_child(_pill("Mua về lò", T.TEAL, T.PAPER))

	var times: Array = GameState.get_day("ky_luc_don", [], id)
	var t: float = times[i] if i < times.size() else -1.0
	var tl := T.label("%.1f giây" % t if t > 0.0 else "chưa giao", 14, T.MUTED, "bold")
	tl.custom_minimum_size.x = 80
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tl)
	var stars := T.StarRow.new()
	stars.filled = Scoring.best_stars(i, id)
	stars.empty_color = T.SAND
	stars.custom_minimum_size = Vector2(3 * 24 + 8, 24)
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(stars)
	b.tooltip_text = "Vào thẳng đơn %d của %s" % [i + 1, GameState.DAY_NAMES.get(id, id)] + "\n" + Main._item_text(o)
	b.pressed.connect(func(): PlayMode.start(get_tree(), PlayMode.Mode.ORDER, i, id))
	return b


# ---------------------------------------------------------------- Thứ Năm chưa mở: vẫn cho leo thử cảnh chung cư

func _build_thursday() -> void:
	_detail.add_child(T.label("Thứ Năm · Lên tầng năm", 30, T.INK, "display"))
	var desc := T.label("Mang 2 ổ trứng lên căn 5B-1 cho Bé Na. Đi cầu thang (chui giá phơi đồ, rón rén qua em bé ngủ), "
		+ "đợi thang máy, hay leo ngoài tường: bật tường trong khe hẹp, bám mép (Space), leo ống nước.", 15, T.MUTED, "body")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(desc)
	var best := Scoring.best_stars(0, "thu_nam")
	var play := _mode_button("thu_nam", "Leo chung cư", "Kỷ lục %d/3 sao" % best if best > 0 else "Chưa leo lần nào",
		"primary", PlayMode.Mode.ORDER, func(): PlayMode.start_chung_cu(get_tree()))
	play.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_detail.add_child(play)
	var note := T.label("Đây là riêng cảnh chung cư (đơn 5). Cả ngày Thứ Năm mở khi chơi xong Thứ Tư.", 14, T.MUTED, "bold")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(note)
	_first_focus = play


# ---------------------------------------------------------------- ngày chưa làm

func _build_soon(day: String) -> void:
	var d := Days.get_day(day)
	_detail.add_child(T.label("%s · %s" % [d.name, d.title], 34, T.MUTED, "display"))
	var desc := T.label(d.blurb, 18, T.INK, "body")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(desc)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", T.box(T.SAND, 22, 28, T.INK, 3, 6))
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var big := T.label("Chưa mở" if Days.playable(day) else "Sắp có", 52, T.MUTED, "display")
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var prev: String = Days.ORDER[maxi(Days.ORDER.find(day) - 1, 0)]
	var sub := T.label("Chơi xong %s để mở ngày này." % GameState.DAY_NAMES[prev] if Days.playable(day) else "Ngày này đang được làm.", 17, T.MUTED, "bold")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	_detail.add_child(card)
	var go := T.button("  Chơi Thứ Hai", "primary", 60, 20)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	go.pressed.connect(_select.bind("thu_hai"))
	_detail.add_child(go)
	_first_focus = go


## Chữ dài hơn chỗ (nhất là bản tiếng Anh) thì tự thu cỡ, nhỏ nhất `nho`; vẫn dài thì cắt "…".
## Nhãn phải nằm trong ô được kéo giãn (EXPAND_FILL hoặc phủ kín nút) vì clip_text cho bề rộng tối thiểu bằng 0.
func _co_chu(l: Label, nho: int) -> Label:
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lon := l.get_theme_font_size("font_size")
	var vua := func() -> void:
		var f := l.get_theme_font("font")
		if f == null or l.size.x <= 0.0:
			return
		var s := lon
		var chu := l.atr(l.text)
		while s > nho and f.get_string_size(chu, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > l.size.x:
			s -= 1
		l.add_theme_font_size_override("font_size", s)
	l.resized.connect(vua)
	var ng := get_node_or_null("/root/NgonNgu")
	if ng:
		var doi := func(_ma: String) -> void: vua.call()
		l.tree_entered.connect(func(): ng.doi_ngon_ngu.connect(doi))
		l.tree_exiting.connect(func(): ng.doi_ngon_ngu.disconnect(doi))
	return l
