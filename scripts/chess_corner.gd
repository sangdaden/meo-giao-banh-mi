class_name ChessCorner
extends Node3D
## Góc cờ tướng ở công viên khối 4 cho đơn 3 Thứ Ba (gói T3-2, trang thiết kế màn chơi mục 06 và 13).
## Ông Bảy và Ông Tám ngồi ghế đá đánh cờ trên bàn đá mài dưới gốc cây lớn, bàn cờ gỗ gập với
## 30 quân đang đánh dở, ấm trà trên ghế đẩu cạnh bàn, 5 người đứng xem chen một phía.
## Bơ rón rén tới đặt túi bánh cạnh ấm trà.
## - Đi thường trong vòng 3 m: một ông quay ra "suỵt", Bơ khựng 1 giây.
## - Chạy nhanh trong vòng 3 m, hoặc đụng bàn, nhảy lên bàn: quân cờ rung, rơi; hai ông đứng dậy mắng,
##   đơn mất 1 sao.
## - Mỗi 10 đến 14 giây có "chiếu tướng": cả đám reo lên, 2 giây không ai để ý Bơ.
##   Nhiệm vụ phụ: đặt túi đúng lúc này.
## Nghe tiếng động qua player.noise_made (hợp đồng gói 1), báo ra ngoài bằng chess_event(kind) với
## kind là "chieu_tuong", "suyt", "mang".
##
## Cách dùng (deliveries.gd làm sẵn khi một đơn có "delivery": "beside_tea"):
##   ChessCorner.build_static(parent) trước Blocks.merge_static (cây, bàn đá, ghế, ấm trà đứng yên),
##   add_child(ChessCorner.new()) sau khi gộp, rồi setup(player).
##   begin_order() lúc nhận bánh, deliver() lúc đặt túi (ổ bánh bay tới bag_point() rồi show_bag()),
##   end_order() khi đơn xong.
## Đồ vật là model Blender theo trang "Phác thảo Thứ Ba" (Sang duyệt 21/10, assets/models/goc_co/,
## dựng bằng scripts/do3.py của luồng phác thảo). Hai ông là model có xương của luồng "Người dân vào game"
## (Nguoi); trong lúc chờ animation suỵt / mắng / reo riêng thì mượn noi / sot_ruot / vui.
## Người xem vẫn là khối tạm, chờ người chợ có xương.

signal chess_event(kind: String)

## Tâm bàn cờ, ở góc đông bắc công viên khối 4, gần đường lớn phía bắc (đi từ lò bánh qua là tới).
const CENTER := CityProps.CHESS_CORNER
## Ấm trà trên ghế đẩu phía bắc bàn; Bơ đứng ở DROP để đặt túi (đây là "pos" của đơn).
const TEA := Vector3(-28.8, 0, 7.75)
const DROP := Vector3(-28.8, 0, 7.15)
## Đơn 3 Thứ Ba theo hợp đồng Days (days.gd ở PR #41 dùng cùng các khóa; "time" là số giây cuối cùng).
const ORDER := {
	"who": "Ông Bảy, Ông Tám", "place": "Góc cờ công viên", "item": "1 ổ pate, 1 ổ trứng",
	"pos": DROP, "time": 22.0, "color": Color("#8C6D4F"), "kind": "deliver",
	"delivery": "beside_tea", "side_quest": "dat_luc_chieu", "note": "",
}

const NOTICE_RADIUS := 3.0      ## trong vòng này hai ông nghe thấy tiếng bước chân
var _notice: float = NOTICE_RADIUS  ## Thong thả: 2 m (DoKho)
const TABLE_RADIUS := 1.0       ## tiếng đụng mạnh trong vòng này là đụng bàn (bàn, ghế, hai ông)
const WALK_NOISE := 6.0         ## bán kính tiếng động theo hợp đồng player.gd
const BUMP_NOISE := 8.0
const SPRINT_NOISE := 10.0
const SHUSH_STUN := 1.0         ## bị suỵt thì Bơ khựng lại bấy nhiêu giây
const SHUSH_COOLDOWN := 2.0
const SCOLD_COOLDOWN := 3.0
const CHECK_EVERY := Vector2(10.0, 14.0)  ## khoảng giữa hai lần chiếu tướng
const CHECK_WINDOW := 2.0       ## sau chiếu tướng bấy nhiêu giây không ai để ý Bơ

