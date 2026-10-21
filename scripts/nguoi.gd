class_name Nguoi
extends Node3D
## Một người dân khu phố: model .glb dựng trong Blender (tools/nguoi_game.py), 19 xương,
## animation keyframe làm sẵn trong Blender. Code chỉ chọn animation, trộn chuyển cảnh và
## xoay đầu nhìn theo Bơ cho sống động.
##
## Dùng:
##   var p := Nguoi.make("coba")          # thêm vào cây cảnh SAU Blocks.merge_static (gộp sẽ ăn mất mesh có xương)
##   p.position = ...; p.rotation.y = ... # model nhìn về +Z cục bộ
##   p.look_target = player               # đầu quay theo Bơ khi lại gần
##   p.play("cho_banh"); p.play_once("nhan_banh")  # play_once xong tự về idle_anim
##
## Animation có sẵn (mọi người): dung_yen, noi, vay, vui, sot_ruot, cho_banh, nhan_banh, viec_rieng.
## Người đứng có thêm di_bo; Bé Na có keo_day; Bà Sáu có goi_muc.
## Thứ Ba (trang phác thảo Thứ Ba): Ông Bảy, Ông Tám viec_rieng = đánh cờ, thêm suyt, mang, reo;
## Cô Hai dua_tui; Chú Năm cho_khach, nhan_xe, cho_di (tựa yên xe máy cao 0,93 m, chở khách);
## người xem cờ (Ông Chín xemco, người đi chợ dicho1-3) xem, reo; người đi chợ thêm dung_chon, va;
## Cô Tư bán rau (bancho, ngồi) ngoi_rao; Chú Sáu (hangrong) day_xe, quat_than, va; Cô Bảy (ganhhang) ganh_di, va.
## Chị Thảo khách xe ôm (khachxeom): ngoi_sau (yên sau, hông 0,95 m), nhan_banh trên yên, xuong_xe.
## Người ngồi (Chú Tư, Anh Hùng, Bà Sáu, hai ông, Chú Năm) làm mọi động tác ở tư thế ngồi;
## gốc model là mặt đất, ghế đặt sao cho mặt ghế đúng chiều cao trong SEAT.

signal finished(anim_name: String)

const IDS := ["coba", "chutu", "bena", "may", "hung", "basau", "ongbay", "ongtam", "cohai", "chunam",
	"xemco", "bancho", "hangrong", "ganhhang", "dicho1", "dicho2", "dicho3", "khachxeom"]
const NAMES := {
	"coba": "Cô Ba", "chutu": "Chú Tư", "bena": "Bé Na", "may": "Chị Mây", "hung": "Anh Hùng",
	"basau": "Bà Sáu", "ongbay": "Ông Bảy", "ongtam": "Ông Tám", "cohai": "Cô Hai", "chunam": "Chú Năm",
	"xemco": "Ông Chín", "bancho": "Cô Tư", "hangrong": "Chú Sáu", "ganhhang": "Cô Bảy",
	"dicho1": "Bà Tư", "dicho2": "Anh Tâm", "dicho3": "Chị Hồng", "khachxeom": "Chị Thảo",
}
## Chiều cao mặt ghế (m) của người ngồi, khớp với ROLES trong tools/nguoi_game.py
const SEAT := {"chutu": 0.45, "hung": 0.28, "basau": 0.42, "ongbay": 0.30, "ongtam": 0.30, "chunam": 0.45, "bancho": 0.18}
const ONE_SHOT := ["nhan_banh", "goi_muc", "suyt", "mang", "reo", "dua_tui", "nhan_xe", "va", "xuong_xe"]

## Model và mesh đã đổi màu cho bản web, dùng chung giữa các lần tạo
static var _scenes := {}
static var _srgb_meshes := {}

var id := ""
## Animation khi rảnh; play_once xong thì quay về đây.
var idle_anim := "viec_rieng"
## Đầu quay nhìn theo node này khi trong tầm look_range mét (null = không nhìn).
var look_target: Node3D
var look_range := 6.0

var anim: AnimationPlayer
var skeleton: Skeleton3D
var _current := ""
var _after := ""
var _after_for := 0.0
var _busy_until := 0.0
var _look: Node


static func make(person_id: String, idle := "viec_rieng") -> Nguoi:
	var p := Nguoi.new()
	p.id = person_id
	p.idle_anim = idle
	p.name = "Nguoi_" + person_id
	return p


func _ready() -> void:
	if not _scenes.has(id):
		_scenes[id] = load("res://assets/models/nguoi/%s.glb" % id)
	var model: Node3D = _scenes[id].instantiate()
	add_child(model)
	skeleton = model.find_child("*", true, false) as Skeleton3D
	if skeleton == null:
		for n in model.find_children("*", "Skeleton3D", true, false):
			skeleton = n
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		_apply_style(mi)
	for n in model.find_children("*", "AnimationPlayer", true, false):
		anim = n
	if anim:
		for a in anim.get_animation_list():
			anim.get_animation(a).loop_mode = Animation.LOOP_NONE if a in ONE_SHOT else Animation.LOOP_LINEAR
		anim.animation_finished.connect(_on_finished)
		play(idle_anim if anim.has_animation(idle_anim) else "dung_yen", 0.0)
		# Mỗi người lệch nhịp một chút để cả phố không thở cùng lúc
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(id)
		anim.seek(rng.randf() * anim.current_animation_length, true)
		anim.speed_scale = rng.randf_range(0.92, 1.08)
	if skeleton:
		_look = preload("res://scripts/nguoi_nhin.gd").new()
		_look.owner_person = self
		skeleton.add_child(_look)
	# Ra khỏi màn hình thì ngừng tính animation cho nhẹ (bản web)
	var vis := VisibleOnScreenNotifier3D.new()
	vis.aabb = AABB(Vector3(-0.6, 0, -0.6), Vector3(1.2, 1.9, 1.2))
	vis.screen_entered.connect(func(): _set_active(true))
	vis.screen_exited.connect(func(): _set_active(false))
	add_child(vis)


