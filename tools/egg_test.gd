extends SceneTree
## Thử riêng đơn mua trứng Thứ Ba (gói T3-3): tạp hóa Cô Hai, túi trứng dễ vỡ, mang về lò.
## Chạy: godot --headless --path . --script res://tools/egg_test.gd
## In "EGG TEST OK" và thoát mã 0 nếu mọi tình huống đúng.

const PlayerScript := preload("res://scripts/player.gd")
const DeliveriesScript := preload("res://scripts/deliveries.gd")
## Màn giao giả: chỉ có những gì ShopTapHoa đọc từ main.gd
const FAKE_MAIN := """
extends Node3D
signal order_delivered(index: int, order: Dictionary)
var intact := true
var orders: Array = []
var result_notes: Array = []
"""
const ORDER := {"who": "Cô Hai", "place": "Tạp hóa", "item": "1 túi 6 trứng", "kind": "errand", "errand_item": "trung6",
	"pos": ShopTapHoa.COUNTER_POINT, "time": 25.0, "color": Color("#E39C7A"), "delivery": "errand", "side_quest": "du_6_trung"}

var world: Node3D
var player: CharacterBody3D
var deliveries: Node3D
var fails := 0


func _initialize() -> void:
	DoKho.force = 1  # các bài thử này kiểm tra số của Chế độ thử thách (số gốc)
	_run.call_deferred()


