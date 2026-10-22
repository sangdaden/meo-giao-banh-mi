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
var kitchen_row: HBoxContainer  # sao bếp của ổ đang giao (ẩn khi chưa có)
var kitchen_stars: UiTheme.StarRow
var stance_pill: PanelContainer
var stance_label: Label
var stance_dot: Panel
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
var tip_card: PanelContainer
var order_note: PanelContainer
var order_note_label: Label
var egg_pill: PanelContainer
var egg_row: HBoxContainer
var egg_label: Label
var day_card: Control
var _day_time := 0.0
var tip_title: Label
var tip_body: Label
var tip_keys: HBoxContainer
var _tip_time := 0.0
var _goal := Vector3.ZERO
var _has_goal := false
var _playing := false
## Bản đồ nhỏ góc phải (scripts/ui/ban_do_nho.gd) và bản đồ lớn phím B. Màn nào có khu phố thì gọi enable_minimap(true).
var minimap: BanDoNho
var minimap_card: Control
var big_map: Control
var big_map_view: BanDoNho
var _minimap_on := false


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
	_build_stance()
	_build_hints()
	_build_tip()
	_build_eggs()
	_build_day_card()
	_build_minimap()

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

	big_map = _build_big_map()
	big_map.visible = false
	root.add_child(big_map)

	if settings == null:  # _build_pause đã tạo rồi thì dùng lại, không tạo bảng thứ hai
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
		elif event.physical_keycode == KEY_F1 and hint:
			GameSettings.set_value("hints", not GameSettings.get_value("hints"))
			hint.visible = _playing and GameSettings.get_value("hints")
	if _minimap_on and big_map and (event.is_action_pressed("ban_do") or (big_map.visible and event.is_action_pressed("pause"))):
		if big_map.visible or (minimap_card.visible and not get_tree().paused):
			toggle_big_map()
			get_viewport().set_input_as_handled()
			return
	# Lúc đang tạm dừng, main.gd bị dừng theo nên HUD tự bắt phím Esc để chơi tiếp
	if get_tree().paused and pause_screen.visible and not (settings and settings.visible) and event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if fps_label.visible:
		var fps := Engine.get_frames_per_second()
		fps_label.text = "%d FPS · %.1f ms" % [fps, 1000.0 / maxf(fps, 1.0)]
		fps_label.add_theme_color_override("font_color", PAPER if fps >= 55 else (CRUST if fps >= 40 else RED))
	if _day_time > 0.0:
		_day_time -= delta
		day_card.modulate.a = clampf(_day_time / 0.5, 0.0, 1.0)
		day_card.visible = _day_time > 0.0
	if _tip_time > 0.0:
		_tip_time -= delta
		tip_card.modulate.a = clampf(_tip_time / 0.4, 0.0, 1.0)
		tip_card.visible = _tip_time > 0.0
	if _toast_time > 0.0:
		_toast_time -= delta
		toast.modulate.a = clampf(_toast_time / 0.4, 0.0, 1.0)
	if edge_arrow == null:
		return
	edge_arrow.visible = _playing and _has_goal
	if edge_arrow.visible:
		edge_arrow.update_goal(get_viewport().get_camera_3d(), _goal)


# ------------------------------------------------------------ API cho main.gd

func show_playing_ui(on: bool) -> void:
	_playing = on
	# Kiểm tra null: script kế thừa (HUD bếp cũ) tự dựng giao diện riêng, chỉ có vài node này.
	for n in [order_card, timer_ring, progress_row, distance_pill,
			order_label.get_parent() if order_label else null, distance_label.get_parent() if distance_label else null]:
		if n:
			n.visible = on
	if hint:
		hint.visible = on and (GameSettings.get_value("hints") or bag_card == null)
	if bag_card and not on:
		bag_card.visible = false
	if stance_pill and not on:
		stance_pill.visible = false
	if tip_card and not on:
		tip_card.visible = false
	if egg_pill and not on:
		egg_pill.visible = false
	if minimap_card:
		minimap_card.visible = on and _minimap_on
	if big_map and big_map.visible and not on:
		toggle_big_map()


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


## Sao bếp (0..3) của ổ đang giao, hiện dưới phiếu đơn. -1 để ẩn.
func set_kitchen_stars(n: int) -> void:
	if kitchen_row == null:
		return
	kitchen_row.visible = n >= 0
	kitchen_stars.filled = clampi(n, 0, 3)
	kitchen_stars.queue_redraw()


