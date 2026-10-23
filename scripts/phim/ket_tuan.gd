extends Node
## Cảnh kết tuần sau Hội mèo (storyboard K2–K8 trên trang C1 Sang duyệt 23/10/2026; K1 ảnh chung chụp ngay
## trên sân khấu, xem Phim.anh_hoi). Bơ đeo huy chương đi về dưới đèn đêm (Mực đi kèm nếu Thứ Bảy đã làm bạn),
## Cô Ba đón ở cửa, xoa đầu, treo huy chương lên bảng "Tuần của Bơ" cạnh 7 tấm ảnh của tuần, Bơ ngủ trong giỏ.
## Rồi bảng tổng kết và chữ chạy (TongKetTuan) trên nền phố đêm, người dân vẫy tay khi tên mình hiện.
## Bấm "Tuần mới": sáng Thứ Hai Bơ vươn vai, Cô Ba gọi, vào tuần mới.
## Giữ phím cách 1 giây: đang ở K2–K6 thì nhảy tới bảng tổng kết; đang ở K8 thì vào tuần mới luôn.

const BoPhim := preload("res://scripts/phim/bo_phim.gd")
const MUC_MODEL := preload("res://assets/models/cho_muc/cho_muc.glb")
## Người ra cửa vẫy tay trong chữ chạy: [id, x, y theo bản phác thảo, tên trong danh sách]
const HANG_XOM := [
	["bena", -3.2, -1.25, "Bé Na"], ["chutu", -2.1, -1.7, "Chú Tư"], ["may", 5.0, -1.25, "Chị Mây"],
	["hung", 6.2, -1.7, "Anh Hùng"], ["basau", 7.4, -1.25, "Bà Sáu"], ["cohai", -4.4, -1.7, "Cô Hai"],
	["chunam", 8.6, -1.7, "Chú Năm"],
]

var p: Phim
var bo: BoPhim
var coba: Nguoi
var muc: Node3D
var muc_anim: AnimationPlayer
var friend := false
var medal: Node3D
var _scene: Node3D            ## bối cảnh đang dựng (gỡ cả cụm khi đổi cảnh)
var _gen := 0                 ## tăng lên khi bỏ qua: đoạn kịch bản cũ đang chờ thì tự dừng
var _phase := "phim"          ## phim | tong_ket | sang | xong
var _hang := {}               ## tên -> Nguoi vẫy tay trong chữ chạy
var _summary: TongKetTuan


static func B(x: float, y: float, z := 0.0) -> Vector3:
	return CanhPhim.B(x, y, z)


static func _yaw(rz: float) -> float:
	return deg_to_rad(rz) + PI


func run(phim: Phim) -> void:
	p = phim
	if Phim.data.is_empty():
		Phim.data = _sample()
	friend = bool(GameState.get_day("muc_ban", false, "thu_bay"))
	bo = BoPhim.new()
	bo.name = "Bo"
	p.add_child(bo)
	bo.dress(_worn())
	coba = Nguoi.make("coba", "dung_yen")
	p.add_child(coba)
	_hang_medal()
	p.music("")
	_story()


