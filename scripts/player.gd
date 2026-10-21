extends CharacterBody3D
## Mèo Bơ bản khối thô: chạy, chạy nhanh, nhảy, mang túi bánh.
## Cảm giác tay được chỉnh bằng các biến @export bên dưới (xem trong Inspector khi chạy).

signal jumped
signal landed
## Bơ gây tiếng động: Chó Mực (và ai muốn nghe) nghe thấy nếu ở trong bán kính radius (mét)
signal noise_made(pos: Vector3, radius: float)
signal stance_changed(stance: String)   ## HUD hiện chấm chỉ báo khi rón rén/chui
signal deliver_finished(kind: String)   ## xong động tác giao bánh
signal bread_released(kind: String)     ## lúc nhả ổ bánh khỏi miệng (0,8 s khi giao cao, 0,7 s khi giao thấp)
signal startled                         ## giật mình (bị đớp, xe tông)
signal slipped                          ## bắt đầu trượt trên vũng dầu

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
var _released := false
# Mức hoà các tư thế đã duyệt (0..1), để chuyển qua lại mượt
var _sneak_amt := 0.0
var _slide_amt := 0.0
var _head_off := Vector3.ZERO     ## dời xương đầu (hệ model: +Y lên, +Z ra trước)
var _head_roll := 0.0
var _ear_spread := 0.0
var _tail_fluff := 0.0
var _eye_big := 0.0
var _leg_extra := [0.0, 0.0, 0.0, 0.0]   ## góc cộng thêm cho từng chân theo tư thế
var _fr_sweep := 0.0              ## chân trước phải vung ngang khi trượt
var _mouth_bread: Node3D          ## ổ bánh gói giấy ngậm ở miệng khi giao
var _bob := 0.0                   ## nhún người theo bước
const BANH_GOI := preload("res://assets/models/do/banh_goi.glb")
const MOUTH := Vector3(0, 0.368, 0.30)   ## điểm miệng trong hệ model Bơ (đã duyệt)

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
var preview := false             ## tủ đồ/màn hình chính: đứng yên trên bục, không có vật lý, thỉnh thoảng ngồi hoặc liếm chân
var breed := "bo"                ## giống mèo đang dùng (tủ đồ cho mặc thử giống khác)
var _model: Node3D
var _acc_nodes := []             # phụ kiện đang gắn (OutfitView.attach)
var _ears_down := false          # đội nón che tai: tai cụp xuống
var _action := ""                # động tác chờ khi preview: "sit" | "lick" | ""
var _sit_w := Spring.new()
var _lick_w := Spring.new()    # 0..1: mức đang làm động tác
var _action_timer := 6.0
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
var _sit := 0.0
var _lick := 0.0
var _off_legs := [0.0, 0.0, 0.0, 0.0]  # cộng thêm cho động tác chờ (ngồi, liếm chân)
var _off_head := Vector2.ZERO          # (xoay ngang, cúi)
var _off_tail := 0.0
var _sit_pivot := Vector3(0, 0.22, -0.13)
## Góc động tác chờ (rad), chỉnh ở đây
const SIT_PITCH := 0.45        # thân ngẩng lên khi ngồi
const SIT_HIND := 0.75         # chân sau gập tới trước, nằm sát sàn
const LICK_PAW := 1.5          # đang ngồi, chân trước trái nhấc lên tới miệng
const LICK_HEAD := 0.6         # cúi đầu xuống chân
const SIT_TAIL := 0.5          # đuôi nhấc lên khỏi sàn khi ngồi