## Dáng đi của Bơ ("walk" | "sprint" | "crouch" | "sneak"): rón rén và chui thì hiện chấm chỉ báo.
func set_stance(stance: String) -> void:
	if stance_pill == null:
		return
	var show := _playing and stance in ["sneak", "crouch"]
	stance_pill.visible = show
	if show:
		stance_label.text = "Đang rón rén · bước êm" if stance == "sneak" else "Đang chui · thấp người"
		stance_dot.add_theme_stylebox_override("panel", T.box(T.LEAF if stance == "sneak" else T.AMBER, 999, 0, PAPER, 2))


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
	if minimap:
		minimap.set_goal(world_pos, on)
		big_map_view.set_goal(world_pos, on)


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


var _pause_text := ""
var _mouse_before := Input.MOUSE_MODE_CAPTURED  # chế độ chuột trước khi mở menu, đóng menu thì trả lại


## Dòng tóm tắt hiện dưới chữ "Tạm dừng" (vd. "Đơn 3/5 · Chị Mây · đồng hồ đứng ở 0:09").
## Gọi trước toggle_pause(); để trống thì lấy theo thẻ đơn.
func set_pause_info(info: String) -> void:
	_pause_text = info


func toggle_pause() -> void:
	var info := _pause_text
	_pause_text = ""
	var tree := get_tree()
	tree.paused = not tree.paused
	pause_screen.visible = tree.paused
	if tree.paused:
		_mouse_before = Input.mouse_mode
		if pause_info:
			if info == "" and order_chip:
				info = "%s · %s" % [order_chip.text, order_label.text]
			pause_info.text = info
			pause_info.visible = info != ""
		pause_screen.get_meta("first").grab_focus.call_deferred()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if settings:
			settings.visible = false
		Input.mouse_mode = _mouse_before


## Kiểu cũ: một khối chữ. Màn chơi hiện dùng show_results.
func show_end(lines: String) -> void:
	show_playing_ui(false)
	if bag_card == null:  # script kế thừa đã tự dựng end_screen có sẵn end_text
		end_text.text = lines
		end_screen.visible = true
		return
	for c in end_screen.get_children():
		c.queue_free()
	var o := _overlay("Hết ca giao bánh!", lines, "Chơi lại (Enter)", func(): restart_pressed.emit())
	end_screen.add_child(o)
	end_text = o.find_child("Body", true, false)
	end_screen.visible = true


## rows: mỗi phần tử {who, place, item, color, stars (0 = trễ), note} và thêm (luồng chấm điểm):
##   {tip (đồng), kitchen_stars 0..3, side_quest (tên, "" = không có), side_ok, late, intact, time, best_time}
## summary: {stars, stars_max, tip (tổng gồm thưởng), bonus, rank "thuong"|"gion"|"vang",
##   stamps, stamps_total, stamps_all, new_record, day, wallet}. Khóa nào thiếu thì phần đó ẩn.
func show_results(rows: Array, summary := {}) -> void:
	show_playing_ui(false)
	for c in end_screen.get_children():
		c.queue_free()
	end_screen.add_child(_build_results(rows, summary))
	end_screen.visible = true
	T.wire_clicks(end_screen)


# ------------------------------------------------------------ dựng giao diện

func _apply_scale() -> void:
	var s := GameSettings.hud_scale_factor()
	var vp := get_viewport().get_visible_rect().size
	play_root.scale = Vector2(s, s)
	play_root.size = vp / s


## Tự thử menu Esc (autotest): mở menu, bấm Cài đặt, bảng Cài đặt phải hiện và nằm trên menu, rồi đóng hết.
func self_test_menu() -> bool:
	var was := get_tree().paused
	if not was:
		toggle_pause()
	var btn: Button = null
	for b in pause_screen.find_children("*", "Button", true, false):
		if b.text.strip_edges() == "Cài đặt":
			btn = b
	var ok := btn != null and pause_screen.visible
	if btn:
		btn.pressed.emit()
	ok = ok and settings.visible and settings.get_parent() == pause_screen.get_parent() \
		and settings.get_index() > pause_screen.get_index() \
		and root.find_children("*", "SettingsPanel", true, false).size() == 1
	settings.close()
	ok = ok and not settings.visible and pause_screen.visible
	if not was:
		toggle_pause()
	print("[autotest] menu Esc > Cài đặt: ", "OK" if ok else "FAIL")
	return ok


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
	kitchen_row = HBoxContainer.new()
	kitchen_row.add_theme_constant_override("separation", 6)
	kitchen_row.add_child(T.label("Ổ từ bếp", 13, T.MUTED, "bold"))
	kitchen_stars = T.StarRow.new()
	kitchen_stars.empty_color = T.SAND
	kitchen_stars.custom_minimum_size = Vector2(3 * 22 + 8, 20)
	kitchen_stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kitchen_row.add_child(kitchen_stars)
	kitchen_row.visible = false
	col.add_child(kitchen_row)
	# Ghi chú món của khách (Thứ Ba: "không ớt", "thêm pate"), như mẩu giấy ghim trên phiếu
	order_note = PanelContainer.new()
	order_note.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	order_note.add_theme_stylebox_override("panel", T.box(Color("#F7D35E"), 6, 8, Color(0, 0, 0, 0), 0))
	order_note_label = T.label("", 14, INK, "bold")
	order_note.add_child(order_note_label)
	order_note.visible = false
	col.add_child(order_note)


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
	pause_button = T.icon_button("pause", "Menu (Esc)")
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


