extends CanvasLayer
## Giao diện màn giao bánh theo bản phác thảo Sang duyệt (artboard 5, 6, 8):
## thẻ đơn, đồng hồ, 5 ổ bánh tiến độ, túi bánh còn nóng, khoảng cách, mũi tên ở mép màn hình,
## gợi ý phím, và các màn phủ: tạm dừng, cài đặt, kết quả ca.
## Màn hình chính nằm riêng ở scenes/menu.tscn.
##
## Lưu ý: scripts/kitchen_hud.gd (luồng bếp) kế thừa file này và dùng _overlay, _box, _label,
## _place, start_screen, end_screen, end_text, toast, fps_label, timer_ring, show_end, show_toast.
## Đổi tên những thứ đó thì báo luồng bếp.

signal start_pressed
signal restart_pressed
signal menu_pressed

const T = preload("res://scripts/ui/ui_theme.gd")
# Tên cũ, giữ cho các script kế thừa
const PAPER := Color("#FFF8EA")
const INK := Color("#1F3A3D")
const CRUST := Color("#D98E2B")
const RED := Color("#C8412F")

var root: Control
var play_root: Control
var order_card: PanelContainer
var order_label: Label      # dòng tên khách · nơi giao
var order_detail: Label
var order_chip: Label
var avatar: Panel
var avatar_label: Label
var timer_ring: TimerRing
var progress_row: HBoxContainer
var dots: Array = []
var pause_button: Button
var distance_label: Label
var distance_pill: PanelContainer
var bag_card: PanelContainer
var bag_title: Label
var bag_state: Label
var bag_tag: Label
var bag_tag_box: PanelContainer
var bag_bar: ProgressBar
var edge_arrow: EdgeArrow
var toast: Label
var hint: Control
var fps_label: Label
var start_screen: Control
var pause_screen: Control
var pause_info: Label
var settings: SettingsPanel
var end_screen: Control
var end_text: Label
var _toast_time := 0.0
var _goal := Vector3.ZERO
var _has_goal := false
var _playing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = T.make_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	play_root = Control.new()
	play_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(play_root)
	_build_order_card()
	_build_timer()
	_build_progress()
	_build_bag()
	_build_distance()
	_build_hints()

	edge_arrow = EdgeArrow.new()
	edge_arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	edge_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.add_child(edge_arrow)

	toast = T.outlined("", 28, PAPER, 10)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD
	_place(toast, 0.5, 0.0, Rect2(-330, 158, 660, 80))
	play_root.add_child(toast)

	fps_label = T.outlined("", 16, PAPER, 6)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(fps_label, 1.0, 0.0, Rect2(-260, 92, 232, 24))
	fps_label.visible = GameSettings.get_value("show_fps")
	play_root.add_child(fps_label)

	# Màn bắt đầu cũ nay là scenes/menu.tscn; giữ biến để script khác không lỗi.
	start_screen = Control.new()
	start_screen.visible = false
	root.add_child(start_screen)

	pause_screen = _build_pause()
	pause_screen.visible = false
	root.add_child(pause_screen)

	end_screen = Control.new()
	end_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_screen.visible = false
	root.add_child(end_screen)
	end_text = T.label("", 20, PAPER)  # dùng khi show_end(lines) được gọi kiểu cũ

	settings = SettingsPanel.new()
	settings.visible = false
	root.add_child(settings)
	settings.closed.connect(_on_settings_closed)

	get_viewport().size_changed.connect(_apply_scale)
	_apply_scale()
	T.wire_clicks(root)
	show_playing_ui(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F3:
			fps_label.visible = not fps_label.visible
			GameSettings.set_value("show_fps", fps_label.visible)
		elif event.physical_keycode == KEY_F1:
			GameSettings.set_value("hints", not GameSettings.get_value("hints"))
			hint.visible = _playing and GameSettings.get_value("hints")
	# Lúc đang tạm dừng, main.gd bị dừng theo nên HUD tự bắt phím Esc để chơi tiếp
	if get_tree().paused and pause_screen.visible and not settings.visible and event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if fps_label.visible:
		var fps := Engine.get_frames_per_second()
		fps_label.text = "%d FPS · %.1f ms" % [fps, 1000.0 / maxf(fps, 1.0)]
		fps_label.add_theme_color_override("font_color", PAPER if fps >= 55 else (CRUST if fps >= 40 else RED))
	if _toast_time > 0.0:
		_toast_time -= delta
		toast.modulate.a = clampf(_toast_time / 0.4, 0.0, 1.0)
	edge_arrow.visible = _playing and _has_goal
	if edge_arrow.visible:
		edge_arrow.update_goal(get_viewport().get_camera_3d(), _goal)


# ------------------------------------------------------------ API cho main.gd

func show_playing_ui(on: bool) -> void:
	_playing = on
	for n in [order_card, timer_ring, progress_row, distance_pill, bag_card]:
		n.visible = on
	hint.visible = on and GameSettings.get_value("hints")
	if not on:
		bag_card.visible = false


## color và initial là tuỳ chọn: màu áo và chữ cái của khách cho hình đại diện.
func set_order(index: int, total: int, title: String, detail: String, color := Color(), initial := "") -> void:
	order_chip.text = "Đơn %d/%d" % [index + 1, total]
	order_label.text = title
	order_detail.text = detail
	if initial == "":
		var who := title.split(" · ")[0].strip_edges().split(" ")
		initial = who[who.size() - 1].left(1).to_upper() if who.size() > 0 else "?"
	avatar_label.text = initial
	avatar.add_theme_stylebox_override("panel", T.box(color if color.a > 0 else T.CRUST, 999, 0, INK, 3))


func set_timer(seconds: float, limit: float, active: bool) -> void:
	timer_ring.active = active
	timer_ring.seconds = maxf(seconds, 0.0)
	timer_ring.ratio = seconds / limit if limit > 0 else 0.0


func set_distance(meters: float, what: String) -> void:
	distance_label.text = "%s · còn %d m" % [what, roundi(meters)]


## Điểm đến trong thế giới 3D; khi nó ra ngoài màn hình thì hiện mũi tên đỏ ở mép.
func set_goal(world_pos: Vector3, on := true) -> void:
	_goal = world_pos
	_has_goal = on


## Túi bánh đang mang: what = món, heat 0..1 (1 là vừa ra lò).
func set_bread(carrying: bool, what := "", heat := 1.0) -> void:
	bag_card.visible = _playing and carrying
	if not carrying:
		return
	bag_title.text = "Túi bánh · %s" % what
	bag_bar.value = clampf(heat, 0.0, 1.0) * 100.0
	var state := "Còn nóng giòn" if heat > 0.66 else ("Còn ấm" if heat > 0.33 else "Nguội dần, chạy nhanh lên!")
	var tag := "Nóng" if heat > 0.66 else ("Ấm" if heat > 0.33 else "Nguội")
	bag_state.text = state
	bag_tag.text = tag
	var tag_col := T.AMBER if heat > 0.66 else (T.CREAM if heat > 0.33 else Color("#B5CBC2"))
	bag_tag_box.add_theme_stylebox_override("panel", T.box(tag_col, 999, 10, Color(0, 0, 0, 0), 0))


## results: mỗi phần tử là số sao của đơn đã xong (0 = trễ)
func set_progress(results: Array) -> void:
	for i in dots.size():
		var d: LoafIcon = dots[i]
		if i < results.size():
			d.state = "done" if results[i] > 0 else "late"
		elif i == results.size():
			d.state = "current"
		else:
			d.state = "todo"
		d.queue_redraw()


func show_toast(text: String, seconds := 2.0) -> void:
	toast.text = text
	_toast_time = seconds
	toast.modulate.a = 1.0


## info: dòng tóm tắt hiện dưới chữ "Tạm dừng" (vd. "Đơn 3/5 · Chị Mây · đồng hồ đứng ở 0:09").
func toggle_pause(info := "") -> void:
	var tree := get_tree()
	tree.paused = not tree.paused
	pause_screen.visible = tree.paused
	if tree.paused:
		pause_info.text = info if info != "" else "%s · %s" % [order_chip.text, order_label.text]
		pause_screen.get_meta("first").grab_focus.call_deferred()
	else:
		settings.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if tree.paused else Input.MOUSE_MODE_CAPTURED


## Kiểu cũ: một khối chữ. Màn chơi hiện dùng show_results.
func show_end(lines: String) -> void:
	show_playing_ui(false)
	for c in end_screen.get_children():
		c.queue_free()
	var o := _overlay("Hết ca giao bánh!", lines, "Chơi lại (Enter)", func(): restart_pressed.emit())
	end_screen.add_child(o)
	end_text = o.find_child("Body", true, false)
	end_screen.visible = true


## rows: mỗi phần tử {who, place, item, color, stars (0 = trễ), note}
func show_results(rows: Array) -> void:
	show_playing_ui(false)
	for c in end_screen.get_children():
		c.queue_free()
	end_screen.add_child(_build_results(rows))
	end_screen.visible = true
	T.wire_clicks(end_screen)


# ------------------------------------------------------------ dựng giao diện

func _apply_scale() -> void:
	var s := GameSettings.hud_scale_factor()
	var vp := get_viewport().get_visible_rect().size
	play_root.scale = Vector2(s, s)
	play_root.size = vp / s


func _on_settings_closed() -> void:
	fps_label.visible = GameSettings.get_value("show_fps")
	_apply_scale()
	if pause_screen.visible:
		pause_screen.get_meta("first").grab_focus.call_deferred()


func _card() -> PanelContainer:
	var p := PanelContainer.new()
	var s := T.box(PAPER, 18, 0, INK, 3, 5, Color(INK, 0.35))
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		s.set_content_margin(side, 3)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _build_order_card() -> void:
	order_card = _card()
	_place(order_card, 0.0, 0.0, Rect2(28, 24, 330, 0))
	play_root.add_child(order_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	order_card.add_child(v)
	var stripe := T.stripe(10)
	v.add_child(stripe)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 16)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 12)
	v.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	m.add_child(h)
	avatar = Panel.new()
	avatar.custom_minimum_size = Vector2(60, 60)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar.add_theme_stylebox_override("panel", T.box(T.CRUST, 999, 0, INK, 3))
	h.add_child(avatar)
	avatar_label = T.label("?", 28, INK, "display")
	avatar_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(avatar_label)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.add_theme_stylebox_override("panel", T.box(INK, 999, 10, Color(0, 0, 0, 0), 0))
	order_chip = T.label("Đơn 1/5", 13, PAPER, "bold")
	chip.add_child(order_chip)
	col.add_child(chip)
	order_label = T.label("", 19, INK, "bold")
	order_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(order_label)
	order_detail = T.label("", 16, Color("#2C4F52"))
	col.add_child(order_detail)


