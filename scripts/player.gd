extends CharacterBody3D
## Mèo Bơ bản khối thô: chạy, chạy nhanh, nhảy, mang túi bánh.
## Cảm giác tay được chỉnh bằng các biến @export bên dưới (xem trong Inspector khi chạy).

signal jumped
signal landed

@export_group("Chạy")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var ground_accel := 45.0      ## tăng tốc trên mặt đất (m/s²)
@export var ground_decel := 55.0      ## phanh khi thả phím
@export var air_accel := 18.0         ## đổi hướng giữa không trung
@export var turn_speed := 14.0        ## tốc độ xoay người theo hướng chạy

@export_group("Nhảy")
@export var jump_velocity := 8.5      ## cao khoảng 1,3 m khi giữ nút nhảy
@export var gravity := 28.0
@export var fall_multiplier := 1.7    ## rơi nhanh hơn lúc lên cho đỡ "bồng bềnh"
@export var short_hop_multiplier := 2.2  ## thả nút nhảy sớm thì nhảy thấp
@export var coyote_time := 0.12       ## vẫn nhảy được ngay sau khi rời mép
@export var jump_buffer := 0.12       ## bấm nhảy hơi sớm trước khi chạm đất vẫn tính

var camera_rig: Node3D               ## main.gd gán: để lấy hướng camera
var can_move := false
var carrying := false:
	set(v):
		carrying = v
		if bread:
			bread.visible = v

var _coyote := 0.0
var _buffer := 0.0
var _stun := 0.0
var _phase := 0.0
var _was_on_floor := true
# Vị trí ở hai nhịp vật lý gần nhất, để vẽ mèo nằm giữa hai nhịp cho mượt
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO

var visual: Node3D
var _body: Node3D
var bread: Node3D
var _skel: Skeleton3D
var _bone_idx := {}
var _bone_rest := {}
var _legs := [0.0, 0.0, 0.0, 0.0]
# Đuôi: góc ngẩng/cụp (pitch) và góc lệch trái phải (yaw) của 4 đốt, cùng vận tốc góc
var _tail_p := [0.0, 0.0, 0.0, 0.0]
var _tail_pv := [0.0, 0.0, 0.0, 0.0]
var _tail_y := [0.0, 0.0, 0.0, 0.0]
var _tail_yv := [0.0, 0.0, 0.0, 0.0]
var _last_yaw := 0.0
var _yaw_rate := 0.0  # góc vung chân: trước trái, trước phải, sau trái, sau phải

const BO_MODEL := preload("res://assets/models/bo.glb")
const BONE_NAMES := ["head", "leg_FL", "leg_FR", "leg_BL", "leg_BR", "tail_1", "tail_2", "tail_3", "tail_4"]
const TAIL_BONES := ["tail_1", "tail_2", "tail_3", "tail_4"]
## Độ cứng lò xo từng đốt đuôi: gốc cứng, chóp mềm nên chóp đuôi đi trễ và phất theo sau
const TAIL_STIFF := [90.0, 60.0, 42.0, 30.0]
const TAIL_DAMP := 0.55
const LEG_BONES := ["leg_FL", "leg_FR", "leg_BL", "leg_BR"]

const ORANGE := Color("#E8913A")
const ORANGE_DARK := Color("#C96F1C")
const CREAM := Color("#FBE3C2")
const SCARF := Color("#C8412F")
const BAG := Color("#2E7C80")
const INK := Color("#1F2A2A")
const PINK := Color("#F6B8A0")
const LEG_SWING_SIGN := 1.0  ## đổi thành -1 nếu chân vung ngược chiều chạy


func _ready() -> void:
	collision_layer = 2
	collision_mask = Blocks.LAYER_WORLD | Blocks.LAYER_PROP
	floor_snap_length = 0.3
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 0.7
	shape.shape = cap
	shape.position.y = 0.35
	add_child(shape)
	_build_visual()
	# Phần hình tách khỏi thân vật lý: thân di chuyển 60 lần/giây theo nhịp vật lý,
	# còn hình được nội suy mỗi khung hình nên vẫn mượt trên màn 75, 120, 144 Hz.
	visual.top_level = true
	_prev_pos = global_position
	_curr_pos = global_position


