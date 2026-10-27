extends SceneTree
## Kệ sách của tháng (Vũ Trụ Mark C1) trên sạp báo Chú Tư:
## - sap_bao.glb có thêm kệ (số tam giác trong manifest tăng so với sạp cũ 712), chiều cao sạp không đổi;
## - Bơ ở xa sạp thì im, tới gần thì hiện một dòng nhắc tên sách, chỉ một lần mỗi cảnh;
## - câu nhắc có bản tiếng Anh.
## Chạy: godot --headless --path . -s tests/test_ke_sach_thang.gd

var fails := 0


class FakeHud:
	extends CanvasLayer
	var shown: Array[String] = []
	func show_toast(text: String, _seconds := 2.0) -> void:
		shown.append(text)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/pho/manifest.json"))
	var sap: Dictionary = m["sap_bao"]
	_check(int(sap.tris) > 712 and int(sap.tris) <= 1500, "sap_bao có thêm kệ sách (%d tam giác)" % int(sap.tris))
	_check(absf(float(sap.max[1]) - 2.25) < 0.01, "chiều cao sạp không đổi")

	var holder := _Main.new()
	var player := Node3D.new()
	var hud := FakeHud.new()
	holder.add_child(player)
	holder.add_child(hud)
	holder.player = player
	holder.hud = hud
	root.add_child(holder)
	var sap_node := Node3D.new()
	sap_node.add_to_group("sap_bao")
	holder.add_child(sap_node)
	sap_node.global_position = Vector3(1.4, 0.0, -6.6)
	KeSachThang.setup(holder)
	player.global_position = Vector3(10, 0, 10)
	for i in 5:
		await physics_frame
	_check(hud.shown.is_empty(), "Bơ ở xa sạp thì không nhắc")
	player.global_position = Vector3(1.4, 0.0, -5.2)
	for i in 5:
		await physics_frame
	_check(hud.shown.size() == 1 and hud.shown[0] == KeSachThang.SACH, "tới gần sạp thì nhắc tên sách của tháng")
	player.global_position = Vector3(10, 0, 10)
	await physics_frame
	player.global_position = Vector3(1.4, 0.0, -5.2)
	for i in 5:
		await physics_frame
	_check(hud.shown.size() == 1, "chỉ nhắc một lần mỗi cảnh")
	var en: Dictionary = load("res://scripts/dich/en_choi.gd").EN
	_check(en.has(KeSachThang.SACH), "câu nhắc có bản tiếng Anh")
	print("KE SACH THANG TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


class _Main:
	extends Node3D
	var player: Node3D
	var hud: CanvasLayer


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1
