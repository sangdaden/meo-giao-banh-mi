extends SceneTree
## U2 · Bơ phản ứng theo ngày (scripts/bo_theo_ngay.gd):
## - mỗi ngày có node BoTheoNgay, đủ 7 động tác trong bo_dong_tac.json;
## - đứng yên đủ lâu ở chỗ hợp thì Bơ làm đúng động tác của ngày, bấm phím là ngắt ngay;
## - Thứ Hai đi lại thì không diễn; Thứ Sáu xa bàn thờ thì không hắt xì, gần thì một lần mỗi lượt vào vùng;
## - Thứ Tư dầm mưa xong vào chỗ khô thì giũ nước trước; Thứ Bảy bướm bay lại đầu Bơ.
## Chạy: godot --headless --path . -s tests/test_bo_theo_ngay.gd → in "BO THEO NGAY TEST OK"

var fails := 0
var m: Node
var bo: CharacterBody3D
var u2: BoTheoNgay


func _initialize() -> void:
	DoKho.force = -1
	GameState.use_test_save("user://test_bo_theo_ngay.cfg")
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  SAI  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _load(day: String) -> void:
	PlayMode.day = day
	GameState.day = day
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await _frames(20)
	bo = m.player
	m.state = m.State.PLAY
	bo.can_move = true
	if m.hud.has_method("hide_day_card"):
		m.hud.hide_day_card()
	u2 = m.find_child("BoTheoNgay", true, false)


func _unload() -> void:
	m.queue_free()
	m = null
	u2 = null
	await _frames(3)


func _put(p: Vector3) -> void:
	bo.global_position = p + Vector3(0, 0.15, 0)
	bo.velocity = Vector3.ZERO
	await _frames(20)


## Đứng yên tới khi Bơ diễn (tối đa `giay` giây); trả về tên clip đang chạy
func _cho(giay: float) -> String:
	for i in int(giay * 60.0):
		await physics_frame
		if u2.dang != "":
			return bo.clip
	return ""


func _bam_phim() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_E
	e.pressed = true
	u2._input(e)
	await _frames(2)


