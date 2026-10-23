class_name MeoHangXom
extends Node3D
## Mèo hàng xóm trong tuần (gói N, trang https://claude.ai/artifact/9CnjRzPcoQXuSMtvLg14Vf, kế hoạch
## /mnt/project-files/tuong-tac-con-vat/KE-HOACH.md, luồng 4). Mọi thứ ở đây là thưởng, không mất sao, không thua.
##   N1: mỗi ngày một mèo Hội mèo có mặt ngoài phố (LICH), Bơ bấm Q gọi thì mèo đáp, ConVat.meet(id).
##   N2: đứng sát (GREET_R) bấm Q là chào kiểu mèo: lần đầu chạm mũi, lần sau cụng đầu; mèo đáp theo tính cách (CHAO).
##   N3: Thứ Tư, Bột chờ ở đầu đường sân thượng, rủ đua tới tạp hóa Cô Hai (đúng đường đơn 2, không tốn thêm giờ).
##   N4: chạy lòng vòng hơn 20 s không gần đích hơn thì mèo của ngày chạy ra dẫn đường (Cài đặt "Mèo chỉ đường").
## Node nạp cho mọi ngày qua khóa "nodes" của scripts/ngay/thu_hai.gd (main.gd thêm node của mọi ngày); ngày không có
## trong LICH thì tự gỡ. Không có begin()/resume_day(): hai hàm đó dành cho node chính của ngày.
## Động tác chào mới (chạm mũi, cụng đầu, liếm đầu, 4 kiểu đáp) do luồng "Phác thảo động tác và phụ kiện thưởng" vẽ
## (Sang duyệt 23/10, CAP); chưa có clip tên đó thì dùng động tác tạm có sẵn (BO_CLIP, DAP_TAM).

const GREET_R := 2.0          ## đứng gần chừng này thì chào kiểu mèo
const VIEW_END := 14.0        ## mèo đứng yên ngoài 14 m thì không vẽ (ngã tư sát trần 400k tam giác)

