class_name HudBanDo
extends RefCounted
## Bản đồ nhỏ góc màn hình và bản đồ lớn (phím B) của HUD phố. Tách từ hud.gd; hud.gd giữ biến minimap, minimap_card, big_map, big_map_view.

const T = preload("res://scripts/ui/ui_theme.gd")
const PAPER := Color("#FFF8EA")
const INK := Color("#1F3A3D")
const CRUST := Color("#D98E2B")
const RED := Color("#C8412F")


## Thẻ giấy bo góc viền mực, bên trong là bản đồ xoay theo camera; dưới đáy có nhãn phím B.
static func build_minimap(hud: Node) -> void:
	hud.minimap_card = Control.new()
	hud.minimap_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	T.place(hud.minimap_card, 1.0, 0.0, Rect2(-248, 98, 220, 238))
	hud.minimap_card.visible = false
	hud.play_root.add_child(hud.minimap_card)
	var mask := Panel.new()
	mask.add_theme_stylebox_override("panel", T.box(PAPER, 22, 0, Color(0, 0, 0, 0), 0))
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.position = Vector2.ZERO
	mask.size = Vector2(220, 220)
	hud.minimap_card.add_child(mask)
	hud.minimap = BanDoNho.new()
	hud.minimap.position = Vector2.ZERO
	hud.minimap.size = mask.size
	mask.add_child(hud.minimap)
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", T.box(Color(0, 0, 0, 0), 22, 0, INK, 3))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = mask.size
	hud.minimap_card.add_child(frame)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", T.box(INK, 999, 10, Color(0, 0, 0, 0), 0))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_text := T.label("B · bản đồ lớn", 13, PAPER, "bold")
	chip.add_child(chip_text)
	chip.position = Vector2(56, 206)
	chip.size = Vector2(108, 26)
	hud.minimap_card.add_child(chip)


## Bản đồ lớn: nền mờ, thẻ giấy giữa màn hình, bắc ở trên, có chú thích. Mở thì tạm dừng cho người chơi xem thong thả.
static func build_big_map(hud: Node) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(INK, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(dim)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", T.box(PAPER, 22, 18, INK, 3, 6))
	T.place(card, 0.5, 0.5, Rect2(-520, -330, 1040, 0))
	c.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	var title := T.label("Bản đồ khu phố", 28, INK, "display")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(T.label("B hoặc Esc để đóng · đồng hồ tạm dừng", 15, T.MUTED))
	var mask := Panel.new()
	mask.add_theme_stylebox_override("panel", T.box(PAPER, 16, 0, Color(0, 0, 0, 0), 0))
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	mask.custom_minimum_size = Vector2(1000, 560)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(mask)
	hud.big_map_view = BanDoNho.new()
	hud.big_map_view.full = true
	hud.big_map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.add_child(hud.big_map_view)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 22)
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(legend)
	for item in [[T.FUR, "Bơ"], [RED, "Đang tới"], [CRUST, "Lò Cô Ba"], [T.SAND, "Số: đơn sắp tới"], [PAPER, "Dấu tích: đã xong"]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(16, 16)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel", T.box(item[0], 999, 0, INK, 2))
		h.add_child(dot)
		h.add_child(T.label(item[1], 15, INK, "bold"))
		legend.add_child(h)
	if DoKho.v("map_path", false):
		legend.add_child(T.label("Chấm đỏ: đường gợi ý", 15, T.MUTED))
	return c
