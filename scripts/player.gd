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
signal ledge_grabbed                    ## bám được mép (Thứ Năm)
signal ledge_climbed                    ## leo lên xong mép
signal wall_kicked(count: int)          ## bật tường lần thứ count trong một lần bay
signal bumped(kind: String)              ## va "person" | "cart" | "stall" (chợ Thứ Ba); đồ dễ vỡ nghe để vỡ
## Đồ dễ vỡ đang ngậm (túi trứng) mất một món; remaining là số còn lại
signal fragile_damaged(remaining: int)
signal clip_finished(clip_name: String)    ## động tác Blender chạy một lần (play_clip) đã xong

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

@export_group("Đồ dễ vỡ")
@export var fragile_fall := 1.0       ## đáp đất từ cao hơn mức này (mét) là vỡ một món
@export var fragile_bump_speed := 2.2 ## va người/xe đẩy nhanh hơn mức này (m/s) là vỡ một món

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
## Đồ dễ vỡ Bơ đang ngậm (gói T3-3): "" là không ngậm gì, "trung6" là túi 6 trứng của Cô Hai
var fragile_item := ""
var fragile_count := 0
var _fragile_cd := 0.0            ## vừa vỡ một quả thì chờ chút, một cú va không vỡ liền hai quả
var _hit_cd := 0.0                ## đứng ép vào người thì chỉ tính một lần va
var _fragile_bag: BoneAttachment3D
var _fragile_eggs: Array[Node3D] = []
## Nút quai túi trứng (chỗ Bơ ngậm) cao hơn đáy túi bấy nhiêu mét (KNOT_Z trong bàn giao Thứ Ba)
const FRAGILE_KNOT := 0.19
## Miệng Bơ trong hệ CatVisual (mặt nhìn -Z): chỗ nút quai túi trứng
const FRAGILE_MOUTH := Vector3(0, 0.31, -0.23)
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
# Bộ xương 22 xương: thân gập ở hông và ngực, chân gập khuỷu/gối bằng IK nên bàn chân ở lại trên đất
var _foot := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]  ## đích cổ chân so với chỗ đứng nghỉ (hệ model: +Y lên, +Z ra trước)
var _paw_tilt := [0.0, 0.0, 0.0, 0.0]   ## gập bàn chân (dương: ngón cụp xuống, lúc nhấc chân)
var _root_off := Vector3.ZERO     ## dời cả bộ xương: hạ thân khi chui/rón rén/ngồi, nhún theo bước
var _hips_pitch := 0.0            ## xoay quanh khớp háng sau (dương: chúi mũi xuống, hệ model)
var _chest_pitch := 0.0           ## gập ở giữa lưng (cong lưng khi giật mình)
var _fold := 0.0                  ## giao cao: hai chân trước co trước ngực
var _splay := 0.0                 ## chui: khuỷu xoè ra hai bên
var _fr_sweep := 0.0              ## chân trước phải vung ngang khi trượt
var _leg_rig := []                ## mỗi chân: chỉ số 3 xương, dài 2 đoạn, góc nghỉ, cổ chân lúc nghỉ
var _bag_xf := Transform3D()      ## chỗ đeo túi trong hệ _body (lúc dựng), để gắn lại khi đổi model
var _mouth_bread: Node3D          ## ổ bánh gói giấy ngậm ở miệng khi giao
var _bob := 0.0                   ## nhún người theo bước
const BANH_GOI := preload("res://assets/models/do/banh_goi.glb")
const MOUTH := Vector3(0, 0.368, 0.30)   ## điểm miệng trong hệ model Bơ (đã duyệt)

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