func _build_stance() -> void:
	stance_pill = PanelContainer.new()
	stance_pill.add_theme_stylebox_override("panel", T.box(Color(INK, 0.8), 999, 16, Color(0, 0, 0, 0), 0))
	stance_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(stance_pill, 0.5, 1.0, Rect2(-130, -128, 260, 36))
	play_root.add_child(stance_pill)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	stance_pill.add_child(h)
	stance_dot = Panel.new()
	stance_dot.custom_minimum_size = Vector2(14, 14)
	stance_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(stance_dot)
	stance_label = T.label("", 15, PAPER, "bold")
	h.add_child(stance_label)
	stance_pill.visible = false


## Ghi chú món của đơn đang giao trên phiếu ("" để ẩn). ok = false: ráp sai ghi chú, gạch đỏ.
func set_order_note(text: String, ok := true) -> void:
	if order_note == null:
		return
	order_note.visible = text != ""
	order_note_label.text = "Ghi chú: " + text + ("" if ok else " · ráp sai")
	order_note.add_theme_stylebox_override("panel", T.box(Color("#F7D35E") if ok else Color("#F2B8A8"), 6, 8, Color(0, 0, 0, 0), 0))
	order_note_label.add_theme_color_override("font_color", INK if ok else T.RED)


## Số trứng còn nguyên trong túi (Thứ Hai không có: gọi -1 để ẩn). Quả vỡ vẽ nứt và mờ đi.
func set_eggs(left: int, total := 6) -> void:
	if egg_pill == null:
		return
	egg_pill.visible = _playing and left >= 0
	if left < 0:
		return
	if egg_row.get_child_count() != total:
		for c in egg_row.get_children():
			c.free()
		for i in total:
			var e := EggIcon.new()
			e.custom_minimum_size = Vector2(22, 28)
			e.mouse_filter = Control.MOUSE_FILTER_IGNORE
			egg_row.add_child(e)
	for i in total:
		var e: EggIcon = egg_row.get_child(i)
		var broken := i >= left
		if e.broken != broken:
			e.broken = broken
			e.queue_redraw()
	egg_label.text = "Trứng %d/%d" % [left, total]
	egg_label.add_theme_color_override("font_color", PAPER if left > total / 2 else (T.AMBER if left > 0 else T.RED))


## Thẻ mở đầu ngày: tên ngày, một câu tình huống, vài dòng điều mới. Tự tắt sau `seconds` giây.
func show_day_card(title: String, subtitle: String, lines: Array, seconds := 5.0) -> void:
	day_card.get_meta("title").text = title
	day_card.get_meta("sub").text = subtitle
	var box: VBoxContainer = day_card.get_meta("lines")
	for c in box.get_children():
		c.queue_free()
	for l in lines:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel", T.box(T.CRUST, 999, 0, INK, 2))
		h.add_child(dot)
		var lab := T.label(str(l), 17, INK, "bold")
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(lab)
		box.add_child(h)
	_day_time = seconds
	day_card.modulate.a = 1.0
	day_card.visible = seconds > 0.0


func _build_eggs() -> void:
	egg_pill = PanelContainer.new()
	egg_pill.add_theme_stylebox_override("panel", T.box(Color(INK, 0.82), 999, 14, Color(0, 0, 0, 0), 0))
	egg_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(egg_pill, 0.0, 1.0, Rect2(28, -172, 0, 44))
	egg_pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
	play_root.add_child(egg_pill)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	egg_pill.add_child(h)
	egg_label = T.label("", 15, PAPER, "bold")
	egg_label.custom_minimum_size.x = 92
	h.add_child(egg_label)
	egg_row = HBoxContainer.new()
	egg_row.add_theme_constant_override("separation", 3)
	h.add_child(egg_row)
	egg_pill.visible = false


