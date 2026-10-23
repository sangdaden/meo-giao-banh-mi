class_name ChuNhat
extends Node3D
## Chủ Nhật · Hội mèo khu phố (gói việc thiet-ke-man/goi-viec-chu-nhat.md). Mèo hội G10 (MeoNpc), đồ sân hội G11
## (DoHoi, assets/models/chu_nhat; bố trí theo thiet-ke-man/goi-phac-thao/g11-hoi-meo/BAN-GIAO.md).
## main.gd chỉ cần add_child(preload("res://scripts/chu_nhat.gd").new()); ngày khác tự gỡ.
## - Sáng (trời "pho_sang"): một đơn không tính giờ (days.gd "time": 0): Bơ ngậm khay bánh mì mini từ lò
##   tới Bà Mướp ở sân khấu công viên khối 4. Các mèo hội đã tới phơi nắng quanh công viên.
## - Đơn xong thì main giao lại (main.hand_off): tối Hội mèo (trời "pho_toi"), giăng đèn lồng, sân khấu,
##   cổng hội. Mực gác cổng nếu Thứ Bảy đã làm bạn (thu_bay/muc_ban), chưa thì nằm ngủ ngoài cổng.
## - 5 trò thi (scripts/hoi_meo/*.gd), chơi theo thứ tự hoặc chọn trên bảng. Không có thua: hạng 1–3 hoặc
##   "tham gia", ai cũng có huy chương.
## - Kết tuần: Bà Mướp trao huy chương, Cô Ba và hàng xóm ra xem, rồi màn tổng kết (TongKetTuan),
##   chữ chạy cuối game, mở cờ "tuan_moi" trong GameState.
## Autotest: -- --autotest --ngay=chu_nhat: bot chơi đủ 5 trò ở Thong thả, tới màn tổng kết thì in AUTOTEST CHU_NHAT OK.

const DAY := "chu_nhat"
const STAGE := Vector3(-33.0, 0, 22.6)        ## giữa sân khấu G11 (quay về bắc), sàn cao STAGE_H
const STAGE_H := 0.45
const STAGE_SIZE := Vector2(3.0, 1.8)
const SEAT_Y := 0.88                           ## mặt nệm thùng Bà Mướp ngồi
const CRATE := Vector3(0, 0, 0.4)              ## thùng ngồi so với giữa sân khấu (nửa sau sàn)
const POSE_SPOT := Vector3(0, 0, -0.45)        ## chỗ Bơ tạo dáng, trao huy chương: nửa trước sàn
const TRAY_DROP := Vector3(-33.0, 0, 21.0)    ## chỗ giao khay bánh sáng (trước sân khấu)
const GATE := Vector3(-33.0, 0, 5.6)          ## cổng hội "HỘI MÈO KHU PHỐ" mé bắc công viên
const MUC_SPOT := Vector3(-30.9, 0, 4.9)
const MAT := Vector3(-33.0, 0, 19.6)           ## chiếu mèo trước sân khấu (gối cao 0,08)
const BENCHES := [Vector3(-34.7, 0, 17.6), Vector3(-31.3, 0, 17.6), Vector3(-34.7, 0, 16.2), Vector3(-31.3, 0, 16.2)]
const CRATES := Vector3(-40.5, 0, 12.0)        ## chồng thùng (trò 2), quay 90°
const RECORD_BOARD := Vector3(-36.5, 0, 7.4)   ## bảng kỷ lục, quay 200°
## Chỗ xem của mèo khi không thi: 4 con trên chiếu, 3 con hai bên
const WATCH := {
	"tuyet": Vector3(-33.4, 0.08, 19.85), "sua": Vector3(-32.6, 0.08, 19.85), "mun": Vector3(-33.4, 0.08, 19.35),
	"gung": Vector3(-32.6, 0.08, 19.35), "lac": Vector3(-34.6, 0, 20.4), "mit": Vector3(-35.4, 0, 21.0), "bot": Vector3(-31.0, 0, 20.6),
}
## Sáng: mèo hội tới sớm, nằm phơi nắng quanh công viên
const MORNING := {
	"mit": Vector3(-29.0, 0, 13.0), "bot": Vector3(-27.5, 0, 17.5), "mun": Vector3(-40.5, 0, 22.0),
	"tuyet": Vector3(-36.0, 0, 21.0), "lac": Vector3(-30.0, 0, 20.6), "gung": Vector3(-24.5, 0, 11.0), "sua": Vector3(-38.0, 0, 18.0),
}
## Hàng xóm xem hội (đề xuất 2 G11): Chú Tư, Bà Sáu, Chú Năm ngồi băng ghế; Cô Ba, Ông Chín, Bé Na đứng cạnh
## [id, vị trí, quay (rad), động tác]. Người ngồi: gốc ở đất, mặt ghế 0,45 (Bà Sáu ghế 0,42 nên nâng 0,03)
const AUDIENCE := [
	["chutu", Vector3(-35.25, 0, 17.62), 0.0, "dung_yen"], ["basau", Vector3(-34.7, 0.03, 17.62), 0.0, "dung_yen"],
	["chunam", Vector3(-31.3, 0, 17.62), 0.0, "dung_yen"], ["coba", Vector3(-36.3, 0, 17.2), 0.3, "vui"],
	["xemco", Vector3(-29.8, 0, 17.3), -0.3, "xem"], ["bena", Vector3(-30.2, 0, 16.4), -0.2, "vui"],
]
const CONTESTS := ["dua_mai", "nhay_thung", "tron_tim", "tiep_suc", "trang_phuc"]
const CONTEST_COLORS := [Color("#C8412F"), Color("#E8913A"), Color("#4F7FA8"), Color("#3FA39A"), Color("#D7A9C4")]

