extends SceneTree
## Chụp màn Cài đặt (mục Hỗ trợ) và màn "Đổi phím và tay cầm" (F2 B3) ra PNG.
## Chạy: xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/chup_doi_phim.gd -- <thư_mục_ra> [--lang=en]

var out := "user://chup"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _shot(name: String) -> void:
	await _wait(8)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("đã chụp ", name)


func _run() -> void:
	var en := "--lang=en" in OS.get_cmdline_user_args()
	var hau := "_en" if en else ""
	change_scene_to_file("res://scenes/menu.tscn")
	await _wait(30)
	var menu := current_scene
	menu.settings.open()
	await _shot("cai_dat" + hau)
	for sc: ScrollContainer in menu.settings.find_children("*", "ScrollContainer", true, false):
		sc.scroll_vertical = 100000
	await _shot("cai_dat_ho_tro" + hau)
	var p: DoiPhimPanel
	for c in menu.settings.get_children():
		if c is DoiPhimPanel:
			p = c
	p.open()
	await _shot("doi_phim" + hau)
	BanPhim.dat_phim("jump", KEY_G)
	p._lam_moi()
	p._bat_dau("deliver", "phim", p._o["deliver"][0])
	await _shot("doi_phim_cho" + hau)
	BanPhim.mac_dinh()
	quit()
