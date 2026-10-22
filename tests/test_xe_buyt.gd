extends SceneTree
## Kiểm tra gói P3 trong game: trạm xe buýt có ghế, mái để Bơ nhảy lên; xe buýt tuyến 08 tấp vào trạm, mở cửa,
## chạy tiếp; Bơ đứng trước mũi thì xe dừng và bóp còi, không tông; Bơ đứng trên nóc thì xe chờ;
## người qua đường thật (Nguoi qd_*) ra phố theo lịch, không đứng trong nhà hay đồ phố, lên xuống xe buýt.
## Chạy: godot --headless --path . -s tests/test_xe_buyt.gd

var fails := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await physics_frame
	var player: CharacterBody3D = main.get("player")
	var tr: Node = main.get_node("GiaoThong")
	var space := player.get_world_3d().direct_space_state

	# Trạm: mặt ghế 0,45 m và mái 2,6 m có va chạm lớp đồ (Bơ đứng lên được)
	for probe in [[XeBuyt.at(Vector3(0.4, 1.5, -0.35)), 0.45, "ghế trạm"], [XeBuyt.at(Vector3(0, 4.0, 0.05)), 2.64, "mái trạm"]]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(probe[0], probe[0] - Vector3(0, 4, 0), Blocks.LAYER_PROP))
		_check(not hit.is_empty() and absf(hit.position.y - probe[1]) < 0.05, "%s cao %.2f m" % [probe[2], probe[1]])

	# Người khối cũ đã bỏ, người qua đường thật ra phố
	_check(not "_walkers" in tr, "không còn người khối đi tới đi lui")
	var nq: NguoiQuaDuong = tr.passers
	for i in 30:
		await physics_frame
	_check(nq.ready_grid and nq.count() > 0, "có người qua đường (%d)" % nq.count())
	_check(nq._doors.size() > 10 and nq._exits.size() >= 6, "có cửa nhà (%d) và đầu đường ra vành (%d)" % [nq._doors.size(), nq._exits.size()])

	# Xe buýt chạy tới trạm: cất Bơ khỏi đường cho xe chạy
	player.global_position = City.BAKERY_POINT + Vector3(0, 0.1, 0)
	var bus: XeBuyt = tr.bus
	_check(bus != null, "có xe buýt (không phải ngày chợ)")
	var b = bus.bike
	b.rest = 0.0
	var saw_doors := false
	var stop_pos := Vector3.ZERO
	var t := 0.0
	while t < 90.0 and bus.phase != "di":
		await physics_frame
		t += 1.0 / 60.0
		if bus.is_dwelling() and not saw_doors:
			saw_doors = true
			stop_pos = b.pos
	_check(saw_doors, "xe buýt dừng ở trạm và mở cửa")
	_check(absf(stop_pos.x - XeBuyt.STOP_FRONT_X) < 0.3 and stop_pos.z > 3.6, "đỗ sát vỉa hè trước trạm (mũi xe %s)" % stop_pos)
	_check(bus.phase == "di", "đón khách xong thì chạy tiếp")

	# Bơ đứng giữa làn trước mũi xe: xe dừng hẳn, bóp còi, không hất Bơ
	var honks := [0]
	tr.honked.connect(func(_p): honks[0] += 1)
	var hits := [0]
	tr.bike_hit_player.connect(func(p): if p.distance_to(b.pos) < 3.0: hits[0] += 1)
	for i in 3:
		await physics_frame
	var fwd: Vector3 = -b.xf.basis.z
	player.global_position = Vector3(b.pos.x, 0.1, 2.5) + Vector3(fwd.x, 0, 0) * 6.0
	player.velocity = Vector3.ZERO
	t = 0.0
	while t < 6.0:
		await physics_frame
		t += 1.0 / 60.0
		player.velocity = Vector3.ZERO
	var gap: float = (player.global_position - b.pos).dot(fwd)
	_check(b.speed < 0.05 and gap > 0.5, "xe buýt dừng trước Bơ (cách mũi %.2f m)" % gap)
	_check(honks[0] > 0, "xe buýt bóp còi")
	_check(hits[0] == 0, "xe buýt không tông Bơ")

	# Bơ đứng trên nóc: xe đứng chờ
	player.global_position = b.pos - fwd * 4.0 + Vector3(0, XeBuyt.HEIGHT + 0.3, 0)
	t = 0.0
	var moved := 0.0
	var s0: float = b.s
	while t < 3.0:
		await physics_frame
		t += 1.0 / 60.0
	moved = b.s - s0
	_check(moved < 0.05, "Bơ trên nóc thì xe đứng chờ (xe nhích %.2f m)" % moved)
	_check(bus._bubble_time > 0.0, "nhắc Bơ xuống xe")
	player.global_position = City.BAKERY_POINT + Vector3(0, 0.1, 0)

	# Người qua đường không đứng trong ô đặc (nhà, đồ phố) khi đang đi bộ trong vùng chơi
	var bad := 0
	for k in nq._people:
		if k.state == "walk" and nq._in_area(k.n.position) and nq._solid(k.n.position) and k.goal.get("kind", "") not in ["leave_door", "door"]:
			bad += 1
	_check(bad == 0, "không ai đi xuyên nhà (%d người kẹt)" % bad)

	if fails == 0:
		print("TEST XE BUYT OK")
	else:
		print("TEST XE BUYT: %d lỗi" % fails)
	quit(1 if fails else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  LỖI: ", what)
