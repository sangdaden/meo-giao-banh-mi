class_name TongKetTuan
extends CanvasLayer
## Màn kết tuần sau Hội mèo: bảng huy chương 5 trò, sổ hàng xóm, tổng sao 5 ngày giao bánh,
## danh hiệu "Mèo giao bánh của tuần", rồi chữ chạy cuối game và nút "Tuần mới".
## Bản tạm tới khi luồng "Giao diện menu và HUD" làm màn riêng theo bộ giao diện chung.

signal new_week
signal to_menu

const INK := Color("#3A2418")
const PAPER := Color("#FFF8EA")
const AMBER := Color("#E8913A")
const MEDAL_COLORS := [Color(), Color("#F2C14E"), Color("#C9CED6"), Color("#C98B4A"), Color("#7DB46C")]
const MEDAL_NAMES := ["", "Vàng", "Bạc", "Đồng", "Tham gia"]
const CREDITS := [
	"MÈO GIAO BÁNH MÌ",
	"",
	"Một tuần ở khu phố nhỏ",
	"",
	"Ý tưởng, thiết kế, duyệt từng con mèo",
	"Sang",
	"",
	"Model, rig, animation",
	"Blender (phong cách D \"Chững chạc\")",
	"",
	"Ráp game",
	"Godot 4",
	"",
	"Bơ · Cô Ba · Chó Mực",
	"Chú Tư · Bé Na · Chị Mây · Anh Hùng · Bà Sáu",
	"Cô Hai · Chú Năm · Ông Bảy · Ông Tám · Chị Thu",
	"Bà Mướp · Mít · Bột · Mun · Tuyết · Lạc · Gừng · Sữa",
	"",
	"Cảm ơn bạn đã giao bánh cùng Bơ!",
	"",
	"Hẹn gặp lại tuần sau.",
]
const CREDIT_SPEED := 46.0   ## điểm ảnh mỗi giây

var medals: Array = []       ## [{title, rank, note}]
var neighbour_pages := 0
var neighbour_total := 11
var week_stars := 0
var week_stars_max := 0
var extra_medal := ""        ## "Hàng xóm thân" khi sổ đã đủ trang
var autotest := false

var _summary: Control
var _credits: Control
var _roll: VBoxContainer
var _rolling := false
var _end_box: Control


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.08, 0.06, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_summary = _build_summary()
	add_child(_summary)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_summary() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := _panel()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(_text("Tổng kết tuần", 34, AMBER))
	v.add_child(_text("Danh hiệu: Mèo giao bánh của tuần", 22))
	v.add_child(_text("Huy chương Hội mèo", 20, AMBER))
	for m in medals:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(22, 22)
		var sb := StyleBoxFlat.new()
		sb.bg_color = MEDAL_COLORS[clampi(int(m.rank), 1, 4)]
		sb.set_corner_radius_all(11)
		sb.border_color = INK
		sb.set_border_width_all(2)
		dot.add_theme_stylebox_override("panel", sb)
		row.add_child(dot)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var line := _text("%s · %s (%s)" % [m.title, MEDAL_NAMES[clampi(int(m.rank), 1, 4)], m.note], 18)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(line)
		v.add_child(row)
	if extra_medal != "":
		v.add_child(_text("Huy chương đặc biệt: " + extra_medal, 18))
	v.add_child(_text("Sổ hàng xóm: %d/%d trang" % [neighbour_pages, neighbour_total], 18))
	v.add_child(_text("Sao giao bánh cả tuần: %d/%d" % [week_stars, week_stars_max], 18))
	var b := _button("Xem chữ chạy cuối game")
	b.pressed.connect(_start_credits)
	v.add_child(b)
	return center


func _start_credits() -> void:
	_summary.visible = false
	_credits = Control.new()
	_credits.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits.clip_contents = true
	add_child(_credits)
	_roll = VBoxContainer.new()
	_roll.add_theme_constant_override("separation", 14)
	_roll.custom_minimum_size = Vector2(get_viewport().get_visible_rect().size.x, 0)
	for line: String in CREDITS:
		var l := _text(line, 34 if line == CREDITS[0] else 22, AMBER if line == CREDITS[0] else PAPER)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_roll.add_child(l)
	_credits.add_child(_roll)
	_roll.position.y = get_viewport().get_visible_rect().size.y
	_rolling = true
	var skip := _text("Bấm phím cách để bỏ qua", 14, Color(1, 1, 1, 0.6))
	skip.autowrap_mode = TextServer.AUTOWRAP_OFF
	skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.position += Vector2(-240, -36)
	_credits.add_child(skip)


func _process(delta: float) -> void:
	if not _rolling:
		return
	_roll.position.y -= delta * CREDIT_SPEED * (12.0 if autotest else 1.0)
	if _roll.position.y + _roll.size.y < 0.0:
		_end_credits()


func _unhandled_input(event: InputEvent) -> void:
	if _rolling and (event.is_action_pressed("jump") or event.is_action_pressed("ui_accept")):
		_end_credits()


func _end_credits() -> void:
	_rolling = false
	_credits.queue_free()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := _panel()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(_text("Hết tuần rồi!", 30, AMBER))
	v.add_child(_text("Đã mở \"Tuần mới\": sáng Thứ Hai lại có bánh nóng chờ Bơ.", 18))
	var nw := _button("Tuần mới")
	nw.pressed.connect(func(): new_week.emit())
	v.add_child(nw)
	var home := _button("Về màn hình chính")
	home.pressed.connect(func(): to_menu.emit())
	v.add_child(home)
	_end_box = center


func is_finished() -> bool:
	return _end_box != null


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(560, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = INK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(24)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _text(t: String, size: int, color := INK) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 18)
	return b