## Mèo Bơ kiểu D "Chững chạc" (bản tạm từ model phác thảo, xem tools/bo_game.py).
## Model có 11 xương (4 đốt đuôi); game tự xoay xương chân, đuôi, đầu bằng code thay cho animation.
## Tuần 2 sẽ thay bằng model dựng tay 22 xương cùng animation làm trong Blender.
func _build_visual() -> void:
	visual = Node3D.new()
	visual.name = "CatVisual"
	add_child(visual)
	_body = Node3D.new()
	visual.add_child(_body)

	var model: Node3D = BO_MODEL.instantiate()
	model.rotation.y = PI  # model quay mặt về +Z (glTF), Godot coi -Z là phía trước
	_body.add_child(model)
	_skel = model.find_children("*", "Skeleton3D", true, false)[0]
	for bone_name in BONE_NAMES:
		var idx := _skel.find_bone(bone_name)
		_bone_idx[bone_name] = idx
		_bone_rest[bone_name] = _skel.get_bone_rest(idx).basis.get_rotation_quaternion()
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		_apply_style(mi)

	# Túi bánh đeo bên hông phải, quai vắt qua lưng
	Blocks.box(_body, Vector3(0.07, 0.13, 0.18), Vector3(0.14, 0.27, 0.02), BAG)
	Blocks.box(_body, Vector3(0.26, 0.02, 0.03), Vector3(0.02, 0.37, 0.02), BAG)

	# Ổ bánh mì ló ra khỏi túi khi đang giao
	bread = Node3D.new()
	_body.add_child(bread)
	var loaf := CapsuleMesh.new()
	loaf.radius = 0.035
	loaf.height = 0.2
	loaf.radial_segments = 8
	loaf.rings = 2
	var loaf_mi := Blocks.mesh(bread, loaf, Vector3(0.14, 0.36, 0.03), Color("#D98E2B"))
	loaf_mi.rotation_degrees = Vector3(70, 0, 0)
	bread.visible = false


## Vật liệu theo style guide D: lông Roughness .8 Rim .3, vải Roughness .9 Rim .4, mắt Clearcoat.
## Màu lông, vằn, khăn, mắt đều nằm trong màu đỉnh (vertex color) của model.
func _apply_style(mi: MeshInstance3D) -> void:
	if RenderingServer.get_rendering_device() == null:
		_vertex_colors_to_srgb(mi)
	for i in mi.mesh.get_surface_count():
		var src := mi.get_active_material(i)
		var mat_name := src.resource_name if src else ""
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		if mat_name.begins_with("Sang"):
			# Đốm sáng trong mắt: luôn trắng, không bị bóng đổ làm tối
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		elif mat_name.begins_with("Mat"):
			m.roughness = 0.3
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
		else:
			var fabric := mat_name.begins_with("Khan")
			m.roughness = 0.9 if fabric else 0.8
			m.rim_enabled = true
			m.rim = 0.4 if fabric else 0.3
		mi.set_surface_override_material(i, m)


## Bản web (Compatibility) không đổi màu đỉnh từ linear sang sRGB như Forward+,
## nên lông bị sậm và đỏ hơn. Đổi sẵn màu một lần lúc tạo để hai bản trông giống nhau.
func _vertex_colors_to_srgb(mi: MeshInstance3D) -> void:
	var src: ArrayMesh = mi.mesh
	var dst := ArrayMesh.new()
	for i in src.get_surface_count():
		var arrays := src.surface_get_arrays(i)
		var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for k in cols.size():
			cols[k] = cols[k].linear_to_srgb()
		arrays[Mesh.ARRAY_COLOR] = cols
		dst.add_surface_from_arrays(src.surface_get_primitive_type(i), arrays)
		dst.surface_set_material(i, src.surface_get_material(i))
	mi.mesh = dst


