extends "res://scripts/hud.gd"
## Giao diện màn bếp. Dùng lại khung, nút, chữ của hud.gd (màn giao bánh) cho đồng bộ.
## - Góc trái: công thức 2 ổ, đánh dấu bước đã xong, món đang cầm.
## - Giữa trên: đồng hồ 2:30. Góc phải: số ổ xong và trạng thái lò.
## - Dưới giữa: gợi ý phím E ở trạm đang đứng, hoặc trạm nên tới tiếp.
## - Cận cảnh: tên bước to, cách bấm, thước đo (độ đầy, vùng xanh, kim), các ô chọn, các chấm bước.

signal go_delivery_pressed
signal option_pressed(index: int)

var recipe_label: Label
var status_label: Label
var prompt_label: Label
var step_panel: Control
var start_text: Label
var step_title: Label
var step_hint: Label
var step_dots: HBoxContainer
var meter: Meter
var pick_row: HBoxContainer
var _flash_t := 0.0


## Thước của cận cảnh: nền, vùng xanh (thả hoặc bấm trong vùng này), phần đã đầy, kim.
class Meter extends Control:
	var fill := 0.0
	var zone := Vector2(-1, -1)
	var needle := -1.0
	var bad := false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("#1F3A3D"))
		var inner := r.grow(-4)
		draw_rect(inner, Color("#FFF8EA", 0.25))
		if zone.x >= 0.0:
			draw_rect(Rect2(inner.position + Vector2(inner.size.x * zone.x, 0), Vector2(inner.size.x * (zone.y - zone.x), inner.size.y)), Color("#7BC35E"))
		if fill > 0.0:
			draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(fill, 0.0, 1.0), inner.size.y)), Color("#C8412F") if bad else Color("#D98E2B", 0.9))
		if needle >= 0.0:
			var x := inner.position.x + inner.size.x * clampf(needle, 0.0, 1.0)
			draw_rect(Rect2(x - 3, r.position.y - 6, 6, r.size.y + 12), Color("#FFF8EA"))
			draw_rect(Rect2(x - 1, r.position.y - 6, 2, r.size.y + 12), Color("#1F3A3D"))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(PAPER, 10, 14))
	card.position = Vector2(24, 24)
	root.add_child(card)
	recipe_label = _label("", 17, INK)
	card.add_child(recipe_label)
	order_label = recipe_label  # để các hàm chung của hud.gd không lỗi

	timer_ring = TimerRing.new()
	_place(timer_ring, 0.5, 0.0, Rect2(-48, 16, 96, 96))
	timer_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(timer_ring)

	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", _box(PAPER, 10, 14))
	_place(right, 1.0, 0.0, Rect2(-264, 24, 240, 0))
	root.add_child(right)
	status_label = _label("", 18, INK)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(status_label)

	prompt_label = _label("", 22, PAPER)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _box(INK, 999, 18))
	pill.add_child(prompt_label)
	_place(pill, 0.5, 1.0, Rect2(-260, -96, 520, 44))
	root.add_child(pill)
	distance_label = prompt_label

	# Khung cận cảnh: tên bước + "Bấm E" + chấm các bước
	step_panel = VBoxContainer.new()
	step_panel.add_theme_constant_override("separation", 6)
	_place(step_panel, 0.5, 1.0, Rect2(-420, -262, 840, 222))
	step_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(step_panel)
	step_title = _label("", 44, PAPER)
	step_title.add_theme_color_override("font_outline_color", INK)
	step_title.add_theme_constant_override("outline_size", 12)
	step_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_panel.add_child(step_title)
	step_hint = _label("", 22, Color("#FFE2A8"))
	step_hint.add_theme_color_override("font_outline_color", INK)
	step_hint.add_theme_constant_override("outline_size", 8)
	step_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_panel.add_child(step_hint)
	var meter_box := CenterContainer.new()
	step_panel.add_child(meter_box)
	meter = Meter.new()
	meter.custom_minimum_size = Vector2(420, 26)
	meter_box.add_child(meter)
	pick_row = HBoxContainer.new()
	pick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pick_row.add_theme_constant_override("separation", 8)
	step_panel.add_child(pick_row)
	step_dots = HBoxContainer.new()
	step_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	step_dots.add_theme_constant_override("separation", 8)
	step_panel.add_child(step_dots)
	step_panel.visible = false

	toast = _label("", 30, PAPER)
	toast.add_theme_color_override("font_outline_color", INK)
	toast.add_theme_constant_override("outline_size", 10)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(toast, 0.5, 0.5, Rect2(-500, -230, 1000, 50))
	root.add_child(toast)

	hint = _label("WASD chạy · E (hoặc Enter) làm việc ở trạm · Space nhảy · Esc tạm dừng · F3 hiện FPS", 14, PAPER)
	hint.add_theme_color_override("font_outline_color", INK)
	hint.add_theme_constant_override("outline_size", 6)
	_place(hint, 0.0, 1.0, Rect2(20, -36, 900, 24))
	root.add_child(hint)

	fps_label = _label("", 16, PAPER)
	fps_label.add_theme_color_override("font_outline_color", INK)
	fps_label.add_theme_constant_override("outline_size", 6)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(fps_label, 1.0, 1.0, Rect2(-224, -40, 200, 24))
	fps_label.visible = false
	root.add_child(fps_label)

	start_screen = _overlay(
		"Bếp Cô Ba",
		"Trước giờ giao, Bơ phụ Cô Ba làm 2 ổ bánh mì trong 2 phút 30 giây.\n\n"
		+ "Xúc bột → nhào, ủ, tạo hình ở bàn gỗ → nướng trong lò gạch (6 giây chín, để quá 5 giây là cháy)\n"
		+ "→ làm đồ chua, rửa rau ở bồn, sơ chế dưa leo, chả, thịt trên thớt → ráp ổ ở bàn giữa → bỏ vào xe bánh mì.\n"
		+ "Mỗi lần chỉ cầm được một món. Tới trạm rồi bấm E; mỗi bước có cách làm riêng: bấm, giữ, canh giờ,\n"
		+ "bấm xen kẽ, vuốt, xoay, nhúng hay chọn đúng thứ tự (xem dòng nhắc dưới màn hình).\n\n"
		+ "Làm khéo được tới 3 sao: mỗi sao cộng 2 giây vào đồng hồ của mọi đơn giao.",
		"Vào bếp (Enter)", func(): start_pressed.emit())
	start_text = start_screen.find_child("Body", true, false)
	root.add_child(start_screen)

	pause_screen = _overlay("Tạm dừng", "Nhấn Esc để làm tiếp.", "Làm tiếp", func(): toggle_pause())
	pause_screen.visible = false
	root.add_child(pause_screen)

	end_screen = _overlay("Xong ca bếp!", "", "Đi giao bánh (Enter)", func(): go_delivery_pressed.emit())
	end_text = end_screen.find_child("Body", true, false)
	end_screen.visible = false
	root.add_child(end_screen)

	show_playing_ui(false)


