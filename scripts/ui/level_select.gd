class_name LevelSelectPanel
extends Control
## Màn Chọn màn: mở từ nút "Bắt đầu ca" ở màn hình chính.
## Bên trái là bảy ngày trong tuần (theo trang thiết kế màn chơi), bên phải là các cách chơi của ngày đang chọn.
## Thứ Hai chơi được: cả ca, chỉ bếp, chỉ giao 5 đơn, hoặc giao một đơn. Các ngày khác hiện "Sắp có".
## Bản chơi thử nên không khóa phần nào của Thứ Hai. Sao và kỷ lục đọc từ file lưu (GameState).

signal closed

const T = preload("res://scripts/ui/ui_theme.gd")
const Main = preload("res://scripts/main.gd")

## [mã ngày, tên chủ đề, mô tả]. Chỉ Thứ Hai đã làm xong.
const DAYS := [
	["thu_hai", "Mẻ bánh đầu tiên", "Làm bánh trong bếp Cô Ba rồi giao 5 đơn. Đơn cuối phải lách qua Chó Mực ở hẻm 42."],
	["thu_ba", "Chợ đông", "Sáng chợ đông nghẹt: góc đánh cờ và tiệm tạp hóa chắn lối, phải tìm đường vòng."],
	["thu_tu", "Trời mưa", "Mưa trơn trượt, đi đường sân thượng và giữ thăng bằng trên mép tường."],
	["thu_nam", "Chung cư", "Giao lên các tầng chung cư: bám mép và bật tường để leo."],
	["thu_sau", "Đám giỗ Bà Sáu", "Ngày đông khách nhất: tiệm sửa xe và nhà Bà Sáu đặt bánh cho đám giỗ."],
	["thu_bay", "Dạo phố", "Không có đồng hồ: đi giúp hàng xóm, chụp ảnh, và làm bạn với Chó Mực."],
	["chu_nhat", "Hội mèo", "Năm cuộc thi với mèo cả phố: đua sân thượng, nhảy thùng, trốn tìm, giao tiếp sức, thi trang phục."],
]
const PLAYABLE := ["thu_hai"]
## Ngày chưa làm xong nhưng đã có cảnh chơi thử riêng.
const PREVIEW := ["thu_nam"]

var _day := "thu_hai"
var _day_buttons := {}  # mã ngày -> Button
var _week: VBoxContainer
var _detail: VBoxContainer
var _first_focus: Control


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
	head.add_child(T.label("Chọn màn chơi", 42, T.INK, "display"))
	var note := T.label("Bản chơi thử: mở hết phần của Thứ Hai · Esc để quay lại", 15, T.MUTED, "bold")
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
			_build_week()
			_select("thu_hai"))


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
	if day in PLAYABLE:
		_build_monday()
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
	for d in DAYS:
		var b := _day_button(d[0], d[1])
		_week.add_child(b)
		_day_buttons[d[0]] = b


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
	var playable := day in PLAYABLE
	v.add_child(T.label(GameState.DAY_NAMES[day], 22, T.INK if playable else T.MUTED, "display"))
	v.add_child(T.label(theme_name, 14, T.MUTED, "bold"))
	if playable:
		var best := int(GameState.get_day("sao_cao_nhat", -1, day))
		if best >= 0:
			h.add_child(_pill("%d/15 sao" % best, T.AMBER, T.ON_CRUST))
		else:
			h.add_child(_pill("Mới", T.LEAF, T.PAPER))
	elif day in PREVIEW:
		h.add_child(_pill("Chơi thử", T.LEAF, T.PAPER))
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

func _build_monday() -> void:
	var d: Array = DAYS[0]
	_detail.add_child(T.label("Thứ Hai · %s" % d[1], 30, T.INK, "display"))
	var desc := T.label(d[2], 15, T.MUTED, "body")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(desc)
	_detail.add_child(_record_line())

	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 14)
	_detail.add_child(modes)
	var kitchen_best := int(GameState.get_day("sao_bep", -1, "thu_hai"))
	var full := _mode_button("Cả ca", "Làm bếp rồi giao 5 đơn", "primary", PlayMode.Mode.FULL)
	modes.add_child(full)
	modes.add_child(_mode_button("Chỉ làm bếp", "Kỷ lục bếp %d/3 sao" % kitchen_best if kitchen_best >= 0 else "Chưa làm bếp lần nào", "secondary", PlayMode.Mode.KITCHEN))
	modes.add_child(_mode_button("Chỉ giao 5 đơn", "Bỏ qua phần bếp", "secondary", PlayMode.Mode.DELIVERY))
	_first_focus = full

	var h := T.label("Giao một đơn · vào thẳng đơn đó, không tính kỷ lục ca", 20, T.INK, "display")
	_detail.add_child(h)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	_detail.add_child(list)
	for i in Main.ORDERS.size():
		list.add_child(_order_button(i, Main.ORDERS[i]))


