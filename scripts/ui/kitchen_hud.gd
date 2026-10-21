class_name KitchenHud
extends CanvasLayer
## HUD trong bếp theo bản phác thảo Sang duyệt (artboard 7).
## Luồng bếp tạo node này trong kitchen.tscn rồi gọi các hàm bên dưới; HUD không biết gì về luật chơi.
##
##   set_clock("5:12 sáng", "Còn 2:04 tới giờ mở bán")
##   set_tickets([{"title": "Ổ 1 · bánh mì thịt", "items": ["Bánh", "Pate", ...], "done": [true, ...], "current": 4}])
##   show_prompt("E", "Thái dưa leo") / hide_prompt()
##   set_held("Dưa leo đã rửa", Color("#3F8A5C")) / clear_held()
##   add_bubble("lo", world_pos, "Lò · chín sau 4s", 0.7, UiTheme.CRUST) / remove_bubble("lo")
##   show_closeup("Chẻ dọc dưa leo", "bấm khi dao vào vùng xanh", 2, 3) / set_closeup_meter(needle, zone_from, zone_to) / hide_closeup()

signal pause_pressed

const T = preload("res://scripts/ui/ui_theme.gd")

var root: Control
var clock_label: Label
var clock_sub: Label
var tickets_row: HBoxContainer
var prompt_box: PanelContainer
var prompt_key: Label
var prompt_text: Label
var held_box: PanelContainer
var held_label: Label
var held_swatch: Panel
var closeup: PanelContainer
var closeup_title: Label
var closeup_step: Label
var closeup_meter: Meter
var closeup_dots: HBoxContainer
var _bubbles := {}  # id -> {node, pos}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = T.make_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Đồng hồ ca góc trái trên
	var clock := _card(18)
	T.place(clock, 0.0, 0.0, Rect2(24, 22, 0, 0))
	root.add_child(clock)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 12)
	clock.add_child(ch)
	var sun := SunIcon.new()
	sun.custom_minimum_size = Vector2(40, 40)
	sun.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ch.add_child(sun)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 0)
	ch.add_child(cv)
	clock_label = T.label("5:00 sáng", 30, T.INK, "display")
	cv.add_child(clock_label)
	clock_sub = T.label("", 13, T.MUTED, "bold")
	cv.add_child(clock_sub)

	# Phiếu từng ổ, giữa trên
	tickets_row = HBoxContainer.new()
	tickets_row.add_theme_constant_override("separation", 14)
	T.place(tickets_row, 0.5, 0.0, Rect2(-310, 18, 620, 0))
	tickets_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(tickets_row)

	var pause := T.icon_button("pause", "Menu (Esc)")
	pause.focus_mode = Control.FOCUS_NONE
	T.place(pause, 1.0, 0.0, Rect2(-80, 24, 56, 56))
	pause.pressed.connect(func(): pause_pressed.emit())
	root.add_child(pause)

	# Gợi ý thao tác ở trạm gần nhất
	prompt_box = PanelContainer.new()
	prompt_box.add_theme_stylebox_override("panel", T.box(T.INK, 999, 10, Color(0, 0, 0, 0), 0, 4, Color(0, 0, 0, 0.25)))
	T.place(prompt_box, 0.5, 1.0, Rect2(-150, -220, 300, 0))
	prompt_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(prompt_box)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 10)
	prompt_box.add_child(ph)
	var kc := PanelContainer.new()
	kc.add_theme_stylebox_override("panel", T.box(T.PAPER, 9, 9, T.INK, 2, 4, Color("#9C8E70")))
	prompt_key = T.label("E", 20, T.INK, "display")
	kc.add_child(prompt_key)
	ph.add_child(kc)
	prompt_text = T.label("", 20, T.PAPER, "bold")
	prompt_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(prompt_text)
	prompt_box.visible = false

	# Món đang cầm, trái dưới
	held_box = _card(18)
	T.place(held_box, 0.0, 1.0, Rect2(24, -22, 0, 0))
	held_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(held_box)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 12)
	held_box.add_child(hh)
	held_swatch = Panel.new()
	held_swatch.custom_minimum_size = Vector2(56, 56)
	hh.add_child(held_swatch)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hh.add_child(hv)
	hv.add_child(T.label("Đang cầm", 13, T.MUTED, "bold"))
	held_label = T.label("", 18, T.INK, "bold")
	hv.add_child(held_label)
	held_box.visible = false

	# Bảng cận cảnh, phải dưới
	closeup = PanelContainer.new()
	closeup.add_theme_stylebox_override("panel", T.box(T.PAPER, 20, 18, T.CRUST, 3, 6))
	T.place(closeup, 1.0, 1.0, Rect2(-494, -22, 470, 0))
	closeup.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(closeup)
	var cvb := VBoxContainer.new()
	cvb.add_theme_constant_override("separation", 10)
	closeup.add_child(cvb)
	closeup_step = T.label("", 12, T.MUTED, "bold")
	cvb.add_child(closeup_step)
	closeup_title = T.label("", 22, T.INK, "display")
	closeup_title.add_theme_constant_override("line_spacing", -10)
	closeup_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	cvb.add_child(closeup_title)
	closeup_meter = Meter.new()
	closeup_meter.custom_minimum_size = Vector2(0, 28)
	cvb.add_child(closeup_meter)
	closeup_dots = HBoxContainer.new()
	closeup_dots.add_theme_constant_override("separation", 8)
	cvb.add_child(closeup_dots)
	closeup.visible = false


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for id in _bubbles:
		var b: Dictionary = _bubbles[id]
		var node: Control = b.node
		node.visible = not cam.is_position_behind(b.pos)
		if node.visible:
			node.position = cam.unproject_position(b.pos) - Vector2(node.size.x / 2.0, node.size.y)