func show_playing_ui(on: bool) -> void:
	for n in [recipe_label.get_parent(), timer_ring, status_label.get_parent(), prompt_label.get_parent(), hint]:
		n.visible = on
	if not on:
		step_panel.visible = false


func toggle_pause() -> void:
	var tree := get_tree()
	tree.paused = not tree.paused
	pause_screen.visible = tree.paused


func set_recipe(text: String) -> void:
	recipe_label.text = text


func set_status(text: String) -> void:
	status_label.text = text


func set_prompt(text: String, ready: bool) -> void:
	prompt_label.text = text
	prompt_label.add_theme_color_override("font_color", Color("#FFE2A8") if ready else PAPER)


## Khung cận cảnh. index: bước đang làm (0..count-1); hint_text: cách bấm của bước.
func show_step(title: String, index: int, count: int, hint_text: String) -> void:
	step_panel.visible = true
	prompt_label.get_parent().visible = false
	step_title.text = title
	if _flash_t <= 0.0:
		step_hint.text = hint_text
	if step_dots.get_child_count() != count:
		for c in step_dots.get_children():
			step_dots.remove_child(c)
			c.free()
		for i in count:
			var d := Panel.new()
			d.custom_minimum_size = Vector2(18, 18)
			step_dots.add_child(d)
	for i in count:
		var col := CRUST if i < index else (PAPER if i == index else Color(PAPER, 0.35))
		(step_dots.get_child(i) as Panel).add_theme_stylebox_override("panel", _box(col, 9, 0, INK))


func hide_step() -> void:
	step_panel.visible = false
	prompt_label.get_parent().visible = true


## Thước: fill < 0 thì ẩn thước. needle < 0 thì không có kim.
func set_meter(fill: float, zone := Vector2(-1, -1), needle := -1.0) -> void:
	meter.get_parent().visible = fill >= 0.0
	meter.fill = fill
	meter.zone = zone
	meter.needle = needle
	meter.bad = _flash_t > 0.0
	meter.queue_redraw()


## Các ô chọn. done[i] = đã chọn đúng; cursor = ô đang trỏ bằng ← →. options rỗng thì ẩn.
func set_pick(options: Array, done: Array, cursor: int) -> void:
	pick_row.visible = not options.is_empty()
	if pick_row.get_child_count() != options.size():
		for c in pick_row.get_children():
			pick_row.remove_child(c)
			c.free()
		for i in options.size():
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 18)
			b.pressed.connect(func(): option_pressed.emit(i))
			pick_row.add_child(b)
	for i in options.size():
		var b: Button = pick_row.get_child(i)
		b.text = "%d · %s" % [i + 1, options[i]]
		b.disabled = done[i]
		var col := CRUST if done[i] else (Color("#FFE2A8") if i == cursor else PAPER)
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, _box(col, 8, 8, INK))
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_disabled_color", INK)


## Bấm sai: dòng nhắc đỏ lên và rung nhẹ.
func flash(text: String) -> void:
	_flash_t = 0.9
	step_hint.text = text
	step_hint.add_theme_color_override("font_color", Color("#FF8A7A"))
	var tw := create_tween()
	var x0 := step_panel.position.x
	for k in 4:
		tw.tween_property(step_panel, "position:x", x0 + (10 if k % 2 == 0 else -10), 0.04)
	tw.tween_property(step_panel, "position:x", x0, 0.04)


func _process(delta: float) -> void:
	super(delta)
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			step_hint.add_theme_color_override("font_color", Color("#FFE2A8"))