## Động tác làm trong Blender (G2, Sang duyệt 21/10): 18 động tác nướng sẵn trên bộ 22 xương, 30 khung/giây.
## Nguồn: tools/dong_tac_bo/ (anims.py), xuất bằng export_glb.py rồi xuat_json.py.
## play_clip đè lên dáng tính bằng code: vào 0,12 s, ra 0,15 s, đổi động tác thì hoà hai động tác vào nhau.
## Giống mèo khác cùng tên xương: lấy phần chênh so với dáng nghỉ của Bơ đặt lên dáng nghỉ của giống đó.
const DONG_TAC_PATH := "res://assets/models/bo_dong_tac.json"
const TUI_3O := preload("res://assets/models/giao/tui_3o.glb")
const CLIP_FADE_IN := 0.12
const CLIP_FADE_OUT := 0.15
const CLIMB_CLIPS := ["bam_mep", "keo_len", "leo_ong"]
## Ôm ống: trong Blender gốc thân cao hơn chân 0,45 m; game giữ thân gần khối va chạm nên hạ bớt
const CLIP_ROOT_SHIFT := {"leo_ong": Vector3(0, -0.25, 0)}
## Vật lý đã đẩy Bơ đi (bật tường, rơi khỏi ván): bỏ đường đi thẳng của gốc từ khung đầu tới khung cuối
const CLIP_STRIP_MOTION := ["dap_tuong", "roi_van"]
const TUI3_LIFT := 0.31            ## ngậm túi 3 ổ: ngẩng cằm 18° cho túi khỏi chạm ngực
static var _dong_tac := {}
## Động tác Blender đang chạy ("" là không có); _clip_w 0..1 là mức đè lên dáng code
var clip := ""
var _clip_t := 0.0
var _clip_speed := 1.0
var _clip_w := 0.0
var _clip_on := false              ## false: đang mờ dần ra
var _clip_driven := false          ## thời gian do code leo đặt (keo_len), không tự chạy
var _clip_prev := {}               ## động tác vừa bị thay, đang mờ ra: name, t, w
var _tui3: Node3D                  ## túi 3 ổ ngậm ở miệng (Thứ Sáu, giỗ)
var _tui3_hang: Node3D
var _tui3_on := false
var _tui3_swing := Spring.new()

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
var sex := "duc"                 ## "duc" / "cai" (tủ đồ); bản cái chưa có model thì vẫn hiện bản đực
var _cai_model := false          ## đang dùng model mèo cái (<id>_cai.glb)
var _model: Node3D
var _acc_nodes := []             # phụ kiện đang gắn (OutfitView.attach)
var _cloth_mats := []            # vật liệu đồ vải bay (áo choàng) trong _acc_nodes
var _cloth_s := Spring.new()     # tốc độ gió lên áo, có quán tính
var _cloth_fall := Spring.new()
var _cloth_turn := Spring.new()
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
var _off_head := Vector2.ZERO          # (xoay ngang, cúi)
var _off_tail := 0.0
## Góc động tác chờ (rad), chỉnh ở đây
const SIT_PITCH := 0.45        # thân ngẩng lên khi ngồi
const LICK_PAW := Vector3(0, 0.29, 0.2)  # liếm chân: cổ chân trước trái nhấc tới gần miệng (hệ model)
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
## Bộ xương chính thức (Sang duyệt 21/10, xem tools/bo_game.py): 22 xương + 3 xương phụ (mắt chớp, khăn)
const BONE_NAMES := ["root", "hips", "chest", "head", "ear_L", "ear_R", "tail_1", "tail_2", "tail_3", "tail_4",
	"upperarm_FL", "forearm_FL", "paw_FL", "upperarm_FR", "forearm_FR", "paw_FR",
	"thigh_BL", "shin_BL", "paw_BL", "thigh_BR", "shin_BR", "paw_BR", "eye_L", "eye_R", "scarf"]
const TAIL_BONES := ["tail_1", "tail_2", "tail_3", "tail_4"]
## Độ cứng lò xo từng đốt đuôi: gốc cứng, chóp mềm nên chóp đuôi đi trễ và phất theo sau
const TAIL_STIFF := [90.0, 60.0, 42.0, 30.0]
const TAIL_DAMP := 0.55
## 4 chân (trước trái, trước phải, sau trái, sau phải), mỗi chân 3 xương từ vai/háng xuống bàn chân
const LEG_CHAINS := [["upperarm_FL", "forearm_FL", "paw_FL"], ["upperarm_FR", "forearm_FR", "paw_FR"],
	["thigh_BL", "shin_BL", "paw_BL"], ["thigh_BR", "shin_BR", "paw_BR"]]
const LEG_PHASE := [0.0, PI, PI, 0.0]   ## nhịp bước: trước trái đi cùng sau phải

const ORANGE := Color("#E8913A")
const ORANGE_DARK := Color("#C96F1C")
const CREAM := Color("#FBE3C2")
const SCARF := Color("#C8412F")
const BAG := Color("#2E7C80")
const INK := Color("#1F2A2A")
const PINK := Color("#F6B8A0")


func _ready() -> void:
	fragile_fall = DoKho.v("fragile_fall", fragile_fall)
	fragile_bump_speed = DoKho.v("fragile_bump_speed", fragile_bump_speed)
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


## Mèo Bơ kiểu D "Chững chạc" (dựng từ model chuẩn, xem tools/bo_game.py).
## Bộ xương chính thức 22 xương: thân gập ở hông/ngực, mỗi chân 3 xương có khuỷu và gối, đuôi 4 đốt;
## thêm xương phụ cho mắt và khăn. Game tự xoay xương bằng code thay cho animation.
func _build_visual() -> void:
	visual = Node3D.new()
	visual.name = "CatVisual"
	add_child(visual)
	_body = Node3D.new()
	visual.add_child(_body)

	breed = Outfit.breed()  # giống mèo đã chọn trong tủ đồ
	sex = Outfit.sex(breed)
	_load_model()
	_build_bag()
	_attach_bag()
	apply_outfit()
	# Thân, khăn, túi và quai: góc nhìn thứ nhất không vẽ (vẫn đổ bóng), thay bằng hai chân trước riêng
	for mi: MeshInstance3D in _body.find_children("*", "MeshInstance3D", true, false):
		mi.layers = LAYER_BO_BODY
	_build_fp_paws()


## Dựng model của giống đang chọn (Bơ hoặc giống skin cùng bộ xương, xem tools/xuat_skin_game.py).
func _load_model() -> void:
	if _model:
		if _bag and _bag.get_parent() != _body:
			_bag.reparent(_body, false)  # túi gắn ở xương hông của model cũ: giữ lại trước khi xoá model
		_model.free()
	_acc_nodes.clear()
	_scarf_mesh = null
	var scene: PackedScene = OutfitView.breed_scene(breed, sex)
	_cai_model = sex == "cai" and OutfitView.has_sex_model(breed, "cai")
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
	_setup_legs()
	_build_mouth_bread()
	_attach_bag()


