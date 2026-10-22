extends TroThi
## Trò 5 · Thi trang phục trước sân khấu. Bà Mướp bốc 1 trong 3 chủ đề, Bơ chọn tối đa 3 món,
## lên sân khấu tạo 3 dáng (chup_vay, chup_nam, chup_dung), 4 giám khảo giơ bảng 1–5.
## Thong thả: được MƯỢN món chưa mua cho cuộc thi, thi xong trả lại (costume_borrow); món hợp chủ đề có dấu gợi ý.
## Thử thách: chỉ dùng món đã có.

const THEMES := {
	"đi biển": ["kinhram", "hoadambut", "vonghoa", "phaovit", "deptoong"],
	"ngày Tết": ["canhmai", "khanlen", "baolixi", "denlong", "nonla"],
	"siêu anh hùng": ["aochoang", "bitmat", "kinhphicong", "bangdo", "coduua"],
}
const OTHERS := ["mudaubep", "munlen", "nobuom", "mubaohiem", "khautrang", "riamep", "nonsinhnhat", "tatsoc"]
const JUDGES := ["ba_muop", "tuyet", "lac", "mit"]
## Điểm trung bình của mèo khác (Tuyết điệu đà nhất)
const RIVALS := {"tuyet": 4.25, "mit": 3.5, "lac": 3.0}
const POSES := ["chup_vay", "chup_nam", "chup_dung"]
const MAX_PICK := 3

var theme := ""
var picked: Array[String] = []
var scores: Array[int] = []
var _ui: CanvasLayer
var _phase := ""         ## chon | dang | cham | xong
var _t := 0.0
var _boards: Array[Label3D] = []
var _buttons := {}
var _go_btn: Button


func title() -> String:
	return "Thi trang phục"


func rule() -> String:
	return "Bà Mướp ra chủ đề, Bơ chọn đồ trong tủ, lên sân khấu tạo 3 dáng."


func begin() -> void:
	theme = THEMES.keys()[randi() % THEMES.size()]
	picked.clear()
	scores.clear()
	cat("ba_muop").say("Chủ đề: %s!" % theme, 4.0)
	put_player(ChuNhat.STAGE + Vector3(0, 0, -2.6), ChuNhat.STAGE)
	player.can_move = false
	_phase = "chon"
	_build_ui()
	if not autotest:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _borrow() -> bool:
	return bool(DoKho.v("costume_borrow", false))


func _usable(id: String) -> bool:
	return OutfitView.has_model(id) and (_borrow() or Shop.owned(id))


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 0)
	panel.position = Vector2(-280, -230)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFF8EA")
	sb.border_color = Color("#3A2418")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	_ui.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(_text("Thi trang phục · chủ đề \"%s\"" % theme, 26))
	v.add_child(_text("Chọn tối đa %d món. %s" % [MAX_PICK, "Món chưa có được mượn, thi xong trả lại." if _borrow() else "Chỉ dùng đồ đã có."], 16))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var list: Array = THEMES[theme] + OTHERS.slice(0, 5)
	for id: String in list:
		var a := Outfit.acc(id)
		if a.is_empty():
			continue
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(250, 40)
		var hint := " ★" if id in THEMES[theme] and _borrow() else ""
		var tag := "" if Shop.owned(id) else (" (mượn)" if _borrow() else " (chưa có)")
		b.text = "%s%s%s" % [a[1], tag, hint]
		b.disabled = not _usable(id)
		b.toggled.connect(_on_pick.bind(id))
		grid.add_child(b)
		_buttons[id] = b
	_go_btn = Button.new()
	_go_btn.text = "Lên sân khấu"
	_go_btn.custom_minimum_size = Vector2(0, 46)
	_go_btn.pressed.connect(_to_stage)
	v.add_child(_go_btn)


func _text(t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#3A2418"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _on_pick(on: bool, id: String) -> void:
	if on:
		# Một ô một món: bỏ món cùng ô đang chọn
		var slot: String = Outfit.acc(id)[3]
		for other in picked.duplicate():
			if Outfit.acc(other)[3] == slot:
				picked.erase(other)
				_buttons[other].set_pressed_no_signal(false)
		if picked.size() >= MAX_PICK:
			_buttons[id].set_pressed_no_signal(false)
			return
		picked.append(id)
	else:
		picked.erase(id)
	_wear()


func _wear() -> void:
	var worn := {}
	for id in picked:
		worn[Outfit.acc(id)[3]] = id
	if worn.is_empty():
		worn = {"neck": "khando"}
	player.apply_outfit(worn)


func _to_stage() -> void:
	if _ui:
		_ui.queue_free()
		_ui = null
	if not autotest:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	put_player(ChuNhat.STAGE + Vector3(0, ChuNhat.STAGE_H, 0), ChuNhat.STAGE + Vector3(0, 0, -5))
	_phase = "dang"
	_t = 0.0
	toast("Tạo dáng nào!", 2.0)


func tick(delta: float) -> void:
	_t += delta
	match _phase:
		"chon":
			if autotest and _t > 0.3:
				for id in THEMES[theme]:
					if _usable(id) and picked.size() < MAX_PICK:
						_buttons[id].button_pressed = true
				_to_stage()
		"dang":
			var k := int(_t / 1.8)
			if k < POSES.size():
				if player.clip != POSES[k]:
					player.play_clip(POSES[k])
			else:
				player.stop_clip()
				_score()
		"cham":
			if _t > 3.0:
				_end()


func _score() -> void:
	_phase = "cham"
	_t = 0.0
	var match_n := 0
	for id in picked:
		if id in THEMES[theme]:
			match_n += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(theme + ",".join(picked))
	for j in JUDGES.size():
		var s := clampi(2 + match_n + (rng.randi_range(-1, 0) if match_n < 3 else rng.randi_range(0, 1)) + (1 if picked.size() > 0 else 0), 1, 5)
		scores.append(s)
		var m := cat(JUDGES[j])
		var lb := Label3D.new()
		lb.text = str(s)
		lb.font_size = 140
		lb.outline_size = 18
		lb.modulate = Color("#C8412F")
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.pixel_size = 0.004
		m.add_child(lb)
		lb.position = Vector3(0, 0.9, 0)
		_boards.append(lb)
		if JUDGES[j] == "ba_muop":
			m.set_pose("noi")  # bà ngồi thùng gỗ đọc điểm
		else:
			m.play("gio_bang")
	toast("Giám khảo chấm: %s" % " · ".join(scores.map(func(x): return str(x))), 3.0)


func _end() -> void:
	var avg := 0.0
	for s in scores:
		avg += s
	avg /= maxf(scores.size(), 1.0)
	var rank := 1
	for r in RIVALS.values():
		if r > avg:
			rank += 1
	cat("ba_muop").set_pose("ngoi_cao")
	for b in _boards:
		b.queue_free()
	_boards.clear()
	player.apply_outfit()  # trả đồ mượn, mặc lại đồ của tủ
	player.can_move = true
	_phase = "xong"
	finish(mini(rank, 4), "chủ đề %s, %.1f điểm" % [theme, avg])


func goal() -> Vector3:
	return Vector3.INF


func status() -> String:
	match _phase:
		"chon":
			return "Chủ đề \"%s\" · chọn đồ (%d/%d)" % [theme, picked.size(), MAX_PICK]
		"dang":
			return "Đang tạo dáng"
	return "Giám khảo đang chấm"