func _build_timer() -> void:
	timer_ring = TimerRing.new()
	_place(timer_ring, 0.5, 0.0, Rect2(-64, 16, 128, 128))
	timer_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.add_child(timer_ring)


func _build_progress() -> void:
	progress_row = HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 14)
	progress_row.alignment = BoxContainer.ALIGNMENT_END
	_place(progress_row, 1.0, 0.0, Rect2(-400, 24, 372, 60))
	play_root.add_child(progress_row)
	var pill := PanelContainer.new()
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.add_theme_stylebox_override("panel", T.box(Color(INK, 0.8), 999, 12, Color(0, 0, 0, 0), 0))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_row.add_child(pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	pill.add_child(row)
	for i in 5:
		var d := LoafIcon.new()
		d.custom_minimum_size = Vector2(40, 26)
		row.add_child(d)
		dots.append(d)
	set_progress([])
	pause_button = T.icon_button("pause", "Tạm dừng (Esc)")
	pause_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.pressed.connect(func(): toggle_pause())
	progress_row.add_child(pause_button)


func _build_bag() -> void:
	bag_card = _card()
	_place(bag_card, 0.0, 1.0, Rect2(28, -28, 320, 0))
	bag_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	play_root.add_child(bag_card)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 16)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 14)
	bag_card.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var icon := BagIcon.new()
	icon.custom_minimum_size = Vector2(40, 34)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	bag_title = T.label("Túi bánh", 16, INK, "bold")
	bag_title.clip_text = true
	col.add_child(bag_title)
	bag_state = T.label("Còn nóng giòn", 13, Color("#8A3D12"), "bold")
	col.add_child(bag_state)
	bag_tag_box = PanelContainer.new()
	bag_tag_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bag_tag = T.label("Nóng", 13, T.ON_CRUST, "bold")
	bag_tag_box.add_child(bag_tag)
	h.add_child(bag_tag_box)
	bag_bar = ProgressBar.new()
	bag_bar.show_percentage = false
	bag_bar.custom_minimum_size = Vector2(0, 16)
	bag_bar.add_theme_stylebox_override("background", T.box(T.SAND, 999, 0, INK, 2))
	bag_bar.add_theme_stylebox_override("fill", T.box(T.CRUST, 999, 0, INK, 2))
	bag_bar.value = 100
	v.add_child(bag_bar)
	set_bread(false)


