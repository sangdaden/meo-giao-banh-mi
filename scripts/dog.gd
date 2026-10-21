extends CharacterBody3D
## Chó Mực bản khối: giữ hẻm 42. Không phải trận đánh mà là trò trốn tìm.
## Ngủ gật 6 s rồi hé mắt 2 s; nghe tiếng động của Bơ thì ngóc đầu nghi ngờ,
## còn nghe nữa thì đuổi. Đớp được một lần là thỏa, đi về ổ nằm thở.
## Bơ lên chỗ cao hoặc chạy ra khỏi 13 m thì nó chỉ đứng sủa. Không ai thua.

signal bit_player
signal state_changed(state: int)

enum State { SLEEP, PEEK, SUSPICIOUS, CHASE, BITE, BARK, TIRED }
const STATE_NAMES := ["ngủ gật", "hé mắt", "nghi ngờ", "đuổi", "đớp", "sủa", "mệt"]

@export_group("Ngủ")
@export var sleep_time := 6.0          ## ngủ gật bao lâu thì hé mắt (Thứ Sáu: 4)
@export var peek_time := 2.0           ## hé mắt bao lâu (Thứ Sáu: 3)
@export var see_radius := 8.0          ## lúc hé mắt, thấy Bơ trong tầm này là đuổi
@export_group("Nghi ngờ")
@export var confirm_time := 1.5        ## nghi ngờ rồi mà sau ngần này giây còn nghe tiếng là đuổi
@export var calm_time := 3.0           ## im lặng ngần này giây thì ngủ lại
@export_group("Đuổi")
@export var chase_speed := 6.3         ## chậm hơn mèo chạy nhanh (8), nhanh hơn mèo đi bộ (5)
@export var chase_turn := 3.2          ## rẽ chậm (radian/giây): chạy chữ chi là thoát
@export var leash_radius := 13.0       ## không đuổi xa ổ quá mức này
@export var high_ground := 0.5         ## Bơ đứng cao hơn chân chó ngần này là với không tới
@export var bite_reach := 0.75
@export_group("Sau đó")
@export var bark_time := 2.5
@export var bite_time := 0.5
@export var rest_time := 5.0           ## về tới ổ nằm thở bao lâu rồi mới ngủ lại
@export var walk_speed := 2.5

var player: CharacterBody3D
## true khi Mực đang canh hẻm (đơn đi qua hẻm 42). false: ngủ say, không nghe gì.
var awake := false:
	set(v):
		awake = v
		woke_up_this_order = false
		if is_inside_tree() and state not in [State.BITE, State.TIRED]:
			_set_state(State.SLEEP if _flat(home - global_position).length() < 0.5 else State.TIRED)
## Đơn này Mực có lần nào ngóc dậy không (nhiệm vụ phụ "qua hẻm mà Mực không thức").
var woke_up_this_order := false
var state := State.SLEEP
var home := Vector3.ZERO

var _t := 0.0                          # thời gian trong trạng thái hiện tại
var _last_noise := -1.0                # lúc nghe tiếng gần nhất, tính theo _t
var _noise_pos := Vector3.ZERO
var _heading := Vector3.FORWARD
var _stuck := 0.0
var _resting := false
var _fake_noise := false
var _fake_cd := 0.0
var _air_peak := 0.0

var _visual: Node3D
var _body: Node3D                      # nghiêng, nhún theo trạng thái; chứa các tư thế
var _poses := {}                       # tên tư thế -> model
var _pose := ""
var _phase := 0.0
var _zzz: Label3D
var _what: Label3D
var _bark: Label3D
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO

## Model phong cách D, mỗi trạng thái một tư thế (Sang duyệt 21/10). Chưa có xương nên đổi mesh theo trạng thái.
const POSE_MODELS := {
	"dung": preload("res://assets/models/cho_muc/cho_muc_dung.glb"),
	"ngu_gat": preload("res://assets/models/cho_muc/cho_muc_ngu_gat.glb"),
	"he_mat": preload("res://assets/models/cho_muc/cho_muc_he_mat.glb"),
	"ngui": preload("res://assets/models/cho_muc/cho_muc_ngui.glb"),
	"nghi_ngo": preload("res://assets/models/cho_muc/cho_muc_nghi_ngo.glb"),
	"duoi": preload("res://assets/models/cho_muc/cho_muc_duoi.glb"),
	"sua": preload("res://assets/models/cho_muc/cho_muc_sua.glb"),
	"dop": preload("res://assets/models/cho_muc/cho_muc_dop.glb"),
	"met": preload("res://assets/models/cho_muc/cho_muc_met.glb"),
}


func _ready() -> void:
	collision_layer = 4
	collision_mask = Blocks.LAYER_WORLD | Blocks.LAYER_PROP
	home = global_position
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.45, 0.6, 0.85)
	shape.shape = bs
	shape.position.y = 0.3
	add_child(shape)
	_build_visual()
	_visual.top_level = true  # hình nội suy giữa hai nhịp vật lý, giống mèo
	_prev_pos = global_position
	_curr_pos = global_position
	_listen_to_player()
	_set_state(State.SLEEP)


## Nghe tiếng động của Bơ. Gói động tác mới của Bơ phát `noise_made(pos, radius)`;
## khi chưa có thì tự ước lượng tiếng từ tốc độ chạy và cú đáp đất của Bơ.
func _listen_to_player() -> void:
	if not player:
		return
	if player.has_signal("noise_made"):
		player.connect("noise_made", hear)
	else:
		_fake_noise = true
		if player.has_signal("landed"):
			player.landed.connect(_on_player_landed)


## Một tiếng động ở `pos`, nghe xa `radius` mét (rón rén 2,5 · đi 6 · chạy nhanh 10 · đáp đất mạnh 8).
func hear(pos: Vector3, radius: float) -> void:
	if not awake or pos.distance_to(global_position) > radius:
		return
	_noise_pos = pos
	match state:
		State.SLEEP, State.PEEK:
			_set_state(State.SUSPICIOUS)
			_last_noise = _t
		State.SUSPICIOUS:
			_last_noise = _t
			if _t >= confirm_time:
				_set_state(State.CHASE)


func state_name() -> String:
	return STATE_NAMES[state]


func _set_state(s: State) -> void:
	var changed := s != state
	state = s
	_t = 0.0
	_last_noise = -1.0
	_stuck = 0.0
	_resting = false
	if s in [State.SUSPICIOUS, State.CHASE, State.BARK]:
		woke_up_this_order = true
	if s == State.CHASE and player:
		var to := player.global_position - global_position
		to.y = 0
		if to.length() > 0.01:
			_heading = to.normalized()
	if _zzz:
		_zzz.visible = s == State.SLEEP
		_what.visible = s == State.SUSPICIOUS
		_bark.visible = s == State.CHASE or s == State.BARK or s == State.BITE
		_bark.text = "!" if s == State.CHASE else "GÂU!"
	if changed:
		state_changed.emit(s)