## Mèo của từng ngày: id cast (MeoNpc.CAST), chỗ, hướng (độ, 0 = nhìn về -Z bắc), dáng, câu khi gọi từ xa
const LICH := {
	"thu_hai": [{"id": "mit", "pos": Vector3(-8.2, 3.3, -6.2), "yaw": 100.0, "pose": "nam",
		"xa": "Meo? Mít nằm phơi nắng trên mái hiên tiệm tóc nè!"}],
	"thu_ba": [{"id": "bot", "pos": Vector3(-13.4, 0.2, 5.3), "yaw": 200.0, "pose": "ngoi",
		"xa": "Bột chờ cô bán khô cho miếng cá. Mai mưa, lên mái đua với Bột nha!"}],
	"thu_tu": [{"id": "mun", "pos": Vector3(3.2, 0.2, 5.6), "yaw": 180.0, "pose": "ngoi",
		"xa": "Mun trú mưa dưới mái hiên. Ướt lông là ghét lắm."},
		{"id": "bot", "pos": Vector3(-25.0, 3.3, -6.5), "yaw": 270.0, "pose": "ngoi", "dua": true,
		"xa": "Bột đây! Chân Bột chắc lắm, mưa cũng không trượt."}],
	"thu_nam": [{"id": "gung", "pos": Vector3(25.2, 1.2, -15.55), "yaw": 180.0, "pose": "nam",
		"xa": "Trưa nóng quá, Gừng nằm yên xe máy dưới ban công cho mát."}],
	"thu_sau": [{"id": "tuyet", "pos": Vector3(-19.9, 0.2, 19.8), "yaw": 120.0, "pose": "kieu",
		"xa": "Tuyết tới đám giỗ ngắm người ta bày mâm."}],
	"thu_bay": [{"id": "sua", "pos": Vector3(-40.5, 0.2, 21.0), "yaw": 30.0, "pose": "nam",
		"xa": "Sữa nằm cỏ công viên, nắng ấm ghê."},
		{"id": "lac", "pos": Vector3(-39.4, 0.2, 21.6), "yaw": 240.0, "pose": "ngoi",
		"xa": "Lạc nè! Chân Lạc ngắn nên nhảy không cao, hihi."}],
}
## Kiểu chào mèo thích và cách đáp (theo tính trong MeoNpc.CAST); câu lần đầu chạm mũi, câu những lần sau
const CHAO := {
	"mit": {"dap": "lui_ngai", "dau": "Mít đây. Đừng làm văng nước lên Mít nha!", "lai": "Lại là Bơ hả, chào chào."},
	"bot": {"dap": "cung_lai", "dau": "Chào Bơ! Bột là Bột, chắc chân nhất phố.", "lai": "Cụng cái nữa nè!"},
	"mun": {"dap": "lui_ngai", "dau": "...Mun. Chào.", "lai": "...Ừ. Chào Bơ."},
	"tuyet": {"dap": "hat_mat", "dau": "Tuyết đây. Khăn Bơ cũng xinh đó.", "lai": "Hừm, hôm nay Bơ thơm mùi bánh mì."},
	"gung": {"dap": "cung_lai", "dau": "Gừng nè! Bơ giao bánh hả? Hay quá!", "lai": "Hì, cụng đầu nữa!"},
	"sua": {"dap": "liem_dau", "dau": "Sữa chào Bơ. Để Sữa vuốt lông cho nè.", "lai": "Bơ ngoan ghê."},
	"lac": {"dap": "cung_lai", "dau": "Lạc nè! Bơ chơi với Lạc không?", "lai": "Hehe, Bơ lại tới!"},
}
## Động tác Bơ chào: [clip mới của luồng 7, clip tạm đang có]
const BO_CLIP := {"mui": ["cham_mui", "ngui_mui"], "dau": ["cung_dau", "dui_dau"]}
## Đáp tạm khi chưa có clip luồng 7: dáng MeoNpc giữ trong DAP_GIAY giây
const DAP_TAM := {"lui_ngai": "tron", "hat_mat": "kieu", "liem_dau": "vay_duoi", "cung_lai": "vay_duoi"}
const DAP_GIAY := 1.8
## Cặp động tác luồng 7 (trang https://claude.ai/artifact/VfkNSdts59PFPJ1ipYsjVQ, Sang duyệt 23/10): mèo đi tới đứng
## đúng chỗ rồi hai con cùng diễn. Khoảng cách gốc hai con đo va chạm từng khung trong Blender: mũi, trán chỉ vừa chạm.
## kiểu đáp: [clip Bơ, cách (m), đứng bên trái Bơ cùng hướng thay vì mặt đối mặt]
const CAP := {"liem_dau": ["duoc_liem", 0.34, true], "cung_lai": ["cung_dau", 0.76, false]}
const SAT := 0.76             ## chạm mũi, cụng đầu: gốc hai con cách nhau chừng này
const DI_CHAO := 1.0          ## tốc độ mèo bước lại chỗ chào (m/s)
const LIEM_GIAY := 2.0        ## liếm đầu (clip lặp 1 s) chừng này rồi dừng

# N3: đua mái Thứ Tư
const RACE_ORDER := 1         ## đơn 2 (Cô Hai): đường sân thượng "co_hai"
const RACE_SPEED := 4.6       ## như đối thủ Hội mèo (scripts/hoi_meo/dua_mai.gd)
const RACE_INVITE_R := 3.5
const RACE_WIN_R := 2.5
const RACE_MAX := 120.0

# N4: chỉ đường
const LOST_CHECK := 1.0       ## đo đường còn lại mỗi giây
const LOST_PROGRESS := 1.0    ## gần đích hơn chừng này mét mới tính là đi đúng
const LOST_NEAR := 12.0       ## còn dưới 12 m đường thì không coi là lạc
const GUIDE_LEAD := 4.5       ## mèo chạy trước Bơ chừng này
const GUIDE_WAIT := 7.5       ## xa Bơ hơn thì ngồi chờ
const GUIDE_DONE := 8.0       ## Bơ còn cách đích chừng này thì mèo chào về
const GUIDE_GIVE_UP := 18.0   ## Bơ bỏ đi xa hơn chừng này 8 s thì mèo thôi
const GUIDE_COOL := 30.0

var main: Node
var player: CharacterBody3D
var _pairing := {}            ## id mèo đang bước lại chỗ chào (clip luồng 7)
var hud: Node
var day_id := ""
## id -> MeoNpc của ngày (mỗi id một con)
var cats := {}
## id -> số lần đã chào kiểu mèo hôm nay
var greeted := {}
## Bột Thứ Tư: "" | "moi" (đang rủ) | "dem" (đếm ngược) | "chay" | "xong"
var race := ""
var race_won := false
## Mèo dẫn đường (N4), ẩn khi không dẫn
var guide: MeoNpc
var guiding := false
var lost_t := 0.0

