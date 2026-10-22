extends SceneTree
## Chụp màn Thứ Tư (mưa, đường sân thượng, ván, cổng chào, bồ câu, nước ngập) ra PNG để soát khối tạm.
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 30 -s tools/chup_thu_tu.gd -- <thư_mục_ra>

var out := "user://chup_thu_tu"
## tên ảnh, vị trí camera, điểm nhìn, chỗ Bơ đứng (null: để nguyên), mức nước
const SHOTS := [
	["toan_canh_san_thuong", Vector3(-10, 26, 14), Vector3(-6, 6, -11), null, 0.12],
	["len_mai_hien_lo_banh", Vector3(-22.5, 4.5, 2.5), Vector3(-28.0, 4.0, -6.5), Vector3(-25.0, 2.5, -5.6), 0.0],
	["van_qua_duong_doc", Vector3(-19.5, 13.4, -6.5), Vector3(-23.2, 11.5, -10.6), Vector3(-23.0, 11.7, -10.6), 0.12],
	["cau_thang_sau_tap_hoa", Vector3(15.5, 8.0, -4.0), Vector3(10.5, 4.0, -12.0), null, 0.12],
	["chuong_bo_cau", Vector3(-4.4, 13.0, -5.5), Vector3(-4.4, 9.8, -11.5), Vector3(-6.2, 9.8, -9.0), 0.12],
	["cau_thang_hem_be_na", Vector3(16.5, 6.5, -6.0), Vector3(21.5, 3.0, -13.0), null, 0.12],
	["cong_chao_duong_ngap", Vector3(-31.0, 4.0, 3.0), Vector3(-23.7, 2.5, 0.0), Vector3(-23.75, 3.0, -2.0), 0.25],
	["cong_chao_cau_thang", Vector3(-15.0, 3.5, 2.5), Vector3(-21.0, 1.8, 6.5), null, 0.0],
	["sap_bao_chu_tu", Vector3(1.5, 1.8, -1.5), Vector3(-0.2, 1.0, -6.3), null, 0.0],
	["ca_phe_may_mua", Vector3(8.0, 2.0, 1.5), Vector3(6.5, 1.0, 6.3), null, 0.0],
	["xe_om_chu_nam", Vector3(-15.0, 3.2, 6.2), Vector3(-17.5, 1.0, 10.2), null, 0.0],
	["bo_cau_gan", Vector3(-2.6, 11.0, -8.6), Vector3(-4.4, 9.8, -10.8), null, 0.12],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	PlayMode.day = "thu_tu"
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(20)
	var main: Node = current_scene
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.fov = 60
	var thu_tu: ThuTu = main.get_node("ThuTu")
	thu_tu.pigeons.perch_at(thu_tu.san.perch, 1.2)
	main.hud.visible = false
	for s in SHOTS:
		if s[3] != null:
			main.player.global_position = s[3]
			main.player.velocity = Vector3.ZERO
		if thu_tu.thoi_tiet:
			thu_tu.thoi_tiet.ngap(s[4], 0.0)
		cam.global_position = s[1]
		cam.look_at(s[2])
		cam.current = true
		await _wait(60)
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out.path_join("%s.png" % s[0]))
		print("đã chụp ", s[0])
	quit()
