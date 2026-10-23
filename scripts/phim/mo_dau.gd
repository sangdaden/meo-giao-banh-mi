extends Node
## Phim mở đầu 40 s, rạng sáng Thứ Hai (storyboard M1–M8 trên trang C1 Sang duyệt 23/10/2026):
## Bơ chưa khăn chưa túi đi dọc vỉa hè, ngửi mùi bánh; Cô Ba bưng khay ra xe, quàng khăn đỏ, đưa túi bánh xanh,
## chỉ ra phố; Bơ nhảy lên thùng gỗ, chữ "Thứ Hai" hiện rồi vào game. Toạ độ theo bản phác thảo (CanhPhim.B).
## Giữ phím cách 1 giây để bỏ qua.

const BoPhim := preload("res://scripts/phim/bo_phim.gd")

var p: Phim
var bo: BoPhim
var coba: Nguoi
var _set: Node3D


func run(phim: Phim) -> void:
	p = phim
	_set = CanhPhim.pho(p, "sang")["set"]
	PhoModels.put(_set, "thung_go", B(-1.2, -2.5))
	bo = BoPhim.new()
	bo.name = "Bo"
	p.add_child(bo)
	bo.dress({})  # chưa có khăn, chưa có túi
	coba = Nguoi.make("coba", "dung_yen")
	p.add_child(coba)
	_put_coba(B(2.2, 0.6), 0.0)
	coba.visible = false  # trong tiệm, tới M3 mới ra
	p.ambience("morning")
	p.music("menu")

	# M1 0:00–0:05 · rạng sáng, cẩu máy hạ dần về Lò bánh, tên game
	bo.place(B(-8.0, -1.5), _yaw(-90))
	bo.go(B(0.6, -1.5), 1.35)
	p.cut(B(-5, -15, 7.5), B(3, 0, 3.2), 26)
	p.move(B(-1.5, -9.5, 3.0), B(2.0, 0, 1.6), 28, 5.0)
	p.fade(0.0, 1.4)
	p.bars(true)
	if not await p.wait(0.8):
		return
	p.title("Mèo Giao Bánh Mì", 3.6, 96)
	if not await p.wait(4.2):
		return

	# M2 0:05–0:10 · mùi bánh: máy thấp ngang mắt mèo, theo ngang rồi dừng
	p.track(bo, Vector3(1.4, 0.42, 1.15), Vector3(0, 0.32, 0), 32)
	await bo.arrived
	if p.done:
		return
	bo.face_point(B(2.7, 0))  # quay về cửa lò bánh
	bo.pose("ngui_mui")
	p.move(B(1.95, -2.65, 0.42), B(0.6, -1.4, 0.42), 32, 1.5)
	p.sound("sniff")
	if not await p.wait(1.2):
		return
	p.sound("sniff")
	if not await p.wait(2.6):
		return

	# M3 0:10–0:15 · Cô Ba bưng khay bánh ra xe, thấy Bơ ngồi ngay ngắn
	p.cut(B(0.2, -5.0, 1.45), B(3.0, -1.4, 0.5), 30)
	var tray := _tray()
	coba.visible = true
	_put_coba(B(2.2, -0.3), 0.0)
	_coba_face(B(3.5, -0.85))
	coba.play("bung_khay", 0.0)
	var tw := p.create_tween()
	tw.tween_property(coba, "position", B(3.5, -0.85), 1.6)
	bo.go(B(2.4, -2.15), 1.2)
	p.sound("step_wood")
	if not await p.wait(1.7):
		return
	# đặt khay lên nóc tủ kính xe bánh mì rồi quay sang Bơ
	tray.reparent(_set)
	tray.global_transform = Transform3D(Basis(), B(4.4, -1.25) + XeCoBa.TRAY + Vector3(0, 0.01, 0))
	p.sound("glass_rattle", -6.0)
	_coba_face(bo.global_position)
	coba.play("noi")
	bo.face_point(coba.global_position)
	bo.pose("ngoi_yen")
	p.say("Cô Ba", "Ủa, mèo ở đâu mà ngoan dữ vậy nè?", 3.0, "coba_hello")
	if not await p.wait(3.3):
		return

	# M4 0:15–0:21 · quàng khăn đỏ: cận ngang, đẩy vào nút khăn (khay bánh nằm lại trên xe)
	_put_coba(B(2.2, -1.5), 0.0)
	coba.play("quang_khan", 0.0)
	var scarf := CanhPhim.prop(p, "khan_cam")
	var hands := Giua.new()
	hands.person = coba
	hands.item = scarf
	hands.drop = 0.30
	p.add_child(hands)
	bo.place(B(2.2, -2.12), _yaw(180))
	bo.pose("ngua_co")
	p.cut(B(3.7, -3.5, 0.9), B(2.2, -1.8, 0.55), 32)
	p.move(B(3.35, -3.1, 0.8), B(2.2, -1.9, 0.5), 32, 6.0)
	if not await p.wait(0.3):
		return
	p.say("Cô Ba", "Quàng cái khăn này cho ấm cổ nghe con.", 3.4, "coba_ok")
	if not await p.wait(3.6):
		return
	hands.queue_free()
	scarf.queue_free()
	bo.dress({"neck": "khando"})
	p.sound("wrap")
	if not await p.wait(2.1):
		return

	# M5 0:21–0:26 · ngắm khăn mới
	_put_coba(B(2.0, -1.2), -15.0)
	coba.play("vui", 0.0)
	bo.place(B(2.2, -2.1), _yaw(15))
	bo.pose("ngam_khan")
	p.cut(B(2.75, -4.4, 0.75), B(2.15, -1.6, 0.6), 30)
	p.move(B(2.6, -4.0, 0.7), B(2.15, -1.7, 0.55), 30, 5.0)
	if not await p.wait(1.4):
		return
	p.say("Bơ", "Meo!", 2.2, "meow")
	if not await p.wait(3.6):
		return

	# M6 0:26–0:31 · túi bánh xanh
	_put_coba(B(2.2, -1.45), 0.0)
	coba.play("dua_tui", 0.0)
	var bag := _bag_in_hand()
	bo.place(B(2.2, -2.15), _yaw(180))
	bo.pose("ngoi_yen")
	p.cut(B(4.2, -3.6, 1.3), B(2.2, -1.7, 0.7), 32)
	if not await p.wait(0.3):
		return
	p.say("Cô Ba", "Phụ cô giao bánh cho bà con trong xóm được hông?", 3.6, "coba_order")
	if not await p.wait(3.0):
		return
	bag.queue_free()
	bo.dress({"neck": "khando", "back": "tuibanh"})
	p.sound("pickup")
	if not await p.wait(0.7):
		return
	p.sound("meow_short")
	if not await p.wait(1.0):
		return

	# M7 0:31–0:36 · năm đơn sáng nay: sau lưng hai người nhìn ra đường
	_put_coba(B(2.2, -2.2), -15.0)
	coba.play("chi_ra_pho", 0.0)
	bo.place(B(2.85, -2.8), _yaw(20))
	bo.pose("")
	p.cut(B(2.75, -0.35, 1.65), B(2.3, -5.5, 0.2), 26)
	if not await p.wait(0.3):
		return
	p.say("Cô Ba", "Sáng nay có năm đơn. Đi từ từ thôi, không ai hối đâu!", 4.2, "coba_good")
	if not await p.wait(1.8):
		return
	p.sound("moto_pass", -6.0)
	if not await p.wait(2.9):
		return

	# M8 0:36–0:40 · Bơ nhảy lên thùng gỗ, máy vòng ra sau lưng như camera chơi
	_put_coba(B(3.3, -1.3), 0.0)
	_coba_face(B(-1.2, -2.5))
	coba.play("vay")
	p.cut(B(1.9, -3.4, 1.2), B(-1.2, -2.4, 0.6), 30)
	bo.go(B(-0.55, -2.5), 4.2)
	await bo.arrived
	if p.done:
		return
	var crate_top := PhoModels.aabb("thung_go").end.y
	bo.hop(B(-1.2, -2.5, crate_top), 0.45, 0.45)
	p.sound("jump")
	p.move(B(1.1, -2.55, 1.5), B(-3.2, -2.4, 0.7), 32, 2.0)
	await bo.arrived
	if p.done:
		return
	p.sound("land")
	if not await p.wait(0.6):
		return
	p.title("Thứ Hai", 2.4, 110)
	p.music("delivery")
	if not await p.wait(2.2):
		return
	_done()


