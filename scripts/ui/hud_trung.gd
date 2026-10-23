class_name HudTrung
extends RefCounted
## Chỉ báo số trứng còn nguyên trong túi (đơn mua trứng Thứ Ba). Tách từ hud.gd; hud.set_eggs gọi vào đây.

const T = preload("res://scripts/ui/ui_theme.gd")
const PAPER := Color("#FFF8EA")
const INK := Color("#1F3A3D")
const CRUST := Color("#D98E2B")
const RED := Color("#C8412F")


## Số trứng còn nguyên trong túi (Thứ Hai không có: gọi -1 để ẩn). Quả vỡ vẽ nứt và mờ đi.
static func set_eggs(hud: Node, left: int, total := 6) -> void:
	if hud.egg_pill == null:
		return
	hud.egg_pill.visible = hud._playing and left >= 0
	if left < 0:
		return
	if hud.egg_row.get_child_count() != total:
		for c in hud.egg_row.get_children():
			c.free()
		for i in total:
			var e := HudHinh.EggIcon.new()
			e.custom_minimum_size = Vector2(22, 28)
			e.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hud.egg_row.add_child(e)
	for i in total:
		var e: HudHinh.EggIcon = hud.egg_row.get_child(i)
		var broken := i >= left
		if e.broken != broken:
			e.broken = broken
			e.queue_redraw()
	hud.egg_label.text = "Trứng %d/%d" % [left, total]
	hud.egg_label.add_theme_color_override("font_color", PAPER if left > total / 2 else (T.AMBER if left > 0 else T.RED))


static func build(hud: Node) -> void:
	hud.egg_pill = PanelContainer.new()
	hud.egg_pill.add_theme_stylebox_override("panel", T.box(Color(INK, 0.82), 999, 14, Color(0, 0, 0, 0), 0))
	hud.egg_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	T.place(hud.egg_pill, 0.0, 1.0, Rect2(28, -172, 0, 44))
	hud.egg_pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.play_root.add_child(hud.egg_pill)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	hud.egg_pill.add_child(h)
	hud.egg_label = T.label("", 15, PAPER, "bold")
	hud.egg_label.custom_minimum_size.x = 92
	h.add_child(hud.egg_label)
	hud.egg_row = HBoxContainer.new()
	hud.egg_row.add_theme_constant_override("separation", 3)
	h.add_child(hud.egg_row)
	hud.egg_pill.visible = false