var _spots := {}              ## id -> chỗ ngồi gốc (sau khi đáp xong về đây)
var _busy := {}               ## id -> giây còn bận đáp, Q lúc này bỏ qua
var _race_route: Array = []
var _race_t := 0.0
var _race_cat: MeoNpc
var _check_t := 0.0
var _best := INF
var _goal := Vector3.INF
var _cool := 0.0
var _gpath: Array = []        ## các điểm mèo dẫn đường đi theo
var _gi := 0
var _gwait := false
var _gaway := 0.0
var _gbye := -1.0
var _autotest := false


func _ready() -> void:
	name = "MeoHangXom"
	main = get_parent()
	var day: Dictionary = main.get("day") if main.get("day") is Dictionary else {}
	day_id = day.get("id", "")
	if not LICH.has(day_id):
		queue_free()
		return
	player = main.get("player")
	hud = main.get("hud")
	_autotest = "--autotest" in OS.get_cmdline_user_args()
	for spot: Dictionary in LICH[day_id]:
		var m := MeoNpc.from_cast(spot.id)
		add_child(m)
		m.global_position = spot.pos
		m.rotation.y = deg_to_rad(spot.yaw)
		m.look_target = player
		m.set_pose(spot.pose)
		_light(m)
		cats[spot.id] = m
		_spots[spot.id] = spot.duplicate()
		_hook_q(m)
	var first: Dictionary = LICH[day_id][0]
	if not day.get("orders", []).is_empty():
		guide = MeoNpc.from_cast(first.id)
		guide.name = "MeoChiDuong"
		add_child(guide)
		guide.look_target = player
		_light(guide)
		_hide_guide()
	if day_id == "thu_tu":
		_setup_race.call_deferred()  # đường sân thượng do ThuTu dựng trong cùng lượt, chờ một nhịp


## Mèo đứng yên: không đổ bóng, xa thì thôi vẽ (thêm ~6k tam giác bản web mỗi con, chỉ khi ở gần).
func _light(m: MeoNpc) -> void:
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = VIEW_END
		mi.visibility_range_end_margin = 1.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## Q gọi: ConVat (scripts/con_vat.gd) gắn phím Q mọi ngày, Bơ ngồi kêu meo, mèo trong tầm gọi on_called → on_q.
func _hook_q(m: MeoNpc) -> void:
	m.on_q = func(pos: Vector3): _on_q(m, pos)


func _meet(id: String) -> void:
	ConVat.meet(id)


func _toast(text: String, seconds := 2.4) -> void:
	if hud and hud.has_method("show_toast"):
		hud.show_toast(text, seconds)


# ---------------------------------------------------------------- N1, N2: gọi và chào

## Bơ bấm Q trong tầm nghe của mèo `m` (pos: chỗ Bơ ngồi gọi).
func _on_q(m: MeoNpc, pos: Vector3) -> void:
	var id := m.cast_id
	if _busy.get(id, 0.0) > 0.0 or m.moving:
		return
	var spot: Dictionary = _spots.get(id, {})
	if spot.get("dua", false) and race == "moi":
		_race_start()
		return
	if race in ["dem", "chay"] and m == _race_cat:
		return
	_meet(id)
	m.face(pos)
	var d := Vector2(m.global_position.x - pos.x, m.global_position.z - pos.z).length()
	if d > GREET_R or absf(m.global_position.y - pos.y) > 0.8:
		m.say(str(spot.get("xa", "Meo?")), 3.0)
		_busy[id] = 1.0
		if not greeted.has(id):
			_toast("Lại sát %s rồi bấm Q để chào kiểu mèo" % m.ten)
		return
	_greet(m)


