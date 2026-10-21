extends Control
## Màn hình chính (artboard 1): logo, Bắt đầu ca, Tủ đồ của Bơ, Cài đặt, Thoát,
## và Bơ đứng trong tủ kính xe bánh mì Cô Ba.

const T = preload("res://scripts/ui/ui_theme.gd")
const KITCHEN_SCENE := "res://scenes/kitchen.tscn"
const DELIVERY_SCENE := "res://scenes/main.tscn"
const RECORD_PATH := "user://ky_luc.cfg"

var settings: SettingsPanel
var wardrobe: WardrobePanel
var level_select: LevelSelectPanel
var start_btn: Button
var showcase_cat: BoPreview


## Cảnh đầu tiên của một ca: bếp nếu đã có, không thì vào thẳng màn giao.
static func first_scene() -> String:
	return KITCHEN_SCENE if ResourceLoader.exists(KITCHEN_SCENE) else DELIVERY_SCENE


func _ready() -> void:
	GameSettings.apply_graphics(get_tree())
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args or "--autotest-bep" in args or "--demo-bep" in args \
			or "--autotest-rap-nhanh" in args or "--demo-rap-nhanh" in args:
		get_tree().change_scene_to_file.call_deferred(first_scene())
		return
	theme = T.make_theme()
	T.full_rect(self)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var sound := get_node_or_null("/root/Sound")
	if sound and sound.has_method("music"):
		sound.music("menu")

	var bg := MenuBackdrop.new()
	add_child(T.full_rect(bg))

	# Logo: đặt từng phần theo toạ độ của bản phác thảo
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.position = Vector2(72, 50)
	var ears := EarsDraw.new()
	ears.custom_minimum_size = Vector2(56, 40)
	ears.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(ears)
	top.add_child(T.label("Mèo Giao", 46, T.INK, "display"))
	add_child(top)
	var title := T.label("Bánh Mì", 112, T.FUR, "display")
	title.add_theme_color_override("font_outline_color", T.INK)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_shadow_color", T.INK)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_outline_size", 14)
	title.position = Vector2(70, 96)
	add_child(title)
	var loaf := LoafDraw.new()
	loaf.position = Vector2(76, 262)
	loaf.size = Vector2(300, 44)
	add_child(loaf)
	var tag := T.label("Ca sáng ở lò bánh Cô Ba · làm bánh rồi giao 5 đơn", 18, Color("#2C4F52"))
	tag.position = Vector2(72, 316)
	add_child(tag)

	# Menu
	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 16)
	T.place(nav, 0.0, 0.0, Rect2(72, 372, 380, 330))
	add_child(nav)
	start_btn = T.button("  Bắt đầu ca", "primary", 72, 26)
	start_btn.pressed.connect(_start)
	nav.add_child(start_btn)
	var wd := T.button("  Tủ đồ của Bơ", "secondary", 62, 21)
	wd.pressed.connect(func(): wardrobe.open())
	nav.add_child(wd)
	var st := T.button("  Cài đặt", "secondary", 62, 21)
	st.pressed.connect(func(): settings.open())
	nav.add_child(st)
	if not OS.has_feature("web"):
		var quit := T.button("  Thoát game", "secondary", 52, 18)
		var clear := T.box(Color(0, 0, 0, 0), 18, 22, Color(0, 0, 0, 0), 0)
		quit.add_theme_stylebox_override("normal", clear)
		quit.add_theme_stylebox_override("hover", T.box(Color(T.INK, 0.08), 18, 22, Color(0, 0, 0, 0), 0))
		quit.pressed.connect(func(): get_tree().quit())
		nav.add_child(quit)
	var enter_hint := T.label("Enter", 14, T.ON_CRUST, "bold")
	enter_hint.modulate.a = 0.7
	T.place(enter_hint, 1.0, 0.5, Rect2(-70, -10, 50, 20))
	start_btn.add_child(enter_hint)

	add_child(_showcase())

	var ver := T.label("Bản chơi thử · %s" % ("web" if OS.has_feature("web") else "Windows"), 14, T.MUTED, "bold")
	T.place(ver, 0.0, 1.0, Rect2(72, -40, 400, 24))
	add_child(ver)

	wardrobe = WardrobePanel.new()
	wardrobe.visible = false
	add_child(wardrobe)
	settings = SettingsPanel.new()
	settings.visible = false
	add_child(settings)
	level_select = LevelSelectPanel.new()
	level_select.visible = false
	add_child(level_select)
	for p in [wardrobe, settings, level_select]:
		p.closed.connect(func(): start_btn.grab_focus())
	# Bảng nào che trang chủ thì Bơ trong tủ kính thôi chạy và thôi vẽ; đóng tủ đồ thì mặc lại đồ vừa chọn
	for p in [wardrobe, settings, level_select]:
		p.visibility_changed.connect(func():
			var covered: bool = wardrobe.visible or settings.visible or level_select.visible
			showcase_cat.set_active(not covered)
			if not wardrobe.visible and showcase_cat.cat:
				showcase_cat.cat.set_breed(Outfit.breed()))

	T.wire_clicks(self)
	if PlayMode.back_to_select:
		# Vừa chơi xong quay về: mở lại màn Chọn màn
		PlayMode.back_to_select = false
		level_select.open()
	else:
		start_btn.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if settings.visible or wardrobe.visible or level_select.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_start()
		get_viewport().set_input_as_handled()


