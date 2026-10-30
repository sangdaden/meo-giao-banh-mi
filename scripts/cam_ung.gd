class_name CamUng
extends CanvasLayer
## G3: chơi bằng màn hình cảm ứng (điện thoại, máy tính bảng). Autoload tên "NutCamUng", khai trong project.godot.
##
## Chỉ hiện khi máy có màn cảm ứng (hoặc vừa chạm màn hình) và đang chơi (cảnh có Bơ, không tạm dừng).
## Bấm một phím trên bàn phím thì ẩn, chạm lại thì hiện.
##   nửa trái màn hình: cần đi (chạm chỗ nào thì cần hiện ở đó); đẩy sát mép là chạy nhanh
##   nửa phải: các nút việc (Nhảy, Giao, Chui, Meo, Tự đi; trong bếp: Làm, Tự đi); vuốt chỗ trống là xoay camera
## Nút gửi đúng hành động trong InputMap (Input.parse_input_event), nên code chơi không phải đổi gì.
## Ngón không chạm cần/nút thì thành chuột trái (menu, nút bấm, vuốt trong bếp), xem _chuot().
## Thử trên máy tính: chạy với tham số -- --cam-ung

## true khi đang dùng cảm ứng (camera_rig bỏ qua chuột giả từ ngón tay, vì vuốt đã xoay camera ở đây).
static var bat := false

const CAN_R := 90.0          ## bán kính cần đi (theo màn cao 720)
const CHAY_NHANH := 0.92     ## đẩy cần quá chừng này là chạy nhanh
const XOAY := 0.006          ## độ nhạy vuốt xoay camera

## [hành động, chữ, bán kính, vị trí tính từ góc dưới phải (theo màn cao 720)]
const NUT_PHO := [
	["jump", "Nhảy", 64.0, Vector2(120, 130)],
	["deliver", "Giao", 50.0, Vector2(265, 90)],
	["crouch", "Chui", 42.0, Vector2(110, 290)],
	["goi", "Meo", 38.0, Vector2(245, 235)],
	["tu_di_pho", "Tự đi", 34.0, Vector2(370, 80)],
]
const NUT_BEP := [
	["interact", "Làm", 70.0, Vector2(130, 140)],
	["tu_di", "Tự đi", 44.0, Vector2(280, 90)],
]

var _ve: Control
var _hien := false
var _ngon := {}               ## index ngón -> "can" (cần đi) / tên hành động
var _cam_i := -1              ## ngón đang vuốt xoay camera
var _chuot_i := -1            ## ngón đang làm chuột
var _goc_can := Vector2.ZERO  ## tâm cần đi lúc đang giữ
var _can := Vector2.ZERO      ## hướng cần đi (-1..1)
var _nut: Array = []          ## [hành động, chữ, tâm, bán kính] đang hiện
var _bep := false
var _gia_phim: Array = []     ## phím vừa gửi thay cho nút, chưa tới _input


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ve = Control.new()
	_ve.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ve.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ve.draw.connect(_draw_nut)
	add_child(_ve)
	bat = DisplayServer.is_touchscreen_available() or "--cam-ung" in OS.get_cmdline_user_args()
	visible = false


