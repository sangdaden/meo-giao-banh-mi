class_name DoChuyen
extends Node
## Đồ 3D của chuyện tuần "Bí mật cho Cô Ba" (R2) ngoài phố, theo trang duyệt 24/10
## (https://claude.ai/artifact/2oxRYWdjepyueHYDRLdDwG; model: tools/chuyen/do_chuyen.py -> assets/models/chuyen/):
## - lá thư Hùng–Mây (L3) ngậm ở miệng Bơ suốt lúc đang mang thư, cất đi khi Bơ ngậm ổ bánh để giao;
## - trang nhất báo sáng của ngày (O1) dán lên nửa phải tờ báo Chú Tư đang đọc (bao_mo);
## - bảng đồng "Lò bánh Cô Ba" của ông Sáu treo trên mi cửa lò bánh, sau khi người chơi đã qua buổi bất ngờ Chủ Nhật.
## Thiệp 30 năm (thiep_30.glb, mặt trong đổi texture theo số chữ ký qua thiep()) dùng ở buổi mừng Chủ Nhật.
## scripts/chuyen/chuyen.gd thêm node này; không đụng sao, không chặn chơi.

const THU := {1: "la_thu_hung", 2: "la_thu_may", 3: "la_thu_hung"}
const MODEL := "res://assets/models/chuyen/%s.glb"
const MOUTH := Vector3(0, 0.368, 0.30)   ## điểm miệng trong hệ model Bơ (như ổ bánh, scripts/player.gd)
const BAO := "res://assets/chuyen/bao_%s.jpg"
## Bảng đồng: đáy cao Y_BANG m, mặt sau áp mặt trước hộp cuốn cửa (cách mép trong mái hiên Z_HOP_CUON m)
const Y_BANG := 2.55
const Z_HOP_CUON := -0.12

var main: Node
var day_id := ""
var _thu: Node3D            ## lá thư đang ngậm
var _thu_n := 0
var _att: BoneAttachment3D
var _skel: Skeleton3D


func _ready() -> void:
	name = "DoChuyen"
	main = get_parent().get_parent() if get_parent() else null
	if main == null or not "day" in main:
		return
	day_id = str(main.day.get("id", ""))
	_bao.call_deferred()
	_bang_dong.call_deferred()


## Thiệp 30 năm mở, mặt trong theo ảnh assets/chuyen/<trong>.jpg (thiep_trong_0 / _3 / _8 / _du).
static func thiep(trong: String) -> Node3D:
	var n: Node3D = (load(MODEL % "thiep_30") as PackedScene).instantiate()
	var path := "res://assets/chuyen/%s.jpg" % trong
	if ResourceLoader.exists(path):
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s)
				if m and m.resource_name == "Thiep_trong":
					var m2: StandardMaterial3D = (m as StandardMaterial3D).duplicate()
					m2.albedo_texture = load(path)
					mi.set_surface_override_material(s, m2)
	return n


# ---------------------------------------------------------------- thư ở miệng Bơ

## Số thư Bơ đang mang (đã nhận, chưa tới tay), 0 nếu không mang.
static func thu_dang_mang() -> int:
	for n in [3, 2, 1]:
		if Chuyen.co_thu(n):
			return n
	return 0


func _process(_delta: float) -> void:
	if main == null:
		return
	var n := thu_dang_mang()
	var p: Node = main.get("player")
	if p == null:
		return
	var sk: Skeleton3D = p.get("_skel")
	if n != _thu_n or sk != _skel or not is_instance_valid(_thu):
		_dung_thu(n, sk)
	if _thu:
		var banh: Node3D = p.get("_mouth_bread")
		_thu.visible = not (banh != null and banh.visible)


func _dung_thu(n: int, sk: Skeleton3D) -> void:
	if is_instance_valid(_att):
		_att.queue_free()
	_att = null
	_thu = null
	_thu_n = n
	_skel = sk
	if n == 0 or sk == null or not is_instance_valid(sk):
		return
	var hi := sk.find_bone("head")
	if hi < 0:
		return
	_att = BoneAttachment3D.new()
	_att.bone_name = "head"
	sk.add_child(_att)
	_thu = (load(MODEL % THU[n]) as PackedScene).instantiate()
	# thư dựng đứng ngang miệng, mặt phong bì nhìn ra trước, mép trên ngậm trong miệng (như trang duyệt)
	_thu.transform = sk.get_bone_global_rest(hi).affine_inverse() * Transform3D(Basis.from_euler(Vector3(0.3, 0, 0)), MOUTH + Vector3(0, -0.012, -0.02))
	_att.add_child(_thu)
	for mi: MeshInstance3D in _thu.find_children("*", "MeshInstance3D", true, false):
		mi.layers = 1 << 10  # Player.LAYER_BO_BODY: camera góc thứ nhất bỏ qua


# ---------------------------------------------------------------- báo Chú Tư

func _bao() -> void:
	var d: Node = main.get("deliveries")
	var paper: Node3D = d.get("_tu_paper") if d else null
	var path := BAO % day_id
	if paper == null or not ResourceLoader.exists(path):
		return
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in paper.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = paper.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		box = a if first else box.merge(a)
		first = false
	if first:
		return
	var w := box.size.x * 0.5 * 0.92
	var h := minf(box.size.y * 0.92, w * 4.0 / 3.0)
	var q := MeshInstance3D.new()
	q.name = "TrangNhat"
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, h)
	pm.orientation = PlaneMesh.FACE_Z
	q.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.roughness = 0.9
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position = Vector3(box.position.x + box.size.x * 0.75, box.position.y + box.size.y * 0.5, box.end.z + 0.004)
	paper.add_child(q)


# ---------------------------------------------------------------- bảng đồng trên cửa lò bánh

func _bang_dong() -> void:
	if (GameState.get_day("huy_chuong", [], "chu_nhat") as Array).is_empty():
		return
	# mặt trước hộp cuốn cửa lò bánh: sau mép trong mái hiên (FIXME nếu đổi model lo_banh)
	var mai: Node3D = null
	for n: Node in get_tree().get_nodes_in_group("mai_hien"):
		if n is Node3D and absf((n as Node3D).global_position.x - City.BAKERY_POINT.x) < 2.0:
			mai = n
	if mai == null:
		return
	var face_z := mai.global_position.z - 0.5 + Z_HOP_CUON
	var b: Node3D = (load(MODEL % "bang_dong") as PackedScene).instantiate()
	b.name = "BangDong"
	main.add_child(b)
	b.global_position = Vector3(City.BAKERY_POINT.x, Y_BANG, face_z)
