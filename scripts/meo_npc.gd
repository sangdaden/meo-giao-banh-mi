class_name MeoNpc
extends Node3D
## Mèo hàng xóm không do người chơi điều khiển: mèo trong Hội mèo Chủ Nhật, hai mèo lạ trên sân thượng
## Thứ Bảy, sau này mèo trong "Tuần mới". Dùng model 19 giống trong tủ đồ (assets/models/skin/giong, cùng
## bộ 22 xương với Bơ) và phụ kiện (OutfitView.attach). Gói G10 (PR #106): Bà Mướp có giống riêng "bamuop"
## (chỉ bản cái), bản web dùng model nhẹ giong_nhe / phu_kien_nhe, 13 động tác hội trong meo_hoi_dong_tac.json.
##
## Dùng:
##   var m := MeoNpc.from_cast("mit")          # hoặc MeoNpc.make("xiem", "duc", ["bangdo"], "Mít")
##   parent.add_child(m); m.global_position = ...
##   m.walk_to(p) / m.run_to(p) / m.follow_path([p1, p2...], 4.5)  → phát arrived khi tới nơi
##   m.set_pose("ngoi")                        # dung | ngoi | nam | ngu | tron | reo | vay_duoi | kieu | ngoi_cao
##   m.play("nhan_tui")                        # động tác Blender (Bơ G2 hoặc mèo hội G10), một lần → clip_finished
##   m.say("Meo!")                             # bong bóng chữ trên đầu
##
## Không có vật lý: đi thẳng tới đích, tự bám mặt đất/mái nhà bằng tia dò (snap_ground). Đi theo đường
## có độ cao (sân thượng) thì tắt snap_ground, độ cao lấy theo các điểm trên đường.
## Dáng đi, chạy, thở, vẫy đuôi tính bằng code trên xương; ngồi, nằm, reo... là động tác Blender giữ ở một khung.

signal arrived
signal clip_finished(clip_name: String)

## 8 mèo Hội mèo (gói việc goi-viec-chu-nhat.md). Mun và Gừng còn là 2 mèo lạ trên sân thượng Thứ Bảy.
## breed: id giống trong Outfit.BREEDS · acc: phụ kiện đeo sẵn · scale: cỡ so với giống gốc
const CAST := {
	"ba_muop": {"ten": "Bà Mướp", "breed": "bamuop", "sex": "cai", "acc": ["kinhlao", "daykinh", "khanchoang"], "tinh": "chậm rãi, hay cười"},
	"mit": {"ten": "Mít", "breed": "xiem", "sex": "cai", "acc": ["kinhphicong"], "tinh": "nhanh nhẹn, ngại nước"},
	"bot": {"ten": "Bột", "breed": "khoaimon", "sex": "duc", "acc": ["khanran"], "tinh": "chắc chân, không bao giờ trượt"},
	"mun": {"ten": "Mun", "breed": "mun", "sex": "duc", "acc": ["chuong"], "tinh": "lặng lẽ, giỏi trốn"},
	"tuyet": {"ten": "Tuyết", "breed": "tuyet", "sex": "cai", "acc": ["vuongmien"], "tinh": "điệu đà"},
	"lac": {"ten": "Lạc", "breed": "vobanh", "sex": "duc", "acc": ["nonsinhnhat"], "tinh": "vui tính, nhảy kém"},
	"gung": {"ten": "Gừng", "breed": "que", "sex": "duc", "acc": ["bangdo"], "tinh": "hăng hái"},
	"sua": {"ten": "Sữa", "breed": "suadac", "sex": "cai", "acc": ["hoadambut"], "tinh": "hiền, chậm"},
}
## Dáng giữ bằng động tác Blender: [tên động tác, giây giữ (-1 = chạy lặp)]
const POSES := {
	"ngoi": ["ngoi_xem", -1.0],
	"nam": ["phoi_nang", -1.0],
	"ngu": ["ngu_cuon", -1.0],
	"tron": ["tron", -1.0],
	"reo": ["reo", -1.0],
	"vay_duoi": ["vay_duoi", -1.0],
	"kieu": ["tao_dang_kieu", -1.0],
	"ngoi_cao": ["ngoi_san_khau", -1.0],   ## Bà Mướp ngồi thùng gỗ 0,4 m
	"noi": ["noi", -1.0],                   ## Bà Mướp nói (trên thùng)
	"cuoi": ["cuoi", -1.0],                 ## Bà Mướp cười (trên thùng)
}
## Động tác hội mèo (G10), dạng lệch so với dáng nghỉ nên chạy trên mọi giống
const HOI_DONG_TAC := "res://assets/models/meo_hoi_dong_tac.json"
## Giống chân ngắn: độ hạ gốc (root) của động tác nhân theo hệ số chân, không thì thân lún xuống đất
const LEG_K := {"vobanh": 0.62}
const WALK_SPEED := 1.6
const RUN_SPEED := 4.5
const LEGS := [["upperarm_FL", "forearm_FL"], ["upperarm_FR", "forearm_FR"], ["thigh_BL", "shin_BL"], ["thigh_BR", "shin_BR"]]
const TAIL := ["tail_1", "tail_2", "tail_3", "tail_4"]