## Lò xo giảm chấn một chiều: đuổi theo đích, có quán tính nên chuyển động không bị giật cục.
class Spring:
	var x := 0.0
	var v := 0.0

	func step(target: float, stiff: float, damping: float, dt: float) -> float:
		# Chia nhỏ bước (≤ 1/120 s): máy yếu chạy 5–10 FPS thì một bước lớn làm lò xo nổ tung
		var n := maxi(1, ceili(dt * 120.0))
		var h := dt / n
		for i in n:
			v += ((target - x) * stiff - v * 2.0 * sqrt(stiff) * damping) * h
			x += v * h
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

	_load_model()
	_build_bag()
	_build_mouth_bread()
	apply_outfit()
	# Thân, khăn, túi và quai: góc nhìn thứ nhất không vẽ (vẫn đổ bóng), thay bằng hai chân trước riêng
	for mi: MeshInstance3D in _body.find_children("*", "MeshInstance3D", true, false):
		mi.layers = LAYER_BO_BODY
	_build_fp_paws()


## Dựng model của giống đang chọn (Bơ hoặc giống skin cùng bộ xương, xem tools/xuat_skin_game.py).
func _load_model() -> void:
	if _model:
		_model.free()
	_acc_nodes.clear()
	_scarf_mesh = null
	var scene: PackedScene = OutfitView.breed_scene(breed)
	_model = (scene if scene else BO_MODEL).instantiate()
	_model.rotation.y = PI  # model quay mặt về +Z (glTF), Godot coi -Z là phía trước
	_body.add_child(_model)
	_skel = _model.find_children("*", "Skeleton3D", true, false)[0]
	for bone_name in BONE_NAMES:
		var idx := _skel.find_bone(bone_name)
		_bone_idx[bone_name] = idx
		_bone_rest[bone_name] = _skel.get_bone_rest(idx).basis.get_rotation_quaternion() if idx >= 0 else Quaternion.IDENTITY
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		_apply_style(mi)
		mi.layers = LAYER_BO_BODY
	# Khớp vai trước: ngồi xuống thì thân xoay quanh đây để bàn chân trước đứng yên trên sàn
	var fl: int = _bone_idx["leg_FL"]
	if fl >= 0:
		_sit_pivot = _model.transform * _skel.get_bone_global_rest(fl).origin
		_sit_pivot.x = 0.0


## Đổi giống mèo (tủ đồ mặc thử). Giống chưa có model thì giữ Bơ.
func set_breed(id: String, worn := {}) -> void:
	breed = id if OutfitView.has_breed(id) else "bo"
	_load_model()
	_build_mouth_bread()
	apply_outfit(worn)


## Ổ bánh gói giấy gắn vào xương đầu ở điểm miệng, chỉ hiện lúc giao (rút từ túi ra ngậm).
func _build_mouth_bread() -> void:
	var hi: int = _bone_idx.get("head", -1)
	if hi < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "head"
	_skel.add_child(att)
	_mouth_bread = BANH_GOI.instantiate()
	_mouth_bread.transform = _skel.get_bone_global_rest(hi).affine_inverse() * Transform3D(Basis(), MOUTH)
	_mouth_bread.visible = false
	att.add_child(_mouth_bread)
	for mi: MeshInstance3D in _mouth_bread.find_children("*", "MeshInstance3D", true, false):
		mi.layers = LAYER_BO_BODY


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


