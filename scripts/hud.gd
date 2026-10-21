extends CanvasLayer
## Giao diện: thẻ đơn, đồng hồ, 5 chấm tiến độ, khoảng cách, thông báo,
## và ba màn hình phủ: bắt đầu, tạm dừng, kết thúc.

signal start_pressed
signal restart_pressed

const PAPER := Color("#FFF8EA")
const INK := Color("#1F2A2A")
const CRUST := Color("#D98E2B")
const RED := Color("#C8412F")

var order_label: Label
var timer_ring: TimerRing
var dots: Array[Panel] = []
var distance_label: Label
var toast: Label
var hint: Label
var start_screen: Control
var pause_screen: Control
var end_screen: Control
var end_text: Label
var _toast_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 1. Thẻ đơn góc trái
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(PAPER, 10, 14))
	card.position = Vector2(24, 24)
	root.add_child(card)
	order_label = _label("", 20, INK)
	card.add_child(order_label)

	# 2. Đồng hồ giữa trên
	timer_ring = TimerRing.new()
	timer_ring.size = Vector2(96, 96)
	_place(timer_ring, 0.5, 0.0, Rect2(-48, 16, 96, 96))
	timer_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(timer_ring)

	# 4. Năm chấm tiến độ góc phải
	var row := HBoxContainer.new()
	_place(row, 1.0, 0.0, Rect2(-24 - 5 * 26, 30, 5 * 26, 20))
	row.add_theme_constant_override("separation", 6)
	root.add_child(row)
	for i in 5:
		var d := Panel.new()
		d.custom_minimum_size = Vector2(20, 20)
		row.add_child(d)
		dots.append(d)
	set_progress([])

	# Khoảng cách còn lại, dưới giữa
	distance_label = _label("", 20, PAPER)
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _box(INK, 999, 16))
	pill.add_child(distance_label)
	distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(pill, 0.5, 1.0, Rect2(-160, -90, 320, 40))
	root.add_child(pill)

	toast = _label("", 30, PAPER)
	toast.add_theme_color_override("font_outline_color", INK)
	toast.add_theme_constant_override("outline_size", 10)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(toast, 0.5, 0.5, Rect2(-500, -200, 1000, 50))
	root.add_child(toast)

	hint = _label("WASD chạy · Shift chạy nhanh · Space nhảy · Chuột xoay camera · Esc tạm dừng", 14, PAPER)
	hint.add_theme_color_override("font_outline_color", INK)
	hint.add_theme_constant_override("outline_size", 6)
	_place(hint, 0.0, 1.0, Rect2(20, -36, 900, 24))
	root.add_child(hint)

	start_screen = _overlay(
		"Mèo Giao Bánh Mì",
		"Bản khối thô · tuần 1\n\nLò bánh Cô Ba đã mở! 5 đơn đang chờ.\nChạy tới lò để nhận bánh, rồi theo mũi tên đỏ đi giao trước khi hết giờ.\nĐơn 5 có Chó Mực canh hẻm: nhảy qua đầu nó, đừng để bị đớp.",
		"Bắt đầu (Enter)", func(): start_pressed.emit())
	root.add_child(start_screen)

	pause_screen = _overlay("Tạm dừng", "Nhấn Esc để chơi tiếp.", "Chơi tiếp", func(): toggle_pause())
	pause_screen.visible = false
	root.add_child(pause_screen)

	end_screen = _overlay("Hết ca giao bánh!", "", "Chơi lại (Enter)", func(): restart_pressed.emit())
	end_text = end_screen.find_child("Body", true, false)
	end_screen.visible = false
	root.add_child(end_screen)

	show_playing_ui(false)


func _unhandled_input(event: InputEvent) -> void:
	# Lúc đang tạm dừng, main.gd bị dừng theo nên HUD tự bắt phím Esc để chơi tiếp
	if get_tree().paused and event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		toast.modulate.a = clampf(_toast_time / 0.4, 0.0, 1.0)


func show_playing_ui(on: bool) -> void:
	for n in [order_label.get_parent(), timer_ring, dots[0].get_parent(), distance_label.get_parent(), hint]:
		n.visible = on


func set_order(index: int, total: int, title: String, detail: String) -> void:
	order_label.text = "Đơn %d/%d\n%s\n%s" % [index + 1, total, title, detail]


func set_timer(seconds: float, limit: float, active: bool) -> void:
	timer_ring.active = active
	timer_ring.seconds = maxf(seconds, 0.0)
	timer_ring.ratio = seconds / limit if limit > 0 else 0.0


func set_distance(meters: float, what: String) -> void:
	distance_label.text = "%s · còn %d m" % [what, roundi(meters)]


## results: mỗi phần tử là số sao của đơn đã xong (0 = trễ)
func set_progress(results: Array) -> void:
	for i in dots.size():
		var col := PAPER
		if i < results.size():
			col = CRUST if results[i] > 0 else RED
		dots[i].add_theme_stylebox_override("panel", _box(col, 10, 0, INK))


func show_toast(text: String, seconds := 2.0) -> void:
	toast.text = text
	_toast_time = seconds
	toast.modulate.a = 1.0


func toggle_pause() -> void:
	var tree := get_tree()
	tree.paused = not tree.paused
	pause_screen.visible = tree.paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if tree.paused else Input.MOUSE_MODE_CAPTURED


func show_end(lines: String) -> void:
	show_playing_ui(false)
	end_text.text = lines
	end_screen.visible = true


func _overlay(title: String, body: String, button_text: String, on_press: Callable) -> Control:
	var bg := ColorRect.new()
	bg.color = Color(INK, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	var t := _label(title, 56, CRUST)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var b := _label(body, 20, PAPER)
	b.name = "Body"
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(b)
	var btn := Button.new()
	btn.text = button_text
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_stylebox_override("normal", _box(CRUST, 999, 12))
	btn.add_theme_stylebox_override("hover", _box(CRUST.lightened(0.15), 999, 12))
	btn.add_theme_stylebox_override("pressed", _box(CRUST.darkened(0.15), 999, 12))
	btn.add_theme_stylebox_override("focus", _box(CRUST, 999, 12, PAPER))
	btn.add_theme_color_override("font_color", Color("#2A1A05"))
	btn.add_theme_color_override("font_hover_color", Color("#2A1A05"))
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(on_press)
	box.add_child(btn)
	return bg


## Neo control vào một điểm của màn hình (ax, ay từ 0 đến 1) rồi đặt khung lệch từ điểm đó.
func _place(c: Control, ax: float, ay: float, r: Rect2) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.end.x
	c.offset_bottom = r.end.y


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box(color: Color, radius: int, pad: int, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	if border.a > 0:
		s.border_color = border
		s.set_border_width_all(2)
	return s