## Chào kiểu mèo: Bơ chạm mũi (lần đầu) hay cụng đầu (lần sau), mèo đáp theo tính cách.
func _greet(m: MeoNpc) -> void:
	var id := m.cast_id
	var n: int = greeted.get(id, 0)
	greeted[id] = n + 1
	var c: Dictionary = CHAO.get(id, CHAO.bot)
	_busy[id] = DAP_GIAY + 0.8
	if player:
		var to := m.global_position - player.global_position
		to.y = 0.0
		if to.length() > 0.01 and "visual" in player:
			player.visual.rotation.y = atan2(-to.x, -to.z)
		if player.has_method("hold"):
			player.hold(1.4)
		var dap := str(c.dap)
		if player.has_clip("cham_mui") and MeoNpc._clips().has(dap):
			_greet_pair(m, dap, n, to)
		else:
			var pair: Array = BO_CLIP["mui" if n == 0 else "dau"]
			var clip: String = pair[0] if player.has_clip(pair[0]) else pair[1]
			player.play_clip(clip)
	m.say(str(c.dau if n == 0 else c.lai), 3.2)
	if n == 0:
		_toast("Bơ và %s đã thành bạn!" % m.ten)
	if not _pairing.has(id):
		get_tree().create_timer(0.45).timeout.connect(_reply.bind(m, str(c.dap)))