## Mặc đồ theo tủ đồ (Outfit). worn = {ô: id} để mặc thử trong tủ đồ; để trống thì lấy đồ đã mặc.
## Trên Bơ, khăn quàng đỏ là một phần của model và túi bánh dựng bằng code (túi chứa ổ bánh khi giao);
## món khác và mọi món trên giống khác lấy từ model phụ kiện. Túi tháo rồi thì chỉ hiện lúc mang bánh.
func apply_outfit(worn := {}) -> void:
	if worn.is_empty():
		for s in Outfit.SLOTS:
			worn[s[0]] = Outfit.worn(s[0])
	for n in _acc_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_acc_nodes.clear()
	var is_bo := breed == "bo"
	_wear_bag = is_bo and worn.get("back", "") == "tuibanh"
	if _bag:
		_bag.visible = carrying or _wear_bag
	if _scarf_mesh:
		if _hidden_mat == null:
			_hidden_mat = StandardMaterial3D.new()
			_hidden_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			_hidden_mat.albedo_color = Color(1, 1, 1, 0)
		var on: bool = worn.get("neck", "") == "khando"
		_scarf_mesh.set_surface_override_material(_scarf_surface, _scarf_mat if on else _hidden_mat)
	_ears_down = false
	for slot in worn:
		var id: String = worn[slot]
		if id == "" or (is_bo and id in ["khando", "tuibanh"]):
			continue
		_acc_nodes.append_array(OutfitView.attach(_skel, id, breed))
		_ears_down = _ears_down or OutfitView.ears_down(id)


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
	if can_move and _stun <= 0.0 and _act == "":
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
	var hv := Vector2(velocity.x, velocity.z).move_toward(target, accel * delta)
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
	if _act == "deliver" and not _released and _act_t >= (0.7 if _act_kind == "under_car" else 0.8):
		_released = true
		if _mouth_bread:
			_mouth_bread.visible = false  # ẩn ngay để không thấy hai ổ (ổ bay đi do deliveries.gd vẽ)
		bread_released.emit(_act_kind)
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
	# giao_cao 1,2 s (đứng lên, nhả bánh ở 0,8 s) hoặc giao_thap 1,0 s (dáng chui đẩy bánh), rồi giao_xong 0,4 s
	_act_len = (1.0 if kind == "under_car" else 1.2) + 0.4
	_released = false
	velocity.x = 0.0
	velocity.z = 0.0