func _set_active(on: bool) -> void:
	if anim:
		anim.active = on


## Chuyển sang animation lặp (trộn mềm blend giây). Không có thì giữ nguyên.
func play(anim_name: String, blend := 0.35) -> void:
	if anim == null or not anim.has_animation(anim_name):
		return
	_after = ""
	if _current == anim_name and anim.is_playing():
		return
	_current = anim_name
	anim.play(anim_name, blend)


## Chơi một lần rồi chuyển sang then_anim (mặc định idle_anim);
## then_for > 0 thì then_anim chỉ chơi chừng đó giây rồi về idle_anim.
func play_once(anim_name: String, then_anim := "", then_for := 0.0) -> void:
	if anim == null or not anim.has_animation(anim_name):
		return
	_current = anim_name
	_after = then_anim if then_anim != "" else idle_anim
	_after_for = then_for
	anim.get_animation(anim_name).loop_mode = Animation.LOOP_NONE
	anim.play(anim_name, 0.25)
	anim.seek(0.0, true)


## Chơi một animation lặp trong seconds giây rồi về idle_anim (vd. "vui" sau khi nhận bánh).
## Trong lúc đó busy() trả true để code khác không giành động tác.
func play_for(anim_name: String, seconds: float) -> void:
	play(anim_name)
	_busy_until = Time.get_ticks_msec() / 1000.0 + seconds
	var token := anim_name
	get_tree().create_timer(seconds).timeout.connect(func():
		if is_instance_valid(self) and _current == token:
			play(idle_anim))


func busy() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _busy_until


func back_to_idle() -> void:
	play(idle_anim)


func current() -> String:
	return _current


func _on_finished(anim_name: String) -> void:
	finished.emit(anim_name)
	if _after != "" and anim_name == _current:
		var next := _after
		var secs := _after_for
		_after = ""
		_after_for = 0.0
		_current = ""
		if next in ONE_SHOT:
			play_once(next)
		elif secs > 0.0:
			play_for(next, secs)
		else:
			play(next, 0.4)


## Gắn đồ vào xương (tờ báo, ổ bánh, quạt...). Trả node gắn để thêm đồ vào.
func attach(bone: String) -> Node3D:
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skeleton.add_child(ba)
	return ba


## Khối va chạm cho người (Bơ không chạy xuyên qua). size theo mét, center tính từ gốc model.
func add_collision(size: Vector3, center: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Blocks.LAYER_PROP
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	shape.position = center
	body.add_child(shape)
	add_child(body)
	return body


## Vật liệu theo style guide D: da/vải mờ (màu ở màu đỉnh), tròng mắt bóng, đốm sáng luôn trắng.
func _apply_style(mi: MeshInstance3D) -> void:
	mi.visibility_range_end = 30.0  # xa hơn chỉ còn vài điểm ảnh, khỏi vẽ
	mi.lod_bias = 0.5  # đổi sang mức LOD thấp sớm hơn (người nhỏ trong khung)
	if RenderingServer.get_rendering_device() == null:
		if not _srgb_meshes.has(id):
			_srgb_meshes[id] = _srgb_copy(mi.mesh)
		mi.mesh = _srgb_meshes[id]
	for i in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(i)
		var mat_name := src.resource_name if src else ""
		mi.set_surface_override_material(i, _material(mat_name))


static var _mats := {}


static func _material(mat_name: String) -> StandardMaterial3D:
	var key := "Sang" if mat_name.begins_with("Sang") else "Mat" if mat_name.begins_with("Mat") else "Than"
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	match key:
		"Sang":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"Mat":
			m.roughness = 0.25
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
		_:
			m.roughness = 0.85
			m.rim_enabled = true
			m.rim = 0.3
	_mats[key] = m
	return m


## Bản web (Compatibility) không đổi màu đỉnh linear sang sRGB như Forward+ (giống Bơ trong player.gd).
## Bản sao dựng lại các mức LOD (không có thì người ở xa vẫn vẽ đủ ~3,8k tam giác).
static func _srgb_copy(src: ArrayMesh) -> ArrayMesh:
	var im := ImporterMesh.new()
	for i in src.get_surface_count():
		var arrays := src.surface_get_arrays(i)
		var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for k in cols.size():
			cols[k] = cols[k].linear_to_srgb()
		arrays[Mesh.ARRAY_COLOR] = cols
		im.add_surface(src.surface_get_primitive_type(i), arrays, [], {}, src.surface_get_material(i), "", src.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()
