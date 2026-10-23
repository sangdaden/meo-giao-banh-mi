extends SceneTree
## Chó Mực cả tuần (scripts/muc_tuan.gd, M1–M5): chả cá cho Mực ngủ say (Thứ Hai), Thứ Sáu đuổi một đoạn rồi
## đứng vẫy đuôi, khoảnh khắc Thứ Ba / Thứ Tư / Thứ Năm (tiền boa, muc_quen), gọi Q lúc chưa làm bạn và đã làm bạn,
## đánh hơi tìm tem, ngủ trưa cạnh Mực. Chạy cảnh main thật, Thong thả.
## Chạy: godot --headless --path . -s tests/test_muc_tuan.gd
## In "MUC TUAN TEST OK" và thoát mã 0 nếu mọi tình huống đúng.

var m: Node3D
var mt: MucTuan
var bo: CharacterBody3D
var dog: CharacterBody3D
var fails := 0


func _init() -> void:
	DoKho.force = -1
	PlayMode.mode = PlayMode.Mode.DELIVERY
	GameState.use_test_save("user://luu_game_test_muc_tuan.cfg")
	_run.call_deferred()


func _run() -> void:
	await _cha_ca()
	await _goi_chua_quen()
	await _ngu_trua()
	await _ban_goi_q()
	await _quen_thu_sau()
	for d in ["thu_ba", "thu_tu", "thu_nam"]:
		await _khoanh_khac(d)
	_check((GameState.get_global("muc_quen", []) as Array).size() == 3, "gặp Mực đủ 3 ngày: %s" % [GameState.get_global("muc_quen", [])])
	_check(int(GameState.get_global("vi_tien_boa", 0)) == 3 * MucTuan.TIP, "boa %dđ" % int(GameState.get_global("vi_tien_boa", 0)))
	await _load("thu_sau")
	_check(is_equal_approx(mt.chase_limit(), 4.0 - 3 * MucTuan.QUEN_STEP), "gặp 3 lần thì Thứ Sáu đuổi ngắn hơn (%.1f s)" % mt.chase_limit())
	_unload()
	await _load("chu_nhat")
	_check(m.get_node_or_null("MucTuan") == null, "Chủ Nhật không có MucTuan")
	_unload()
	print("MUC TUAN TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


func _load(day: String) -> void:
	PlayMode.day = day
	GameState.day = day  # chợ Thứ Ba đọc GameState.day
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await _frames(20)
	bo = m.player
	dog = m.dog
	mt = m.get_node_or_null("MucTuan")
	m.state = m.State.PLAY
	bo.can_move = true
	if m.hud.has_method("hide_day_card"):
		m.hud.hide_day_card()


func _unload() -> void:
	m.queue_free()
	m = null
	mt = null


## Thứ Hai đơn 5 (Mực canh hẻm): thả chả cá ở đầu hẻm, Mực tới ăn rồi ngủ say, hết giờ về ổ canh lại.
func _cha_ca() -> void:
	await _load("thu_hai")
	_check(mt != null, "Thứ Hai có node MucTuan")
	m.order_index = 4
	m._pick_up(m.orders[4])
	_check(dog.awake and mt._piece_ready, "nhận đơn có Mực canh thì có miếng chả cá")
	bo.global_position = MucTuan.CHA_CA_SPOT + Vector3(0, 0.1, -1.0)
	await _frames(5)
	_check(mt._prompt.visible, "tới đầu hẻm hiện chữ E thả chả cá")
	mt.drop_cha_ca()
	bo.global_position = Vector3(-25, 0.1, -5)  # đi chỗ khác cho Mực ăn
	var ok := await _wait(func(): return mt._ctl == "snack_eat", 6.0)
	_check(ok, "Mực đi vòng xe ba gác tới chỗ chả cá trong 6 s, không phải nhảy tới (%s, %s)" % [mt._ctl, dog.global_position])
	ok = await _wait(func(): return mt._ctl == "snack_sleep", 6.0)
	_check(ok, "Mực đi tới ăn chả cá rồi ngủ (%s)" % mt._ctl)
	_check(not dog.awake and mt._piece == null, "ngủ say: không canh hẻm, miếng chả cá đã ăn")
	dog.hear(dog.global_position, 10.0)
	await _frames(5)
	_check(dog.state == dog.State.SLEEP, "ngủ say thì tiếng động không đánh thức")
	mt._t = 999.0
	ok = await _wait(func(): return mt._ctl == "", 12.0)
	_check(ok and dog.awake, "hết giấc ngủ say: về ổ, canh hẻm lại (awake %s)" % dog.awake)
	_check(not mt._piece_ready, "mỗi đơn chỉ một miếng")
	_unload()


## Chưa làm bạn: kêu meo lúc Mực canh hẻm thì nó nghi ngờ; lúc không canh thì hé mắt rồi ngủ tiếp.
func _goi_chua_quen() -> void:
	await _load("thu_hai")
	dog.awake = true
	await _frames(3)
	mt.on_called(dog.global_position + Vector3(0, 0, -4))
	await _frames(2)
	_check(dog.state == dog.State.SUSPICIOUS, "kêu meo lúc Mực canh hẻm: nó nghi ngờ")
	dog.awake = false
	await _frames(3)
	mt.on_called(dog.global_position + Vector3(0, 0, -4))
	_check(mt._ctl == "peek", "không canh: Mực hé mắt")
	await _frames(100)
	_check(mt._ctl == "" and not dog.awake, "hé mắt xong ngủ tiếp")
	_unload()


## Đứng yên cạnh Mực đang ngủ 5 giây (không mang bánh) thì Bơ ngủ trưa; bấm phím là dậy.
func _ngu_trua() -> void:
	await _load("thu_hai")
	var cam0: float = bo.camera_rig.distance
	dog.awake = false
	bo.global_position = dog.global_position + Vector3(1.0, 0.1, 0)
	bo.velocity = Vector3.ZERO
	var ok := await _wait(func(): return mt._napping, MucTuan.NAP_AFTER + 2.0)
	_check(ok, "đứng yên cạnh Mực 5 s thì ngủ trưa")
	await _frames(120)
	_check(not bo.can_move and bo.camera_rig.distance > cam0 + 1.5, "lúc ngủ: Bơ nằm yên, camera lùi ra (%.1f m)" % bo.camera_rig.distance)
	var e := InputEventKey.new()
	e.physical_keycode = KEY_SPACE
	e.pressed = true
	mt._input(e)
	await _frames(60)
	_check(not mt._napping and bo.can_move, "bấm phím là dậy")
	_check(int(GameState.get_global("ngu_trua_muc", 0)) == 1, "đếm lần ngủ trưa")
	_unload()


## Đã làm bạn (Thứ Bảy): Q gọi Mực chạy tới đi theo; Q lần nữa thì đánh hơi dẫn tới tem Cô Ba.
func _ban_goi_q() -> void:
	GameState.set_day("muc_ban", true, "thu_bay")
	await _load("thu_hai")
	bo.global_position = dog.global_position + Vector3(6, 0.1, -6)
	mt.on_called(bo.global_position)
	_check(dog.get_node_or_null("MucBan") != null and mt._ctl == "follow", "đã làm bạn: Q thì Mực đi theo")
	var ok := await _wait(func(): return Vector2(dog.global_position.x - bo.global_position.x, dog.global_position.z - bo.global_position.z).length() < 3.0, 8.0)
	_check(ok, "Mực chạy tới cạnh Bơ")
	m.stamps.set_active(true)
	mt.on_called(bo.global_position)
	_check(mt._ctl == "sniff" and mt._sniff_target != null, "Q lần nữa: Mực đánh hơi tìm tem")
	# Bơ đi theo Mực tới tem (dời thẳng Bơ theo sau Mực)
	ok = false
	for i in 60 * 40:
		var to: Vector3 = dog.global_position - bo.global_position
		to.y = 0.0
		if to.length() > 1.5:
			bo.global_position += to.normalized() * 4.0 / 60.0
		await physics_frame
		if mt._sniff_found >= 0.0:
			ok = true
			break
	_check(ok, "Mực dẫn tới tem rồi sủa (Mực ở %s, tem ở %s)" % [dog.global_position, mt._sniff_target.global_position if mt._sniff_target else Vector3.ZERO])
	GameState.set_day("muc_ban", false, "thu_bay")
	_unload()


## Thứ Sáu: Mực đuổi tối đa chase_limit() giây rồi đứng sủa vẫy đuôi.
func _quen_thu_sau() -> void:
	await _load("thu_sau")
	var lim := mt.chase_limit()
	dog.awake = true
	dog.chase_speed = 0.8  # chậm cho khỏi đớp trúng trong bài thử
	bo.global_position = dog.home + Vector3(0, 0.1, 4.5)
	await _frames(2)
	dog.call("_set_state", dog.State.CHASE)
	await _frames(int(lim * 60) - 20)
	_check(dog.state == dog.State.CHASE, "Thứ Sáu vẫn đuổi một đoạn")
	await _frames(40)
	_check(dog.state == dog.State.BARK and mt._ctl == "wag", "đuổi %.1f s rồi đứng sủa vẫy đuôi" % lim)
	await _frames(200)
	_check(mt._ctl == "" and dog.awake, "vẫy đuôi xong vẫn canh hẻm")
	_unload()


## Khoảnh khắc mỗi ngày: Mực ở chỗ riêng; Bơ tới gần (Thứ Năm: đẩy chén nước) thì Mực đáp, boa lần đầu.
func _khoanh_khac(day: String) -> void:
	await _load(day)
	var spot: Vector3 = mt._moment.spot
	_check(Vector2(dog.global_position.x - spot.x, dog.global_position.z - spot.z).length() < 0.3, "%s: Mực ở chỗ khoảnh khắc %s" % [day, spot])
	if day == "thu_nam":
		bo.global_position = mt._bowl.global_position + Vector3(0.5, 0.1, 0)
		await _frames(5)
		_check(mt._prompt.visible, "thu_nam: tới chén nước hiện chữ E")
		mt.push_bowl()
	else:
		bo.global_position = dog.global_position + Vector3(0.8, 0.1, -0.8)
	var ok := await _wait(func(): return mt._moment_done, 8.0)
	_check(ok and day in (GameState.get_global("muc_quen", []) as Array), "%s: Mực đáp, ghi đã gặp" % day)
	_unload()


func _wait(cond: Callable, secs: float) -> bool:
	for i in int(secs * 60):
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  SAI ") + what)
	if not ok:
		fails += 1
