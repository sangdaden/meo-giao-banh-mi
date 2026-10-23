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
## Người chợ thêm: Cô Năm (cho4, bán đứng), Bé Thư (cho5), Ông Út (cho6), Chị Mai (cho7) mac_ca, dung_chon, xem, reo;
## Chú Tám (cho8, bán ngồi ghế đẩu) mac_ca. Người chợ nào cũng có va, di_bo và bản nhẹ (ban = "nhe" / "dong").
## Người ngồi (Chú Tư, Anh Hùng, Bà Sáu, hai ông, Chú Năm) làm mọi động tác ở tư thế ngồi;
## gốc model là mặt đất, ghế đặt sao cho mặt ghế đúng chiều cao trong SEAT.
## Thứ Bảy (trang G9): ai cũng có chup_chung (đứng chụp ảnh chung với Bơ, lặp). Cô Ba nem_banh, khen_ngon;
## Chú Tư (đứng cả ngày) voi_bao, chi_len, nhan_bao, dung_cho; Bé Na nup, lo_dau, bi_tim_thay, chay_tron;
## Chị Mây chi_bang, vo_tay, lac_dau_cuoi; Anh Hùng cui_tim, nhan_oc; Bà Sáu (chup_chung ngồi) chi_gian, nhan_bong;
## hai ông chi_quan_co; Cô Hai chong_nanh, vo_tay; Chú Năm (chup_chung trên yên xe) gai_dau, chi_mai;
## Chị Thảo không mũ "khachxeom_tb" tim_mu, nhan_mu. Chú Tư, Anh Hùng, Bà Sáu, Chú Năm có di_bo.
## Người qua đường (trang P3, id qd_*): chỉ có bản "nhe" (mặc định) và "dong". 8 người gốc qd_ongtd, qd_vanphong,
## qd_hocsinh, qd_sinhvien, qd_veso, qd_giaohang, qd_congnhan, qd_mehoa; đổi đồ <id>_b (qd_hocsinh_b là Bé Ngân);
## áo mưa qd_vanphong_mua, qd_hocsinh_mua, qd_congnhan_mua, qd_giaohang_mua, qd_mehoa_mua; đội nón đi xe
## qd_sinhvien_xe, qd_hocsinh_xe (Anh Đạt, Chị Hoa lúc nào cũng đội). Clip chung: di_bo, chay, dung_cho, dung_yen,
## vay, vui, noi, ne_bo, len_xe_buyt (bậc 0,35 m, xong thì đứng cao 0,35 m), xuong_xe_buyt, che_mua; người lớn
## nhin_dt, goi_dt, ngoi_ghe (ghế 0,26 m); Ông Hai, Cô Tám di_cham; Ông Hai vuon_vai; Cô Tám moi_ve;
## Chú Bảy ngoi_an, lau_mo_hoi; Chị Hoa vay_con; Bé Khoa vay_bo, ngoi_sau (yên sau, hông 0,95 m);
## Anh Đạt, Chị Hoa, Anh Phúc lai_xe (hông 0,95 m), len_xe, xuong_xe, dat_xe (đi bộ dắt xe).
## Đồ cầm tay P3: dien_thoai, ly_tra_da, bang_ve_so, xap_ve, hop_com, dua, goi_hang, tui_che_dau.
## Đồ cầm tay G9 (assets/models/nguoi, gốc ở chỗ tay cầm): ly_ca_phe, banh_mieng, nua_o, con_oc, bong_giay, mu_hong.

signal finished(anim_name: String)

const IDS := ["coba", "chutu", "bena", "may", "hung", "basau", "ongbay", "ongtam", "cohai", "chunam",
	"xemco", "bancho", "hangrong", "ganhhang", "dicho1", "dicho2", "dicho3", "khachxeom",
	"cho4", "cho5", "cho6", "cho7", "cho8",
	"may_mua", "cohai_mua", "bena_mua", "chunam_mua", "chutu_mua", "chithu",
	"thanh", "loan", "muoi", "hanh", "bin", "mit", "khachxeom_tb",
	"qd_ongtd", "qd_vanphong", "qd_hocsinh", "qd_sinhvien", "qd_veso", "qd_giaohang", "qd_congnhan", "qd_mehoa",
	"qd_ongtd_b", "qd_vanphong_b", "qd_hocsinh_b", "qd_sinhvien_b", "qd_veso_b", "qd_giaohang_b", "qd_congnhan_b", "qd_mehoa_b",
	"qd_vanphong_mua", "qd_hocsinh_mua", "qd_congnhan_mua", "qd_giaohang_mua", "qd_mehoa_mua", "qd_sinhvien_xe", "qd_hocsinh_xe"]
