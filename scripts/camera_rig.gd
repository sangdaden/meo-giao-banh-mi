extends Node3D
## Camera theo mèo, có hai góc nhìn (phím V hoặc cài đặt đổi qua lại):
## - Thứ ba: sau lưng mèo. Vật che giữa camera và Bơ (mái hiên, tường, thùng) thì mờ lấm tấm (CatVatChe),
##   camera giữ khoảng cách. Chỉ kéo camera lại gần khi chỗ camera đứng nằm lọt trong nhà hay chui xuống
##   dưới mặt đất/mặt mái (xem _update_arm).
## - Thứ nhất: ngay mắt Bơ. Không vẽ thân Bơ để khỏi che mắt, bóng Bơ vẫn in trên đất.
## Chuột (hoặc cần phải tay cầm) xoay camera. Khi chuột chưa bị khóa (trình duyệt từ chối khóa con trỏ)
## thì giữ chuột trái hoặc phải rồi kéo để xoay.

signal view_changed(first_person: bool)

@export var mouse_sensitivity := 0.0035
@export var stick_speed := 2.8
@export var distance := 3.2
@export var follow_speed := 18.0
## Bơ đang bay: camera theo chiều dọc chậm hơn để cú nhảy không làm khung hình giật lên giật xuống
## (lệch tối đa air_lag_max mét, rơi xa vẫn bám kịp)
@export var air_follow_y := 6.0
@export var air_lag_max := 0.7
@export var look_height := 0.55
@export var fp_height := 0.44     ## độ cao mắt Bơ so với chân
@export var fp_forward := 0.04    ## mắt nằm trước tâm người bao nhiêu
## Trên mái (Bơ cao hơn mặt đất high_y mét): người chơi buông chuột high_wait giây mà camera chúc dốc hơn
## high_pitch thì camera tự nâng dần về high_pitch, để thấy đường phía trước chứ không chỉ nóc mái dưới chân.
@export var high_y := 1.2
@export var high_pitch := -0.6
@export var high_wait := 1.2

var target: Node3D
var yaw := 0.0
var pitch := -0.32
var invert_y := false             ## đảo trục dọc chuột/cần (menu Cài đặt gán)
var first_person := false: set = set_first_person
var _manual_ms := -100000         ## lần cuối người chơi tự xoay (chuột hoặc cần)

var arm: SpringArm3D
var camera: Camera3D
var cutter: CatVatChe             ## làm mờ vật che giữa camera và Bơ
var _len := 0.0                   ## khoảng cách camera thật: rút ngay khi bị chắn, nới ra êm
var occluded := false             ## khung hình này có vật che giữa camera và Bơ


func _ready() -> void:
	add_to_group("camera_rig")
	arm = SpringArm3D.new()
	arm.spring_length = distance
	arm.collision_mask = 0  # va chạm tự tính trong _update_arm: vật che thì làm mờ, không kéo camera sát
	add_child(arm)
	_len = distance
	cutter = CatVatChe.new(get_parent())
	add_child(cutter)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.far = 300.0
	arm.add_child(camera)
	if target:
		global_position = target.global_position + Vector3.UP * look_height
	_apply_view()


func set_first_person(v: bool) -> void:
	if v == first_person:
		return
	first_person = v
	pitch = -0.15 if v else -0.32
	if is_node_ready():
		_apply_view()
		_snap()
	view_changed.emit(v)


func _apply_view() -> void:
	arm.spring_length = 0.0 if first_person else distance
	_len = arm.spring_length
	camera.near = 0.02 if first_person else 0.05
	if target and target.has_method("set_first_person"):
		target.set_first_person(first_person, camera)


## Bao nhiêu giây kể từ lần cuối người chơi tự xoay camera (cảnh tự lái camera thì nhường người chơi).
func since_manual() -> float:
	return (Time.get_ticks_msec() - _manual_ms) / 1000.0


func _pitch_limits() -> Vector2:
	return Vector2(-1.35, 1.2) if first_person else Vector2(-1.2, 0.35)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		first_person = not first_person
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			or event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)):
		_manual_ms = Time.get_ticks_msec()
		var lim := _pitch_limits()
		var dy: float = -event.relative.y if invert_y else event.relative.y
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - dy * mouse_sensitivity, lim.x, lim.y)