## Đoạn K2–K6 (40 s). Bỏ qua thì _gen đổi và đoạn này dừng ở lần chờ kế tiếp.
func _story() -> void:
	var g := _gen
	# K2 0:00–0:06 · đi về dưới đèn đêm, máy đi lùi trước mặt
	_build("pho_dem")
	p.ambience("street")
	coba.visible = false
	bo.place(B(-7.5, -2.0), _yaw(-90))
	bo.go(B(1.2, -2.0), 1.35)
	if friend:
		_muc(B(-7.5, -1.35), 90.0, "di_theo")
	else:
		_muc(B(-4.9, -0.9), 160.0, "ngu_gat")
	p.track(bo, Vector3(2.4, 0.75, 1.5), Vector3(0, 0.35, 0), 32)
	p.fade(0.0, 1.0)
	p.bars(true)
	if friend:
		var tw := p.create_tween()
		tw.tween_property(muc, "position", B(-1.6, -1.35), 4.4)
		tw.tween_callback(func():
			_muc_play("vay_duoi")
			muc.rotation.y = deg_to_rad(180.0))
		tw.tween_interval(1.0)
		tw.tween_callback(func():
			_muc_play("di")
			muc.rotation.y = deg_to_rad(-90.0))
		tw.tween_property(muc, "position", B(-6.0, -1.0), 3.0)
		p.say("Chó Mực", "Gâu! (Mai gặp nha Bơ.)", 2.6)
	elif not await _w(2.2, g):
		return
	if not await _w(3.6 if friend else 1.4, g):
		return
	p.sound("meow_short")
	if not await _w(2.2, g):
		return

	# K3 0:06–0:12 · Lò bánh sáng đèn lồng, Cô Ba vẫy ở cửa
	coba.visible = true
	coba.position = B(2.7, -0.75)
	coba.rotation.y = 0.0
	coba.play("vay", 0.0)
	bo.place(B(-0.5, -2.4), _yaw(-60))
	bo.go(B(2.2, -1.55), 3.4)
	p.cut(B(-0.6, -5.6, 1.5), B(2.4, -1.0, 1.1), 30)
	p.say("Cô Ba", "Về rồi đó hả! Cô nghe nói con được huy chương!", 3.8, "coba_hello")
	if not await _w(4.4, g):
		return
	p.fade(1.0, 0.5)
	if not await _w(0.6, g):
		return

	# K4 0:12–0:19 · trong tiệm, Cô Ba ngồi xổm xoa đầu Bơ
	var tiem := _build("tiem_dem")
	_muc_hide()
	coba.position = B(0.4, -0.1)
	coba.rotation.y = 0.0
	coba.play("xoa_dau", 0.0)
	bo.place(B(0.4, -0.72), _yaw(180))
	bo.pose("ngua_co")
	p.cut(B(1.7, -2.0, 0.9), B(0.4, -0.5, 0.55), 38)
	p.move(B(1.5, -1.75, 0.85), B(0.4, -0.5, 0.55), 38, 6.5)
	p.fade(0.0, 0.5)
	if not await _w(0.6, g):
		return
	p.say("Cô Ba", "Giỏi quá trời. Cả tuần cực rồi ha.", 3.4, "coba_good")
	if not await _w(3.6, g):
		return
	p.sound("meow_short", -4.0)
	if not await _w(2.2, g):
		return

	# K5 0:19–0:27 · treo huy chương lên bảng "Tuần của Bơ", máy lia qua 7 tấm ảnh
	coba.position = B(0.95, 1.45)
	coba.rotation.y = PI
	coba.play("treo_tuong", 0.0)
	bo.place(B(-0.2, 0.55), _yaw(170))
	bo.pose("ngoi_yen")
	p.cut(B(-0.75, -0.6, 1.3), B(-0.15, 1.9, 1.35), 30)
	p.move(B(-0.35, -0.6, 1.25), B(0.85, 1.9, 1.15), 30, 7.0)
	p.say("Cô Ba", "Treo chỗ này cho cả xóm thấy nè.", 3.2, "coba_ok")
	if not await _w(1.2, g):
		return
	# huy chương rời cổ Bơ, lên móc giữa bảng
	if is_instance_valid(medal):
		medal.queue_free()
	var hung := DoHoi.put(tiem["set"], DoHoi.MEDALS[int(Phim.data.get("best", 1))], B(CanhPhim.MEDAL_HOOK.x, CanhPhim.MEDAL_HOOK.y, CanhPhim.MEDAL_HOOK.z))
	DoHoi.anim(hung, "lac")
	p.sound("tag_jingle")
	for i in 7:
		if not await _w(0.8, g):
			return
		p.sound("record", -14.0)
	if not await _w(0.6, g):
		return

	# K6 0:27–0:35 · Bơ leo vào giỏ mây ngủ, Cô Ba tắt đèn treo
	coba.position = B(0.5, 0.2)
	coba.rotation.y = deg_to_rad(-120)
	coba.play("noi", 0.0)
	bo.place(B(-0.35, 0.55), _yaw(-60))
	bo.go(B(-0.95, 0.95), 0.9)
	p.cut(B(-0.65, -0.35, 0.85), B(-1.2, 1.05, 0.2), 34)
	if not await _w(1.0, g):
		return
	bo.hop(B(-1.22, 1.12, 0.07), 0.35, 0.18)
	if not await _w(0.5, g):
		return
	bo.visual.rotation.y = _yaw(20)
	bo.pose("ngu_cuon")
	p.say("Cô Ba", "Ngủ ngon nghe Bơ.", 2.8, "coba_ok")
	if not await _w(2.6, g):
		return
	p.sound("ui_click")
	p.create_tween().tween_property(tiem["den_treo"], "light_energy", 0.0, 0.25)
	if not await _w(2.0, g):
		return
	p.fade(1.0, 1.2)
	if not await _w(1.4, g):
		return
	_credits()