static var _scenes := {}
static var _data := {}

var ten := ""
var cast_id := ""
var breed := "muop"
var sex := "duc"
var acc: Array = []
var size := 1.0
## Bám mặt đất bằng tia dò mỗi khung (tắt khi đi theo đường có độ cao riêng)
var snap_ground := true
## Đầu quay nhìn theo node này khi trong tầm 6 m (null = không nhìn)
var look_target: Node3D
var pose := "dung"
var moving := false

var _model: Node3D
var _skel: Skeleton3D
var _bone := {}       # tên xương -> chỉ số
var _rest := {}       # tên xương -> quaternion dáng nghỉ
var _path: Array = []
var _speed := WALK_SPEED
var _phase := 0.0
var _gait := 0.0      # 0 đứng · 1 đi · 2 chạy (mượt)
var _t := 0.0
var _clip := ""
var _clip_t := 0.0
var _clip_speed := 1.0
var _clip_hold := -1.0
var _clip_w := 0.0
var _clip_once := false
var _bubble: Label3D
var _bubble_t := 0.0
var _name_tag: Label3D
var _held: Node3D
## Đồ ngậm đang cầm (model G11, gốc = điểm ngậm), null nếu không
var held: Node3D:
	get:
		return _held if is_instance_valid(_held) else null


## Tạo một con mèo theo giống. acc: các id phụ kiện (Outfit.ACCS). Thêm vào cây cảnh rồi mới đặt vị trí.
static func make(breed_id: String, sex_id := "duc", accessories: Array = [], display_name := "") -> MeoNpc:
	var m := MeoNpc.new()
	m.breed = breed_id
	m.sex = sex_id
	m.acc = accessories.duplicate()
	m.ten = display_name
	m.name = "Meo_" + (display_name if display_name != "" else breed_id).replace(" ", "")
	return m


## Một trong 8 mèo của CAST (tên, giống, phụ kiện có sẵn).
static func from_cast(id: String) -> MeoNpc:
	var c: Dictionary = CAST.get(id, CAST.mit)
	var m := make(c.breed, c.get("sex", "duc"), c.get("acc", []), c.ten)
	m.cast_id = id
	m.size = float(c.get("scale", 1.0))
	return m


func _ready() -> void:
	var key := breed + "_" + sex
	if not _scenes.has(key):
		var light := "res://assets/models/skin/giong_nhe/%s.glb" % key
		_scenes[key] = load(light) if OS.has_feature("web") and ResourceLoader.exists(light) else OutfitView.breed_scene(breed, sex)
	var scene: PackedScene = _scenes[key]
	if scene == null:
		scene = load("res://assets/models/bo.glb")
	_model = scene.instantiate()
	_model.rotation.y = PI  # model nhìn về +Z (glTF), Godot coi -Z là phía trước
	_model.scale = Vector3.ONE * size
	add_child(_model)
	var skels := _model.find_children("*", "Skeleton3D", true, false)
	_skel = skels[0] if not skels.is_empty() else null
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		_style(mi)
	if _skel:
		for i in _skel.get_bone_count():
			var n := _skel.get_bone_name(i)
			_bone[n] = i
			_rest[n] = _skel.get_bone_rest(i).basis.get_rotation_quaternion()
		var worn_sex := sex if OutfitView.has_sex_model(breed, sex) else "duc"
		for a in acc:
			OutfitView.attach(_skel, a, breed, worn_sex, OS.has_feature("web"))
	_t = randf() * 10.0
	# Ra khỏi màn hình thì ngừng tính xương cho nhẹ
	var vis := VisibleOnScreenNotifier3D.new()
	vis.aabb = AABB(Vector3(-0.4, 0, -0.5), Vector3(0.8, 0.7, 1.0))
	add_child(vis)
	vis.screen_exited.connect(func(): set_process(moving))
	vis.screen_entered.connect(func(): set_process(true))


