extends SceneTree
## Dấu vết khu phố (Vũ Trụ Mark G1): poster kênh anh Mark ở chung cư, ti vi chiếu Bit trong bếp Cô Ba.
## - hai model nạp được, mặt giấy và màn có ảnh, số tam giác đúng như trang duyệt (poster 132, ti vi 448);
## - Bơ ở xa poster thì im, tới gần thì hiện một dòng nhắc, chỉ một lần mỗi cảnh; câu nhắc có bản tiếng Anh;
## - cảnh chung cư và bếp đều có món của mình.
## Chạy: godot --headless --path . -s tests/test_dau_vet_mark.gd

var fails := 0


class FakeHud:
	extends CanvasLayer
	var shown: Array[String] = []
	func show_toast(text: String, _seconds := 2.0) -> void:
		shown.append(text)


class _Main:
	extends Node3D
	var player: Node3D
	var hud: CanvasLayer


func _init() -> void:
	_run.call_deferred()


func _tris(n: Node) -> int:
	var t := 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var idx = a[Mesh.ARRAY_INDEX]
			t += (idx.size() if idx != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return t


func _anh(n: Node, ten: String) -> bool:
	for mi: MeshInstance3D in n.find_children(ten + "*", "MeshInstance3D", true, false):
		var m := mi.material_override as StandardMaterial3D
		if m != null and m.albedo_texture != null:
			return true
	return false


func _run() -> void:
	var holder := _Main.new()
	var player := Node3D.new()
	var hud := FakeHud.new()
	holder.add_child(player)
	holder.add_child(hud)
	holder.player = player
	holder.hud = hud
	root.add_child(holder)
	var p := DauVetMark.poster(holder, Vector3(14.3, 0.825, -1.69), 0.0)
	var t := DauVetMark.ti_vi(holder, Vector3(0.95, 0.85, -1.49), 0.0)
	_check(_anh(p, "giay"), "mặt poster có ảnh")
	_check(_anh(t, "man_hinh"), "màn ti vi có ảnh Bit")
	_check(_tris(p) == 132, "poster 132 tam giác (%d)" % _tris(p))
	_check(_tris(t) == 448, "ti vi 448 tam giác (%d)" % _tris(t))

	player.global_position = Vector3(5, 0, 5)
	for i in 5:
		await physics_frame
	_check(hud.shown.is_empty(), "Bơ ở xa poster thì không nhắc")
	player.global_position = Vector3(14.3, 0.1, -0.6)
	for i in 5:
		await physics_frame
	_check(hud.shown.size() == 1 and hud.shown[0] == DauVetMark.NHAC, "tới gần poster thì nhắc kênh anh Mark")
	player.global_position = Vector3(5, 0, 5)
	await physics_frame
	player.global_position = Vector3(14.3, 0.1, -0.6)
	for i in 5:
		await physics_frame
	_check(hud.shown.size() == 1, "chỉ nhắc một lần mỗi cảnh")
	var en: Dictionary = load("res://scripts/dich/en_choi.gd").EN
	_check(en.has(DauVetMark.NHAC), "câu nhắc có bản tiếng Anh")
	holder.queue_free()

	# Cảnh thật: chung cư có poster, bếp có ti vi
	for c in [["res://scenes/chung_cu.tscn", "poster_mark"], ["res://scenes/kitchen.tscn", "ti_vi_bit"]]:
		var s: Node = load(c[0]).instantiate()
		root.add_child(s)
		for i in 3:
			await process_frame
		_check(s.find_child(c[1], true, false) != null, "%s có %s" % [c[0].get_file(), c[1]])
		s.queue_free()
		await process_frame
	print("DAU VET MARK TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1
