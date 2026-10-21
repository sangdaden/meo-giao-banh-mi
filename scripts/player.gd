extends CharacterBody3D
## Mèo Bơ bản khối thô: chạy, chạy nhanh, nhảy, mang túi bánh.
## Cảm giác tay được chỉnh bằng các biến @export bên dưới (xem trong Inspector khi chạy).

signal jumped
signal landed
## Bơ gây tiếng động: Chó Mực (và ai muốn nghe) nghe thấy nếu ở trong bán kính radius (mét)
signal noise_made(pos: Vector3, radius: float)
signal stance_changed(stance: String)   ## HUD hiện chấm chỉ báo khi rón rén/chui
signal deliver_finished(kind: String)   ## xong động tác giao bánh
signal startled                         ## giật mình (bị đớp, xe tông)
signal slipped                          ## bắt đầu trượt trên vũng dầu
signal ledge_grabbed                    ## bám được mép (Thứ Năm)
signal ledge_climbed                    ## leo lên xong mép
signal wall_kicked(count: int)          ## bật tường lần thứ count trong một lần bay

@export_group("Chạy")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var ground_accel := 45.0      ## tăng tốc trên mặt đất (m/s²)
@export var ground_decel := 55.0      ## phanh khi thả phím
@export var air_accel := 18.0         ## đổi hướng giữa không trung
@export var turn_speed := 14.0        ## tốc độ xoay người theo hướng chạy

@export_group("Chui và rón rén")
@export var crouch_speed := 2.5       ## chui: thấp 0,25 m
@export var sneak_speed := 2.0        ## rón rén: đi êm, tiếng động nhỏ
@export var crouch_height := 0.25
@export var oil_accel := 4.0          ## trên vũng dầu: gần như không bám, trượt theo quán tính

@export_group("Tiếng động (bán kính, mét)")
@export var noise_sneak := 2.5
@export var noise_walk := 6.0
@export var noise_sprint := 10.0
@export var noise_land := 8.0         ## đáp đất từ cao hơn 1 m
@export var noise_bump := 8.0         ## đụng thùng, đồ nhỏ khi đang chạy

@export_group("Nhảy")
@export var jump_velocity := 8.5      ## cao khoảng 1,3 m khi giữ nút nhảy
@export var gravity := 28.0
@export var fall_multiplier := 1.7    ## rơi nhanh hơn lúc lên cho đỡ "bồng bềnh"
@export var short_hop_multiplier := 2.2  ## thả nút nhảy sớm thì nhảy thấp
@export var coyote_time := 0.12       ## vẫn nhảy được ngay sau khi rời mép
@export var jump_buffer := 0.12       ## bấm nhảy hơi sớm trước khi chạm đất vẫn tính

@export_group("Leo (Thứ Năm, chung cư)")
@export var ledge_min := 0.3          ## mép thấp nhất (so với chân) để bám; thấp hơn thì nhảy lên luôn
@export var ledge_reach := 0.95       ## mép cao nhất với tới khi đang bay: nhảy 1,3 m + 0,95 = mép 2,2 m
@export var pull_time := 0.6          ## leo từ tư thế bám lên mặt mép
@export var wall_kick_up := 8.5
@export var wall_kick_out := 4.5
@export var wall_kick_max := 3        ## số lần đạp tối đa trước khi chạm đất
@export var wall_gap_max := 1.5       ## chỉ bật tường trong khe hẹp: phía sau lưng có tường trong 1,5 m
@export var pipe_speed := 1.4         ## leo ống nước

var camera_rig: Node3D               ## main.gd gán: để lấy hướng camera
var can_move := false
var carrying := false:
	set(v):
		carrying = v
		if bread:
			bread.visible = v
		if _bag:
			_bag.visible = v or _wear_bag

## Dáng đi hiện tại: "walk" | "sprint" | "crouch" | "sneak"
var stance := "walk"
var crouch_amount := 0.0          ## 0 đứng, 1 chui hẳn (hình và camera hạ xuống theo)
var _stand_shape: CollisionShape3D
var _crouch_shape: CollisionShape3D
var _low_probe: CollisionShape3D  ## khối dò gầm: rộng bằng dáng đứng, thấp bằng dáng chui
var _forced_crouch := false       ## đang ở dưới gầm thấp: thả phím chui vẫn phải chui
var _oil := 0                     ## số vũng dầu đang đứng lên (các vùng có thể chồng nhau)
var _sliding := false
var _fall_from := 0.0             ## độ cao lúc bắt đầu rơi, để biết đáp đất từ bao cao
var _bump_cooldown := 0.0
var _step_side := 1.0             ## dấu của nhịp bước trước, đổi dấu là một bước chân
var _act := ""                    ## động tác đang diễn: "" | "deliver" | "startle"
var _act_kind := ""
var _act_t := 0.0
var _act_len := 0.0

## Cảnh chung cư bật: bám mép, bật tường, leo ống nước. Thứ Hai để tắt nên khu phố không đổi.
var climb_moves := false
## Đang leo: "" | "hang" (bám mép) | "pull" (đang leo lên mép) | "pipe" (ôm ống nước)
var climb := ""
var _climb_t := 0.0
var _wall_n := Vector3.FORWARD     ## pháp tuyến tường đang bám/ôm (chỉ ra ngoài)
var _pull_from := Vector3.ZERO
var _pull_to := Vector3.ZERO
var _kicks := 0
var _kick_lock := 0.0               ## vừa đạp tường: khóa điều khiển một chút cho khỏi lao lại vào tường
var _grab_cooldown := 0.0           ## vừa buông/nhảy khỏi chỗ bám: chưa bám lại ngay
var _pipes: Array = []              ## ống nước đang chạm (cảnh đặt Area3D gọi enter_pipe/exit_pipe)
var _pipe: Node3D

