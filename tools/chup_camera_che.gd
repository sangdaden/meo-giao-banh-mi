extends SceneTree
## Chụp so sánh camera trước/sau khi làm mờ vật che (A1): mỗi cảnh hai ảnh, _truoc (tắt làm mờ) và _sau.
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 30 -s tools/chup_camera_che.gd -- <thư_mục_ra>

var out := "user://chup_camera_che"
var main: Node
var p: CharacterBody3D
var rig: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	PlayMode.day = "thu_bay"
	GameState.use_test_save("user://luu_game_chup_camera_che.cfg")
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _shot(name: String) -> void:
	await _wait(30)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join("%s.png" % name))
	print("đã chụp ", name)


## Đặt Bơ và góc camera, chụp một ảnh tắt làm mờ và một ảnh bật.
func _pair(name: String, pos: Vector3, yaw: float, pitch: float) -> void:
	for on in [false, true]:
		rig.cutter.enabled = on
		p.velocity = Vector3.ZERO
		p.global_position = pos
		rig.yaw = yaw
		rig.pitch = pitch
		rig._manual_ms = Time.get_ticks_msec()  # giữ nguyên góc đặt tay
		rig._snap()
		await _wait(20)
		rig._manual_ms = Time.get_ticks_msec()
		await _shot("%s_%s" % [name, "sau" if on else "truoc"])


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(30)
	main = current_scene
	p = main.player
	rig = main.get_node("CameraRig")
	main.hud.visible = false
	# 1. Như video Sang quay: Bơ dưới đất cạnh đầu tây mái hiên khối 2, camera chếch trên cao phía đông
	await _pair("1_mai_hien_khoi_2", Vector3(-7.5, 0.05, -6.5), PI / 2.0, -1.0)
	# 2. Bơ đi dưới mái hiên, camera nhìn từ ngoài đường lên
	await _pair("2_duoi_mai_hien", Vector3(-3.5, 0.05, -6.7), 0.15, -0.75)
	# 3. Chồng thùng che giữa camera và Bơ
	await _pair("3_chong_thung", City.CORNER_STAIR + Vector3(1.6, 0.05, 0), -PI / 2.0, -0.25)
	# 4. Bơ đứng trên mái hiên khối 2, camera đang chúc thẳng xuống: _truoc giữ góc, _sau buông chuột 3 giây
	for on in [false, true]:
		rig.cutter.enabled = on
		p.velocity = Vector3.ZERO
		p.global_position = Vector3(-3.5, 3.0, -6.5)
		rig.yaw = 0.0
		rig.pitch = -1.15
		rig._snap()
		rig._manual_ms = -100000
		for i in 120:
			if not on:
				rig._manual_ms = Time.get_ticks_msec()
				rig.pitch = -1.15
			await process_frame
		var n := 0
		while on and rig.pitch < rig.high_pitch - 0.03 and n < 900:
			n += 1
			await process_frame
		if not on:
			rig._manual_ms = Time.get_ticks_msec() + 100000  # chụp lúc vẫn giữ góc cũ
		await _shot("4_tren_mai_hien_%s" % ("sau" if on else "truoc"))
	rig._manual_ms = -100000
	quit()