const NAMES := {
	"coba": "Cô Ba", "chutu": "Chú Tư", "bena": "Bé Na", "may": "Chị Mây", "hung": "Anh Hùng",
	"basau": "Bà Sáu", "ongbay": "Ông Bảy", "ongtam": "Ông Tám", "cohai": "Cô Hai", "chunam": "Chú Năm",
	"xemco": "Ông Chín", "bancho": "Cô Tư", "hangrong": "Chú Sáu", "ganhhang": "Cô Bảy",
	"dicho1": "Bà Tư", "dicho2": "Anh Tâm", "dicho3": "Chị Hồng", "khachxeom": "Chị Thảo",
	"cho4": "Cô Năm", "cho5": "Bé Thư", "cho6": "Ông Út", "cho7": "Chị Mai", "cho8": "Chú Tám",
	"may_mua": "Chị Mây", "cohai_mua": "Cô Hai", "bena_mua": "Bé Na", "chunam_mua": "Chú Năm", "chutu_mua": "Chú Tư",
	"chithu": "Chị Thu",
	"thanh": "Chú Thành", "loan": "Cô Loan", "muoi": "Ông Mười", "hanh": "Chị Hạnh", "bin": "Bé Bin", "mit": "Bé Mít",
	"khachxeom_tb": "Chị Thảo",
	"qd_ongtd": "Ông Hai", "qd_vanphong": "Chị Vy", "qd_hocsinh": "Bé Khoa", "qd_sinhvien": "Anh Phúc",
	"qd_veso": "Cô Tám", "qd_giaohang": "Anh Đạt", "qd_congnhan": "Chú Bảy", "qd_mehoa": "Chị Hoa",
	"qd_ongtd_b": "Ông Hai", "qd_vanphong_b": "Chị Vy", "qd_hocsinh_b": "Bé Ngân", "qd_sinhvien_b": "Anh Phúc",
	"qd_veso_b": "Cô Tám", "qd_giaohang_b": "Anh Đạt", "qd_congnhan_b": "Chú Bảy", "qd_mehoa_b": "Chị Hoa",
	"qd_vanphong_mua": "Chị Vy", "qd_hocsinh_mua": "Bé Khoa", "qd_congnhan_mua": "Chú Bảy", "qd_giaohang_mua": "Anh Đạt",
	"qd_mehoa_mua": "Chị Hoa", "qd_sinhvien_xe": "Anh Phúc", "qd_hocsinh_xe": "Bé Khoa",
}
## Chiều cao mặt ghế (m) của người ngồi, khớp với ROLES trong tools/nguoi_game.py
const SEAT := {"chutu": 0.45, "hung": 0.28, "basau": 0.42, "ongbay": 0.30, "ongtam": 0.30, "chunam": 0.45, "bancho": 0.18, "cho8": 0.32, "chunam_mua": 0.45, "muoi": 0.26}
const ONE_SHOT := ["nhan_banh", "goi_muc", "suyt", "mang", "reo", "dua_tui", "nhan_xe", "va", "xuong_xe", "goi_1", "goi_2", "nhan_banh_cau",
	"cam_on", "mo_cua", "thuc_day", "ngoi_day", "dat_mam", "vap_nhe",
	"nem_banh", "khen_ngon", "nhan_bao", "bi_tim_thay", "vo_tay", "lac_dau_cuoi", "nhan_oc", "nhan_bong", "nhan_mu",
	"ne_bo", "len_xe_buyt", "xuong_xe_buyt", "len_xe", "xuong_xe", "vuon_vai", "moi_ve", "lau_mo_hoi"]

## Mọi người dân Nguoi.make ra đều vào nhóm này: một người chỉ có một bản trong cảnh.
## Cảnh phụ (người xem cờ...) hỏi in_scene() rồi mới dựng, nhường người đã có chỗ trong ngày (khách, chợ).
const GROUP := "nguoi_dan"

## Model và mesh đã đổi màu cho bản web, dùng chung giữa các lần tạo
static var _scenes := {}
static var _srgb_meshes := {}
## Thư viện animation dùng chung của người qua đường, theo model gốc (anim_source)
static var _libs := {}

var id := ""
## Bản model: "" đủ chi tiết (~3,8k tam giác), "nhe" ~1,4k (người chợ, phố đông), "dong" ~600 (đám đông xa).
## Đặt trước khi thêm vào cây cảnh: n.ban = "nhe". Cùng xương và animation với bản đủ.
var ban := ""
## Model đang mặc nếu khác id (vd. "may_mua" ngày mưa, xem wear()); id vẫn giữ để code khác tìm người.
var model_id := ""
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
	p.add_to_group(GROUP)
	return p