const TABLE_SIZE := Vector3(0.72, 0.48, 0.72)  ## bàn đá mài ban_da
const BOARD_TOP := 0.494        ## mặt bàn cờ gỗ (bàn đá 0,48 + bàn cờ 0,014)
const GRID := 0.045             ## khoảng giao điểm bàn cờ (8 x 9 ô), như do3.py
const STOOL_TOP := 0.32         ## mặt ghế đá; gốc model người ngồi = STOOL_TOP - Nguoi.SEAT[id]
const TEA_TOP := 0.28           ## mặt ghế đẩu gỗ
const MODELS := "../goc_co/"    ## PhoModels.mesh() đọc từ assets/models/pho/
## Thế cờ đang đánh dở trong phác thảo: (loại, cột 0–8, hàng 0–9). Đỏ phía Ông Tám (đông), đen phía Ông Bảy.
const PIECE_FILE := {"K": "tuong", "A": "si", "E": "tuong_voi", "H": "ma", "R": "xe", "C": "phao", "P": "tot"}
const POS_RED := [["K", 4, 0], ["A", 3, 0], ["A", 4, 1], ["E", 2, 0], ["E", 4, 2], ["H", 2, 2], ["H", 6, 4], ["R", 0, 0],
	["R", 5, 6], ["C", 1, 2], ["C", 4, 4], ["P", 0, 3], ["P", 2, 3], ["P", 4, 5], ["P", 8, 3]]
const POS_BLK := [["K", 4, 9], ["A", 3, 9], ["A", 5, 9], ["E", 2, 9], ["E", 6, 9], ["H", 1, 7], ["H", 7, 9], ["R", 8, 8],
	["R", 3, 5], ["C", 7, 7], ["C", 1, 5], ["P", 0, 6], ["P", 4, 6], ["P", 6, 6], ["P", 8, 6]]
## Animation Nguoi cho từng trạng thái của hai ông
const MAN_ANIM := {"danh_co": "viec_rieng", "suyt": "noi", "mang": "sot_ruot", "reo": "vui"}
## Clip một lần riêng của hai ông (suyt 1 s, mang 1,5 s, reo 2 s); model cũ chưa có thì mượn MAN_ANIM
const ONE_SHOT_ANIM := ["suyt", "mang", "reo"]
## Người xem có xương (idle "xem", reo khi chiếu tướng); chưa có file thì dựng khối tạm
const SPECTATOR_IDS := ["xemco", "dicho1", "dicho2", "xemco", "dicho3"]
const SKIN := Color("#E7B98F")
const PANTS := Color("#3D4A4A")
const PAVING := [Color("#A8A396"), Color("#97928A")]
const CROWD := [Color("#3D5A80"), Color("#E39C7A"), Color("#7FB7A4"), Color("#F2E3B8"), Color("#A9C7E8")]

var player: Node3D
var hud: CanvasLayer
## Đang giao đơn góc cờ (chỉ lúc này hai ông mới để ý Bơ).
var active := false
## Đơn này đã bị hai ông mắng (mất 1 sao).
var scolded := false
var shushes := 0
## Đang trong 2 giây sau chiếu tướng.
var distracted := false
var delivered := false
var checks := 0                 ## số lần chiếu tướng từ lúc vào cảnh (test đếm)

var _rng := RandomNumberGenerator.new()
var _check_t := 0.0
var _window_t := 0.0
var _shush_cd := 0.0
var _scold_cd := 0.0
var _checker := 0               ## ông nào vừa chiếu (0 Bảy, 1 Tám)
var _men: Array = []            # {"person", "speech", "state", "t", "speech_t"}
var _crowd: Array = []          # {"node", "arm_l", "arm_r", "phase"}
var _pieces: Array = []         # {"node", "base", "fallen"}
var _rattle := 0.0
var _turn := 0
var _turn_t := 0.0
var _bag: Node3D
var _crowd_label: Label3D


func _init() -> void:
	name = "GocCoTuong"
	_rng.seed = 742
	_check_t = _rng.randf_range(float(DoKho.v("check_every_min", CHECK_EVERY.x)), float(DoKho.v("check_every_max", CHECK_EVERY.y)))