func skip() -> void:
	match _phase:
		"phim":
			_gen += 1
			p.fade(1.0, 0.3)
			await p.get_tree().create_timer(0.35, false).timeout
			_credits()
		"sang":
			_new_week()


## K7 · bảng tổng kết rồi chữ chạy trên nền phố đêm; người dân bước ra cửa vẫy tay khi tên mình hiện.
func _credits() -> void:
	_phase = "tong_ket"
	_gen += 1
	p.allow_skip(false)
	_build("pho_dem")
	p.music("menu")
	coba.visible = true
	coba.position = B(1.6, -0.95)
	coba.rotation.y = 0.0
	coba.play("dung_yen", 0.0)
	_hang["Cô Ba"] = coba
	bo.place(B(2.45, -1.55), _yaw(0))
	bo.pose("ngoi_yen")
	if friend:
		_muc(B(3.25, -1.7), 0.0, "ngoi")
	else:
		_muc_hide()
	for h in HANG_XOM:
		var n := Nguoi.make(h[0], "dung_yen")
		_scene.add_child(n)
		n.position = B(h[1], h[2])
		_hang[h[3]] = n
	p.cut(B(2.0, -10.0, 2.2), B(2.0, -1.0, 1.6), 26)
	p.bars(false)
	p.fade(0.0, 1.0)
	var d: Dictionary = Phim.data
	_summary = TongKetTuan.new()
	_summary.see_through = true
	_summary.medals = d.get("medals", [])
	_summary.neighbour_pages = int(d.get("neighbour_pages", 0))
	_summary.week_stars = int(d.get("week_stars", 0))
	_summary.week_stars_max = int(d.get("week_stars_max", 0))
	_summary.extra_medal = str(d.get("extra_medal", ""))
	_summary.new_week_text = str(d.get("new_week_text", "Tuần mới"))
	_summary.autotest = p.test
	_summary.credit_line.connect(_on_credit_line)
	_summary.new_week.connect(_morning)
	_summary.to_menu.connect(_to_menu)
	p.add_child(_summary)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if p.test:
		await p.get_tree().create_timer(1.0, false).timeout
		_summary._start_credits()
		while not _summary.is_finished():
			await p.get_tree().process_frame
		_morning()


func _on_credit_line(text: String) -> void:
	for who: String in _hang:
		if text.contains(who):
			var n: Nguoi = _hang[who]
			if is_instance_valid(n):
				n.play_for("vay", 3.2)
	if text.contains("Bơ ·"):
		bo.pose("chup_vay")
		p.get_tree().create_timer(3.0, false).timeout.connect(func():
			if _phase == "tong_ket":
				bo.pose("ngoi_yen"))
	if text.contains("Chó Mực") and friend:
		_muc_play("vay_duoi")


## K8 · sáng Thứ Hai tuần mới (6 s): nắng sớm vào tiệm, Bơ vươn vai cạnh giỏ, Cô Ba gọi.
func _morning() -> void:
	if _phase == "sang" or _phase == "xong":
		return
	_phase = "sang"
	if is_instance_valid(_summary):
		_summary.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	p.allow_skip(true)
	p.fade(1.0, 0.4)
	await p.get_tree().create_timer(0.45, false).timeout
	_build("tiem_sang")
	_muc_hide()
	p.ambience("morning")
	coba.position = B(0.55, 0.75)
	coba.rotation.y = deg_to_rad(110)
	coba.play("noi", 0.0)
	bo.place(B(-1.0, 0.5), _yaw(100))
	bo.pose("")
	bo.play_clip("vuon_vai")
	p.cut(B(1.1, -2.4, 1.15), B(-0.4, 0.6, 0.55), 28)
	p.bars(true)
	p.fade(0.0, 0.8)
	await p.get_tree().create_timer(0.8, false).timeout
	if _phase != "sang":
		return
	p.say("Cô Ba", "Dậy chưa Bơ? Tuần mới rồi nè!", 3.4, "coba_hello")
	await p.get_tree().create_timer(3.0, false).timeout
	if _phase != "sang":
		return
	p.title("Tuần mới", 2.2, 100)
	await p.get_tree().create_timer(2.2, false).timeout
	_new_week()