func _physics_process(delta: float) -> void:
	_prev_pos = _curr_pos
	_t += delta
	if not is_on_floor():
		velocity.y -= 28.0 * delta
	if _fake_noise and awake and player:
		_fake_noise_tick(delta)

	var goal := home
	var speed := walk_speed
	match state:
		State.SLEEP:
			if awake and _t >= sleep_time:
				_set_state(State.PEEK)
		State.PEEK:
			if _sees_player():
				_set_state(State.CHASE)
			elif _t >= peek_time:
				_set_state(State.SLEEP)
		State.SUSPICIOUS:
			# Chỉ tiếng động mới làm nó đuổi: Bơ đứng im là qua được cơn nghi ngờ
			if _t - maxf(_last_noise, 0.0) >= calm_time:
				_set_state(State.SLEEP)
			_face(_noise_pos, delta)
			goal = global_position
		State.CHASE:
			_chase(delta)
		State.BITE:
			goal = global_position
			if _t >= bite_time:
				_set_state(State.TIRED)
		State.BARK:
			goal = global_position
			if player:
				_face(player.global_position, delta)
			if _t >= bark_time:
				_set_state(State.TIRED)
		State.TIRED:
			speed = walk_speed * 0.8
			if _flat(home - global_position).length() <= 0.3:
				if not _resting:
					_resting = true
					_t = 0.0
				elif _t >= rest_time:
					_set_state(State.SLEEP)

	if state != State.CHASE:
		var to_goal := _flat(goal - global_position)
		if to_goal.length() > 0.3:
			var dir := to_goal.normalized()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			_turn_visual(dir, delta, 8.0)
		else:
			velocity.x = 0
			velocity.z = 0
	move_and_slide()
	_curr_pos = global_position
	if state == State.CHASE:
		# Kẹt (gầm ba gác quá thấp, thùng chắn) thì lát nữa đứng sủa
		var moved := _flat(_curr_pos - _prev_pos).length() / maxf(delta, 0.001)
		_stuck = _stuck + delta if (_t > 0.4 and moved < chase_speed * 0.25) else 0.0
	_animate(delta)


func _chase(delta: float) -> void:
	if not player:
		_set_state(State.TIRED)
		return
	var to_player := player.global_position - global_position
	var flat := _flat(to_player)
	# Đớp: chạm Bơ mà Bơ không nhảy cao hơn lưng chó
	if flat.length() < bite_reach and to_player.y < 0.65:
		velocity.x = 0
		velocity.z = 0
		_set_state(State.BITE)
		bit_player.emit()
		return
	var too_far := player.global_position.distance_to(home) > leash_radius \
		or global_position.distance_to(home) > leash_radius
	var too_high := player.is_on_floor() and to_player.y > high_ground
	if too_far or too_high or _stuck > 0.8:
		_set_state(State.BARK)
		return
	# Rẽ chậm: hướng chạy xoay dần về phía Bơ
	if flat.length() > 0.01:
		var want := flat.normalized()
		var ang := _heading.signed_angle_to(want, Vector3.UP)
		_heading = _heading.rotated(Vector3.UP, clampf(ang, -chase_turn * delta, chase_turn * delta))
	velocity.x = _heading.x * chase_speed
	velocity.z = _heading.z * chase_speed
	_turn_visual(_heading, delta, 12.0)


func _sees_player() -> bool:
	if not player:
		return false
	if player.global_position.distance_to(global_position) > see_radius:
		return false
	return player.global_position.distance_to(home) <= leash_radius


## Tạm thời, khi Bơ chưa phát tiếng động: chạy nhanh 10 m, đi 6 m, đáp đất từ trên 1 m là 8 m.
func _fake_noise_tick(delta: float) -> void:
	if not player.is_on_floor():
		_air_peak = maxf(_air_peak, player.global_position.y)
	_fake_cd -= delta
	if _fake_cd > 0.0:
		return
	_fake_cd = 0.25
	var hs := _flat(player.velocity).length()
	if not player.is_on_floor() or hs < 0.5:
		return
	hear(player.global_position, 10.0 if hs > 6.0 else 6.0)


func _on_player_landed() -> void:
	if _air_peak - player.global_position.y > 1.0:
		hear(player.global_position, 8.0)
	_air_peak = player.global_position.y


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func _face(pos: Vector3, delta: float) -> void:
	var d := _flat(pos - global_position)
	if d.length() > 0.05:
		_turn_visual(d.normalized(), delta, 5.0)


