extends CanvasLayer
## Giao diện chuyện tuần (scripts/chuyen/chuyen.gd điều khiển):
## - phụ đề một câu ở giữa đáy màn hình: tên người nói (màu riêng) + câu; chữ kể (toast) in nghiêng không tên;
## - tranh Bé Na hiện cạnh phụ đề khi câu có "anh";
## - nút hỏi nhận thư (L3): "E: nhận thư (tùy chọn)" kèm vạch 4 giây;
## - tờ báo sáng Chú Tư (O1) góc trái dưới thẻ đơn lúc đầu ngày, có góc đếm ngược "Còn N ngày ★";
## - bưu thiếp cuối ngày (O2) góc trên trái, trên bảng kết quả.
## Cỡ chữ theo Cài đặt > Cỡ giao diện như HUD chính. Không nhận chuột (MOUSE_FILTER_IGNORE).

const T = preload("res://scripts/ui/ui_theme.gd")

## Màu tên người nói (đậm cho dễ đọc trên nền giấy)
const MAU := {
	"Cô Ba": Color("#C8412F"), "Chú Tư": Color("#3D5A80"), "Bé Na": Color("#A3477A"), "Chị Mây": Color("#2F7A66"),
	"Anh Hùng": Color("#4A5A57"), "Bà Sáu": Color("#9C3326"), "Chú Năm": Color("#5C6B2E"), "Cô Hai": Color("#B4612F"),
	"Ông Bảy": Color("#6A4E2A"), "Ông Tám": Color("#6A4E2A"), "Bà Mướp": Color("#8A5A9E"), "Chị Lan": Color("#5F6B2B"),
	"Cả xóm": Color("#C8412F"),
}

var root: Control
var _sub: PanelContainer
var _who: Label
var _txt: Label
var _pic: TextureRect
var _hoi_box: PanelContainer
var _hoi_bar: ProgressBar
var _bao: PanelContainer
var _bao_day: Label
var _bao_hl: Label
var _bao_corner: Label
var _bao_t := 0.0
var _buu: PanelContainer
var _hoi_t := 0.0
var _noi := false


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = T.make_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_sub()
	_build_bao()
	_apply_scale()
	get_viewport().size_changed.connect(_apply_scale)


func _apply_scale() -> void:
	var s := GameSettings.hud_scale_factor()
	root.scale = Vector2(s, s)
	root.size = get_viewport().get_visible_rect().size / s


func _build_sub() -> void:
	_sub = PanelContainer.new()
	_sub.add_theme_stylebox_override("panel", T.box(T.PAPER, 18, 16, T.INK, 3, 5))
	T.place(_sub, 0.5, 1.0, Rect2(-330, -330, 660, 0))
	_sub.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_sub)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_sub.add_child(h)
	_pic = TextureRect.new()
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pic.custom_minimum_size = Vector2(200, 142)
	_pic.visible = false
	h.add_child(_pic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_who = T.label("", 16, T.RED, "bold")
	v.add_child(_who)
	_txt = T.label("", 20, T.INK)
	_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_txt.custom_minimum_size.x = 400
	_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_txt)
	_hoi_box = PanelContainer.new()
	_hoi_box.add_theme_stylebox_override("panel", T.box(T.CREAM, 12, 8, T.TEAL, 2))
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 8)
	_hoi_box.add_child(hh)
	hh.add_child(T.keycap("E", 14))
	var hl := T.label("nhận thư (tùy chọn)", 16, T.INK, "bold")
	hl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hh.add_child(hl)
	_hoi_bar = ProgressBar.new()
	_hoi_bar.show_percentage = false
	_hoi_bar.custom_minimum_size = Vector2(120, 8)
	_hoi_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hoi_bar.max_value = 1.0
	hh.add_child(_hoi_bar)
	_hoi_box.visible = false
	v.add_child(_hoi_box)
	_sub.visible = false


func _build_bao() -> void:
	_bao = PanelContainer.new()
	_bao.add_theme_stylebox_override("panel", T.box(Color("#F3EEDF"), 6, 14, T.INK, 3, 5))
	T.place(_bao, 0.0, 0.0, Rect2(28, 120, 340, 0))  # dưới thẻ đơn, góc trái
	_bao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bao.rotation_degrees = -1.5
	root.add_child(_bao)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_bao.add_child(v)
	var mast := HBoxContainer.new()
	v.add_child(mast)
	var m := T.label("BÁO SÁNG CHÚ TƯ", 15, T.INK, "display")
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mast.add_child(m)
	_bao_day = T.label("", 13, T.MUTED, "bold")
	_bao_day.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mast.add_child(_bao_day)
	var rule := ColorRect.new()
	rule.color = T.INK
	rule.custom_minimum_size = Vector2(0, 3)
	v.add_child(rule)
	_bao_hl = T.label("", 24, T.INK, "display")
	_bao_hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bao_hl.custom_minimum_size.x = 300
	v.add_child(_bao_hl)
	var cr := HBoxContainer.new()
	v.add_child(cr)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cr.add_child(sp)
	var cbox := PanelContainer.new()
	cbox.add_theme_stylebox_override("panel", T.box(T.CREAM, 6, 6, T.RED, 2))
	cbox.rotation_degrees = -3.0
	cr.add_child(cbox)
	_bao_corner = T.label("", 15, T.RED, "bold")
	cbox.add_child(_bao_corner)
	_bao.visible = false