func _physics_process(delta: float) -> void:
	_prev_pos = _curr_pos
	var on_floor := is_on_floor()
	_coyote = coyote_time if on_floor else _coyote - delta
	_buffer = jump_buffer if (can_move and Input.is_action_just_pressed("jump")) else _buffer - delta
	_stun = maxf(_stun - delta, 0.0)

	if not on_floor:
		var g := gravity
		if velocity.y < 0.0:
			g *= fall_multiplier
		elif not Input.is_action_pressed("jump"):
			g *= short_hop_multiplier
		velocity.y = maxf(velocity.y - g * delta, -30.0)

	if _buffer > 0.0 and _coyote > 0.0 and _stun <= 0.0:
		velocity.y = jump_velocity
		_buffer = 0.0
		_coyote = 0.0
		visual.scale = Vector3(0.8, 1.25, 0.8)
		jumped.emit()

	var input := Vector2.ZERO
	if can_move and _stun <= 0.0:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw: float = camera_rig.yaw if camera_rig else 0.0
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw)
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target := Vector2(dir.x, dir.z) * speed
	var accel := air_accel
	if on_floor:
		accel = ground_accel if dir.length() > 0.01 else ground_decel
	var hv := Vector2(velocity.x, velocity.z).move_toward(target, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.y

	move_and_slide()

	if is_on_floor() and not _was_on_floor:
		visual.scale = Vector3(1.25, 0.75, 1.25)
		landed.emit()
	_was_on_floor = is_on_floor()

	if dir.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-turn_speed * delta))

	# Rơi khỏi bản đồ thì đưa về chỗ cũ
	if global_position.y < -10.0:
		global_position = Vector3(-33, 1, -2)
		velocity = Vector3.ZERO
	_curr_pos = global_position


## Animation tạm bằng code: vung chân, nhún người, vẫy đuôi.
## Tuần 2 sẽ thay bằng AnimationTree với animation làm trong Blender.
## Vị trí mèo đã nội suy giữa hai nhịp vật lý: camera và mũi tên bám theo vị trí này.
func smooth_position() -> Vector3:
	return _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())


func _process(delta: float) -> void:
	visual.global_position = smooth_position()
	var hspeed := Vector2(velocity.x, velocity.z).length()
	visual.scale = visual.scale.lerp(Vector3.ONE, 1.0 - exp(-12.0 * delta))
	if is_on_floor():
		_phase += delta * (4.0 + hspeed * 2.2)
		var k := clampf(hspeed / sprint_speed, 0.0, 1.0)
		var swing := sin(_phase) * 0.9 * k
		_legs = [swing, -swing, -swing, swing]
		_body.position.y = absf(sin(_phase)) * 0.04 * k
		_body.rotation.x = 0.0
	else:
		# Trên không: chân trước duỗi, chân sau co
		var t := 1.0 - exp(-10.0 * delta)
		for i in 4:
			_legs[i] = lerpf(_legs[i], 0.8 if i < 2 else -0.8, t)
		_body.rotation.x = clampf(velocity.y * 0.04, -0.3, 0.3)
	_update_tail(delta, hspeed, velocity.y, is_on_floor())
	_apply_bones(hspeed)


## Xoay xương theo góc tính ở trên. Trục X của xương chân là trục vung trước/sau.
func _apply_bones(hspeed: float) -> void:
	for i in 4:
		_pose(LEG_BONES[i], Vector3.RIGHT, _legs[i] * LEG_SWING_SIGN)
	_pose("head", Vector3.RIGHT, sin(_phase * 2.0) * 0.04 * clampf(hspeed / sprint_speed, 0.0, 1.0))
	for i in 4:
		var idx: int = _bone_idx[TAIL_BONES[i]]
		if idx >= 0:
			_skel.set_bone_pose_rotation(idx, _bone_rest[TAIL_BONES[i]]
				* Quaternion(Vector3.RIGHT, -_tail_p[i]) * Quaternion(Vector3.BACK, _tail_y[i]))


