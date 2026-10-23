extends SceneTree
## Cơ chế chung con vật (T1 + T2, scripts/con_vat.gd):
## - ConVat.meet/met/count lưu vào hồ sơ, gọi lại không đếm hai lần, đủ hết thì có quà ConVat.QUA trong tủ đồ;
## - cảnh phố Thứ Hai có phím Q ("goi"), bấm Q thì Bơ ngồi kêu meo, mèo gần đáp và vào "Bạn bốn chân", mèo xa không;
## - bảng "Cách chơi" ngày nào cũng có đúng một dòng Q;
## - trang "Bạn bốn chân" (BanBonChan) có đủ ô, ghi đúng số đã gặp.
## Chạy: godot --headless --path . -s tests/test_con_vat.gd

var fails := 0


func _init() -> void:
	GameState.use_test_save("user://luu_game_test_con_vat.cfg")
	_run.call_deferred()


func _run() -> void:
	GameState.set_global(ConVat.SAVE_KEY, [])
	_check_meet()
	_check_help()
	await _check_q()
	await _check_page()
	if fails == 0:
		print("CON VAT TEST OK")
	quit(0 if fails == 0 else 1)


func _check_meet() -> void:
	GameState.set_global(ConVat.SAVE_KEY, [])
	_check(ConVat.count() == (1 if SoHangXom.muc_friend() else 0), "hồ sơ mới: chưa gặp ai")
	_check(ConVat.meet("bo_cau"), "gặp bồ câu lần đầu")
	_check(not ConVat.meet("bo_cau"), "gặp lại bồ câu không tính thêm")
	_check(ConVat.met("bo_cau") and ConVat.count() >= 1, "đã ghi bồ câu")
	_check(not ConVat.full(), "chưa đủ bạn")
	for id: String in ConVat.ALL:
		ConVat.meet(id)
	_check(ConVat.full() and ConVat.count() == ConVat.ALL.size(), "gặp đủ %d bạn" % ConVat.ALL.size())
	_check(ConVat.QUA in Shop.bought(), "đủ bạn thì có quà %s" % ConVat.QUA)
	GameState.set_global(ConVat.SAVE_KEY, [])


func _check_help() -> void:
	for id: String in Days.ORDER:
		var rows := ChuHuongDan.bang(Days.get_day(id))
		var q := rows.filter(func(r: Array) -> bool: return r[0] == "Q").size()
		_check(q == 1, "%s: bảng Cách chơi có đúng một dòng Q (%d)" % [id, q])


func _check_q() -> void:
	PlayMode.day = "thu_hai"
	PlayMode.mode = PlayMode.Mode.DELIVERY
	var m: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await _frames(40)
	_check(InputMap.has_action("goi"), "Thứ Hai: có phím Q (goi)")
	_check(m.get_node_or_null("ConVat") != null, "Thứ Hai: có ConVat")
	m.state = m.State.PLAY
	var bo: CharacterBody3D = m.player
	var near := MeoNpc.from_cast("mit")
	m.add_child(near)
	near.global_position = bo.global_position + Vector3(2.0, 0, 0)
	var far := MeoNpc.from_cast("sua")
	m.add_child(far)
	far.global_position = bo.global_position + Vector3(30.0, 0, 0)
	await _frames(20)
	var heard := [0]
	bo.called.connect(func(_p): heard[0] += 1)
	Input.action_press("goi")
	await process_frame
	await physics_frame
	await physics_frame
	Input.action_release("goi")
	await _frames(5)
	_check(heard[0] == 1, "bấm Q: Bơ kêu meo một lần (%d)" % heard[0])
	_check(ConVat.met("mit"), "mèo Mít đứng gần đáp lại, vào Bạn bốn chân")
	_check(near._bubble != null and near._bubble.visible, "Mít kêu đáp (bong bóng chữ)")
	_check(not ConVat.met("sua"), "mèo Sữa ở xa 30 m không nghe")
	far.dap_q = false
	far.global_position = near.global_position
	_check(ConVat.call_near(self, bo.global_position) >= 1 and not ConVat.met("sua"), "dap_q = false thì mèo không đáp")
	m.queue_free()
	await _frames(5)


func _check_page() -> void:
	var page := BanBonChan.new()
	root.add_child(page)
	await process_frame
	_check(page._grid.get_child_count() == ConVat.ALL.size(), "trang Bạn bốn chân đủ %d ô" % ConVat.ALL.size())
	_check(page._title.text.contains("%d/%d" % [ConVat.count(), ConVat.ALL.size()]), "trang ghi số đã gặp: " + page._title.text)
	page.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  LỖI  ") + what)
	if not ok:
		fails += 1
