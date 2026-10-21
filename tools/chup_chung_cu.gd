extends SceneTree
## Chụp cảnh leo chung cư (Thứ Năm) từ vài góc, có Bơ ở các tư thế leo, để đưa lên trang thiết kế.
## Chạy (cần màn hình, trên máy đám mây dùng xvfb-run):
##   godot --path . --rendering-driver opengl3 -s tools/chup_chung_cu.gd -- <thư_mục_ra>

var out := "user://chup_chung_cu"
var scene: Node3D
var bo: CharacterBody3D
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Đặt Bơ đứng yên ở p, quay mặt về hướng yaw (radian, 0 = nhìn về phía bắc −z).
func _bo_at(p: Vector3, yaw: float, climb := "") -> void:
	bo.climb = climb
	bo.global_position = p
	bo.velocity = Vector3.ZERO
	bo._prev_pos = p
	bo._curr_pos = p
	bo.visual.rotation.y = yaw


func _shot(name: String, from: Vector3, at: Vector3, fov := 60.0, hud := false) -> void:
	scene.hud.visible = hud
	if hud:
		scene.rig.camera.current = true
	else:
		cam.current = true
		cam.fov = fov
		cam.global_position = from
		cam.look_at(at)
	await _frames(20)
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("đã chụp ", name)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	scene = load("res://scenes/chung_cu.tscn").instantiate()
	root.add_child(scene)
	await _frames(10)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	bo = scene.player
	scene.playing = false
	cam = Camera3D.new()
	scene.add_child(cam)

	# Góc chơi thật, có HUD, lúc bắt đầu ở hẻm
	scene.playing = true
	await _frames(30)
	scene.rig.first_person = false  # cài đặt máy có thể đang để góc thứ nhất
	await _shot("1_bat_dau_hud", Vector3.ZERO, Vector3.ZERO, 70.0, true)
	scene.playing = false

	# Toàn cảnh mặt hành lang: dãy căn hộ, khối cầu thang, thang máy kính, nhà bên
	_bo_at(Vector3(9.0, 0.0, 3.5), PI)
	await _shot("2_toan_canh", Vector3(4.0, 11.0, 23.0), Vector3(9.0, 6.5, -2.0), 55.0)

	# Ngoài tường hông tây: Bơ bám mép chuồng cọp D
	var d: Array = scene.WALL_STEPS[3]
	_bo_at(Vector3(-0.3, d[3] - 0.5, d[2] + 0.27), 0.0, "hang")
	await _shot("3_ngoai_tuong", Vector3(-7.5, 9.5, 5.0), Vector3(-0.4, 8.0, -3.2), 55.0)
	await _shot("3b_bam_mep_gan", Vector3(-3.2, 10.6, -2.0), Vector3(-0.3, 9.6, -4.2), 50.0)

	# Ống nước
	bo.enter_pipe(scene.get_children().filter(func(n): return n is Area3D and n.has_meta("top"))[0])
	_bo_at(Vector3(-0.32, 7.0, scene.PIPE.z), PI / 2.0, "pipe")
	bo._pipe = bo._pipes[0]
	bo._wall_n = Vector3.LEFT
	await _shot("4_ong_nuoc", Vector3(-4.0, 8.0, -4.0), Vector3(-0.2, 7.0, -6.4), 55.0)

	# Khe 1,2 m giữa chung cư và nhà bên: bật tường
	_bo_at(Vector3(-0.55, 2.4, -3.6), PI / 2.0)
	bo.gravity = 0.0
	await _shot("5_khe_bat_tuong", Vector3(-0.6, 1.4, 4.5), Vector3(-0.6, 2.6, -4.0), 60.0)
	bo.gravity = 28.0

	# Cầu thang: chui dưới giá phơi đồ ở chiếu nghỉ tầng 2
	_bo_at(Vector3(scene.TX0 + 1.3, 4.5, -4.75), -PI / 2.0)
	bo.stance = "crouch"
	bo.crouch_amount = 1.0
	await _shot("6_cau_thang_gia_phoi", Vector3(17.4, 5.7, -2.0), Vector3(18.4, 4.7, -4.9), 75.0)
	bo.stance = "walk"
	bo.crouch_amount = 0.0

	# Em bé ngủ võng ở hành lang tầng 3, Bơ rón rén ở chiếu tầng 3
	_bo_at(Vector3(17.4, 6.0, -0.8), PI / 2.0)
	bo.stance = "sneak"
	await _shot("7_em_be_ngu", Vector3(12.0, 8.2, 4.5), Vector3(15.5, 6.6, -1.0), 50.0)
	bo.stance = "walk"

	# Thang máy ở tầng trệt, Ông Bảy bước ra chắn cửa
	scene.lift = scene.Lift.OPEN_GROUND
	scene.lift_floor = 0.0
	scene._lift_blocked = true
	scene._lift_t = 1.0
	scene._ong_bay.visible = true
	scene._ong_bay.position = Vector3(20.0, 0.6, -0.9)
	_bo_at(Vector3(scene.TX0 + 0.8, 0.0, -0.9), -PI / 2.0)
	await _shot("8_thang_may", Vector3(16.5, 2.0, 3.2), Vector3(19.8, 1.0, -0.9), 60.0)

	# Cửa 5B-1: Bé Na ra nhận bánh
	scene._be_na.visible = true
	_bo_at(scene.DOOR + Vector3(0.6, 0, 0.2), PI * 0.75)
	await _shot("9_giao_be_na", Vector3(3.6, 13.6, 2.6), Vector3(0.9, 12.5, -1.3), 55.0)
	quit()