## Bắt đầu ca: mở màn Chọn màn (scripts/ui/level_select.gd) để chọn ngày và cách chơi.
func _start() -> void:
	level_select.open()


func _showcase() -> Control:
	# Tủ kính xe bánh mì: mái đỏ, kính nhìn thấy Bơ, thân xanh có kỷ lục sao, hai bánh xe.
	var root := Control.new()
	T.place(root, 1.0, 0.0, Rect2(-670, 70, 600, 560))
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var glass := Panel.new()
	var gs := T.box(Color("#8DBDB3"), 0, 0, T.INK, 4)
	gs.border_width_top = 0
	glass.add_theme_stylebox_override("panel", gs)
	glass.position = Vector2(28, 70)
	glass.size = Vector2(544, 364)
	glass.clip_contents = true
	root.add_child(glass)
	# Bơ 3D thật (cùng model trong màn chơi): vẫy đuôi, chớp mắt, thở, thỉnh thoảng ngồi hoặc liếm chân.
	# Kéo chuột để xoay. Tủ đồ mở thì tạm dừng để đỡ tốn máy.
	showcase_cat = BoPreview.new()
	showcase_cat.bg_color = Color("#8DBDB3")
	showcase_cat.show_hint = false
	showcase_cat.start_yaw = PI + 0.75
	showcase_cat.start_pitch = 0.16
	showcase_cat.start_dist = 1.95
	showcase_cat.target = Vector3(0, 0.27, 0.0)
	showcase_cat.position = Vector2(4, 0)
	showcase_cat.size = Vector2(536, 364)
	glass.add_child(showcase_cat)
	var shine := GlassShine.new()
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.position = Vector2.ZERO
	shine.size = glass.size
	glass.add_child(shine)

	var roof := PanelContainer.new()
	roof.add_theme_stylebox_override("panel", T.box(T.RED, 14, 10, T.INK, 4))
	roof.position = Vector2(0, 0)
	roof.size = Vector2(600, 74)
	var rl := T.label("BÁNH MÌ CÔ BA", 34, T.PAPER, "display")
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	roof.add_child(rl)
	root.add_child(roof)

	var body := PanelContainer.new()
	body.add_theme_stylebox_override("panel", T.box(T.TEAL, 10, 26, T.INK, 4))
	body.position = Vector2(10, 430)
	body.size = Vector2(580, 92)
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	var stars := _record_stars()
	var rec := T.label("Kỷ lục ca: %d/15 sao" % stars if stars >= 0 else "Chưa có kỷ lục · chơi ca đầu nào!", 22, T.CREAM, "display")
	rec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rec.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bh.add_child(rec)
	if stars >= 0:
		var sd := T.StarRow.new()
		sd.filled = clampi(int(round(stars / 5.0)), 0, 3)
		sd.custom_minimum_size = Vector2(90, 30)
		sd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bh.add_child(sd)
	body.add_child(bh)
	root.add_child(body)
	for x in [60, 500]:
		var wheel := Panel.new()
		wheel.add_theme_stylebox_override("panel", T.box(T.INK, 20, 0, T.INK, 0))
		wheel.position = Vector2(x, 516)
		wheel.size = Vector2(40, 40)
		root.add_child(wheel)
	return root


