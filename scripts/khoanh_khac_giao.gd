class_name KhoanhKhacGiao
extends Node3D
## Khoảnh khắc giao bánh (gói A3, trang Sang duyệt 23/10: https://claude.ai/artifact/HzaXDEqQVMxVAX6nux3FUv).
## Bơ đặt bánh xong (player.deliver_finished), máy quay lại gần 1,5 giây: khách cảm ơn bằng clip riêng theo tính cách,
## Bơ đáp lại (cho_khen / dui_dau / dap_tay, trễ thì xin_loi), sao bật trên đầu khách rồi bay về góc màn hình,
## xu boa bay vào túi Bơ. Bấm phím nào, bấm chuột hay nút tay cầm là bỏ qua ngay; sao, tiền boa vẫn cộng như cũ
## (Scoring.order_done chấm từ lúc bấm giao, ở đây chỉ diễn lại cho thấy, không đổi số).
## Đồng hồ đơn đã dừng vì đơn xong, nên khoảnh khắc này không làm mất giờ.
##
## Cài đặt "Khoảnh khắc giao bánh" (GameSettings "khoanh_khac"): 0 Đầy đủ, 1 Ngắn (không lại gần, chỉ sao + câu
## nói 0,8 s), 2 Tắt. Lần thứ hai cùng khách trong ngày tự chạy Ngắn. Không chạy: đơn lấy đồ mang về lò, đơn có
## cảnh riêng (đám giỗ, cảnh Thứ Năm), đơn cuối ngày (bảng kết quả hiện ngay), chạy thử --autotest (bot I1).
## main.gd chỉ thêm node này; tiếng sao, xu, lời cảm ơn do node phát (sound_director nhường khi sap_dien()).

const SAO_VANG := preload("res://assets/models/giao_banh/sao_vang.glb")
const SAO_TRONG := preload("res://assets/models/giao_banh/sao_trong.glb")
const XU_BOA := preload("res://assets/models/giao_banh/xu_boa.glb")

const DAI := 1.5          ## giây, bản đầy đủ
const NGAN := 0.8         ## giây, bản ngắn
const VAO := 0.25         ## máy quay lại gần
const RA := 0.2           ## máy quay về góc chơi
const SAO_CACH := 0.27    ## khoảng cách giữa hai sao (m)
const SAO_CO := 1.5       ## sao 16 cm phóng lên cho dễ thấy trong khung hai người
const FOV := 50.0
const SAO_TREN := 0.42    ## sao nằm trên gốc xương đầu khách
const CHO_TOI_DA := 2.2   ## đơn đã chấm mà chưa thấy deliver_finished thì chạy luôn sau chừng này giây
const BO_QUA_KIEU := ["errand", "errand_nhe", "errand_da"]
const CANH_RIENG := ["scene", "gio_table"]

## Khách → (clip cảm ơn của khách trong tools/nguoi_game.py A3, clip đáp lại của Bơ, câu nói).
const KHACH := {
	"coba": ["xoa_dau", "dui_dau", "Ngoan quá, Bơ của cô!"],
	"chutu": ["day_kinh", "cho_khen", "Ừm. Đúng giờ. Được lắm."],
	"bena": ["om_banh", "cho_khen", "Bánh còn nóng nè! Cảm ơn Bơ!"],
	"may": ["nang_ly", "cho_khen", "Cụng ly nè, nhân viên giỏi nhất phố!"],
	"hung": ["dap_tay", "dap_tay", "Đập tay cái coi! Ngon lành!"],
	"basau": ["xoa_dau", "dui_dau", "Con mèo ngoan của bà."],
	"chunam": ["chao_nghiem", "cho_khen", "Báo cáo: nhận đủ bánh!"],
	"cohai": ["tha_xu", "cho_khen", "Boa thêm nè, đừng nói Cô Ba nha!"],
	"ongbay": ["vuot_rau", "cho_khen", "Ổ bánh này… nước đi hay."],
	"ongtam": ["quat_bo", "cho_khen", "Quạt cho mát nè con."],
}
const CAU_TRE := "Hơi trễ chút, không sao, bánh vẫn ngon!"
const CAU_CHUNG := "Cảm ơn Bơ nha!"

var main: Node
var player: CharacterBody3D
var autotest := false