## Số đo chân lấy từ dáng nghỉ của bộ xương (mỗi giống một khác): dài đoạn trên/dưới,
## góc từng đoạn trong mặt phẳng dọc thân, và chỗ cổ chân chạm đất.
## Góc đo trong hệ model (trục Y lên, Z ra trước): xoay quanh +X một góc a thì góc tăng a.
func _setup_legs() -> void:
	_leg_rig.clear()
	for chain in LEG_CHAINS:
		var ids := []
		for n in chain:
			ids.append(_bone_idx[n])
		if ids.has(-1):
			_leg_rig.clear()
			return
		var p0 := _skel.get_bone_global_rest(ids[0]).origin
		var p1 := _skel.get_bone_global_rest(ids[1]).origin
		var p2 := _skel.get_bone_global_rest(ids[2]).origin
		_leg_rig.append({"ids": ids, "l1": p0.distance_to(p1), "l2": p1.distance_to(p2),
			"r1": _ang(p1 - p0), "r2": _ang(p2 - p1), "ankle": p2})


static func _ang(v: Vector3) -> float:
	return atan2(v.z, v.y)


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


## Túi đeo theo xương hông: thân hạ khi chui, ngồi dậy khi giao thì túi đi theo, không lơ lửng.
func _attach_bag() -> void:
	var hi: int = _bone_idx.get("hips", -1)
	if _bag == null or hi < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "hips"
	_skel.add_child(att)
	# Hệ _body -> hệ bộ xương: đi qua model (quay 180°) và các nút cha của Skeleton3D trong .glb
	var to_skel := Transform3D()
	var n: Node = _skel
	while n != _model:
		to_skel = (n as Node3D).transform * to_skel
		n = n.get_parent()
	to_skel = (_model.transform * to_skel).affine_inverse()
	_bag.reparent(att, false)
	_bag.transform = _skel.get_bone_global_rest(hi).affine_inverse() * to_skel * _bag_xf


## Đổi giống mèo (tủ đồ mặc thử). Giống chưa có model thì giữ Bơ. new_sex "" = giới tính đang chọn trong tủ đồ.
func set_breed(id: String, worn := {}, new_sex := "") -> void:
	breed = id if OutfitView.has_breed(id) else "bo"
	sex = new_sex if new_sex != "" else Outfit.sex(breed)
	_load_model()
	apply_outfit(worn)


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
	var is_bo := breed == "bo" and not _cai_model  # Bơ chuẩn có sẵn khăn và túi dựng trong code
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
		_acc_nodes.append_array(OutfitView.attach(_skel, id, breed, sex if _cai_model else "duc"))
		_ears_down = _ears_down or OutfitView.ears_down(id)
	_cloth_mats = OutfitView.cloth_mats(_acc_nodes)


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
	_fragile_cd = maxf(_fragile_cd - delta, 0.0)
	_hit_cd = maxf(_hit_cd - delta, 0.0)

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
		if _fall_from - global_position.y > fragile_fall:
			_damage_fragile()
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
	play_clip("dap_tuong")
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
		var paw := BoPaw.create(side, FP_PAW_SIZE, "dung", breed)
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
	# Người, xe đẩy, sạp có meta "bump_kind": va vào đủ mạnh thì phát bumped (kể cả lúc đi thường)
	if _hit_cd <= 0.0 and speed_before > fragile_bump_speed and stance not in ["sneak", "crouch"]:
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			var o := c.get_collider()
			if o and o.has_meta("bump_kind") and absf(c.get_normal().y) < 0.5:
				_hit_cd = 0.8
				bump(str(o.get_meta("bump_kind")), c.get_position())
				break
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


## Số liệu 18 động tác Blender (nạp một lần cho mọi con mèo).
static func dong_tac() -> Dictionary:
	if _dong_tac.is_empty() and FileAccess.file_exists(DONG_TAC_PATH):
		_dong_tac = JSON.parse_string(FileAccess.get_file_as_string(DONG_TAC_PATH))
	return _dong_tac


func has_clip(clip_name: String) -> bool:
	return dong_tac().get("clips", {}).has(clip_name)


## Chạy động tác Blender (tên trong tools/dong_tac_bo/anims.py, vd "ngoi_goi", "chup_vay", "nhan_huy_chuong").
## Động tác lặp chạy tới khi stop_clip(); động tác một lần xong thì phát clip_finished rồi mờ về dáng code.
## speed âm là chạy ngược (động tác lặp).
func play_clip(clip_name: String, speed := 1.0) -> void:
	if not has_clip(clip_name):
		push_warning("Không có động tác " + clip_name)
		return
	if clip != "" and clip != clip_name and _clip_w > 0.0:
		_clip_prev = {"name": clip, "t": _clip_t, "w": _clip_w}
		_clip_w = 0.0
	clip = clip_name
	_clip_t = 0.0
	_clip_speed = speed
	_clip_on = true
	_clip_driven = false


## Mờ dần về dáng code trong 0,15 s, giữ khung đang dừng.
func stop_clip() -> void:
	_clip_on = false


## Ngậm túi 3 ổ (Thứ Sáu: giỗ 6 ổ, hai chuyến). dua_tui/nhan_tui tự đổi theo lúc nhả/ngậm.
func carry_tui3(on: bool) -> void:
	_tui3_on = on


