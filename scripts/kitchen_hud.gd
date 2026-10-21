extends "res://scripts/hud.gd"
## Giao diện màn bếp. Dùng lại khung, nút, chữ của hud.gd (màn giao bánh) cho đồng bộ.
## - Góc trái: công thức 2 ổ, đánh dấu bước đã xong, món đang cầm.
## - Giữa trên: đồng hồ 2:30. Góc phải: số ổ xong và trạng thái lò.
## - Dưới giữa: gợi ý phím E ở trạm đang đứng, hoặc trạm nên tới tiếp.
## - Cận cảnh: tên bước to, số lần bấm, các chấm bước.

signal go_delivery_pressed

var recipe_label: Label
var status_label: Label
var prompt_label: Label
var step_panel: Control
var step_title: Label
var step_hint: Label
var step_dots: HBoxContainer


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
	_place(step_panel, 0.5, 1.0, Rect2(-400, -190, 800, 150))
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
		+ "Xúc bột → nhồi và tạo hình ở bàn gỗ → nướng trong lò gạch (6 giây chín, để quá 5 giây là cháy)\n"
		+ "→ lấy rau, chả, thịt ở kệ → sơ chế trên thớt → ráp ổ ở bàn giữa → bỏ vào tủ kính.\n"
		+ "Mỗi lần chỉ cầm được một món. Tới trạm rồi bấm E, mỗi bước bấm E để Bơ làm.\n\n"
		+ "Làm khéo được tới 3 sao: mỗi sao cộng 2 giây vào đồng hồ của mọi đơn giao.",
		"Vào bếp (Enter)", func(): start_pressed.emit())
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


## Khung cận cảnh. index: bước đang làm (0..count-1); presses_left: số lần bấm E còn lại của bước.
func show_step(title: String, index: int, count: int, presses_left: int, busy: bool) -> void:
	step_panel.visible = true
	prompt_label.get_parent().visible = false
	step_title.text = title
	if busy:
		step_hint.text = "..."
	else:
		step_hint.text = "Bấm E" if presses_left <= 1 else "Bấm E × %d" % presses_left
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
