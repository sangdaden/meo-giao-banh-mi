class_name ChoNamTrang
extends VBoxContainer
## Trang "Chỗ nằm ưa thích" trong Sổ hàng xóm (U1): mỗi chỗ nằm trong tuần (ChoNam.LIST) một ô nhỏ.
## Đã nằm thì có tên chỗ và ngày, chưa thì "???" kèm ngày để Sang biết hôm nào đi tìm.

const T = preload("res://scripts/ui/ui_theme.gd")

var _title: Label
var _grid: GridContainer


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = T.label("", 22, T.INK, "display")
	add_child(_title)
	add_child(T.label("Tìm vệt nắng ấm trên phố, đứng yên một lúc là Bơ cuộn tròn nằm sưởi.", 14, T.MUTED, "bold"))
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	add_child(_grid)
	refresh()


func refresh() -> void:
	if _grid == null:
		return
	_title.text = "Chỗ nằm ưa thích · %d/%d" % [ChoNam.count(), ChoNam.LIST.size()]
	for c in _grid.get_children():
		c.queue_free()
	for s in ChoNam.LIST:
		_grid.add_child(_card(s))


func _card(s: Dictionary) -> Control:
	var seen := ChoNam.found(str(s.id))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(164, 0)
	card.add_theme_stylebox_override("panel", T.box(T.PAPER if seen else Color("#F4ECDA"), 12, 8, T.AMBER if seen else T.SAND, 2))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)
	var name_l := T.label(("☀ " + str(s.name)) if seen else "???", 16, T.INK if seen else T.MUTED, "display")
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_l)
	v.add_child(T.label(str(GameState.DAY_NAMES.get(s.day, s.day)), 12, T.MUTED, "bold"))
	return card
