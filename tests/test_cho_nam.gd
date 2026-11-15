extends SceneTree
## Chỗ nằm ưa thích (U1, scripts/cho_nam.gd) và chụp ảnh mọi ngày (U3, scripts/chup_anh.gd):
## - ngày nào trong tuần cũng có 1–2 chỗ nằm, id không trùng, chỗ trên phố nằm trong khối nhà (không trên lòng đường);
## - Thứ Hai có vệt nắng; Bơ đứng yên trong vệt thì cuộn tròn nằm, đủ giây thì chỗ đó vào sổ, đi ra thì dậy;
## - đứng ngoài vệt không ghi gì; trang "Chỗ nằm ưa thích" (ChoNamTrang) đếm đúng;
## - Thứ Hai có máy ảnh phím P: mở máy thì đồng hồ đơn đứng lại, đóng thì chạy tiếp;
## - ảnh tự chụp lên bảng tuần thì ảnh tự động của ngày đó không đè lên;
## - bảng "Cách chơi" ngày nào cũng có đúng một dòng P; câu mới có bản tiếng Anh.
## Chạy: godot --headless --path . -s tests/test_cho_nam.gd

var fails := 0


func _init() -> void:
	GameState.use_test_save("user://luu_game_test_cho_nam.cfg")
	_run.call_deferred()


func _run() -> void:
	GameState.set_global(ChoNam.SAVE_KEY, [])
	GameState.set_global(AnhTuan.SAVE_KEY, [])
	_check_list()
	_check_help()
	_check_en()
	_check_anh_tuan()
	await _check_day()
	if fails == 0:
		print("CHO NAM TEST OK")
	quit(0 if fails == 0 else 1)


func _check_list() -> void:
	var ids := {}
	for s in ChoNam.LIST:
		_check(not ids.has(s.id), "id %s không trùng" % s.id)
		ids[s.id] = true
		_check(s.day in Days.ORDER, "%s thuộc một ngày trong tuần" % s.id)
		if s.get("san", false):
			continue
		var inb := false
		for r: Rect2 in City.BLOCKS:
			inb = inb or r.has_point(Vector2(s.x, s.z))
		_check(inb, "%s nằm trong khối nhà, không trên lòng đường" % s.id)
	for day: String in Days.ORDER:
		var n := ChoNam.day_spots(day).size()
		_check(n >= 1 and n <= 2, "%s có 1–2 chỗ nằm (%d)" % [day, n])


func _check_help() -> void:
	for id: String in Days.ORDER:
		var rows := ChuHuongDan.bang(Days.get_day(id))
		var p := rows.filter(func(r: Array) -> bool: return r[0] == "P").size()
		_check(p == 1, "%s: bảng Cách chơi có đúng một dòng P (%d)" % [id, p])


func _check_en() -> void:
	var en: Dictionary = load("res://scripts/dich/en_choi.gd").EN
	for s in ChoNam.LIST:
		_check(en.has(s.name), "tên chỗ \"%s\" có bản tiếng Anh" % s.name)
	for k in ["Chỗ nằm ưa thích mới: %s (%d/%d)", "Đã ghi vào Sổ hàng xóm", "Chỗ nằm ưa thích · %d/%d",
			"Ảnh chụp sau cùng lên bảng Tuần của Bơ", "đồng hồ đang dừng", "chụp ảnh · đồng hồ dừng lúc chụp",
			ChoNam._sleep_text("nang"), ChoNam._sleep_text("kho"), ChoNam._sleep_text("den")]:
		_check(en.has(k), "câu \"%s\" có bản tiếng Anh" % k)


func _check_anh_tuan() -> void:
	_check(not AnhTuan.tu_chup("thu_ba"), "chưa tự chụp Thứ Ba")
	var img := Image.create(320, 240, false, Image.FORMAT_RGB8)
	img.fill(Color(0.9, 0.6, 0.3))
	AnhTuan.keep_tu_chup("thu_ba", img)
	_check(AnhTuan.tu_chup("thu_ba"), "tự chụp Thứ Ba thì ghi vào %s" % AnhTuan.SAVE_KEY)
	_check(AnhTuan.image("thu_ba") != null and AnhTuan.image("thu_ba").get_size() == AnhTuan.SIZE, "ảnh tự chụp lên bảng tuần, đúng cỡ")
	GameState.set_global(AnhTuan.SAVE_KEY, [])


func _check_day() -> void:
	PlayMode.day = "thu_hai"
	PlayMode.mode = PlayMode.Mode.DELIVERY
	var m: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await _frames(40)
	var cn: ChoNam = m.get_node_or_null("ChoNam")
	_check(cn != null and cn.spots.size() == 2, "Thứ Hai có 2 vệt nắng")
	var cam: ChupAnh = m.get_node_or_null("ChupAnh")
	_check(cam != null and InputMap.has_action("chup_anh"), "Thứ Hai có máy ảnh phím P")
	if cn == null or cam == null:
		return
	m.state = m.State.PLAY
	var bo: CharacterBody3D = m.player
	var spot: Vector3 = cn.spots[0].pos
	# ngoài vệt: không ghi
	bo.global_position = spot + Vector3(3.0, 0.2, 0)
	bo.velocity = Vector3.ZERO
	await _frames(int(60 * 5))
	_check(ChoNam.count() == 0, "đứng ngoài vệt nắng thì không ghi")
	bo.global_position = spot + Vector3(0, 0.2, 0)
	bo.velocity = Vector3.ZERO
	await _frames(int(60 * 2))
	_check(bo.clip == "ngu_cuon", "đứng yên trong vệt thì Bơ cuộn tròn nằm (%s)" % bo.clip)
	await _frames(int(60 * (float(DoKho.v("cho_nam_giay", 6.0)) + 0.5)))
	var id := str(cn.spots[0].data.id)
	_check(ChoNam.found(id) and ChoNam.count() == 1, "nằm đủ giây thì %s vào sổ" % id)
	var page := ChoNamTrang.new()
	root.add_child(page)
	await process_frame
	_check(page._title.text == "Chỗ nằm ưa thích · 1/%d" % ChoNam.LIST.size(), "trang sổ đếm đúng (%s)" % page._title.text)
	page.queue_free()
	bo.global_position = spot + Vector3(4.0, 0.2, 0)
	await _frames(10)
	_check(bo.clip != "ngu_cuon" or not bo.get("_clip_on"), "đi khỏi vệt thì Bơ dậy")
	# đồng hồ dừng khi chụp ảnh: cầm bánh (đồng hồ đang chạy) rồi mở máy
	bo.global_position = m.bakery_zone.global_position + Vector3(0, 0.3, 0)
	await _frames(20)
	_check(bo.carrying, "đã nhận bánh ở lò")
	await _frames(30)
	var t0: float = m.time_left
	await _frames(30)
	_check(m.time_left < t0, "không chụp thì đồng hồ chạy")
	cam.open()
	_check(cam.active and ChupAnh.dang_chup, "mở máy ảnh được")
	var t1: float = m.time_left
	await _frames(90)
	_check(is_equal_approx(m.time_left, t1), "đang chụp thì đồng hồ dừng (%.2f → %.2f)" % [t1, m.time_left])
	cam.close()
	_check(not ChupAnh.dang_chup, "đóng máy ảnh")
	await _frames(30)
	_check(m.time_left < t1, "đóng máy thì đồng hồ chạy tiếp")
	m.queue_free()
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1
