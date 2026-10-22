class_name AnhChung
extends Node3D
## Ảnh chụp chung dán vào Sổ hàng xóm (bố cục G9 Sang duyệt 22/10, nguồn g9canh.py).
## Giúp xong: Bơ tới đứng đúng chỗ cạnh người (trên quầy, bàn quán, yên xe...), chơi dáng G2,
## người chơi chup_chung, máy ảnh tạm đặt trước mặt người; ThuBay chụp rồi gọi done() để trả Bơ về chỗ cũ.
##
## Toạ độ trong LAYOUT theo khung Blender của trang phác thảo: x sang phải (nhìn từ máy ảnh), y ra sau lưng người,
## z lên; gốc là chỗ người đứng ("origin": "table" = giữa bàn cờ), người nhìn ra máy ảnh (-y).
## "rot" là góc xoay quanh trục đứng như trong Blender. "prop": đồ dựng tạm khi chỗ đó trong phố không có mặt đứng.

const LAYOUT := {
	"coba": {"person": Vector3(0, 0, 0), "prot": 0.1, "bo": Vector3(0.55, 0, 0.94), "rot": -0.3, "clip": "chup_dung",
		"cam": Vector3(0.3, -3.4, 1.3), "at": Vector3(0.35, 0, 0.95), "lens": 42.0,
		"prop": {"at": Vector3(0.62, 0.05, 0), "size": Vector3(0.7, 0.5, 0.9), "color": "#9A6A3E"}},
	"chutu": {"person": Vector3(-0.2, 0, 0), "prot": 0.05, "bo": Vector3(0.42, -0.25, 0), "rot": -0.2, "clip": "chup_vay",
		"cam": Vector3(0.1, -3.3, 1.2), "at": Vector3(0.1, 0, 0.85), "lens": 42.0},
	"bena": {"person": Vector3(-0.15, 0, 0), "prot": 0.1, "bo": Vector3(0.38, -0.2, 0), "rot": -0.3, "clip": "chup_vay",
		"cam": Vector3(0.1, -2.6, 0.9), "at": Vector3(0.1, 0, 0.6), "lens": 40.0},
	"may": {"person": Vector3(-0.2, 0, 0), "prot": -0.1, "bo": Vector3(0.5, -0.1, 0.715), "rot": -0.25, "clip": "chup_dung",
		"cam": Vector3(0.15, -3.4, 1.25), "at": Vector3(0.15, 0, 0.9), "lens": 42.0,
		"prop": {"at": Vector3(0.5, -0.1, 0), "size": Vector3(0.64, 0.64, 0.7), "color": "#E9E2D2", "round": true}},
	"hung": {"person": Vector3(-0.2, 0, 0), "prot": 0.05, "bo": Vector3(0.45, -0.2, 0), "rot": -0.3, "clip": "chup_dung",
		"cam": Vector3(0.1, -3.5, 1.25), "at": Vector3(0.15, 0, 0.9), "lens": 42.0},
	"basau": {"person": Vector3(0, 0, 0), "prot": 0.1, "bo": Vector3(0.55, -0.25, 0), "rot": -0.4, "clip": "chup_nam",
		"cam": Vector3(0.25, -3.0, 1.0), "at": Vector3(0.25, 0, 0.6), "lens": 42.0},
	"ongbay": {"origin": "table", "bo": Vector3(0, 0.02, 0.556), "rot": 0.0, "clip": "chup_dung",
		"cam": Vector3(0, -3.2, 1.25), "at": Vector3(0, 0, 0.7), "lens": 40.0,
		"prop": {"at": Vector3(0, 0.05, 0), "size": Vector3(0.64, 0.64, 0.53), "color": "#BDB6A8", "round": true}},
	"cohai": {"person": Vector3(-0.25, 0, 0), "prot": 0.1, "bo": Vector3(1.0, -0.15, 0), "rot": -0.4, "clip": "chup_vay",
		"cam": Vector3(0.3, -3.4, 1.15), "at": Vector3(0.35, 0, 0.8), "lens": 40.0},
	"chunam": {"person": Vector3(0, 0, 0), "prot": 0.0, "bo": Vector3(0.82, -0.02, 0.72), "rot": -0.2, "clip": "ngoi_goi",
		"cam": Vector3(0.7, -4.2, 1.35), "at": Vector3(0.75, 0, 0.85), "lens": 40.0,
		"prop": {"at": Vector3(0.82, -0.02, 0), "size": Vector3(0.32, 0.6, 0.72), "color": "#2E6FA8"},
		"guest": {"id": "khachxeom", "at": Vector3(1.55, -0.15, 0), "rot": -0.25}},
	"chithu": {"person": Vector3(-0.1, 0, 0), "prot": 0.1, "bo": Vector3(0.5, -0.25, 0), "rot": -0.4, "clip": "chup_nam",
		"cam": Vector3(0.15, -3.2, 1.2), "at": Vector3(0.2, 0, 0.8), "lens": 42.0},
}
const FIT := 0.3            ## mặt đứng có sẵn lệch hơn chừng này so với bố cục thì dựng đồ tạm
const CAM_MARGIN := 0.2     ## máy ảnh lùi khỏi tường
const CAM_MIN := 1.8        ## vật chắn gần người hơn chừng này (xe đậu, cột) thì bỏ qua, không dí máy ảnh vào mặt