var main: Node3D
var player: CharacterBody3D
var hud: Node
var san: SanThuong
var cats := {}                ## id -> MeoNpc
var contests: Array[TroThi] = []
var medals := {}              ## id trò -> {title, rank, note}
var phase := "sang"           ## sang | hoi | trao | tong_ket
var current := -1
var _decor: Node3D
var _stage: Node3D
var _record_board: Node3D
var _medal: Node3D
var _board: CanvasLayer
var _fade: ColorRect
var _summary: TongKetTuan
var _autotest := false
var _ceremony_t := 0.0
var _board_t := 0.0


func _ready() -> void:
	name = "ChuNhat"
	main = get_parent()
	var day: Dictionary = main.get("day") if main.get("day") != null else {}
	if day.get("id", "") != DAY:
		queue_free()
		return
	player = main.get("player")
	hud = main.get("hud")
	_autotest = "--autotest" in OS.get_cmdline_user_args()
	_swap_sky("pho_sang")
	add_to_group("ban_do_nho")  # ghim sân khấu Hội mèo trên bản đồ nhỏ: ban_do_pins()
	san = SanThuong.new()
	add_child(san)
	san.build(main)
	ThangBang.attach(player, san.planks)
	for id in MeoNpc.CAST:
		var m := MeoNpc.from_cast(id)
		add_child(m)
		m.look_target = player
		cats[id] = m
	cats.ba_muop.global_position = STAGE + CRATE + Vector3(0, SEAT_Y, 0)
	cats.ba_muop.snap_ground = false
	cats.ba_muop.set_pose("ngoi_cao")
	for id in MORNING:
		cats[id].global_position = MORNING[id]
		cats[id].rotation.y = randf() * TAU
		cats[id].set_pose("nam" if id in ["mun", "sua", "lac"] else "ngoi")
	_build_stage()
	main.hand_off(self)
	player.carry_model(func(h: Node3D): DoHoi.put(h, "khay_banh_mini", Vector3.ZERO))  # khay mây, gốc ở đỉnh quai
	main.order_picked_up.connect(func(_i, _o): player.carry_tui3(true))
	main.order_delivered.connect(_on_tray)
	for k in CONTESTS.size():
		var t: TroThi = load("res://scripts/hoi_meo/%s.gd" % CONTESTS[k]).new()
		t.name = CONTESTS[k]
		t.hoi = self
		t.main = main
		t.player = player
		t.hud = hud
		t.cats = cats
		t.autotest = _autotest
		add_child(t)
		t.build()
		t.finished.connect(_on_contest_done.bind(k))
		contests.append(t)


func _on_tray(_i: int, _o: Dictionary) -> void:
	hud = main.get("hud")
	player.carry_tui3(false)
	player.carry_model(Callable())
	cats.ba_muop.say("Khay bánh thơm quá! Tối nay nhớ tới hội nha Bơ!", 3.5)
	cats.ba_muop.set_pose("cuoi")
	get_tree().create_timer(3.5).timeout.connect(func(): cats.ba_muop.set_pose("ngoi_cao"))


