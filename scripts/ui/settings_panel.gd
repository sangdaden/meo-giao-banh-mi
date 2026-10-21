class_name SettingsPanel
extends Control
## Màn Cài đặt (artboard 2): âm thanh, điều khiển (có chọn góc nhìn thứ ba / thứ nhất), hình ảnh.
## Dùng chung cho màn hình chính và màn tạm dừng. Mọi thay đổi áp dụng và lưu ngay.

signal closed

const T = preload("res://scripts/ui/ui_theme.gd")

var _rows := {}  # key -> hàm làm mới giao diện theo giá trị đã lưu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = T.make_theme()
	T.full_rect(self)
	var dim := ColorRect.new()
	dim.color = Color(T.INK, 0.6)
	add_child(T.full_rect(dim))

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.box(T.PAPER, 28, 36, T.INK, 4, 8))
	T.place(panel, 0.5, 0.5, Rect2(-560, -330, 1120, 660))
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
	head.add_child(T.label("Cài đặt", 42, T.INK, "display"))
	var note := T.label("Esc để quay lại · tự lưu", 15, T.MUTED, "bold")
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(note)

	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 48)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(grid)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	for c in [left, right]:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_theme_constant_override("separation", 6)
		grid.add_child(c)

	# --- Âm thanh
	left.add_child(_heading("Âm thanh"))
	_volume_row(left, "Âm lượng chung", "Master")
	_volume_row(left, "Nhạc nền", "Music")
	_volume_row(left, "Hiệu ứng", "SFX")
	_volume_row(left, "Tiếng phố", "Ambience")
	var snd := get_node_or_null("/root/Sound")
	_switch_row(left, "Tắt tiếng (M)", "",
		func() -> bool: return snd.muted if snd and "muted" in snd else AudioServer.is_bus_mute(0),
		func(on: bool) -> void:
			if snd and snd.has_method("set_muted"):
				snd.set_muted(on)
			else:
				AudioServer.set_bus_mute(0, on))

	# --- Điều khiển
	var h2 := _heading("Điều khiển")
	h2.add_theme_constant_override("margin_top", 10)
	left.add_child(h2)
	_segment_row(left, "Góc nhìn (V)", "first_person", [["Thứ ba", false], ["Thứ nhất", true]], _apply_camera)
	_slider_row(left, "Độ nhạy chuột", "sensitivity", _apply_camera)
	_switch_row(left, "Đảo trục dọc", "invert_y")

	# --- Hình ảnh
	right.add_child(_heading("Hình ảnh"))
	_segment_row(right, "Chất lượng", "quality", [["Thấp", 0], ["Vừa", 1], ["Cao", 2]], _apply_graphics)
	_segment_row(right, "Khung hình", "fps_cap", [["30", 30], ["60", 60], ["Không giới hạn", 0]], _apply_graphics)
	_switch_row(right, "Bóng đổ", "shadows")
	if not OS.has_feature("web"):
		_switch_row(right, "Toàn màn hình", "fullscreen")
	_switch_row(right, "Hiện FPS (F3)", "show_fps")
	_segment_row(right, "Cỡ chữ HUD", "hud_scale", [["Nhỏ", 0], ["Vừa", 1], ["To", 2]])
	_switch_row(right, "Gợi ý phím", "hints")
	_switch_row(right, "Mẹo lần đầu chơi", "tips")
	_switch_row(right, "Chế độ thử thách (giờ gấp, phạt nặng)", "thu_thach")

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 14)
	right.add_child(foot)
	var reset_btn := T.button("Khôi phục mặc định", "secondary", 56, 17)
	reset_btn.pressed.connect(func():
		GameSettings.reset()
		_apply_all()
		_refresh())
	foot.add_child(reset_btn)
	var done := T.button("Xong", "primary", 56, 19)
	done.custom_minimum_size.x = 130
	done.alignment = HORIZONTAL_ALIGNMENT_CENTER
	done.pressed.connect(close)
	foot.add_child(done)

	T.wire_clicks(self)
	visibility_changed.connect(func():
		if visible:
			_refresh()
			done.grab_focus.call_deferred())
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig and rig.has_signal("view_changed"):
		rig.connect("view_changed", func(_fp): _refresh())


func open() -> void:
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for k in _rows:
		_rows[k].call()


func _apply_all() -> void:
	_apply_graphics()
	_apply_camera()


func _apply_graphics() -> void:
	GameSettings.apply_graphics(get_tree())


func _apply_camera() -> void:
	GameSettings.apply_camera(get_tree())


func _heading(text: String) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_child(T.label(text, 28, T.INK, "display"))
	return m


func _row(parent: Control, text: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.custom_minimum_size.y = 52
	r.add_theme_constant_override("separation", 14)
	var l := T.label(text, 17, T.INK, "bold")
	l.custom_minimum_size.x = 160
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(l)
	parent.add_child(r)
	return r


func _make_slider() -> HSlider:
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 1
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size.y = 40
	var track := T.box(T.SAND, 999, 0, T.INK, 2)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := T.box(T.CRUST, 999, 0, T.INK, 2)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob_texture()
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)
	return s


func _value_label() -> Label:
	var v := T.label("", 18, T.INK, "display")
	v.custom_minimum_size.x = 44
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return v