var _coyote := 0.0
var _buffer := 0.0
var _stun := 0.0
var _phase := 0.0
var _was_on_floor := true
# Vị trí ở hai nhịp vật lý gần nhất, để vẽ mèo nằm giữa hai nhịp cho mượt
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO

const LAYER_BO_BODY := 1 << 10   ## lớp hình thân Bơ: camera góc thứ nhất bỏ qua lớp này
const LAYER_FP_PAWS := 1 << 11   ## lớp chân trước riêng, chỉ camera góc thứ nhất vẽ
const FP_PAW_SIZE := 0.8         ## cỡ BoPaw ở góc thứ nhất (bàn chân ~8 cm)
const FP_PAW_LEAN := 0.85        ## chân trước chống chéo ra trước bao nhiêu (radian)
var visual: Node3D
var _fp_paws := []               ## khớp vai của hai chân trước BoPaw (trái, phải) ở góc thứ nhất
var first_person := false        ## camera_rig gán: góc nhìn thứ nhất thì người quay theo camera
var _body: Node3D
var bread: Node3D
var preview := false             ## tủ đồ: đứng yên trên bục xem trước, không có vật lý
var _bag: Node3D
var _wear_bag := true
var _scarf_mesh: MeshInstance3D  # khăn là một mặt (surface) của mesh Bơ, tháo khăn thì thay vật liệu ẩn
var _scarf_surface := -1
var _scarf_mat: Material
var _hidden_mat: StandardMaterial3D
var _skel: Skeleton3D
var _bone_idx := {}
var _bone_rest := {}
var _legs := [0.0, 0.0, 0.0, 0.0]  # góc vung chân: trước trái, trước phải, sau trái, sau phải
# Đuôi: góc ngẩng/cụp (pitch) và góc lệch trái phải (yaw) của 4 đốt, cùng vận tốc góc
var _tail_p := [0.0, 0.0, 0.0, 0.0]
var _tail_pv := [0.0, 0.0, 0.0, 0.0]
var _tail_y := [0.0, 0.0, 0.0, 0.0]
var _tail_yv := [0.0, 0.0, 0.0, 0.0]
var _last_yaw := 0.0
var _yaw_rate := 0.0
# Toàn thân: tốc độ lúc trước (để tính gia tốc), các lò xo cho chuyển động phụ
var _last_hspeed := 0.0
var _accel := 0.0
var _was_floor_anim := true
var _lean := Spring.new()        # nghiêng người khi quẹo
var _pitch := Spring.new()       # chúi/ngả người khi tăng tốc, phanh, nhảy
var _head_yaw := Spring.new()
var _head_pitch := Spring.new()
var _ear := [Spring.new(), Spring.new()]      # cụp ra sau
var _ear_flick := [0.0, 0.0]                  # giật tai (giảm dần về 0)
var _scarf_p := Spring.new()
var _scarf_r := Spring.new()
var _idle_time := 0.0
var _look_target := Vector2.ZERO              # đứng yên lâu thì ngó quanh
var _look_timer := 2.0
var _blink_timer := 3.0
var _blink := 0.0                             # 1 = mắt nhắm
var _flick_timer := 4.0


## Lò xo giảm chấn một chiều: đuổi theo đích, có quán tính nên chuyển động không bị giật cục.
class Spring:
	var x := 0.0
	var v := 0.0

	func step(target: float, stiff: float, damping: float, dt: float) -> float:
		v += ((target - x) * stiff - v * 2.0 * sqrt(stiff) * damping) * dt
		x += v * dt
		return x

const BO_MODEL := preload("res://assets/models/bo.glb")
const BONE_NAMES := ["head", "leg_FL", "leg_FR", "leg_BL", "leg_BR", "tail_1", "tail_2", "tail_3", "tail_4",
	"ear_L", "ear_R", "eye_L", "eye_R", "scarf"]
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
	_stand_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 0.7
	_stand_shape.shape = cap
	_stand_shape.position.y = 0.35
	add_child(_stand_shape)
	# Khi chui: trụ dẹt cao 0,25 m, lọt gầm ba gác, gầm bàn cà phê
	_crouch_shape = CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.22
	cyl.height = crouch_height
	_crouch_shape.shape = cyl
	_crouch_shape.position.y = crouch_height * 0.5
	_crouch_shape.disabled = true
	add_child(_crouch_shape)
	# Dò gầm thấp bằng khối rộng như dáng đứng: nếu dùng trụ chui (hẹp hơn) thì đi sát cạnh bàn,
	# tường cũng bị tưởng là gầm và Bơ tự khụm xuống.
	_low_probe = CollisionShape3D.new()
	var probe := CylinderShape3D.new()
	probe.radius = cap.radius
	probe.height = crouch_height
	_low_probe.shape = probe
	_low_probe.position.y = crouch_height * 0.5
	_build_visual()
	# Phần hình tách khỏi thân vật lý: thân di chuyển 60 lần/giây theo nhịp vật lý,
	# còn hình được nội suy mỗi khung hình nên vẫn mượt trên màn 75, 120, 144 Hz.
	visual.top_level = true
	_prev_pos = global_position
	_curr_pos = global_position