# ---------------------------------------------------------------- tối hội

## main.gd gọi khi đơn cuối (khay bánh) xong: chuyển sang tối Hội mèo.
func begin_after_orders() -> void:
	hud = main.get("hud")  # HUD dựng sau ChuNhat trong main._ready
	for t in contests:
		t.hud = hud
	phase = "hoi"
	player.can_move = false
	_fade_to("Tối hôm đó, công viên khối 4 giăng đèn lồng...\nHỘI MÈO KHU PHỐ", _start_festival)


func _start_festival() -> void:
	_swap_sky("pho_toi")
	# Thẻ khách buổi sáng và phần HUD của đơn giao không dùng tới buổi tối
	for l: Label3D in main.find_children("*", "Label3D", true, false):
		if l.text.begins_with("1. Bà Mướp"):
			l.visible = false
	hud.set_bread(false)
	for n in ["timer_ring", "progress_row"]:
		var c: Control = hud.get(n)
		if c:
			c.visible = false
	_build_festival()
	_seat_audience()
	for id in WATCH:
		_to_watch(id)
	_place_muc()
	player.can_move = true
	put_player(GATE + Vector3(0, 0, 1.2), STAGE)
	hud.show_toast("Bà Mướp: \"Chào mừng tới Hội mèo! Năm trò thi, ai tham gia cũng có huy chương nha!\"", 4.0)
	_show_board()


func _to_watch(id: String) -> void:
	var m: MeoNpc = cats[id]
	m.stop()
	m.snap_ground = WATCH[id].y <= 0.0  # mèo trên chiếu ngồi lên gối 0,08
	m.global_position = WATCH[id]
	m.face(STAGE)
	m.set_pose("ngoi")
	m.show_name()