## Người id đã được dựng ở đâu đó trong cảnh chưa (khách của ngày, người chợ, hàng xóm...).
static func in_scene(tree: SceneTree, person_id: String) -> bool:
	for n in tree.get_nodes_in_group(GROUP):
		if (n as Nguoi).id == person_id and not n.is_queued_for_deletion():
			return true
	return false


func _ready() -> void:
	if id.begins_with("qd_") and ban == "":
		ban = "nhe"  # người qua đường chỉ có bản nhẹ và bản xa
	var key := id + ("_" + ban if ban != "" else "")
	if not _scenes.has(key):
		_scenes[key] = load("res://assets/models/nguoi/%s.glb" % key)
	var model: Node3D = _scenes[key].instantiate()
	add_child(model)
	skeleton = model.find_child("*", true, false) as Skeleton3D
	if skeleton == null:
		for n in model.find_children("*", "Skeleton3D", true, false):
			skeleton = n
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		_apply_style(mi)
	anim = _model_anim(model, id)
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


## Cầm đồ đứng thẳng (dù, giỏ, cuộn bạt): đồ đi theo vị trí xương nhưng không xoay theo bàn tay,
## nên dù luôn dựng đứng. offset tính theo hướng người (x trái, y lên, z trước). Trả node model để chỉnh thêm.
func hold(model: String, bone: String, offset := Vector3.ZERO) -> Node3D:
	var holder := Node3D.new()
	add_child(holder)
	var m: Node3D = (load(model) as PackedScene).instantiate()
	m.position = offset
	holder.add_child(m)
	var rt := RemoteTransform3D.new()
	rt.update_rotation = false
	rt.update_scale = false
	attach(bone).add_child(rt)
	rt.remote_path = rt.get_path_to(holder)
	return m


## Đổi sang model khác cùng khung xương (bộ đồ theo ngày, vd. áo mưa Thứ Tư "may_mua") khi người đã vào cảnh.
## Giữ id, vị trí, va chạm và animation đang chơi; đồ gắn bằng attach()/hold() trước đó phải gắn lại.
func wear(new_model: String) -> void:
	var old: Node = skeleton.owner if skeleton else null
	if old == null or not ResourceLoader.exists("res://assets/models/nguoi/%s.glb" % new_model):
		return
	model_id = new_model
	var key := new_model + ("_" + ban if ban != "" else "")
	if not _scenes.has(key):
		_scenes[key] = load("res://assets/models/nguoi/%s.glb" % key)
	var model: Node3D = _scenes[key].instantiate()
	var pos := anim.current_animation_position if anim and anim.is_playing() else 0.0
	var playing := _current
	if anim and anim.animation_finished.is_connected(_on_finished):
		anim.animation_finished.disconnect(_on_finished)
	if _look:
		_look.get_parent().remove_child(_look)
	remove_child(old)
	old.queue_free()
	add_child(model)
	move_child(model, 0)
	skeleton = null
	anim = null
	for n in model.find_children("*", "Skeleton3D", true, false):
		skeleton = n
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		_apply_style(mi)
	anim = _model_anim(model, new_model)
	if anim:
		for a in anim.get_animation_list():
			anim.get_animation(a).loop_mode = Animation.LOOP_NONE if a in ONE_SHOT else Animation.LOOP_LINEAR
		anim.animation_finished.connect(_on_finished)
		_current = ""
		play(playing if anim.has_animation(playing) else idle_anim, 0.0)
		if anim.is_playing():
			anim.seek(minf(pos, anim.current_animation_length), true)
	if skeleton and _look:
		skeleton.add_child(_look)


## AnimationPlayer của model. Người qua đường (qd_*): chỉ bản nhẹ của người gốc mang clip (qd_vanphong_nhe),
## bản đổi đồ, áo mưa, đội nón đi xe và bản xa (_b, _mua, _xe, _dong) mượn chung, cùng khung xương,
## để bản web khỏi chở hơn chục bộ clip giống hệt nhau.
func _model_anim(model: Node3D, model_name: String) -> AnimationPlayer:
	for n in model.find_children("*", "AnimationPlayer", true, false):
		return n
	if not model_name.begins_with("qd_"):
		return null
	var src := anim_source(model_name)
	if not _libs.has(src):
		var s: Node = (load("res://assets/models/nguoi/%s.glb" % src) as PackedScene).instantiate()
		var players := s.find_children("*", "AnimationPlayer", true, false)
		_libs[src] = (players[0] as AnimationPlayer).get_animation_library("") if players.size() > 0 else null
		s.free()
	if _libs[src] == null:
		return null
	var a := AnimationPlayer.new()
	a.name = "AnimationPlayer"
	model.add_child(a)
	a.add_animation_library("", _libs[src])
	return a