func _clip_step(delta: float) -> void:
	# Động tác cũ giữ nguyên mức dưới động tác mới đang vào (không lộ dáng code ở giữa), vào hẳn thì bỏ
	if not _clip_prev.is_empty():
		if _clip_w >= 1.0 or clip == "":
			_clip_prev = {}
		elif not _clip_on:
			_clip_prev.w = move_toward(_clip_prev.w, 0.0, delta / CLIP_FADE_OUT)
	if clip == "":
		return
	var c: Dictionary = dong_tac().clips[clip]
	if not _clip_on:
		_clip_w = move_toward(_clip_w, 0.0, delta / CLIP_FADE_OUT)
		if _clip_w <= 0.0:
			clip = ""
		return
	_clip_w = move_toward(_clip_w, 1.0, delta / CLIP_FADE_IN)
	if _clip_driven:
		return
	_clip_t += delta * _clip_speed
	var dur := float(c.dur)
	if c.loop:
		_clip_t = fposmod(_clip_t, dur)
	elif _clip_t >= dur:
		_clip_t = dur
		_clip_on = false
		if c.has("tui3"):
			_tui3_on = c.tui3[-1] == 1
		clip_finished.emit(clip)


## Đè động tác Blender lên dáng code vừa đặt trong _apply_bones (động tác cũ đang mờ ra trước, động tác mới sau).
func _apply_clip() -> void:
	var w_body := 0.0
	if not _clip_prev.is_empty():
		_apply_clip_layer(_clip_prev.name, _clip_prev.t, _clip_prev.w)
		w_body = _clip_prev.w
	if clip != "" and _clip_w > 0.0:
		_apply_clip_layer(clip, _clip_t, _clip_w)
		w_body = maxf(w_body, _clip_w)
	if w_body > 0.0:
		# Động tác Blender đã có đủ dáng: bớt nghiêng, nhún, thở của _body
		var k := 1.0 - smoothstep(0.0, 1.0, w_body)
		_body.rotation *= k
		_body.scale = Vector3.ONE.lerp(_body.scale, k)


func _apply_clip_layer(clip_name: String, t: float, weight: float) -> void:
	var data := dong_tac()
	var c: Dictionary = data.clips[clip_name]
	var rest: Dictionary = data.rest
	var w := smoothstep(0.0, 1.0, weight)
	var fr := t * float(data.fps)
	for bone_name: String in c.bones:
		var idx: int = _bone_idx.get(bone_name, -1)
		if idx < 0:
			continue
		var ch: Dictionary = c.bones[bone_name]
		var rb: Dictionary = rest[bone_name]
		if ch.has("r"):
			var rq := Quaternion(rb.r[0], rb.r[1], rb.r[2], rb.r[3])
			var q: Quaternion = _bone_rest[bone_name] * (rq.inverse() * _clip_q(ch.r, fr))
			_skel.set_bone_pose_rotation(idx, _skel.get_bone_pose_rotation(idx).slerp(q.normalized(), w))
		if ch.has("p"):
			var p := _clip_v(ch.p, fr) - Vector3(rb.p[0], rb.p[1], rb.p[2])
			if bone_name == "root":
				p += _clip_root_fix(clip_name, ch.p, t, float(c.dur))
			p += _skel.get_bone_rest(idx).origin
			_skel.set_bone_pose_position(idx, _skel.get_bone_pose_position(idx).lerp(p, w))
		if ch.has("s"):
			_skel.set_bone_pose_scale(idx, _skel.get_bone_pose_scale(idx).lerp(_clip_v(ch.s, fr), w))


## Gốc thân trong động tác đã gồm đường đi; phần đó trong game do vật lý/code leo đẩy nên trừ ra.
func _clip_root_fix(clip_name: String, ch: Array, t: float, dur: float) -> Vector3:
	var fix: Vector3 = CLIP_ROOT_SHIFT.get(clip_name, Vector3.ZERO)
	var u := clampf(t / dur, 0.0, 1.0)
	if clip_name == "keo_len":
		# đúng đường kéo trong _climb_process: lên 0,52 m rồi tới 0,59 m vào mặt mép
		fix -= Vector3(0, 0.52 * smoothstep(0.0, 0.7, u), 0.59 * smoothstep(0.45, 1.0, u))
	elif clip_name in CLIP_STRIP_MOTION:
		var first := _clip_v(ch, 0.0)
		fix -= first + (_clip_v(ch, 1e9) - first) * u
	return fix


static func _clip_q(v: Array, fr: float) -> Quaternion:
	var n := v.size() / 4
	var i0 := clampi(int(fr), 0, n - 1)
	var i1 := mini(i0 + 1, n - 1)
	var a := Quaternion(v[i0 * 4], v[i0 * 4 + 1], v[i0 * 4 + 2], v[i0 * 4 + 3])
	if i1 == i0:
		return a.normalized()
	var b := Quaternion(v[i1 * 4], v[i1 * 4 + 1], v[i1 * 4 + 2], v[i1 * 4 + 3])
	return a.normalized().slerp(b.normalized(), clampf(fr - i0, 0.0, 1.0))