## Giật mình: bật lên tại chỗ, cong lưng, tai dựng xoè, đuôi dựng thẳng xù to, mắt mở to.
func play_startle() -> void:
	_act = "startle"
	_act_t = 0.0
	_act_len = 0.6
	if is_on_floor():
		velocity.y = sqrt(2.0 * gravity * 0.09)  # bật lên 0,09 m
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

	# Tư thế đã duyệt (trang phác thảo động tác Thứ Hai), làm tạm trên 16 xương:
	# chui vào/ra 0,25 s; rón rén; trượt dầu; giao cao/thấp; giật mình.
	crouch_amount = move_toward(crouch_amount, 1.0 if stance == "crouch" else 0.0, delta / 0.25)
	_sneak_amt = move_toward(_sneak_amt, 1.0 if stance == "sneak" else 0.0, delta / 0.3)
	_slide_amt = move_toward(_slide_amt, 1.0 if _sliding else 0.0, delta / (0.15 if _sliding else 0.4))
	var sneak_k := _sneak_amt
	# Giao: lên dáng trong 0,3 s, giữ, rồi giao_xong 0,4 s cuối trở về
	var dw := 0.0
	if _act == "deliver":
		dw = smoothstep(0.0, 0.3, _act_t) * (1.0 - smoothstep(_act_len - 0.4, _act_len, _act_t))
	var high := dw if _act_kind != "under_car" else 0.0   # giao_cao: đứng lên hai chân sau
	var low := dw if _act_kind == "under_car" else 0.0    # giao_thap: dáng chui đẩy bánh
	var startle := sin(clampf(_act_t / 0.6, 0.0, 1.0) * PI) if _act == "startle" else 0.0
	var cr := maxf(crouch_amount, low)                     # độ chui (kể cả lúc giao thấp)
	if _mouth_bread:
		_mouth_bread.visible = _act == "deliver" and _act_t > 0.25 and not _released
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
			_legs = [0.35, 0.0, -0.3, -0.3]  # trượt dầu: chân cứng đơ
		_bob = absf(sin(_phase)) * 0.04 * k
		var side := signf(sin(_phase))
		if hspeed > 0.3 and side != 0.0 and side != _step_side:
			_step_side = side
			_footstep()
	else:
		# Trên không: chân trước duỗi, chân sau co
		var tl := 1.0 - exp(-10.0 * delta)
		for i in 4:
			_legs[i] = lerpf(_legs[i], 0.8 if i < 2 else -0.8, tl)

	_update_tail(delta, hspeed, vy, on_floor)

	# Thân: nghiêng khi quẹo (vào phía trong vòng), chúi/ngả theo gia tốc, ngẩng khi bay lên
	var lean_target := clampf(_yaw_rate * k * 0.07, -0.22, 0.22)
	var pitch_target := clampf(-_accel * 0.012, -0.12, 0.12)
	if not on_floor:
		pitch_target = clampf(vy * 0.04, -0.3, 0.3)
	lean_target += _slide_amt * (deg_to_rad(11.0) + sin(t * 9.0) * 0.06)  # trượt: nghiêng 11°, chao nhẹ
	pitch_target -= deg_to_rad(3.0) * sneak_k                            # rón rén: chúi 3°
	pitch_target += deg_to_rad(54.0) * high                              # giao cao: ngửa thân 54° quanh hông
	_body.rotation.z = _lean.step(lean_target, 120.0, 0.7, delta)
	_body.rotation.x = _pitch.step(pitch_target, 150.0, 0.6, delta)
	_body.rotation.y = deg_to_rad(6.0) * _slide_amt
	if landed_now:
		_pitch.v -= 2.5  # tiếp đất: thân khựng chúi tới rồi bật lại
	# Xoay quanh hông (0; 0,2; 0,15 trong hệ visual, hông ở phía sau) thay vì quanh chân
	var hip := Vector3(0, 0.2, 0.15)
	_body.position = hip - Basis.from_euler(_body.rotation) * hip + Vector3(0, _bob - 0.13 * cr - 0.05 * sneak_k, 0)

	# Thở khi đứng yên: ngực phồng nhẹ
	var breath := sin(t * 2.4) * (1.0 - k)
	_body.scale = Vector3(1.0 + 0.012 * breath, 1.0 + 0.008 * breath, 1.0 + 0.006 * breath)
	# Chui: nén cao 0,78, dài 1,1; giật mình: cong lưng (cao thêm 5%)
	_body.scale *= Vector3(1.0, lerpf(1.0, 0.78, cr) * (1.0 + 0.05 * startle), lerpf(1.0, 1.1, cr))
	# Chân: chui thì chân trước xoè ra trước 45°, chân sau ra sau 40°; giao cao thì hai chân trước co
	# trước ngực, chân sau bù góc ngửa để vẫn đứng trên đất
	# (góc xương chân: dương là vung ra sau theo hệ model)
	var pre := -deg_to_rad(45.0) * cr - deg_to_rad(30.0) * high
	var hind := deg_to_rad(40.0) * cr + deg_to_rad(54.0) * high
	_leg_extra = [pre, pre, hind, hind]
	_fr_sweep = _slide_amt * 0.9
	# Đầu: chui hạ 0,15 m, đẩy trước 0,075; rón rén hạ 0,085, đẩy trước 0,055
	_head_off = Vector3(0, -0.15, 0.075) * cr + Vector3(0, -0.085, 0.055) * sneak_k
	_head_roll = -deg_to_rad(10.0) * _slide_amt
	_tail_fluff = startle
	_eye_big = startle
	_ear_spread = startle

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
	head_pitch_target += deg_to_rad(8.0) * sneak_k               # rón rén: cúi 8°
	# Giao cao: so với thân, đầu cúi 36° (thân ngửa 54° nên mặt vẫn ngước lên)
	head_pitch_target += (deg_to_rad(36.0) + 0.7 * deg_to_rad(54.0)) * high
	if not on_floor:
		head_pitch_target += clampf(-vy * 0.03, -0.25, 0.2)  # rơi thì cúi nhìn chỗ đáp
	_head_yaw.step(yaw_target, 60.0, 0.8, delta)
	_head_pitch.step(head_pitch_target, 90.0, 0.65, delta)

	# Tai: chạy nhanh thì cụp ra sau, bay lên thì dựng; nảy khi tiếp đất; thỉnh thoảng giật
	var ear_target := k * 0.55 - (0.25 if not on_floor and vy > 0.0 else 0.0)
	ear_target += sneak_k * 0.35 + deg_to_rad(69.0) * cr   # rón rén/chui: tai ngả ra sau
	ear_target = lerpf(ear_target, -0.25, startle)          # giật mình: tai dựng
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

	if preview:
		_idle_action(delta, t)
	_apply_bones()


