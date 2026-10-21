extends CanvasLayer
## Nút loa góc phải dưới và bảng chỉnh âm lượng. Chỉ hiện khi thấy chuột
## (màn bắt đầu, tạm dừng, kết thúc); lúc đang chạy thì phím M để tắt/bật tiếng.

const PAPER := Color("#FFF8EA")
const INK := Color("#1F2A2A")
const CRUST := Color("#D98E2B")
const ROWS := [["Master", "Tổng"], ["Music", "Nhạc"], ["SFX", "Hiệu ứng"], ["Ambience", "Tiếng phố"]]

var _button: Button
var _icon: Control
var _panel: PanelContainer
var _mute: CheckButton
var _sliders := {}
var _flash: Label
var _flash_time := 0.0


func _ready() -> void:
	layer = 20  # trên HUD
	process_mode = Node.PROCESS_MODE_ALWAYS

	_button = Button.new()
	_button.tooltip_text = "Âm thanh"
	_button.focus_mode = Control.FOCUS_NONE
	_button.add_theme_stylebox_override("normal", _box(Color(INK, 0.85), 999, 0))
	_button.add_theme_stylebox_override("hover", _box(INK.lightened(0.15), 999, 0))
	_button.add_theme_stylebox_override("pressed", _box(INK, 999, 0, CRUST))
	_place(_button, Rect2(-68, -68, 48, 48))
	_button.pressed.connect(_toggle_panel)
	add_child(_button)
	_icon = Control.new()
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.draw.connect(_draw_speaker)
	_button.add_child(_icon)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _box(PAPER, 12, 18))
	_place(_panel, Rect2(-344, -330, 324, 250))
	_panel.visible = false
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	box.add_child(_label("Âm thanh", 22, CRUST))
	for row in ROWS:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var l := _label(row[1], 17, INK)
		l.custom_minimum_size.x = 90
		line.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.custom_minimum_size = Vector2(180, 24)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.focus_mode = Control.FOCUS_NONE
		s.value = Sound.get_volume(row[0])
		var bus: String = row[0]
		s.value_changed.connect(func(v): Sound.set_volume(bus, v))
		s.drag_ended.connect(func(_c): Sound.play_ui("ui_click"))
		line.add_child(s)
		box.add_child(line)
		_sliders[bus] = s
	_mute = CheckButton.new()
	_mute.text = "Tắt tiếng (phím M)"
	_mute.focus_mode = Control.FOCUS_NONE
	_mute.add_theme_color_override("font_color", INK)
	_mute.add_theme_color_override("font_hover_color", INK)
	_mute.add_theme_color_override("font_pressed_color", INK)
	_mute.add_theme_color_override("font_hover_pressed_color", INK)
	_mute.button_pressed = Sound.muted
	_mute.toggled.connect(func(on): Sound.set_muted(on); _icon.queue_redraw())
	box.add_child(_mute)

	_flash = _label("", 18, PAPER)
	_flash.add_theme_color_override("font_outline_color", INK)
	_flash.add_theme_constant_override("outline_size", 6)
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_flash, Rect2(-344, -60, 320, 30))
	add_child(_flash)


func _process(delta: float) -> void:
	var show := Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	_button.visible = show
	if not show:
		_panel.visible = false
	if _flash_time > 0.0:
		_flash_time -= delta
		_flash.modulate.a = clampf(_flash_time / 0.4, 0.0, 1.0)


## Dòng chữ nhỏ góc phải dưới, ví dụ khi bấm M lúc đang chạy.
func flash(text: String) -> void:
	_flash.text = text
	_flash_time = 1.6
	_mute.set_pressed_no_signal(Sound.muted)
	_icon.queue_redraw()


func _toggle_panel() -> void:
	_panel.visible = not _panel.visible
	Sound.play_ui("ui_click")


func _draw_speaker() -> void:
	var c := _icon.size / 2
	var col := PAPER
	var body := PackedVector2Array([
		c + Vector2(-11, -4), c + Vector2(-5, -4), c + Vector2(2, -10),
		c + Vector2(2, 10), c + Vector2(-5, 4), c + Vector2(-11, 4)])
	_icon.draw_colored_polygon(body, col)
	if Sound.muted:
		_icon.draw_line(c + Vector2(6, -5), c + Vector2(14, 5), CRUST, 2.5, true)
		_icon.draw_line(c + Vector2(6, 5), c + Vector2(14, -5), CRUST, 2.5, true)
	else:
		_icon.draw_arc(c + Vector2(2, 0), 6, -0.9, 0.9, 12, col, 2.0, true)
		_icon.draw_arc(c + Vector2(2, 0), 11, -0.9, 0.9, 16, col, 2.0, true)


func _place(c: Control, r: Rect2) -> void:
	c.anchor_left = 1.0
	c.anchor_right = 1.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
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