## Bật bản đồ nhỏ cho màn có khu phố (main.gd). Màn bếp, cảnh chung cư không bật thì không hiện.
func enable_minimap(on := true) -> void:
	_minimap_on = on
	if minimap_card:
		minimap_card.visible = on and _playing
	if fps_label:  # dời số FPS xuống dưới bản đồ cho khỏi đè
		_place(fps_label, 1.0, 0.0, Rect2(-260, 346 if on else 92, 232, 24))
	if not InputMap.has_action("ban_do"):
		InputMap.add_action("ban_do", 0.2)
		var k := InputEventKey.new()
		k.physical_keycode = KEY_B
		InputMap.action_add_event("ban_do", k)
		var j := InputEventJoypadButton.new()
		j.button_index = JOY_BUTTON_DPAD_UP
		InputMap.action_add_event("ban_do", j)


## Hiện bản đồ nhỏ cả khi không có thẻ đơn (Thứ Bảy dạo phố tự dựng giao diện riêng, không bật show_playing_ui).
func show_minimap(on := true) -> void:
	if minimap_card:
		minimap_card.visible = on and _minimap_on


## Thẻ giấy bo góc viền mực, bên trong là bản đồ xoay theo camera; dưới đáy có nhãn phím B.
func _build_minimap() -> void:
	minimap_card = Control.new()
	minimap_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(minimap_card, 1.0, 0.0, Rect2(-248, 98, 220, 238))
	minimap_card.visible = false
	play_root.add_child(minimap_card)
	var mask := Panel.new()
	mask.add_theme_stylebox_override("panel", T.box(PAPER, 22, 0, Color(0, 0, 0, 0), 0))
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.position = Vector2.ZERO
	mask.size = Vector2(220, 220)
	minimap_card.add_child(mask)
	minimap = BanDoNho.new()
	minimap.position = Vector2.ZERO
	minimap.size = mask.size
	mask.add_child(minimap)
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", T.box(Color(0, 0, 0, 0), 22, 0, INK, 3))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = mask.size
	minimap_card.add_child(frame)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", T.box(INK, 999, 10, Color(0, 0, 0, 0), 0))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_text := T.label("B · bản đồ lớn", 13, PAPER, "bold")
	chip.add_child(chip_text)
	chip.position = Vector2(56, 206)
	chip.size = Vector2(108, 26)
	minimap_card.add_child(chip)


## Bản đồ lớn: nền mờ, thẻ giấy giữa màn hình, bắc ở trên, có chú thích. Mở thì tạm dừng cho người chơi xem thong thả.
func _build_big_map() -> Control:
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
	_place(card, 0.5, 0.5, Rect2(-520, -330, 1040, 0))
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
	big_map_view = BanDoNho.new()
	big_map_view.full = true
	big_map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.add_child(big_map_view)
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


func toggle_big_map() -> void:
	var open := not big_map.visible
	big_map.visible = open
	get_tree().paused = open
	if open:
		_mouse_before = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = _mouse_before


func _build_day_card() -> void:
	day_card = PanelContainer.new()
	day_card.add_theme_stylebox_override("panel", T.box(PAPER, 22, 26, INK, 4, 8))
	day_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(day_card, 0.5, 0.5, Rect2(-300, -150, 600, 0))
	root.add_child(day_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	day_card.add_child(v)
	v.add_child(T.stripe(10))
	var title := T.label("", 44, INK, "display")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := T.label("", 18, T.MUTED, "bold")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(sub)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 6)
	v.add_child(lines)
	day_card.set_meta("title", title)
	day_card.set_meta("sub", sub)
	day_card.set_meta("lines", lines)
	day_card.visible = false