static func _clip_v(v: Array, fr: float) -> Vector3:
	var n := v.size() / 3
	var i0 := clampi(int(fr), 0, n - 1)
	var i1 := mini(i0 + 1, n - 1)
	var a := Vector3(v[i0 * 3], v[i0 * 3 + 1], v[i0 * 3 + 2])
	return a.lerp(Vector3(v[i1 * 3], v[i1 * 3 + 1], v[i1 * 3 + 2]), clampf(fr - i0, 0.0, 1.0))


## Túi 3 ổ: quai ngậm ở miệng, túi luôn thòng thẳng đứng và đung đưa theo quán tính (không xoay theo đầu).
func _update_tui3() -> void:
	var show := _tui3_on
	for layer in [_clip_prev, {"name": clip, "t": _clip_t, "w": _clip_w}]:
		if layer.get("name", "") != "" and layer.w > 0.5 and dong_tac().clips[layer.name].has("tui3"):
			var flags: Array = dong_tac().clips[layer.name].tui3
			show = flags[clampi(int(layer.t * 30.0 + 0.5), 0, flags.size() - 1)] == 1
	if show and not is_instance_valid(_tui3):
		_build_tui3()
	if not is_instance_valid(_tui3):
		return
	_tui3.visible = show
	if show:
		var dt := get_process_delta_time()
		var swing := _tui3_swing.step(clampf(_accel * 0.03, -0.6, 0.6), 60.0, 0.25, dt)
		_tui3_hang.global_basis = Basis(Vector3.UP, _model.global_rotation.y) * Basis(Vector3.RIGHT, swing)


