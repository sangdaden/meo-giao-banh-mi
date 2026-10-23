extends SceneTree
## Chụp chào mào (K3 lồng Ông Bảy ở góc cờ Thứ Ba, K4 chim trong lồng ban công) ra PNG để soát.
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 30 -s tools/chup_chao_mao.gd -- <thư_mục_ra>

var out := "user://chup_chao_mao"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	PlayMode.day = "thu_ba"
	GameState.use_test_save("user://luu_game_chup_chao_mao.cfg")
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _shot(name: String) -> void:
	await _wait(40)
	var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var tris := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % name))
	print("đã chụp %s · %d lệnh vẽ · %d tam giác" % [name, draws, tris])


func _look(cam: Camera3D, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.current = true


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(200)  # chờ thẻ ngày tắt
	var main: Node = current_scene
	var p: CharacterBody3D = main.player
	main.hud.visible = true
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.fov = 50
	var cages := get_nodes_in_group("con_vat").filter(func(n): return n is ChaoMao)
	var chess: ChaoMao = cages.filter(func(c): return not c.nhe)[0]
	var hook := chess.global_position
	# 1. Lồng Ông Bảy dưới tán cây, nhìn từ bàn cờ
	p.global_position = hook + Vector3(1.2, -2.4, 0.6)
	_look(cam, hook + Vector3(3.2, -0.9, 2.2), hook + Vector3(0, -0.6, 0))
	await _shot("6_long_ong_bay")
	_look(cam, hook + Vector3(0.9, -0.35, 0.5), hook + Vector3(0, -0.45, 0))
	await _shot("7_chao_mao_can")
	chess.on_called(p.global_position)
	await _wait(12)
	await _shot("8_chao_mao_hot")
	# 2. Chim trong lồng ban công
	var i := 0
	for c: ChaoMao in cages.filter(func(c): return c.nhe):
		var f := c.global_transform.basis.z.normalized()
		_look(cam, c.global_position + f * 0.7 + Vector3(0.2, 0.15, 0), c.global_position + Vector3(0, 0.25, 0))
		await _shot("9_ban_cong_%d" % i)
		_look(cam, Vector3(c.global_position.x + 3.0, 1.6, c.global_position.z) + f * 7.0, c.global_position)
		await _shot("9_ban_cong_%d_xa" % i)
		i += 1
	quit()
