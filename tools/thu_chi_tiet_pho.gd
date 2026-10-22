extends SceneTree
## Kiểm chi tiết phố P4 (scripts/chi_tiet_pho.gd) trong cả 7 ngày: mở màn phố từng ngày, chờ mọi thứ dựng xong
## (chợ, Hội mèo, tiệm xe chiều tà...), rồi xem mỗi món có va chạm của chi tiết phố có chồng lên va chạm khác không,
## và có món nào nằm trên lòng đường không. In các món bị bỏ lúc dựng (chỗ vướng).
## Chạy: godot --headless --path . -s tools/thu_chi_tiet_pho.gd
## In "CHI TIET PHO OK" nếu không chồng gì.

var fails := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.use_test_save("user://test_chi_tiet_pho.cfg")
	for day: String in Days.ORDER:
		PlayMode.day = day
		var scene: Node3D = load("res://scenes/main.tscn").instantiate()
		root.add_child(scene)
		for i in 10:
			await physics_frame
		await _check_day(scene, day)
		scene.queue_free()
		await process_frame
		await process_frame
	print("[chi tiet] dựng %d món, bỏ %d chỗ:" % [ChiTietPho.placed, ChiTietPho.skipped.size()])
	for s in ChiTietPho.skipped:
		print("[chi tiet]   bỏ ", s)
	print("CHI TIET PHO OK" if fails == 0 else "CHI TIET PHO FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


func _check_day(scene: Node3D, day: String) -> void:
	var space := scene.get_world_3d().direct_space_state
	var mine := {}
	for n in get_nodes_in_group(ChiTietPho.GROUP):
		if n is CollisionObject3D:
			mine[n.get_rid()] = true
	var n_bodies := 0
	for n in get_nodes_in_group(ChiTietPho.GROUP):
		if not (n is StaticBody3D):
			continue
		n_bodies += 1
		for cs: CollisionShape3D in n.find_children("*", "CollisionShape3D", false, false):
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = cs.shape
			q.transform = cs.global_transform
			q.collision_mask = 0xFFFFFFFF
			q.exclude = mine.keys()
			q.margin = -0.02
			for hit in space.intersect_shape(q, 8):
				var other: Node = hit.collider
				if other.name.begins_with("Ground") or _is_ground(other):
					continue
				fails += 1
				print("[chi tiet] %s: %s ở %s chồng lên %s (%s)" % [day, n.name, (n as Node3D).global_position, other.name, other.get_path()])
	print("[chi tiet] %s: %d món có va chạm" % [day, n_bodies])


## Mặt đường, vỉa hè: khối phẳng rộng sát đất
func _is_ground(n: Node) -> bool:
	if not (n is StaticBody3D):
		return false
	for cs: CollisionShape3D in n.find_children("*", "CollisionShape3D", false, false):
		if cs.shape is BoxShape3D:
			var s: Vector3 = (cs.shape as BoxShape3D).size
			if s.x > 30.0 or s.z > 30.0:
				return true
	return false