## Bắt đầu ngay một động tác chờ ("sit" | "lick" | "" để đứng), giữ trong `seconds` giây.
func play_idle_action(action_name: String, seconds := 4.0) -> void:
	_action = action_name
	_action_timer = seconds


## Động tác chờ ở tủ đồ và màn hình chính: thỉnh thoảng ngồi xuống, hoặc ngồi liếm chân trước.
## Cộng thêm vào dáng đứng; _sit_w, _lick_w là lò xo 0..1 nên vào và ra động tác đều mềm.
func _idle_action(delta: float, t: float) -> void:
	_action_timer -= delta
	if _action_timer <= 0.0:
		if _action == "":
			_action = "sit" if randf() < 0.55 else "lick"
			_action_timer = randf_range(4.0, 6.5) if _action == "sit" else randf_range(3.0, 4.0)
		else:
			_action = ""
			_action_timer = randf_range(5.0, 9.0)
	_sit = clampf(_sit_w.step(1.0 if _action in ["sit", "lick"] else 0.0, 18.0, 0.9, delta), 0.0, 1.0)
	_lick = clampf(_lick_w.step(1.0 if _action == "lick" else 0.0, 22.0, 0.9, delta), 0.0, 1.0)
	if _sit < 0.001 and _lick < 0.001:
		_body.position = Vector3.ZERO
		_off_legs = [0.0, 0.0, 0.0, 0.0]
		_off_head = Vector2.ZERO
		_off_tail = 0.0
		return
	# Ngồi: thân ngẩng lên quanh khớp vai trước nên mông hạ xuống; chân trước bù lại để vẫn thẳng đứng,
	# chân sau gập ra trước. Trục X của chân: dương là vung ra sau.
	var a := SIT_PITCH * _sit
	_body.rotation.x += a
	_body.position = _sit_pivot - _sit_pivot.rotated(Vector3.RIGHT, a)
	_off_legs = [a - LICK_PAW * _lick, a, -SIT_HIND * _sit, -SIT_HIND * _sit]
	# Liếm chân: nhấc chân trước trái lên, cúi đầu nghiêng sang, đầu gật nhịp liếm. Trục X của đầu: dương là cúi.
	_off_head = Vector2(0.25 * _lick, a * 0.8 + (LICK_HEAD + sin(t * 11.0) * 0.07) * _lick)
	_off_tail = SIT_TAIL * _sit
	if _lick > 0.0:
		_blink = maxf(_blink, 0.6 * _lick)