func _record_line() -> Control:
	var best := int(GameState.get_day("sao_cao_nhat", -1, "thu_hai"))
	var text := "Chưa chơi ca nào · chơi cả ca để lập kỷ lục"
	if best >= 0:
		var parts := ["Kỷ lục ca %d/15 sao" % best]
		var rank := str(GameState.get_day("hang_cao_nhat", "", "thu_hai"))
		if rank != "":
			parts.append(Scoring.rank_name(rank))
		var tip := int(GameState.get_day("boa_cao_nhat", 0, "thu_hai"))
		if tip > 0:
			parts.append("boa cao nhất %s" % Main._money(tip))
		parts.append("đã chơi %d lần" % int(GameState.get_day("so_lan_choi", 0, "thu_hai")))
		text = " · ".join(parts)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.box(T.CREAM, 14, 14, Color(0, 0, 0, 0), 0))
	p.add_child(T.label(text, 15, T.INK, "bold"))
	return p


## on_press: bấm thì làm việc khác thay cho PlayMode.start(mode) (vd. vào cảnh chung cư Thứ Năm).
func _mode_button(title: String, sub: String, style: String, mode: PlayMode.Mode, on_press := Callable()) -> Button:
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
	v.add_child(T.label(title, 22, fg, "display"))
	var sl := T.label(sub, 13, fg if style == "primary" else T.MUTED, "bold")
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(sl)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	else:
		b.pressed.connect(func(): PlayMode.start(get_tree(), mode))
	return b


func _order_button(i: int, o: Dictionary) -> Button:
	var b := T.button("", "secondary", 48)
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

	var who := T.label("%s · %s" % [o.who, o.place], 18, T.INK, "bold")
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(who)
	var item := T.label(o.item, 14, T.MUTED, "body")
	item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(item)
	if o.get("boss", false):
		h.add_child(_pill("Chó Mực", T.RED, T.PAPER))

	var t := Scoring.best_time(i)
	var tl := T.label("%.1f giây" % t if t > 0.0 else "chưa giao", 14, T.MUTED, "bold")
	tl.custom_minimum_size.x = 80
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tl)
	var stars := T.StarRow.new()
	stars.filled = Scoring.best_stars(i)
	stars.empty_color = T.SAND
	stars.custom_minimum_size = Vector2(3 * 24 + 8, 24)
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(stars)
	b.tooltip_text = "Vào thẳng đơn %d: chạy tới lò nhận bánh rồi giao cho %s" % [i + 1, o.who]
	b.pressed.connect(func(): PlayMode.start(get_tree(), PlayMode.Mode.ORDER, i))
	return b


# ---------------------------------------------------------------- Thứ Năm (chơi thử cảnh chung cư)

func _build_thursday() -> void:
	_detail.add_child(T.label("Thứ Năm · Lên tầng năm", 30, T.INK, "display"))
	var desc := T.label("Mang 2 ổ trứng lên căn 5B-1 cho Bé Na. Đi cầu thang (chui giá phơi đồ, rón rén qua em bé ngủ), "
		+ "đợi thang máy, hay leo ngoài tường: bật tường trong khe hẹp, bám mép (Space), leo ống nước.", 15, T.MUTED, "body")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(desc)
	var best := Scoring.best_stars(0, "thu_nam")
	var play := _mode_button("Leo chung cư", "Kỷ lục %d/3 sao" % best if best > 0 else "Bản khối tạm, chưa có model",
		"primary", PlayMode.Mode.ORDER, func(): PlayMode.start_chung_cu(get_tree()))
	play.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_detail.add_child(play)
	var note := T.label("Cả ngày Thứ Năm (đường từ lò tới chung cư, nhiều đơn) làm sau bản Thứ Hai.", 14, T.MUTED, "bold")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(note)
	_first_focus = play


# ---------------------------------------------------------------- ngày chưa làm

func _build_soon(day: String) -> void:
	var d: Array = DAYS[0]
	for x in DAYS:
		if x[0] == day:
			d = x
	_detail.add_child(T.label("%s · %s" % [GameState.DAY_NAMES[day], d[1]], 34, T.MUTED, "display"))
	var desc := T.label(d[2], 18, T.INK, "body")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(desc)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", T.box(T.SAND, 22, 28, T.INK, 3, 6))
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var big := T.label("Sắp có", 52, T.MUTED, "display")
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var sub := T.label("Ngày này đang được làm. Bản chơi thử hiện có Thứ Hai.", 17, T.MUTED, "bold")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	_detail.add_child(card)
	var go := T.button("  Chơi Thứ Hai", "primary", 60, 20)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	go.pressed.connect(_select.bind("thu_hai"))
	_detail.add_child(go)
	_first_focus = go
