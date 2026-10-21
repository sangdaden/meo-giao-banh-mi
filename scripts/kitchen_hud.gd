extends "res://scripts/hud.gd"
## Giao diện màn bếp, cùng kiểu với HUD ở phố (bản phác thảo Sang duyệt, artboard 7):
## thẻ giấy viền mực, phím vẽ thành nút phím (không dùng ký tự mũi tên vì font không có).
## - Trái trên: thẻ công thức 2 ổ, từng việc có vòng tròn đánh dấu xong, món đang cầm.
## - Giữa trên: đồng hồ ca. Phải trên: thẻ số ổ xong, lò, bột.
## - Dưới giữa: viên nhắc "[E] tên trạm" khi đứng ở trạm, hoặc trạm nên tới tiếp.
## - Cận cảnh: thẻ giấy phải dưới (chừa chỗ giữa màn hình cho hai chân Bơ): "CẬN CẢNH · BƯỚC 2/4",
##   tên bước, hàng phím cần bấm, thước đo (độ đầy, vùng xanh, kim), các ô chọn, các chấm bước.
## - Phải dưới khi đi lại: hàng phím gợi ý như ở phố.

signal go_delivery_pressed
signal option_pressed(index: int)

## Phím vẽ bằng hình thay cho ký tự (font Be Vietnam Pro không có mũi tên)
const GLYPHS := ["←", "→", "↑", "↓", "chuột"]

var recipe_label: Label        # giữ tên cũ: dòng tiêu đề thẻ công thức
var recipe_rows: VBoxContainer
var held_label: Label
var status_label: Label
var prompt_label: Label
var prompt_key: Control
var step_panel: Control
var start_text: Label
var step_title: Label
var step_count: Label
var step_hint: HBoxContainer   # hàng phím + cách bấm của bước
var step_flash: Label          # dòng báo bấm sai, thay chỗ hàng phím một lúc
var step_dots: HBoxContainer
var meter: Meter
var pick_row: HFlowContainer
var _flash_t := 0.0
var _hint_key := ""


## Thước của cận cảnh: rãnh cát, vùng xanh (thả hoặc bấm trong vùng này), phần đã đầy, kim.
class Meter extends Control:
	var fill := 0.0
	var zone := Vector2(-1, -1)
	var needle := -1.0
	var bad := false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(UiTheme.box(UiTheme.SAND, 999, 0, Color(0, 0, 0, 0), 0), r)
		if zone.x >= 0.0:
			draw_rect(Rect2(size.x * zone.x, 3, size.x * (zone.y - zone.x), size.y - 6), Color("#9CC96B"))
		if fill > 0.0:
			var w := maxf(size.x * clampf(fill, 0.0, 1.0), size.y)
			draw_style_box(UiTheme.box(UiTheme.RED if bad else UiTheme.CRUST, 999, 0, Color(0, 0, 0, 0), 0), Rect2(0, 0, w, size.y))
		if needle >= 0.0:
			var x := size.x * clampf(needle, 0.0, 1.0)
			draw_rect(Rect2(x - 3.5, -5, 7, size.y + 10), UiTheme.INK)
			draw_rect(Rect2(x - 1, -3, 2, size.y + 6), UiTheme.PAPER)
		draw_style_box(UiTheme.box(Color(0, 0, 0, 0), 999, 0, UiTheme.INK, 2), r)


## Hình trong nút phím: mũi tên hoặc con chuột.
class Glyph extends Control:
	var kind := "←"

	func _draw() -> void:
		var c := size / 2.0
		var col := UiTheme.INK
		if kind == "chuột":
			var r := Rect2(c - Vector2(6, 9), Vector2(12, 18))
			draw_style_box(UiTheme.box(Color(0, 0, 0, 0), 6, 0, col, 2), r)
			draw_line(c + Vector2(0, -8), c + Vector2(0, -2), col, 2.0, true)
			draw_rect(Rect2(c + Vector2(-5, -8), Vector2(5, 6)), Color(col, 0.35))  # nút trái
			return
		var dir: Vector2 = {"←": Vector2.LEFT, "→": Vector2.RIGHT, "↑": Vector2.UP, "↓": Vector2.DOWN}[kind]
		var side := Vector2(-dir.y, dir.x)
		var tip := c + dir * 7.0
		draw_line(c - dir * 7.0, c + dir * 1.0, col, 3.0, true)
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 7.0 + side * 6.0, tip - dir * 7.0 - side * 6.0]), col)