## Xoay xương theo các góc tính ở trên. Trục X của xương là trục gập trước/sau.
func _apply_bones() -> void:
	for i in 4:
		var q := Quaternion(Vector3.RIGHT, (_legs[i] + _leg_extra[i] + _off_legs[i]) * LEG_SWING_SIGN)
		if i == 1:
			q = q * Quaternion(Vector3.FORWARD, _fr_sweep)  # trượt: chân trước phải vung ngang
		_pose_q(LEG_BONES[i], q)
	for i in _fp_paws.size():
		# Thân Bơ quay ngược 180° trong visual nên trục X đổi chiều
		_fp_paws[i].rotation.x = FP_PAW_LEAN - _legs[i] * LEG_SWING_SIGN
	_pose_q("head", Quaternion(Vector3.UP, _head_yaw.x + _off_head.x) * Quaternion(Vector3.RIGHT, _head_pitch.x + _off_head.y) * Quaternion(Vector3.FORWARD, _head_roll))
	var hi: int = _bone_idx["head"]
	if hi >= 0:
		var parent := _skel.get_bone_parent(hi)
		var pb := _skel.get_bone_global_rest(parent).basis if parent >= 0 else Basis()
		_skel.set_bone_pose_position(hi, _skel.get_bone_rest(hi).origin + pb.inverse() * _head_off)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var flick := sin(_ear_flick[i] * PI) * 0.5
		_pose_q(["ear_L", "ear_R"][i], Quaternion(Vector3.RIGHT, _ear[i].x + flick + (1.0 if _ears_down else 0.0)) * Quaternion(Vector3.FORWARD, side * (flick * 0.6 + deg_to_rad(30.0) * _ear_spread)))
		var ei: int = _bone_idx[["ear_L", "ear_R"][i]]
		if ei >= 0:
			_skel.set_bone_pose_scale(ei, Vector3.ONE * (0.45 if _ears_down else 1.0))
	for eye in ["eye_L", "eye_R"]:
		var idx: int = _bone_idx[eye]
		if idx >= 0:
			var big := 1.0 + 0.16 * _eye_big  # giật mình: mắt to 1,16
			_skel.set_bone_pose_scale(idx, Vector3(big, big * (1.0 - 0.9 * sin(_blink * PI * 0.5)), big))
	_pose_q("scarf", Quaternion(Vector3.RIGHT, _scarf_p.x) * Quaternion(Vector3.FORWARD, _scarf_r.x))
	for i in 4:
		_pose_q(TAIL_BONES[i], Quaternion(Vector3.RIGHT, -_tail_p[i] + _off_tail * (1.0 if i < 2 else -0.6)) * Quaternion(Vector3.BACK, _tail_y[i]))
	# Giật mình: đuôi xù to gấp 1,75 bề ngang (chỉ đốt gốc, các đốt sau thừa hưởng tỉ lệ)
	var ti: int = _bone_idx["tail_1"]
	if ti >= 0:
		var f := 1.0 + 0.75 * _tail_fluff
		_skel.set_bone_pose_scale(ti, Vector3(f, 1.0, f))


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
		if stance == "sneak":
			a = lerpf(a, [0.15, 0.0, 0.0, -0.1][i], 0.8)    # rón rén: đuôi duỗi ngang
		if stance == "crouch" or (_act == "deliver" and _act_kind == "under_car"):
			a = deg_to_rad(15.0) if i == 0 else 0.0     # chui: đuôi duỗi thấp ra sau
		if _act == "startle":
			a = [-1.2, -0.1, 0.0, 0.0][i]               # giật mình: đuôi dựng thẳng
		targets.append(a)

	# Lắc ngang: đứng yên vẫy chậm, chạy thì vẫy nhẹ theo bước; quẹo thì văng ra ngoài
	var sway := sin(t * (1.6 + k * 4.0)) * lerpf(0.18, 0.08, k) + 0.5 * _slide_amt  # trượt: đuôi quét sang trái
	for i in 4:
		var yaw_target := sway * (0.4 + i * 0.3) - clampf(_yaw_rate * 0.12, -0.5, 0.5) * (0.5 + i * 0.25)
		var stiff: float = TAIL_STIFF[i]
		var damp := 2.0 * sqrt(stiff) * TAIL_DAMP
		var n := maxi(1, ceili(delta * 120.0))  # chia nhỏ bước như Spring.step
		var h := delta / n
		for j in n:
			_tail_pv[i] += ((targets[i] - _tail_p[i]) * stiff - _tail_pv[i] * damp) * h
			_tail_p[i] += _tail_pv[i] * h
			_tail_yv[i] += ((yaw_target - _tail_y[i]) * stiff - _tail_yv[i] * damp) * h
			_tail_y[i] += _tail_yv[i] * h


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