# ------------------------------------------------------------ API

func set_clock(text: String, sub := "") -> void:
	clock_label.text = text
	clock_sub.text = sub


func set_tickets(tickets: Array) -> void:
	for c in tickets_row.get_children():
		c.queue_free()
	for t in tickets:
		tickets_row.add_child(_ticket(t))


func show_prompt(key: String, text: String) -> void:
	prompt_key.text = key
	prompt_text.text = text
	prompt_box.visible = true


func hide_prompt() -> void:
	prompt_box.visible = false


func set_held(name: String, color := UiTheme.CRUST) -> void:
	held_label.text = name
	held_swatch.add_theme_stylebox_override("panel", T.box(color, 14, 0, T.INK, 2))
	held_box.visible = true


func clear_held() -> void:
	held_box.visible = false


## Bong bóng trạng thái nổi trên một trạm (lò, bột ủ...). ratio 0..1 là vòng tiến độ.
func add_bubble(id: String, world_pos: Vector3, text: String, ratio := -1.0, color := UiTheme.CRUST) -> void:
	var b: Dictionary = _bubbles.get(id, {})
	if b.is_empty():
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", T.box(T.PAPER, 999, 10, T.INK, 3))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		p.add_child(h)
		var ring := Ring.new()
		ring.custom_minimum_size = Vector2(36, 36)
		h.add_child(ring)
		var l := T.label("", 16, T.INK, "bold")
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		root.add_child(p)
		b = {"node": p, "ring": ring, "label": l}
		_bubbles[id] = b
	b.pos = world_pos
	b.label.text = text
	b.ring.visible = ratio >= 0.0
	b.ring.ratio = ratio
	b.ring.color = color
	b.ring.queue_redraw()


func remove_bubble(id: String) -> void:
	if _bubbles.has(id):
		_bubbles[id].node.queue_free()
		_bubbles.erase(id)


func show_closeup(title: String, how: String, step: int, total: int) -> void:
	closeup_step.text = "CẬN CẢNH · BƯỚC %d/%d" % [step, total]
	closeup_title.text = title + (" · " + how if how != "" else "")
	for c in closeup_dots.get_children():
		c.queue_free()
	for i in total:
		var d := Panel.new()
		d.custom_minimum_size = Vector2(16, 16)
		var col := T.LEAF if i < step - 1 else (T.CRUST if i == step - 1 else T.PAPER)
		d.add_theme_stylebox_override("panel", T.box(col, 999, 0, T.INK, 2))
		closeup_dots.add_child(d)
	closeup.visible = true