func _build_distance() -> void:
	distance_pill = PanelContainer.new()
	distance_pill.add_theme_stylebox_override("panel", T.box(INK, 999, 22, Color(0, 0, 0, 0), 0))
	distance_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(distance_pill, 0.5, 1.0, Rect2(-200, -80, 400, 48))
	play_root.add_child(distance_pill)
	distance_label = T.label("", 18, PAPER, "bold")
	distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	distance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	distance_pill.add_child(distance_label)


func _build_hints() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_END
	_place(v, 1.0, 1.0, Rect2(-560, -110, 532, 80))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.add_child(v)
	v.add_child(_key_line([["W A S D", "chạy"], ["Shift", "nhanh"], ["Space", "nhảy"]]))
	v.add_child(_key_line([["V", "góc nhìn"], ["Esc", "tạm dừng"], ["F1", "ẩn gợi ý"]]))
	hint = v


func _key_line(pairs: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	h.add_theme_constant_override("separation", 6)
	for p in pairs:
		h.add_child(_keycap(p[0], 13))
		var l := T.outlined(p[1], 13, PAPER, 5)
		l.add_theme_font_override("font", T.font("bold"))
		h.add_child(l)
		var gap := Control.new()
		gap.custom_minimum_size.x = 6
		h.add_child(gap)
	return h


func _keycap(text: String, size := 14) -> PanelContainer:
	var k := PanelContainer.new()
	var s := T.box(PAPER, 7, 7, INK, 2, 3, Color("#9C8E70"))
	k.add_theme_stylebox_override("panel", s)
	k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	k.add_child(T.label(text, size, INK, "bold"))
	return k


func _build_pause() -> Control:
	var scr := Control.new()
	scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(INK, 0.72)
	scr.add_child(T.full_rect(dim))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	_place(col, 0.5, 0.5, Rect2(-310, -290, 420, 560))
	scr.add_child(col)
	col.add_child(T.label("Tạm dừng", 64, PAPER, "display"))
	pause_info = T.label("", 16, T.CREAM, "bold")
	col.add_child(pause_info)
	var resume := T.button("  Chơi tiếp", "primary", 70, 24)
	resume.pressed.connect(func(): toggle_pause())
	col.add_child(resume)
	_add_key_hint(resume, "Esc", T.ON_CRUST)
	var st := T.button("  Cài đặt", "secondary", 62, 20)
	st.pressed.connect(func(): settings.open())
	col.add_child(st)
	var again := T.button("  Làm lại ca từ đầu", "secondary", 62, 20)
	again.pressed.connect(func(): restart_pressed.emit())
	col.add_child(again)
	var home := T.button("  Về màn hình chính", "ghost", 62, 20)
	home.pressed.connect(func(): menu_pressed.emit())
	col.add_child(home)
	scr.set_meta("first", resume)

	var help := PanelContainer.new()
	help.add_theme_stylebox_override("panel", T.box(PAPER, 22, 24, INK, 3, 6))
	_place(help, 0.5, 0.5, Rect2(180, -210, 330, 0))
	scr.add_child(help)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 10)
	help.add_child(hv)
	hv.add_child(T.label("Cách chơi", 26, INK, "display"))
	for line in [["W A S D", "chạy"], ["Shift", "chạy nhanh"], ["Space", "nhảy, nhảy qua Chó Mực"], ["Chuột", "xoay camera"], ["V", "góc nhìn thứ ba / thứ nhất"]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.add_child(_keycap(line[0], 14))
		var l := T.label(line[1], 16, INK)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		hv.add_child(h)
	var note := T.label("Tay cầm: cần trái chạy, A nhảy, Start tạm dừng. Mũi tên đỏ trên đầu Bơ luôn chỉ về phía khách.", 14, Color("#2C4F52"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.custom_minimum_size.x = 280
	hv.add_child(note)
	return scr


func _add_key_hint(btn: Button, text: String, color: Color) -> void:
	var l := T.label(text, 14, color, "bold")
	l.modulate.a = 0.7
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(l, 1.0, 0.5, Rect2(-90, -10, 70, 20))
	btn.add_child(l)


func _build_results(rows: Array) -> Control:
	var scr := Control.new()
	scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = T.TEAL
	scr.add_child(T.full_rect(bg))

	var total := 0
	var on_time := 0
	for r in rows:
		total += int(r.stars)
		on_time += 1 if r.stars > 0 else 0

	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 10)
	_place(left, 0.5, 0.5, Rect2(-592, -320, 420, 640))
	scr.add_child(left)
	var title := T.label("Hết ca giao bánh!", 52, PAPER, "display")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(title)
	var big := T.StarRow.new()
	big.filled = 3 if total >= 13 else (2 if total >= 9 else (1 if total >= 5 else 0))
	big.empty_color = Color("#256569")
	big.custom_minimum_size = Vector2(3 * 84 + 8, 80)
	big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(big)
	var tl := T.label("%d / 15 sao" % total, 34, T.AMBER, "display")
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(tl)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", T.box(Color("#8DBDB3"), 24, 0, INK, 4))
	frame.custom_minimum_size = Vector2(300, 230)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var pic := TextureRect.new()
	pic.texture = load("res://assets/ui/bo_menu.jpg")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.add_child(pic)
	left.add_child(frame)
	var praise := "Khách khen bánh còn nóng giòn!" if on_time == rows.size() else ("Ca này ổn, còn vài đơn trễ." if on_time >= 3 else "Ca vất vả quá, thử lại nhé!")
	var pl := T.label(praise, 16, T.CREAM, "bold")
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(pl)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.box(PAPER, 26, 28, INK, 4, 8))
	_place(panel, 0.5, 0.5, Rect2(-120, -320, 712, 640))
	scr.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(T.label("Năm đơn sáng nay", 30, INK, "display"))
	for i in rows.size():
		v.add_child(_result_row(rows[i], i))

	var unlock := PanelContainer.new()
	var us := T.box(Color(0, 0, 0, 0), 14, 12, CRUST, 3)
	unlock.add_theme_stylebox_override("panel", us)
	var uh := HBoxContainer.new()
	uh.add_theme_constant_override("separation", 14)
	unlock.add_child(uh)
	var uv := VBoxContainer.new()
	uv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var need := rows.size() - on_time
	uv.add_child(T.label("Đã mở skin Vỏ Bánh Giòn!" if need == 0 else "Còn %d đơn kịp giờ nữa là mở skin Vỏ Bánh Giòn" % need, 16, INK, "bold"))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.max_value = maxi(rows.size(), 1)
	bar.value = on_time
	bar.add_theme_stylebox_override("background", T.box(T.SAND, 999, 0, INK, 2))
	bar.add_theme_stylebox_override("fill", T.box(CRUST, 999, 0, INK, 2))
	uv.add_child(bar)
	uh.add_child(uv)
	uh.add_child(T.label("%d/%d" % [on_time, rows.size()], 20, INK, "display"))
	v.add_child(unlock)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	v.add_child(foot)
	var again := T.button("  Chơi lại ca", "primary", 62, 20)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func(): restart_pressed.emit())
	_add_key_hint(again, "Enter", T.ON_CRUST)
	foot.add_child(again)
	var home := T.button("Về menu", "secondary", 62, 20)
	home.pressed.connect(func(): menu_pressed.emit())
	foot.add_child(home)
	again.grab_focus.call_deferred()
	return scr


