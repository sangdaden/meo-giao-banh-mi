extends SceneTree
## Chụp các khung của phim mở đầu / cảnh kết tuần (scripts/phim/) để soát với storyboard C1.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/chup_phim.gd -- --phim=mo_dau --chup=<thư_mục>
##   ... --phim=ket_tuan [--muc-ban]   (kết tuần: --muc-ban giả như Thứ Bảy đã làm bạn với Mực)
## Chụp theo giây trong phim (bảng LUC), xong thì thoát. Kết tuần: tự bấm "Xem chữ chạy" lúc 44 s, "Tuần mới" lúc 88 s.

const LUC := {
	"mo_dau": [2.5, 7.5, 13.5, 17.5, 23.5, 29.5, 33.5, 38.0],
	"ket_tuan": [3.0, 8.5, 14.0, 20.0, 24.5, 29.0, 33.0, 40.0, 50.0, 62.0, 76.0, 92.0],
}

var out := "user://chup_phim"
var which := "mo_dau"
var _t := 0.0
var _i := 0
var _pressed := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chup="):
			out = a.substr(7)
		elif a.begins_with("--phim="):
			which = a.substr(7)
	DirAccess.make_dir_recursive_absolute(out)
	if "--muc-ban" in OS.get_cmdline_user_args():
		GameState.set_day("muc_ban", true, "thu_bay")
	Phim.which = which
	Phim.after = "menu"
	change_scene_to_file.call_deferred(Phim.SCENE)


func _process(delta: float) -> bool:
	if current_scene == null or not current_scene is Phim:
		return false
	_t += delta
	var ph := current_scene as Phim
	if which == "ket_tuan" and _pressed == 0 and _t >= 44.0:
		_pressed = 1
		for n in ph.get_children():
			if n is TongKetTuan:
				n._start_credits()
	if which == "ket_tuan" and _pressed == 1 and _t >= 88.0:
		_pressed = 2
		ph.script_node._morning()
	var times: Array = LUC.get(which, [])
	if _i < times.size() and _t >= times[_i]:
		_i += 1
		root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%02d_%04.1fs.png" % [which, _i, _t]))
		print("chụp ", _i, " lúc ", _t)
		if _i >= times.size():
			quit()
	if (current_scene as Phim).done:
		quit()
	return false