## Thẻ mẹo lần đầu: nền giấy viền mực ở giữa phía dưới, nhãn "Mẹo", tiêu đề và các phím cần bấm.
func _build_tip() -> void:
	tip_card = PanelContainer.new()
	tip_card.add_theme_stylebox_override("panel", T.box(PAPER, 16, 14, INK, 3, 5))
	tip_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(tip_card, 0.5, 1.0, Rect2(-260, -262, 520, 112))
	play_root.add_child(tip_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", T.box(T.TEAL, 999, 10, Color(0, 0, 0, 0), 0))
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_child(T.label("Mẹo", 13, PAPER, "bold"))
	top.add_child(tag)
	tip_title = T.label("", 20, INK, "display")
	top.add_child(tip_title)
	tip_body = T.label("", 15, T.MUTED, "bold")
	tip_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(tip_body)
	tip_keys = HBoxContainer.new()
	tip_keys.add_theme_constant_override("separation", 6)
	v.add_child(tip_keys)
	tip_card.visible = false


## Hiện một mẹo lần đầu. keys: [[phím, việc], ...], vd [["C", "giữ để chui"]].
func show_tip(title: String, body: String, keys: Array, seconds := 6.0) -> void:
	if tip_card == null:
		return
	tip_title.text = title
	tip_body.text = body
	for c in tip_keys.get_children():
		c.queue_free()
	for k in keys:
		tip_keys.add_child(_keycap(k[0], 14))
		var l := T.label(k[1], 14, INK, "bold")
		tip_keys.add_child(l)
		var gap := Control.new()
		gap.custom_minimum_size.x = 8
		tip_keys.add_child(gap)
	_tip_time = seconds
	tip_card.modulate.a = 1.0
	tip_card.visible = _playing and seconds > 0.0


func _build_hints() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_END
	_place(v, 1.0, 1.0, Rect2(-560, -110, 532, 80))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.add_child(v)
	v.add_child(_key_line([["W A S D", "chạy"], ["Shift", "nhanh"], ["Space", "nhảy"]]))
	v.add_child(_key_line([["V", "góc nhìn"], ["Esc", "menu"], ["F1", "ẩn gợi ý"]]))
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


const HELP_PHO := [["W A S D", "chạy"], ["Shift", "chạy nhanh"], ["Space", "nhảy, nhảy qua Chó Mực"],
	["C", "chui"], ["Z", "rón rén"], ["E", "giao bánh"], ["Chuột", "xoay camera"], ["V", "góc nhìn thứ ba / thứ nhất"]]
const HELP_NOTE_PHO := "Tay cầm: cần trái chạy, A nhảy, Start mở menu. Mũi tên đỏ trên đầu Bơ luôn chỉ về phía khách."


## Menu Esc dùng chung cho phố, bếp và leo chung cư: thẻ giấy giữa màn hình với Tiếp tục, Chơi lại,
## Cài đặt, Chọn màn, Về trang chủ; bên phải là thẻ "Cách chơi" của màn đó.
## Chơi lại phát restart_pressed (màn nào không nối thì tải lại cảnh); Chọn màn phát menu_pressed.
func _build_pause(help := HELP_PHO, note := HELP_NOTE_PHO) -> Control:
	if settings == null:
		settings = SettingsPanel.new()
		settings.visible = false
		root.add_child(settings)
		settings.closed.connect(_on_settings_closed)
	var scr := Control.new()
	scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(INK, 0.72)
	scr.add_child(T.full_rect(dim))

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", T.box(PAPER, 22, 0, INK, 4, 8))
	_place(card, 0.5, 0.5, Rect2(-470, -270, 430, 0))
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
	pause_info = T.label("", 15, T.MUTED, "bold")
	pause_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(pause_info)
	var resume := T.button("  Tiếp tục", "primary", 64, 22)
	resume.pressed.connect(func(): toggle_pause())
	col.add_child(resume)
	_add_key_hint(resume, "Esc", T.ON_CRUST)
	var again := T.button("  Chơi lại", "secondary", 56, 19)
	again.pressed.connect(_on_menu_restart)
	col.add_child(again)
	var st := T.button("  Cài đặt", "secondary", 56, 19)
	st.pressed.connect(func(): settings.open())
	col.add_child(st)
	var pick := T.button("  Chọn màn", "secondary", 56, 19)
	pick.pressed.connect(_on_menu_select)
	col.add_child(pick)
	var home := T.button("  Về trang chủ", "secondary", 56, 19)
	home.pressed.connect(func(): PlayMode.go_home(get_tree()))
	col.add_child(home)
	scr.set_meta("first", resume)

	var helpc := PanelContainer.new()
	helpc.add_theme_stylebox_override("panel", T.box(PAPER, 22, 24, INK, 3, 6))
	_place(helpc, 0.5, 0.5, Rect2(0, -230, 400, 0))
	scr.add_child(helpc)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 9)
	helpc.add_child(hv)
	hv.add_child(T.label("Cách chơi", 26, INK, "display"))
	for line in help:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.add_child(_keycap(line[0], 14))
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


func _on_menu_restart() -> void:
	if restart_pressed.get_connections().is_empty():
		get_tree().paused = false
		get_tree().reload_current_scene()
	else:
		restart_pressed.emit()


func _on_menu_select() -> void:
	if menu_pressed.get_connections().is_empty():
		PlayMode.back_to_menu(get_tree())
	else:
		menu_pressed.emit()


func _add_key_hint(btn: Button, text: String, color: Color) -> void:
	var l := T.label(text, 14, color, "bold")
	l.modulate.a = 0.7
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(l, 1.0, 0.5, Rect2(-90, -10, 70, 20))
	btn.add_child(l)


const RANKS := {
	"thuong": ["Bánh mì thường", "#E7DCC4", 1],
	"gion": ["Bánh mì giòn", "#D98E2B", 2],
	"vang": ["Bánh mì vàng", "#F7D35E", 3],
}


## 85000 -> "85.000đ"
static func money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if v < 0 else "") + s + out + "đ"


