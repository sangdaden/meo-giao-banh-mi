extends CanvasLayer
## Giao diện màn giao bánh theo bản phác thảo Sang duyệt (artboard 5, 6, 8):
## thẻ đơn, đồng hồ, 5 ổ bánh tiến độ, túi bánh còn nóng, khoảng cách, mũi tên ở mép màn hình,
## gợi ý phím, và các màn phủ: tạm dừng, cài đặt, kết quả ca.
## Màn hình chính nằm riêng ở scenes/menu.tscn.
## Các mảnh lớn nằm ở file riêng trong scripts/ui/: hud_ket_qua.gd (bảng kết quả), hud_tam_dung.gd (menu Esc),
## hud_ban_do.gd (bản đồ nhỏ/lớn), hud_trung.gd (số trứng), hud_hinh.gd (hình vẽ nhỏ). Giao diện riêng của một ngày
## là mảnh khai ở scripts/ngay/<ngày>.gd (khóa "hud"), gắn qua add_piece(); đừng thêm vào file này.
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
var order_label: Label      # dòng tên khách · nơi giao (thẻ gọn: một dòng, dư thì "…")
var order_detail: Label
var order_chip: Label
var order_more: VBoxContainer   # phần chỉ hiện khi thẻ mở đủ: món, sao bếp, ghi chú món
var _card_pinned := false       # Tab mở đủ thẻ đơn (bấm lại thì gọn)
var _card_open_t := 0.0         # sang đơn mới: thẻ tự mở đủ thêm chừng này giây
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
var edge_arrow: HudHinh.EdgeArrow
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
## Bảng "Cách chơi" riêng của ngày (main.gd đặt từ khóa help, help_note của scripts/ngay/<ngày>.gd trước khi thêm HUD).
## Rỗng thì dùng bảng chung HELP_PHO, HELP_NOTE_PHO.
var help: Array = []
var help_note := ""


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

	edge_arrow = HudHinh.EdgeArrow.new()
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

	pause_screen = _build_pause(HELP_PHO if help.is_empty() else help, HELP_NOTE_PHO if help_note == "" else help_note)
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
	_step_order_card(delta)
	if edge_arrow == null:
		return
	edge_arrow.visible = _playing and _has_goal
	if edge_arrow.visible:
		edge_arrow.update_goal(get_viewport().get_camera_3d(), _goal)


# ------------------------------------------------------------ API cho main.gd

## Gắn một mảnh giao diện riêng của ngày (khóa "hud" trong scripts/ngay/<ngày>.gd) vào lớp chơi.
## Mảnh là Control có biến hud (được gán HUD này) và tự lo ẩn hiện; ngày mới thêm giao diện bằng mảnh
## riêng thay vì sửa hud.gd.
func add_piece(piece: Node) -> void:
	if "hud" in piece:
		piece.set("hud", self)
	play_root.add_child(piece)


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
	if order_more and title != order_label.text:
		_card_open_t = ChuHuongDan.THE_MO_GIAY  # việc mới (đổi nơi tới): mở đủ vài giây cho thấy món rồi gọn lại
	order_chip.text = "Đơn %d/%d" % [index + 1, total]
	order_label.text = title
	order_detail.text = detail
	_set_dot_count(total)
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
		var d: HudHinh.LoafIcon = dots[i]
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
			if info == "" and order_chip and _playing:  # ngày tự do không có thẻ đơn: đừng ghi "Đơn 1/5"
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