func _run() -> void:
	var data: Dictionary = load("res://scripts/player.gd").dong_tac().clips
	for c: String in BoTheoNgay.CLIP.values():
		_check(data.has(c), "có động tác %s trong bo_dong_tac.json" % c)

	# Thứ Hai: đứng yên 6 s là rửa mặt, bấm phím thì ngắt; đi lại thì không
	await _load("thu_hai")
	_check(u2 != null, "thu_hai có node BoTheoNgay")
	await _put(bo.global_position)
	var c := await _cho(4.0)
	_check(c == "", "đứng yên 4 s chưa diễn")
	c = await _cho(3.0)
	_check(c == "rua_mat", "đứng yên 6 s thì rửa mặt (%s)" % c)
	await _bam_phim()
	_check(u2.dang == "" and not bo._clip_on, "bấm phím là ngắt động tác")
	u2._t = 5.9
	Input.action_press("move_forward")
	await _frames(2)
	Input.action_release("move_forward")
	_check(u2._t < 0.1 and u2.dang == "", "đang đi thì đếm lại từ đầu")
	await _unload()

	# Thứ Ba: ở góc cờ
	await _load("thu_ba")
	await _put(CityProps.CHESS_CORNER + Vector3(0, 0, 2.2))
	c = await _cho(7.0)
	_check(c == "ngo_cho", "Thứ Ba ở góc cờ: ngó chợ (%s)" % c)
	await _unload()

	# Thứ Tư: tìm chỗ có mái che; dầm mưa trước thì giũ nước, rồi 3 s nữa giũ chân
	await _load("thu_tu")
	var kho := _tim(func(p: Vector3) -> bool: return u2._tia(p + Vector3(0, 0.8, 0), p + Vector3(0, 14, 0)))
	_check(kho != Vector3.INF, "Thứ Tư có chỗ mái che (%s)" % kho)
	if kho != Vector3.INF:
		u2._wet = true
		await _put(kho)
		c = await _cho(2.0)
		_check(c == "giu_nuoc", "ướt mưa vào chỗ khô: giũ nước (%s)" % c)
		await _frames(60)
		c = await _cho(4.0)
		_check(c == "giu_chan", "đứng yên 3 s chỗ khô: giũ chân (%s)" % c)
	await _unload()

	# Thứ Năm: dưới bóng râm thì nằm (lặp)
	await _load("thu_nam")
	var bong := _tim(func(p: Vector3) -> bool: return u2._bong_ram(p))
	_check(bong != Vector3.INF, "Thứ Năm có chỗ bóng râm (%s)" % bong)
	if bong != Vector3.INF:
		await _put(bong)
		c = await _cho(6.0)
		_check(c == "nam_bong_mat", "đứng yên 5 s dưới bóng: nằm bóng mát (%s)" % c)
		await _frames(240)
		_check(bo.clip == "nam_bong_mat" and bo._clip_on, "nằm bóng mát lặp tới khi bấm phím")
		await _bam_phim()
		_check(not bo._clip_on, "bấm phím là dậy")
	await _unload()

	# Thứ Sáu: xa bàn thờ không hắt xì, gần thì hắt xì một lần
	await _load("thu_sau")
	await _put(ThuSau.ALTAR_POS + Vector3(-0.6, 0, -3.6))
	c = await _cho(4.0)
	_check(c == "", "xa bàn thờ không hắt xì")
	await _put(ThuSau.ALTAR_POS + Vector3(-0.6, 0, -1.2))
	c = await _cho(4.0)
	_check(c == "hat_xi", "gần bàn thờ 3 s: hắt xì (%s)" % c)
	await _frames(170)
	c = await _cho(5.0)
	_check(c == "", "còn trong vùng thì không hắt xì lần nữa")
	await _unload()

	# Thứ Bảy: gần bướm, con bướm bay lại đầu Bơ
	await _load("thu_bay")
	var buom: Array = u2._ds_buom()
	_check(not buom.is_empty(), "Thứ Bảy có bướm")
	if not buom.is_empty():
		await _put(Vector3(buom[0].home.x + 1.0, 0, buom[0].home.z))
		c = await _cho(7.0)
		_check(c == "von_buom", "gần bướm 6 s: vờn bướm (%s)" % c)
		_check(buom.any(func(b) -> bool: return b.state == "tham"), "con bướm bay lại đầu Bơ")
	await _unload()

	# Chủ Nhật: sân Hội mèo
	await _load("chu_nhat")
	_check(u2 != null, "chu_nhat có node BoTheoNgay")
	if u2:
		await _put(Vector3(-37.0, 0, 14.0))
		c = await _cho(7.0)
		_check(c == "chai_long", "sân Hội mèo: chải lông (%s)" % c)
	await _unload()

	print("BO THEO NGAY TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


## Tìm một chỗ trên vỉa hè hai bên đường lớn thỏa điều kiện (mặt đất có va chạm)
func _tim(dk: Callable) -> Vector3:
	var space: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	for z in [-5.6, 5.6, -6.2, 6.2, -4.0, 4.0]:
		for xi in range(-40, 40):
			var p := Vector3(xi * 1.0 + 0.5, 0, z)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN))
			if hit.is_empty() or hit.position.y > 0.4:
				continue
			p.y = hit.position.y
			# chỗ trống đủ đứng (không trong tường, cột)
			var q := PhysicsShapeQueryParameters3D.new()
			var s := SphereShape3D.new()
			s.radius = 0.3
			q.shape = s
			q.transform = Transform3D(Basis(), p + Vector3(0, 0.4, 0))
			q.exclude = [bo.get_rid()]
			if not space.intersect_shape(q, 1).is_empty():
				continue
			if dk.call(p):
				return p
	return Vector3.INF