## Mèo Bơ kiểu D "Chững chạc" (bản tạm từ model phác thảo, xem tools/bo_game.py).
## Model có 16 xương (chân, đầu, 4 đốt đuôi, tai, mắt, khăn); game tự xoay xương bằng code thay cho animation.
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

	_build_bag()
	apply_outfit()
	# Thân, khăn, túi và quai: góc nhìn thứ nhất không vẽ (vẫn đổ bóng), thay bằng hai chân trước riêng
	for mi: MeshInstance3D in _body.find_children("*", "MeshInstance3D", true, false):
		mi.layers = LAYER_BO_BODY
	_build_fp_paws()


## Túi bánh đeo sát hông phải, quai vắt chéo qua lưng ôm theo thân.
## Số đo lấy từ thân Bơ chỗ đeo túi: nửa bề ngang ~0,108 m ở độ cao 0,24 m, sống lưng cao 0,35 m.
func _build_bag() -> void:
	var bag := Node3D.new()
	bag.name = "TuiBanh"
	_body.add_child(bag)
	_bag = bag
	# Thân túi áp sát hông (mặt trong ở x = 0,105), nắp túi phủ nửa trên, khoá cài nhỏ
	Blocks.box(bag, Vector3(0.05, 0.11, 0.16), Vector3(0.13, 0.235, 0.03), BAG)
	Blocks.box(bag, Vector3(0.056, 0.05, 0.168), Vector3(0.132, 0.272, 0.03), BAG.darkened(0.25))
	Blocks.box(bag, Vector3(0.008, 0.022, 0.03), Vector3(0.162, 0.255, 0.03), Color("#E8C15A"))
	# Quai: dải vải uốn theo mặt cắt elip của thân, từ miệng túi vắt qua lưng xuống hông trái
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector2(0.0, 0.235)
	var a := 0.116
	var b := 0.124
	var steps := 18
	for i in steps + 1:
		var th := deg_to_rad(lerpf(30.0, 200.0, float(i) / steps))
		var pt := Vector3(c.x + cos(th) * a, c.y + sin(th) * b, 0.0)
		var n := Vector3(cos(th) / a, sin(th) / b, 0.0).normalized()
		st.set_normal(n)
		st.add_vertex(pt + Vector3(0, 0, 0.016))
		st.set_normal(n)
		st.add_vertex(pt + Vector3(0, 0, 0.044))
	for i in steps:
		var k := i * 2
		st.add_index(k)
		st.add_index(k + 1)
		st.add_index(k + 2)
		st.add_index(k + 1)
		st.add_index(k + 3)
		st.add_index(k + 2)
	var strap := Blocks.mesh(bag, st.commit(), Vector3.ZERO, BAG.darkened(0.25))
	strap.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Ổ bánh mì ló ra khỏi miệng túi khi đang giao
	bread = Node3D.new()
	bag.add_child(bread)
	var loaf := CapsuleMesh.new()
	loaf.radius = 0.03
	loaf.height = 0.17
	loaf.radial_segments = 8
	loaf.rings = 2
	var loaf_mi := Blocks.mesh(bread, loaf, Vector3(0.128, 0.3, 0.0), Color("#D98E2B"))
	loaf_mi.rotation_degrees = Vector3(60, 0, 0)
	bread.visible = carrying


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
		if mat_name.begins_with("Khan"):
			_scarf_mesh = mi
			_scarf_surface = i
			_scarf_mat = m


## Mặc đồ theo tủ đồ (Outfit): khăn quàng đỏ và túi bánh tháo ra được.
## Túi bánh tháo rồi thì chỉ hiện lúc đang mang bánh đi giao.
func apply_outfit() -> void:
	_wear_bag = Outfit.worn("back") == "tuibanh"
	if _bag:
		_bag.visible = carrying or _wear_bag
	if _scarf_mesh:
		if _hidden_mat == null:
			_hidden_mat = StandardMaterial3D.new()
			_hidden_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			_hidden_mat.albedo_color = Color(1, 1, 1, 0)
		var on := Outfit.worn("neck") == "khando"
		_scarf_mesh.set_surface_override_material(_scarf_surface, _scarf_mat if on else _hidden_mat)


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
	_grab_cooldown = maxf(_grab_cooldown - delta, 0.0)
	_kick_lock = maxf(_kick_lock - delta, 0.0)
	if climb != "":
		_climb_process(delta)
		_curr_pos = global_position
		return
	var on_floor := is_on_floor()
	if on_floor:
		_kicks = 0
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
	elif climb_moves and _buffer > 0.0 and not on_floor and _stun <= 0.0:
		_try_wall_kick()

	var input := Vector2.ZERO
	if can_move and _stun <= 0.0 and _act == "" and _kick_lock <= 0.0:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw: float = camera_rig.yaw if camera_rig else 0.0
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw)
	_update_stance(dir, on_floor)
	var speed: float = {"walk": walk_speed, "sprint": sprint_speed, "crouch": crouch_speed, "sneak": sneak_speed}[stance]
	var target := Vector2(dir.x, dir.z) * speed
	var accel := air_accel
	if on_floor:
		accel = ground_accel if dir.length() > 0.01 else ground_decel
		if _oil > 0:
			accel = oil_accel
	var hv := Vector2(velocity.x, velocity.z)
	if _kick_lock <= 0.0:
		hv = hv.move_toward(target, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.y
	var sliding := on_floor and _oil > 0 and hv.length() > 1.0
	if sliding and not _sliding:
		slipped.emit()
		_sfx("oil_slip")
	_sliding = sliding

	var speed_before := hv.length()
	move_and_slide()
	_check_bump(speed_before, delta)
	if climb_moves and can_move and _stun <= 0.0 and _act == "":
		if not _try_pipe(dir):
			_try_grab(dir)

	if not is_on_floor() and _was_on_floor:
		_fall_from = global_position.y
	if not is_on_floor():
		_fall_from = maxf(_fall_from, global_position.y)
	if is_on_floor() and not _was_on_floor:
		visual.scale = Vector3(1.25, 0.75, 1.25)
		landed.emit()
		if _fall_from - global_position.y > 1.0:
			noise_made.emit(global_position, noise_land)
	_was_on_floor = is_on_floor()
	_act_t += delta
	if _act != "" and _act_t >= _act_len:
		var done := _act
		_act = ""
		if done == "deliver":
			deliver_finished.emit(_act_kind)

	if first_person:
		# Góc nhìn thứ nhất: người (và bóng) luôn quay theo hướng nhìn, đi tới là đi theo mắt
		visual.rotation.y = lerp_angle(visual.rotation.y, yaw, 1.0 - exp(-turn_speed * 2.0 * delta))
	elif dir.length() > 0.1 and _act == "":
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-turn_speed * delta))

	# Rơi khỏi bản đồ thì đưa về chỗ cũ
	if global_position.y < -10.0:
		global_position = Vector3(-33, 1, -2)
		velocity = Vector3.ZERO
	_curr_pos = global_position