# ---------------------------------------------------------------- dựng cảnh

## Phần đứng yên: cây lớn, ghế nhựa, ghế đẩu để ấm trà. Gọi trước Blocks.merge_static.
## Bàn cờ có va chạm nhưng cũng đứng yên nên dựng ở đây; quân cờ, người, ấm trà dựng trong _ready.
static func build_static(parent: Node3D) -> void:
	var c := CENTER
	# Gốc cây lớn phía tây nam bàn, tán che cả góc
	var trunk := StaticBody3D.new()
	trunk.collision_layer = Blocks.LAYER_PROP
	trunk.position = c + Vector3(-1.7, 0, 1.7)
	parent.add_child(trunk)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.32
	cyl.bottom_radius = 0.48
	cyl.height = 3.4
	cyl.radial_segments = 12
	cyl.rings = 1
	Blocks.mesh(trunk, cyl, Vector3(0, 1.7, 0), Color("#6E4A2F"))
	var crown := SphereMesh.new()
	crown.radius = 2.8
	crown.height = 3.6
	crown.radial_segments = 14
	crown.rings = 7
	Blocks.mesh(trunk, crown, Vector3(0.6, 4.6, -0.6), Color("#4E8F4A"))
	var ts := CollisionShape3D.new()
	var tcs := CylinderShape3D.new()
	tcs.radius = 0.45
	tcs.height = 3.4
	ts.shape = tcs
	ts.position.y = 1.7
	trunk.add_child(ts)
	# Vòng sơn trắng quanh gốc cây như trong phác thảo
	var band := CylinderMesh.new()
	band.top_radius = 0.43
	band.bottom_radius = 0.47
	band.height = 0.5
	band.radial_segments = 12
	band.rings = 1
	Blocks.mesh(trunk, band, Vector3(0, 0.6, 0), Color("#F4F1EA"))
	# Sân lát gạch hai màu dưới gốc cây (chỗ hai ông ngồi hằng ngày)
	for ix in 6:
		for iz in 5:
			var tile := Blocks.box(parent, Vector3(0.6, 0.02, 0.6), c + Vector3(-1.7 + ix * 0.6, 0.06, -0.9 + iz * 0.6), PAVING[(ix + iz) % 2])
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	build_furniture(parent)
	Blocks.label(parent, "3. Ông Bảy, Ông Tám\nGóc cờ", c + Vector3(0, 3.0, 0), 40)


## Bàn đá, bàn cờ gỗ, hai ghế đá, ghế đẩu và ấm trà (model thật, va chạm bằng hộp/trụ riêng).
static func build_furniture(parent: Node3D) -> void:
	var c := CENTER
	var table := Blocks.collider(parent, TABLE_SIZE, c + Vector3(0, TABLE_SIZE.y / 2.0, 0), Blocks.LAYER_PROP)
	table.add_to_group("ban_co")
	PhoModels.put(parent, MODELS + "ban_da", c)
	PhoModels.put(parent, MODELS + "ban_co_go", c + Vector3(0, TABLE_SIZE.y, 0), PI / 2)  # cạnh dài nằm giữa hai ông
	for sx in [-1, 1]:
		var seat := Blocks.collider(parent, Vector3(0.34, 0.32, 0.34), c + Vector3(sx * 0.62, 0.16, 0), Blocks.LAYER_PROP)
		seat.name = "GheDa"
		PhoModels.put(parent, MODELS + "ghe_da", c + Vector3(sx * 0.62, 0, 0))
	Blocks.collider(parent, Vector3(0.3, TEA_TOP, 0.26), TEA + Vector3(0, TEA_TOP / 2.0, 0), Blocks.LAYER_PROP)
	PhoModels.put(parent, MODELS + "ghe_dau", TEA)
	PhoModels.put(parent, MODELS + "am_tra", TEA + Vector3(0, TEA_TOP, 0))


