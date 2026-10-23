class_name UiTheme
extends RefCounted
## Bộ màu, font và các khối giao diện chung theo bản phác thảo Sang đã duyệt:
## giấy gói bánh mì, viền mực cửa sắt, nút đứng trên gờ mực và tụt xuống khi nhấn.
## Mockup: https://claude.ai/artifact/EyQjPFrq3V3FimwRgTPgWb

const PAPER := Color("#FFF8EA")   # giấy gói: nền thẻ, nút phụ
const INK := Color("#1F3A3D")     # mực cửa sắt: viền, chữ
const CRUST := Color("#D98E2B")   # vỏ bánh: nút chính
const CRUST_DARK := Color("#A9621A")
const FUR := Color("#E8913A")     # lông Bơ: chữ logo
const TEAL := Color("#2E7C80")    # xanh túi bánh: phụ, viền khi chọn
const RED := Color("#C8412F")     # khăn đỏ: gấp, trễ, mũi tên
const LEAF := Color("#3F8A5C")    # lá ngò: kịp giờ, bật
const AMBER := Color("#F7D35E")   # mắt hổ phách: sao
const SAND := Color("#E7DCC4")    # vỉa hè: rãnh thanh trượt, ô trống
const CREAM := Color("#FBE6C8")
const MUTED := Color("#5A4A2E")   # chữ phụ trên nền giấy
const ON_CRUST := Color("#2A1A05")
const SKY := Color("#CFE6E0")

static var _fonts := {}


static func font(kind := "body") -> Font:
	if not _fonts.has(kind):
		var path: String = {
			"display": "res://assets/fonts/Baloo2-ExtraBold.ttf",
			"bold": "res://assets/fonts/BeVietnamPro-Bold.ttf",
			"body": "res://assets/fonts/BeVietnamPro-Medium.ttf",
		}[kind]
		var f: Font = load(path)
		_add_symbols(f)
		_fonts[kind] = f
	return _fonts[kind]


## Baloo 2 và Be Vietnam Pro thiếu ★ ✓ ✗ ▲ ▼ ◀ ← → ○ •: thiếu là hiện ô số (2605, 2713).
## Gắn một font ký hiệu nhỏ (cắt từ DejaVu Sans Bold) làm font dự phòng, gồm cả font mặc định
## của Godot mà Label3D dùng. Gọi một lần lúc khởi động (Sound gọi trong _ready).
const SYMBOL_FONT := "res://assets/fonts/KyHieu-DejaVuSansBold.ttf"


static func install_symbol_fallback() -> void:
	_add_symbols(ThemeDB.fallback_font)
	for k in ["display", "bold", "body"]:
		font(k)


static func _add_symbols(f: Font) -> void:
	if f == null:
		return
	var sym: Font = load(SYMBOL_FONT)
	if sym in f.fallbacks:
		return
	var fb := f.fallbacks.duplicate()
	fb.append(sym)
	f.fallbacks = fb


## Theme gốc gán cho Control ngoài cùng: mọi chữ con dùng Be Vietnam Pro.
static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = 18
	t.set_color("font_color", "Label", INK)
	return t


## Hộp bo góc. ledge > 0 là gờ mực đậm phía dưới (kiểu nút đứng trên bệ).
static func box(color: Color, radius := 18, pad := 14, border := INK, border_w := 3, ledge := 0, ledge_color := INK) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	if border.a > 0 and border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	if ledge > 0:
		s.shadow_color = ledge_color
		s.shadow_size = 0
		s.shadow_offset = Vector2(0, ledge)
	s.anti_aliasing = true
	return s


static func label(text: String, size := 18, color := INK, kind := "body") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Chữ trắng viền mực, dùng cho thông báo nổi trên cảnh 3D.
static func outlined(text: String, size := 26, color := PAPER, outline := 10) -> Label:
	var l := label(text, size, color, "display")
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", outline)
	return l