var _cho := {}            ## đơn vừa chấm, đợi Bơ diễn xong động tác giao
var _cho_t := 0.0
var _dang := false        ## đang diễn
var _t := 0.0
var _dai := DAI
var _ngan := false
var _da_gap := {}         ## id khách đã có khoảnh khắc trong ngày
var _cam: Camera3D
var _cam_cu: Camera3D
var _tu: Transform3D
var _toi: Transform3D
var _sao: Array[Node3D] = []
var _sao_goc: Array[Vector3] = []
var _xu: Node3D
var _xu_tu := Vector3.ZERO
var _chu: Label3D
var _boa: Label3D
var _khach: Array[Nguoi] = []
var _dau := Vector3.ZERO  ## đỉnh đầu khách chính
var _bay := false         ## sao đang bay về góc màn hình
var _xu_xong := false
var _bo_qua: Array[RID] = []   ## tia kiểm tra tường chắn bỏ qua Bơ và thân khách
var _an: Array[Node3D] = []     ## chữ 3D gần chỗ giao (tên khách, [E] Đưa bánh) tạm ẩn cho khung hình gọn


func _init() -> void:
	name = "KhoanhKhacGiao"


func _ready() -> void:
	add_to_group("khoanh_khac_giao")
	main = get_parent()
	player = main.player
	autotest = "--autotest" in OS.get_cmdline_user_args()
	main.order_delivered.connect(_on_delivered)
	player.deliver_finished.connect(func(_kind: String) -> void: _bat_dau())


## Cài đặt đang chọn: 0 đầy đủ, 1 ngắn, 2 tắt.
static func che_do() -> int:
	return clampi(int(GameSettings.get_value("khoanh_khac")), 0, 2)


## sound_director hỏi ngay lúc chấm đơn: có khoảnh khắc thì tiếng sao, xu, lời cảm ơn để node này phát đúng nhịp.
func sap_dien() -> bool:
	return not _cho.is_empty()


func _on_delivered(index: int, order: Dictionary) -> void:
	if autotest or che_do() == 2:
		return
	if str(order.get("kind", "")) in BO_QUA_KIEU or str(order.get("delivery", "")) in BO_QUA_KIEU + CANH_RIENG:
		return
	if index >= PlayMode.last_order(main.orders.size()) or main.state != main.State.PLAY:
		return  # đơn cuối: bảng kết quả (hoặc cảnh riêng của ngày) hiện ngay
	if _dang:
		_ket_thuc()
	var row: Dictionary = main.score_rows[-1] if not main.score_rows.is_empty() else {}
	_cho = {"index": index, "order": order, "stars": int(row.get("stars", 3)), "tip": int(row.get("tip", 0)),
		"late": bool(row.get("late", false)), "new_best": bool(row.get("new_best", false)) and float(row.get("best_time", -1.0)) >= 0.0}
	_cho_t = CHO_TOI_DA


func _process(delta: float) -> void:
	if not _cho.is_empty() and not _dang:
		_cho_t -= delta
		if _cho_t <= 0.0:
			_bat_dau()
	if _dang:
		_dien(delta)