## Thẻ đơn góc trái, gọn một dòng (Sang 22/10: thẻ cũ 3 dòng che phố lúc leo): hình khách, số đơn, tên · nơi giao, phím Tab.
## Tab (tay cầm: Back) mở đủ: món, sao bếp của ổ, ghi chú món. Sang đơn mới thẻ tự mở đủ ChuHuongDan.THE_MO_GIAY giây.
func _build_order_card() -> void:
	order_card = _card()
	_place(order_card, 0.0, 0.0, Rect2(28, 24, 360, 0))
	order_card.custom_minimum_size.x = 360  # chữ một dòng tự co về 0 nên giữ bề ngang thẻ
	play_root.add_child(order_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	order_card.add_child(v)
	var stripe := T.stripe(8)
	v.add_child(stripe)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 12)
	m.add_theme_constant_override("margin_top", 7)
	m.add_theme_constant_override("margin_bottom", 8)
	v.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	m.add_child(h)
	avatar = Panel.new()
	avatar.custom_minimum_size = Vector2(40, 40)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	avatar.add_theme_stylebox_override("panel", T.box(T.CRUST, 999, 0, INK, 3))
	h.add_child(avatar)
	avatar_label = T.label("?", 20, INK, "display")
	avatar_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(avatar_label)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.custom_minimum_size.y = 40
	col.add_child(top)
	var chip := PanelContainer.new()
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", T.box(INK, 999, 8, Color(0, 0, 0, 0), 0))
	order_chip = T.label("Đơn 1/5", 13, PAPER, "bold")
	chip.add_child(order_chip)
	top.add_child(chip)
	order_label = T.label("", 17, INK, "bold")
	order_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	order_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	order_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	order_label.clip_text = true
	top.add_child(order_label)
	var key := _keycap(ChuHuongDan.PHIM_THE, 12)
	key.modulate.a = 0.75
	top.add_child(key)
	order_more = VBoxContainer.new()
	order_more.add_theme_constant_override("separation", 2)
	order_more.visible = false
	col.add_child(order_more)
	order_detail = T.label("", 15, Color("#2C4F52"))
	order_detail.autowrap_mode = TextServer.AUTOWRAP_WORD
	order_detail.custom_minimum_size.x = 270  # chữ xuống dòng cần bề ngang sẵn, không thì thẻ cao vọt
	order_more.add_child(order_detail)
	kitchen_row = HBoxContainer.new()
	kitchen_row.add_theme_constant_override("separation", 6)
	kitchen_row.add_child(T.label("Ổ từ bếp", 13, T.MUTED, "bold"))
	kitchen_stars = T.StarRow.new()
	kitchen_stars.empty_color = T.SAND
	kitchen_stars.custom_minimum_size = Vector2(3 * 22 + 8, 20)
	kitchen_stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kitchen_row.add_child(kitchen_stars)
	kitchen_row.visible = false
	order_more.add_child(kitchen_row)
	# Ghi chú món của khách (Thứ Ba: "không ớt", "thêm pate"), như mẩu giấy ghim trên phiếu
	order_note = PanelContainer.new()
	order_note.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	order_note.add_theme_stylebox_override("panel", T.box(Color("#F7D35E"), 6, 8, Color(0, 0, 0, 0), 0))
	order_note_label = T.label("", 14, INK, "bold")
	order_note.add_child(order_note_label)
	order_note.visible = false
	order_more.add_child(order_note)
	if not InputMap.has_action("the_nhiem_vu"):
		InputMap.add_action("the_nhiem_vu", 0.2)
		var k := InputEventKey.new()
		k.physical_keycode = KEY_TAB
		InputMap.action_add_event("the_nhiem_vu", k)
		var j := InputEventJoypadButton.new()
		j.button_index = JOY_BUTTON_BACK
		InputMap.action_add_event("the_nhiem_vu", j)


## Tab mở/gọn thẻ đơn; hết giờ tự mở thì gọn lại.
func _step_order_card(delta: float) -> void:
	if order_more == null:
		return
	if _card_open_t > 0.0:
		_card_open_t -= delta
	if _playing and not get_tree().paused and InputMap.has_action("the_nhiem_vu") and Input.is_action_just_pressed("the_nhiem_vu"):
		var was_open := _card_pinned or _card_open_t > 0.0
		_card_pinned = not was_open
		_card_open_t = 0.0
	var open := _card_pinned or _card_open_t > 0.0
	if order_more.visible != open:
		order_more.visible = open
		order_label.clip_text = not open  # mở đủ: hiện hết tên, thẻ nở ngang theo chữ
		order_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING if open else TextServer.OVERRUN_TRIM_ELLIPSIS
		order_card.reset_size()  # gọn lại thì thẻ co về một dòng


## Số ổ tiến độ góc phải theo số đơn của ngày (Chủ Nhật 1 đơn, Thứ Sáu Thử thách 6 đơn).
func _set_dot_count(total: int) -> void:
	if dots.is_empty() or total <= 0:
		return
	var row: HBoxContainer = dots[0].get_parent()
	while dots.size() < total:
		var d := HudHinh.LoafIcon.new()
		d.custom_minimum_size = Vector2(40, 26)
		row.add_child(d)
		dots.append(d)
	for i in dots.size():
		dots[i].visible = i < total


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
		var d := HudHinh.LoafIcon.new()
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
	var icon := HudHinh.BagIcon.new()
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


## Số trứng còn nguyên trong túi (Thứ Hai không có: gọi -1 để ẩn): scripts/ui/hud_trung.gd
func set_eggs(left: int, total := 6) -> void:
	HudTrung.set_eggs(self, left, total)


func _build_eggs() -> void:
	HudTrung.build(self)


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


## Bản đồ nhỏ và bản đồ lớn: scripts/ui/hud_ban_do.gd
func _build_minimap() -> void:
	HudBanDo.build_minimap(self)


func _build_big_map() -> Control:
	return HudBanDo.build_big_map(self)


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
	for line: Array in ChuHuongDan.DAY_PHIM:
		v.add_child(_key_line(line))
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
	return T.keycap(text, size)




const HELP_PHO := HudTamDung.HELP_PHO
const HELP_NOTE_PHO := HudTamDung.HELP_NOTE_PHO


## Menu Esc: scripts/ui/hud_tam_dung.gd
func _build_pause(help_lines := HELP_PHO, note := HELP_NOTE_PHO) -> Control:
	return HudTamDung.build(self, help_lines, note)


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


## Bảng kết quả: scripts/ui/hud_ket_qua.gd
const RANKS := HudKetQua.RANKS


## 85000 -> "85.000đ"
static func money(v: int) -> String:
	return HudKetQua.money(v)


func _build_results(rows: Array, summary := {}) -> Control:
	return HudKetQua.build(self, rows, summary)


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
