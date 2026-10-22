extends SceneTree
## Lỗi Sang báo 22/10 ("nhảy lên kẹt luôn động tác"): Thứ Bảy bật bám mép cả khu phố, nhảy vào chồng thùng
## cạnh lò bánh Cô Ba là Bơ treo trên mép, giữ dáng bam_mep mãi vì không biết phải bấm Space.
## Thong thả: giữ phím đi tới là tự leo lên, đẩy ra xa tường là buông; leo xong động tác Blender tắt hẳn.
## Thử thách: giữ phím đi tới vẫn treo (như cũ), Space mới leo.
## Chạy: godot --headless --path . -s tests/test_bam_mep_thu_bay.gd

const CRATE_TOP := 1.6           ## hai thùng chồng ở (-25,8; -2) trong city.gd
const START := Vector3(-28.0, 0.1, -2.0)

var m: Node3D
var bo: CharacterBody3D
var fails := 0


func _init() -> void:
	PlayMode.day = "thu_bay"
	PlayMode.mode = PlayMode.Mode.DELIVERY
	GameState.use_test_save("user://luu_game_test_bam_mep.cfg")
	_run.call_deferred()


func _run() -> void:
	print("Thong thả:")
	await _load(-1)
	_check(bo.climb_moves, "Thứ Bảy bật bám mép")
	# 1. Giữ phím đi tới suốt: bám rồi tự leo lên nóc thùng
	await _put(START)
	_check(await _jump_toward("move_right", true), "nhảy vào chồng thùng thì bám mép")
	Input.action_press("move_right")
	var pulled := false
	for i in int((bo.hang_auto_pull + bo.pull_time) * 60) + 30:
		await physics_frame
		pulled = pulled or bo.climb == "pull"
		if pulled and bo.climb == "":
			break  # lên tới nóc thì thả phím (thùng chỉ rộng 0,8 m)
	Input.action_release("move_right")
	await _frames(10)
	_check(bo.climb == "" and absf(bo.global_position.y - CRATE_TOP) < 0.15, "giữ phím đi tới là tự leo lên nóc thùng (y = %.2f)" % bo.global_position.y)
	await _frames(20)
	_check(bo.clip == "", "leo xong không còn kẹt động tác (clip = '%s')" % bo.clip)
	# 2. Bám rồi đẩy ra xa tường: buông, rơi xuống đất
	await _put(START)
	_check(await _jump_toward("move_right", false), "bám lại mép")
	await _frames(15)
	Input.action_press("move_left")
	await _frames(40)
	Input.action_release("move_left")
	_check(bo.climb == "" and bo.global_position.y < 0.3, "đẩy ra xa tường là buông (y = %.2f)" % bo.global_position.y)
	await _frames(20)
	_check(bo.clip == "", "buông xong không còn kẹt động tác (clip = '%s')" % bo.clip)

	print("Thử thách:")
	await _load(1)
	await _put(START)
	_check(await _jump_toward("move_right", true), "bám mép")
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	_check(bo.climb == "hang", "giữ phím đi tới vẫn treo như cũ")
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	await _frames(int(bo.pull_time * 60) + 30)
	_check(bo.climb == "" and absf(bo.global_position.y - CRATE_TOP) < 0.15, "Space leo lên nóc thùng (y = %.2f)" % bo.global_position.y)
	await _frames(20)
	_check(bo.clip == "", "không còn kẹt động tác (clip = '%s')" % bo.clip)

	DoKho.force = 0
	print("BAM MEP TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


func _load(force: int) -> void:
	if m:
		m.queue_free()
		await _frames(5)
	DoKho.force = force
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await _frames(30)
	bo = m.player
	bo.can_move = true
	var rig = m.get_node_or_null("CameraRig")
	if rig:
		rig.yaw = 0.0


func _put(p: Vector3) -> void:
	bo.climb = ""
	bo.velocity = Vector3.ZERO
	bo.global_position = p
	await _frames(30)


## Giữ hướng, nhảy; trả về true khi Bơ bám mép. keep: vẫn giữ phím hướng sau khi bám.
func _jump_toward(dir: String, keep: bool) -> bool:
	Input.action_press(dir)
	Input.action_press("jump")
	var grabbed := false
	for i in 80:
		await physics_frame
		if i == 12:
			Input.action_release("jump")
		if bo.climb == "hang":
			grabbed = true
			break
	Input.action_release("jump")
	if not keep:
		Input.action_release(dir)
	return grabbed


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  LỖI  ") + what)
	if not ok:
		fails += 1