func _process(delta: float) -> void:
	var look := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if invert_y:
		look.y = -look.y
	var lim := _pitch_limits()
	if look.length() > 0.05:
		_manual_ms = Time.get_ticks_msec()
	yaw -= look.x * stick_speed * delta
	pitch = clampf(pitch - look.y * stick_speed * delta, lim.x, lim.y)
	if target:
		if first_person:
			_snap()  # góc thứ nhất bám sát mắt, không trễ, để khỏi chóng mặt
		else:
			var goal := _goal()
			var p := global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))
			if target.has_method("is_on_floor") and not target.is_on_floor() and str(target.get("climb")) == "":
				p.y = clampf(lerpf(global_position.y, goal.y, 1.0 - exp(-air_follow_y * delta)), goal.y - air_lag_max, goal.y + air_lag_max)
			global_position = p
			_ease_pitch_high(delta)
	rotation = Vector3(pitch, yaw, 0)
	if target and not first_person:
		_update_arm(delta)
	else:
		occluded = false
	var feet: Vector3 = target.global_position if target else global_position
	cutter.step(occluded, global_position + global_transform.basis.z * _len, feet + Vector3.UP * 0.3, feet.y, delta)


func _goal() -> Vector3:
	var at: Vector3 = target.smooth_position() if target.has_method("smooth_position") else target.global_position
	var low: float = target.get("crouch_amount") if "crouch_amount" in target else 0.0  # Bơ chui thì camera hạ theo
	if first_person:
		return at + Vector3.UP * fp_height * lerpf(1.0, 0.5, low) + Basis(Vector3.UP, yaw) * (Vector3.FORWARD * fp_forward)
	return at + Vector3.UP * look_height * lerpf(1.0, 0.6, low)


func _snap() -> void:
	if target:
		global_position = _goal()


## Bơ đứng trên mái/mái hiên: buông chuột một lúc thì camera bớt chúc xuống, giữ góc nhìn ngang vừa phải.
func _ease_pitch_high(delta: float) -> void:
	if pitch >= high_pitch or since_manual() < high_wait:
		return
	if not _is_high():
		return
	pitch = lerpf(pitch, high_pitch, 1.0 - exp(-2.5 * delta))


## Độ dài cần camera và có vật che hay không. Camera giữ đủ khoảng cách, vật che để CatVatChe làm mờ; chỉ rút
## lại khi (1) tia từ Bơ ra gặp mặt hướng lên (đất, mặt mái, nóc thùng: camera sắp chui xuống dưới) hoặc
## (2) chỗ camera muốn đứng lọt trong khối nhà: quét quả cầu từ Bơ ra, dừng trước tường như SpringArm cũ.
func _update_arm(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var from := global_position
	var back := global_transform.basis.z.normalized()
	var to := from + back * distance
	var exclude: Array[RID] = []
	if target is CollisionObject3D:
		exclude.append((target as CollisionObject3D).get_rid())
	var want := distance
	var hits: Array[float] = []          # khoảng cách các vật che (không phải mặt sàn) dọc tia
	var q := PhysicsRayQueryParameters3D.create(from, to, Blocks.LAYER_WORLD | Blocks.LAYER_PROP, exclude)
	for i in 8:
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var d: float = (hit.position - from).length()
		if hit.normal.y > 0.6:
			want = maxf(0.3, d - 0.25)
			break
		hits.append(d)
		exclude.append(hit.rid)
		q.exclude = exclude
	if want == distance:
		var sphere := SphereShape3D.new()
		sphere.radius = 0.2
		var sq := PhysicsShapeQueryParameters3D.new()
		sq.shape = sphere
		sq.collision_mask = Blocks.LAYER_WORLD
		sq.transform = Transform3D(Basis(), to)
		if not space.intersect_shape(sq, 1).is_empty():
			sq.transform = Transform3D(Basis(), from)
			sq.motion = back * distance
			var r := space.cast_motion(sq)
			want = maxf(0.3, distance * r[0] - 0.15)
	# Bị chắn thì rút ngay (khỏi thấy xuyên tường), hết chắn thì nới ra êm
	_len = want if want < _len else lerpf(_len, want, 1.0 - exp(-5.0 * delta))
	arm.spring_length = _len
	# Trên mái thì luôn bật: bảng hiệu, lan can trên mái hiên chỉ có hình, không có va chạm để tia dò ra
	occluded = _is_high()
	for d in hits:
		if d < _len:
			occluded = true
			break


func _is_high() -> bool:
	return target.global_position.y >= high_y and target.has_method("is_on_floor") and target.is_on_floor()