func skip() -> void:
	_done()


func _done() -> void:
	GameState.set_global("da_xem_mo_dau", true)
	GameState.write_save()
	p.finish(func():
		if Phim.after == "menu":
			PlayMode.go_home(p.get_tree())
		else:
			PlayMode.play_week(p.get_tree()))


## Toạ độ bản phác thảo -> Godot (CanhPhim.B).
static func B(x: float, y: float, z := 0.0) -> Vector3:
	return CanhPhim.B(x, y, z)


## Hướng mặt của Bơ theo góc rz trong bản phác thảo (rz 0: nhìn ra đường).
static func _yaw(rz: float) -> float:
	return deg_to_rad(rz) + PI


func _put_coba(pos: Vector3, rz: float) -> void:
	coba.position = pos
	coba.rotation.y = deg_to_rad(rz)


## Khay inox bánh vàng trên tay phải Cô Ba (như trong bếp: kitchen.gd _build_co_ba).
func _tray() -> Node3D:
	var at := coba.attach("hand.R")
	var tray := KitchenModels.place(at, "khay_inox", Vector3(-0.12, 0.02, 0.08))
	for i in 4:
		KitchenModels.place(tray, "banh_vang", Vector3(-0.15 + i * 0.1, 0.02, 0), 90.0)
	return tray