func _ready() -> void:
	_notice = DoKho.v("chess_notice", NOTICE_RADIUS)
	var c := CENTER
	# Hai ông: Ông Bảy phía tây nhìn sang đông, Ông Tám phía đông nhìn sang tây (model Nguoi nhìn về +Z)
	_men.append(_man("ongbay", c + Vector3(-0.62, STOOL_TOP - float(Nguoi.SEAT.get("ongbay", 0.28)), 0), PI / 2))
	_men.append(_man("ongtam", c + Vector3(0.62, STOOL_TOP - float(Nguoi.SEAT.get("ongtam", 0.28)), 0), -PI / 2))
	# Người xem chen một phía (phía nam, quay mặt về bàn)
	var spots := [Vector3(-0.85, 0, 1.0), Vector3(-0.35, 0, 1.15), Vector3(0.15, 0, 1.05), Vector3(0.65, 0, 1.2), Vector3(1.05, 0, 0.75)]
	for k in spots.size():
		var sid: String = SPECTATOR_IDS[k]
		if ResourceLoader.exists("res://assets/models/nguoi/%s.glb" % sid):
			_crowd.append(_rigged_spectator(sid, c + spots[k]))
		else:
			_crowd.append(_spectator(c + spots[k], CROWD[k], 0.9 + 0.08 * (k % 3), k * 1.3))
	_crowd_label = Blocks.label(self, "", c + Vector3(0.3, 2.35, 1.3), 34, Color("#F2C14E"))
	_crowd_label.visible = false
	# 30 quân cờ theo thế cờ trong phác thảo; bàn cờ xoay 90° nên hàng chạy theo trục X
	for side in 2:
		var red := side == 0
		for e in (POS_RED if red else POS_BLK):
			var node := Node3D.new()
			node.position = c + Vector3(4.5 * GRID - float(e[2]) * GRID, BOARD_TOP, 4.0 * GRID - float(e[1]) * GRID)
			node.rotation.y = PI / 2 if red else -PI / 2  # chữ quay về phía người cầm quân
			add_child(node)
			var mi := PhoModels.put(node, MODELS + "quan_%s_%s" % ["do" if red else "den", PIECE_FILE[e[0]]], Vector3.ZERO)
			mi.visibility_range_end = 25.0  # quân cờ nhỏ, xa thì thôi vẽ
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_pieces.append({"node": node, "base": node.position, "yaw": node.rotation.y, "fallen": false})
	# Túi bánh nằm lại cạnh ấm trà khi giao xong
	_bag = Node3D.new()
	_bag.position = TEA + Vector3(0.3, 0, 0)  # trên nền gạch, bên phải khay trà (phía đông ghế đẩu)
	add_child(_bag)
	Blocks.box(_bag, Vector3(0.16, 0.1, 0.1), Vector3(0, 0.05, 0), Color("#F4F1EA"))
	Blocks.box(_bag, Vector3(0.2, 0.05, 0.05), Vector3(0, 0.12, 0), Color("#D98E2B"))
	_bag.visible = false


## Một ông ngồi ghế đá đánh cờ (model Nguoi có xương). Va chạm là thân tĩnh riêng.
func _man(id: String, pos: Vector3, yaw: float) -> Dictionary:
	var body := StaticBody3D.new()
	body.collision_layer = Blocks.LAYER_PROP
	body.position = pos
	body.rotation.y = yaw
	add_child(body)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.5, 1.1, 0.6)
	shape.shape = bs
	shape.position = Vector3(0, 0.55, 0.1)
	body.add_child(shape)
	var person := Nguoi.make(id, MAN_ANIM.danh_co)
	person.position = pos
	person.rotation.y = yaw
	add_child(person)
	# Thoại hai ông lệch về hai phía, cao thấp khác nhau để không đè lên nhau khi cùng mắng
	var speech := Blocks.label(self, "", pos + Vector3(signf(pos.x - CENTER.x) * 0.35, 1.65 if pos.x < CENTER.x else 2.0, 0), 36, Color("#FFF8EA"))
	speech.visible = false
	return {"person": person, "speech": speech, "state": "danh_co", "t": 0.0, "speech_t": 0.0}


