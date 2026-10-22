extends SceneTree
## Chụp Chủ Nhật lúc bot chơi: sáng giao khay, sân hội, từng trò thi, trao huy chương, tổng kết.
##   (bỏ --autotest thì chỉ chụp cảnh sáng lúc mới vào)
##   xvfb-run godot --path . --rendering-driver opengl3 -s tools/chup_hoi_meo.gd -- --autotest --ngay=chu_nhat --chup=<thư_mục>

var out := "user://chup_hoi_meo"
var _last := ""
var _wait := -1
var _n := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chup="):
			out = a.substr(7)
	DirAccess.make_dir_recursive_absolute(out)
	PlayMode.day = "chu_nhat"
	change_scene_to_file.call_deferred("res://scenes/main.tscn")


func _process(_delta: float) -> bool:
	var cn := current_scene.get_node_or_null("ChuNhat") if current_scene else null
	if cn == null:
		return false
	var key := "%s_%d" % [cn.phase, cn.current]
	if cn.phase == "sang" and cn.player and cn.player.carrying:
		key = "sang_khay"
	if key != _last:
		_last = key
		_wait = 25 if "--autotest" in OS.get_cmdline_user_args() else 90
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			_n += 1
			root.get_viewport().get_texture().get_image().save_png(out.path_join("%02d_%s.png" % [_n, key]))
			if not "--autotest" in OS.get_cmdline_user_args():
				quit()  # không có bot: chỉ chụp cảnh sáng lúc mới vào
	return false