# ---------------------------------------------------------------- leo (Thứ Năm)

## Đang bay và đẩy về phía tường: nếu mép tường cao hơn chân từ ledge_min tới ledge_reach
## và trên mép đủ chỗ đứng thì bám lại. Đang bay lên nhanh thì chưa bám (nhảy qua bậc thấp vẫn như cũ).
func _try_grab(dir: Vector3) -> bool:
	if is_on_floor() or _grab_cooldown > 0.0 or velocity.y > 1.0 or dir.length() < 0.1:
		return false
	var fwd := dir.normalized()
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.3
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 0.55, collision_mask, [get_rid()])
	var hit := space.intersect_ray(q)
	if hit.is_empty() or absf(hit.normal.y) > 0.3:
		return false
	var n: Vector3 = hit.normal
	n.y = 0.0
	n = n.normalized()
	if n.dot(fwd) > -0.5:
		return false
	# Dò mặt mép: tia đi xuống ngay sau mặt tường (lan can chỉ dày 6 cm)
	var top_from: Vector3 = hit.position - n * 0.03
	top_from.y = global_position.y + ledge_reach + 0.05
	var down := top_from
	down.y = global_position.y + ledge_min
	var h2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(top_from, down, collision_mask, [get_rid()]))
	if h2.is_empty() or h2.normal.y < 0.7:
		return false
	var ledge_y: float = h2.position.y
	var on_top: Vector3 = hit.position - n * 0.32
	on_top.y = ledge_y + 0.02
	if _shape_hits(_stand_shape, Transform3D(Basis.IDENTITY, on_top)):
		return false  # trên mép không đủ chỗ (sát trần, sát tường khác)
	climb = "hang"
	_climb_t = 0.0
	_wall_n = n
	_pull_to = on_top
	velocity = Vector3.ZERO
	global_position = Vector3(hit.position.x, ledge_y - 0.5, hit.position.z) + n * 0.27
	visual.rotation.y = atan2(n.x, n.z)
	visual.scale = Vector3(0.9, 1.15, 0.9)
	ledge_grabbed.emit()
	return true


## Ôm ống nước: đang chạm ống và đẩy về phía tường sau ống.
func _try_pipe(dir: Vector3) -> bool:
	if _pipes.is_empty() or _grab_cooldown > 0.0:
		return false
	var p: Node3D = _pipes.back()
	var n: Vector3 = p.get_meta("normal", Vector3.BACK)
	if dir.length() < 0.1 or dir.normalized().dot(-n) < 0.4:
		return false
	if global_position.y > float(p.get_meta("top", 99.0)) - 0.3:
		return false
	climb = "pipe"
	_pipe = p
	_wall_n = n
	_climb_t = 0.0
	velocity = Vector3.ZERO
	visual.rotation.y = atan2(n.x, n.z)
	return true


## Bật tường: đang bay, sát tường, sau lưng có tường thứ hai trong wall_gap_max (khe giữa hai nhà).
func _try_wall_kick() -> void:
	if _kicks >= wall_kick_max or not is_on_wall():
		return
	var n := get_wall_normal()
	n.y = 0.0
	if n.length() < 0.5:
		return
	n = n.normalized()
	var from := global_position + Vector3.UP * 0.3
	var q := PhysicsRayQueryParameters3D.create(from, from + n * wall_gap_max, collision_mask, [get_rid()])
	if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return  # tường đơn ngoài trời rộng: không bật được
	_kicks += 1
	_buffer = 0.0
	_kick_lock = 0.18
	velocity = n * wall_kick_out + Vector3.UP * wall_kick_up
	visual.rotation.y = atan2(-n.x, -n.z)
	visual.scale = Vector3(0.8, 1.25, 0.8)
	noise_made.emit(global_position, noise_walk)
	wall_kicked.emit(_kicks)


