class_name WardrobePanel
extends Control
## Tủ đồ của Bơ (artboard 3). Bên trái: Bơ 3D trên bục, kéo chuột hoặc vuốt để xoay 360°,
## lăn chuột để phóng to; sáu ô gắn phụ kiện. Bên phải: ba tab Giống mèo, Phụ kiện, Bộ đồ.
## Danh mục và đồ đang mặc nằm ở Outfit. Món chưa có hình trong game hiện khoá "Sắp có";
## khi luồng skin đưa model vào, thêm id vào Outfit.IN_GAME và vẽ món đó trong player.apply_outfit().

signal closed

const T = preload("res://scripts/ui/ui_theme.gd")
const PlayerScript = preload("res://scripts/player.gd")
const TAGS := {
	"mac": ["#F7D35E", "#2A1A05"],
	"thuong": ["#E7DCC4", "#1F3A3D"],
	"hiem": ["#2E7C80", "#FFF8EA"],
	"dacbiet": ["#D98E2B", "#2A1A05"],
	"sukien": ["#C8412F", "#FFF8EA"],
}
const TAB_NAMES := ["Giống mèo · 19", "Phụ kiện · 35", "Bộ đồ · 8"]
const NOTES := [
	"19 giống, hiện mới có Bơ trong game. Các giống khác đang dựng trong Blender.",
	"Bấm một món để đeo hoặc tháo. Món khoá đang được dựng trong Blender.",
	"Mặc cả bộ khi mọi món trong bộ đã có trong game.",
]

var tab := 0
var slot_filter := ""
var preview: BoPreview
var _tabs: Array[Button] = []
var _filters: HBoxContainer
var _scroll: ScrollContainer
var _list: Container
var _slots: HBoxContainer
var _worn_label: Label
var _note: Label
var _done: Button


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
	preview = BoPreview.new()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.offset_bottom = -210
	left.add_child(preview)
	var edge := ColorRect.new()
	edge.color = T.INK
	edge.anchor_bottom = 1.0
	edge.offset_left = 500
	edge.offset_right = 504
	add_child(edge)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.position = Vector2(28, 28)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)
	var back := T.icon_button("back", "Quay lại (Esc)")
	back.pressed.connect(close)
	head.add_child(back)
	var title := T.label("Tủ đồ của Bơ", 40, T.INK, "display")
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title)

	var name_card := PanelContainer.new()
	name_card.add_theme_stylebox_override("panel", T.box(T.PAPER, 14, 14, T.INK, 3))
	T.place(name_card, 0.0, 1.0, Rect2(28, -200, 444, 74))
	var nc := VBoxContainer.new()
	nc.add_theme_constant_override("separation", 0)
	nc.add_child(T.label("Bơ · mèo ta cam", 24, T.INK, "display"))
	_worn_label = T.label("", 14, T.MUTED, "bold")
	_worn_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nc.add_child(_worn_label)
	name_card.add_child(nc)
	add_child(name_card)

	_slots = HBoxContainer.new()
	_slots.add_theme_constant_override("separation", 8)
	T.place(_slots, 0.0, 1.0, Rect2(28, -112, 444, 84))
	add_child(_slots)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
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
	for i in TAB_NAMES.size():
		var b := T.button(TAB_NAMES[i], "secondary", 52, 17)
		b.pressed.connect(show_tab.bind(i))
		tabs.add_child(b)
		_tabs.append(b)

	_filters = HBoxContainer.new()
	_filters.add_theme_constant_override("separation", 6)
	right.add_child(_filters)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_scroll)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	right.add_child(foot)
	_note = T.label("", 15, T.MUTED, "bold")
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_note)
	_done = T.button("Xong", "primary", 60, 20)
	_done.custom_minimum_size.x = 150
	_done.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_done.pressed.connect(close)
	foot.add_child(_done)

	show_tab(0)
	T.wire_clicks(self)
	visibility_changed.connect(func():
		preview.set_active(visible)
		if visible:
			_done.grab_focus.call_deferred())
	preview.set_active(visible)


