extends CanvasLayer
## Dòng chữ nhỏ góc phải dưới khi bấm M tắt/bật tiếng. Chỉnh âm lượng nằm ở menu
## Cài đặt (scripts/ui/settings_panel.gd), gọi Sound.get_volume/set_volume/set_muted.

const PAPER := Color("#FFF8EA")
const INK := Color("#1F2A2A")

var _flash: Label
var _flash_time := 0.0


func _ready() -> void:
	layer = 20  # trên HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	_flash = Label.new()
	_flash.add_theme_font_size_override("font_size", 18)
	_flash.add_theme_color_override("font_color", PAPER)
	_flash.add_theme_color_override("font_outline_color", INK)
	_flash.add_theme_constant_override("outline_size", 6)
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.anchor_left = 1.0
	_flash.anchor_right = 1.0
	_flash.anchor_top = 1.0
	_flash.anchor_bottom = 1.0
	_flash.offset_left = -344
	_flash.offset_top = -60
	_flash.offset_right = -24
	_flash.offset_bottom = -30
	_flash.modulate.a = 0.0
	add_child(_flash)


func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		_flash.modulate.a = clampf(_flash_time / 0.4, 0.0, 1.0)


## Hiện thông báo ngắn, ví dụ khi bấm M lúc đang chạy.
func flash(text: String) -> void:
	_flash.text = text
	_flash_time = 1.6
