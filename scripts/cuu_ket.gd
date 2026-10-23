class_name CuuKet
extends Node
## Nút cứu kẹt (A2, Sang chọn 23/10): giữ R (tay cầm: nút xuống) 1 giây là Bơ về chỗ đứng vững gần đây nhất.
## Node con của Bơ (player.gd tự gắn, trừ Bơ đứng bục ở tủ đồ), dùng được ở mọi màn có Bơ: phố, chung cư, bếp.
## - Ghi lại chỗ an toàn: đứng yên trên nền phẳng, rộng, đứng im (không phải xe buýt, xe đẩy), không bám, không chui.
## - Bấm lại trong 10 giây thì lùi về chỗ cũ hơn nữa (lỡ chỗ mới nhất cũng là chỗ kẹt).
## - Đứng yên ở tư thế lạ (treo, kẹt giữa không trung, đẩy vào tường mà không nhích) hơn 4 giây thì tự nhắc.
## - Rơi khỏi bản đồ cũng đưa về chỗ an toàn này (player.gd gọi cuu()).
## Giao diện tự dựng ở đây, không đụng hud.gd.

const ACTION := "cuu_ket"
const HOLD := 1.0             ## giữ bao lâu thì cứu (giây)
const HINT_AFTER := 4.0       ## đứng yên tư thế lạ bao lâu thì nhắc
const STABLE := 0.5           ## đứng vững bao lâu mới tính là chỗ an toàn
const SPACING := 1.0          ## hai chỗ an toàn cách nhau ít nhất (m)
const KEEP := 24              ## nhớ bao nhiêu chỗ
const FOOT := 0.28            ## dò nền bốn góc quanh chân, cách tâm chừng này (m)
const SAME_SPOT := 0.6        ## chỗ an toàn gần hơn thế coi như chính chỗ đang kẹt, bỏ qua
const STEP_BACK_TIME := 10.0  ## bấm lại trong khoảng này thì lùi thêm một chỗ
const JUMP_AWAY := 5.0        ## Bơ bị cảnh dời đi xa hơn thế trong một khung (vào chung cư, đổi khu) thì quên chỗ cũ
const MOVED := 0.3            ## nhích quá chừng này coi như không kẹt

var player: CharacterBody3D
var points: Array[Vector3] = []  ## chỗ an toàn, mới nhất ở cuối
var hint_on := false
var _hold := 0.0
var _stable := 0.0
var _last_pos := Vector3.INF
var _stuck_t := 0.0
var _stuck_at := Vector3.INF
var _hinted := false
var _last_idx := -1           ## chỗ vừa về lần cứu trước (bấm lại thì lùi từ đây)
var _back_t := 0.0
var _done_t := 0.0            ## còn hiện chữ "Đã về chỗ an toàn" bao lâu

var _layer: CanvasLayer
var _card: PanelContainer
var _title: Label
var _key: Label
var _bar: ProgressBar


func _ready() -> void:
	player = get_parent()
	_setup_input()
	_build_ui()


static func _setup_input() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION, 0.2)
	var k := InputEventKey.new()
	k.physical_keycode = KEY_R
	InputMap.action_add_event(ACTION, k)
	var j := InputEventJoypadButton.new()
	j.button_index = JOY_BUTTON_DPAD_DOWN
	InputMap.action_add_event(ACTION, j)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var pos := player.global_position
	if _last_pos != Vector3.INF and pos.distance_to(_last_pos) > JUMP_AWAY:
		# Cảnh dời Bơ sang chỗ khác (vào chung cư, về lò, đổi đơn): chỗ cũ không còn gần nữa
		points.clear()
		_stable = 0.0
		_last_idx = -1
	_last_pos = pos
	_back_t = maxf(_back_t - delta, 0.0)
	_remember(delta)
	_watch_stuck(delta)

	var holding: bool = player.can_move and Input.is_action_pressed(ACTION) and player.get("_act") == ""
	if holding:
		_hold += delta
		if _hold >= HOLD:
			_hold = 0.0
			cuu()
			_done_t = 1.6
	else:
		_hold = 0.0
	_done_t = maxf(_done_t - delta, 0.0)
	_update_ui()


## Đưa Bơ về chỗ an toàn. Trả về false khi chưa có chỗ nào (Bơ đứng yên tại chỗ).
func cuu() -> bool:
	var i := _pick()
	if i < 0:
		return false
	_last_idx = i
	player.cuu_ket_ve(points[i])
	_last_pos = player.global_position
	_stable = 0.0
	_stuck_t = 0.0
	_stuck_at = Vector3.INF
	_hinted = false
	hint_on = false
	_back_t = STEP_BACK_TIME
	return true