## Chuyển tab: 0 giống mèo, 1 phụ kiện, 2 bộ đồ.
func show_tab(i: int, filter := "") -> void:
	tab = i
	slot_filter = filter if i == 1 else ""
	for k in _tabs.size():
		var b := _tabs[k]
		var on := k == tab
		b.add_theme_stylebox_override("normal", T.box(T.INK if on else T.PAPER, 16, 20, T.INK, 3, 0 if on else 5))
		b.add_theme_stylebox_override("hover", T.box(T.INK if on else T.PAPER.lightened(0.1), 16, 20, T.INK, 3, 0 if on else 5))
		for c in ["font_color", "font_focus_color", "font_hover_color"]:
			b.add_theme_color_override(c, T.PAPER if on else T.INK)
	_note.text = NOTES[tab]
	_refresh()


func _refresh() -> void:
	_build_slots()
	var names := Outfit.worn_names()
	_worn_label.text = "Đực · " + ("đang đeo: " + ", ".join(names) if names.size() > 0 else "chưa đeo gì")
	if preview.cat:
		preview.cat.apply_outfit()

	for c in _filters.get_children():
		c.queue_free()
	_filters.visible = tab == 1
	if tab == 1:
		_filters.add_child(_chip("Tất cả · %d" % Outfit.ACCS.size(), ""))
		for s in Outfit.SLOTS:
			var n := 0
			for a in Outfit.ACCS:
				if a[3] == s[0]:
					n += 1
			_filters.add_child(_chip("%s · %d" % [s[1], n], s[0]))

	var keep_scroll := _scroll.scroll_vertical
	if _list:
		_list.queue_free()
	var grid := GridContainer.new()
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match tab:
		0:
			grid.columns = 6
			for b in Outfit.BREEDS:
				grid.add_child(_breed_tile(b))
		1:
			grid.columns = 6
			for a in Outfit.ACCS:
				if slot_filter == "" or a[3] == slot_filter:
					grid.add_child(_acc_tile(a))
		2:
			grid.columns = 2
			for s in Outfit.SETS:
				grid.add_child(_set_card(s))
	_list = grid
	_scroll.add_child(grid)
	_scroll.set_deferred("scroll_vertical", keep_scroll)
	T.wire_clicks(self)


# ---------------------------------------------------------------- ô gắn bên trái

func _build_slots() -> void:
	for c in _slots.get_children():
		c.queue_free()
	for s in Outfit.SLOTS:
		var id := Outfit.worn(s[0])
		var active: bool = tab == 1 and slot_filter == s[0]
		var b := Button.new()
		b.custom_minimum_size = Vector2(66, 84)
		b.focus_mode = Control.FOCUS_ALL
		b.tooltip_text = "Ô %s: %s" % [s[1], Outfit.acc(id)[1] if id != "" else "trống, bấm để chọn"]
		var fill := Color("#FFF1D6") if id != "" else Color("#FBF3E2")
		var border := T.TEAL if active else (T.CRUST if id != "" else Color("#8A7B5C"))
		b.add_theme_stylebox_override("normal", T.box(fill, 18, 4, border, 4 if active or id != "" else 3))
		b.add_theme_stylebox_override("hover", T.box(fill.lightened(0.3), 18, 4, border, 4))
		b.add_theme_stylebox_override("pressed", T.box(fill.darkened(0.06), 18, 4, border, 4))
		b.add_theme_stylebox_override("focus", T.box(Color(0, 0, 0, 0), 20, 4, T.TEAL, 4))
		b.pressed.connect(show_tab.bind(1, s[0]))
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(v)
		var ic := SlotIcon.new()
		ic.slot = s[0]
		ic.color = T.RED if id == "khando" else (T.TEAL if id != "" else Color("#B5A88A"))
		ic.plus = id == ""
		ic.custom_minimum_size = Vector2(40, 30)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(ic)
		var l := T.label(s[1], 13, T.INK if id != "" else T.MUTED, "bold")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
		_slots.add_child(b)