## Nút theo kiểu bản phác thảo. style: "primary" (vỏ bánh), "secondary" (giấy), "ghost" (viền sáng trên nền tối).
static func button(text: String, style := "secondary", height := 60, font_size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT if style != "icon" else HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_override("font", font("bold"))
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_constant_override("h_separation", 12)
	var bg := CRUST if style == "primary" else PAPER
	var fg := ON_CRUST if style == "primary" else INK
	if style == "ghost":
		var g := box(Color(0, 0, 0, 0), 18, 22, PAPER, 3)
		var gh := box(Color(1, 1, 1, 0.12), 18, 22, PAPER, 3)
		for k in ["normal", "disabled"]:
			b.add_theme_stylebox_override(k, g)
		b.add_theme_stylebox_override("hover", gh)
		b.add_theme_stylebox_override("pressed", gh)
		b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), 20, 22, AMBER, 3))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, PAPER)
		return b
	b.add_theme_stylebox_override("normal", box(bg, 18, 22, INK, 3, 5))
	b.add_theme_stylebox_override("hover", box(bg.lightened(0.12), 18, 22, INK, 3, 5))
	var pressed := box(bg.darkened(0.12), 18, 22, INK, 3, 1)
	pressed.content_margin_top += 4  # tụt xuống gờ
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", box(SAND, 18, 22, Color("#A89C80"), 3))
	# Chọn bằng bàn phím/tay cầm: viền xanh túi bao ngoài
	var f := box(Color(0, 0, 0, 0), 22, 22, TEAL, 4)
	f.expand_margin_left = 5
	f.expand_margin_right = 5
	f.expand_margin_top = 5
	f.expand_margin_bottom = 9
	b.add_theme_stylebox_override("focus", f)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fg)
	b.add_theme_color_override("font_disabled_color", Color("#7A6D55"))
	return b


## Nút vuông chỉ có biểu tượng vẽ bằng code (pause, quay lại...).
static func icon_button(icon: String, tooltip: String, size := 56) -> Button:
	var b := button("", "secondary", size)
	b.custom_minimum_size = Vector2(size, size)
	b.tooltip_text = tooltip
	var ic := IconDraw.new()
	ic.icon = icon
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	return b


## Neo control vào một điểm màn hình (ax, ay từ 0 đến 1) rồi đặt khung lệch từ điểm đó.
static func place(c: Control, ax: float, ay: float, r: Rect2) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.end.x
	c.offset_bottom = r.end.y


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


## Dải sọc đỏ trên đầu thẻ đơn, như giấy gói bánh mì. radius bo hai góc trên cho khớp thẻ
## (thẻ chứa nó nên có lề trong 3 px để viền mực vẫn hiện).
static func stripe(height := 10, radius := 15) -> Control:
	var clip := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.corner_radius_top_left = radius
	st.corner_radius_top_right = radius
	st.anti_aliasing = true
	clip.add_theme_stylebox_override("panel", st)
	clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	clip.custom_minimum_size = Vector2(0, height)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StripeDraw.new()
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(s)
	return clip


static func play_click() -> void:
	var sound: Node = Engine.get_main_loop().root.get_node_or_null("Sound") if Engine.get_main_loop() else null
	if sound and sound.has_method("play"):
		sound.play("ui_click")


## Gắn tiếng bấm cho mọi nút trong cây (dùng autoload Sound của luồng âm thanh nếu có).
static func wire_clicks(root: Node) -> void:
	for n in root.find_children("*", "BaseButton", true, false):
		if not n.pressed.is_connected(play_click):
			n.pressed.connect(play_click)


class StripeDraw:
	extends Control
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), PAPER)
		var x := 0.0
		while x < size.x:
			draw_rect(Rect2(x, 0, 14, size.y), RED)
			x += 22.0


## Biểu tượng nét đơn giản vẽ bằng code, khỏi cần file ảnh.
class IconDraw:
	extends Control
	var icon := "pause"
	var color := INK

	func _draw() -> void:
		var c := size / 2.0
		match icon:
			"pause":
				draw_rect(Rect2(c + Vector2(-8, -9), Vector2(5, 18)), color)
				draw_rect(Rect2(c + Vector2(3, -9), Vector2(5, 18)), color)
			"back":
				draw_polyline(PackedVector2Array([c + Vector2(5, -10), c + Vector2(-5, 0), c + Vector2(5, 10)]), color, 4.0, true)
			"play":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -10), c + Vector2(10, 0), c + Vector2(-7, 10)]), color)


## Hàng sao. filled = số sao vàng.
class StarRow:
	extends Control
	var filled := 0
	var count := 3
	var empty_color := TEAL
	func _draw() -> void:
		var s := size.y
		for i in count:
			var c := Vector2(s * 0.5 + i * (s + 4), s * 0.5)
			var pts := PackedVector2Array()
			for k in 10:
				var r := s * (0.5 if k % 2 == 0 else 0.22)
				var a := -PI / 2 + k * PI / 5
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, AMBER if i < filled else empty_color)
			pts.append(pts[0])
			draw_polyline(pts, INK, 1.6, true)


## Nút phím vẽ như phím thật (nền giấy, viền mực, gờ dưới) cho dãy gợi ý phím và thẻ nhiệm vụ.
static func keycap(text: String, size := 14) -> PanelContainer:
	var k := PanelContainer.new()
	k.add_theme_stylebox_override("panel", box(PAPER, 7, 7, INK, 2, 3, Color("#9C8E70")))
	k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	k.add_child(label(text, size, INK, "bold"))
	return k