## Đuôi mèo thật đổi dáng theo việc mèo đang làm:
## - Đứng yên: đuôi rủ xuống rồi cong lên, chóp đung đưa chậm.
## - Đi: đuôi hạ xuống ngang lưng rồi cong lên; chạy nhanh: duỗi thẳng ra sau để giữ thăng bằng.
## - Nhảy lên: đuôi cụp xuống; rơi xuống: đuôi vểnh lên như bánh lái.
## - Quẹo: đuôi văng ra phía ngoài vòng quẹo.
## Mỗi đốt là một lò xo đuổi theo góc đích; chóp mềm hơn gốc nên tự có độ trễ, phất theo sau.
func _update_tail(delta: float, hspeed: float, vy: float, on_floor: bool) -> void:
	var k := clampf(hspeed / sprint_speed, 0.0, 1.0)
	var t := Time.get_ticks_msec() * 0.001
	var yaw := visual.rotation.y
	var rate := wrapf(yaw - _last_yaw, -PI, PI) / maxf(delta, 0.001)
	_last_yaw = yaw
	_yaw_rate = lerpf(_yaw_rate, rate, 1.0 - exp(-8.0 * delta))

	# Góc đích (radian, dương là cụp xuống/ra sau). Đứng yên là dáng gốc của model: rủ xuống rồi cong lên.
	var idle := [0.0, 0.0, sin(t * 1.3) * 0.12, sin(t * 1.3 - 0.8) * 0.25]
	var walk := [0.1, 0.1, 0.25, 0.1]      # hạ thấp hơn, chóp vẫn cong lên nhẹ
	var run := [-0.1, 0.25, 0.7, 0.45]     # duỗi ra sau
	var targets := []
	for i in 4:
		var a: float
		if hspeed < walk_speed:
			a = lerpf(idle[i], walk[i], hspeed / walk_speed)
		else:
			a = lerpf(walk[i], run[i], clampf((hspeed - walk_speed) / (sprint_speed - walk_speed), 0.0, 1.0))
		if not on_floor:
			# Lên: cụp (+), xuống: vểnh (-). Chủ yếu ở gốc đuôi.
			a += clampf(vy * 0.07, -0.6, 0.5) * (1.0 if i < 2 else 0.5)
		targets.append(a)

	# Lắc ngang: đứng yên vẫy chậm, chạy thì vẫy nhẹ theo bước; quẹo thì văng ra ngoài
	var sway := sin(t * (1.6 + k * 4.0)) * lerpf(0.18, 0.08, k)
	for i in 4:
		var yaw_target := sway * (0.4 + i * 0.3) - clampf(_yaw_rate * 0.12, -0.5, 0.5) * (0.5 + i * 0.25)
		var stiff: float = TAIL_STIFF[i]
		var damp := 2.0 * sqrt(stiff) * TAIL_DAMP
		_tail_pv[i] += ((targets[i] - _tail_p[i]) * stiff - _tail_pv[i] * damp) * delta
		_tail_p[i] += _tail_pv[i] * delta
		_tail_yv[i] += ((yaw_target - _tail_y[i]) * stiff - _tail_yv[i] * damp) * delta
		_tail_y[i] += _tail_yv[i] * delta


func _pose(bone_name: String, axis: Vector3, angle: float) -> void:
	var idx: int = _bone_idx[bone_name]
	if idx >= 0:
		_skel.set_bone_pose_rotation(idx, _bone_rest[bone_name] * Quaternion(axis, angle))


## Bị Chó Mực đớp: văng ra và khựng lại một chút.
func knockback(from: Vector3, strength := 9.0) -> void:
	var away := global_position - from
	away.y = 0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	velocity = away * strength + Vector3.UP * 4.5
	_stun = 0.45
	visual.scale = Vector3(1.3, 0.7, 1.3)