## Chào bằng clip luồng 7: mèo bước tới chỗ chào cạnh Bơ (to: hướng Bơ nhìn), xong thì Bơ diễn, mèo đáp.
## Cặp cụng đầu, liếm đầu diễn cùng lúc; mèo lùi ngại, hất mặt đáp sau 0,45 s như cũ.
func _greet_pair(m: MeoNpc, dap: String, n: int, to: Vector3) -> void:
	var f := to.normalized() if to.length() > 0.01 else Vector3.FORWARD
	var cap: Array = CAP.get(dap, ["cham_mui" if n == 0 else "cung_dau", SAT, false])
	var spot: Vector3 = player.global_position + (Vector3(f.z, 0.0, -f.x) if cap[2] else f) * float(cap[1])
	spot.y = m.global_position.y
	# chỗ chào vướng tường, thùng (mèo đứng sát quá phải lùi vào tường) thì mèo đứng yên chỗ cũ
	var lift := Vector3.UP * 0.3   # trên mép lề đường 20 cm
	var q := PhysicsRayQueryParameters3D.create(m.global_position + lift, spot + lift + (spot - m.global_position).normalized() * 0.2)
	q.exclude = [player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		spot = m.global_position
	var id := m.cast_id
	_pairing[id] = true
	var t := Vector2(spot.x - m.global_position.x, spot.z - m.global_position.z).length() / DI_CHAO
	_busy[id] = t + (LIEM_GIAY if CAP.has(dap) else DAP_GIAY) + 0.3
	if player.has_method("hold"):
		player.hold((LIEM_GIAY if CAP.has(dap) else 1.4) + t)
	if t > 0.08:
		m.walk_to(spot, DI_CHAO)
	get_tree().create_timer(t + 0.05).timeout.connect(func():
		_pairing.erase(id)
		if not is_instance_valid(m) or not is_instance_valid(player):
			return
		m.stop()
		m.global_position = spot
		if cap[2]:
			m.rotation.y = atan2(-f.x, -f.z)
		else:
			m.face(player.global_position)
		player.play_clip(str(cap[0]))
		if not CAP.has(dap):
			get_tree().create_timer(0.45).timeout.connect(_reply.bind(m, dap))
			return
		_reply(m, dap)
		if MeoNpc._clips()[dap].loop:   # liếm đầu lặp: liếm hai lượt rồi thôi
			get_tree().create_timer(LIEM_GIAY).timeout.connect(func():
				if is_instance_valid(player) and player.clip == str(cap[0]):
					player.stop_clip()
				if is_instance_valid(m):
					m.set_pose(m.pose)))


func _reply(m: MeoNpc, kind: String) -> void:
	if not is_instance_valid(m):
		return
	if MeoNpc._clips().has(kind):
		m.play(kind)
		return
	var base := m.pose
	match kind:
		"lui_ngai":
			var away := m.global_position - (player.global_position if player else m.global_position)
			away.y = 0.0
			if away.length() > 0.01:
				m.walk_to(m.global_position + away.normalized() * 0.5, 0.9)
		"cung_lai":
			var to := (player.global_position if player else m.global_position) - m.global_position
			to.y = 0.0
			if to.length() > 0.5:
				m.walk_to(m.global_position + to.normalized() * minf(0.25, to.length() - 0.45), 0.6)
	m.set_pose(DAP_TAM.get(kind, "vay_duoi"))
	get_tree().create_timer(DAP_GIAY).timeout.connect(func():
		if is_instance_valid(m) and not m.moving:
			m.set_pose(base))


# ---------------------------------------------------------------- mỗi nhịp

func _physics_process(delta: float) -> void:
	if player == null:
		return
	for id in _busy:
		_busy[id] = maxf(0.0, _busy[id] - delta)
	if day_id == "thu_tu":
		_update_race(delta)
	if guide:
		_update_lost(delta)
		_update_guide(delta)


func _playing() -> bool:
	return main.get("state") == main.State.PLAY


# ---------------------------------------------------------------- N3: Bột rủ đua mái

func _setup_race() -> void:
	var san := main.find_child("SanThuong", true, false)
	if san == null or not "routes" in san:
		return
	var route: Array = san.routes.get("co_hai", [])
	if route.size() < 4:
		return
	_race_route = route.slice(2)
	_race_cat = cats.get("bot")
	if _race_cat:
		var start: Vector3 = route[1]
		_race_cat.snap_ground = false
		_race_cat.global_position = start + Vector3(0.7, 0, 0.1)
		_spots.bot.pos = _race_cat.global_position


func _update_race(delta: float) -> void:
	if _race_cat == null or _race_route.is_empty():
		return
	var order_ok: bool = int(main.get("order_index")) == RACE_ORDER and bool(player.get("carrying")) and _playing()
	var d := _race_cat.global_position.distance_to(player.global_position)
	match race:
		"":
			if order_ok and d < RACE_INVITE_R:
				race = "moi"
				_race_cat.face(player.global_position)
				_race_cat.say("Đua tới tạp hóa Cô Hai không? Bấm Q!", 4.0)
				_toast("Bột rủ đua trên mái: bấm Q để nhận (không tính vào đơn)", 3.0)
		"moi":
			if not order_ok or d > RACE_INVITE_R * 2.5:
				race = ""
			elif _autotest:
				_race_start()
		"chay":
			_race_t += delta
			var end: Vector3 = _race_route[-1]
			if player.global_position.distance_to(end) < RACE_WIN_R:
				_race_end(true)
			elif _race_t > RACE_MAX:
				_race_end(false)


func _race_start() -> void:
	race = "dem"
	_meet("bot")
	_race_cat.say("3... 2... 1... Chạy!", 2.0)
	_toast("3... 2... 1... Chạy!", 1.6)
	get_tree().create_timer(1.6).timeout.connect(func():
		if race != "dem":
			return
		race = "chay"
		_race_t = 0.0
		_race_cat.follow_path(_race_route, RACE_SPEED * float(DoKho.v("bot_race_mult", 1.0)))
		_race_cat.arrived.connect(_on_bot_arrived, CONNECT_ONE_SHOT))


func _on_bot_arrived() -> void:
	if race == "chay":
		_race_end(false)
	_race_cat.set_pose("ngoi")


func _race_end(won: bool) -> void:
	race = "xong"
	race_won = won
	if won:
		_toast("Bơ về trước Bột! Chân Bơ cũng chắc ghê.", 3.0)
		_race_cat.say("Bơ nhanh ghê! Chủ Nhật đua thật nha!", 3.5)
	else:
		_toast("Bột về trước! Không sao, đơn vẫn tính bình thường.", 3.0)
		_race_cat.say("Bột thắng! Chủ Nhật đua lại nha!", 3.5)


# ---------------------------------------------------------------- N4: mèo chỉ đường

func guide_enabled() -> bool:
	return bool(GameSettings.get_value("meo_chi_duong"))


func _update_lost(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = LOST_CHECK
	if guiding or not guide_enabled() or not _playing() or main.get("_leaving") or race in ["dem", "chay"]:
		lost_t = 0.0
		return
	var goal: Vector3 = main._current_goal()
	if goal.distance_to(_goal) > 0.5:
		_goal = goal
		_best = INF
		lost_t = 0.0
	var left := path_left(player.global_position, goal)
	if left < _best - LOST_PROGRESS:
		_best = left
		lost_t = 0.0
		return
	lost_t += LOST_CHECK
	if lost_t >= float(DoKho.v("lost_guide_after", 40.0)) and left > LOST_NEAR and _cool <= 0.0 \
			and player.global_position.y < 1.5 and player.is_on_floor():
		summon_guide()


## Độ dài đường đi bộ (né dãy nhà, như đường chấm bản đồ nhỏ) từ a tới b.
static func path_left(a: Vector3, b: Vector3) -> float:
	var pts := BanDoNho.find_path(Vector2(a.x, a.z), Vector2(b.x, b.z))
	if pts.size() < 2:
		return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
	var s := 0.0
	for i in range(1, pts.size()):
		s += pts[i - 1].distance_to(pts[i])
	return s + pts[-1].distance_to(Vector2(b.x, b.z))


## Mèo chạy ra trước mặt Bơ rồi dẫn theo đường bản đồ nhỏ tới đích đang làm.
func summon_guide() -> void:
	var goal: Vector3 = main._current_goal()
	var pts := BanDoNho.find_path(Vector2(player.global_position.x, player.global_position.z), Vector2(goal.x, goal.z))
	if pts.size() < 2:
		return
	_gpath.clear()
	for p in pts:
		_gpath.append(Vector3(p.x, 0.0, p.y))
	_gpath.append(Vector3(goal.x, 0.0, goal.z))
	# Ra chỗ cách Bơ ~3 m dọc đường đi, để Bơ thấy ngay
	var start := _along(_gpath, 3.0)
	_gi = _index_after(_gpath, 3.0)
	guiding = true
	_gwait = false
	_gaway = 0.0
	_gbye = -1.0
	lost_t = 0.0
	guide.visible = true
	guide.set_process(true)
	guide.global_position = start + Vector3(0, 0.4, 0)
	guide.face(player.global_position)
	guide.set_pose("dung")
	guide.say("Lạc hả Bơ? Theo %s nè!" % guide.ten, 3.0)
	_toast("%s chỉ đường cho Bơ" % guide.ten, 2.4)
	_meet(guide.cast_id)
	get_tree().create_timer(1.0).timeout.connect(func():
		if guiding and _gbye < 0.0:
			guide.follow_path(_gpath.slice(_gi), MeoNpc.RUN_SPEED))


func _update_guide(delta: float) -> void:
	if not guiding:
		return
	if _gbye >= 0.0:
		_gbye -= delta
		if _gbye <= 0.0:
			_hide_guide()
		return
	var goal: Vector3 = main._current_goal()
	var bo := player.global_position
	var cat := guide.global_position
	if not _playing() or Vector2(bo.x - goal.x, bo.z - goal.z).length() < GUIDE_DONE \
			or Vector2(cat.x - goal.x, cat.z - goal.z).length() < 1.5 or goal.distance_to(_goal) > 0.5:
		_bye("Tới rồi đó! Giao bánh vui nha!")
		return
	while _gi < _gpath.size() and Vector2(cat.x - _gpath[_gi].x, cat.z - _gpath[_gi].z).length() < 0.6:
		_gi += 1
	var gap := Vector2(cat.x - bo.x, cat.z - bo.z).length()
	_gaway = _gaway + delta if gap > GUIDE_GIVE_UP else 0.0
	if _gaway > 8.0:
		_bye("Bơ đi đâu rồi? Thôi %s về nha." % guide.ten)
		return
	if not _gwait and gap > GUIDE_WAIT and guide.moving:
		_gwait = true
		guide.stop()
		guide.face(bo)
		guide.set_pose("ngoi")
	elif _gwait and gap < GUIDE_LEAD:
		_gwait = false
		if _gi < _gpath.size():
			guide.follow_path(_gpath.slice(_gi), MeoNpc.RUN_SPEED)


func _bye(text: String) -> void:
	guide.stop()
	guide.face(player.global_position)
	guide.set_pose("vay_duoi")
	guide.say(text, 2.5)
	_gbye = 2.6
	_cool = GUIDE_COOL
	_best = INF


func _hide_guide() -> void:
	guiding = false
	guide.stop()
	guide.visible = false
	guide.set_process(false)
	guide.global_position = Vector3(0, -50, 0)


## Điểm trên đường cách điểm đầu `dist` mét.
static func _along(path: Array, dist: float) -> Vector3:
	var s := 0.0
	for i in range(1, path.size()):
		var seg: float = path[i - 1].distance_to(path[i])
		if s + seg >= dist:
			return path[i - 1].lerp(path[i], (dist - s) / maxf(seg, 0.001))
		s += seg
	return path[-1]


static func _index_after(path: Array, dist: float) -> int:
	var s := 0.0
	for i in range(1, path.size()):
		s += path[i - 1].distance_to(path[i])
		if s >= dist:
			return i
	return path.size() - 1