func _chip(text: String, slot: String) -> Button:
	var on := slot_filter == slot
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_override("font", T.font("bold"))
	b.add_theme_font_size_override("font_size", 14)
	var fill := T.TEAL if on else T.PAPER
	b.add_theme_stylebox_override("normal", T.box(fill, 999, 14, T.INK if not on else T.TEAL, 2))
	b.add_theme_stylebox_override("hover", T.box(fill.lightened(0.1), 999, 14, T.INK, 2))
	b.add_theme_stylebox_override("pressed", T.box(fill.darkened(0.1), 999, 14, T.INK, 2))
	b.add_theme_stylebox_override("focus", T.box(Color(0, 0, 0, 0), 999, 14, T.TEAL, 3))
	for c in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, T.PAPER if on else T.INK)
	b.pressed.connect(show_tab.bind(1, slot))
	return b


# ---------------------------------------------------------------- ô trong lưới

## Nút ô vuông: nền giấy viền mực, đang chọn thì viền vỏ bánh.
func _tile_button(size: Vector2, selected: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_ALL
	var fill := Color("#FFF1D6") if selected else T.PAPER
	var border := T.CRUST if selected else T.INK
	var w := 4 if selected else 3
	b.add_theme_stylebox_override("normal", T.box(fill, 18, 6, border, w))
	b.add_theme_stylebox_override("hover", T.box(fill.lightened(0.4), 18, 6, border, w))
	b.add_theme_stylebox_override("pressed", T.box(fill.darkened(0.05), 18, 6, border, w))
	var f := T.box(Color(0, 0, 0, 0), 20, 6, T.TEAL, 4)
	f.expand_margin_left = 3
	f.expand_margin_right = 3
	f.expand_margin_top = 3
	f.expand_margin_bottom = 3
	b.add_theme_stylebox_override("focus", f)
	return b


func _tile_body(b: Button) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.offset_top = 20
	b.add_child(v)
	return v


func _tag(rar: String) -> Control:
	var tag := PanelContainer.new()
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_stylebox_override("panel", T.box(Color(TAGS[rar][0]), 999, 8, Color(0, 0, 0, 0), 0))
	tag.add_child(T.label(Outfit.RARITY[rar], 11, Color(TAGS[rar][1]), "bold"))
	return tag


func _name_label(text: String) -> Label:
	var n := T.label(text, 13, T.INK, "bold")
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


## Món chưa có: làm mờ nội dung, nền xám cát, dải mực "Khoá · ..." ở trên cùng (tên vẫn đọc được).
func _lock_cover(b: Button, body: Control, text: String) -> void:
	body.modulate = Color(1, 1, 1, 0.5)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, T.box(Color("#E9E2D2") if k != "hover" else Color("#F1EBDD"), 18, 6, Color("#8A7B5C"), 3))
	var rib := PanelContainer.new()
	rib.add_theme_stylebox_override("panel", T.box(T.INK, 8, 4, Color(0, 0, 0, 0), 0))
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rib.anchor_right = 1.0
	rib.offset_left = 8
	rib.offset_right = -8
	rib.offset_top = 8
	var l := T.label("Khoá · " + text, 10, T.PAPER, "bold")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	rib.add_child(l)
	b.add_child(rib)


func _breed_tile(br: Array) -> Button:
	var ready: bool = br[0] in Outfit.BREEDS_IN_GAME
	var b := _tile_button(Vector2(104, 150), br[0] == "bo")
	b.tooltip_text = "%s · %s" % [br[1], br[2]]
	var v := _tile_body(b)
	var face := CatFace.new()
	face.fur = Color(br[4])
	face.belly = Color(br[5])
	face.eye = Color(br[6])
	face.custom_minimum_size = Vector2(64, 56)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(face)
	v.add_child(_name_label(br[1]))
	v.add_child(_tag(br[3]))
	if not ready:
		_lock_cover(b, v, "Sắp có" if br[3] in ["thuong", "hiem"] else br[7])
	b.pressed.connect(func():
		if ready:
			_note.text = "%s · %s · đang chọn." % [br[1], br[2]]
		else:
			_note.text = "%s · %s · đang dựng trong Blender. %s." % [br[1], br[2], br[7]])
	return b