func _record_stars() -> int:
	var cf := ConfigFile.new()
	if cf.load(RECORD_PATH) == OK:
		return int(cf.get_value("ky_luc", "sao", -1))
	return -1


class MenuBackdrop:
	extends Control
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), UiTheme.SKY)
		var houses := [[0, 250, 150], [160, 190, 130], [300, 290, 170], [560, 230, 140], [w - 160, 210, 170]]
		for hs in houses:
			draw_rect(Rect2(hs[0], hs[1], hs[2], h * 0.806 - hs[1]), Color("#B4D4CC"))
		for p in [Vector2(20, 300), Vector2(80, 300), Vector2(190, 240), Vector2(240, 240), Vector2(190, 320), Vector2(240, 320)]:
			draw_rect(Rect2(p, Vector2(32, 44)), Color("#A3C9C0"))
		var wire := PackedVector2Array()
		for i in 33:
			var x := w * i / 32.0
			wire.append(Vector2(x, 176 + sin(i / 32.0 * PI) * 22))
		draw_polyline(wire, Color(UiTheme.INK, 0.35), 2.0, true)
		var ground := h * 0.806
		draw_rect(Rect2(0, ground, w, h - ground), Color("#E7DCC4"))
		draw_rect(Rect2(0, ground, w, 6), Color("#C9BC9E"))
		var x2 := 80.0
		while x2 < w:
			draw_line(Vector2(x2, ground + 6), Vector2(x2, h), Color("#D6C9AB"), 2)
			x2 += 160.0
		draw_line(Vector2(0, ground + 70), Vector2(w, ground + 70), Color("#D6C9AB"), 2)


class EarsDraw:
	extends Control
	func _draw() -> void:
		var ear := PackedVector2Array([Vector2(6, 38), Vector2(10, 4), Vector2(24, 18), Vector2(32, 18), Vector2(46, 4), Vector2(50, 38)])
		draw_colored_polygon(ear, UiTheme.FUR)
		ear.append(ear[0])
		draw_polyline(ear, UiTheme.INK, 3.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(14, 14), Vector2(13, 26), Vector2(20, 20)]), Color("#E59A8C"))
		draw_colored_polygon(PackedVector2Array([Vector2(42, 14), Vector2(43, 26), Vector2(36, 20)]), Color("#E59A8C"))


class LoafDraw:
	extends Control
	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in 41:
			var a := PI + PI * i / 40.0
			pts.append(Vector2(150 + cos(a) * 144, 26 + sin(a) * 20))
		for i in 41:
			var a := PI * i / 40.0
			pts.append(Vector2(150 + cos(a) * 140, 30 + sin(a) * 10))
		draw_colored_polygon(pts, UiTheme.CRUST)
		pts.append(pts[0])
		draw_polyline(pts, UiTheme.INK, 3.0, true)
		for x in [80, 140, 200]:
			draw_line(Vector2(x, 14), Vector2(x + 18, 30), UiTheme.CRUST_DARK, 5.0, true)


class GlassShine:
	extends Control
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var h := size.y
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(110, 0), Vector2(110 - h * 0.6, h), Vector2(0, h)]), Color(1, 1, 1, 0.16))
		draw_colored_polygon(PackedVector2Array([Vector2(150, 0), Vector2(180, 0), Vector2(180 - h * 0.6, h), Vector2(150 - h * 0.6, h)]), Color(1, 1, 1, 0.1))