func _process(_delta: float) -> void:
	var muon := bat and _dang_choi()
	if muon != _hien:
		_hien = muon
		visible = muon
		if not muon:
			_tha_het()
		_an_goi_y_phim(muon)
	if not _hien:
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # chạm màn hình không khóa chuột
	_xep_nut()
	_ve.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var gia := _gia_phim.find(event)
		if gia >= 0:
			_gia_phim.remove_at(gia)
		elif event.pressed:
			bat = false
		return
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	bat = true
	var p: Vector2 = event.position
	var i: int = event.index
	if event is InputEventScreenTouch and event.pressed:
		if _hien and _cham(i, p):
			get_viewport().set_input_as_handled()
			return
		if _chuot_i < 0:
			_chuot_i = i
			_chuot.call_deferred(p, Vector2.ZERO, true, true)
		if _hien and not _bep and _cam_i < 0 and p.x >= _man().x * 0.45:
			_cam_i = i
	elif event is InputEventScreenTouch:
		if _ngon.has(i):
			_tha(i)
			get_viewport().set_input_as_handled()
		if i == _cam_i:
			_cam_i = -1
		if i == _chuot_i:
			_chuot_i = -1
			_chuot.call_deferred(p, Vector2.ZERO, true, false)
	else:
		if _ngon.get(i, "") == "can":
			_dat_can(p)
			get_viewport().set_input_as_handled()
			return
		if i == _cam_i:
			var rig = _camera()
			if rig:
				rig.xoay(event.relative, XOAY / _k())
		if i == _chuot_i:
			_chuot.call_deferred(p, event.relative, false, true)


## Chạm trúng cần đi hay một nút việc thì giữ ngón đó lại (không thành chuột).
func _cham(i: int, p: Vector2) -> bool:
	for n in _nut:
		if p.distance_to(n[2]) <= n[3] * 1.15:
			_ngon[i] = n[0]
			_gui.call_deferred(n[0], true)
			return true
	var vs := _man()
	if p.x < vs.x * 0.45 and p.y > vs.y * 0.22 and not _ngon.values().has("can"):
		_ngon[i] = "can"
		_goc_can = p
		_dat_can(p)
		return true
	return false


func _tha(i: int) -> void:
	var v = _ngon.get(i, "")
	_ngon.erase(i)
	if v == "can":
		_can = Vector2.ZERO
		_dat_di()
	elif v != "":
		_gui.call_deferred(v, false)


func _tha_het() -> void:
	for i in _ngon.keys():
		_tha(i)
	_ngon.clear()
	_cam_i = -1


## Ngón còn lại thành chuột trái (menu, nút, vuốt trong bếp). Tắt chuột giả sẵn của Godot
## (input_devices/pointing/emulate_mouse_from_touch=false) để ngón giữ cần đi không thành cú bấm chuột.
## p là tọa độ trong khung game; Input.parse_input_event cần tọa độ cửa sổ.
func _chuot(p: Vector2, rel: Vector2, nut: bool, pressed: bool) -> void:
	var xf := get_viewport().get_final_transform()
	var wp := xf * p
	var e: InputEventMouse
	if nut:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pressed
		b.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		e = b
	else:
		var m := InputEventMouseMotion.new()
		m.relative = xf.basis_xform(rel)
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		e = m
	e.device = InputEvent.DEVICE_ID_EMULATION
	e.position = wp
	e.global_position = wp
	Input.parse_input_event(e)


func _dat_can(p: Vector2) -> void:
	var r := CAN_R * _k()
	var d := p - _goc_can
	if d.length() > r:
		_goc_can = p - d.limit_length(r)  # kéo quá thì cần đi theo ngón
		d = p - _goc_can
	_can = d / r
	_dat_di()


func _dat_di() -> void:
	var v := _can if _can.length() > 0.15 else Vector2.ZERO
	_truc("move_left", "move_right", v.x)
	_truc("move_forward", "move_back", v.y)
	var nhanh := v.length() >= CHAY_NHANH and not _bep
	if not InputMap.has_action("sprint") or nhanh == Input.is_action_pressed("sprint"):
		return
	if nhanh:
		Input.action_press("sprint")
	else:
		Input.action_release("sprint")


func _truc(am: String, duong: String, x: float) -> void:
	for pair in [[am, -x], [duong, x]]:
		if not InputMap.has_action(pair[0]):
			continue
		if pair[1] > 0.0:
			Input.action_press(pair[0], minf(pair[1], 1.0))
		else:
			Input.action_release(pair[0])