func _spectator(pos: Vector3, shirt: Color, height: float, phase: float) -> Dictionary:
	var body := StaticBody3D.new()
	body.collision_layer = Blocks.LAYER_PROP
	body.position = pos
	add_child(body)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.45, 1.6 * height, 0.3)
	shape.shape = bs
	shape.position.y = 0.8 * height
	body.add_child(shape)
	var node := Node3D.new()
	node.position = pos
	node.scale = Vector3.ONE * height
	add_child(node)
	Blocks.box(node, Vector3(0.42, 0.8, 0.28), Vector3(0, 0.4, 0), PANTS)
	Blocks.box(node, Vector3(0.48, 0.6, 0.3), Vector3(0, 1.1, 0), shirt)
	var hs := SphereMesh.new()
	hs.radius = 0.16
	hs.height = 0.32
	hs.radial_segments = 10
	hs.rings = 5
	Blocks.mesh(node, hs, Vector3(0, 1.58, 0), SKIN)
	var arms := []
	for sx in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.29, 1.36, 0)
		node.add_child(arm)
		Blocks.box(arm, Vector3(0.09, 0.5, 0.09), Vector3(0, -0.24, 0), shirt)
		arms.append(arm)
	return {"node": node, "base": pos, "arm_l": arms[0], "arm_r": arms[1], "phase": phase}


## Người xem model Nguoi đứng quay mặt vào bàn (model nhìn về +Z).
func _rigged_spectator(id: String, pos: Vector3) -> Dictionary:
	var person := Nguoi.make(id, "xem")
	person.name = "Xem_%d" % _crowd.size()
	person.position = pos
	person.rotation.y = atan2(CENTER.x - pos.x, CENTER.z - pos.z)
	add_child(person)
	person.add_collision(Vector3(0.45, 1.6, 0.3), Vector3(0, 0.8, 0))
	return {"person": person}


## Gọi sau add_child: nối Bơ để nghe tiếng động.
func setup(p: Node3D, h: CanvasLayer = null) -> void:
	player = p
	hud = h
	if player and player.has_signal("noise_made") and not player.noise_made.is_connected(_on_noise):
		player.noise_made.connect(_on_noise)
	for m in _men:
		(m.person as Nguoi).look_target = player  # quay đầu nhìn Bơ khi lại gần


# ---------------------------------------------------------------- vòng đơn

## Bơ vừa nhận bánh đơn góc cờ.
func begin_order() -> void:
	active = true
	scolded = false
	shushes = 0
	delivered = false
	_bag.visible = false
	for pc in _pieces:
		_reset_piece(pc)


## Đặt túi cạnh ấm trà. Trả true nếu đặt đúng lúc chiếu tướng (nhiệm vụ phụ).
func deliver() -> bool:
	var on_check := distracted
	delivered = true
	active = false
	_say(0 if _checker == 1 else 1, "Ừ, để đó đi con." if on_check else "Cảm ơn con, để cạnh ấm trà.", 2.5)
	return on_check


## Chỗ ổ bánh Bơ nhả ra (cạnh ấm trà); show_bag() hiện túi nằm lại đó.
func bag_point() -> Vector3:
	return _bag.global_position + Vector3(0, 0.06, 0)


func show_bag() -> void:
	_bag.visible = true


func end_order() -> void:
	active = false


## Chiếu tướng ngay (test và cảnh chụp gọi; bình thường do đồng hồ trong _physics_process).
func checkmate_now() -> void:
	_check_t = _rng.randf_range(float(DoKho.v("check_every_min", CHECK_EVERY.x)), float(DoKho.v("check_every_max", CHECK_EVERY.y)))
	_window_t = float(DoKho.v("check_window", CHECK_WINDOW))
	distracted = true
	checks += 1
	_checker = _turn
	_set_state(_checker, "reo", float(DoKho.v("check_window", CHECK_WINDOW)))
	_set_state(1 - _checker, "reo", float(DoKho.v("check_window", CHECK_WINDOW)))
	for s in _crowd:
		if s.has("person"):
			(s.person as Nguoi).play_once("reo")
	_say(_checker, "Chiếu tướng!", 1.6)
	_crowd_label.text = "Hay! Hay quá!"
	_crowd_label.visible = true
	_sfx("check_cheer")
	chess_event.emit("chieu_tuong")


