class_name CamGiacTay
extends Node3D
## DK2 "Cảm giác tay": các phản hồi nhỏ khi điều khiển Bơ ngoài phố. Camera rig tự tạo node này (camera_rig.gd).
## - Bụi tung khi đáp từ cao (> dust_fall m) và khi phanh gấp lúc đang chạy nhanh. Ngày mưa thì là nước bắn.
##   Một vật liệu dùng chung, mảng sát đất không đổ bóng, có visibility_range, xong thì ẩn (không tốn lệnh vẽ).
## - Camera nảy nhẹ khi rơi > bump_fall m (rig.nay(), Cài đặt "Camera nảy khi đáp từ cao").
## - Rung tay cầm khi bị hất văng (xe tông, Mực đớp, va sạp chợ) và khi đáp rất mạnh (Cài đặt "Rung tay cầm").

@export var dust_fall := 1.2
@export var bump_fall := 2.0
@export var brake_cooldown := 0.8

var rig: Node3D
var player: CharacterBody3D
var so_lan_bui := 0      ## đếm cho test
var so_lan_phanh := 0
var so_lan_rung := 0

var _dap: CPUParticles3D       # vòng bụi khi đáp
var _phanh: CPUParticles3D     # bụi xịt về phía trước khi phanh
var _an := {}                  # emitter -> giây còn lại trước khi ẩn
var _prev_h := Vector2.ZERO
var _brake_cd := 0.0

static var _mat: StandardMaterial3D


func _init(r: Node3D = null) -> void:
	rig = r
	name = "CamGiacTay"


func _ready() -> void:
	top_level = true
	player = rig.target as CharacterBody3D if rig else null
	if player == null:
		return
	_dap = _make_puff(12, 0.55)
	_dap.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_dap.emission_ring_axis = Vector3.UP
	_dap.emission_ring_radius = 0.22
	_dap.emission_ring_inner_radius = 0.08
	_dap.emission_ring_height = 0.02
	_dap.direction = Vector3.RIGHT
	_dap.spread = 180.0
	_dap.flatness = 1.0   # tỏa đều ra quanh chân trên mặt đất
	_dap.initial_velocity_min = 1.2
	_dap.initial_velocity_max = 2.2
	_phanh = _make_puff(10, 0.5)
	_phanh.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_phanh.emission_sphere_radius = 0.15
	_phanh.spread = 70.0
	_phanh.flatness = 0.3
	_phanh.initial_velocity_min = 1.0
	_phanh.initial_velocity_max = 2.0
	if player.has_signal("landed"):
		player.landed.connect(_on_landed)
	if player.has_signal("knocked"):
		player.knocked.connect(_on_knocked)


func _make_puff(n: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = n
	p.lifetime = life
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.34, 0.34)
	q.material = _material()
	p.mesh = q
	p.gravity = Vector3(0, 0.5, 0)   # bụi bốc nhẹ lên rồi tan
	p.damping_min = 3.0
	p.damping_max = 4.5
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.6))
	sc.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.75))
	g.add_point(0.4, Color(1, 1, 1, 0.5))
	g.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_range_end = 30.0
	p.visible = false
	add_child(p)
	return p


static func _material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_mat.vertex_color_use_as_albedo = true
		_mat.disable_receive_shadows = true
		var tex := GradientTexture2D.new()
		tex.width = 32
		tex.height = 32
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		tex.gradient = g
		_mat.albedo_texture = tex
	return _mat


func _tint() -> Color:
	# Ngày mưa: nước bắn trắng xanh thay cho bụi đất
	return Color(0.86, 0.9, 0.95) if ThoiTiet.dang_mua() else Color(0.95, 0.9, 0.82)


func _fire(p: CPUParticles3D, at: Vector3, size := 1.0) -> void:
	p.global_position = at
	p.color = _tint()
	p.scale_amount_min = 0.7 * size
	p.scale_amount_max = 1.2 * size
	p.visible = true
	p.restart()
	_an[p] = p.lifetime + 0.15


func _process(delta: float) -> void:
	for p in _an.keys():
		_an[p] -= delta
		if _an[p] <= 0.0:
			p.visible = false
			_an.erase(p)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_brake_cd = maxf(_brake_cd - delta, 0.0)
	var h := Vector2(player.velocity.x, player.velocity.z)
	var fast: float = float(player.get("walk_speed")) * 1.15 if "walk_speed" in player else 5.75
	if _brake_cd <= 0.0 and player.is_on_floor() and str(player.get("climb")) == "" and _prev_h.length() > fast:
		# Phanh gấp (thả phím, đổi ngược chiều) chứ không phải chậm dần: tụt hơn 0,6 m/s trong một nhịp vật lý
		var reverse := h.length() > 0.5 and h.dot(_prev_h) < 0.0
		if _prev_h.length() - h.length() > 0.6 or reverse:
			_brake_cd = brake_cooldown
			so_lan_phanh += 1
			var fwd := Vector3(_prev_h.x, 0, _prev_h.y).normalized()
			# Bụi xịt lên từ bốn chân, tạt hai bên và về trước: camera sau lưng vẫn thấy, không bị thân Bơ che
			_phanh.direction = fwd * 0.5 + Vector3.UP * 0.6
			_fire(_phanh, player.global_position + Vector3.UP * 0.05, 1.0)
	_prev_h = h


func _on_landed() -> void:
	var fall: float = float(player.get("_fall_from")) - player.global_position.y
	if fall > dust_fall:
		so_lan_bui += 1
		_fire(_dap, player.global_position + Vector3.UP * 0.04, clampf(0.8 + (fall - dust_fall) * 0.2, 0.8, 1.5))
	if fall > bump_fall:
		if rig and rig.has_method("nay"):
			rig.nay(clampf((fall - bump_fall) / 3.0 + 0.4, 0.4, 1.0))
		if fall > bump_fall + 1.5:
			_rung(0.25, 0.1, 0.12)


func _on_knocked(strength: float) -> void:
	var k := clampf(strength / 9.0, 0.2, 1.0)
	_rung(0.5 * k, 0.8 * k, 0.15 + 0.2 * k)


func _rung(weak: float, strong: float, seconds: float) -> void:
	if not GameSettings.get_value("rung_tay_cam"):
		return
	so_lan_rung += 1
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, weak, strong, seconds)