func _result_row(r: Dictionary, i: int) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.box(Color("#F6EDDA") if i % 2 == 0 else Color(0, 0, 0, 0), 14, 12, Color(0, 0, 0, 0), 0))
	p.custom_minimum_size.y = 58
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var av := Panel.new()
	av.custom_minimum_size = Vector2(42, 42)
	av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	av.add_theme_stylebox_override("panel", T.box(r.get("color", CRUST), 999, 0, INK, 3))
	var who: String = r.get("who", "")
	var parts := who.split(" ")
	var ini := T.label(parts[parts.size() - 1].left(1).to_upper() if parts.size() > 0 else "?", 20, INK, "display")
	ini.set_anchors_preset(Control.PRESET_FULL_RECT)
	ini.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ini.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av.add_child(ini)
	h.add_child(av)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(T.label("%s · %s" % [who, r.get("place", "")], 17, INK, "bold"))
	col.add_child(T.label("%s · %s" % [r.get("item", ""), r.get("note", "")], 14, Color("#2C4F52")))
	h.add_child(col)
	var stars: int = r.get("stars", 0)
	var tag := PanelContainer.new()
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_theme_stylebox_override("panel", T.box(T.LEAF if stars > 0 else RED, 999, 12, Color(0, 0, 0, 0), 0))
	tag.add_child(T.label("Kịp giờ" if stars > 0 else "Trễ", 13, PAPER, "bold"))
	h.add_child(tag)
	var sr := T.StarRow.new()
	sr.filled = stars
	sr.empty_color = T.SAND
	sr.custom_minimum_size = Vector2(3 * 32 + 8, 28)
	sr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sr)
	return p