func _climb_process(delta: float) -> void:
	_climb_t += delta
	var jump := can_move and Input.is_action_just_pressed("jump")
	var drop := can_move and (_pressed("crouch") or Input.is_action_pressed("move_back"))
	match climb:
		"hang":
			velocity = Vector3.ZERO
			if jump:
				climb = "pull"
				_climb_t = 0.0
				_pull_from = global_position
				noise_made.emit(global_position, noise_sneak)
			elif drop and _climb_t > 0.15:
				_release(Vector3.ZERO)
		"pull":
			var u := clampf(_climb_t / pull_time, 0.0, 1.0)
			# Lên trước (móng bám, chân sau đạp), rồi mới nhích tới mặt mép
			var up := smoothstep(0.0, 0.7, u)
			var fwd := smoothstep(0.45, 1.0, u)
			global_position = Vector3(lerpf(_pull_from.x, _pull_to.x, fwd), lerpf(_pull_from.y, _pull_to.y, up), lerpf(_pull_from.z, _pull_to.z, fwd))
			if u >= 1.0:
				climb = ""
				velocity = Vector3.ZERO
				_kicks = 0
				_fall_from = global_position.y
				ledge_climbed.emit()
		"pipe":
			var p := _pipe
			var target := p.global_position + _wall_n * 0.24
			var v := 0.0
			if can_move and Input.is_action_pressed("move_forward"):
				v = pipe_speed
			elif can_move and Input.is_action_pressed("move_back"):
				v = -pipe_speed * 1.6
			var y := clampf(global_position.y + v * delta, p.global_position.y, float(p.get_meta("top", 99.0)) - 0.3)
			global_position = Vector3(target.x, y, target.z)
			velocity = Vector3(0, v, 0)
			if jump:
				# Nhảy khỏi ống: bật ra sau và lên, hướng phím trái/phải đẩy sang ngang
				var side := Input.get_axis("move_left", "move_right")
				var right := Vector3.UP.cross(_wall_n).normalized()
				_release(_wall_n * 2.5 + right * side * 2.5 + Vector3.UP * jump_velocity * 0.8)
				_kick_lock = 0.2
				jumped.emit()
			elif _pressed("crouch") or (v < 0.0 and y <= p.global_position.y + 0.01):
				_release(_wall_n * 1.0)
	_curr_pos = global_position


func _release(vel: Vector3) -> void:
	climb = ""
	_pipe = null
	velocity = vel
	_grab_cooldown = 0.35
	_fall_from = global_position.y


## Ống nước (Area3D của cảnh) gọi khi Bơ chạm/rời. Ống có meta "normal" (hướng ra khỏi tường) và "top" (độ cao đầu ống).
func enter_pipe(p: Node3D) -> void:
	if p not in _pipes:
		_pipes.append(p)


func exit_pipe(p: Node3D) -> void:
	_pipes.erase(p)
	if p == _pipe and climb == "pipe":
		_release(_wall_n * 1.0)


## Góc nhìn thứ nhất: camera không vẽ thân Bơ, nhưng bóng đổ của Bơ vẫn đủ cả đầu lẫn đuôi.
func set_first_person(v: bool, cam: Camera3D = null) -> void:
	first_person = v
	if cam:
		cam.cull_mask = (0xFFFFF & ~LAYER_BO_BODY) if v else (0xFFFFF & ~LAYER_FP_PAWS)


## Hai chân trước dùng chung (BoPaw, tư thế đứng) cho góc thứ nhất: cúi xuống là thấy chân Bơ bước.
## Vai đặt ngay dưới camera, chân chống chéo ra trước nên đầu ống ở vai nằm ngoài tầm nhìn,
## bàn chân xoay ngược lại để vẫn đặt phẳng trên đất. Mỗi chân vung theo nhịp chân của thân Bơ.
func _build_fp_paws() -> void:
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		visual.add_child(pivot)
		var paw := BoPaw.create(side, FP_PAW_SIZE, "dung")
		pivot.add_child(paw)
		var shoulder := paw.top_point() * FP_PAW_SIZE  # điểm vai do BoPaw báo, đổi dáng chân không phải sửa ở đây
		pivot.position = Vector3(side * 0.056, shoulder.y, 0.03)
		paw.position = -shoulder
		paw.foot.rotation.x = -FP_PAW_LEAN
		for mi: MeshInstance3D in paw.find_children("*", "MeshInstance3D", true, false):
			mi.layers = LAYER_FP_PAWS
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fp_paws.append(pivot)


## Chọn dáng đi: chui (giữ Ctrl/C, hoặc tự chui khi chạy vào gầm thấp và ở yên dưới đó),
## rón rén (giữ Alt), chạy nhanh (Shift), còn lại là đi.
func _update_stance(dir: Vector3, on_floor: bool) -> void:
	var want_crouch := can_move and _pressed("crouch")
	if not want_crouch and stance == "crouch" and _blocked_above():
		want_crouch = true  # còn ở dưới gầm thì không đứng dậy được
	if not want_crouch and on_floor and dir.length() > 0.1 and _low_gap_ahead(dir):
		want_crouch = true  # chạy tới gầm thấp: tự cúi người chui vào
	var s := "walk"
	if want_crouch:
		s = "crouch"
	elif can_move and _pressed("sneak"):
		s = "sneak"
	elif Input.is_action_pressed("sprint") and dir.length() > 0.1:
		s = "sprint"
	if s != stance:
		var was_crouch := stance == "crouch"
		stance = s
		if was_crouch != (s == "crouch"):
			_stand_shape.disabled = s == "crouch"
			_crouch_shape.disabled = s != "crouch"
		stance_changed.emit(s)


