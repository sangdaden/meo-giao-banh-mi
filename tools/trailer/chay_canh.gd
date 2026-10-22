extends SceneTree
## Quay một cảnh cho trailer bằng Movie Maker của Godot (ảnh đều 30 hình/giây, không phụ thuộc máy chậm).
## Chạy (máy đám mây):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 \
##     --write-movie <ra.avi> -s tools/trailer/chay_canh.gd -- <cảnh.tscn> <giây> [--an-hud] [các cờ của cảnh như --demo-bep]

var scene := "res://scenes/kitchen.tscn"
var seconds := 10.0
var hide_hud := false


func _initialize() -> void:
	var rest := []
	for a in OS.get_cmdline_user_args():
		if a == "--an-hud":
			hide_hud = true
		elif a.ends_with(".tscn"):
			scene = a
		elif a.is_valid_float():
			seconds = float(a)
	GameState.use_test_save("user://luu_game_trailer.cfg")
	_run.call_deferred()


func _run() -> void:
	# Tắt nhạc nền của game, giữ tiếng động (bước chân, xe, mưa, tiếng sủa) để trộn dưới nhạc trailer
	var music := AudioServer.get_bus_index("Music")
	if music != -1:
		AudioServer.set_bus_mute(music, true)
	change_scene_to_file(scene)
	var frames := int(seconds * 30.0)
	for i in frames:
		await process_frame
		if hide_hud and i < 300:
			_hide_layers(root)
	quit()


func _hide_layers(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasLayer:
			c.visible = false
		_hide_layers(c)