# ---------------------------------------------------------------- điều khiển

## Đi bộ tới pos (mặt đất). Tới nơi phát arrived.
func walk_to(pos: Vector3, speed := WALK_SPEED) -> void:
	follow_path([pos], speed)


func run_to(pos: Vector3, speed := RUN_SPEED) -> void:
	follow_path([pos], speed)


## Đi lần lượt qua các điểm. Khi snap_ground = false, độ cao đi theo các điểm (đường sân thượng).
func follow_path(points: Array, speed := RUN_SPEED) -> void:
	_path = points.duplicate()
	_speed = speed
	moving = not _path.is_empty()
	if moving:
		set_pose("dung")
		set_process(true)


func stop() -> void:
	_path.clear()
	moving = false


## Quay mặt về phía pos (ngang).
func face(pos: Vector3) -> void:
	var d := pos - global_position
	d.y = 0.0
	if d.length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)


## Đổi dáng: một khóa của POSES, hoặc "dung". Dáng khác "dung" thì đứng yên tại chỗ.
func set_pose(p: String) -> void:
	pose = p
	if POSES.has(p):
		var d: Array = POSES[p]
		_start_clip(d[0], 1.0, d[1], false)
	elif not _clip_once:
		_clip = ""


## Chạy một động tác Blender một lần: của Bơ ("nhan_tui", "dua_tui", "chup_dung"...) hay mèo hội ("nhay", "lo_dau",
## "gio_bang", "trao_huy_chuong").
## Động tác một lần xong thì phát clip_finished rồi về dáng đang đặt.
func play(clip_name: String, speed := 1.0) -> void:
	if not _clips().has(clip_name):
		return
	_start_clip(clip_name, speed, -1.0, not bool(_clips()[clip_name].loop))


## Bong bóng chữ trên đầu.
## Ngậm một món G11 ở miệng (vd "tui_tiep_suc_cam", "bang_cham"); "" = nhả ra.
func hold(model: String) -> void:
	if is_instance_valid(_held):
		_held.queue_free()
	_held = null
	if model != "" and _skel:
		_held = DoHoi.attach(_skel, "head", model, preload("res://scripts/player.gd").MOUTH)


func say(text: String, seconds := 2.5) -> void:
	if _bubble == null:
		_bubble = _label(0.95, 30)
		_bubble.modulate = Color("#3A2418")
		_bubble.outline_modulate = Color("#FFF8EA")
		_bubble.outline_size = 10
	_bubble.text = text
	_bubble.visible = true
	_bubble_t = seconds


## Hiện tên nhỏ trên đầu (Hội mèo: người chơi biết ai là ai).
func show_name(on := true) -> void:
	if _name_tag == null:
		_name_tag = _label(0.58, 22)
		_name_tag.text = ten
		_name_tag.modulate = Color("#FFF8EA")
		_name_tag.outline_modulate = Color("#3A2418")
		_name_tag.outline_size = 8
	_name_tag.visible = on


# ---------------------------------------------------------------- mỗi khung

func _process(delta: float) -> void:
	_t += delta
	var target_gait := 0.0
	if moving:
		target_gait = 2.0 if _speed > 3.0 else 1.0
		_move(delta)
	_gait = move_toward(_gait, target_gait, delta * 4.0)
	if _bubble and _bubble.visible:
		_bubble_t -= delta
		_bubble.visible = _bubble_t > 0.0
	if _skel == null:
		return
	_pose_code(delta)
	_clip_step(delta)
	_apply_clip()


