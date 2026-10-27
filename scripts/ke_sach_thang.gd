class_name KeSachThang
extends Node
## Kệ sách của tháng trên sạp báo Chú Tư (Vũ Trụ Mark C1, Sang duyệt phác thảo 27/10/2026).
## Model nằm trong sap_bao.glb (tools/khu_pho/ke_sach_thang.py, xuất qua tools/khu_pho/xuat_game.py).
## Bơ đi tới gần sạp lần đầu trong cảnh thì hiện một dòng nhắc tên sách của tháng, mỗi cảnh một lần.
## Đổi sách tháng sau: sửa SACH ở đây, màu bìa và chữ thẻ trong ke_sach_thang.py rồi xuất lại sap_bao.

const SACH := "Sách tháng 11 của khu phố: Tư duy nhanh và chậm (Kahneman)"
const GAN := 2.2  # m tính từ tâm sạp

var main: Node
var _da_nhac := false


## Một dòng trong main.gd. Sạp nào muốn có dòng nhắc thì vào nhóm "sap_bao" (deliveries.gd, thu_bay.gd).
static func setup(main_scene: Node) -> void:
	var k := KeSachThang.new()
	k.name = "KeSachThang"
	k.main = main_scene
	main_scene.add_child(k)


func _physics_process(_delta: float) -> void:
	if _da_nhac or main == null:
		return
	var player: Node3D = main.get("player")
	var hud = main.get("hud")
	if player == null or hud == null or not hud.has_method("show_toast"):
		return
	for s: Node in get_tree().get_nodes_in_group("sap_bao"):
		if s is Node3D and (s as Node3D).global_position.distance_to(player.global_position) < GAN:
			_da_nhac = true
			hud.show_toast(SACH, 3.5)
			set_physics_process(false)
			return