# ------------------------------------------------------------ hàm cũ, giữ cho script kế thừa

func _overlay(title: String, body: String, button_text: String, on_press: Callable) -> Control:
	var bg := ColorRect.new()
	bg.color = Color(INK, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	var t := T.label(title, 56, CRUST, "display")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var b := T.label(body, 20, PAPER)
	b.name = "Body"
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(b)
	var btn := T.button(button_text, "primary", 60, 22)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(on_press)
	box.add_child(btn)
	return bg


func _place(c: Control, ax: float, ay: float, r: Rect2) -> void:
	T.place(c, ax, ay, r)


func _label(text: String, font_size: int, color: Color) -> Label:
	return T.label(text, font_size, color)


func _box(color: Color, radius: int, pad: int, border := Color.TRANSPARENT) -> StyleBoxFlat:
	return T.box(color, radius, pad, border, 2 if border.a > 0 else 0)


# ------------------------------------------------------------ hình vẽ nhỏ

## Ổ bánh mì trong hàng tiến độ: done (cam), late (đỏ), current (viền vàng nét đứt), todo (viền mờ).
class LoafIcon:
	extends Control
	var state := "todo"

	func _draw() -> void:
		var pts := PackedVector2Array()
		var w := size.x
		var h := size.y
		for i in 25:
			var a := PI + PI * i / 24.0
			pts.append(Vector2(w / 2 + cos(a) * (w / 2 - 2), h * 0.6 + sin(a) * (h * 0.5)))
		for i in 25:
			var a := PI * i / 24.0
			pts.append(Vector2(w / 2 + cos(a) * (w / 2 - 3), h * 0.62 + sin(a) * (h * 0.3)))
		var outline := pts.duplicate()
		outline.append(pts[0])
		match state:
			"done", "late":
				draw_colored_polygon(pts, UiTheme.CRUST if state == "done" else UiTheme.RED)
				draw_polyline(outline, UiTheme.PAPER, 2.0, true)
				if state == "done":
					for x in [0.32, 0.5, 0.68]:
						draw_line(Vector2(w * x - 2, h * 0.35), Vector2(w * x + 2, h * 0.62), UiTheme.CRUST_DARK, 2.0, true)
				else:
					draw_line(Vector2(w * 0.38, h * 0.3), Vector2(w * 0.62, h * 0.75), UiTheme.PAPER, 2.5, true)
					draw_line(Vector2(w * 0.62, h * 0.3), Vector2(w * 0.38, h * 0.75), UiTheme.PAPER, 2.5, true)
			"current":
				for i in range(0, outline.size() - 1, 2):
					draw_line(outline[i], outline[i + 1], UiTheme.AMBER, 2.5, true)
			_:
				draw_polyline(outline, Color(UiTheme.PAPER, 0.6), 2.0, true)


class BagIcon:
	extends Control
	func _draw() -> void:
		draw_style_box(UiTheme.box(UiTheme.TEAL, 6, 0, UiTheme.INK, 2), Rect2(3, 8, 34, 24))
		draw_arc(Vector2(20, 8), 7, PI, TAU, 12, UiTheme.INK, 2.5, true)
		draw_line(Vector2(10, 15), Vector2(31, 14), UiTheme.CRUST, 5.0, true)


## Mũi tên đỏ ở mép màn hình chỉ về phía điểm đến khi nó nằm ngoài khung hình.
class EdgeArrow:
	extends Control
	var _pos := Vector2.ZERO
	var _dir := Vector2.RIGHT
	var _show := false

	func update_goal(cam: Camera3D, goal: Vector3) -> void:
		_show = false
		if cam == null:
			queue_redraw()
			return
		var vp := size
		var margin := 70.0
		var behind := cam.is_position_behind(goal)
		var p := cam.unproject_position(goal)
		if behind:
			p = vp - p  # đằng sau: lật lại để mũi tên chỉ đúng phía
		var inside := not behind and p.x > margin and p.x < vp.x - margin and p.y > margin and p.y < vp.y - margin
		if not inside:
			var c := vp / 2.0
			var d := (p - c)
			if d.length() < 1.0:
				d = Vector2.DOWN
			if behind and absf(d.y) < absf(d.x) * 0.2:
				d.y = absf(d.x) * 0.2
			_dir = d.normalized()
			var half := c - Vector2(margin, margin)
			var t := minf(half.x / maxf(absf(_dir.x), 0.001), half.y / maxf(absf(_dir.y), 0.001))
			_pos = c + _dir * t
			_show = true
		queue_redraw()

	func _draw() -> void:
		if not _show:
			return
		var a := _dir.angle()
		var pts := PackedVector2Array([Vector2(26, 0), Vector2(-16, -22), Vector2(-8, 0), Vector2(-16, 22)])
		for i in pts.size():
			pts[i] = _pos + pts[i].rotated(a)
		draw_colored_polygon(pts, UiTheme.RED)
		pts.append(pts[0])
		draw_polyline(pts, UiTheme.PAPER, 4.0, true)
