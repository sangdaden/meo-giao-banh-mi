extends SceneTree
## Chụp 8 mèo Hội mèo (MeoNpc.CAST) đứng thành hàng, mỗi con một dáng, để xem nhanh scripts/meo_npc.gd.
##   xvfb-run godot --path . -s tools/chup_meo_hoi.gd -- <thư_mục_ra>
## Ảnh: hang.png (8 con, dáng đứng/đi/chạy/ngồi/nằm/ngủ/trốn/reo), dong_tac.png (nhận túi, đưa túi, huy chương)

const POSES := ["dung", "di", "chay", "ngoi", "nam", "ngu", "tron", "reo"]


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if not args.is_empty() else "user://meo_hoi"
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new()
	root.add_child(world)
	AnhSang.build(world, "pho_sang")
	Blocks.solid_box(world, Vector3(20, 1, 10), Vector3(0, -0.5, 0), Color("#C9C3B3"))
	var cam := Camera3D.new()
	cam.fov = 40.0
	world.add_child(cam)
	cam.position = Vector3(0, 1.5, 6.5)
	cam.look_at(Vector3(0, 0.35, 0))
	var cats: Array = []
	var ids: Array = MeoNpc.CAST.keys()
	for i in ids.size():
		var m := MeoNpc.from_cast(ids[i])
		world.add_child(m)
		m.position = Vector3(-3.5 + i * 1.0, 0, 0)
		m.rotation.y = -PI * 0.5  # nhìn ngang sang trái khung hình
		m.show_name()
		cats.append(m)
	await process_frame
	for i in cats.size():
		var m: MeoNpc = cats[i]
		match POSES[i]:
			"di":
				m.walk_to(m.position + Vector3(0, 0, -0.01) + Vector3.LEFT * 50.0)
			"chay":
				m.run_to(m.position + Vector3.LEFT * 80.0)
			_:
				m.set_pose(POSES[i])
		m.say(POSES[i], 99.0)
	for k in 50:
		await process_frame
	# đứng tại chỗ cho hai con đang đi/chạy để vẫn trong khung
	cats[1].position.x = -2.5
	cats[2].position.x = -1.5
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join("hang.png"))
	for i in 3:
		var m: MeoNpc = cats[i]
		m.stop()
		m.position.x = -3.5 + i * 1.0
		m.play(["nhan_tui", "dua_tui", "nhan_huy_chuong"][i])
		m.say(["nhan_tui", "dua_tui", "nhan_huy_chuong"][i], 99.0)
	for k in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join("dong_tac.png"))
	print("đã chụp ", out)
	quit()