func _bat_dau() -> void:
	if _cho.is_empty() or _dang:
		return
	var c := _cho
	_cho = {}
	if main.state != main.State.PLAY or main.get("_leaving"):
		return
	var who := str(c.order.get("who", ""))
	_khach = _tim_khach(who, int(c.index))
	var chinh: Nguoi = _khach[0] if not _khach.is_empty() else null
	var kid := _goc(chinh.id) if chinh else ""
	_ngan = che_do() == 1 or (kid != "" and _da_gap.has(kid))
	if kid != "":
		_da_gap[kid] = true
	_dai = NGAN if _ngan else DAI
	_t = 0.0
	_dang = true
	_bay = false
	_xu_xong = c.tip <= 0
	_dau = _dinh_dau(chinh) if chinh else Vector3(c.order.pos) + Vector3(0, 1.75, 0)
	_bo_qua = [player.get_rid()]
	for n in _khach:
		for co: CollisionObject3D in n.find_children("*", "CollisionObject3D", true, false):
			_bo_qua.append(co.get_rid())
	if not _ngan:
		_an_chu()
	if main.get("deliveries") and "bao_ha" in main.deliveries:
		main.deliveries.bao_ha = true
	var late: bool = c.late

	# Khách: clip cảm ơn (người áo mưa Thứ Tư chưa có clip riêng thì "vui")
	for n in _khach:
		var k: Array = KHACH.get(_goc(n.id), [])
		var clip: String = k[0] if not k.is_empty() and n.anim and n.anim.has_animation(k[0]) else "vui"
		if clip == "vui":
			n.play_for("vui", _dai + 0.4)
		else:
			n.play_once(clip, "vui", 1.2)

	# Bơ: quay về phía khách, ngồi đáp lại; bản ngắn thì Bơ đi tiếp được ngay
	if not _ngan:
		player.hold(_dai)
		var to := _dau - player.global_position
		if Vector2(to.x, to.z).length() > 0.2 and "_face_yaw" in player:
			player._face_yaw = atan2(-to.x, -to.z)
		var bo_clip := "xin_loi" if late else str(KHACH.get(kid, ["", "cho_khen"])[1])
		if player.has_method("has_clip") and player.has_clip(bo_clip):
			player.play_clip(bo_clip)
		_vao_may()
	# Khách trên ban công thì máy đang chơi không thấy đầu khách: sao, câu nói hiện trên đầu Bơ
	if _dau.y - player.global_position.y > 2.3:
		_dau = player.global_position + Vector3.UP * 0.75

	# Sao: đủ 3 ô, ô không đạt là sao trống
	var right := Vector3.RIGHT
	var cam := get_viewport().get_camera_3d()
	if _cam:
		right = _toi.basis.x  # hàng sao nằm ngang theo máy lúc đã lại gần
	elif cam:
		right = cam.global_transform.basis.x
	right = Vector3(right.x, 0, right.z).normalized() if Vector2(right.x, right.z).length() > 0.01 else Vector3.RIGHT
	for i in 3:
		var s: Node3D = (SAO_VANG if i < int(c.stars) else SAO_TRONG).instantiate()
		_tat_bong(s)
		add_child(s)
		var p := _dau + Vector3.UP * SAO_TREN + right * (i - 1) * SAO_CACH + Vector3.UP * (0.05 if i == 1 else 0.0)
		s.global_position = p
		s.scale = Vector3.ONE * 0.01
		_sao.append(s)
		_sao_goc.append(p)
		var tw := s.create_tween()
		tw.tween_interval(0.12 + i * 0.08)
		tw.tween_property(s, "scale", Vector3.ONE * 1.2 * SAO_CO, 0.17).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale", Vector3.ONE * SAO_CO, 0.08)
		if i < int(c.stars):
			tw.parallel().tween_callback(Sound.play.bind("star_%d" % (i + 1))).set_delay(0.0)

	# Câu nói của khách, giọng ú ớ theo câu
	var cau := CAU_TRE if late else (str(KHACH[kid][2]) if KHACH.has(kid) else CAU_CHUNG)
	_chu = _nhan(cau, 34, UiTheme.INK, UiTheme.PAPER)
	_chu.global_position = _dau + Vector3.UP * (SAO_TREN + 0.3)
	_chu.modulate.a = 0.0
	create_tween().tween_property(_chu, "modulate:a", 1.0, 0.15).set_delay(0.2)
	if who != "" and not GiongUO.dang_noi(who):
		get_tree().create_timer(0.2).timeout.connect(func(): GiongUO.noi(who, cau))
	if int(c.stars) == 3:
		get_tree().create_timer(0.35).timeout.connect(Sound.play.bind("meow"))
	if c.new_best:
		get_tree().create_timer(0.9).timeout.connect(Sound.play.bind("record"))

	# Xu boa: từ tay khách bay vòng cung vào túi Bơ, số boa hiện cạnh túi
	if int(c.tip) > 0:
		_xu = XU_BOA.instantiate()
		_tat_bong(_xu)
		add_child(_xu)
		_xu_tu = _tay_khach(chinh, int(c.index))
		_xu.global_position = _xu_tu
		_xu.visible = false
		_boa = _nhan("+" + main.call("_money", int(c.tip)), 30, UiTheme.ON_CRUST, UiTheme.AMBER)
		_boa.visible = false