func _move(delta: float) -> void:
	var goal: Vector3 = _path[0]
	var pos := global_position
	var flat := Vector3(goal.x - pos.x, 0, goal.z - pos.z)
	var step := _speed * delta
	if flat.length() <= step:
		pos = Vector3(goal.x, pos.y if snap_ground else goal.y, goal.z)
		_path.pop_front()
	else:
		var dir := flat.normalized()
		var k := step / flat.length()
		pos += dir * step
		if not snap_ground:
			pos.y = lerpf(pos.y, goal.y, clampf(k, 0.0, 1.0))
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-12.0 * delta))
	if snap_ground:
		pos.y = _ground_y(pos)
	global_position = pos
	if _path.is_empty():
		moving = false
		arrived.emit()


func _ground_y(pos: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 1.2, pos + Vector3.DOWN * 3.0, Blocks.LAYER_WORLD | Blocks.LAYER_PROP)
	var hit := space.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else pos.y


## Dáng tính bằng code: thở, đi/chạy (vung chân theo nhịp), đuôi vẫy, đầu nhìn theo.
func _pose_code(delta: float) -> void:
	for n in _rest:
		_skel.set_bone_pose_rotation(_bone[n], _rest[n])
		_skel.set_bone_pose_position(_bone[n], _skel.get_bone_rest(_bone[n]).origin)
	var freq := lerpf(5.5, 11.0, clampf(_gait - 1.0, 0.0, 1.0))
	_phase += delta * freq * clampf(_gait, 0.0, 1.0)
	var amp := lerpf(0.0, 0.45, clampf(_gait, 0.0, 1.0)) + 0.25 * clampf(_gait - 1.0, 0.0, 1.0)
	# chạy: hai chân trước cùng nhịp, hai chân sau cùng nhịp (phi); đi: chéo nhau
	var offs := [0.0, PI, PI * 0.5, PI * 1.5] if _gait < 1.5 else [0.0, 0.3, PI, PI + 0.3]
	for i in 4:
		var s := sin(_phase + offs[i])
		var front := i < 2
		_rot(LEGS[i][0], Vector3.RIGHT, s * amp * (1.0 if front else 1.1))
		_rot(LEGS[i][1], Vector3.RIGHT, maxf(0.0, -cos(_phase + offs[i])) * amp * (-0.9 if front else 0.9))
	var root: int = _bone.get("root", -1)
	if root >= 0:
		var bob := absf(sin(_phase * 2.0)) * 0.015 * clampf(_gait, 0.0, 2.0)
		_skel.set_bone_pose_position(root, _skel.get_bone_rest(root).origin + Vector3(0, bob + sin(_t * 1.6) * 0.002, 0))
	# đuôi: cong lên khi đi, vẫy chậm khi đứng
	for i in TAIL.size():
		var sway := sin(_t * (1.3 if _gait < 0.5 else 4.0) - i * 0.6) * (0.12 + i * 0.05)
		_rot(TAIL[i], Vector3.BACK, sway)
	# đầu nhìn theo
	if look_target and is_instance_valid(look_target) and _gait < 0.5:
		var to := to_local(look_target.global_position)
		if to.length() < 6.0:
			var yaw := clampf(atan2(-to.x, -to.z), -1.0, 1.0)
			_rot("head", Vector3.UP, yaw * 0.7)


func _rot(bone_name: String, axis: Vector3, angle: float) -> void:
	var i: int = _bone.get(bone_name, -1)
	if i >= 0:
		_skel.set_bone_pose_rotation(i, _skel.get_bone_pose_rotation(i) * Quaternion(axis, angle))


# ---------------------------------------------------------------- động tác Blender