func _build_tui3() -> void:
	var hi: int = _bone_idx.get("head", -1)
	if hi < 0:
		return
	_tui3 = BoneAttachment3D.new()
	_tui3.name = "Tui3o"
	(_tui3 as BoneAttachment3D).bone_name = "head"
	_skel.add_child(_tui3)
	_tui3_hang = Node3D.new()
	_tui3.add_child(_tui3_hang)
	# Gốc model túi ở đỉnh quai (chỗ ngậm), đặt đúng điểm miệng
	_tui3_hang.transform = _skel.get_bone_global_rest(hi).affine_inverse() * Transform3D(Basis(), MOUTH)
	_tui3_hang.add_child(TUI_3O.instantiate())
	for mi: MeshInstance3D in _tui3.find_children("*", "MeshInstance3D", true, false):
		mi.layers = LAYER_BO_BODY


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

	# Tư thế đã duyệt (trang phác thảo động tác Thứ Hai) trên bộ 22 xương:
	# chui vào/ra 0,25 s; rón rén; trượt dầu; giao cao/thấp; giật mình.
	crouch_amount = move_toward(crouch_amount, 1.0 if stance == "crouch" else 0.0, delta / 0.25)
	_sneak_amt = move_toward(_sneak_amt, 1.0 if stance == "sneak" else 0.0, delta / 0.3)
	_slide_amt = move_toward(_slide_amt, 1.0 if _sliding else 0.0, delta / (0.15 if _sliding else 0.4))
	var sneak_k := _sneak_amt
	# Giao: lên dáng trong 0,3 s, giữ, rồi giao_xong 0,4 s cuối trở về
	var dw := 0.0
	if _act == "deliver":
		dw = smoothstep(0.0, 0.3, _act_t) * (1.0 - smoothstep(_act_len - 0.4, _act_len, _act_t))
	var high := dw if _act_kind != "under_car" else 0.0   # giao_cao: ngồi dậy trên hai chân sau
	var low := dw if _act_kind == "under_car" else 0.0    # giao_thap: dáng chui đẩy bánh
	var startle := sin(clampf(_act_t / 0.6, 0.0, 1.0) * PI) if _act == "startle" else 0.0
	var cr := maxf(crouch_amount, low)                     # độ chui (kể cả lúc giao thấp)
	if _mouth_bread:
		_mouth_bread.visible = _act == "deliver" and _act_t > 0.25 and not _released
	if preview:
		_idle_action(delta, t)
	# Bước dài và chậm hơn khi rón rén, ngắn và nhanh khi chui
	var gait := 2.2 if stance in ["walk", "sprint"] else (1.6 if stance == "sneak" else 3.0)
	# Chân: mỗi bàn chân đi theo một vòng bước (ra trước thì nhấc lên, lùi sau thì chạm đất);
	# khuỷu, gối tự gập theo nhờ IK trong _apply_bones. Thân nhún theo bước.
	if on_floor:
		_phase += delta * (4.0 + hspeed * gait)
		var amp := maxf(k, 0.35 if hspeed > 0.3 else 0.0)
		var stride := 0.15 * amp * (0.6 if stance == "crouch" else 1.0)
		var lift := (0.03 + 0.04 * k) * signf(amp) + 0.03 * sneak_k * signf(amp)  # rón rén: nhấc chân cao 6 cm
		for i in 4:
			var ph: float = _phase + LEG_PHASE[i]
			var up := maxf(cos(ph), 0.0)
			_foot[i] = Vector3(0, up * lift, sin(ph) * stride)
			_paw_tilt[i] = up * 0.9 * amp
		if _sliding:
			# Trượt dầu: chân trước trái trượt dài ra trước, hai chân sau dạng ra sau, chân cứng đơ
			_foot = [Vector3(0, 0, 0.1), Vector3(0, 0.03, 0.02), Vector3(0, 0, -0.05), Vector3(0, 0, -0.04)]
			_paw_tilt = [0.0, 0.0, 0.0, 0.0]
		_bob = absf(sin(_phase)) * 0.04 * k
		var side := signf(sin(_phase))
		if hspeed > 0.3 and side != 0.0 and side != _step_side:
			_step_side = side
			_footstep()
	else:
		# Trên không: chân trước vươn ra trước, chân sau co lên
		var tl := 1.0 - exp(-10.0 * delta)
		for i in 4:
			var air := Vector3(0, 0.05, 0.07) if i < 2 else Vector3(0, 0.07, -0.06)
			_foot[i] = _foot[i].lerp(air, tl)
			_paw_tilt[i] = lerpf(_paw_tilt[i], 0.5, tl)
		_bob = lerpf(_bob, 0.0, tl)
	# Leo (tạm, thay bằng tư thế Blender khi Sang duyệt): bám thì chân trước vươn lên mép,
	# chân sau buông; leo lên thì chân sau đạp; ôm ống thì bốn chân thay nhau với
	var climb_u := clampf(_climb_t / pull_time, 0.0, 1.0)
	match climb:
		"hang":
			var sw := sin(t * 3.0) * 0.015
			_foot = [Vector3(0, 0.12, 0.12), Vector3(0, 0.12, 0.12), Vector3(0, 0, -0.04 + sw), Vector3(0, 0, -0.04 - sw)]
			_paw_tilt = [0.9, 0.9, 0.3, 0.3]
		"pull":
			var f := Vector3(0, 0.12, 0.12).lerp(Vector3(0, 0.02, 0.05), climb_u)
			var kick := sin(climb_u * TAU * 2.0)
			_foot = [f, f, Vector3(0, 0.04 + 0.03 * kick, 0.06 * kick), Vector3(0, 0.04 - 0.03 * kick, -0.06 * kick)]
		"pipe":
			_phase += delta * absf(vy) * 6.0
			var c := sin(_phase)
			_foot = [Vector3(0, 0.07 + 0.04 * c, 0.08), Vector3(0, 0.07 - 0.04 * c, 0.08), Vector3(0, 0.04 - 0.03 * c, 0.02), Vector3(0, 0.04 + 0.03 * c, 0.02)]
	for i in 4:
		_legs[i] = -atan2(_foot[i].z, 0.23)  # góc vung tương đương (dương: ra sau), cho chân góc thứ nhất
	# Leo dùng động tác Blender (G2): bám mép lặp, kéo lên theo đúng nhịp kéo, ôm ống theo tốc độ leo
	match climb:
		"hang":
			if clip != "bam_mep":
				play_clip("bam_mep")
		"pull":
			if clip != "keo_len":
				play_clip("keo_len")
			_clip_driven = true
			_clip_t = climb_u * float(dong_tac().clips.keo_len.dur)
		"pipe":
			if clip != "leo_ong":
				play_clip("leo_ong")
			_clip_speed = vy / pipe_speed
		_:
			if clip in CLIMB_CLIPS and _clip_on:
				if clip == "keo_len":
					_clip_t = float(dong_tac().clips.keo_len.dur)  # đã lên hẳn mép: dừng ở khung cuối
				stop_clip()
	_clip_step(delta)

	_update_tail(delta, hspeed, vy, on_floor)

	# Thân: nghiêng khi quẹo (vào phía trong vòng), chúi/ngả theo gia tốc, ngẩng khi bay lên
	var lean_target := clampf(_yaw_rate * k * 0.07, -0.22, 0.22)
	var pitch_target := clampf(-_accel * 0.012, -0.12, 0.12)
	if not on_floor:
		pitch_target = clampf(vy * 0.04, -0.3, 0.3)
	lean_target += _slide_amt * (deg_to_rad(11.0) + sin(t * 9.0) * 0.06)  # trượt: nghiêng 11°, chao nhẹ
	pitch_target -= deg_to_rad(3.0) * sneak_k                            # rón rén: chúi 3°
	pitch_target += deg_to_rad(54.0) * high                              # giao cao: ngửa thân 54° quanh hông
	if climb in ["hang", "pipe"]:
		pitch_target = 1.15  # thân dựng đứng áp vào tường
	elif climb == "pull":
		pitch_target = lerpf(1.15, -0.1, climb_u)
	_body.rotation.z = _lean.step(lean_target, 120.0, 0.7, delta)
	if not _cloth_mats.is_empty():
		# Áo choàng: gió theo tốc độ (đi bay nhẹ, chạy nhanh bay thẳng ra sau), rơi thì hất lên, quẹo thì văng ra
		var fall_t := clampf(-vy / 8.0, -1.0, 1.0) if not on_floor else 0.0
		OutfitView.cloth_drive(_cloth_mats, clampf(_cloth_s.step(k, 30.0, 0.8, delta), 0.0, 1.2),
			_cloth_fall.step(fall_t, 40.0, 0.5, delta), _cloth_turn.step(clampf(-_yaw_rate * k * 0.25, -1.0, 1.0), 30.0, 0.6, delta))
	_body.rotation.y = deg_to_rad(6.0) * _slide_amt
	_pitch.step(pitch_target, 150.0, 0.6, delta)
	if landed_now:
		_pitch.v -= 2.5  # tiếp đất: thân khựng chúi tới rồi bật lại
	# Chúi/ngả là xoay xương hông quanh khớp háng sau (dương của _pitch là ngẩng lên), ngồi thì ngả thêm;
	# giật mình: cong lưng (hông ngẩng, ngực chúi nên giữa lưng nhô lên ~10 cm)
	_hips_pitch = -_pitch.x - SIT_PITCH * _sit - 0.3 * startle
	_chest_pitch = 0.55 * startle
	# Hạ thân: chui 0,13 m, rón rén 0,05 m, giao cao ngồi trên cổ chân sau 0,06 m, ngồi 0,07 m
	_root_off = Vector3(0, _bob - 0.13 * cr - 0.05 * sneak_k - 0.06 * high - 0.07 * _sit, 0)
	_body.position = Vector3.ZERO

	# Thở khi đứng yên: ngực phồng nhẹ
	var breath := sin(t * 2.4) * (1.0 - k)
	_body.scale = Vector3(1.0 + 0.012 * breath, 1.0 + 0.008 * breath, 1.0 + 0.006 * breath)
	# Chui: nén cao 0,78, dài 1,1 như bản phác
	_body.scale *= Vector3(1.0, lerpf(1.0, 0.78, cr), lerpf(1.0, 1.1, cr))
	_splay = cr  # chui: khuỷu xoè, bàn chân ra trước (xem _apply_bones)
	_fold = high  # giao cao: hai chân trước co trước ngực
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
	var head_pitch_target := look.y + nod - _pitch.x * 0.7
	head_pitch_target += deg_to_rad(8.0) * sneak_k               # rón rén: cúi 8°
	# Giao cao: so với thân, đầu cúi 36° (thân ngửa 54° nên mặt vẫn ngước lên)
	head_pitch_target += (deg_to_rad(36.0) + 0.7 * deg_to_rad(54.0)) * high
	if _tui3_on:
		head_pitch_target -= TUI3_LIFT
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
		_off_head = Vector2.ZERO
		_off_tail = 0.0
		return
	# Ngồi: hông ngả ra sau quanh khớp háng, mông hạ xuống; chân trước tự duỗi thẳng giữ bàn chân trên sàn,
	# chân sau gập lại (xem _apply_bones). Liếm chân: nhấc chân trước trái lên tới miệng.
	var a := SIT_PITCH * _sit
	# Đầu cúi bù lại góc ngả, liếm thì cúi xuống chân, gật nhịp liếm. Trục X của đầu: dương là cúi.
	_off_head = Vector2(0.25 * _lick, a * 0.8 + (LICK_HEAD + sin(t * 11.0) * 0.07) * _lick)
	_off_tail = SIT_TAIL * _sit
	if _lick > 0.0:
		_blink = maxf(_blink, 0.6 * _lick)