## Mỗi khung hình: sao xoay, nhấp nhô, quay mặt về máy; xu bay; hết giờ thì sao bay về góc màn hình.
func _dien(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	if _cam and _cam.current:
		var k := clampf(_t / VAO, 0.0, 1.0)
		_cam.global_transform = _tu.interpolate_with(_toi, k * k * (3.0 - 2.0 * k))
	for i in _sao.size():
		var s := _sao[i]
		if not is_instance_valid(s):
			continue
		if not _bay:
			var spin := clampf((_t - 0.12 - i * 0.08) / 0.25, 0.0, 1.0) * TAU if s.scene_file_path == SAO_VANG.resource_path else 0.0
			s.global_position = _sao_goc[i] + Vector3.UP * sin(_t * 5.0 + i) * 0.02
			if cam:
				_nhin_may(s, cam, spin)
	if _chu and cam:
		_chu.global_position = _dau + Vector3.UP * (SAO_TREN + 0.3)
	# Xu: 0,6 s → 0,95 s, cung cao 0,35 m, lật hai vòng; "cạch" khi rơi vào túi
	if _xu and is_instance_valid(_xu):
		var t0 := 0.45 if _ngan else 0.6
		var k := (_t - t0) / 0.35
		if k >= 0.0 and k <= 1.0:
			_xu.visible = true
			var to := player.global_position + Vector3(0, 0.32, 0)
			_xu.global_position = _xu_tu.lerp(to, k) + Vector3.UP * sin(k * PI) * 0.35
			_xu.rotation = Vector3(k * TAU * 2.0, k * PI, 0)
		elif k > 1.0 and not _xu_xong:
			_xu_xong = true
			_xu.visible = false
			Sound.play("coin")
			if _boa:
				_boa.visible = true
				_boa.global_position = player.global_position + Vector3(0.25, 0.75, 0)
				var tw := _boa.create_tween()
				tw.tween_property(_boa, "global_position", _boa.global_position + Vector3.UP * 0.2, 0.6)
				tw.parallel().tween_property(_boa, "modulate:a", 0.0, 0.25).set_delay(0.35)
	# Sao bay về góc trên trái (ô sao trên HUD) rồi tắt
	var bay_luc := _dai - 0.3
	if not _bay and _t >= bay_luc:
		_bay = true
		_sao_bay(cam)
		if _chu:
			create_tween().tween_property(_chu, "modulate:a", 0.0, 0.2)
	if _t >= _dai:
		_ket_thuc()


func _unhandled_input(event: InputEvent) -> void:
	if not _dang or _t < 0.1:
		return
	var bam: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if bam:
		_ket_thuc()


## Kết thúc (hết giờ hoặc bị bỏ qua): dọn sao, xu, chữ; máy về góc chơi; Bơ đi tiếp được.
func _ket_thuc() -> void:
	if not _dang:
		return
	_dang = false
	if not _xu_xong:
		Sound.play("coin")
	for s in _sao:
		if is_instance_valid(s):
			s.queue_free()
	_sao.clear()
	_sao_goc.clear()
	for n in [_xu, _chu, _boa]:
		if n and is_instance_valid(n):
			n.queue_free()
	_xu = null
	_chu = null
	_boa = null
	if not _ngan:
		player._stun = 0.0
		if player.has_method("stop_clip") and str(player.get("clip")) in ["cho_khen", "dui_dau", "dap_tay", "xin_loi"]:
			player.stop_clip()
	_ra_may()
	for n in _an:
		if is_instance_valid(n):
			n.visible = true
	_an.clear()
	if main.get("deliveries") and "bao_ha" in main.deliveries:
		main.deliveries.bao_ha = false


## Ẩn tạm chữ 3D quanh chỗ giao (biển tên khách, gợi ý phím) trong lúc máy lại gần.
func _an_chu() -> void:
	var giua := player.global_position.lerp(_dau, 0.5)
	for l: Label3D in main.find_children("*", "Label3D", true, false):
		if l.visible and not is_ancestor_of(l) and l.global_position.distance_to(giua) < 7.0:
			l.visible = false
			_an.append(l)


# ---------------------------------------------------------------- máy quay

## Khung hai người: thấp ngang ngực khách, lệch 3/4 về phía Bơ, cách 2,2–4,5 m; có tường chắn thì đứng phía kia.
## Khách trên cao (Bé Na ở ban công tầng 3): giữ góc máy đang chơi. Chỗ Bơ đứng là hành lang hẹp dưới ban công,
## máy dưới đất thì sàn ban công che mặt Bé Na, máy trên ban công thì Bơ chỉ còn một chấm (đã thử 23/10).
func _vao_may() -> void:
	_cam_cu = get_viewport().get_camera_3d()
	if _cam_cu == null:
		return
	var bo := player.global_position + Vector3.UP * 0.3
	var h := _dau
	if h.y - bo.y > 2.0:
		return
	var flat := Vector3(h.x - bo.x, 0, h.z - bo.z)
	if flat.length() < 0.3:
		flat = -_cam_cu.global_transform.basis.z
		flat.y = 0
	var dir := flat.normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var cu := _cam_cu.global_position
	if side.dot(cu - bo) < 0.0:
		side = -side  # đứng cùng phía với máy đang chơi cho khỏi đảo hướng
	# Khung phải chứa từ chân Bơ tới hàng sao trên đầu khách
	var top := h + Vector3.UP * (SAO_TREN + 0.2)
	var nhin := bo.lerp(top, 0.5) - Vector3.UP * 0.05
	var cao := top.y - bo.y + 0.4
	var xa := clampf(maxf(cao * 0.5 / tan(deg_to_rad(FOV * 0.5)) * 1.15, flat.length() * 1.3 + 1.2), 2.2, 4.5)
	var thu: Array[Vector3] = []
	for v in [side + dir * 0.15, -side + dir * 0.15, side * 0.85 - dir * 0.45, -side * 0.85 - dir * 0.45, -dir + side * 0.25, -dir - side * 0.25]:
		thu.append(nhin + v.normalized() * xa + Vector3.UP * 0.15)
	for k in thu.size():  # không chỗ nào thoáng thì thử cao hơn 1 m, nhìn chéo xuống qua xe, quầy
		thu.append(thu[k] + Vector3.UP * 1.0)
	for r in [2.2, 1.4]:  # hẻm hẹp: thử vòng quanh Bơ mỗi 45°, gần dần
		for k in 8:
			thu.append(bo + Vector3.FORWARD.rotated(Vector3.UP, k * PI / 4.0) * r + Vector3.UP * 0.9)
	# Chỗ đặt máy: ưu tiên chỗ thấy cả Bơ lẫn đầu khách, không lọt trong tường; không có thì chỗ thấy Bơ
	# (khách trên ban công bị sàn ban công che đầu, sao và câu nói vẫn hiện trên cao); không có nữa thì
	# lùi máy về sát trước vật chắn trên đường từ Bơ ra chỗ thoáng nhất.
	var cho := Vector3.INF
	var thay_bo := Vector3.INF
	var tot := -1.0
	var lui := thu[0]
	for p in thu:
		if _trong_vat(p):
			continue
		var c1 := _chan(p, bo)
		var c2 := _chan(p, h)
		if c1 < 0.0 and c2 < 0.0:
			cho = p
			break
		if c1 < 0.0 and thay_bo == Vector3.INF:
			thay_bo = p
		var c3 := _chan(bo, p)
		var diem := 100.0 if c3 < 0.0 else c3
		if diem > tot:
			tot = diem
			lui = p if c3 < 0.0 else bo + (p - bo).normalized() * maxf(c3 - 0.25, 0.8)
	if cho == Vector3.INF:
		cho = thay_bo if thay_bo != Vector3.INF else lui
	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.near = 0.05
	_cam.far = _cam_cu.far
	add_child(_cam)
	_tu = _cam_cu.global_transform
	_toi = Transform3D(Basis(), cho).looking_at(nhin, Vector3.UP)
	_cam.global_transform = _tu
	_cam.make_current()


func _ra_may() -> void:
	if _cam == null:
		return
	var cam := _cam
	_cam = null
	if _cam_cu == null or not is_instance_valid(_cam_cu):
		cam.queue_free()
		return
	var tu := cam.global_transform
	var cu := _cam_cu
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		if is_instance_valid(cu):
			cam.global_transform = tu.interpolate_with(cu.global_transform, k * k * (3.0 - 2.0 * k)), 0.0, 1.0, RA)
	tw.tween_callback(func() -> void:
		if is_instance_valid(cu):
			cu.make_current()
		cam.queue_free())