# ---------------------------------------------------------------- phụ đề

func noi(ai: String, cau: String, kind: String, anh := "") -> void:
	_noi = true
	_sub.visible = true
	_sub.modulate.a = 1.0
	var ke := ai == ""
	_who.visible = not ke
	_who.text = ai
	_who.add_theme_color_override("font_color", MAU.get(ai, T.RED))
	_txt.text = cau
	_txt.add_theme_color_override("font_color", T.MUTED if ke else T.INK)
	_txt.add_theme_font_override("font", T.font("bold") if kind == "phim" else T.font("body"))
	var path := "res://assets/chuyen/%s.jpg" % anh
	_pic.visible = anh != "" and ResourceLoader.exists(path)
	if _pic.visible:
		_pic.texture = load(path)
		_pic.custom_minimum_size = Vector2(300, 190) if anh == "tranh_lon" else Vector2(200, 142)
	_txt.custom_minimum_size.x = 340.0 if _pic.visible else 560.0


func an() -> void:
	_noi = false
	_hoi_box.visible = false
	if _sub.visible:
		var tw := create_tween()
		tw.tween_property(_sub, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func() -> void:
			if not _noi:
				_sub.visible = false)


func dang_noi() -> bool:
	return _noi


## n > 0: hiện nút nhận thư số n, 0: tắt.
func hoi(n: int) -> void:
	_hoi_box.visible = n > 0
	_hoi_t = 4.0 if n > 0 else 0.0
	_hoi_bar.value = 1.0


# ---------------------------------------------------------------- báo sáng (O1)

func bao(day_name: String, tit: String, goc: String, secs: float) -> void:
	_bao_day.text = day_name
	_bao_hl.text = tit
	_bao_corner.text = goc
	_bao_t = secs
	_bao.visible = true
	_bao.modulate.a = 0.0
	create_tween().tween_property(_bao, "modulate:a", 1.0, 0.3)


# ---------------------------------------------------------------- bưu thiếp cuối ngày (O2)

func buu_thiep(dong1: String, dong2: String, ky: String, thiep: String) -> void:
	if _buu:
		_buu.queue_free()
	_buu = PanelContainer.new()
	_buu.add_theme_stylebox_override("panel", T.box(T.CREAM, 10, 10, T.INK, 3, 5))
	T.place(_buu, 0.0, 0.0, Rect2(24, 14, 440, 0))  # góc trên trái, trên chữ "Hết ca" của bảng kết quả
	_buu.rotation_degrees = -1.5
	_buu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_buu)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	_buu.add_child(h)
	var path := "res://assets/chuyen/%s.jpg" % thiep
	if thiep != "" and ResourceLoader.exists(path):
		var pic := TextureRect.new()
		pic.texture = load(path)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(104, 74)
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(pic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(T.label("Nhật ký của Bơ", 13, T.MUTED, "bold"))
	for d in [dong1, dong2]:
		var l := T.label(d, 14, T.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 290
		v.add_child(l)
	if ky != "":
		v.add_child(T.label("Thiệp mừng: %s" % ky, 13, T.RED, "bold"))
	_buu.modulate.a = 0.0
	create_tween().tween_property(_buu, "modulate:a", 1.0, 0.4).set_delay(0.6)


func _process(delta: float) -> void:
	if _hoi_t > 0.0:
		_hoi_t -= delta
		_hoi_bar.value = maxf(_hoi_t / 4.0, 0.0)
	if _bao_t > 0.0:
		_bao_t -= delta
		if _bao_t <= 0.0:
			var tw := create_tween()
			tw.tween_property(_bao, "modulate:a", 0.0, 0.4)
			tw.tween_callback(func() -> void: _bao.visible = false)
	# phụ đề né thẻ mẹo của HUD chính (đáy giữa)
	var up := false
	var c := get_parent()
	var m: Node = c.get_parent() if c else null
	var hud: Object = m.get("hud") if m else null
	if hud != null and hud.get("tip_card") is Control:
		up = (hud.get("tip_card") as Control).visible
	var y := -300.0 if up else -180.0
	var w := 760.0 if _pic.visible else 640.0
	_sub.offset_left = -w * 0.5
	_sub.offset_right = w * 0.5
	_sub.offset_top = y
	_sub.offset_bottom = y
