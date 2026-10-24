extends SceneTree
## Kiểm tra khu phố sau khi thay khối tạm bằng model nhà và đồ phố: các khoảng trống và mặt đứng
## mà lối chơi dựa vào vẫn đúng (gầm ba gác 0,32 m, gầm bàn cà phê, mái hiên 2,96 m, bờ rào 0,7 m,
## hẻm 42 rộng 3 m, chỗ nhận bánh và chỗ giao không bị đồ chắn).
## Chạy: godot --headless --path . -s tests/test_nha_pho.gd

var world: Node3D
var fails := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	City.build(world)
	Blocks.merge_static(world, 24.0)
	for i in 3:
		await physics_frame
	var space := world.get_world_3d().direct_space_state

	# Gầm ba gác: hộp 0,3 x 0,25 x 0,3 (Bơ đang chui) dưới thùng không chạm gì, hộp 0,6 cao (Chó Mực) thì chạm
	var carts := world.get_tree().get_nodes_in_group("ba_gac")
	_check(carts.size() == 4, "4 xe ba gác (hẻm 42 + 3 hẻm giữa khối), có %d" % carts.size())
	for c: Node3D in carts:
		var under := c.global_transform * Vector3(-0.3, 0.14, 0)
		_check(not _hits(space, Vector3(0.3, 0.25, 0.3), under), "Bơ chui lọt gầm ba gác ở %s" % under)
		_check(_hits(space, Vector3(0.3, 0.6, 0.3), under + Vector3(0, 0.17, 0)), "Chó Mực không chui lọt gầm ba gác ở %s" % under)
	var hem := CityProps.HEM42_X
	_check(is_equal_approx(hem.y - hem.x, 3.0), "hẻm 42 rộng 3 m")

	# Gầm bàn cà phê: chui được dưới mặt bàn (0,41 m)
	for t: Node3D in world.get_tree().get_nodes_in_group("ban_ca_phe"):
		_check(not _hits(space, Vector3(0.3, 0.25, 0.3), t.global_position - Vector3(0, 0.27, 0)), "chui lọt gầm bàn cà phê ở %s" % t.global_position)

	# Mái hiên: mặt trên 2,96 m, có nhóm "mai_hien"
	var awnings := world.get_tree().get_nodes_in_group("mai_hien")
	_check(awnings.size() > 30, "mái hiên nối liền các dãy nhà (%d tấm)" % awnings.size())
	for a: Node3D in awnings:
		var y := _ray_down(space, a.global_position + Vector3(0, 2.0, 0))
		if absf(y - 2.96) > 0.01:
			_check(false, "mái hiên ở %s cao %.2f m" % [a.global_position, y])
			break

	# Bờ rào hẻm 42 cao 0,7 m
	var fy := _ray_down(space, Vector3(hem.x - 0.15, 3.0, 12.0))
	_check(absf(fy - 0.7) < 0.01, "bờ rào hẻm 42 cao 0,7 m (đo %.2f)" % fy)

	# Chỗ nhận bánh, chỗ đứng giao các đơn: một con mèo (hộp 0,3 x 0,3 x 0,6) đứng được, không kẹt trong đồ
	for p in [City.BAKERY_POINT, City.BAKERY_POINT + Vector3(0, 0, 2.5), Vector3(-1, 0, -6), CityProps.CAFE_COUNTER - Vector3(0, 0.9, 0.7),
			Vector3(30.6, 0, 25.3), CityProps.BA_SAU_CHAIR + Vector3(0, 0, -0.9), CityProps.BE_NA_BIKE + Vector3(0, 0.9, 0), CityProps.SHOP_BACK_DOOR + Vector3(0, 0, 0.3)]:
		_check(not _hits(space, Vector3(0.3, 0.3, 0.6), p + Vector3(0, 0.25, 0)), "đứng được ở %s" % p)

	print("TEST NHA PHO %s" % ("OK" if fails == 0 else "FAIL (%d)" % fails))
	quit(0 if fails == 0 else 1)


func _hits(space: PhysicsDirectSpaceState3D, size: Vector3, pos: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	q.shape = bs
	q.transform = Transform3D(Basis(), pos)
	q.collision_mask = Blocks.LAYER_WORLD | Blocks.LAYER_PROP
	return not space.intersect_shape(q, 1).is_empty()


func _ray_down(space: PhysicsDirectSpaceState3D, from: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 10, 0), Blocks.LAYER_WORLD | Blocks.LAYER_PROP)
	var hit := space.intersect_ray(q)
	return hit.position.y if hit else -1.0


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  SAI: ", what)