func _turn_visual(dir: Vector3, delta: float, rate: float) -> void:
	_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-rate * delta))


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	_body = Node3D.new()
	_visual.add_child(_body)
	for pose_name in POSE_MODELS:
		var model: Node3D = POSE_MODELS[pose_name].instantiate()
		model.rotation.y = PI  # model quay mũi về +Z (glTF), Godot coi -Z là phía trước
		model.visible = false
		_body.add_child(model)
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			_apply_style(mi)
		_poses[pose_name] = model
	_show_pose("ngu_gat")
	_zzz = Blocks.label(self, "z z z", Vector3(0, 1.0, 0), 40, Color("#9FD3D6"))
	_what = Blocks.label(self, "?", Vector3(0, 1.3, 0), 72, Color("#F2C14E"))
	_bark = Blocks.label(self, "GÂU!", Vector3(0, 1.4, 0), 64, Color("#C8412F"))


## Lông mờ, màu nằm ở màu đỉnh như Bơ. Bản web (Compatibility) không tự đổi màu đỉnh
## từ linear sang sRGB nên đổi sẵn một lần, để hai bản trông giống nhau.
func _apply_style(mi: MeshInstance3D) -> void:
	if RenderingServer.get_rendering_device() == null:
		var src: ArrayMesh = mi.mesh
		var dst := ArrayMesh.new()
		for i in src.get_surface_count():
			var arrays := src.surface_get_arrays(i)
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for k in cols.size():
				cols[k] = cols[k].linear_to_srgb()
			arrays[Mesh.ARRAY_COLOR] = cols
			dst.add_surface_from_arrays(src.surface_get_primitive_type(i), arrays)
		mi.mesh = dst
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	m.rim_enabled = true
	m.rim = 0.3
	for i in mi.mesh.get_surface_count():
		mi.set_surface_override_material(i, m)


func _show_pose(pose_name: String) -> void:
	if pose_name == _pose:
		return
	if _poses.has(_pose):
		_poses[_pose].visible = false
	_pose = pose_name
	_poses[_pose].visible = true


## Tư thế theo trạng thái, cộng chút chuyển động phụ (thở, nhún khi chạy, giật đầu khi sủa)
## để người chơi đọc được trạng thái từ xa.
func _animate(delta: float) -> void:
	var k := 1.0 - exp(-10.0 * delta)
	var hspeed := _flat(velocity).length()
	_phase += delta * (2.0 + hspeed * 2.2)
	var pose := "dung"
	var bob := 0.0
	var pitch := 0.0
	var squash := 1.0
	match state:
		State.SLEEP:
			pose = "ngu_gat" if hspeed < 0.5 else "dung"
			squash = 1.0 + sin(_t * 2.2) * 0.015  # thở chậm
		State.PEEK:
			pose = "he_mat"
		State.SUSPICIOUS:
			# Ngóc đầu nhìn về phía tiếng động, thỉnh thoảng cúi ngửi đất
			pose = "nghi_ngo" if fmod(_t, 1.6) < 1.0 else "ngui"
		State.CHASE:
			pose = "duoi"
			bob = absf(sin(_phase)) * 0.08
			pitch = sin(_phase * 2.0) * 0.06
		State.BITE:
			pose = "dop"
			squash = 1.0 + sin(minf(_t / bite_time, 1.0) * PI) * 0.1
		State.BARK:
			pose = "sua"
			pitch = -absf(sin(_t * 9.0)) * 0.12
		State.TIRED:
			pose = "met"
			if hspeed > 0.5:
				bob = absf(sin(_phase)) * 0.03
			else:
				squash = 1.0 + sin(_t * 6.0) * 0.02  # thở dốc
	_show_pose(pose)
	_body.position.y = lerpf(_body.position.y, bob, k)
	_body.rotation.x = lerpf(_body.rotation.x, pitch, k)
	_body.scale = _body.scale.lerp(Vector3(1.0, squash, 1.0), k)


func _process(_delta: float) -> void:
	var smooth := _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	_visual.global_position = smooth
