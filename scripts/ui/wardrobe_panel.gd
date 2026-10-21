class_name WardrobePanel
extends Control
## Lối vào Tủ đồ của Bơ (artboard 3). Skin và phụ kiện chưa vào game nên hiện giờ
## chỉ Bơ dùng được, các giống khác hiện khoá kèm điều kiện mở dự kiến.
## Khi luồng skin đưa model vào, thay BREEDS bằng dữ liệu thật và nối nút "Chọn".

signal closed

const T = preload("res://scripts/ui/ui_theme.gd")
# tên, độ hiếm, màu lông, màu bụng, màu mắt, điều kiện mở ("" = có sẵn)
const BREEDS := [
	["Bơ", "Thường", "#E8913A", "#FBE6C8", "#F7D35E", ""],
	["Mướp", "Thường", "#9A8A6E", "#E9DFCB", "#C9D46A", "Sắp có"],
	["Mun", "Thường", "#2A2524", "#2A2524", "#F2C14B", "Sắp có"],
	["Tuyết", "Thường", "#F4EFE6", "#FFFFFF", "#7FB6E8", "Sắp có"],
	["Khoai Môn", "Thường", "#8F96A8", "#B5BACB", "#E9A23B", "Sắp có"],
	["Cà Phê Sữa", "Thường", "#7A5236", "#B08562", "#E2B04A", "Sắp có"],
	["Tam Thể", "Hiếm", "#E8913A", "#FFFFFF", "#E2B04A", "Sắp có"],
	["Bò Sữa", "Hiếm", "#2A2524", "#FFFFFF", "#9CC96B", "Sắp có"],
	["Xiêm", "Hiếm", "#EADCC2", "#F6EEDC", "#5AA8E0", "Sắp có"],
	["Vỏ Bánh Giòn", "Đặc biệt", "#C9822E", "#F0C98A", "#F7D35E", "Giao kịp cả 5 đơn"],
	["Thần Tài", "Đặc biệt", "#E2B04A", "#FBE6C8", "#C8412F", "Đủ 45 sao"],
	["Lân Tết", "Sự kiện", "#D9A02B", "#C8412F", "#F7D35E", "Mở dịp Tết"],
]
const TAGS := {
	"Thường": ["#E7DCC4", "#1F3A3D"],
	"Hiếm": ["#2E7C80", "#FFF8EA"],
	"Đặc biệt": ["#D98E2B", "#2A1A05"],
	"Sự kiện": ["#C8412F", "#FFF8EA"],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = T.make_theme()
	T.full_rect(self)
	var bg := ColorRect.new()
	bg.color = Color("#F3EFE4")
	add_child(T.full_rect(bg))

	var left := Panel.new()
	left.add_theme_stylebox_override("panel", T.box(Color("#9CCBC1"), 0, 0, Color(0, 0, 0, 0), 0))
	left.anchor_bottom = 1.0
	left.offset_right = 500
	left.clip_contents = true
	add_child(left)
	var pic := TextureRect.new()
	pic.texture = load("res://assets/ui/bo_menu.jpg")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.offset_bottom = -210
	left.add_child(pic)
	var edge := ColorRect.new()
	edge.color = T.INK
	edge.anchor_bottom = 1.0
	edge.offset_left = 500
	edge.offset_right = 504
	add_child(edge)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.position = Vector2(28, 28)
	add_child(head)
	var back := T.icon_button("back", "Quay lại (Esc)")
	back.pressed.connect(close)
	head.add_child(back)
	head.add_child(T.label("Tủ đồ của Bơ", 40, T.INK, "display"))

	var name_card := PanelContainer.new()
	name_card.add_theme_stylebox_override("panel", T.box(T.PAPER, 14, 16, T.INK, 3))
	T.place(name_card, 0.0, 1.0, Rect2(28, -200, 300, 66))
	var nc := VBoxContainer.new()
	nc.add_theme_constant_override("separation", 0)
	nc.add_child(T.label("Bơ · mèo ta cam", 24, T.INK, "display"))
	nc.add_child(T.label("Đực · đang mặc", 14, T.MUTED, "bold"))
	name_card.add_child(nc)
	add_child(name_card)

	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	T.place(slots, 0.0, 1.0, Rect2(28, -112, 444, 84))
	add_child(slots)
	for s in ["Đầu", "Mặt", "Cổ", "Lưng", "Đuôi", "Chân"]:
		var b := Button.new()
		b.text = "+\n" + s
		b.custom_minimum_size = Vector2(66, 84)
		b.disabled = true
		b.tooltip_text = "Phụ kiện sắp có"
		var st := T.box(Color("#FBF3E2"), 18, 4, Color("#8A7B5C"), 3)
		b.add_theme_stylebox_override("disabled", st)
		b.add_theme_font_override("font", T.font("bold"))
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_disabled_color", T.MUTED)
		slots.add_child(b)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 18)
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = 540
	right.offset_top = 28
	right.offset_right = -40
	right.offset_bottom = -28
	add_child(right)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	right.add_child(tabs)
	var tab_on := true
	for t in ["Giống mèo · 19", "Phụ kiện · 35", "Bộ đồ · 8"]:
		var b := T.button(t, "secondary", 52, 17)
		if tab_on:
			b.add_theme_stylebox_override("normal", T.box(T.INK, 16, 20, T.INK, 3))
			b.add_theme_color_override("font_color", T.PAPER)
			b.add_theme_color_override("font_focus_color", T.PAPER)
		else:
			b.disabled = true
			b.tooltip_text = "Sắp có"
		tab_on = false
		tabs.add_child(b)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	right.add_child(grid)
	for b in BREEDS:
		grid.add_child(_tile(b))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	right.add_child(foot)
	var note := T.label("Skin và phụ kiện đang được dựng trong Blender, sẽ mở dần", 15, T.MUTED, "bold")
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(note)
	var pick := T.button("Chọn Bơ", "primary", 60, 20)
	pick.pressed.connect(close)
	foot.add_child(pick)

	T.wire_clicks(self)
	visibility_changed.connect(func():
		if visible:
			pick.grab_focus.call_deferred())


