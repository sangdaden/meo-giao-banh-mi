extends SceneTree
## Con vật mới V1–V6 (scripts/con_vat_moi/, luồng "Con vật mới vào game"):
## - mỗi ngày đủ con theo ConVatMoi.LICH, Thứ Năm và Chủ Nhật ngoài phố không có node;
## - Thứ Ba: đi sát gà con thì nó theo Bơ, dẫn về bu thì nhảy vào, đủ 5 con được tiền boa một lần; thau cá té nước;
## - Thứ Tư: nước ngập thì vịt ra, Bơ đứng lên lưng con đầu là cưỡi vịt;
## - Thứ Bảy: Q gần bướm thì một con bay tới thăm Bơ; bể cá vàng quầy cà phê đáp Q;
## - chung cư: Bơ đứng yên trên mái nhà bên thì thạch sùng bò tới chỗ bám kế tiếp (bậc A);
## - bếp: Bơ đi lại gần thì chuột Tí vẫy chào;
## - mỗi con gọi ConVat.meet đúng id.
## Chạy: godot --headless --path . -s tests/test_con_vat_moi.gd → in "CON VAT MOI TEST OK"

var fails := 0


func _initialize() -> void:
	DoKho.force = -1
	GameState.use_test_save("user://test_con_vat_moi.cfg")
	GameState.set_global(ConVat.SAVE_KEY, [])
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  SAI  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _load(day: String, scene := "res://scenes/main.tscn") -> Node:
	PlayMode.day = day
	GameState.day = day
	change_scene_to_file(scene)
	await _frames(20)
	return current_scene


func _put(p: CharacterBody3D, at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO


func _run() -> void:
	for day in ConVatMoi.LICH:
		var main := await _load(day)
		var cv: ConVatMoi = main.find_child("ConVatMoi", true, false)
		_check(cv != null and cv.parts.size() == ConVatMoi.LICH[day].size(), "%s đủ con vật %s" % [day, ConVatMoi.LICH[day]])
		if cv == null:
			continue
		if cv.parts.has("ga"):
			await _ga(main, cv.parts.ga)
		if cv.parts.has("thau_ca"):
			cv.parts.thau_ca.on_called(cv.parts.thau_ca.global_position)
			_check(cv.parts.thau_ca.splashes == 1 and ConVat.met("ca"), "thau cá quẫy nước khi gọi Q, gặp bạn \"ca\"")
		if cv.parts.has("vit"):
			await _vit(main, cv.parts.vit)
		if cv.parts.has("buom"):
			await _buom(main, cv.parts.buom)
		if cv.parts.has("be_ca"):
			cv.parts.be_ca.on_called(cv.parts.be_ca.global_position)
			_check(cv.parts.be_ca._feed > 0.0, "%s: bể cá vàng đớp mồi khi gọi Q" % day)
	for day in ["thu_nam", "chu_nhat"]:
		var m := await _load(day)
		await _frames(2)
		_check(m.find_child("ConVatMoi", true, false) == null, "%s ngoài phố không có con vật mới" % day)
	await _thach_sung()
	await _chuot_ti()
	print("CON VAT MOI TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


func _ga(main: Node, ga: Node) -> void:
	var p: CharacterBody3D = main.player
	var wallet := Shop.wallet()
	for c in ga.chicks:
		_put(p, c.pos + Vector3(0.3, 0.1, 0))
		await _frames(4)
	var follow: int = ga.chicks.filter(func(c): return c.state != "lac").size()
	_check(follow == ga.chicks.size(), "đi sát từng gà con thì cả 5 con theo Bơ (%d)" % follow)
	_check(ConVat.met("ga"), "gặp bạn \"ga\"")
	# dẫn về: Bơ đi từ từ tới bu, hàng gà con theo sau
	var from: Vector3 = p.global_position
	for i in 60:
		_put(p, from.lerp(ga.BU + Vector3(0, 0.1, -0.2), i / 59.0))
		await _frames(2)
	await _frames(60)
	_check(ga.home_count == ga.chicks.size(), "dẫn tới bu thì đủ 5 gà con nhảy vào (%d)" % ga.home_count)
	_check(Shop.wallet() == wallet + ga.REWARD, "đủ 5 con được tiền boa %d" % ga.REWARD)


func _vit(main: Node, vit: Node) -> void:
	_check(not vit.visible, "chưa ngập thì chưa có vịt")
	var tt: Node = main.find_child("ThoiTiet", true, false)
	tt.ngap(0.2, 0.0)
	await _frames(3)
	_check(vit.visible, "nước ngập thì đàn vịt ra bơi")
	var p: CharacterBody3D = main.player
	for i in 40:
		var lead: Node3D = vit.ducks[0]
		if i < 3:
			_put(p, lead.global_position + Vector3(0, 0.45, 0))
		await _frames(1)
	_check(vit.rides >= 1, "Bơ đứng lên lưng vịt đầu đàn là cưỡi vịt")
	_check(ConVat.met("vit"), "gặp bạn \"vit\"")
	tt.ngap(0.0, 0.0)
	await _frames(3)
	_check(not vit.visible, "nước rút thì vịt về")


func _buom(main: Node, buom: Node) -> void:
	var p: CharacterBody3D = main.player
	var b = buom.bugs[0]
	_put(p, b.home + Vector3(0.5, 0.1, 0))
	await _frames(5)
	buom.on_called(p.global_position)
	_check(buom.bugs.any(func(x): return x.state == "tham"), "Q gần bướm thì một con bay tới thăm Bơ")
	await _frames(90)
	var t = buom.bugs.filter(func(x): return x.state == "tham")
	_check(not t.is_empty() and t[0].pos.distance_to(p.global_position) < 0.8, "con bọ tới sát Bơ")
	_check(ConVat.met("buom"), "gặp bạn \"buom\"")


func _thach_sung() -> void:
	var s := await _load("thu_nam", "res://scenes/chung_cu.tscn")
	var ts: ThachSung = s.find_child("ThachSung", true, false)
	_check(ts != null, "cảnh chung cư có thạch sùng")
	if ts == null:
		return
	var p: CharacterBody3D = s.player
	_put(p, Vector3(-3.0, 4.0, -2.6))  # mái nhà bên
	await _frames(int((ThachSung.HESITATE + 2.5) * 60))
	_check(ts.level() == 0, "Bơ đứng trên mái nhà bên (bậc %d)" % ts.level())
	_check(ts.hints >= 1, "đứng ngập ngừng thì thạch sùng chỉ đường")
	var a: Vector2 = ts.stops[1]
	_check(absf(ts._wall.x - (a.x + ThachSung.ABOVE)) < 0.2 and absf(ts._wall.y - a.y) < 0.2, "thạch sùng bám ngay trên bậc A (%s)" % ts._wall)
	_check(ConVat.met("thach_sung"), "gặp bạn \"thach_sung\"")


func _chuot_ti() -> void:
	var k := await _load("thu_hai", "res://scenes/kitchen.tscn")
	var ti: ChuotTi = k.find_child("ChuotTi", true, false)
	_check(ti != null, "bếp có chuột Tí")
	if ti == null:
		return
	var p: CharacterBody3D = k.player
	_put(p, ChuotTi.HOME + Vector3(0.6, 0.05, 0.2))
	await _frames(10)
	_check(ti.waves >= 1, "Bơ lại gần thì chuột Tí vẫy chào")
	_check(ConVat.met("chuot_ti"), "gặp bạn \"chuot_ti\"")