## Trên đầu có vật chắn: dáng đứng sẽ va vào nó.
func _blocked_above() -> bool:
	return _shape_hits(_stand_shape, global_transform)


## Phía trước là gầm thấp: đứng thì đụng, chui thì lọt.
func _low_gap_ahead(dir: Vector3) -> bool:
	var xf := global_transform.translated(dir.normalized() * 0.3)
	return _shape_hits(_stand_shape, xf) and not _shape_hits(_low_probe, xf)


## Phím chưa khai báo (vd màn bếp không có chui/rón rén) thì coi như không bấm, khỏi báo lỗi mỗi khung hình.
func _pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)


func _shape_hits(cs: CollisionShape3D, xf: Transform3D) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cs.shape
	q.transform = xf * cs.transform
	q.collision_mask = collision_mask
	q.exclude = [get_rid()]
	q.margin = 0.01
	# Bỏ qua mặt đất: nâng nhẹ khối kiểm tra lên khỏi sàn
	q.transform.origin.y += 0.04
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Đụng thùng, đồ nhỏ khi đang chạy (không phải rón rén/chui) thì kêu lớn.
func _check_bump(speed_before: float, delta: float) -> void:
	_bump_cooldown = maxf(_bump_cooldown - delta, 0.0)
	if _bump_cooldown > 0.0 or speed_before < walk_speed * 0.6 or stance in ["sneak", "crouch"]:
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider() as CollisionObject3D
		if body and body.collision_layer & Blocks.LAYER_PROP and absf(c.get_normal().y) < 0.5:
			noise_made.emit(c.get_position(), noise_bump)
			_bump_cooldown = 0.6
			return


## Mỗi bước chân phát một tiếng động nhỏ theo dáng đi. Gọi từ _animate khi nhịp bước đổi dấu.
func _footstep() -> void:
	var r: float = {"walk": noise_walk, "sprint": noise_sprint, "crouch": noise_sneak, "sneak": noise_sneak}[stance]
	noise_made.emit(global_position, r)
	if stance == "sneak":
		_sfx("sneak")


## Động tác giao bánh. kind: "hand" (đưa tận tay), "basket" (bỏ vào giỏ thòng dây),
## "counter" (nhảy đặt lên quầy), "under_car" (chui đẩy vào gầm xe), "chair" (đặt lên ghế mây).
## Bơ đứng yên trong lúc diễn, xong phát deliver_finished(kind).
func play_deliver(kind: String) -> void:
	_act = "deliver"
	_act_kind = kind
	_act_t = 0.0
	_act_len = {"hand": 0.9, "basket": 1.0, "counter": 1.1, "under_car": 1.2, "chair": 1.0}.get(kind, 0.9)
	velocity.x = 0.0
	velocity.z = 0.0
	if kind == "counter" and is_on_floor():
		velocity.y = jump_velocity * 0.75


## Giật mình: nhảy dựng tại chỗ, lông đuôi xù, tai cụp, khựng lại một chút.
func play_startle() -> void:
	_act = "startle"
	_act_t = 0.0
	_act_len = 0.6
	if is_on_floor():
		velocity.y = jump_velocity * 0.45
	visual.scale = Vector3(0.85, 1.25, 0.85)
	for i in 2:
		_ear[i].v += 10.0
	startled.emit()


## Phát tiếng qua autoload Sound nếu có (chạy test riêng bằng -s thì không có autoload).
func _sfx(name: String) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd:
		snd.play(name)


## Vũng dầu (gói giao bánh đặt Area3D) gọi khi Bơ bước vào/ra.
func enter_oil() -> void:
	_oil += 1


func exit_oil() -> void:
	_oil = maxi(_oil - 1, 0)


## Vị trí mèo đã nội suy giữa hai nhịp vật lý: camera và mũi tên bám theo vị trí này.
func smooth_position() -> Vector3:
	return _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())


func _process(delta: float) -> void:
	visual.global_position = smooth_position()
	visual.scale = visual.scale.lerp(Vector3.ONE, 1.0 - exp(-12.0 * delta))
	_animate(delta, Vector2(velocity.x, velocity.z).length(), velocity.y, preview or is_on_floor())