var player: CharacterBody3D
var person: Nguoi
var cam: Camera3D
var _prev_cam: Camera3D
var _bo_back := Vector3.ZERO
var _bo_yaw := 0.0
var _origin := Vector3.ZERO
var _right := Vector3.RIGHT
var _front := Vector3.BACK  ## từ người hướng ra máy ảnh
var _guest: Nguoi
var _person_yaw := 0.0
var _turned := false


static func has(id: String) -> bool:
	return LAYOUT.has(id)


## Dựng ảnh: đưa Bơ vào chỗ, người tạo dáng, bật máy ảnh tạm. people: id -> Nguoi của ThuBay.
func setup(id: String, the_player: CharacterBody3D, people: Dictionary) -> void:
	var L: Dictionary = LAYOUT[id]
	player = the_player
	person = people.get(id)
	_frame(id, L, people)
	_bo_back = player.global_position
	_bo_yaw = player.visual.rotation.y
	# đồ dựng tạm (quầy, bàn quán, bàn đá, yên xe) chỉ khi chỗ đó trong phố không có mặt đứng đúng tầm
	var bo_at := _w(L.bo)
	var stand_y := _origin.y + float(L.bo.z)
	var s := ViecNho.surface(get_world_3d(), bo_at.x, bo_at.z, stand_y + 0.5)
	if L.bo.z > 0.1 and absf(s.y - stand_y) > FIT and L.has("prop"):
		_prop(L.prop)
		s.y = stand_y
	elif L.bo.z <= 0.1:
		s = ViecNho.surface(get_world_3d(), bo_at.x, bo_at.z, _origin.y + 1.0)
	player.velocity = Vector3.ZERO
	player.can_move = false
	player.global_position = Vector3(bo_at.x, s.y + 0.02, bo_at.z)
	var d := _front.rotated(Vector3.UP, float(L.rot))
	player.visual.rotation.y = atan2(-d.x, -d.z)  # model Bơ nhìn -Z của visual
	player.play_clip(str(L.clip))
	var guest_id: String = L.get("guest", {}).get("id", "")
	if ResourceLoader.exists("res://assets/models/nguoi/%s_tb.glb" % guest_id):
		guest_id += "_tb"  # Thứ Bảy không đội mũ
	if guest_id != "" and not Nguoi.in_scene(get_tree(), guest_id):
		_guest = Nguoi.make(guest_id, "dung_yen")
		add_child(_guest)
		_guest.global_position = _w(L.guest.at)
		var gd := _front.rotated(Vector3.UP, float(L.guest.rot))
		_guest.rotation.y = atan2(gd.x, gd.z)  # Nguoi nhìn +Z
		_guest.play("chup_chung")
	for n: Nguoi in _people(id, people):
		n.play("chup_chung" if n.anim and n.anim.has_animation("chup_chung") else "vui")
	_camera(L)


## Chụp xong: trả Bơ về chỗ cũ, người về động tác thường, tắt máy ảnh tạm, dỡ đồ dựng.
func done() -> void:
	if is_instance_valid(player):
		player.stop_clip()
		player.global_position = _bo_back
		player.visual.rotation.y = _bo_yaw
		player.velocity = Vector3.ZERO
		player.can_move = true
	if _prev_cam and is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	if _turned and is_instance_valid(person):
		person.rotation.y = _person_yaw
	for n: Nguoi in get_tree().get_nodes_in_group(Nguoi.GROUP):
		if n.current() == "chup_chung" or n == person:
			n.back_to_idle()
	queue_free()