## Chỗ mới nhất còn đứng được và không phải chính chỗ đang kẹt; bấm lại liền thì lùi thêm một chỗ.
func _pick() -> int:
	var pos := player.global_position
	var start := points.size() - 1
	if _back_t > 0.0 and _last_idx >= 0:
		start = mini(_last_idx - 1, start)
	for i in range(start, -1, -1):
		if points[i].distance_to(pos) >= SAME_SPOT and _ground_ok(points[i]):
			return i
	# Hết chỗ để lùi (hoặc chỉ còn đúng chỗ đang đứng): về chỗ mới nhất còn đứng được
	for i in range(points.size() - 1, -1, -1):
		if _ground_ok(points[i]):
			return i
	return -1


func _remember(delta: float) -> void:
	if _back_t > 0.0 or not _safe_now():  # vừa được cứu về chỗ cũ: chưa ghi, để bấm lại còn lùi tiếp
		_stable = 0.0
		return
	_stable += delta
	if _stable < STABLE:
		return
	var pos := player.global_position
	if not points.is_empty() and points[-1].distance_to(pos) < SPACING:
		return
	if not _ground_ok(pos):
		return
	points.append(pos)
	if points.size() > KEEP:
		points.remove_at(0)


func _safe_now() -> bool:
	var p := player
	if not p.can_move or not p.is_on_floor() or p.climb != "" or p.get("_act") != "":
		return false
	if p.stance == "crouch" or p.get("_forced_crouch") or p.get("_oil") > 0:
		return false
	if p.get_floor_normal().y < 0.85 or p.get_platform_velocity().length() > 0.05:
		return false
	for i in p.get_slide_collision_count():
		var c := p.get_slide_collision(i)
		if c.get_normal().y > 0.7:
			var o := c.get_collider()
			if o is AnimatableBody3D or o is RigidBody3D or o is CharacterBody3D:
				return false  # đứng trên xe buýt, xe đẩy, người: chỗ này sẽ đi mất
	return true


## Bốn góc quanh chân đều có nền ngang mặt: chỗ rộng, không phải mép thùng hay lan can.
func _ground_ok(at: Vector3) -> bool:
	var space := player.get_world_3d().direct_space_state
	for off in [Vector3(FOOT, 0, 0), Vector3(-FOOT, 0, 0), Vector3(0, 0, FOOT), Vector3(0, 0, -FOOT)]:
		var from: Vector3 = at + off + Vector3.UP * 0.4
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.7, player.collision_mask, [player.get_rid()])
		var hit := space.intersect_ray(q)
		if hit.is_empty() or absf(hit.position.y - at.y) > 0.15:
			return false
	return true


## Tư thế lạ mà không nhích được: treo mép, kẹt lơ lửng, hay đẩy phím mà đứng im.
func _watch_stuck(delta: float) -> void:
	var p := player
	if not p.can_move:
		_stuck_t = 0.0
		hint_on = false
		return
	var pos := p.global_position
	if _stuck_at == Vector3.INF or pos.distance_to(_stuck_at) > MOVED:
		_stuck_at = pos
		_stuck_t = 0.0
		_hinted = false
		hint_on = false
		return
	var pushing := Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.3
	var odd: bool = p.climb != "" or not p.is_on_floor() or p.get("_forced_crouch") or pushing
	_stuck_t = _stuck_t + delta if odd else 0.0
	if _stuck_t >= HINT_AFTER and not _hinted and not points.is_empty():
		_hinted = true
		hint_on = true


# ---------------------------------------------------------------- giao diện

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 6
	add_child(_layer)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PAPER, 16, 12))
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_card)
	UiTheme.place(_card, 0.5, 1.0, Rect2(-190, -168, 380, 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_card.add_child(row)
	var key := UiTheme.label("R", 22, UiTheme.PAPER, "display")
	_key = key
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.custom_minimum_size = Vector2(44, 44)
	var cap := PanelContainer.new()
	cap.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.TEAL, 10, 0, UiTheme.INK, 3, 3))
	cap.add_child(key)
	row.add_child(cap)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	_title = UiTheme.label("", 18, UiTheme.INK, "bold")
	col.add_child(_title)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 12)
	_bar.max_value = 1.0
	_bar.add_theme_stylebox_override("background", UiTheme.box(UiTheme.SAND, 6, 0, UiTheme.INK, 2))
	_bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.LEAF, 6, 0, UiTheme.INK, 2))
	col.add_child(_bar)
	_card.visible = false


func _update_ui() -> void:
	if _card == null:
		return
	var holding := _hold > 0.0
	_card.visible = holding or hint_on or _done_t > 0.0
	if not _card.visible:
		return
	if _done_t > 0.0 and not holding:
		_title.text = "Bơ về chỗ an toàn rồi"
		_bar.value = 1.0
	elif holding:
		_title.text = "Giữ thêm chút nữa…"
		_bar.value = _hold / HOLD
	else:
		_title.text = "Kẹt à? Giữ R để về chỗ an toàn"
		_bar.value = 0.0
	var pad := not Input.get_connected_joypads().is_empty()
	_key.text = "▼" if pad else "R"
	if pad and not holding and _done_t <= 0.0:
		_title.text = "Kẹt à? Giữ nút xuống để về chỗ an toàn"