func _show_board() -> void:
	current = -1
	_board_t = 0.0
	if _board:
		_board.queue_free()
	_board = CanvasLayer.new()
	_board.layer = 15
	add_child(_board)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.position = Vector2(24, -210)
	panel.custom_minimum_size = Vector2(430, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFF8EA")
	sb.border_color = Color("#3A2418")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	_board.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(_label("Bảng trò thi Hội mèo", 24))
	var next := _next_contest()
	for k in contests.size():
		var t := contests[k]
		var b := Button.new()
		var m: Dictionary = medals.get(CONTESTS[k], {})
		b.text = "%d. %s%s" % [k + 1, t.title(), "  · " + TroThi.RANK_NAMES[m.rank] if not m.is_empty() else ""]
		b.tooltip_text = t.rule()
		b.custom_minimum_size = Vector2(0, 40)
		b.disabled = not m.is_empty()
		b.pressed.connect(_play.bind(k))
		v.add_child(b)
		if k == next:
			b.call_deferred("grab_focus")
	v.add_child(_label("Chọn trò, hoặc bấm Enter để chơi trò kế tiếp." if next >= 0 else "Xong cả 5 trò!", 15))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _next_contest() -> int:
	for k in CONTESTS.size():
		if not medals.has(CONTESTS[k]):
			return k
	return -1


func _play(k: int) -> void:
	if _board:
		_board.queue_free()
		_board = null
	if not _autotest:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	current = k
	DoHoi.anim(_stage, "go_chuong")  # Bà Mướp gõ chuông mở trò
	contests[k].start()


func _on_contest_done(rank: int, note: String, k: int) -> void:
	var t := contests[k]
	medals[CONTESTS[k]] = {"title": t.title(), "rank": rank, "note": note}
	_save_record(k, t.score)
	current = -1
	hud.show_toast("%s: %s, %s! Bà Mướp ghi tên Bơ vào bảng." % [t.title(), TroThi.RANK_NAMES[rank], note], 3.0)
	print("[hoi meo] ", t.title(), " hạng ", rank, " (", note, ")")
	for id in WATCH:
		_to_watch(id)
	if _next_contest() < 0:
		_ceremony()
	else:
		_show_board()


# ---------------------------------------------------------------- trao huy chương, kết tuần

func _ceremony() -> void:
	phase = "trao"
	_ceremony_t = 0.0
	put_player(STAGE + POSE_SPOT + Vector3(0, STAGE_H, 0), STAGE + Vector3(0, 0, -6))
	stage_camera()
	player.can_move = false
	for n: Node in get_tree().get_nodes_in_group(Nguoi.GROUP):
		if n.has_method("play") and n.get("id") in ["coba", "bena", "xemco"]:
			n.play("vay" if n.get("id") == "coba" else "vui")
	cats.ba_muop.say("Huy chương cho Bơ, mèo giao bánh của tuần!", 4.0)
	cats.ba_muop.play("trao_huy_chuong")
	player.play_clip("nhan_huy_chuong")
	# Huy chương tốt nhất đeo lên cổ Bơ lúc 0,85 s của nhan_huy_chuong, rồi đung đưa (clip lac)
	var best := 4
	for m in medals.values():
		best = mini(best, int(m.rank))
	get_tree().create_timer(0.85).timeout.connect(_hang_medal.bind(DoHoi.MEDALS[best]))
	for id in WATCH:
		cats[id].set_pose("reo")


func _finish_week() -> void:
	phase = "tong_ket"
	var list := []
	for k in CONTESTS.size():
		list.append(medals[CONTESTS[k]])
	GameState.set_day("huy_chuong", list.map(func(m): return int(m.rank)), DAY)
	var pages: Array = GameState.get_day("so_trang", [], "thu_bay")
	var full := pages.size() >= 11
	# Tổng sao 5 ngày giao bánh (kỷ lục từng ngày)
	var stars := 0
	for d in ["thu_hai", "thu_ba", "thu_tu", "thu_nam", "thu_sau"]:
		stars += maxi(0, int(GameState.get_day("sao_cao_nhat", 0, d)))
	var summary := Scoring.end_day(Scoring.STARS_PER_ORDER)  # đơn khay bánh sáng: lưu số lần chơi, tiền boa
	GameState.set_global("tuan_moi", true)
	GameState.write_save()
	_summary = TongKetTuan.new()
	_summary.medals = list
	_summary.neighbour_pages = pages.size()
	_summary.week_stars = stars
	_summary.week_stars_max = 5 * 5 * Scoring.STARS_PER_ORDER
	_summary.extra_medal = "Hàng xóm thân" if full else ""
	_summary.autotest = _autotest
	if PlayMode.continuous:
		_summary.new_week_text = PlayMode.next_label()  # "Sang Tuần mới"
	_summary.new_week.connect(_on_new_week)
	_summary.to_menu.connect(_on_to_menu)
	add_child(_summary)
	hud.show_playing_ui(false)
	print("[tong ket] huy chương ", list.map(func(m): return int(m.rank)), " sổ ", pages.size(), " sao tuần ", stars, " boa ", summary.get("tip", 0))
	if _autotest:
		get_tree().create_timer(2.5).timeout.connect(_summary._start_credits)


## "Tuần mới": mở cờ trong GameState (đơn trộn ngẫu nhiên làm sau). Đang chơi liền các ngày thì vào thẳng
## Thứ Hai tuần sau (Scoring.end_day đã gọi day_done: lưu ngày kế và cộng tuần); chơi từ màn Chọn ngày thì về đó.
func _on_new_week() -> void:
	GameState.set_global("tuan_moi", true)
	GameState.write_save()
	if PlayMode.continuous:
		PlayMode.go_next_day(get_tree())
	else:
		PlayMode.back_to_menu(get_tree())


func _on_to_menu() -> void:
	if PlayMode.continuous:
		PlayMode.go_home(get_tree())  # Bắt đầu lần sau là Thứ Hai tuần mới
	else:
		PlayMode.back_to_menu(get_tree())


# ---------------------------------------------------------------- mỗi khung

func _process(delta: float) -> void:
	match phase:
		"hoi":
			_hud_contest()
			if _autotest and current < 0 and _board:
				_board_t += delta
				if _board_t > 0.5:
					_play(_next_contest())
		"trao":
			_ceremony_t += delta
			if _ceremony_t > (1.0 if _autotest else 5.0):
				_finish_week()
		"tong_ket":
			if _autotest and _summary and _summary.is_finished():
				var ok := medals.size() == 5 and medals.values().all(func(m): return int(m.rank) >= 1 and int(m.rank) <= 4)
				ok = ok and bool(GameState.get_global("tuan_moi", false)) and GameState.get_day("so_lan_choi", 0) == 1
				ok = ok and (GameState.get_day("huy_chuong", [], DAY) as Array).size() == 5
				print("AUTOTEST CHU_NHAT ", "OK" if ok else "FAIL")
				get_tree().quit(0 if ok else 1)
				phase = "xong"


func _unhandled_input(event: InputEvent) -> void:
	if phase == "hoi" and _board and current < 0 and event.is_action_pressed("ui_accept"):
		var k := _next_contest()
		if k >= 0:
			_play(k)
			get_viewport().set_input_as_handled()


## Ghim cho bản đồ nhỏ: sân khấu Hội mèo (tối mới đông vui, sáng vẫn hiện để biết chỗ).
func ban_do_pins() -> Array:
	return [{"pos": STAGE, "kind": "place", "text": "★", "color": Color("#F2C14E"), "state": "done" if phase == "xong" else "next",
		"name": "Sân khấu Hội mèo · %d/5 trò" % medals.size() if phase != "sang" else "Sân khấu Hội mèo"}]


## Thẻ HUD và mũi tên trên đầu Bơ trong lúc thi.
func _hud_contest() -> void:
	var arrow: Node3D = main.get("arrow")
	var beacon: Node3D = main.get("beacon")
	if current < 0:
		hud.set_order(0, 5, "Hội mèo khu phố", "Chọn trò trên bảng", Color("#F2C14E"), "★")
		hud.order_chip.text = "Hội mèo · %d/5 trò" % medals.size()
		hud.set_timer(0, 1, false)
		hud.set_distance(player.global_position.distance_to(STAGE), "Sân khấu")
		hud.set_goal(STAGE, false)
		return
	var t := contests[current]
	hud.set_order(current, 5, t.title(), t.status(), CONTEST_COLORS[current], str(current + 1))
	hud.order_chip.text = "Trò %d/5" % (current + 1)
	var g := t.goal()
	hud.set_goal(g + Vector3.UP if g != Vector3.INF else Vector3.ZERO, g != Vector3.INF)
	if g != Vector3.INF:
		hud.set_distance(player.global_position.distance_to(g), t.title())
		if arrow:
			arrow.visible = true
			arrow.global_position = player.smooth_position() + Vector3.UP * 1.15
			var flat := Vector3(g.x, arrow.global_position.y, g.z)
			if arrow.global_position.distance_to(flat) > 0.5:
				arrow.look_at(flat, Vector3.UP)
		if beacon:
			beacon.visible = player.global_position.distance_to(g) > 8.0  # đứng gần thì cột sáng che mất cảnh
			beacon.global_position = Vector3(g.x, 15, g.z)


# ---------------------------------------------------------------- dựng cảnh (đồ sân hội G11, va chạm bằng hộp)

## Đổi trời giữa ngày: gỡ môi trường, nắng, đèn phụ, đèn lồng của buổi cũ rồi dựng buổi mới.
func _swap_sky(preset: String) -> void:
	for n in ["MoiTruong", "MatTroi", "AnhTroi", "DenToi", "GiuFps", "ThoiTiet"]:
		var old := main.get_node_or_null(n)
		if old:
			main.remove_child(old)
			old.queue_free()
	AnhSang.build(main, preset)
	if is_inside_tree():
		GameSettings.apply_graphics(get_tree())


## Sân khấu G11 (có cả buổi sáng để giao khay bánh): hộp sàn, bậc lên góc trước trái, thùng ngồi Bà Mướp.
## Chiếu mèo, 4 băng ghế, chồng thùng, bảng kỷ lục cũng dựng từ sáng.
func _build_stage() -> void:
	_stage = DoHoi.put(self, "san_khau", STAGE, PI)
	DoHoi.anim(_stage, "yen")
	var c := Blocks.collider(self, Vector3(STAGE_SIZE.x, STAGE_H, STAGE_SIZE.y), STAGE + Vector3(0, STAGE_H / 2.0, 0), Blocks.LAYER_PROP)
	c.name = "SanKhau"
	Blocks.collider(self, Vector3(0.65, 0.22, 0.22), STAGE + Vector3(0.925, 0.11, -1.01), Blocks.LAYER_PROP)  # bậc lên
	Blocks.collider(self, Vector3(0.56, SEAT_Y - STAGE_H, 0.42), STAGE + CRATE + Vector3(0, (SEAT_Y + STAGE_H) / 2.0, 0), Blocks.LAYER_PROP)
	DoHoi.put(self, "chieu_meo", MAT)
	for b: Vector3 in BENCHES:
		DoHoi.put(self, "bang_ghe", b)
		Blocks.collider(self, Vector3(1.8, 0.45, 0.42), b + Vector3(0, 0.225, 0), Blocks.LAYER_PROP)
	_record_board = DoHoi.put(self, "bang_ky_luc", RECORD_BOARD, deg_to_rad(200.0))
	Blocks.collider(self, Vector3(1.0, 1.6, 0.5), RECORD_BOARD + Vector3(0, 0.8, 0), Blocks.LAYER_PROP)
	_fill_records()


func _build_festival() -> void:
	_decor = Node3D.new()
	_decor.name = "SanHoi"
	add_child(_decor)
	# Cổng hội: va chạm hai trụ ở chân xô
	var gate := DoHoi.put(_decor, "cong_hoi", GATE, PI)
	DoHoi.anim(gate, "lac")
	for side in [-1.0, 1.0]:
		Blocks.collider(_decor, Vector3(0.35, 2.7, 0.35), GATE + Vector3(side * 1.41, 1.35, 0), Blocks.LAYER_PROP)
	# Dây đèn lồng: hai dây cổng → cột tre sân khấu (dọc x −34,4 và −31,6), hai dây cổng → cây hai bên
	var top_y := 2.95
	for x in [-34.4, -31.6]:
		var a := Vector3(x, top_y, GATE.z)
		var b := Vector3(x, 2.35, STAGE.z + 0.87)
		var mid := a.lerp(b, 0.5) + Vector3(0, 0.15, 0)
		_lanterns(a, mid)
		_lanterns(mid, b)
	_lanterns(GATE + Vector3(-1.45, top_y, 0), Vector3(-39.0, 3.0, 9.5))
	_lanterns(GATE + Vector3(1.45, top_y, 0), Vector3(-27.0, 3.0, 9.5))
	# Cờ đuôi nheo trên xà sân khấu và ngang cổng
	var f1 := DoHoi.put(_decor, "co_duoi_nheo", Vector3(-34.45, 2.37, 21.8), 0.0, Vector3(0.48, 1, 1))
	DoHoi.anim(f1, "bay")
	var f2 := DoHoi.put(_decor, "co_duoi_nheo", GATE + Vector3(-1.45, 2.3, 0.1), 0.0, Vector3(2.9 / 6.0, 1, 1))
	DoHoi.anim(f2, "bay")
	# Ánh đèn lồng: bản PC thêm đèn cam ấm dọc hai dây (mỗi ~3 m), bản web chỉ có emission + 1 đèn sân khấu
	var spots := [STAGE + Vector3(0, 3.0, -2.0)]
	if not AnhSang.is_compat():
		for x in [-34.4, -31.6]:
			for z in [8.6, 11.6, 14.6, 17.6]:
				spots.append(Vector3(x, 2.3, z))
	for p: Vector3 in spots:
		var l := OmniLight3D.new()
		l.light_color = Color("#FFB070")
		l.light_energy = 2.2 if p == spots[0] else 0.9
		l.omni_range = 11.0 if p == spots[0] else 4.0
		l.shadow_enabled = false
		_decor.add_child(l)
		l.global_position = p


## Một đoạn dây đèn lồng (model dài 6 m, gốc ở móc trái) kéo từ a sang b.
func _lanterns(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var x := d.normalized()
	var z := x.cross(Vector3.UP).normalized()
	var y := z.cross(x)
	var n := DoHoi.put(_decor, "day_den_long", Vector3.ZERO)
	n.transform = Transform3D(Basis(x * (d.length() / 6.0), y, z), a)
	DoHoi.anim(n, "lac")


## Hàng xóm ra xem hội (đề xuất 2 G11). Ai đã có trong cảnh thì dời tới chỗ, chưa có thì dựng.
func _seat_audience() -> void:
	for a in AUDIENCE:
		var n: Node3D = null
		for o: Node in get_tree().get_nodes_in_group(Nguoi.GROUP):
			if o.get("id") == a[0]:
				n = o
		if n == null:
			n = Nguoi.make(a[0], a[3])
			add_child(n)
		elif n.has_method("play"):
			n.play(a[3])
		n.set_physics_process(false)
		n.global_position = a[1]
		n.rotation.y = a[2]
		n.set("look_target", player)


## Huy chương G11 đeo ở socket cổ Bơ (xương neck), đung đưa khi vừa đeo.
func _hang_medal(model: String) -> void:
	var skel: Skeleton3D = player.get("_skel")
	if skel == null:
		return
	if is_instance_valid(_medal):
		_medal.queue_free()
	_medal = DoHoi.attach(skel, "neck", model, DoHoi.NECK)
	DoHoi.anim(_medal, "lac")


# ---------------------------------------------------------------- bảng kỷ lục

## Kỷ lục từng trò (lưu trong mục chu_nhat "ky_luc"): đua, trốn tìm, tiếp sức tính giây (ít hơn là hơn);
## chồng thùng tính tầng, trang phục tính điểm (nhiều hơn là hơn).
const LOWER_BETTER := ["dua_mai", "tron_tim", "tiep_suc"]


func _save_record(k: int, value: float) -> void:
	if value < 0.0:
		return
	var rec: Dictionary = GameState.get_day("ky_luc", {}, DAY)
	var id: String = CONTESTS[k]
	var old := float(rec.get(id, -1.0))
	var better := old < 0.0 or (value < old if id in LOWER_BETTER else value > old)
	if better:
		rec[id] = value
		GameState.set_day("ky_luc", rec, DAY)
		_fill_records()


## Ghi số lên 5 dòng trống của bảng kỷ lục (toạ độ dòng theo bàn giao G11, bảng nghiêng 10°).
func _fill_records() -> void:
	if _record_board == null:
		return
	const ROWS := [Vector3(0.242, 1.161, -0.083), Vector3(0.242, 1.054, -0.064), Vector3(0.242, 0.946, -0.045),
		Vector3(0.242, 0.838, -0.026), Vector3(0.242, 0.731, -0.008)]
	for l in _record_board.find_children("KyLuc*", "Label3D", false, false):
		l.queue_free()
	var rec: Dictionary = GameState.get_day("ky_luc", {}, DAY)
	for k in CONTESTS.size():
		var v := float(rec.get(CONTESTS[k], -1.0))
		if v < 0.0:
			continue
		var l := Label3D.new()
		l.name = "KyLuc%d" % k
		l.text = str(int(round(v))) if CONTESTS[k] != "trang_phuc" else "%.1f" % v
		l.font_size = 40
		l.pixel_size = 0.0025
		l.modulate = Color("#F4EFE2")
		l.outline_size = 0
		l.double_sided = false
		l.position = ROWS[k] + Vector3(0, 0.012, 0.012)
		l.rotation_degrees.x = -10.0
		_record_board.add_child(l)


## Mực: đã làm bạn ở Thứ Bảy thì đứng gác cổng, chưa thì nằm ngủ ngoài cổng. AI tắt cả buổi tối.
func _place_muc() -> void:
	var dog: Node3D = main.get("dog")
	if dog == null:
		return
	var friend := bool(GameState.get_day("muc_ban", false, "thu_bay"))
	dog.set("awake", false)
	dog.set_physics_process(false)
	dog.global_position = MUC_SPOT
	dog.set("home", MUC_SPOT)
	dog.set("_prev_pos", MUC_SPOT)
	dog.set("_curr_pos", MUC_SPOT)
	dog.velocity = Vector3.ZERO
	if dog.has_method("play_clip"):
		dog.play_clip("dung_gac" if friend else "ngu_gat")


## Đưa camera ra trước sân khấu nhìn vào (sau lưng Bơ lúc đứng trên sân khấu là phông vải).
func stage_camera() -> void:
	var rig: Node = player.get("camera_rig")
	if rig:
		rig.set("yaw", PI)
		rig.set("pitch", -0.2)


func put_player(pos: Vector3, look := Vector3.INF) -> void:
	player.global_position = pos + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	if look != Vector3.INF:
		var d := look - pos
		player.visual.rotation.y = atan2(-d.x, -d.z)


func _fade_to(text: String, then: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 25
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.06, 0.05, 0.08, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color("#FFE3A0"))
	l.modulate.a = 0.0
	layer.add_child(l)
	var fast := 0.2 if _autotest else 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.8 * fast)
	tw.parallel().tween_property(l, "modulate:a", 1.0, 0.8 * fast)
	tw.tween_callback(then)
	tw.tween_interval(1.6 * fast)
	tw.tween_property(_fade, "color:a", 0.0, 0.8 * fast)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8 * fast)
	tw.tween_callback(layer.queue_free)


func _label(t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#3A2418"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