## Điểm p nằm lọt trong khối va chạm (tường, mái, quầy).
func _trong_vat(p: Vector3) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = p
	q.exclude = _bo_qua
	return not get_world_3d().direct_space_state.intersect_point(q, 1).is_empty()


## Khoảng cách tới vật chắn đầu tiên từ a tới b (âm: không có gì chắn).
func _chan(a: Vector3, b: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = _bo_qua
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return a.distance_to(hit.position) if hit else -1.0


# ---------------------------------------------------------------- khách, sao, xu

## Người nhận đơn: khách đơn trong deliveries (nếu có), không thì người dân cùng tên đứng gần Bơ nhất.
## "Ông Bảy, Ông Tám" trả cả hai ông.
func _tim_khach(who: String, index: int) -> Array[Nguoi]:
	var out: Array[Nguoi] = []
	var ids := []
	for id in Nguoi.NAMES:
		if str(Nguoi.NAMES[id]) in who.split(", "):
			ids.append(id)
	var d = main.get("deliveries")
	if d and d.has_method("person"):
		var n: Nguoi = d.person(index)
		if n and is_instance_valid(n) and (ids.is_empty() or n.id in ids):
			out.append(n)
	var best := {}
	for n: Nguoi in get_tree().get_nodes_in_group(Nguoi.GROUP):
		if not (n.id in ids) or n in out or n.is_queued_for_deletion():
			continue
		var dd := n.global_position.distance_to(player.global_position)
		var g := _goc(n.id)
		if dd < 8.0 and (not best.has(g) or dd < best[g][0]):
			best[g] = [dd, n]
	for g in best:
		out.append(best[g][1])
	return out


static func _goc(id: String) -> String:
	return id.trim_suffix("_mua").trim_suffix("_tb")


func _dinh_dau(n: Nguoi) -> Vector3:
	if n.skeleton:
		var b := n.skeleton.find_bone("head")
		if b >= 0:
			return n.skeleton.global_transform * n.skeleton.get_bone_global_pose(b).origin + Vector3.UP * 0.22
	return n.global_position + Vector3.UP * 1.7


func _tay_khach(n: Nguoi, index: int) -> Vector3:
	var d = main.get("deliveries")
	if n and d and d.has_method("person") and d.person(index) == n and d.has_method("hand_point"):
		return d.hand_point(index)
	if n and n.skeleton:
		var hand := "hand.L" if _goc(n.id) == "cohai" else "hand.R"
		var b := n.skeleton.find_bone(hand)
		if b >= 0:
			return n.skeleton.global_transform * n.skeleton.get_bone_global_pose(b).origin
	return _dau + Vector3.UP * 0.2


func _sao_bay(cam: Camera3D) -> void:
	for i in _sao.size():
		var s := _sao[i]
		if not is_instance_valid(s):
			continue
		var to := s.global_position + Vector3.UP * 0.6
		if cam:
			var vp := get_viewport().get_visible_rect().size
			to = cam.project_position(Vector2(vp.x * (0.1 + i * 0.03), vp.y * 0.08), 1.2)
		var tw := s.create_tween()
		tw.tween_property(s, "global_position", to, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(i * 0.03)
		tw.parallel().tween_property(s, "scale", Vector3.ONE * 0.15, 0.28).set_delay(i * 0.03)


## Sao quay mặt về máy, xoay quanh trục đứng một vòng lúc bật.
static func _nhin_may(s: Node3D, cam: Camera3D, spin: float) -> void:
	var to := cam.global_position - s.global_position
	to.y = 0
	if to.length() < 0.01:
		return
	var yaw := atan2(to.x, to.z) + spin
	s.global_rotation = Vector3(0, yaw, 0)


func _nhan(text: String, size: int, color: Color, outline: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UiTheme.font("bold")
	l.font_size = size
	l.pixel_size = 0.0011
	l.modulate = color
	l.outline_modulate = outline
	l.outline_size = 14
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true  # cùng cỡ chữ trên màn hình dù khách ở gần hay trên ban công
	l.width = 900.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(l)
	return l


static func _tat_bong(n: Node) -> void:
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