func _acc_tile(a: Array) -> Button:
	var ready := Outfit.in_game(a[0])
	var on := Outfit.is_worn(a[0])
	var b := _tile_button(Vector2(104, 160), on)
	b.tooltip_text = "%s · ô %s" % [a[1], Outfit.slot_name(a[3])]
	var v := _tile_body(b)
	var ic := SlotIcon.new()
	ic.slot = a[3]
	ic.color = T.RED if a[0] == "khando" else T.TEAL
	ic.custom_minimum_size = Vector2(48, 38)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ic)
	v.add_child(_name_label(a[1]))
	v.add_child(_tag(a[2]))
	if on:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", T.box(T.AMBER, 8, 4, Color(0, 0, 0, 0), 0))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.anchor_right = 1.0
		p.offset_left = 8
		p.offset_right = -8
		p.offset_top = 8
		var badge := T.label("Đang đeo", 10, T.ON_CRUST, "bold")
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(badge)
		b.add_child(p)
	if not ready:
		_lock_cover(b, v, "Sắp có")
	b.pressed.connect(func():
		if ready:
			Outfit.toggle(a[0])
			_refresh()
			_note.text = "%s %s." % ["Đã đeo" if Outfit.is_worn(a[0]) else "Đã tháo", a[1].to_lower()]
		else:
			_note.text = "%s (ô %s) đang được dựng trong Blender, sắp có." % [a[1], Outfit.slot_name(a[3])])
	return b


func _set_card(s: Array) -> Control:
	var items: Array = s[2]
	var ready := 0
	var worn := 0
	for id in items:
		if Outfit.in_game(id):
			ready += 1
		if Outfit.is_worn(id):
			worn += 1
	var all_ready := ready == items.size()
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var on := all_ready and worn == items.size()
	card.add_theme_stylebox_override("panel", T.box(Color("#FFF1D6") if on else T.PAPER, 18, 14, T.CRUST if on else T.INK, 4 if on else 3))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_child(T.label(s[0], 20, T.INK, "display"))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(T.label("%d món" % items.size(), 13, T.MUTED, "bold"))
	v.add_child(top)
	var d := T.label(s[1], 13, T.MUTED, "body")
	d.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(d)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	for id in items:
		var a := Outfit.acc(id)
		var chip := PanelContainer.new()
		var have := Outfit.in_game(id)
		chip.add_theme_stylebox_override("panel", T.box(T.SAND if have else Color("#EDE6D6"), 999, 8, Color(0, 0, 0, 0), 0))
		chip.add_child(T.label(a[1], 11, T.INK if have else Color("#8A7B5C"), "bold"))
		chip.tooltip_text = a[1] + ("" if have else " · sắp có")
		flow.add_child(chip)
	v.add_child(flow)
	var b: Button
	if all_ready:
		b = T.button("Đang mặc cả bộ" if on else "Mặc cả bộ", "primary" if not on else "secondary", 44, 15)
		b.disabled = on
		b.pressed.connect(func():
			for id in items:
				Outfit.wear(id)
			_refresh()
			_note.text = "Đã mặc %s." % s[0].to_lower())
	else:
		b = T.button("Sắp có · %d/%d món" % [ready, items.size()], "secondary", 44, 15)
		b.disabled = true
		b.tooltip_text = "Các món trong bộ đang được dựng trong Blender"
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	return card