## Cô Ba quay mặt về điểm pos (model người nhìn về +Z).
func _coba_face(pos: Vector3) -> void:
	var d := pos - coba.global_position
	coba.rotation.y = atan2(d.x, d.z)


## Túi bánh xanh (phụ kiện tuibanh, bỏ quai đeo) cầm thẳng đứng dưới tay phải Cô Ba.
func _bag_in_hand() -> Node3D:
	var scene: PackedScene = load(OutfitView.DIR + "phu_kien/tuibanh.glb")
	var bag: Node3D = scene.instantiate()
	var objs: Dictionary = OutfitView.meta().get("phu_kien", {}).get("tuibanh", {}).get("objects", {})
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in bag.find_children("*", "MeshInstance3D", true, false):
		if mi.name.begins_with("Quai") or mi.name.begins_with("Dem") or mi.name.begins_with("Banh"):
			mi.visible = false
			continue
		if AnhSang.is_compat() and DisplayServer.get_name() != "headless":
			mi.mesh = OutfitView.srgb_mesh(mi.mesh)  # bản web: màu đỉnh linear -> sRGB như OutfitView.attach
		OutfitView.style(mi, objs.get(String(mi.name), {}))
		var b := mi.transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var holder := Giua.new()
	holder.person = coba
	holder.item = bag
	holder.one_hand = "hand.R"
	holder.drop = 0.14
	bag.position = -box.get_center()
	var pivot := Node3D.new()
	pivot.add_child(bag)
	holder.item = pivot
	p.add_child(pivot)
	p.add_child(holder)
	pivot.tree_exiting.connect(holder.queue_free)
	return pivot


## Đặt một món giữa hai bàn tay của người (khăn vắt trên hai tay), hoặc dưới một bàn tay, đứng thẳng.
class Giua extends Node:
	var person: Nguoi
	var item: Node3D
	var one_hand := ""
	var drop := 0.0

	func _process(_delta: float) -> void:
		if not is_instance_valid(person) or not is_instance_valid(item) or person.skeleton == null:
			return
		var sk := person.skeleton
		if one_hand != "":
			var h := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(one_hand)).origin
			item.global_transform = Transform3D(Basis(Vector3.UP, person.rotation.y), h - Vector3(0, drop, 0))
			return
		var l := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand.L")).origin
		var r := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand.R")).origin
		var x := r - l
		x.y = 0.0
		var yaw := atan2(-x.z, x.x)
		item.global_transform = Transform3D(Basis(Vector3.UP, yaw), (l + r) * 0.5 - Vector3(0, drop, 0))
