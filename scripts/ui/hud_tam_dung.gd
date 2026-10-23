class_name HudTamDung
extends RefCounted
## Menu Esc dùng chung (phố, bếp, chung cư) và bảng "Cách chơi" mặc định. Tách từ hud.gd; hud._build_pause gọi vào đây.
## Bảng "Cách chơi" riêng của một ngày đặt ở scripts/ngay/<ngày>.gd (khóa help, help_note), không sửa file này.

const T = preload("res://scripts/ui/ui_theme.gd")
const PAPER := Color("#FFF8EA")
const INK := Color("#1F3A3D")
const CRUST := Color("#D98E2B")
const RED := Color("#C8412F")

const HELP_PHO := [["W A S D", "chạy"], ["Shift", "chạy nhanh"], ["Space", "nhảy, nhảy qua Chó Mực"],
	["C", "chui"], ["Z", "rón rén"], ["E", "giao bánh"], ["Chuột", "xoay camera"], ["V", "góc nhìn thứ ba / thứ nhất"]]
const HELP_NOTE_PHO := "Tay cầm: cần trái chạy, A nhảy, Start mở menu. Mũi tên đỏ trên đầu Bơ luôn chỉ về phía khách."


## Menu Esc dùng chung cho phố, bếp và leo chung cư: thẻ giấy giữa màn hình với Tiếp tục, Chơi lại,
## Cài đặt, Chọn màn, Về trang chủ; bên phải là thẻ "Cách chơi" của màn đó.
## Chơi lại phát hud.restart_pressed (màn nào không nối thì tải lại cảnh); Chọn màn phát hud.menu_pressed.
static func build(hud: Node, help := HELP_PHO, note := HELP_NOTE_PHO) -> Control:
	if hud.settings == null:
		hud.settings = SettingsPanel.new()
		hud.settings.visible = false
		hud.root.add_child(hud.settings)
		hud.settings.closed.connect(hud._on_settings_closed)
	var scr := Control.new()
	scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(INK, 0.72)
	scr.add_child(T.full_rect(dim))

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", T.box(PAPER, 22, 0, INK, 4, 8))
	T.place(card, 0.5, 0.5, Rect2(-470, -270, 430, 0))
	scr.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 0)
	card.add_child(cv)
	cv.add_child(T.stripe(12, 22))
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 28)
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 26)
	cv.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	m.add_child(col)
	col.add_child(T.label("Tạm dừng", 46, INK, "display"))
	hud.pause_info = T.label("", 15, T.MUTED, "bold")
	hud.pause_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(hud.pause_info)
	var resume := T.button("  Tiếp tục", "primary", 64, 22)
	resume.pressed.connect(func(): hud.toggle_pause())
	col.add_child(resume)
	hud._add_key_hint(resume, "Esc", T.ON_CRUST)
	var again := T.button("  Chơi lại", "secondary", 56, 19)
	again.pressed.connect(hud._on_menu_restart)
	col.add_child(again)
	var st := T.button("  Cài đặt", "secondary", 56, 19)
	st.pressed.connect(func(): hud.settings.open())
	col.add_child(st)
	var pick := T.button("  Chọn màn", "secondary", 56, 19)
	pick.pressed.connect(hud._on_menu_select)
	col.add_child(pick)
	var home := T.button("  Về trang chủ", "secondary", 56, 19)
	home.pressed.connect(func(): PlayMode.go_home(hud.get_tree()))
	col.add_child(home)
	scr.set_meta("first", resume)

	var helpc := PanelContainer.new()
	helpc.add_theme_stylebox_override("panel", T.box(PAPER, 22, 24, INK, 3, 6))
	T.place(helpc, 0.5, 0.5, Rect2(0, -230, 400, 0))
	scr.add_child(helpc)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 9)
	helpc.add_child(hv)
	hv.add_child(T.label("Cách chơi", 26, INK, "display"))
	for line in help:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.add_child(hud._keycap(line[0], 14))
		var l := T.label(line[1], 16, INK)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		hv.add_child(h)
	if note != "":
		var nl := T.label(note, 14, Color("#2C4F52"))
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD
		nl.custom_minimum_size.x = 340
		hv.add_child(nl)
	T.wire_clicks(scr)
	return scr