## Thanh canh giờ / giữ: needle và vùng xanh tính theo 0..1. needle < 0 thì ẩn kim.
func set_closeup_meter(needle: float, zone_from := -1.0, zone_to := -1.0, fill := -1.0) -> void:
	closeup_meter.needle = needle
	closeup_meter.zone = Vector2(zone_from, zone_to)
	closeup_meter.fill = fill
	closeup_meter.queue_redraw()


func hide_closeup() -> void:
	closeup.visible = false


# ------------------------------------------------------------ dựng

func _card(pad: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.box(T.PAPER, 18, pad, T.INK, 3, 5, Color(T.INK, 0.35)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _ticket(t: Dictionary) -> Control:
	var p := PanelContainer.new()
	var s := T.box(T.PAPER, 16, 0, T.INK, 3, 5, Color(T.INK, 0.35))
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		s.set_content_margin(side, 3)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size.x = 300
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	v.add_child(T.stripe(8, 13))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 10)
	v.add_child(m)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	m.add_child(inner)
	var items: Array = t.get("items", [])
	var done: Array = t.get("done", [])
	var current: int = t.get("current", -1)
	var count := 0
	for d in done:
		count += 1 if d else 0
	var head := HBoxContainer.new()
	var tl := T.label(t.get("title", ""), 16, T.INK, "bold")
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	head.add_child(T.label("%d/%d" % [count, items.size()], 13, T.LEAF if count > 0 else T.MUTED, "bold"))
	inner.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	inner.add_child(row)
	for i in items.size():
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(34, 34)
		var is_done: bool = i < done.size() and done[i]
		var col := T.LEAF if is_done else (T.AMBER if i == current else T.PAPER)
		chip.add_theme_stylebox_override("panel", T.box(col, 10, 3, T.INK, 2))
		var l := T.label(str(items[i]).left(4), 11, T.PAPER if is_done else T.INK, "bold")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_child(l)
		chip.tooltip_text = str(items[i])
		row.add_child(chip)
	return p


class Ring:
	extends Control
	var ratio := 0.0
	var color := UiTheme.CRUST
	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 3.0
		draw_circle(c, r, UiTheme.PAPER)
		draw_arc(c, r, 0, TAU, 32, UiTheme.SAND, 5.0, true)
		draw_arc(c, r, -PI / 2, -PI / 2 + TAU * clampf(ratio, 0, 1), 32, color, 5.0, true)


class Meter:
	extends Control
	var needle := -1.0
	var zone := Vector2(-1, -1)
	var fill := -1.0
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(UiTheme.box(UiTheme.SAND, 999, 0, Color(0, 0, 0, 0), 0), r)
		if fill >= 0.0:
			draw_style_box(UiTheme.box(UiTheme.CRUST, 999, 0, Color(0, 0, 0, 0), 0), Rect2(0, 0, size.x * clampf(fill, 0, 1), size.y))
		if zone.x >= 0.0:
			draw_rect(Rect2(size.x * zone.x, 2, size.x * (zone.y - zone.x), size.y - 4), Color("#9CC96B"))
		if needle >= 0.0:
			draw_rect(Rect2(size.x * clampf(needle, 0, 1) - 2.5, 0, 5, size.y), UiTheme.INK)
		draw_style_box(UiTheme.box(Color(0, 0, 0, 0), 999, 0, UiTheme.INK, 2), r)


class SunIcon:
	extends Control
	func _draw() -> void:
		var c := Vector2(size.x / 2, size.y * 0.6)
		draw_circle(c, 8, UiTheme.AMBER)
		draw_arc(c, 8, 0, TAU, 24, UiTheme.CRUST, 2.0, true)
		for a in [-PI / 2, -PI / 4, -3 * PI / 4, 0.0, PI]:
			var d := Vector2(cos(a), sin(a))
			draw_line(c + d * 12, c + d * 16, UiTheme.CRUST, 2.5, true)
		draw_line(Vector2(2, size.y - 4), Vector2(size.x - 2, size.y - 4), UiTheme.CRUST, 2.5, true)