## Vòng tròn đánh dấu việc trong thẻ công thức (font không có ✓ ○).
class Tick extends Control:
	var done := false

	func _draw() -> void:
		var c := size / 2.0
		if done:
			draw_circle(c, 9, UiTheme.LEAF)
			draw_polyline(PackedVector2Array([c + Vector2(-4.5, 0), c + Vector2(-1, 3.5), c + Vector2(5, -3.5)]), UiTheme.PAPER, 2.5, true)
		else:
			draw_arc(c, 8, 0, TAU, 24, Color(UiTheme.INK, 0.45), 2.0, true)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = T.make_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	play_root = Control.new()
	play_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(play_root)

	# Thẻ công thức, trái trên
	var card := _paper(16)
	card.position = Vector2(24, 22)
	card.custom_minimum_size.x = 300
	play_root.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card.add_child(cv)
	recipe_label = T.label("", 20, INK, "display")
	cv.add_child(recipe_label)
	recipe_rows = VBoxContainer.new()
	recipe_rows.add_theme_constant_override("separation", 3)
	cv.add_child(recipe_rows)
	var held_row := HBoxContainer.new()
	held_row.add_theme_constant_override("separation", 8)
	cv.add_child(held_row)
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", T.box(T.TEAL, 999, 10, Color(0, 0, 0, 0), 0))
	tag.add_child(T.label("Đang cầm", 12, PAPER, "bold"))
	held_row.add_child(tag)
	held_label = T.label("", 15, INK, "bold")
	held_row.add_child(held_label)
	order_label = recipe_label  # để các hàm chung của hud.gd không lỗi

	timer_ring = TimerRing.new()
	_place(timer_ring, 0.5, 0.0, Rect2(-48, 16, 96, 96))
	timer_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.add_child(timer_ring)

	var right := _paper(16)
	_place(right, 1.0, 0.0, Rect2(-264, 22, 240, 0))
	play_root.add_child(right)
	status_label = T.label("", 16, INK, "bold")
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(status_label)

	# Viên nhắc dưới giữa: [E] tên trạm
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", T.box(INK, 999, 12, Color(0, 0, 0, 0), 0, 4, Color(0, 0, 0, 0.25)))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(pill, 0.5, 1.0, Rect2(-150, -112, 300, 0))
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	play_root.add_child(pill)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 10)
	pill.add_child(ph)
	prompt_key = _keycap("E", 18)
	ph.add_child(prompt_key)
	prompt_label = T.label("", 20, PAPER, "bold")
	prompt_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(prompt_label)
	distance_label = prompt_label

	# Thẻ cận cảnh, phải dưới
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.box(PAPER, 20, 18, T.CRUST, 3, 6))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel, 1.0, 1.0, Rect2(-494, -22, 470, 0))
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	play_root.add_child(panel)
	step_panel = panel
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	panel.add_child(sv)
	step_count = T.label("", 12, T.MUTED, "bold")
	sv.add_child(step_count)
	step_title = T.label("", 28, INK, "display")
	step_title.add_theme_constant_override("line_spacing", -10)
	step_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	sv.add_child(step_title)
	step_hint = HBoxContainer.new()
	step_hint.add_theme_constant_override("separation", 6)
	sv.add_child(step_hint)
	step_flash = T.label("", 17, T.RED, "bold")
	step_flash.autowrap_mode = TextServer.AUTOWRAP_WORD
	step_flash.visible = false
	sv.add_child(step_flash)
	meter = Meter.new()
	meter.custom_minimum_size = Vector2(0, 26)
	sv.add_child(meter)
	pick_row = HFlowContainer.new()
	pick_row.add_theme_constant_override("h_separation", 8)
	pick_row.add_theme_constant_override("v_separation", 8)
	sv.add_child(pick_row)
	step_dots = HBoxContainer.new()
	step_dots.add_theme_constant_override("separation", 8)
	sv.add_child(step_dots)
	step_panel.visible = false

	toast = T.outlined("", 28, PAPER, 10)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD
	_place(toast, 0.5, 0.0, Rect2(-330, 130, 660, 80))
	play_root.add_child(toast)

	# Gợi ý phím khi đi lại, phải dưới như ở phố
	var keys := VBoxContainer.new()
	keys.add_theme_constant_override("separation", 6)
	keys.alignment = BoxContainer.ALIGNMENT_END
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(keys, 1.0, 1.0, Rect2(-560, -80, 532, 50))
	play_root.add_child(keys)
	keys.add_child(_key_line([["W A S D", "chạy"], ["E", "làm việc ở trạm"], ["Space", "nhảy"], ["Esc", "tạm dừng"]]))
	hint = keys

	fps_label = T.outlined("", 16, PAPER, 6)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(fps_label, 1.0, 0.0, Rect2(-260, 150, 232, 24))
	fps_label.visible = false
	play_root.add_child(fps_label)

	start_screen = _overlay(
		"Bếp Cô Ba",
		"Trước giờ giao, Bơ phụ Cô Ba làm 2 ổ bánh mì trong 3 phút 30 giây.\n\n"
		+ "Xúc bột, nhào, ủ, tạo hình ở bàn gỗ, rồi nướng trong lò gạch (chín thì lấy ra kẻo cháy).\n"
		+ "Làm đồ chua, rửa rau ở bồn, sơ chế dưa leo, chả, thịt trên thớt, ráp ổ ở bàn giữa, bỏ vào xe bánh mì.\n"
		+ "Mỗi lần chỉ cầm được một món. Tới trạm rồi bấm E; mỗi bước có cách làm riêng: bấm, giữ, canh giờ,\n"
		+ "bấm xen kẽ, vuốt, xoay, nhúng hay chọn đúng thứ tự (thẻ cận cảnh góc phải chỉ phím cần bấm).\n\n"
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

	get_viewport().size_changed.connect(_apply_scale)
	_apply_scale()
	show_playing_ui(false)


func show_playing_ui(on: bool) -> void:
	for n in [recipe_label.get_parent().get_parent(), timer_ring, status_label.get_parent(), prompt_label.get_parent().get_parent(), hint]:
		n.visible = on
	if not on:
		step_panel.visible = false


func toggle_pause() -> void:
	var tree := get_tree()
	tree.paused = not tree.paused
	pause_screen.visible = tree.paused


## Công thức: dòng đầu là tiêu đề; dòng bắt đầu bằng "✓ " / "○ " thành việc có vòng đánh dấu;
## dòng "Đang cầm: ..." vào ô món đang cầm; dòng khác giữ nguyên.
func set_recipe(text: String) -> void:
	var lines := text.split("\n", false)
	if lines.is_empty():
		return
	recipe_label.text = lines[0]
	var rows: Array = []
	var held := ""
	for i in range(1, lines.size()):
		var l: String = lines[i]
		if l.begins_with("Đang cầm: "):
			held = l.trim_prefix("Đang cầm: ")
		elif l.begins_with("✓ ") or l.begins_with("○ "):
			rows.append([l.begins_with("✓ "), l.substr(2)])
		else:
			rows.append([null, l])
	held_label.text = held
	held_label.get_parent().visible = held != ""
	while recipe_rows.get_child_count() < rows.size():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var t := Tick.new()
		t.custom_minimum_size = Vector2(20, 20)
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(t)
		h.add_child(T.label("", 15, INK, "body"))
		recipe_rows.add_child(h)
	for i in recipe_rows.get_child_count():
		var h: HBoxContainer = recipe_rows.get_child(i)
		h.visible = i < rows.size()
		if not h.visible:
			continue
		var t: Tick = h.get_child(0)
		var lab: Label = h.get_child(1)
		t.visible = rows[i][0] != null
		if t.visible and t.done != rows[i][0]:
			t.done = rows[i][0]
			t.queue_redraw()
		lab.text = rows[i][1]
		lab.add_theme_color_override("font_color", T.MUTED if rows[i][0] == true else INK)


func set_status(text: String) -> void:
	status_label.text = text


## Viên nhắc dưới giữa. ready = đang đứng ở trạm: hiện nút phím E; không thì chỉ chữ "Tới ...".
func set_prompt(text: String, ready: bool) -> void:
	prompt_label.text = text
	prompt_key.visible = ready
	prompt_label.add_theme_color_override("font_color", T.AMBER if ready else PAPER)
	prompt_label.get_parent().get_parent().visible = text != "" and not step_panel.visible and hint.visible


## Thẻ cận cảnh. index: bước đang làm (0..count-1); hint_parts: KitchenInput.hint()
## (mảng: phần tử Array là nhóm phím, String là chữ).
func show_step(title: String, index: int, count: int, hint_parts: Array) -> void:
	step_panel.visible = true
	prompt_label.get_parent().get_parent().visible = false
	hint.visible = false
	step_count.text = "CẬN CẢNH · BƯỚC %d/%d" % [index + 1, count]
	step_title.text = title
	var key := str(hint_parts)
	if key != _hint_key:
		_hint_key = key
		for c in step_hint.get_children():
			step_hint.remove_child(c)
			c.free()
		for part in hint_parts:
			if part is Array:
				for k in part:
					step_hint.add_child(_keycap(k, 16))
			else:
				var l := T.label(str(part), 16, T.MUTED if str(part) == "hoặc" else INK, "bold")
				l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				step_hint.add_child(l)
	if step_dots.get_child_count() != count:
		for c in step_dots.get_children():
			step_dots.remove_child(c)
			c.free()
		for i in count:
			var d := Panel.new()
			d.custom_minimum_size = Vector2(16, 16)
			step_dots.add_child(d)
	for i in count:
		var col := T.LEAF if i < index else (T.CRUST if i == index else PAPER)
		(step_dots.get_child(i) as Panel).add_theme_stylebox_override("panel", T.box(col, 999, 0, INK, 2))


func hide_step() -> void:
	step_panel.visible = false
	prompt_label.get_parent().get_parent().visible = prompt_label.text != ""
	hint.visible = timer_ring.visible


## Thước: fill < 0 thì ẩn thước. needle < 0 thì không có kim.
func set_meter(fill: float, zone := Vector2(-1, -1), needle := -1.0) -> void:
	meter.visible = fill >= 0.0
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
			b.add_theme_font_override("font", T.font("bold"))
			b.add_theme_font_size_override("font_size", 16)
			b.pressed.connect(func(): option_pressed.emit(i))
			pick_row.add_child(b)
	for i in options.size():
		var b: Button = pick_row.get_child(i)
		b.text = "%d  %s" % [i + 1, options[i]]
		b.disabled = done[i]
		var col := T.LEAF if done[i] else (T.AMBER if i == cursor else PAPER)
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, T.box(col, 12, 10, INK, 2, 0 if done[i] else 3))
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", INK)
		b.add_theme_color_override("font_pressed_color", INK)
		b.add_theme_color_override("font_disabled_color", PAPER)


## Bấm sai: dòng báo đỏ thay hàng phím một lúc, thẻ rung nhẹ.
func flash(text: String) -> void:
	_flash_t = 0.9
	step_flash.text = text
	step_flash.visible = true
	step_hint.visible = false
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
			step_flash.visible = false
			step_hint.visible = true


func _paper(pad: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.box(PAPER, 18, pad, INK, 3, 5, Color(INK, 0.35)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Nút phím như ở phố; mũi tên và chuột vẽ bằng hình.
func _keycap(text: String, size := 14) -> PanelContainer:
	if not text in GLYPHS:
		return super(text, size)
	var k := PanelContainer.new()
	k.add_theme_stylebox_override("panel", T.box(PAPER, 7, 5, INK, 2, 3, Color("#9C8E70")))
	k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Glyph.new()
	g.kind = text
	g.custom_minimum_size = Vector2(size + 6, size + 6)
	k.add_child(g)
	return k
