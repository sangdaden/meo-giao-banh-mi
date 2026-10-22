extends SceneTree
## Chụp bản đồ nhỏ (scripts/ui/ban_do_nho.gd) ở cả 7 ngày, mỗi ngày một ảnh đang chơi và một ảnh bản đồ lớn.
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 30 -s tools/chup_ban_do_nho.gd -- <thư_mục_ra> [ngày...]

var out := "user://chup_ban_do"
## Ngày, đơn đang làm, Bơ đang mang bánh chưa, chỗ Bơ đứng, hướng camera (yaw)
const SHOTS := [
	["thu_hai", 1, true, Vector3(-18.0, 0.1, -2.0), 0.6],
	["thu_ba", 1, false, Vector3(-24.0, 0.1, -4.0), 2.6],
	["thu_tu", 2, true, Vector3(2.0, 0.1, -3.0), -1.2],
	["thu_nam", 3, true, Vector3(-10.0, 0.1, 3.5), -0.4],
	["thu_sau", 3, true, Vector3(-26.0, 0.1, 3.0), 3.0],
	["thu_bay", 0, false, Vector3(-4.0, 0.1, -3.0), 0.0],
	["chu_nhat", 0, true, Vector3(-24.0, 0.1, 2.0), 2.4],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred(args.slice(1))


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _shot(name: String) -> void:
	await _wait(4)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("đã chụp ", name)


func _run(only: Array) -> void:
	GameSettings.set_value("tips", false)
	for s in SHOTS:
		if not only.is_empty() and not s[0] in only:
			continue
		PlayMode.day = s[0]
		change_scene_to_file("res://scenes/main.tscn")
		await _wait(40)
		var main: Node = current_scene
		if main.orders.size() > 0:
			main.order_index = s[1]
			main.player.carrying = s[2]
			main.time_left = 40.0
		main.player.global_position = s[3]
		main.player.velocity = Vector3.ZERO
		main.rig.yaw = s[4]
		var hud: Node = main.hud
		hud._day_time = 0.0
		hud.day_card.visible = false
		await _wait(60)
		await _shot("%s_choi" % s[0])
		hud.toggle_big_map()
		await _wait(20)
		await _shot("%s_ban_do_lon" % s[0])
		hud.toggle_big_map()
	quit()