## Model mang clip của người qua đường: qd_hocsinh_xe, qd_hocsinh_mua_dong... -> qd_hocsinh_nhe
static func anim_source(model_name: String) -> String:
	var g := model_name
	for suf in ["_dong", "_nhe", "_xe", "_mua", "_b"]:
		g = g.trim_suffix(suf)
	return g + "_nhe"


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
		var key := (model_id if model_id != "" else id) + ("_" + ban if ban != "" else "")
		if not _srgb_meshes.has(key):
			_srgb_meshes[key] = _srgb_copy(mi.mesh)
		mi.mesh = _srgb_meshes[key]
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


## Đúc một khung hình của clip thành mesh tĩnh (không xương) để vẽ hàng loạt bằng MultiMesh
## (người lái xe máy trong traffic.gd). model: tên file trong nguoi/ (vd. "qd_mehoa_dong"), clip lấy từ
## anim_source. Gộp mọi mặt thành một mặt màu đỉnh, gốc ở chân, mặt trước +Z. Bản web đã đổi màu sang sRGB.
static func bake_pose(model: String, clip: String, t := 0.0) -> ArrayMesh:
	var root: Node3D = (load("res://assets/models/nguoi/%s.glb" % model) as PackedScene).instantiate()
	var skel: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var src := anim_source(model)
	if not _libs.has(src):
		var s: Node = (load("res://assets/models/nguoi/%s.glb" % src) as PackedScene).instantiate()
		var players := s.find_children("*", "AnimationPlayer", true, false)
		_libs[src] = (players[0] as AnimationPlayer).get_animation_library("") if players.size() > 0 else null
		s.free()
	var lib: AnimationLibrary = _libs[src]
	if lib and lib.has_animation(clip):
		var a := lib.get_animation(clip)
		for tr in a.get_track_count():
			var b := skel.find_bone(a.track_get_path(tr).get_concatenated_subnames())
			if b < 0:
				continue
			match a.track_get_type(tr):
				Animation.TYPE_POSITION_3D:
					skel.set_bone_pose_position(b, a.position_track_interpolate(tr, t))
				Animation.TYPE_ROTATION_3D:
					skel.set_bone_pose_rotation(b, a.rotation_track_interpolate(tr, t))
				Animation.TYPE_SCALE_3D:
					skel.set_bone_pose_scale(b, a.scale_track_interpolate(tr, t))
	var to_srgb := RenderingServer.get_rendering_device() == null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var to_root := _to_root(skel, root)
		var binds: Array[Transform3D] = []
		for i in mi.skin.get_bind_count():
			var bn := mi.skin.get_bind_name(i)
			var b := skel.find_bone(bn) if bn != "" else mi.skin.get_bind_bone(i)
			binds.append(to_root * skel.get_bone_global_pose(b) * mi.skin.get_bind_pose(i))
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per := bones.size() / verts.size()
			var flat := Color.WHITE
			var mat := mi.mesh.surface_get_material(si)
			if mat is BaseMaterial3D:
				flat = (mat as BaseMaterial3D).albedo_color
			var out_v := PackedVector3Array()
			var out_n := PackedVector3Array()
			var out_c := PackedColorArray()
			out_v.resize(verts.size())
			out_n.resize(verts.size())
			out_c.resize(verts.size())
			for v in verts.size():
				var p := Vector3.ZERO
				var nn := Vector3.ZERO
				for k in per:
					var w := weights[v * per + k]
					if w > 0.0:
						var xf := binds[bones[v * per + k]]
						p += xf * verts[v] * w
						nn += xf.basis * norms[v] * w
				out_v[v] = p
				out_n[v] = nn.normalized()
				var c := cols[v] if cols.size() > 0 else flat
				out_c[v] = c.linear_to_srgb() if to_srgb else c
			var a2 := []
			a2.resize(Mesh.ARRAY_MAX)
			a2[Mesh.ARRAY_VERTEX] = out_v
			a2[Mesh.ARRAY_NORMAL] = out_n
			a2[Mesh.ARRAY_COLOR] = out_c
			a2[Mesh.ARRAY_INDEX] = arr[Mesh.ARRAY_INDEX]
			var tmp := ArrayMesh.new()
			tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
			st.append_from(tmp, 0, Transform3D.IDENTITY)
	root.free()
	return st.commit()


static func _to_root(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	while n and n != root:
		xf = n.transform * xf
		n = n.get_parent() as Node3D
	return xf