func _on_noise(pos: Vector3, radius: float) -> void:
	if not active or distracted:
		return
	var d := Vector2(pos.x - CENTER.x, pos.z - CENTER.z).length()
	if (radius >= BUMP_NOISE - 0.01 and d <= TABLE_RADIUS) or (radius >= SPRINT_NOISE - 0.01 and d <= _notice):
		_scold()
	elif radius >= WALK_NOISE - 0.01 and d <= _notice:
		_shush(pos)


## Đi thường lại gần: ông gần Bơ hơn quay ra suỵt, Bơ khựng 1 giây.
func _shush(from: Vector3) -> void:
	if _shush_cd > 0.0 or _scold_cd > 0.0:
		return
	_shush_cd = SHUSH_COOLDOWN
	shushes += 1
	var who := 0 if from.x < CENTER.x else 1
	_set_state(who, "suyt", 1.2)
	_say(who, "Suỵt!", 1.2)
	if float(DoKho.v("shush_stun", SHUSH_STUN)) > 0.0:
		_stun_player(float(DoKho.v("shush_stun", SHUSH_STUN)))
	_sfx("shush")
	_toast("Suỵt! Rón rén thôi (giữ Alt), hai ông đang đánh cờ.", 2.0)
	chess_event.emit("suyt")


## Chạy nhanh hoặc đụng bàn: quân cờ rung và rơi, hai ông đứng dậy mắng, mất 1 sao.
func _scold() -> void:
	if _scold_cd > 0.0:
		return
	_scold_cd = SCOLD_COOLDOWN
	scolded = true
	_rattle = 0.8
	var fell := 0
	for pc in _pieces:
		if not pc.fallen and fell < 2 and _rng.randf() < 0.5:
			_drop_piece(pc)
			fell += 1
	_set_state(0, "mang", 1.8)
	_set_state(1, "mang", 1.8)
	_say(0, "Ê con mèo này!", 1.8)
	_say(1, "Đổ bàn cờ bây giờ!", 1.8)
	_stun_player(0.4)
	_sfx("chess_rattle")
	_sfx("scold_%d" % _rng.randi_range(1, 2))  # 1–2 giọng Ông Bảy, 3–4 Ông Tám
	get_tree().create_timer(0.5).timeout.connect(func(): _sfx("scold_%d" % _rng.randi_range(3, 4)))
	_toast("Hai ông mắng rồi: đơn này mất 1 sao!", 2.2)
	chess_event.emit("mang")


func _drop_piece(pc: Dictionary) -> void:
	pc.fallen = true
	var n: Node3D = pc.node
	var away := Vector3(n.position.x - CENTER.x, 0, n.position.z - CENTER.z).normalized()
	if away == Vector3.ZERO:
		away = Vector3.FORWARD
	var land := n.position + away * _rng.randf_range(0.35, 0.6)
	land.y = CENTER.y + 0.07  # trên sân gạch
	var tw := create_tween()
	tw.tween_property(n, "position", n.position + away * 0.15 + Vector3.UP * 0.12, 0.15)
	tw.tween_property(n, "position", land, 0.25).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(n, "rotation:x", PI * 0.5, 0.25)


func _reset_piece(pc: Dictionary) -> void:
	pc.fallen = false
	pc.node.position = pc.base
	pc.node.rotation = Vector3(0, pc.yaw, 0)


func _stun_player(seconds: float) -> void:
	if player == null:
		return
	if "_stun" in player:
		player._stun = maxf(player._stun, seconds)
	if player is CharacterBody3D:
		player.velocity.x = 0.0
		player.velocity.z = 0.0


# ---------------------------------------------------------------- mỗi nhịp

func _physics_process(delta: float) -> void:
	_shush_cd = maxf(_shush_cd - delta, 0.0)
	_scold_cd = maxf(_scold_cd - delta, 0.0)
	if distracted:
		_window_t -= delta
		if _window_t <= 0.0:
			distracted = false
			_crowd_label.visible = false
	else:
		_check_t -= delta
		if _check_t <= 0.0:
			checkmate_now()
	# Chạy nhanh sát bàn mà không có bước chân nào (vd. trượt tới) vẫn tính là đụng bàn
	if active and not distracted and player and player is CharacterBody3D:
		var d := Vector2(player.global_position.x - CENTER.x, player.global_position.z - CENTER.z).length()
		var hs := Vector2(player.velocity.x, player.velocity.z).length()
		if d <= TABLE_RADIUS * 0.75 and hs > 6.5:
			_scold()