## Xoay xương theo các góc tính ở trên. Trục X của xương là trục gập trước/sau.
func _apply_bones() -> void:
	var ri: int = _bone_idx["root"]
	if ri >= 0:
		_skel.set_bone_pose_position(ri, _skel.get_bone_rest(ri).origin + _root_off)
	_pose("hips", Vector3.RIGHT, _hips_pitch)
	_pose("chest", Vector3.RIGHT, _chest_pitch)
	for i in _leg_rig.size():
		_leg_ik(i)
	for i in _fp_paws.size():
		# Thân Bơ quay ngược 180° trong visual nên trục X đổi chiều
		_fp_paws[i].rotation.x = FP_PAW_LEAN - _legs[i]
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
	_apply_clip()
	_update_tui3()


## IK hai đoạn cho một chân trong mặt phẳng dọc thân: cổ chân đặt đúng đích (chỗ đứng nghỉ + _foot),
## khuỷu trước gập ra sau, gối sau gập ra trước như mèo thật; bàn chân giữ nằm phẳng (+ _paw_tilt).
## Mọi xương chân có trục X cục bộ trùng +X của model nên góc gập cộng dồn được dọc theo chân.
func _leg_ik(i: int) -> void:
	var L: Dictionary = _leg_rig[i]
	var ids: Array = L["ids"]
	var front := i < 2
	var s := _skel.get_bone_global_pose(ids[0]).origin  # vai/háng sau khi thân đã xoay, hạ
	var target: Vector3 = L["ankle"] + _foot[i]
	# Chui: bàn chân trước ra trước 10 cm, chân sau rút lên dưới bụng 6 cm
	target.z += (0.1 if front else 0.06) * _splay
	if front and _fold > 0.0:
		target = target.lerp(s + Vector3(0, -0.1, 0.05), _fold)  # giao cao: co trước ngực
	if i == 0 and _lick > 0.0:
		target = target.lerp(LICK_PAW, _lick)
	var l1: float = L["l1"]
	var l2: float = L["l2"]
	var d := Vector2(target.y - s.y, target.z - s.z)  # (y, z)
	var dist := clampf(d.length(), absf(l1 - l2) + 0.002, l1 + l2 - 0.0005)
	var end := d.normalized() * dist
	var bend := acos(clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0))
	var a1 := atan2(end.y, end.x) + (bend if front else -bend)
	var knee := Vector2(cos(a1), sin(a1)) * l1
	var a2 := atan2(end.y - knee.y, end.x - knee.x)
	# Góc thêm so với dáng nghỉ (toàn cục), rồi trừ phần xương cha đã xoay
	var g1 := wrapf(a1 - float(L["r1"]), -PI, PI)
	var g2 := wrapf(a2 - float(L["r2"]), -PI, PI)
	var parent := _hips_pitch + (_chest_pitch if front else 0.0)
	var tilt: float = _paw_tilt[i] + (1.2 * _fold if front else 0.0) + (1.0 * _lick if i == 0 else 0.0)
	var q1 := Quaternion(Vector3.RIGHT, g1 - parent)
	if front:
		# Khuỷu xoè ra ngoài khi chui; trượt dầu thì chân trước phải vung ngang
		var side := -1.0 if i == 0 else 1.0
		var out := 0.3 * _splay + (_fr_sweep if i == 1 else 0.0)
		q1 = q1 * Quaternion(Vector3.BACK, -side * out)
	_skel.set_bone_pose_rotation(ids[0], _bone_rest[LEG_CHAINS[i][0]] * q1)
	_skel.set_bone_pose_rotation(ids[1], _bone_rest[LEG_CHAINS[i][1]] * Quaternion(Vector3.RIGHT, g2 - g1))
	_skel.set_bone_pose_rotation(ids[2], _bone_rest[LEG_CHAINS[i][2]] * Quaternion(Vector3.RIGHT, tilt - g2))


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


