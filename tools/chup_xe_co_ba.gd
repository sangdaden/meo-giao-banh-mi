extends SceneTree
## Chụp xe bánh mì Cô Ba trước lò (scripts/xe_co_ba.gd) ở vài góc gần, renderer giống bản web.
## Chạy: xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
##   -s tools/chup_xe_co_ba.gd -- --chup=<thư_mục_ảnh> [--ngay=thu_hai]

## tên, vị trí camera (cộng vào chỗ xe), điểm nhìn (cộng vào chỗ xe)
const SHOTS := [
	["truoc", Vector3(0.0, 1.3, 3.2), Vector3(0.0, 0.8, 0.0)],
	["xien", Vector3(2.6, 1.6, 2.6), Vector3(0.0, 0.8, 0.0)],
	["tam_meo", Vector3(-0.6, 0.7, 2.0), Vector3(0.0, 0.9, 0.0)],
	["xa", Vector3(-3.0, 2.4, 7.5), Vector3(0.0, 1.0, -1.0)],
]

var out := "anh_xe_co_ba"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chup="):
			out = a.substr(7)
		elif a.begins_with("--ngay="):
			PlayMode.day = a.substr(7)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 10:
		await process_frame
	for layer in scene.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var player: Node3D = scene.get("player")
	if player:
		player.visible = false
	var at := City.BAKERY_POINT + Vector3(2.4, 0, 0.2)
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 300.0
	cam.cull_mask = 0xFFFFF & ~(1 << 11)
	scene.add_child(cam)
	cam.make_current()
	for s in SHOTS:
		cam.position = at + s[1]
		cam.look_at(at + s[2])
		for i in 12:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(out.path_join(s[0] + ".png"))
		print("[chup] ", s[0])
	quit()
