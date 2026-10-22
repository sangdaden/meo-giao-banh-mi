extends SceneTree
## Chụp ảnh chi tiết phố P4 trong game (scripts/chi_tiet_pho.gd) ở vài góc gần, renderer giống bản web.
## Chạy: xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
##   -s tools/chup_chi_tiet_pho.gd -- --chup=<thư_mục_ảnh> [--ngay=thu_hai]

## tên, vị trí camera, điểm nhìn
const SHOTS := [
	["day_dien_nga_tu", Vector3(8.0, 1.8, 1.5), Vector3(15.0, 4.5, -2.0)],
	["pho_ngoai_khoi_1", Vector3(-1.0, 1.6, -28.6), Vector3(4.0, 0.6, -24.6)],
	["pho_ngoai_khoi_3", Vector3(30.0, 1.6, -28.6), Vector3(35.0, 0.6, -24.6)],
	["hem_khoi_5", Vector3(1.5, 1.4, 15.5), Vector3(9.0, 1.2, 15.0)],
	["hem_khoi_1", Vector3(-20.5, 1.4, -15.5), Vector3(-28.0, 0.6, -15.0)],
	["pho_ngoai_khoi_5", Vector3(-10.0, 1.6, 28.6), Vector3(-4.0, 0.6, 24.6)],
	["cong_vien_cay", Vector3(-30.0, 2.0, 2.0), Vector3(-41.0, 4.0, 12.0)],
	["mat_duong", Vector3(-34.0, 1.6, -1.0), Vector3(-41.0, 0.0, 3.0)],
]

var out := "anh_chi_tiet_pho"


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
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 300.0
	cam.cull_mask = 0xFFFFF & ~(1 << 11)
	scene.add_child(cam)
	cam.make_current()
	for s in SHOTS:
		cam.position = s[1]
		cam.look_at(s[2])
		for i in 12:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(out.path_join(s[0] + ".png"))
		print("[chup] ", s[0])
	quit()