## Động tác của Bơ (G2) gộp với động tác mèo hội (G10): cùng dáng nghỉ, cùng 30 khung/giây.
static func dong_tac() -> Dictionary:
	if _data.is_empty():
		var bo: Dictionary = preload("res://scripts/player.gd").dong_tac()
		_data = {"fps": bo.get("fps", 30), "rest": bo.get("rest", {}), "clips": bo.get("clips", {}).duplicate()}
		if FileAccess.file_exists(HOI_DONG_TAC):
			var hoi: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HOI_DONG_TAC))
			_data.clips.merge(hoi.get("clips", {}), true)
			if _data.rest.is_empty():
				_data.rest = hoi.get("rest", {})
	return _data


static func _clips() -> Dictionary:
	return dong_tac().get("clips", {})


func _start_clip(clip_name: String, speed: float, hold: float, once: bool) -> void:
	if not _clips().has(clip_name):
		return
	if _clip != clip_name:
		_clip_w = 0.0
	_clip = clip_name
	_clip_t = 0.0
	_clip_speed = speed
	_clip_hold = hold
	_clip_once = once


func _clip_step(delta: float) -> void:
	if _clip == "":
		_clip_w = 0.0
		return
	var c: Dictionary = _clips()[_clip]
	var dur := float(c.dur)
	_clip_w = move_toward(_clip_w, 0.0 if moving and not _clip_once else 1.0, delta / 0.15)
	if _clip_hold >= 0.0:
		_clip_t = minf(_clip_t + delta * _clip_speed, _clip_hold)
	else:
		_clip_t += delta * _clip_speed
		if c.loop:
			_clip_t = fposmod(_clip_t, dur)
		elif _clip_t >= dur:
			var done := _clip
			_clip_t = dur
			_clip_once = false
			set_pose(pose)
			if _clip == done:
				_clip = ""
			clip_finished.emit(done)


func _apply_clip() -> void:
	if _clip == "" or _clip_w <= 0.0:
		return
	var data := dong_tac()
	var c: Dictionary = data.clips[_clip]
	var rest: Dictionary = data.rest
	var w := smoothstep(0.0, 1.0, _clip_w)
	var fr := _clip_t * float(data.fps)
	var P := preload("res://scripts/player.gd")
	for bone_name: String in c.bones:
		var idx: int = _bone.get(bone_name, -1)
		if idx < 0 or not rest.has(bone_name):
			continue
		var ch: Dictionary = c.bones[bone_name]
		var rb: Dictionary = rest[bone_name]
		if ch.has("r"):
			var rq := Quaternion(rb.r[0], rb.r[1], rb.r[2], rb.r[3])
			var q: Quaternion = _rest[bone_name] * (rq.inverse() * P._clip_q(ch.r, fr))
			_skel.set_bone_pose_rotation(idx, _skel.get_bone_pose_rotation(idx).slerp(q.normalized(), w))
		if ch.has("p") and bone_name == "root":
			var p: Vector3 = P._clip_v(ch.p, fr) - Vector3(rb.p[0], rb.p[1], rb.p[2])
			p.z = 0.0  # động tác đi chỗ khác (bật tường...) thì giữ mèo tại chỗ
			p.y *= float(LEG_K.get(breed, 1.0))
			_skel.set_bone_pose_position(idx, _skel.get_bone_pose_position(idx).lerp(_skel.get_bone_rest(idx).origin + p, w))


# ---------------------------------------------------------------- vẽ

func _style(mi: MeshInstance3D) -> void:
	var names: Array[String] = []
	for i in mi.mesh.get_surface_count():
		var src := mi.get_active_material(i)
		names.append(src.resource_name if src else "")
	if RenderingServer.get_rendering_device() == null and mi.mesh is ArrayMesh:
		mi.mesh = OutfitView.srgb_mesh(mi.mesh)  # bản web: màu đỉnh linear -> sRGB như Forward+
	for i in mi.mesh.get_surface_count():
		var mat_name := names[i] if i < names.size() else ""
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		if mat_name.begins_with("Sang"):
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		elif mat_name.begins_with("Mat"):
			m.roughness = 0.3
		else:
			m.roughness = 0.85
			m.rim_enabled = true
			m.rim = 0.3
		mi.set_surface_override_material(i, m)


func _label(height: float, font: int) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.pixel_size = 0.004
	l.font_size = font
	l.position = Vector3(0, height * size, 0)
	add_child(l)
	return l