## Khung ảnh: gốc, hướng phải và hướng ra máy ảnh theo người đang đứng trong phố.
func _frame(id: String, L: Dictionary, people: Dictionary) -> void:
	if L.get("origin", "") == "table":
		_origin = ChessCorner.CENTER
		var a: Node3D = people.get("ongbay")
		var b := _find("ongtam")
		if a and b:
			_right = (b.global_position - a.global_position)
			_right.y = 0.0
			_right = _right.normalized()
			_front = _right.cross(Vector3.UP)
			# máy ảnh đứng về phía ít người xem cờ đứng chắn hơn
			if _crowd(_front) > _crowd(-_front):
				_right = -_right
				_front = -_front
		_origin.y = 0.0  # bàn cờ đặt trên vỉa hè
		return
	if person == null:
		_origin = player.global_position
		return
	var f := person.global_basis.z
	f.y = 0.0
	f = f.normalized()
	# trước mặt người là tường sát bên: người quay sang hướng thoáng (trả lại hướng cũ khi chụp xong)
	_person_yaw = person.rotation.y
	for turn in [0.0, PI / 2.0, -PI / 2.0, PI]:
		var t := f.rotated(Vector3.UP, turn)
		if _clear(person.global_position, t, L):
			if turn != 0.0:
				person.rotation.y = _person_yaw + turn
				_turned = true
			f = t
			break
	_front = f.rotated(Vector3.UP, -float(L.get("prot", 0.0)))
	_right = Vector3.UP.cross(_front)
	var p: Vector3 = L.get("person", Vector3.ZERO)
	_origin = person.global_position - _right * p.x + _front * p.y
	_origin.y = person.global_position.y


## Máy ảnh đặt theo hướng f có thấy người không (không vướng tường gần hơn CAM_MIN).
func _clear(at: Vector3, f: Vector3, L: Dictionary) -> bool:
	var c: Vector3 = L.cam
	var a: Vector3 = L.at
	var from := at + Vector3.UP.cross(f) * c.x - f * c.y + Vector3.UP * c.z
	var to := at + Vector3.UP.cross(f) * a.x + Vector3.UP * a.z
	var q := PhysicsRayQueryParameters3D.create(to, from, Blocks.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or to.distance_to(hit.position) > CAM_MIN + 0.6


## Số người đứng giữa bàn cờ và máy ảnh nếu máy ảnh ở phía f.
func _crowd(f: Vector3) -> int:
	var n := 0
	for p: Nguoi in get_tree().get_nodes_in_group(Nguoi.GROUP):
		var d := p.global_position - _origin
		d.y = 0.0
		var along := d.dot(f)
		if along > 0.3 and along < 3.2 and absf(d.dot(Vector3.UP.cross(f))) < 0.9:
			n += 1
	return n


## Toạ độ bố cục (khung Blender) → thế giới.
func _w(v: Vector3) -> Vector3:
	return _origin + _right * v.x - _front * v.y + Vector3.UP * v.z


func _people(id: String, people: Dictionary) -> Array[Nguoi]:
	var out: Array[Nguoi] = []
	if id == "ongbay":
		for k in ["ongbay", "ongtam"]:
			var n: Nguoi = people.get(k) if people.has(k) else _find(k)
			if n:
				out.append(n)
	elif person:
		out.append(person)
	return out


func _find(pid: String) -> Nguoi:
	for n: Nguoi in get_tree().get_nodes_in_group(Nguoi.GROUP):
		if n.id == pid and not n.is_queued_for_deletion():
			return n
	return null


func _prop(spec: Dictionary) -> void:
	var size: Vector3 = spec.size  # rộng, sâu, cao
	var at := _w(spec.at)
	var body := Blocks.solid_box(self, Vector3(size.x, size.z, size.y), at + Vector3(0, size.z / 2.0, 0), Color(spec.color), Blocks.LAYER_PROP)
	body.global_basis = Basis(Vector3.UP, atan2(_front.x, _front.z))
	if spec.get("round", false):  # bàn tròn: giấu khối, thay bằng mặt tròn + chân
		for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			mi.visible = false
		var top := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = size.x / 2.0
		cyl.bottom_radius = size.x / 2.0
		cyl.height = 0.04
		top.mesh = cyl
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(spec.color)
		m.roughness = 0.6
		top.material_override = m
		add_child(top)
		top.global_position = at + Vector3(0, size.z - 0.02, 0)
		var leg := MeshInstance3D.new()
		var lc := CylinderMesh.new()
		lc.top_radius = 0.05
		lc.bottom_radius = 0.08
		lc.height = size.z
		leg.mesh = lc
		leg.material_override = m
		add_child(leg)
		leg.global_position = at + Vector3(0, size.z / 2.0, 0)


func _camera(L: Dictionary) -> void:
	_prev_cam = get_viewport().get_camera_3d()
	cam = Camera3D.new()
	cam.name = "MayAnhChung"
	add_child(cam)
	var at := _w(L.at)
	var from := _w(L.cam)
	# tường, quầy chắn giữa người và máy ảnh: máy ảnh tiến lại
	var q := PhysicsRayQueryParameters3D.create(at, from, Blocks.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit and at.distance_to(hit.position) > CAM_MIN:
		from = hit.position + (at - from).normalized() * CAM_MARGIN
	cam.global_position = from
	cam.look_at(at, Vector3.UP)
	# lens Blender (phim 36 mm, ảnh 1200×1000) → góc dọc của Godot
	cam.fov = rad_to_deg(2.0 * atan(18.0 / float(L.lens) * 1000.0 / 1200.0))
	cam.make_current()