## Ngậm đồ dễ vỡ: item_id "trung6" là túi nilon 6 trứng. count 0 hoặc item "" là nhả ra.
## Bơ vẫn đeo túi bánh bên hông; túi trứng ngậm ở miệng (model tui_trung, trang "Phác thảo Thứ Ba").
func carry_fragile(item_id: String, count: int) -> void:
	fragile_item = item_id if count > 0 else ""
	fragile_count = count if item_id != "" else 0
	_fragile_cd = 0.0
	if _fragile_bag:
		_fragile_bag.queue_free()
		_fragile_bag = null
	_fragile_eggs.clear()
	if fragile_item == "":
		return
	# Gắn theo xương đầu để túi đi theo lúc Bơ ngó quanh; quai ngậm ở miệng, túi thòng dưới cằm
	_fragile_bag = BoneAttachment3D.new()
	_fragile_bag.name = "TuiTrung"
	_fragile_bag.bone_name = "head"
	_skel.add_child(_fragile_bag)
	_fragile_bag.global_transform = _skel.global_transform * _skel.get_bone_global_pose(_skel.find_bone("head"))
	var hang := Node3D.new()
	_fragile_bag.add_child(hang)
	hang.global_transform = Transform3D(visual.global_basis.orthonormalized(), visual.global_transform.orthonormalized() * FRAGILE_MOUTH)
	# Túi nilon hồng (model tui_trung, gốc ở đáy) thòng dưới miệng: nút quai cao 0,19 m trên đáy túi.
	# 6 quả trứng là node riêng đứng trong vỉ 2 × 3 để ẩn từng quả khi vỡ.
	var bag_root := Node3D.new()
	hang.add_child(bag_root)
	bag_root.position = Vector3(0, -FRAGILE_KNOT, 0)
	bag_root.rotation.y = PI
	PhoModels.put(bag_root, "tui_trung", Vector3.ZERO)
	for k in count:
		var e := PhoModels.put(bag_root, "trung", Vector3(-0.045 + (k % 3) * 0.045, 0.034, -0.024 + int(k / 3.0) * 0.048))
		_fragile_eggs.append(e)
	for mi: MeshInstance3D in _fragile_bag.find_children("*", "MeshInstance3D", true, false):
		mi.layers = LAYER_BO_BODY


func _damage_fragile() -> void:
	if fragile_item == "" or fragile_count <= 0 or _fragile_cd > 0.0:
		return
	_fragile_cd = 0.5
	fragile_count -= 1
	if fragile_count < _fragile_eggs.size():
		_fragile_eggs[fragile_count].visible = false
	_sfx("egg_crack")
	fragile_damaged.emit(fragile_count)


## Va vào người đi chợ, xe đẩy, sạp: khựng lại một chút, lùi nhẹ ra, không hất văng như xe tông.
func bump(kind: String, from := Vector3.INF, stun := 0.4) -> void:
	# Không có from (xe máy đã tự hất văng Bơ) thì chỉ báo va, không đẩy lùi.
	# Đang ngậm đồ dễ vỡ (túi trứng) thì vỡ một món.
	if from.is_finite():
		var away := global_position - from
		away.y = 0
		away = away.normalized() if away.length() > 0.01 else Vector3.BACK
		velocity.x = away.x * 2.5
		velocity.z = away.z * 2.5
		_stun = maxf(_stun, stun)
		visual.scale = Vector3(1.12, 0.88, 1.12)
		noise_made.emit(global_position, noise_bump)
	bumped.emit(kind)
	_damage_fragile()


## Bị Chó Mực đớp: văng ra và khựng lại một chút.
func knockback(from: Vector3, strength := 9.0, stun := 0.45) -> void:
	var away := global_position - from
	away.y = 0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	play_startle()
	velocity = away * strength + Vector3.UP * 4.5
	_stun = stun
	visual.scale = Vector3(1.3, 0.7, 1.3)
