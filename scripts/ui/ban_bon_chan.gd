class_name BanBonChan
extends VBoxContainer
## Trang "Bạn bốn chân" trong Sổ hàng xóm (gói T2): mỗi con vật Bơ đã chơi cùng (ConVat.meet) một ô nhỏ,
## chưa gặp thì "???" kèm gợi ý chỗ gặp. Đủ hết thì có phụ kiện thưởng (ConVat.QUA).

const T = preload("res://scripts/ui/ui_theme.gd")

## Ảnh dán kèm ô (khóa ảnh SoHangXom.photo): ngủ trưa với Mực (luồng "Mực xuyên tuần").
const PHOTOS := {"muc": "ngu_trua_muc"}

var _title: Label
var _grid: GridContainer


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = T.label("", 22, T.INK, "display")
	add_child(_title)
	add_child(T.label("Bấm Q kêu meo cạnh con vật. Con nào đáp lại lần đầu thì có tên trong trang này.", 14, T.MUTED, "bold"))
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	add_child(_grid)
	refresh()


func refresh() -> void:
	if _grid == null:
		return
	_title.text = "Bạn bốn chân · %d/%d" % [ConVat.count(), ConVat.ALL.size()]
	if ConVat.full():
		_title.text += " · ♥ " + ConVat.QUA_TEN
	for c in _grid.get_children():
		c.queue_free()
	for id: String in ConVat.ALL:
		_grid.add_child(_card(id))


func _card(id: String) -> Control:
	var seen := ConVat.met(id)
	var info: Array = ConVat.ALL[id]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(164, 0)
	card.add_theme_stylebox_override("panel", T.box(T.PAPER if seen else Color("#F4ECDA"), 12, 8, T.LEAF if seen else T.SAND, 2))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)
	var img := SoHangXom.photo(PHOTOS.get(id, "")) if seen and PHOTOS.has(id) else null
	if img:
		var ph := TextureRect.new()
		ph.custom_minimum_size = Vector2(148, 70)
		ph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		ph.texture = ImageTexture.create_from_image(img)
		v.add_child(ph)
	v.add_child(T.label(("♥ " + str(info[0])) if seen else "???", 16, T.INK if seen else T.MUTED, "display"))
	var hint := T.label(str(info[1]), 12, T.MUTED, "bold")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	return card