func _build_results(rows: Array, summary := {}) -> Control:
	var scr := Control.new()
	scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = T.TEAL
	scr.add_child(T.full_rect(bg))

	var total := 0
	var on_time := 0
	var has_tip := summary.has("tip")
	for r in rows:
		total += int(r.stars)
		on_time += 1 if r.stars > 0 and not r.get("late", false) else 0
		has_tip = has_tip or r.has("tip")
	total = int(summary.get("stars", total))
	var stars_max := int(summary.get("stars_max", 15))
	# Hạng ngày: luồng chấm điểm gửi sẵn; thiếu thì tự tính theo cùng ngưỡng (<8, 8–12, ≥13)
	var rank: String = summary.get("rank", "vang" if total >= 13 else ("gion" if total >= 8 else "thuong"))
	var rk: Array = RANKS.get(rank, RANKS.thuong)

	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 8)
	_place(left, 0.5, 0.5, Rect2(-600, -330, 436, 660))
	scr.add_child(left)
	var day: String = summary.get("day", "")
	var title := T.label("Hết ca %s!" % day if day != "" else "Hết ca giao bánh!", 46, PAPER, "display")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(title)
	var big := T.StarRow.new()
	big.filled = rk[2]
	big.empty_color = Color("#256569")
	big.custom_minimum_size = Vector2(3 * 72 + 8, 68)
	big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(big)
	# Huy chương hạng ngày
	var medal := PanelContainer.new()
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	medal.add_theme_stylebox_override("panel", T.box(Color(rk[1]), 999, 22, INK, 3, 5))
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 12)
	medal.add_child(mh)
	var loaf := LoafIcon.new()
	loaf.state = "done"
	loaf.custom_minimum_size = Vector2(44, 28)
	loaf.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mh.add_child(loaf)
	mh.add_child(T.label(rk[0], 24, T.ON_CRUST if rank != "thuong" else INK, "display"))
	left.add_child(medal)
	var tl := T.label("%d / %d sao" % [total, stars_max], 30, T.AMBER, "display")
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(tl)
	if summary.get("new_record", false):
		var rec := PanelContainer.new()
		rec.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rec.add_theme_stylebox_override("panel", T.box(RED, 999, 14, PAPER, 2))
		rec.add_child(T.label("Kỷ lục mới!", 15, PAPER, "bold"))
		left.add_child(rec)

	# Thẻ tiền boa
	if has_tip:
		var tip_total := int(summary.get("tip", 0))
		if not summary.has("tip"):
			for r in rows:
				tip_total += int(r.get("tip", 0))
		var tc := PanelContainer.new()
		tc.add_theme_stylebox_override("panel", T.box(PAPER, 20, 16, INK, 3, 6))
		tc.custom_minimum_size.x = 340
		tc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 2)
		tc.add_child(tv)
		var th := HBoxContainer.new()
		th.add_child(T.label("Tiền boa hôm nay", 16, T.MUTED, "bold"))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		th.add_child(sp)
		th.add_child(T.label(money(tip_total), 30, T.LEAF, "display"))
		tv.add_child(th)
		var bonus := int(summary.get("bonus", 0))
		if bonus > 0:
			tv.add_child(T.label("Gồm %s Cô Ba thưởng vì đủ %d sao" % [money(bonus), stars_max], 13, CRUST, "bold"))
		elif summary.has("bonus"):
			tv.add_child(T.label("Đủ %d sao thì Cô Ba thưởng thêm %s" % [stars_max, money(20000)], 13, T.MUTED, "bold"))
		if summary.has("wallet"):
			tv.add_child(T.label("Trong ví: %s · dùng mở đồ trong tủ" % money(int(summary.wallet)), 13, T.MUTED, "body"))
		left.add_child(tc)
	else:
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", T.box(Color("#8DBDB3"), 24, 0, INK, 4))
		frame.custom_minimum_size = Vector2(300, 200)
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
	panel.add_theme_stylebox_override("panel", T.box(PAPER, 26, 24, INK, 4, 8))
	_place(panel, 0.5, 0.5, Rect2(-128, -330, 728, 660))
	scr.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	v.add_child(T.label(summary.get("rows_title", "Năm đơn sáng nay"), 28, INK, "display"))
	for i in rows.size():
		v.add_child(_result_row(rows[i], i, has_tip))

	# Huy hiệu nhiệm vụ phụ và tem Cô Ba
	var quests := 0
	var quests_ok := 0
	for r in rows:
		if str(r.get("side_quest", "")) != "":
			quests += 1
			quests_ok += 1 if r.get("side_ok", false) else 0
	if quests > 0 or summary.has("stamps"):
		var strip := HBoxContainer.new()
		strip.add_theme_constant_override("separation", 10)
		if quests > 0:
			strip.add_child(_mini_panel("Huy hiệu", "%d/%d" % [quests_ok, quests], _badge_row(rows)))
		if summary.has("stamps"):
			var n := int(summary.stamps)
			var of := int(summary.get("stamps_total", 5))
			var stamps := HBoxContainer.new()
			stamps.add_theme_constant_override("separation", 4)
			for k in of:
				var st := StampIcon.new()
				st.found = k < n
				st.custom_minimum_size = Vector2(30, 24)
				stamps.add_child(st)
			var sub := "%d/%d" % [n, of]
			if summary.has("stamps_all"):
				sub += " · tổng %d/35" % int(summary.stamps_all)
			strip.add_child(_mini_panel("Tem Cô Ba", sub, stamps))
		v.add_child(strip)

	var unlock := PanelContainer.new()
	var us := T.box(Color(0, 0, 0, 0), 14, 10, CRUST, 3)
	unlock.add_theme_stylebox_override("panel", us)
	var uh := HBoxContainer.new()
	uh.add_theme_constant_override("separation", 14)
	unlock.add_child(uh)
	var uv := VBoxContainer.new()
	uv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var need := rows.size() - on_time
	uv.add_child(T.label("Đã mở skin Vỏ Bánh Giòn!" if need == 0 else "Còn %d đơn kịp giờ nữa là mở skin Vỏ Bánh Giòn" % need, 15, INK, "bold"))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
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
	# Chơi liền các ngày: Enter sang ngày kế, Chơi lại ca thành nút phụ, Về menu về thẳng trang chủ.
	var first: Button
	if PlayMode.continuous:
		var next := T.button("  " + PlayMode.next_label(), "primary", 58, 20)
		next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		next.pressed.connect(func(): PlayMode.go_next_day(get_tree()))
		_add_key_hint(next, "Enter", T.ON_CRUST)
		foot.add_child(next)
		first = next
	var again := T.button("  Chơi lại ca", "secondary" if PlayMode.continuous else "primary", 58, 20)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func(): restart_pressed.emit())
	if not PlayMode.continuous:
		_add_key_hint(again, "Enter", T.ON_CRUST)
		first = again
	foot.add_child(again)
	var home := T.button("Về menu", "secondary", 58, 20)
	if PlayMode.continuous:
		home.pressed.connect(func(): PlayMode.go_home(get_tree()))
	else:
		home.pressed.connect(func(): menu_pressed.emit())
	foot.add_child(home)
	first.grab_focus.call_deferred()
	return scr


