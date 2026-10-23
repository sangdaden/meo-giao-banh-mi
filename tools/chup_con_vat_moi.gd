extends SceneTree
## Chụp con vật mới V1–V6 (scripts/con_vat_moi/) ở chỗ đặt, để soát vị trí, cỡ và động tác.
## Chạy: xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 -s tools/chup_con_vat_moi.gd -- <thư_mục_ra>

var out := "user://chup_con_vat_moi"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameState.use_test_save("user://luu_game_chup_con_vat_moi.cfg")
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _shot(name: String, frames := 30) -> void:
	await _wait(frames)
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % name))
	print("đã chụp ", name)


func _load(day: String, scene := "res://scenes/main.tscn") -> Node:
	PlayMode.day = day
	GameState.day = day
	change_scene_to_file(scene)
	await _wait(40)
	var s: Node = current_scene
	if s.get("hud"):
		s.hud.visible = false
	cam = Camera3D.new()
	s.add_child(cam)
	cam.current = true
	cam.fov = 55
	return s


func _look(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)


func _run() -> void:
	# Thứ Ba: gà sổ bu, thau cá
	var m := await _load("thu_ba")
	var cv: Node = m.find_child("ConVatMoi", true, false)
	var ga: Node = cv.parts.ga
	_look(ga.BU + Vector3(0.6, 1.6, -3.2), ga.BU + Vector3(0, 0.1, -1.2))
	await _shot("thu_ba_ga_so_bu")
	_look(ga.BU + Vector3(1.0, 0.5, -1.2), ga.HEN_AT + Vector3(0, 0.2, 0))
	await _shot("thu_ba_ga_me_gan", 10)
	var p: CharacterBody3D = m.player
	for c in ga.chicks:
		p.global_position = c.pos + Vector3(0.3, 0.1, 0)
		await _wait(4)
	p.global_position = ga.BU + Vector3(1.6, 0.1, -1.8)
	await _wait(40)
	_look(p.global_position + Vector3(2.0, 1.4, -1.5), p.global_position + Vector3(-0.4, 0.1, 0))
	await _shot("thu_ba_ga_theo_bo", 5)
	var thau: Node3D = cv.parts.thau_ca
	_look(thau.global_position + Vector3(0.5, 0.9, 0.9), thau.global_position)
	await _shot("thu_ba_thau_ca")
	thau.on_called(thau.global_position)
	await _shot("thau_ca_quay_duoi", 8)
	# Thứ Hai: bể cá quầy cà phê Mây
	m = await _load("thu_hai")
	var be: Node3D = m.find_child("BeCa", true, false)
	_look(be.global_position + Vector3(0.0, 0.5, -1.4), be.global_position + Vector3(0, 0.12, 0))
	await _shot("thu_hai_be_ca")
	_look(be.global_position + Vector3(-1.2, 0.9, -3.5), be.global_position)
	await _shot("thu_hai_be_ca_xa", 10)
	# Thứ Tư: vịt lúc ngập, Bơ cưỡi vịt
	m = await _load("thu_tu")
	m.find_child("ThoiTiet", true, false).ngap(0.2, 0.0)
	await _wait(10)
	var vit: Node = m.find_child("DanVit", true, false)
	var lead: Node3D = vit.ducks[0]
	_look(lead.global_position + Vector3(-1.6, 1.0, 2.0), lead.global_position)
	await _shot("thu_tu_dan_vit", 10)
	p = m.player
	for i in 4:
		p.global_position = lead.global_position + Vector3(0, 0.45, 0)
		p.velocity = Vector3.ZERO
		await physics_frame
	await _wait(30)
	_look(lead.global_position + Vector3(-1.3, 0.9, 1.6), lead.global_position + Vector3(0, 0.25, 0))
	await _shot("thu_tu_bo_cuoi_vit", 3)
	# Thứ Bảy: bướm công viên
	m = await _load("thu_bay")
	var bb: Node = m.find_child("BuomBay", true, false)
	var b = bb.bugs[0]
	_look(b.pos + Vector3(-0.35, 0.15, -0.35), b.pos)
	await _shot("thu_bay_buom", 1)
	var dd = bb.bugs[3]
	_look(dd.pos + Vector3(-0.35, 0.15, -0.35), dd.pos)
	await _shot("thu_bay_chuon_chuon", 1)
	_look(Vector3(-30.0, 3.0, 11.0), Vector3(-35.0, 0.3, 17.0))
	await _shot("thu_bay_cong_vien", 5)
	p = m.player
	p.global_position = b.home + Vector3(0.5, 0.1, 0)
	await _wait(10)
	bb.on_called(p.global_position)
	var guest = bb.bugs.filter(func(x): return x.state == "tham")[0]
	for i in 200:
		await physics_frame
		if guest.pos.distance_to(p.global_position + bb.HEAD) < 0.06:
			break
	_look(p.global_position + Vector3(0.45, 0.6, 0.55), p.global_position + Vector3(0, 0.4, 0))
	await _shot("thu_bay_buom_tren_dau_bo", 3)
	# Chung cư: thạch sùng chỉ bậc A
	var s := await _load("thu_nam", "res://scenes/chung_cu.tscn")
	p = s.player
	p.global_position = Vector3(-3.0, 4.0, -2.6)
	await _wait(int((ThachSung.HESITATE + 2.5) * 60))
	var ts: ThachSung = s.find_child("ThachSung", true, false)
	_look(Vector3(-2.2, ts._wall.x + 0.3, ts._wall.y + 0.6), Vector3(0, ts._wall.x, ts._wall.y))
	await _shot("chung_cu_thach_sung_gan", 3)
	_look(Vector3(-4.5, 6.0, 2.0), Vector3(0, 4.8, -2.6))
	await _shot("chung_cu_thach_sung_xa", 3)
	# Bếp: chuột Tí (góc máy chơi, rồi cận cảnh)
	var k := await _load("thu_hai", "res://scenes/kitchen.tscn")
	cam.current = false
	k.hud.visible = true
	await _shot("bep_chuot_ti_goc_choi")
	cam.current = true
	k.hud.visible = false
	_look(ChuotTi.HOME + Vector3(0.7, 0.35, 0.7), ChuotTi.HOME + Vector3(0, 0.05, 0))
	await _shot("bep_chuot_ti_gan", 5)
	k.player.global_position = ChuotTi.HOME + Vector3(0.6, 0.05, 0.2)
	await _wait(25)
	await _shot("bep_chuot_ti_chao", 3)
	quit()
