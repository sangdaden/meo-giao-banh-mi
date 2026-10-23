extends SceneTree
## Bồ câu và chim (K1, K2) trên phố thật:
## - K1 rắc vụn bánh: Bơ ngồi gọi (on_called) gần đàn đang đậu thì cả đàn sà xuống quanh chân Bơ mổ, đứng sát
##   cũng không bay; ăn xong về chỗ cũ, quen hơi Bơ một lúc; gọi xa quá hay khác tầng thì không có gì.
## - K2 bồ câu non: tìm thấy thì theo Bơ, dẫn tới dưới chuồng mái khối 2 thì bay lên chuồng, ghi lưu, được tiền boa.
## Chạy: godot --headless --path . -s tests/test_bo_cau.gd

const PlayerScript := preload("res://scripts/player.gd")
const MainScript := preload("res://scripts/main.gd")

var world: Node3D
var bo: CharacterBody3D
var fails := 0


func _init() -> void:
	MainScript._setup_input()
	DoKho.force = -1
	GameState.save_path = "user://test_bo_cau.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	_run.call_deferred()


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	City.build(world)
	bo = PlayerScript.new()
	world.add_child(bo)
	await physics_frame
	await _feed()
	await _baby()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	print("BO CAU TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


func _feed() -> void:
	var flock := BoCau.new()
	flock.player = bo
	world.add_child(flock)
	var center := Vector3(-34.0, 0.0, 17.5)  # chỗ đậu Thứ Bảy (công viên)
	flock.perch_at(center)
	_check(flock.is_in_group("con_vat") and flock.has_method("on_called"), "bồ câu theo hợp đồng ConVat (nhóm con_vat, on_called)")
	_place(center + Vector3(12.0, 0, 0))
	await _frames(5)
	flock.on_called(bo.global_position)
	_check(flock.state == "perch" and flock.feeds == 0, "gọi cách đàn 12 m thì đàn không xuống")
	_place(center + Vector3(0, 3.0, 0))
	flock.on_called(center + Vector3(0, 3.0, 0))
	_check(flock.feeds == 0, "gọi ở tầng khác (cao 3 m) thì đàn không xuống")
	var at := center + Vector3(5.5, 0, 0)
	_place(at)
	await _frames(5)
	var scatters := flock.scatters
	flock.on_called(at)
	_check(flock.state == "feed_go" and flock.feeds == 1, "gọi cách đàn 5,5 m thì rắc vụn (Thong thả 7 m)")
	_check(flock.get_node_or_null("VunBanh") != null, "có vụn bánh rơi quanh chân")
	await _seconds(BoCau.FEED_FLY + 0.3)
	_check(flock.state == "feed", "đàn đã xuống ăn")
	var far := 0.0
	for b in flock._birds:
		far = maxf(far, Vector2(b.pos.x - at.x, b.pos.z - at.z).length())
	_check(far < 2.0, "cả đàn mổ quanh chân Bơ (xa nhất %.2f m)" % far)
	_place(flock._birds[0].pos + Vector3(0.2, 0, 0))  # đứng sát một con
	await _seconds(1.0)
	_check(flock.scatters == scatters, "đang ăn thì đứng sát cũng không bay")
	await _seconds(float(DoKho.v("rac_vun_giay", 6.0)) + BoCau.LAND_TIME)
	_check(flock.state == "perch" and flock.get_node_or_null("VunBanh") == null, "ăn xong về chỗ đậu, dọn vụn")
	var home: Vector3 = flock._birds[0].home
	_check(flock._birds[0].pos.distance_to(home) < 0.6, "về đúng chỗ đậu cũ")
	_place(home + Vector3(0.3, 0, 0))
	await _seconds(1.0)
	_check(flock.scatters == scatters, "vừa ăn xong: quen hơi Bơ, đi sát không bay")
	flock._calm = 0.0
	_place(home + Vector3(0.6, 0, 0.2))
	await _seconds(0.5)
	_check(flock.scatters == scatters + 1, "hết quen hơi thì đi sát lại làm đàn bay như cũ")
	flock.on_called(home)
	_check(flock.feeds == 1, "đang bay tán loạn thì gọi không có gì")
	flock.queue_free()


func _baby() -> void:
	var wallet := Shop.wallet()
	var non := BoCauNon.new()
	non.player = bo
	non.city_root = world
	world.add_child(non)
	await _frames(2)
	_check(non.coop.is_finite() and non.coop.y > 4.0 and non.coop.x > -14.0 and non.coop.x < 12.0,
		"chuồng trên mái khối 2 (%s)" % non.coop)
	_check(non.state == "lost", "bồ câu non đang lạc")
	_place(BoCauNon.LOST_AT + Vector3(3.0, 0, 0))
	await _seconds(0.5)
	_check(non._hint.visible and non.state == "lost", "tới gần nghe chíp chíp, chưa theo")
	_place(BoCauNon.LOST_AT + Vector3(0.6, 0, 0))
	await _seconds(0.3)
	_check(non.state == "follow", "tới sát thì nó theo Bơ")
	# Dắt qua đường từng bước 1,5 m: chim luôn theo kịp
	var goal := non.below_coop()
	var lag := 0.0
	for i in 40:
		var p := bo.global_position
		var d := Vector3(goal.x - p.x, 0, goal.z - p.z)
		if d.length() < 1.0:
			break
		_place(p + d.normalized() * minf(1.5, d.length()))
		await _seconds(0.35)
		if non.state == "follow":
			lag = maxf(lag, non._pos.distance_to(bo.global_position))
	_check(lag < 3.0, "đi theo sát (xa nhất %.2f m)" % lag)
	await _seconds(0.5)
	_check(non.state == "fly_home", "tới dưới chuồng thì bay lên (đang %s)" % non.state)
	await _seconds(BoCauNon.FLY_UP + 0.3)
	_check(non.is_home() and non._pos.distance_to(non.ledge) < 0.5 and non.ledge.y > non.coop.y, "đậu trên gờ tường trước chuồng")
	_check(bool(GameState.get_day(BoCauNon.SAVE_KEY, false, BoCauNon.DAY)), "đã ghi lưu")
	_check(Shop.wallet() == wallet + BoCauNon.REWARD, "được tiền boa một lần")
	non.queue_free()
	# Vào lại Thứ Bảy: chim đậu sẵn ở chuồng
	var again := BoCauNon.new()
	again.player = bo
	again.city_root = world
	world.add_child(again)
	await _frames(2)
	_check(again.is_home(), "lần sau bồ câu non đậu sẵn ở chuồng")


func _place(p: Vector3) -> void:
	bo.global_position = p + Vector3(0, 0.1, 0)
	bo.velocity = Vector3.ZERO


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> void:
	await _frames(int(s * 60.0))


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1