## Animation tạm bằng code cho cả người, không chỉ chân.
## Tuần 2 sẽ thay bằng AnimationTree với animation làm trong Blender; phần lò xo phụ vẫn giữ.
## - Chân vung theo bước, thân nhún.
## - Thân nghiêng vào trong khi quẹo, chúi tới khi tăng tốc, ngả ra sau khi phanh, thở khi đứng.
## - Đầu gật nhẹ theo bước, nhìn trước về hướng quẹo, giữ thăng bằng khi thân nghiêng;
##   đứng yên lâu thì ngó quanh.
## - Tai cụp ra sau khi chạy nhanh, dựng lên khi nhảy, thỉnh thoảng giật tai.
## - Mắt chớp mỗi vài giây, chớp khi tiếp đất.
## - Khăn đung đưa theo quán tính. Đuôi xem _update_tail.
func _animate(delta: float, hspeed: float, vy: float, on_floor: bool) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var k := clampf(hspeed / sprint_speed, 0.0, 1.0)
	var acc := (hspeed - _last_hspeed) / maxf(delta, 0.001)
	_last_hspeed = hspeed
	_accel = lerpf(_accel, acc, 1.0 - exp(-10.0 * delta))
	var landed_now := on_floor and not _was_floor_anim
	_was_floor_anim = on_floor

	# Dáng tạm cho chui/rón rén (thay bằng tư thế Blender khi Sang duyệt bản phác)
	var crouch_t := 1.0 if stance == "crouch" else 0.0
	crouch_amount = move_toward(crouch_amount, crouch_t, delta * 6.0)
	var sneak_k := 1.0 if stance == "sneak" else 0.0
	# Động tác: u chạy 0→1 trong thời gian diễn, pose = 0→1→0
	var act_u := clampf(_act_t / maxf(_act_len, 0.01), 0.0, 1.0) if _act != "" else 0.0
	var act_pose := sin(act_u * PI) if _act != "" else 0.0
	# Bước dài và chậm hơn khi rón rén, ngắn và nhanh khi chui
	var gait := 2.2 if stance in ["walk", "sprint"] else (1.6 if stance == "sneak" else 3.0)
	# Chân và nhún người
	if on_floor:
		_phase += delta * (4.0 + hspeed * gait)
		var swing := sin(_phase) * 0.9 * maxf(k, 0.35 if hspeed > 0.3 else 0.0)
		if stance == "crouch":
			swing *= 0.6
		_legs = [swing, -swing, -swing, swing]
		if _sliding:
			_legs = [0.7, 0.7, -0.7, -0.7]  # trượt dầu: chân dạng ra, cứng đơ
		_body.position.y = absf(sin(_phase)) * 0.04 * k
		var side := signf(sin(_phase))
		if hspeed > 0.3 and side != 0.0 and side != _step_side:
			_step_side = side
			_footstep()
	else:
		# Trên không: chân trước duỗi, chân sau co
		var tl := 1.0 - exp(-10.0 * delta)
		for i in 4:
			_legs[i] = lerpf(_legs[i], 0.8 if i < 2 else -0.8, tl)
	# Leo (tạm, thay bằng tư thế Blender trên rig 22 xương): bám thì chân trước vươn lên mép,
	# chân sau buông; leo lên thì chân sau đạp; ôm ống thì bốn chân thay nhau với
	var climb_u := clampf(_climb_t / pull_time, 0.0, 1.0)
	match climb:
		"hang":
			_legs = [-1.3, -1.3, 0.35 + sin(t * 3.0) * 0.08, 0.35 - sin(t * 3.0) * 0.08]
		"pull":
			_legs = [lerpf(-1.3, 0.2, climb_u), lerpf(-1.3, 0.2, climb_u), sin(climb_u * TAU * 2.0) * 0.9, -sin(climb_u * TAU * 2.0) * 0.9]
		"pipe":
			_phase += delta * absf(vy) * 6.0
			var c := sin(_phase) * 0.6
			_legs = [-0.9 + c, -0.9 - c, 0.5 - c, 0.5 + c]

	_update_tail(delta, hspeed, vy, on_floor)

	# Thân: nghiêng khi quẹo (vào phía trong vòng), chúi/ngả theo gia tốc, ngẩng khi bay lên
	var lean_target := clampf(_yaw_rate * k * 0.07, -0.22, 0.22)
	var pitch_target := clampf(-_accel * 0.012, -0.12, 0.12)
	if not on_floor:
		pitch_target = clampf(vy * 0.04, -0.3, 0.3)
	if _sliding:
		lean_target += sin(t * 9.0) * 0.18  # chao đảo
	if _act == "deliver":
		# Đưa tận tay/đặt quầy/ghế: ngẩng lên; gầm xe: chúi xuống đẩy vào; giỏ: vươn cao
		pitch_target += act_pose * {"hand": 0.25, "basket": 0.45, "counter": 0.2, "under_car": -0.3, "chair": 0.3}.get(_act_kind, 0.2)
	elif _act == "startle":
		pitch_target += act_pose * 0.35
	if climb in ["hang", "pipe"]:
		pitch_target = 1.15  # thân dựng đứng áp vào tường
	elif climb == "pull":
		pitch_target = lerpf(1.15, -0.1, climb_u)
	_body.rotation.z = _lean.step(lean_target, 120.0, 0.7, delta)
	_body.rotation.x = _pitch.step(pitch_target, 150.0, 0.6, delta)
	if landed_now:
		_pitch.v -= 2.5  # tiếp đất: thân khựng chúi tới rồi bật lại

	# Thở khi đứng yên: ngực phồng nhẹ
	var breath := sin(t * 2.4) * (1.0 - k)
	_body.scale = Vector3(1.0 + 0.012 * breath, 1.0 + 0.008 * breath, 1.0 + 0.006 * breath)
	# Chui: ép thân thấp xuống 0,25 m (tạm); rón rén: hạ thấp người
	var low := lerpf(1.0, 0.45, crouch_amount) * lerpf(1.0, 0.85, sneak_k)
	_body.scale *= Vector3(lerpf(1.0, 1.12, crouch_amount), low, lerpf(1.0, 1.08, crouch_amount))
	if _act == "deliver" and _act_kind == "under_car":
		_body.scale.y *= lerpf(1.0, 0.6, act_pose)

	# Đầu: nhìn về hướng quẹo, gật ngược nhịp nhún, giữ thăng bằng khi thân chúi
	_idle_time = _idle_time + delta if (hspeed < 0.3 and on_floor) else 0.0
	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = randf_range(1.8, 4.0)
		_look_target = Vector2(randf_range(-0.55, 0.55), randf_range(-0.12, 0.18)) if randf() < 0.7 else Vector2.ZERO
	var look := _look_target if _idle_time > 1.5 else Vector2.ZERO
	var yaw_target := clampf(_yaw_rate * 0.13, -0.45, 0.45) + look.x
	var nod := sin(_phase * 2.0 + 0.6) * 0.06 * k if on_floor else 0.0
	var head_pitch_target := look.y + nod - _body.rotation.x * 0.7
	head_pitch_target += sneak_k * 0.25 + crouch_amount * 0.1   # rón rén: cúi đầu, mắt nhìn tới
	if _act == "deliver":
		head_pitch_target -= act_pose * 0.35  # ngửa đầu đưa ổ bánh tới
	if not on_floor:
		head_pitch_target += clampf(-vy * 0.03, -0.25, 0.2)  # rơi thì cúi nhìn chỗ đáp
	_head_yaw.step(yaw_target, 60.0, 0.8, delta)
	_head_pitch.step(head_pitch_target, 90.0, 0.65, delta)

	# Tai: chạy nhanh thì cụp ra sau, bay lên thì dựng; nảy khi tiếp đất; thỉnh thoảng giật
	var ear_target := k * 0.55 - (0.25 if not on_floor and vy > 0.0 else 0.0)
	ear_target += sneak_k * 0.35 + crouch_amount * 0.3   # rón rén/chui: tai xuôi ra sau
	if _act == "startle":
		ear_target = 1.0  # giật mình: tai cụp hẳn
	for i in 2:
		_ear[i].step(ear_target, 140.0, 0.35, delta)
		if landed_now:
			_ear[i].v += 4.0
		_ear_flick[i] = move_toward(_ear_flick[i], 0.0, delta * 6.0)
	_flick_timer -= delta
	if _flick_timer <= 0.0:
		_flick_timer = randf_range(2.5, 6.0)
		_ear_flick[randi() % 2] = 1.0

	# Mắt: chớp nhanh (0,15 s), thỉnh thoảng chớp hai lần
	_blink_timer -= delta
	if _blink_timer <= 0.0 or landed_now:
		_blink_timer = randf_range(2.5, 5.0) if randf() < 0.8 else 0.25
		_blink = 1.0
	_blink = move_toward(_blink, 0.0, delta / 0.15)

	# Khăn: văng ngược hướng tăng tốc, lệch ra ngoài khi quẹo, nảy theo bước
	var scarf_p_target := clampf(_accel * 0.03, -0.5, 0.5) + k * 0.25
	_scarf_p.step(scarf_p_target, 45.0, 0.25, delta)
	_scarf_r.step(clampf(-_yaw_rate * 0.1, -0.5, 0.5), 45.0, 0.25, delta)
	if on_floor and k > 0.05:
		_scarf_p.v += cos(_phase * 2.0) * k * 6.0 * delta

	_apply_bones()