func _tile(b: Array) -> Control:
	var locked: bool = b[5] != ""
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(100, 140)
	tile.add_theme_stylebox_override("panel", T.box(Color("#FFF1D6") if not locked else T.PAPER, 18, 6, T.CRUST if not locked else T.INK, 4 if not locked else 3))
	tile.tooltip_text = "%s · %s%s" % [b[0], b[1], (" · " + b[5]) if locked else " · đang mặc"]
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	tile.add_child(v)
	var face := CatFace.new()
	face.fur = Color(b[2])
	face.belly = Color(b[3])
	face.eye = Color(b[4])
	face.custom_minimum_size = Vector2(64, 56)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(face)
	var n := T.label(b[0], 14, T.INK, "bold")
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var tag := PanelContainer.new()
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tag.add_theme_stylebox_override("panel", T.box(Color(TAGS[b[1]][0]), 999, 8, Color(0, 0, 0, 0), 0))
	tag.add_child(T.label(b[1], 11, Color(TAGS[b[1]][1]), "bold"))
	v.add_child(tag)
	if locked:
		var cover := PanelContainer.new()
		cover.add_theme_stylebox_override("panel", T.box(Color(T.INK, 0.86), 15, 6, Color(0, 0, 0, 0), 0))
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := T.label("Khoá\n" + b[5], 12, T.PAPER, "bold")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		cover.add_child(l)
		tile.add_child(cover)
	return tile


func open() -> void:
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


class CatFace:
	extends Control
	var fur := Color.ORANGE
	var belly := Color.WHITE
	var eye := Color.YELLOW
	func _draw() -> void:
		var head := PackedVector2Array([Vector2(8, 54), Vector2(6, 30), Vector2(12, 4), Vector2(24, 16), Vector2(40, 16), Vector2(52, 4), Vector2(58, 30), Vector2(56, 54)])
		draw_colored_polygon(head, fur)
		draw_colored_polygon(PackedVector2Array([Vector2(22, 54), Vector2(32, 42), Vector2(42, 54)]), belly)
		head.append(head[0])
		draw_polyline(head, UiTheme.INK, 3.0, true)
		for x in [23, 41]:
			draw_circle(Vector2(x, 32), 4.5, eye)
			draw_arc(Vector2(x, 32), 4.5, 0, TAU, 16, UiTheme.INK, 1.5, true)