## "Tuần mới" như scripts/chu_nhat.gd: chơi liền các ngày thì vào Thứ Hai tuần sau, chơi từ Chọn màn thì về đó.
func _new_week() -> void:
	if _phase == "xong":
		return
	_phase = "xong"
	GameState.set_global("tuan_moi", true)
	GameState.write_save()
	p.finish(func():
		if PlayMode.continuous:
			PlayMode.go_next_day(p.get_tree())
		else:
			PlayMode.back_to_menu(p.get_tree()))


func _to_menu() -> void:
	if _phase == "xong":
		return
	_phase = "xong"
	p.finish(func():
		if PlayMode.continuous:
			PlayMode.go_home(p.get_tree())
		else:
			PlayMode.back_to_menu(p.get_tree()))


# ---------------------------------------------------------------- dựng cảnh, diễn viên

func _w(secs: float, g: int) -> bool:
	var ok: bool = await p.wait(secs)
	return ok and g == _gen and _phase == "phim"


## Gỡ bối cảnh cũ (cả đèn, môi trường) và dựng bối cảnh mới: "pho_dem" | "tiem_dem" | "tiem_sang".
func _build(which: String) -> Dictionary:
	if is_instance_valid(_scene):
		_scene.free()
	_hang.clear()
	_scene = Node3D.new()
	_scene.name = "Canh"
	p.add_child(_scene)
	var info: Dictionary
	if which == "pho_dem":
		info = CanhPhim.pho(_scene, "dem")
	else:
		info = CanhPhim.tiem(_scene, "sang" if which == "tiem_sang" else "dem")
		CanhPhim.dan_anh(info["board"])
		if which == "tiem_sang":
			var m := DoHoi.put(info["set"], DoHoi.MEDALS[int(Phim.data.get("best", 1))], B(CanhPhim.MEDAL_HOOK.x, CanhPhim.MEDAL_HOOK.y, CanhPhim.MEDAL_HOOK.z))
			DoHoi.anim(m, "lac")
	return info


## Đồ Bơ đang mặc trong tủ đồ (huy chương đeo riêng).
func _worn() -> Dictionary:
	var w := {}
	for s in Outfit.SLOTS:
		w[s[0]] = Outfit.worn(s[0])
	return w


## Huy chương tốt nhất của Hội mèo trên cổ Bơ (như chu_nhat.gd _hang_medal).
func _hang_medal() -> void:
	var skel: Skeleton3D = bo.get("_skel")
	if skel:
		medal = DoHoi.attach(skel, "neck", DoHoi.MEDALS[int(Phim.data.get("best", 1))], DoHoi.NECK)


## Chó Mực bằng model và động tác có sẵn (cho_muc.glb): rz theo bản phác thảo.
func _muc(pos: Vector3, rz: float, clip: String) -> void:
	if muc == null:
		muc = MUC_MODEL.instantiate()
		p.add_child(muc)
		for mi: MeshInstance3D in muc.find_children("*", "MeshInstance3D", true, false):
			if AnhSang.is_compat() and DisplayServer.get_name() != "headless":
				mi.mesh = Tiem._srgb("muc_" + mi.name, mi.mesh)
			var m := StandardMaterial3D.new()
			if mi.name.begins_with("Muc_Sang"):
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			else:
				m.vertex_color_use_as_albedo = true
				m.roughness = 0.85
			mi.material_override = m
		var tag := muc.find_child("Muc_The", true, false)
		if tag:
			tag.visible = friend
		muc_anim = muc.find_child("AnimationPlayer", true, false)
		if muc_anim:
			for a in muc_anim.get_animation_list():
				muc_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	muc.visible = true
	muc.position = pos
	muc.rotation.y = deg_to_rad(rz)
	_muc_play(clip)


func _muc_play(clip: String) -> void:
	if muc_anim and muc_anim.has_animation(clip):
		muc_anim.play(clip, 0.3)


func _muc_hide() -> void:
	if muc:
		muc.visible = false


## Số liệu mẫu khi mở thẳng cảnh (thử, chụp ảnh): như một tuần chơi xong.
static func _sample() -> Dictionary:
	return {"medals": [{"title": "Đua trên mái", "rank": 1, "note": "thử"}, {"title": "Nhảy thùng", "rank": 2, "note": "thử"}],
		"neighbour_pages": 8, "week_stars": 60, "week_stars_max": 75, "extra_medal": "", "new_week_text": "Tuần mới", "best": 1}