## Xoay xương theo các góc tính ở trên. Trục X của xương là trục gập trước/sau.
func _apply_bones() -> void:
	for i in 4:
		_pose(LEG_BONES[i], Vector3.RIGHT, _legs[i] * LEG_SWING_SIGN)
	for i in _fp_paws.size():
		# Thân Bơ quay ngược 180° trong visual nên trục X đổi chiều
		_fp_paws[i].rotation.x = FP_PAW_LEAN - _legs[i] * LEG_SWING_SIGN
	_pose_q("head", Quaternion(Vector3.UP, _head_yaw.x) * Quaternion(Vector3.RIGHT, _head_pitch.x))
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var flick := sin(_ear_flick[i] * PI) * 0.5
		_pose_q(["ear_L", "ear_R"][i], Quaternion(Vector3.RIGHT, _ear[i].x + flick) * Quaternion(Vector3.FORWARD, side * flick * 0.6))
	for eye in ["eye_L", "eye_R"]:
		var idx: int = _bone_idx[eye]
		if idx >= 0:
			_skel.set_bone_pose_scale(idx, Vector3(1.0, 1.0 - 0.9 * sin(_blink * PI * 0.5), 1.0))
	_pose_q("scarf", Quaternion(Vector3.RIGHT, _scarf_p.x) * Quaternion(Vector3.FORWARD, _scarf_r.x))
	for i in 4:
		_pose_q(TAIL_BONES[i], Quaternion(Vector3.RIGHT, -_tail_p[i]) * Quaternion(Vector3.BACK, _tail_y[i]))


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
		if stance == "sneak" or stance == "crouch":
			a += 0.3 * (1.0 if i < 2 else 0.4)  # đuôi hạ thấp, giữ ngang
		if _act == "startle":
			a = -0.7 if i < 2 else -0.2  # giật mình: đuôi dựng đứng
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


func _pose_q(bone_name: String, q: Quaternion) -> void:
	var idx: int = _bone_idx[bone_name]
	if idx >= 0:
		_skel.set_bone_pose_rotation(idx, _bone_rest[bone_name] * q)


func _pose(bone_name: String, axis: Vector3, angle: float) -> void:
	var idx: int = _bone_idx[bone_name]
	if idx >= 0:
		_skel.set_bone_pose_rotation(idx, _bone_rest[bone_name] * Quaternion(axis, angle))


## Bị Chó Mực đớp: văng ra và khựng lại một chút.
func knockback(from: Vector3, strength := 9.0, stun := 0.45) -> void:
	var away := global_position - from
	away.y = 0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	play_startle()
	velocity = away * strength + Vector3.UP * 4.5
	_stun = stun
	visual.scale = Vector3(1.3, 0.7, 1.3)
