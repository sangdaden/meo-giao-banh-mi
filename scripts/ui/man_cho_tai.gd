class_name ManChoTai
extends CanvasLayer
## Màn chờ của bản web khi đang tải gói đồ của một ngày hay tủ đồ (scripts/goi_web.gd).
## Thẻ giấy gói bánh giữa màn hình: dòng chữ, thanh tải, số MB; lỗi mạng thì có nút Thử lại / Về trang chủ.

const T = preload("res://scripts/ui/ui_theme.gd")

signal retry

var packs: Array[String] = []
var _title: Label
var _bar: ProgressBar
var _mb: Label
var _buttons: HBoxContainer
var _got := {}


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = T.make_theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(T.full_rect(root))
	var dim := ColorRect.new()
	dim.color = Color(T.INK, 0.55)
	root.add_child(T.full_rect(dim))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", T.box(T.PAPER, 22, 26, T.INK, 3, 6))
	card.custom_minimum_size = Vector2(520, 0)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	_title = T.label(_text(), 26, T.INK, "display")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 22)
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override("background", T.box(T.SAND, 11, 0, T.INK, 2))
	_bar.add_theme_stylebox_override("fill", T.box(T.CRUST, 11, 0, T.INK, 2))
	col.add_child(_bar)
	_mb = T.label("", 16, T.MUTED)
	_mb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_mb)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 12)
	_buttons.visible = false
	col.add_child(_buttons)
	var again := T.button("Thử lại", "primary", 54, 19)
	again.pressed.connect(func():
		_buttons.visible = false
		_title.text = _text()
		retry.emit())
	_buttons.add_child(again)
	var home := T.button("Về trang chủ", "secondary", 54, 19)
	home.pressed.connect(func():
		queue_free()
		PlayMode.go_home(get_tree()))
	_buttons.add_child(home)
	set_progress("", 0, 0)


func _text() -> String:
	for p in packs:
		if p != "tu_do":
			return "Đang mang đồ ra phố…"
	return "Đang mở tủ đồ của Bơ…"


## Cập nhật thanh tải: tổng các gói cần, gói đang tải được `got` byte.
func set_progress(pack: String, got: int, _size: int) -> void:
	if pack != "":
		_got[pack] = got
	var total := 0
	var have := 0
	for p in packs:
		var size := int(GoiWeb.manifest().get(p, {}).get("size", 0))
		total += size
		have += size if GoiWeb.loaded(p) else int(_got.get(p, 0))
	_bar.max_value = maxf(total, 1)
	_bar.value = have
	_mb.text = "%.1f / %.1f MB" % [have / 1048576.0, total / 1048576.0]


func show_error() -> void:
	_title.text = "Mạng chậm quá, chưa tải xong."
	_buttons.visible = true
