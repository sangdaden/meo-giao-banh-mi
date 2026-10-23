extends SceneTree
## Mèo hàng xóm trong tuần (scripts/meo_hang_xom.gd, gói N1–N4):
## - mỗi ngày đủ mèo theo LICH, đứng trên mặt gì đó (đất, mái hiên, yên xe), Chủ Nhật thì node tự gỡ;
## - Q từ xa chỉ đáp, Q sát thì chào kiểu mèo (lần đầu, lần sau);
## - Thứ Tư: mang bánh đơn 2 tới gần Bột thì được rủ đua, Q nhận, Bơ tới cửa sau tạp hóa trước thì thắng;
## - Thứ Hai: mang bánh đứng yên quá 20 s (Thong thả) thì mèo ra dẫn đường, chạy về phía đích, Bơ tới gần thì mèo về.
## Chạy: godot --headless --path . -s tests/test_meo_hang_xom.gd → in "MEO HANG XOM TEST OK"

var fails := 0


func _initialize() -> void:
	DoKho.force = -1
	GameState.use_test_save("user://test_meo_hang_xom.cfg")
	GameSettings.set_value("meo_chi_duong", true)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  SAI  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _load(day: String) -> Node:
	PlayMode.day = day
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(20)
	return current_scene


func _run() -> void:
	for day in MeoHangXom.LICH:
		var main := await _load(day)
		var mhx: MeoHangXom = main.find_child("MeoHangXom", true, false)
		_check(mhx != null, "%s có node mèo hàng xóm" % day)
		if mhx == null:
			continue
		_check(mhx.cats.size() == MeoHangXom.LICH[day].size(), "%s đủ %d mèo" % [day, MeoHangXom.LICH[day].size()])
		var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
		for id in mhx.cats:
			var m: MeoNpc = mhx.cats[id]
			var p := m.global_position
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.3, p + Vector3.DOWN * 0.6))
			_check(not hit.is_empty(), "%s: %s ngồi trên mặt gì đó ở %s" % [day, id, p])
		await _greet(main, mhx)
		if day == "thu_tu":
			await _race(main, mhx)
		if day == "thu_hai":
			await _guide(main, mhx)
	var cn := await _load("chu_nhat")
	await _frames(2)
	_check(cn.find_child("MeoHangXom", true, false) == null, "Chủ Nhật không có node mèo hàng xóm (đã có Hội mèo)")
	print("MEO HANG XOM TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


func _greet(main: Node, mhx: MeoHangXom) -> void:
	var id: String = mhx.cats.keys()[0]
	var m: MeoNpc = mhx.cats[id]
	var p: CharacterBody3D = main.player
	var said := ConVat.call_near(self, m.global_position + Vector3(5, 0, 0))
	_check(said >= 1 and ConVat.met(id), "%s: Q qua ConVat tới được mèo, đã gặp" % id)
	_check(not mhx.greeted.has(id), "%s: gọi từ xa chỉ đáp, chưa chào" % id)
	await _frames(70)
	p.global_position = m.global_position + Vector3(0.8, 0.05, 0)
	mhx._on_q(m, p.global_position)
	_check(mhx.greeted.get(id, 0) == 1, "%s: đứng sát bấm Q thì chạm mũi" % id)
	await _frames(170)
	mhx._on_q(m, p.global_position)
	_check(mhx.greeted.get(id, 0) == 2, "%s: lần sau cụng đầu" % id)
	await _frames(170)
	p.global_position = City.BAKERY_POINT + Vector3(0, 0.1, 2.5)
	await _frames(5)


func _race(main: Node, mhx: MeoHangXom) -> void:
	var bot: MeoNpc = mhx.cats.get("bot")
	_check(mhx._race_route.size() > 3, "Thứ Tư: Bột có đường đua sân thượng (%d điểm)" % mhx._race_route.size())
	if bot == null or mhx._race_route.is_empty():
		return
	var p: CharacterBody3D = main.player
	main.order_index = MeoHangXom.RACE_ORDER
	p.carrying = true
	p.global_position = bot.global_position + Vector3(-1.5, 0.1, 0)
	await _frames(10)
	_check(mhx.race == "moi", "mang bánh đơn 2 lại gần thì Bột rủ đua (race = %s)" % mhx.race)
	mhx._on_q(bot, p.global_position)
	await _frames(120)
	_check(mhx.race == "chay" and bot.moving, "bấm Q thì đếm ngược rồi Bột chạy")
	var end: Vector3 = mhx._race_route[-1]
	p.global_position = end + Vector3(0, 0.2, 0)
	await _frames(5)
	_check(mhx.race == "xong" and mhx.race_won, "Bơ tới cửa sau tạp hóa trước thì thắng")
	p.carrying = false


func _guide(main: Node, mhx: MeoHangXom) -> void:
	_check(mhx.guide != null and not mhx.guiding, "Thứ Hai có mèo chỉ đường, đang ẩn")
	if mhx.guide == null:
		return
	var p: CharacterBody3D = main.player
	main.order_index = 0
	p.carrying = true
	p.global_position = City.BAKERY_POINT + Vector3(0, 0.1, 2.5)
	p.velocity = Vector3.ZERO
	var goal: Vector3 = main._current_goal()
	var left0 := MeoHangXom.path_left(p.global_position, goal)
	await _frames(60 * 23)
	_check(mhx.guiding and mhx.guide.visible, "đứng 23 s không gần đích hơn thì mèo ra dẫn đường")
	await _frames(60 * 2)
	var left1 := MeoHangXom.path_left(mhx.guide.global_position, goal)
	_check(left1 < left0 - 2.0, "mèo chạy về phía đích (còn %.1f m, Bơ %.1f m)" % [left1, left0])
	p.global_position = goal + Vector3(0, 0.2, 3.0)
	await _frames(60 * 4)
	_check(not mhx.guiding and not mhx.guide.visible, "Bơ tới gần đích thì mèo chào rồi về")
	GameSettings.set_value("meo_chi_duong", false)
	mhx.lost_t = 0.0
	p.global_position = City.BAKERY_POINT + Vector3(0, 0.1, 2.5)
	mhx._cool = 0.0
	await _frames(60 * 23)
	_check(not mhx.guiding, "tắt \"Mèo chỉ đường\" trong Cài đặt thì không ra")
	GameSettings.set_value("meo_chi_duong", true)
	p.carrying = false
