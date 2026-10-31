class_name DauVetMark
extends Node
## Dấu vết khu phố (Vũ Trụ Mark G1, Sang duyệt phác thảo 31/10/2026, trang https://claude.ai/artifact/PBBv3zEMstcgqE5SmuBYUN):
## tờ poster "Hàng xóm tầng 3 làm video về AI" ở cầu thang Lô B chung cư (Thứ Năm) và ti vi cũ chiếu Bit trong bếp Cô Ba.
## Model: tools/dau_vet/dau_vet.py --game (bỏ bevel, khối gộp một mesh "vo"); mặt giấy "giay" và màn "man_hinh"
## dán ảnh poster.png / man_tv.png nằm cạnh glb. Poster 132 tam giác, ti vi 448, không thêm đèn.
## Bơ đi tới gần poster lần đầu trong cảnh thì hiện một dòng nhắc, mỗi cảnh một lần (giống kệ sách tháng).

const DIR := "res://assets/models/dau_vet/"
const NHAC := "Anh Mark tầng 3 làm video về AI, ghé markhocai.com xem nha!"
const GAN := 2.0  # m tính từ tâm tờ poster

var scene: Node
var poster_node: Node3D
var _da_nhac := false


## Dán poster: pos là tâm tờ giấy sát mặt tường, mặt giấy nhìn theo +Z đã xoay rot_y. Trả về node để test.
static func poster(parent: Node, pos: Vector3, rot_y: float) -> Node3D:
	var n := _dat(parent, "poster_mark", pos, rot_y)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(DIR + "poster.png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.roughness = 0.9
	_dan(n, "giay", m)
	var k := DauVetMark.new()
	k.name = "DauVetMark"
	k.scene = parent
	k.poster_node = n
	parent.add_child(k)
	return n


## Treo ti vi: pos là đáy giá sắt, mặt màn nhìn theo +Z đã xoay rot_y, tường nằm sau 0,26 m.
static func ti_vi(parent: Node, pos: Vector3, rot_y: float) -> Node3D:
	var n := _dat(parent, "ti_vi_bit", pos, rot_y)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(DIR + "man_tv.png")
	m.emission_enabled = true
	m.emission_texture = m.albedo_texture
	m.emission_energy_multiplier = 0.6
	m.roughness = 0.35
	_dan(n, "man_hinh", m)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.visibility_range_end = 14.0
	return n


static func _dat(parent: Node, ten: String, pos: Vector3, rot_y: float) -> Node3D:
	var n: Node3D = (load(DIR + ten + ".glb") as PackedScene).instantiate()
	n.name = ten
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # mỏng sát tường, bóng không thấy
	return n


static func _dan(n: Node3D, mesh_ten: String, m: Material) -> void:
	for mi: MeshInstance3D in n.find_children(mesh_ten + "*", "MeshInstance3D", true, false):
		mi.material_override = m


func _physics_process(_delta: float) -> void:
	if _da_nhac or scene == null or poster_node == null:
		return
	var player = scene.get("player")
	var hud = scene.get("hud")
	if not (player is Node3D) or hud == null or not hud.has_method("show_toast"):
		return
	if (player as Node3D).global_position.distance_to(poster_node.global_position) < GAN:
		_da_nhac = true
		hud.show_toast(NHAC, 3.5)
		set_physics_process(false)