func _process(delta: float) -> void:
	_turn_t += delta
	if _turn_t > 3.2:  # hai ông thay phiên đi nước cờ
		_turn_t = 0.0
		_turn = 1 - _turn
		_nudge_piece()
	for k in _men.size():
		_animate_man(k, delta)
	_animate_crowd(delta)
	if _rattle > 0.0:
		_rattle = maxf(_rattle - delta, 0.0)
		for pc in _pieces:
			if not pc.fallen:
				pc.node.position = pc.base + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.006 * (_rattle / 0.8)


func _nudge_piece() -> void:
	var standing := _pieces.filter(func(pc): return not pc.fallen)
	if standing.is_empty() or _rattle > 0.0:
		return
	var pc: Dictionary = standing[_rng.randi() % standing.size()]
	var step := Vector3(_rng.randi_range(-1, 1), 0, _rng.randi_range(-1, 1)) * GRID
	var target: Vector3 = pc.base + step
	if absf(target.x - CENTER.x) > 4.5 * GRID or absf(target.z - CENTER.z) > 4.0 * GRID:
		return
	pc.base = target
	var tw := create_tween()
	tw.tween_property(pc.node, "position", target, 0.25).set_delay(0.5)
	tw.tween_callback(_sfx.bind("chess_slap"))  # quân cờ đập xuống bàn


func _set_state(k: int, state: String, seconds: float) -> void:
	var m: Dictionary = _men[k]
	m.state = state
	m.t = seconds
	var person: Nguoi = m.person
	if state in ONE_SHOT_ANIM and person.anim and person.anim.has_animation(state):
		person.play_once(state)  # tự về viec_rieng khi hết clip
	else:
		person.play(MAN_ANIM[state], 0.2)


func _say(k: int, text: String, seconds: float) -> void:
	var m: Dictionary = _men[k]
	var l: Label3D = m.speech
	l.text = text
	l.visible = true
	m.speech_t = seconds


## Hết thời gian của suỵt / mắng / reo thì quay lại đánh cờ. Thoại tắt sau speech_t giây.
func _animate_man(k: int, delta: float) -> void:
	var m: Dictionary = _men[k]
	m.t = maxf(m.t - delta, 0.0)
	if m.t <= 0.0 and m.state != "danh_co":
		_set_state(k, "danh_co", 0.0)
	m.speech_t = maxf(m.speech_t - delta, 0.0)
	m.speech.visible = m.speech_t > 0.0


func _animate_crowd(delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	var w := 1.0 - exp(-12.0 * delta)
	for s in _crowd:
		if s.has("person"):
			continue  # người có xương tự chơi animation
		var n: Node3D = s.node
		var hop := absf(sin(now * 9.0 + s.phase)) * 0.12 if distracted else 0.0
		n.position.y = lerpf(n.position.y, s.base.y + hop, w)
		var up := 2.8 if distracted else 0.15 + sin(now * 0.7 + s.phase) * 0.05
		(s.arm_l as Node3D).rotation.z = lerpf((s.arm_l as Node3D).rotation.z, -up if distracted else 0.0, w)
		(s.arm_r as Node3D).rotation.z = lerpf((s.arm_r as Node3D).rotation.z, up if distracted else 0.0, w)
		(s.arm_l as Node3D).rotation.x = lerpf((s.arm_l as Node3D).rotation.x, 0.0 if distracted else 0.6, w)  # khoanh tay xem
		(s.arm_r as Node3D).rotation.x = lerpf((s.arm_r as Node3D).rotation.x, 0.0 if distracted else 0.6, w)


# ---------------------------------------------------------------- tiện ích

func _sfx(sound_name: String) -> void:
	var s := get_node_or_null("/root/Sound")
	if s == null:
		return
	if s.has_method("play_at"):
		s.play_at(sound_name, CENTER + Vector3.UP)
	else:
		s.play(sound_name)


func _toast(text: String, seconds := 2.0) -> void:
	if hud and hud.has_method("show_toast"):
		hud.show_toast(text, seconds)