func _run() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "sneak", "deliver"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
	var fake := GDScript.new()
	fake.source_code = FAKE_MAIN
	fake.reload()
	world = fake.new()
	world.orders = [ORDER, {}, {}]
	root.add_child(world)
	City.build(world)
	deliveries = DeliveriesScript.new()
	deliveries.build_static(world, [ORDER])
	_check(Days.get_day("thu_ba").orders[1].pos.distance_to(ShopTapHoa.COUNTER_POINT) < 0.01, "đơn 2 Thứ Ba lấy trứng ở quầy Cô Hai")
	player = PlayerScript.new()
	world.add_child(player)
	player.can_move = true
	world.add_child(deliveries)
	deliveries.setup(player, null, null, true)
	var shop: ShopTapHoa = deliveries.shop
	_check(shop != null, "có node tạp hóa khi ngày có đơn errand")
	_check(deliveries.is_errand(0), "đơn kind errand")

	# Tới quầy (main.gd nhận đơn errand trong vùng quanh quầy): Cô Hai đưa túi 6 trứng
	await _teleport(ShopTapHoa.COUNTER_POINT + Vector3(0, 0.1, 0))
	_check(absf(player.global_position.y) < 0.3, "đứng được trước quầy trong tiệm (y = %.2f)" % player.global_position.y)
	player.carrying = true
	deliveries.on_pick_up(0)
	_check(not player.bread.visible, "đơn mua trứng không hiện ổ bánh trong túi")
	_check(shop.state == "carry", "lấy được túi trứng ở quầy")
	_check(player.fragile_item == "trung6" and player.fragile_count == 6, "ngậm túi 6 trứng")
	_check(deliveries.side_ok[0], "chưa vỡ quả nào thì nhiệm vụ phụ còn đạt")

	# Rơi từ 2 m (ngoài đường, chỗ trống): vỡ một quả
	var broken := [0]
	player.fragile_damaged.connect(func(_n): broken[0] += 1)
	await _teleport(Vector3(0, 2.2, -2.5))
	await _settle()
	_check(player.fragile_count == 5, "đáp đất từ 2 m vỡ một quả (còn %d)" % player.fragile_count)
	# Nhảy thấp 0,5 m: không vỡ
	await _teleport(Vector3(0, 0.6, -2.5))
	await _settle()
	_check(player.fragile_count == 5, "đáp đất từ 0,5 m không vỡ (còn %d)" % player.fragile_count)

	# Va người: vỡ một quả; va liền ngay sau đó không vỡ thêm
	var kinds := []
	player.bumped.connect(func(k): kinds.append(k))
	for k in 40:
		await physics_frame  # vừa vỡ một quả lúc rơi: đợi hết lúc nghỉ 0,5 s
	player.bump("person")
	player.bump("person")
	_check(player.fragile_count == 4, "va người vỡ một quả, va liền không vỡ hai (còn %d)" % player.fragile_count)
	for k in 40:
		await physics_frame
	player.bump("cart")
	_check(player.fragile_count == 3, "va xe đẩy vỡ thêm một quả (còn %d)" % player.fragile_count)
	_check(kinds == ["person", "person", "cart"], "tín hiệu bumped đủ loại: %s" % [kinds])
	_check(broken[0] == 3, "fragile_damaged phát 3 lần")
	_check(not deliveries.side_ok[0] and not world.intact, "vỡ 3 quả: trượt nhiệm vụ phụ, mất sao nguyên vẹn")
	for k in 40:
		await physics_frame

	# Va thật vào người có meta bump_kind khi đang chạy: player tự phát bumped("person")
	var body := StaticBody3D.new()
	body.collision_layer = Blocks.LAYER_PROP
	body.set_meta("bump_kind", "person")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.5, 1.6, 0.4)
	cs.shape = bs
	cs.position.y = 0.8
	body.add_child(cs)
	body.position = Vector3(0, 0, -4.2)
	world.add_child(body)
	kinds.clear()
	await _teleport(Vector3(0, 0.05, -2.5))
	await _settle()
	Input.action_press("move_forward")
	for k in 40:
		await physics_frame
	Input.action_release("move_forward")
	_check(kinds == ["person"] and player.fragile_count == 2, "chạy va người thật: vỡ một quả (còn %d, %s)" % [player.fragile_count, kinds])

	# Nắp tủ kem trơn
	await _teleport(Vector3(ShopTapHoa.X1 - 0.75, 1.0, ShopTapHoa.FRONT_Z + 2.4))
	await _settle()
	_check(player._oil > 0, "đứng trên nắp tủ kem là trơn")

	# Cửa sau ra hẻm giữa khối 2: đi từ hẻm vào tới quầy được
	await _teleport(Vector3(ShopTapHoa.X1 - 0.55, 0.1, ShopTapHoa.FRONT_Z + ShopTapHoa.DEPTH + 0.6))
	await _settle()
	player.carry_fragile("", 0)
	var ok_door := await _walk_to(Vector3(ShopTapHoa.X1 - 0.55, 0, ShopTapHoa.FRONT_Z + ShopTapHoa.DEPTH - 1.6), 3.0)
	_check(ok_door, "chui qua cửa sau tiệm từ hẻm giữa khối (tới %s)" % player.global_position)
	player.carry_fragile("trung6", 2)  # trả lại số trứng còn lại để thử tiếp
	shop.state = "carry"

	# Về lò: main chấm điểm rồi phát order_delivered
	await _teleport(City.BAKERY_POINT + Vector3(0, 0.1, 0))
	world.result_notes.append("dư 5 giây")
	world.order_delivered.emit(0, ORDER)
	_check(deliveries.errand_eggs(0) == 2, "số trứng về lò = 2 (%d)" % deliveries.errand_eggs(0))
	var gs: Script = GameState
	_check(not ("eggs_brought" in gs) or gs.get("eggs_brought") == 2, "ghi số trứng cho màn bếp (GameState.eggs_brought)")
	_check(world.result_notes[-1].ends_with("về lò còn 2/6 trứng"), "ghi chú kết quả có số trứng: %s" % world.result_notes[-1])
	_check(player.fragile_item == "", "đã đưa túi trứng cho Cô Ba")

	# Đi lại từ đầu, không vỡ quả nào: đạt nhiệm vụ phụ
	world.intact = true
	deliveries.on_pick_up(0)
	await _teleport(City.BAKERY_POINT + Vector3(0, 0.1, 0))
	await _settle()
	world.result_notes.append("dư 9 giây")
	world.order_delivered.emit(0, ORDER)
	_check(deliveries.side_ok[0] and world.intact and deliveries.errand_eggs(0) == 6, "đủ 6 quả: đạt nhiệm vụ phụ, còn nguyên vẹn")

	print("EGG TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


## Đẩy phím đi tới cho tới khi gần đích (camera nhìn theo -z, nên xoay đích về hướng đi)
func _walk_to(target: Vector3, seconds: float) -> bool:
	var frames := int(seconds * 60)
	for k in frames:
		var d := target - player.global_position
		d.y = 0
		if d.length() < 0.35:
			Input.action_release("move_forward"); Input.action_release("move_back")
			Input.action_release("move_left"); Input.action_release("move_right")
			return true
		var dir := d.normalized()
		for a in ["move_forward", "move_back", "move_left", "move_right"]:
			Input.action_release(a)
		if dir.z < -0.3: Input.action_press("move_forward", -dir.z)
		if dir.z > 0.3: Input.action_press("move_back", dir.z)
		if dir.x < -0.3: Input.action_press("move_left", -dir.x)
		if dir.x > 0.3: Input.action_press("move_right", dir.x)
		await physics_frame
	for a in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(a)
	return false


func _teleport(pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame


## Đợi Bơ rơi chạm đất
func _settle() -> void:
	for k in 90:
		await physics_frame
		if player.is_on_floor() and k > 5:
			break
	for k in 3:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print("  ", "ok   " if ok else "FAIL ", what)
	if not ok:
		fails += 1
