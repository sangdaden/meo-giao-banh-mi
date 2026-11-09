extends SceneTree
## Chụp 7 động tác U2 "Bơ phản ứng theo ngày" (scripts/bo_theo_ngay.gd) ngay trong cảnh phố từng ngày, để soát
## dáng trong game so với trang duyệt. Mỗi động tác 3 khung (đầu, giữa, cuối) chụp ngang và chéo.
## Chạy (thêm <mã ngày> sau thư mục để chụp một ngày): xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 60 -s tools/chup_bo_theo_ngay.gd -- <thư_mục_ra>

var out := "user://chup_bo_theo_ngay"
## [ngày, chỗ đứng, các giây chụp]
const CANH := [
	["thu_hai", Vector3.INF, [0.9, 1.7, 2.6]],
	["thu_ba", CityProps.CHESS_CORNER + Vector3(0, 0, 2.2), [0.8, 1.8, 3.0]],
	["thu_tu", Vector3(-21.5, 0, 6.2), [0.5, 1.2, 2.0]],
	["thu_nam", Vector3(-11.5, 0, 5.6), [0.8, 1.6, 2.8]],
	["thu_sau", ThuSau.ALTAR_POS + Vector3(-0.6, 0, -1.2), [0.4, 1.05, 1.5]],
	["thu_bay", Vector3(-33.5, 0, 18.5), [0.7, 1.4, 2.2]],
	["chu_nhat", Vector3(-37.0, 0, 14.0), [0.9, 1.9, 3.0]],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameState.use_test_save("user://luu_game_chup_bo_theo_ngay.cfg")
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _run() -> void:
	var chi := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else ""  ## chụp một ngày
	for canh: Array in CANH:
		var day: String = canh[0]
		if chi != "" and day != chi:
			continue
		PlayMode.day = day
		GameState.day = day
		var main: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		await _wait(30)
		main.state = main.State.PLAY
		var p: CharacterBody3D = main.player
		p.can_move = true
		if main.hud.has_method("hide_day_card"):
			main.hud.hide_day_card()
		main.hud.visible = false
		var u2: BoTheoNgay = main.find_child("BoTheoNgay", true, false)
		if canh[1] != Vector3.INF:
			p.global_position = canh[1] + Vector3(0, 0.15, 0)
		await _wait(30)
		u2.set_physics_process(false)
		var cam := Camera3D.new()
		main.add_child(cam)
		cam.fov = 40
		var c: String = BoTheoNgay.CLIP[day]
		if day == "thu_bay":
			u2._goi_buom(p.global_position)
		var t0 := 0.0
		p.play_clip(c)
		if day == "thu_tu":
			p.play_clip("giu_nuoc")
		for i in 3:
			var giay: float = canh[2][i]
			await _wait(int((giay - t0) * 60.0))
			t0 = giay
			var at: Vector3 = p.global_position + Vector3(0, 0.25, 0)
			var yaw: float = p.visual.global_rotation.y
			for goc in [["ngang", PI * 0.5], ["cheo", PI * 0.75], ["ben_kia", -PI * 0.75]]:
				var d := Vector3(sin(yaw + goc[1]), 0.25, cos(yaw + goc[1])).normalized() * 1.6
				cam.global_position = at + d
				cam.look_at(at)
				cam.current = true
				await _wait(2)
				root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s_%d_%s.png" % [day, p.clip, i, goc[0]]))
			if day == "thu_tu" and i == 0:
				p.play_clip(c)
				t0 = 0.0
		print("đã chụp ", day, " ", c)
		main.queue_free()
		await _wait(5)
	quit()