## Nút việc gửi phím chính của việc đó (theo phím người chơi đã đổi), để cả code đọc sự kiện lẫn code hỏi
## Input đều thấy. Không dùng InputEventAction: Godot 4.3 nhả các việc đang giữ bằng Input.action_press (cần đi).
func _gui(action: String, pressed: bool) -> void:
	var k := BanPhim.phim(action)
	if not InputMap.has_action(action) or k == KEY_NONE:
		return
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.pressed = pressed
	_gia_phim.append(e)  # để _input biết không phải bàn phím thật (Input có thể gửi muộn một chút)
	if _gia_phim.size() > 16:
		_gia_phim.pop_front()  # phím bị cảnh khác nuốt trước khi tới đây
	Input.parse_input_event(e)


# ---------------------------------------------------------------- đang chơi không, ở đâu

func _dang_choi() -> bool:
	var tree := get_tree()
	if tree.paused:
		return false
	var s := tree.current_scene
	if s == null or not ("player" in s) or s.player == null:
		return false
	if "state" in s and int(s.state) != 1:  # main.gd / kitchen.gd: State.PLAY
		return false
	_bep = s.get_script() != null and "kitchen" in str(s.get_script().resource_path)
	return not ("can_move" in s.player) or s.player.can_move or _bep


## Dãy gợi ý phím góc dưới phải (WASD, Space...) nằm dưới nút: làm trong suốt thay vì ẩn,
## vì HUD bếp còn dựa vào hint.visible.
func _an_goi_y_phim(an: bool) -> void:
	var s := get_tree().current_scene
	var hud = s.get("hud") if s else null
	if hud is Node and "hint" in hud and hud.hint is CanvasItem:
		hud.hint.modulate.a = 0.0 if an else 1.0


func _camera() -> Node:
	var s := get_tree().current_scene
	if s == null or not ("player" in s) or s.player == null or not ("camera_rig" in s.player):
		return null
	var rig = s.player.camera_rig
	return rig if rig and rig.has_method("xoay") else null


func _k() -> float:
	return maxf(_man().y, 1.0) / 720.0


func _man() -> Vector2:
	return get_viewport().get_visible_rect().size


func _xep_nut() -> void:
	var k := _k()
	var vs := _man()
	_nut.clear()
	for n in (NUT_BEP if _bep else NUT_PHO):
		if InputMap.has_action(n[0]):
			_nut.append([n[0], n[1], vs - n[3] * k, n[2] * k])


# ---------------------------------------------------------------- vẽ

func _draw_nut() -> void:
	var k := _k()
	var font := UiTheme.font("bold")
	var giu := _ngon.values()
	for n in _nut:
		var on: bool = giu.has(n[0])
		var c: Vector2 = n[2]
		var r: float = n[3]
		_ve.draw_circle(c, r, Color(UiTheme.CRUST if on else UiTheme.PAPER, 0.62 if on else 0.42))
		_ve.draw_arc(c, r, 0.0, TAU, 48, Color(UiTheme.INK, 0.7), 3.0 * k, true)
		var chu := tr(n[1])
		var fs := int(maxf(14.0, r * 0.42))
		var w := font.get_string_size(chu, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_ve.draw_string(font, c + Vector2(-w * 0.5, fs * 0.35), chu, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.INK)
	var r := CAN_R * k
	var goc := _goc_can if giu.has("can") else Vector2(200.0 * k, _man().y - 280.0 * k)
	_ve.draw_circle(goc, r, Color(UiTheme.PAPER, 0.25))
	_ve.draw_arc(goc, r, 0.0, TAU, 48, Color(UiTheme.INK, 0.45), 3.0 * k, true)
	_ve.draw_circle(goc + _can * r, r * 0.42, Color(UiTheme.PAPER, 0.7))
	_ve.draw_arc(goc + _can * r, r * 0.42, 0.0, TAU, 32, Color(UiTheme.INK, 0.7), 3.0 * k, true)