func open() -> void:
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Bơ 3D trên bục tròn trong thế giới riêng. Kéo để xoay 360° (thả tay thì quay chậm dần),
## kéo dọc để nhìn cao thấp, lăn chuột để phóng to, bấm đúp để về góc ban đầu.
class BoPreview:
	extends SubViewportContainer
	const START_YAW := PI + 0.65
	const START_PITCH := 0.22
	const START_DIST := 2.3
	const TARGET := Vector3(0, 0.27, -0.02)
	var vp: SubViewport
	var cat: Node3D
	var cam: Camera3D
	var yaw := START_YAW
	var pitch := START_PITCH
	var dist := START_DIST
	var spin := 0.0
	var dragging := false
	var _hint: Control

	func _ready() -> void:
		stretch = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_DRAG
		vp = SubViewport.new()
		vp.own_world_3d = true
		vp.msaa_3d = Viewport.MSAA_2X
		vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
		add_child(vp)

		var we := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color("#9CCBC1")
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color("#BFD3DA")
		# Cùng mức sáng với màn giao bánh (main.gd): bản web Compatibility sáng hơn nên giảm bớt
		var compat := RenderingServer.get_rendering_device() == null
		e.ambient_light_energy = 0.3 if compat else 0.45
		e.tonemap_mode = Environment.TONE_MAPPER_LINEAR if compat else Environment.TONE_MAPPER_FILMIC
		we.environment = e
		vp.add_child(we)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-52, 35, 0)
		sun.light_color = Color("#FFE8C4")
		sun.light_energy = 0.6 if compat else 0.95
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 6.0
		vp.add_child(sun)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(-20, -150, 0)
		fill.light_color = Color("#CFE6E0")
		fill.light_energy = 0.15 if compat else 0.25
		vp.add_child(fill)

		# Bục: mặt giấy gói bánh, viền mực bên dưới
		_disc(0.5, 0.035, -0.0175, Color("#E2CFA8"))
		_disc(0.52, 0.03, -0.04, UiTheme.INK)

		cat = PlayerScript.new()
		cat.preview = true
		vp.add_child(cat)
		cat.set_physics_process(false)
		cam = Camera3D.new()
		cam.fov = 30.0
		cam.cull_mask = 0xFFFFF & ~PlayerScript.LAYER_FP_PAWS
		vp.add_child(cam)

		_hint = PanelContainer.new()
		_hint.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.INK, 0.78), 999, 12, Color(0, 0, 0, 0), 0))
		_hint.add_child(UiTheme.label("Kéo chuột hoặc vuốt để xoay 360°", 14, UiTheme.PAPER, "bold"))
		_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiTheme.place(_hint, 0.5, 1.0, Rect2(-150, -50, 300, 36))
		add_child(_hint)

	func _disc(r: float, h: float, y: float, color: Color) -> void:
		var m := CylinderMesh.new()
		m.top_radius = r
		m.bottom_radius = r
		m.height = h
		m.radial_segments = 48
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.9
		m.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.position.y = y
		vp.add_child(mi)

	func set_active(on: bool) -> void:
		if cat:
			cat.set_process(on)
		set_process(on)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				dragging = event.pressed
				if event.double_click:
					spin = 0.0
					var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
					tw.tween_property(self, "yaw", START_YAW + roundf((yaw - START_YAW) / TAU) * TAU, 0.5)
					tw.tween_property(self, "pitch", START_PITCH, 0.5)
					tw.tween_property(self, "dist", START_DIST, 0.5)
			elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
				dist = maxf(dist - 0.15, 1.3)
			elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				dist = minf(dist + 0.15, 3.2)
			accept_event()
		elif event is InputEventMouseMotion and dragging:
			yaw += event.relative.x * 0.012
			pitch = clampf(pitch + event.relative.y * 0.005, -0.05, 0.75)
			spin = event.relative.x * 0.012 * 60.0
			if _hint.visible:
				var tw := create_tween()
				tw.tween_property(_hint, "modulate:a", 0.0, 0.4)
				tw.tween_callback(_hint.hide)
			accept_event()

	func _process(delta: float) -> void:
		if not dragging:
			yaw += spin * delta
			spin *= exp(-3.0 * delta)
		if cat and cat.visual:
			cat.visual.rotation.y = yaw
		var dir := Vector3(0, sin(pitch), cos(pitch))
		cam.position = TARGET + dir * dist
		cam.look_at(TARGET)