func _volume_row(parent: Control, text: String, bus: String) -> void:
	var r := _row(parent, text)
	var s := _make_slider()
	var v := _value_label()
	r.add_child(s)
	r.add_child(v)
	var sound := get_node_or_null("/root/Sound")
	var get_vol := func() -> float:
		if sound and sound.has_method("get_volume"):
			return sound.get_volume(bus)
		var idx := AudioServer.get_bus_index(bus)
		return db_to_linear(AudioServer.get_bus_volume_db(idx)) if idx >= 0 else 1.0
	s.value_changed.connect(func(x: float) -> void:
		v.text = str(int(x))
		if sound and sound.has_method("set_volume"):
			sound.set_volume(bus, x / 100.0)
		else:
			var idx := AudioServer.get_bus_index(bus)
			if idx >= 0:
				AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(x / 100.0, 0.0001))))
	_rows["vol_" + bus] = func() -> void:
		s.set_value_no_signal(roundf(get_vol.call() * 100.0))
		v.text = str(int(s.value))


func _slider_row(parent: Control, text: String, key: String, after := Callable()) -> void:
	var r := _row(parent, text)
	var s := _make_slider()
	var v := _value_label()
	r.add_child(s)
	r.add_child(v)
	s.value_changed.connect(func(x: float) -> void:
		v.text = str(int(x))
		GameSettings.set_value(key, int(x))
		if after.is_valid():
			after.call())
	_rows[key] = func() -> void:
		s.set_value_no_signal(GameSettings.get_value(key))
		v.text = str(int(s.value))


## options: mảng [nhãn, giá trị]
func _segment_row(parent: Control, text: String, key: String, options: Array, after := Callable()) -> void:
	var r := _row(parent, text)
	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 0)
	r.add_child(seg)
	var group := ButtonGroup.new()
	var buttons := []
	for i in options.size():
		var b := Button.new()
		b.text = options[i][0]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 48)
		b.add_theme_font_override("font", T.font("bold"))
		b.add_theme_font_size_override("font_size", 16)
		var first := i == 0
		var last := i == options.size() - 1
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var on: bool = state in ["pressed", "hover_pressed"]
			var st := T.box(T.CRUST if on else (T.PAPER.darkened(0.04) if state == "hover" else T.PAPER), 14, 16, T.INK, 3)
			if state == "focus":
				st = T.box(Color(0, 0, 0, 0), 14, 16, T.TEAL, 3)
			st.corner_radius_top_left = 14 if first else 0
			st.corner_radius_bottom_left = 14 if first else 0
			st.corner_radius_top_right = 14 if last else 0
			st.corner_radius_bottom_right = 14 if last else 0
			if not last:
				st.border_width_right = 0
			b.add_theme_stylebox_override(state, st)
		for c in ["font_color", "font_hover_color", "font_focus_color"]:
			b.add_theme_color_override(c, T.INK)
		b.add_theme_color_override("font_pressed_color", T.ON_CRUST)
		b.add_theme_color_override("font_hover_pressed_color", T.ON_CRUST)
		var value = options[i][1]
		b.pressed.connect(func() -> void:
			GameSettings.set_value(key, value)
			if after.is_valid():
				after.call())
		seg.add_child(b)
		buttons.append([b, value])
	_rows[key] = func() -> void:
		var cur = GameSettings.get_value(key)
		for pair in buttons:
			pair[0].set_pressed_no_signal(pair[1] == cur)


## Công tắc bật/tắt. Có key thì lưu vào GameSettings; không thì dùng getter/setter riêng.
func _switch_row(parent: Control, text: String, key: String, getter := Callable(), setter := Callable()) -> void:
	var r := _row(parent, text)
	var sw := SwitchButton.new()
	r.add_child(sw)
	sw.toggled.connect(func(on: bool) -> void:
		sw.queue_redraw()
		if setter.is_valid():
			setter.call(on)
		else:
			GameSettings.set_value(key, on)
			_apply_graphics()
			_apply_camera())
	_rows["sw_" + text] = func() -> void:
		sw.set_pressed_no_signal(getter.call() if getter.is_valid() else bool(GameSettings.get_value(key)))
		sw.queue_redraw()


func _knob_texture() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(16, 16))
			if d <= 15.5:
				img.set_pixel(x, y, T.INK if d > 12.5 else T.PAPER)
	return ImageTexture.create_from_image(img)


## Công tắc tròn kiểu bản phác thảo: nền cát khi tắt, lá ngò khi bật.
class SwitchButton:
	extends BaseButton

	func _init() -> void:
		toggle_mode = true
		custom_minimum_size = Vector2(72, 40)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		focus_mode = Control.FOCUS_ALL

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, Vector2(72, 40))
		var bg := UiTheme.LEAF if button_pressed else UiTheme.SAND
		draw_style_box(UiTheme.box(bg, 20, 0, UiTheme.TEAL if has_focus() else UiTheme.INK, 3), r)
		var cx := 52.0 if button_pressed else 20.0
		draw_circle(Vector2(cx, 20), 12, UiTheme.INK)
		draw_circle(Vector2(cx, 20), 10, UiTheme.PAPER)