func _mini_panel(title: String, count: String, content: Control) -> Control:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", T.box(Color("#F6EDDA"), 14, 10, Color(0, 0, 0, 0), 0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.add_child(T.label(title, 13, T.MUTED, "bold"))
	col.add_child(T.label(count, 17, INK, "display"))
	h.add_child(col)
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(content)
	return p


func _badge_row(rows: Array) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	for r in rows:
		var q := str(r.get("side_quest", ""))
		if q == "":
			continue
		var b := BadgeIcon.new()
		b.earned = r.get("side_ok", false)
		b.custom_minimum_size = Vector2(26, 26)
		b.tooltip_text = q
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(b)
	return h


func _result_row(r: Dictionary, i: int, show_tip := false) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.box(Color("#F6EDDA") if i % 2 == 0 else Color(0, 0, 0, 0), 14, 10, Color(0, 0, 0, 0), 0))
	p.custom_minimum_size.y = 56
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
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
	var name_l := T.label("%s · %s" % [who, r.get("place", "")], 16, INK, "bold")
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_l)
	var line2 := HBoxContainer.new()
	line2.add_theme_constant_override("separation", 5)
	var sub := T.label(str(r.get("item", "")), 13, Color("#2C4F52"))
	line2.add_child(sub)
	if r.has("kitchen_stars"):
		line2.add_child(T.label("· bếp", 13, Color("#2C4F52")))
		var ks := T.StarRow.new()
		ks.filled = int(r.kitchen_stars)
		ks.empty_color = T.SAND
		ks.custom_minimum_size = Vector2(3 * 18 + 8, 16)
		ks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line2.add_child(ks)
	var note := str(r.get("note", ""))
	if note != "":
		var nl := T.label("· " + note, 13, Color("#2C4F52"))
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.clip_text = true
		line2.add_child(nl)
	col.add_child(line2)
	h.add_child(col)
	var q := str(r.get("side_quest", ""))
	if q != "":
		var b := BadgeIcon.new()
		b.earned = r.get("side_ok", false)
		b.custom_minimum_size = Vector2(30, 30)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.tooltip_text = ("Đạt: " if b.earned else "Chưa đạt: ") + q
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(b)
	var stars: int = r.get("stars", 0)
	var late: bool = r.get("late", stars == 0)
	var tag := PanelContainer.new()
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_theme_stylebox_override("panel", T.box(RED if late else T.LEAF, 999, 10, Color(0, 0, 0, 0), 0))
	tag.add_child(T.label("Trễ" if late else "Kịp giờ", 12, PAPER, "bold"))
	h.add_child(tag)
	var sr := T.StarRow.new()
	sr.filled = stars
	sr.empty_color = T.SAND
	sr.custom_minimum_size = Vector2(3 * 26 + 8, 24)
	sr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sr)
	if show_tip:
		var tip := int(r.get("tip", 0))
		var tl := T.label(("+" + money(tip)) if tip > 0 else "0đ", 15, T.LEAF if tip > 0 else Color("#A89C80"), "display")
		tl.custom_minimum_size.x = 76
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(tl)
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