## Biểu tượng ô gắn vẽ bằng nét: mũ, kính, khăn, túi, nơ đuôi, tất.
class SlotIcon:
	extends Control
	var slot := "head"
	var color := Color.TEAL
	var plus := false

	func _draw() -> void:
		var s := minf(size.x / 40.0, size.y / 30.0)
		var o := (size - Vector2(40, 30) * s) / 2.0
		var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
		var w := 2.6 * s
		var ink := UiTheme.INK
		if plus:
			color = Color(color, 0.55)
		match slot:
			"head":
				var dome := PackedVector2Array()
				for i in 13:
					var a := PI + PI * i / 12.0
					dome.append(p.call(20 + cos(a) * 11, 21 + sin(a) * 12))
				draw_colored_polygon(dome, color)
				draw_polyline(dome, ink, w, true)
				draw_line(p.call(4, 22), p.call(36, 22), ink, w * 1.3, true)
			"face":
				for x in [12.0, 28.0]:
					draw_circle(p.call(x, 16), 6.5 * s, Color(color, 0.35))
					draw_arc(p.call(x, 16), 6.5 * s, 0, TAU, 20, ink, w, true)
				draw_line(p.call(18.5, 15), p.call(21.5, 15), ink, w, true)
			"neck":
				var band := PackedVector2Array([p.call(5, 8), p.call(20, 14), p.call(35, 8), p.call(35, 13), p.call(20, 19), p.call(5, 13)])
				draw_colored_polygon(band, color)
				var tail := PackedVector2Array([p.call(22, 15), p.call(29, 27), p.call(24, 28), p.call(18, 17)])
				draw_colored_polygon(tail, color.darkened(0.15))
				band.append(band[0])
				draw_polyline(band, ink, w * 0.8, true)
				tail.append(tail[0])
				draw_polyline(tail, ink, w * 0.8, true)
			"back":
				draw_arc(p.call(20, 12), 9 * s, PI, TAU, 12, ink, w, true)
				var bag := Rect2(p.call(9, 11), Vector2(22, 15) * s)
				draw_rect(bag, color)
				draw_rect(bag, ink, false, w)
				draw_line(p.call(9, 17), p.call(31, 17), ink, w * 0.7, true)
			"tail":
				var l := PackedVector2Array([p.call(20, 15), p.call(7, 7), p.call(7, 23)])
				var r := PackedVector2Array([p.call(20, 15), p.call(33, 7), p.call(33, 23)])
				for t in [l, r]:
					draw_colored_polygon(t, color)
					t.append(t[0])
					draw_polyline(t, ink, w * 0.8, true)
				draw_circle(p.call(20, 15), 3.2 * s, ink)
			"feet":
				var sock := PackedVector2Array([p.call(13, 3), p.call(23, 3), p.call(23, 18), p.call(33, 21), p.call(33, 27), p.call(13, 27)])
				draw_colored_polygon(sock, color)
				draw_line(p.call(13, 9), p.call(23, 9), Color.WHITE, w, true)
				sock.append(sock[0])
				draw_polyline(sock, ink, w * 0.8, true)
		if plus:
			var c: Vector2 = p.call(34, 6)
			draw_circle(c, 6 * s, UiTheme.PAPER)
			draw_arc(c, 6 * s, 0, TAU, 16, ink, 1.5 * s, true)
			draw_line(c + Vector2(-3, 0) * s, c + Vector2(3, 0) * s, ink, 1.8 * s)
			draw_line(c + Vector2(0, -3) * s, c + Vector2(0, 3) * s, ink, 1.8 * s)


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
