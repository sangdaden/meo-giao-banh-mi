extends SceneTree
## Logic ngày mưa (Thứ Tư, ThoiTiet.dang_mua) và xe nhường con vật:
## - người dân ngoài phố có mái che, hoặc mặc áo mưa (*_mua), hoặc đứng dưới bạt góc cờ;
## - góc cờ căng bạt, không treo lồng chim; chim ban công đem vào nhà; hàng ghế cà phê ngoài trời bỏ trống;
## - Bé Na không thả giỏ mà xuống hành lang tầng trệt (có che) nhận tận tay;
## - xe máy: người lái, người bán xe đẩy mặc áo mưa;
## - xe máy dừng trước con vật dưới lòng đường (ConVat.road_points), không chạy xuyên qua.
## Thứ Hai (nắng) giữ như cũ: thả giỏ, có chim chào mào, người lái không áo mưa.
## Chạy: godot --headless --path . -s tests/test_ngay_mua.gd   (in "NGAY MUA TEST OK")

var fails := 0


func _init() -> void:
	DoKho.force = -1
	_run.call_deferred()


func _load(day: String) -> Node:
	PlayMode.day = day
	change_scene_to_file("res://scenes/main.tscn")
	for i in 40:
		await physics_frame
	return current_scene


func _run() -> void:
	var main: Node = await _load("thu_tu")
	_check(ThoiTiet.dang_mua(), "Thứ Tư là ngày mưa")
	var space: PhysicsDirectSpaceState3D = (main as Node3D).get_world_3d().direct_space_state
	var chess: Node = main.find_child("GocCoTuong", true, false)
	var tarp: Node3D = chess.get_node_or_null("BatChe") if chess else null
	_check(tarp != null, "góc cờ căng bạt che lúc mưa")
	_check(get_nodes_in_group("con_vat").filter(func(n): return n is ChaoMao).is_empty(), "mưa không treo lồng chào mào ngoài trời")
	for n in get_nodes_in_group(Nguoi.GROUP):
		var p := n as Nguoi
		if p == null or not p.is_visible_in_tree() or p.global_position.y < -1.0:
			continue
		var at := p.global_position
		var roof := not space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 1.9, 0), at + Vector3(0, 20, 0))).is_empty()
		var coat := (p.model_id if p.model_id != "" else p.id).ends_with("_mua")
		var under_tarp := tarp != null and absf(at.x - tarp.global_position.x) < 1.14 and absf(at.z - tarp.global_position.z) < 1.33
		var runner := p.get_parent() is NguoiQuaDuong and p.id in ["qd_sinhvien", "qd_hocsinh_b"]  # chạy mưa (LICH "run")
		var rider := p.id == "khachxeom"  # khách xe ôm ngồi sau Chú Năm, chỉ hiện lúc chở
		_check(roof or coat or under_tarp or runner or rider, "%s ở %s không đứng mưa trần" % [p.id, at.snapped(Vector3.ONE * 0.1)])
	var dl: Node = main.deliveries
	var na: int = dl._kind.find("na_cua")
	_check(na >= 0 and dl._kind.find("basket") < 0, "Bé Na không thả giỏ lúc mưa (cách giao na_cua)")
	if na >= 0:
		var bena: Nguoi = dl._people.get(na)
		_check(bena != null and bena.global_position.y < 0.5, "Bé Na xuống tầng trệt")
		if bena:
			var top := bena.global_position + Vector3(0, 1.9, 0)
			_check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3(0, 10, 0))).is_empty(), "chỗ Bé Na đứng có sàn trên che")
	var traffic: Node = main.get_node("GiaoThong")
	_check(traffic._mm_riders.size() == traffic.RIDERS_MUA.size(), "người lái xe máy mặc áo mưa")
	for c in traffic._carts:
		_check(String(c.seller.id).ends_with("_mua"), "người bán xe đẩy mặc áo mưa (%s)" % c.seller.id)
	for b in get_nodes_in_group("khach_ca_phe"):
		_check((b as Node3D).global_position.z > 5.9, "khách cà phê chỉ ngồi hàng trong dưới mái hiên")
	await _yield_test(traffic)

	main = await _load("thu_hai")
	_check(not ThoiTiet.dang_mua(), "Thứ Hai trời nắng")
	_check(main.deliveries._kind.find("basket") >= 0, "Thứ Hai Bé Na vẫn thả giỏ")
	_check(not get_nodes_in_group("con_vat").filter(func(n): return n is ChaoMao).is_empty(), "Thứ Hai có chim chào mào")
	var chess2: Node = main.find_child("GocCoTuong", true, false)
	_check(chess2 != null and chess2.get_node_or_null("BatChe") == null, "Thứ Hai góc cờ không căng bạt")
	_check(main.get_node("GiaoThong")._mm_riders.size() == main.get_node("GiaoThong").RIDERS.size(), "Thứ Hai người lái như cũ")
	print("NGAY MUA TEST OK" if fails == 0 else "NGAY MUA TEST FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


## Đặt một "con vật" giả trước mũi một xe máy đang chạy: xe phải dừng trước nó, không chạy xuyên qua.
func _yield_test(traffic: Node) -> void:
	var bike = null
	for b in traffic._bikes:
		if b.active and not b.bus and absf(b.pos.x) < 50.0 and absf(b.pos.z) < 40.0:
			bike = b
			break
	_check(bike != null, "có xe máy đang chạy trong phố")
	if bike == null:
		return
	var dummy := ConVatGia.new()
	dummy.at = bike.pos + bike.dir * 6.0
	dummy.at.y = 0.0
	root.add_child(dummy)
	var closest := INF
	for i in 180:
		await physics_frame
		closest = minf(closest, (dummy.at - bike.pos).dot(bike.dir))
	_check(closest > bike.front, "xe dừng trước con vật (còn cách %.2f m, mũi xe %.2f m)" % [closest, bike.front])
	_check(bike.speed < 0.1, "xe đứng chờ con vật qua (tốc độ %.2f)" % bike.speed)
	dummy.queue_free()
	for i in 120:
		await physics_frame
	_check(bike.speed > 1.0 or bike.holding or not bike.active, "con vật đi rồi thì xe chạy tiếp (tốc độ %.2f)" % bike.speed)


class ConVatGia extends Node3D:
	var at := Vector3.ZERO

	func _ready() -> void:
		add_to_group("con_vat")

	func road_points() -> PackedVector3Array:
		return PackedVector3Array([at])


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok  ", what)
	else:
		fails += 1
		print("  SAI ", what)