## Huy hiệu nhiệm vụ phụ: khiên tròn, đạt thì vàng có dấu tích, chưa đạt thì xám rỗng.
class BadgeIcon:
	extends Control
	var earned := false
	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.5 - 2.0
		var ribbon := PackedVector2Array([c + Vector2(-r * 0.6, r * 0.2), c + Vector2(-r * 0.75, r + 2), c + Vector2(-r * 0.2, r * 0.75),
			c + Vector2(r * 0.2, r * 0.75), c + Vector2(r * 0.75, r + 2), c + Vector2(r * 0.6, r * 0.2)])
		draw_colored_polygon(ribbon, UiTheme.RED if earned else Color("#C9BFA8"))
		draw_circle(c + Vector2(0, -1), r * 0.82, UiTheme.AMBER if earned else UiTheme.SAND)
		draw_arc(c + Vector2(0, -1), r * 0.82, 0, TAU, 24, UiTheme.INK, 2.0, true)
		if earned:
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.35, -1), c + Vector2(-r * 0.08, r * 0.28 - 1), c + Vector2(r * 0.4, -r * 0.32 - 1)]), UiTheme.INK, 2.5, true)


## Tem Cô Ba: ổ bánh có nơ đỏ trên con tem răng cưa. Chưa nhặt thì chỉ còn viền mờ.
class StampIcon:
	extends Control
	var found := false
	func _draw() -> void:
		var rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		var col := UiTheme.PAPER if found else Color(1, 1, 1, 0.0)
		draw_rect(rect, col)
		var edge := UiTheme.INK if found else Color("#B5A88A")
		draw_rect(rect, edge, false, 1.5)
		for x in range(4, int(size.x) - 3, 5):
			draw_circle(Vector2(x, 2), 1.3, Color("#F6EDDA"))
			draw_circle(Vector2(x, size.y - 2), 1.3, Color("#F6EDDA"))
		var c := size / 2.0 + Vector2(0, 1)
		var loaf := PackedVector2Array()
		for k in 16:
			var a := TAU * k / 16.0
			loaf.append(c + Vector2(cos(a) * size.x * 0.3, sin(a) * size.y * 0.2))
		draw_colored_polygon(loaf, UiTheme.CRUST if found else Color("#D9CFB8"))
		if found:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -2), c + Vector2(-5, -6), c + Vector2(-5, 2)]), UiTheme.RED)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -2), c + Vector2(5, -6), c + Vector2(5, 2)]), UiTheme.RED)


## Quả trứng nhỏ cho chỉ báo số trứng: trứng nguyên màu kem, trứng vỡ nứt đôi, lòng đỏ chảy ra.
class EggIcon:
	extends Control
	var broken := false

	func _draw() -> void:
		var c := size / 2.0
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			var r := Vector2(size.x * 0.42, size.y * 0.46)
			var squash := 1.0 - 0.18 * maxf(0.0, sin(a))  # đầu dưới tròn hơn, đầu trên thon
			pts.append(c + Vector2(cos(a) * r.x * squash, sin(a) * r.y))
		var ink := UiTheme.INK
		if broken:
			draw_circle(c + Vector2(0, size.y * 0.22), size.x * 0.32, Color(UiTheme.AMBER, 0.75))
			draw_colored_polygon(pts, Color("#CFC6B4"))
			var crack := PackedVector2Array([c + Vector2(-size.x * 0.4, -2), c + Vector2(-size.x * 0.15, 3),
				c + Vector2(0, -3), c + Vector2(size.x * 0.17, 3), c + Vector2(size.x * 0.4, -2)])
			draw_polyline(crack, ink, 1.8, true)
		else:
			draw_colored_polygon(pts, Color("#FFF4DC"))
			draw_circle(c + Vector2(-size.x * 0.12, -size.y * 0.16), size.x * 0.08, Color(1, 1, 1, 0.9))
		pts.append(pts[0])
		draw_polyline(pts, ink, 2.0, true)
