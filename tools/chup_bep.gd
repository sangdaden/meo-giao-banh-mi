extends SceneTree
## Chụp màn bếp lúc bot tự chơi (--demo-bep) để soát HUD, camera, Cô Ba.
## Chạy: xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x900 \
##   -s tools/chup_bep.gd -- <thư_mục_ra> --demo-bep [--chup-moi=2.5] [--chup-den=60] [--ngay=thu_hai]
## Mỗi --chup-moi giây chụp một ảnh tới --chup-den giây; ảnh tên bep_<giây>.png.

var out := "user://chup_bep"
var every := 2.5
var until := 60.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chup-moi="):
			every = float(a.trim_prefix("--chup-moi="))
		elif a.begins_with("--chup-den="):
			until = float(a.trim_prefix("--chup-den="))
		elif not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/kitchen.tscn")
	var t := 0.0
	while t <= until:
		await create_timer(every).timeout
		t += every
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out.path_join("bep_%05.1f.png" % t))
	quit()
