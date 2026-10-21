extends SceneTree
## Thử chợ sáng Thứ Ba trong màn giao thật: gầm sạp, va người đi chợ, đổ thúng, xe chè chặn hẻm khối 3,
## xe máy chạy chậm qua chợ, và chợ tan ở đơn 4 (sạp gập, ba gác chở hàng về).
## Chạy: godot --headless --path . --script res://tools/cho_test.gd -- --cho
## In "CHO TEST OK" và thoát mã 0 nếu mọi tình huống đúng.

var main: Node3D
var market: Node
var traffic: Node
var player: CharacterBody3D
var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	market = main.get_node_or_null("ChoSang")
	traffic = main.get_node_or_null("GiaoThong")
	player = main.player
	_check(market != null, "có chợ khi chạy với --cho")
	if market == null:
		_finish()
		return
	player.global_position = Vector3(-30, 0.1, 0)  # đứng xa chợ và xa lò bánh
	player.velocity = Vector3.ZERO
	await _frames(5)
	_case_stall_gap()
	await _case_bump()
	await _case_spill()
	await _case_alley_cart()
	_case_bikes_slow()
	await _case_packing()
	_finish()


func _finish() -> void:
	print("CHO TEST OK" if fails == 0 else "CHO TEST FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _hits(center: Vector3, size: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var b := BoxShape3D.new()
	b.size = size
	q.shape = b
	q.transform = Transform3D(Basis(), center)
	q.collision_mask = Blocks.LAYER_PROP
	return not main.get_world_3d().direct_space_state.intersect_shape(q, 4).is_empty()


## Gầm sạp trống tới 0,5 m (Bơ chui cao 0,25 m), mặt sạp chặn ở 0,56 m.
func _case_stall_gap() -> void:
	var p: Vector3 = CityProps.MARKET_STALLS[2].pos
	_check(not _hits(p + Vector3(0, 0.22, 0), Vector3(0.5, 0.36, 0.5)), "gầm sạp chui được (0,04–0,40 m trống)")
	_check(_hits(p + Vector3(0, 0.56, 0), Vector3(0.5, 0.06, 0.5)), "mặt sạp có va chạm")


## Bơ chen vào người đi chợ: khựng lại và phát bumped("person").
func _case_bump() -> void:
	var kinds: Array[String] = []
	player.bumped.connect(func(k: String) -> void: kinds.append(k))
	var s = null
	for sh in market._shoppers:
		if sh.browse:
			s = sh
			break
	player.global_position = s.pos + Vector3(0.3, 0.05, 0)
	player.velocity = Vector3.ZERO
	await _frames(3)
	_check("person" in kinds, "va người đi chợ phát bumped(\"person\")")
	_check(market.bumps_total >= 1, "chợ đếm được lần va người")
	_check(player._stun > 0.0, "Bơ khựng lại sau khi va")
	player.global_position = Vector3(-30, 0.1, 0)
	await _frames(70)


## Chạy nhanh húc thúng thì thúng đổ; rón rén đi sát thì không.
func _case_spill() -> void:
	var spilled: Array = []
	market.basket_spilled.connect(func(p: Vector3) -> void: spilled.append(p))
	var bk: Dictionary = market._baskets[0]
	player.stance = "sneak"
	player.global_position = bk.pos + Vector3(0.5, 0.05, 0)
	player.velocity = Vector3(-1.5, 0, 0)
	market._check_baskets()
	_check(spilled.is_empty(), "rón rén sát thúng không làm đổ")
	player.stance = "walk"
	player.velocity = Vector3(-5.0, 0, 0)
	market._check_baskets()
	_check(spilled.size() == 1 and bk.spilled, "chạy húc thúng làm đổ thúng")
	_check(market.spills_total == 1, "chợ đếm được thúng đổ")
	player.global_position = Vector3(-30, 0.1, 0)
	player.velocity = Vector3.ZERO
	await _frames(10)


## Xe chè đẩy vào chắn kín miệng hẻm khối 3 rồi đẩy ra theo lịch.
func _case_alley_cart() -> void:
	_check(traffic.blocked_alleys.size() == 1, "giao thông có một hẻm bị chặn theo lịch")
	var saw_blocked := false
	var saw_open := false
	var full_block := false
	for i in 60 * 40:
		await physics_frame
		var a: Dictionary = traffic.blocked_alleys[0]
		if a.blocked:
			saw_blocked = true
			# Hai mép hẻm (z -16,6 và -14,4) đều bị thân xe che: Bơ không lách qua được
			full_block = _hits(Vector3(22.9, 0.5, -16.45), Vector3(0.2, 0.2, 0.3)) and _hits(Vector3(22.9, 0.5, -14.55), Vector3(0.2, 0.2, 0.3))
		elif saw_blocked:
			saw_open = true
			break
	_check(saw_blocked, "xe chè có lúc chặn hẻm khối 3")
	_check(full_block, "khi chặn thì kín cả bề ngang hẻm 2,4 m")
	_check(saw_open, "xe chè có lúc đẩy ra, hẻm thông")


## Xe máy trong vùng chợ không chạy quá tốc độ chợ.
func _case_bikes_slow() -> void:
	var inside := 0
	var fast := 0
	for b in traffic._bikes:
		if b.active and CityProps.MARKET_ZONE.has_point(Vector2(b.pos.x, b.pos.z)):
			inside += 1
			if b.speed > market.BIKE_SPEED + 0.3:
				fast += 1
	print("  (xe trong chợ: %d)" % inside)
	_check(fast == 0, "xe máy qua chợ chạy chậm")


## Sang đơn 4: chợ tan, sạp gập dần, ba gác ra giữa đường, người đi chợ về bớt.
func _case_packing() -> void:
	var started := [false]
	market.packing_started.connect(func() -> void: started[0] = true)
	main.order_index = 3
	await _frames(60 * 20)
	var folded := 0
	for st in market._stalls:
		if st.folded:
			folded += 1
	var left := 0
	for s in market._shoppers:
		if not s.gone:
			left += 1
	_check(started[0], "chợ bắt đầu dọn ở đơn 4")
	_check(folded == 9, "đơn 4 gập một nửa số sạp (%d/18)" % folded)
	_check(market._ba_gac != null, "ba gác chở hàng về nằm giữa đường")
	_check(left <= int(round(market.CROWD[3] * market._shoppers.size())), "người đi chợ về bớt (%d còn lại)" % left)
	var st0: Dictionary = market._stalls.filter(func(s: Dictionary) -> bool: return s.folded)[0]
	_check(_hits(st0.pos + Vector3(0, 0.3, -0.25 * (1 if st0.pos.z < 0 else -1)), Vector3(0.4, 0.3, 0.4)), "sạp đã gập thành đống hàng có va chạm")
	main.order_index = 4
	await _frames(60 * 15)
	folded = 0
	for st in market._stalls:
		if st.folded:
			folded += 1
	_check(folded == int(round(market.FOLDED[4] * 18)), "đơn 5 gần dọn xong (%d/18)" % folded)
