class_name ChessCorner
extends Node3D
## Góc cờ tướng ở công viên khối 4 cho đơn 3 Thứ Ba (gói T3-2, trang thiết kế màn chơi mục 06 và 13).
## Ông Bảy và Ông Tám ngồi ghế nhựa đỏ đánh cờ trên bàn cờ gỗ thấp dưới gốc cây lớn, ấm trà đặt trên
## ghế đẩu cạnh bàn, 5 người đứng xem chen một phía. Bơ rón rén tới đặt túi bánh cạnh ấm trà.
## - Đi thường trong vòng 3 m: một ông quay ra "suỵt", Bơ khựng 1 giây.
## - Chạy nhanh trong vòng 3 m, hoặc đụng bàn, nhảy lên bàn: quân cờ rung, rơi; hai ông đứng dậy mắng,
##   đơn mất 1 sao.
## - Mỗi 10 đến 14 giây có "chiếu tướng": cả đám reo lên, 2 giây không ai để ý Bơ.
##   Nhiệm vụ phụ: đặt túi đúng lúc này.
## Nghe tiếng động qua player.noise_made (hợp đồng gói 1), báo ra ngoài bằng chess_event(kind) với
## kind là "chieu_tuong", "suyt", "mang".
##
## Cách dùng (deliveries.gd làm sẵn khi một đơn có "delivery": "beside_tea"):
##   ChessCorner.build_static(parent) trước Blocks.merge_static (cây, ghế, ghế đẩu trà đứng yên),
##   add_child(ChessCorner.new()) sau khi gộp, rồi setup(player).
##   begin_order() lúc nhận bánh, deliver() lúc đặt túi, end_order() khi đơn xong.
## Toàn bộ là khối tạm; model bàn cờ (ban_co.glb của luồng đồ phố), hai ông, người xem và
## animation suỵt / mắng / reo / đi nước cờ chờ trang "Phác thảo Thứ Ba" được Sang duyệt.

signal chess_event(kind: String)

## Tâm bàn cờ, ở góc đông bắc công viên khối 4, gần đường lớn phía bắc (đi từ lò bánh qua là tới).
const CENTER := CityProps.CHESS_CORNER
## Ấm trà trên ghế đẩu phía bắc bàn; Bơ đứng ở DROP để đặt túi (đây là "pos" của đơn).
const TEA := Vector3(-28.8, 0, 7.75)
const DROP := Vector3(-28.8, 0, 7.15)
## Đơn 3 Thứ Ba theo hợp đồng Days (gói T3-1 chép vào days.gd, "time" trước khi nhân 0,92).
const ORDER := {
	"who": "Ông Bảy, Ông Tám", "place": "Góc cờ công viên", "item": "1 ổ pate, 1 ổ trứng",
	"pos": DROP, "time": 22.0, "color": Color("#8C6D4F"), "kind": "deliver",
	"delivery": "beside_tea", "side_quest": "dat_luc_chieu", "note": "",
}

const NOTICE_RADIUS := 3.0      ## trong vòng này hai ông nghe thấy tiếng bước chân
const TABLE_RADIUS := 1.0       ## tiếng đụng mạnh trong vòng này là đụng bàn (bàn, ghế, hai ông)
const WALK_NOISE := 6.0         ## bán kính tiếng động theo hợp đồng player.gd
const BUMP_NOISE := 8.0
const SPRINT_NOISE := 10.0
const SHUSH_STUN := 1.0         ## bị suỵt thì Bơ khựng lại bấy nhiêu giây
const SHUSH_COOLDOWN := 2.0
const SCOLD_COOLDOWN := 3.0
const CHECK_EVERY := Vector2(10.0, 14.0)  ## khoảng giữa hai lần chiếu tướng
const CHECK_WINDOW := 2.0       ## sau chiếu tướng bấy nhiêu giây không ai để ý Bơ

const TABLE_SIZE := Vector3(0.6, 0.42, 0.6)  ## như ban_co trong trang khu phố
const WOOD := Color("#9B6A3A")
const BOARD := Color("#E3C58E")
const INK_LINE := Color("#5A3D22")
const STOOL := Color("#D94F3D")
const RED_PIECE := Color("#C8412F")
const BLACK_PIECE := Color("#2B2B2B")
const PIECE_FACE := Color("#F2E3B8")
const SKIN := Color("#E7B98F")
const PANTS := Color("#3D4A4A")
const SHIRT_BAY := Color("#6E8B5A")   ## Ông Bảy áo bà ba xanh rêu
const SHIRT_TAM := Color("#C9B79C")   ## Ông Tám áo sơ mi be
const CROWD := [Color("#3D5A80"), Color("#E39C7A"), Color("#7FB7A4"), Color("#F2E3B8"), Color("#A9C7E8")]
const TABLE_GLB := "res://assets/models/pho/ban_co.glb"

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
var _men: Array = []            # {"root", "torso", "head", "arm_l", "arm_r", "speech", "state", "t", "yaw"}
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
	_check_t = _rng.randf_range(CHECK_EVERY.x, CHECK_EVERY.y)


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
	# Đất nện dưới gốc cây (chỗ hai ông ngồi hằng ngày)
	var dirt := Blocks.box(parent, Vector3(3.6, 0.02, 3.2), c + Vector3(-0.2, 0.06, 0.3), Color("#B59C77"))
	dirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Bàn cờ gỗ thấp: mặt bàn và bốn chân (va chạm một khối)
	var table := StaticBody3D.new()
	table.collision_layer = Blocks.LAYER_PROP
	table.position = c
	table.add_to_group("ban_co")
	parent.add_child(table)
	if ResourceLoader.exists(TABLE_GLB):
		var glb: PackedScene = load(TABLE_GLB)
		table.add_child(glb.instantiate())
	else:
		Blocks.box(table, Vector3(TABLE_SIZE.x, 0.04, TABLE_SIZE.z), Vector3(0, TABLE_SIZE.y - 0.02, 0), WOOD)
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				Blocks.box(table, Vector3(0.05, TABLE_SIZE.y - 0.04, 0.05), Vector3(sx * 0.26, (TABLE_SIZE.y - 0.04) / 2.0, sz * 0.26), WOOD.darkened(0.2))
		# Bàn cờ giấy kẻ 9 x 10 ô, có sông ở giữa
		Blocks.box(table, Vector3(0.5, 0.005, 0.54), Vector3(0, TABLE_SIZE.y + 0.003, 0), BOARD)
		for k in 9:
			Blocks.box(table, Vector3(0.004, 0.006, 0.48), Vector3(-0.22 + k * 0.055, TABLE_SIZE.y + 0.006, 0), INK_LINE)
		for k in 10:
			Blocks.box(table, Vector3(0.44, 0.006, 0.004), Vector3(0, TABLE_SIZE.y + 0.006, -0.24 + k * 0.053), INK_LINE)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = TABLE_SIZE
	shape.shape = bs
	shape.position.y = TABLE_SIZE.y / 2.0
	table.add_child(shape)
	# Hai ghế nhựa đỏ thấp cho hai ông (tây và đông)
	for sx in [-1, 1]:
		var stool := Blocks.solid_box(parent, Vector3(0.32, 0.26, 0.32), c + Vector3(sx * 0.62, 0.13, 0), STOOL, Blocks.LAYER_PROP)
		stool.name = "GheCo"
	# Ghế đẩu gỗ để ấm trà, phía bắc bàn
	Blocks.solid_box(parent, Vector3(0.3, 0.3, 0.3), TEA + Vector3(0, 0.15, 0), WOOD.lightened(0.1), Blocks.LAYER_PROP)
	Blocks.label(parent, "3. Ông Bảy, Ông Tám\nGóc cờ", c + Vector3(0, 3.0, 0), 40)


func _ready() -> void:
	var c := CENTER
	# Hai ông: Ông Bảy phía tây nhìn sang đông, Ông Tám phía đông nhìn sang tây
	_men.append(_man(c + Vector3(-0.62, 0, 0), -PI / 2, SHIRT_BAY, "Ông Bảy"))
	_men.append(_man(c + Vector3(0.62, 0, 0), PI / 2, SHIRT_TAM, "Ông Tám"))
	# Người xem chen một phía (phía nam, quay mặt về bàn)
	var spots := [Vector3(-0.85, 0, 1.0), Vector3(-0.35, 0, 1.15), Vector3(0.15, 0, 1.05), Vector3(0.65, 0, 1.2), Vector3(1.05, 0, 0.75)]
	for k in spots.size():
		_crowd.append(_spectator(c + spots[k], CROWD[k], 0.9 + 0.08 * (k % 3), k * 1.3))
	_crowd_label = Blocks.label(self, "", c + Vector3(0.3, 2.35, 1.3), 34, Color("#F2C14E"))
	_crowd_label.visible = false
	# Quân cờ: 5 đỏ, 5 đen rải trên bàn
	var top := c + Vector3(0, TABLE_SIZE.y + 0.012, 0)
	for k in 10:
		var col := RED_PIECE if k < 5 else BLACK_PIECE
		var gx := -0.22 + float((k * 3) % 9) * 0.055
		var gz := (-0.2 + float(k % 5) * 0.053) * (1.0 if k < 5 else -1.0)
		var node := Node3D.new()
		node.position = top + Vector3(gx, 0, gz)
		add_child(node)
		var disc := CylinderMesh.new()
		disc.top_radius = 0.022
		disc.bottom_radius = 0.022
		disc.height = 0.016
		disc.radial_segments = 10
		disc.rings = 1
		Blocks.mesh(node, disc, Vector3.ZERO, PIECE_FACE)
		Blocks.box(node, Vector3(0.018, 0.004, 0.018), Vector3(0, 0.009, 0), col)
		_pieces.append({"node": node, "base": node.position, "fallen": false})
	# Ấm trà và hai chén trên ghế đẩu
	var tea_top := TEA + Vector3(0, 0.3, 0)
	var pot := SphereMesh.new()
	pot.radius = 0.07
	pot.height = 0.11
	pot.radial_segments = 10
	pot.rings = 5
	Blocks.mesh(self, pot, tea_top + Vector3(0, 0.055, 0), Color("#8A4B2F"))
	Blocks.box(self, Vector3(0.09, 0.015, 0.015), tea_top + Vector3(0.08, 0.07, 0), Color("#8A4B2F"))  # vòi ấm
	for k in 2:
		var cup := CylinderMesh.new()
		cup.top_radius = 0.025
		cup.bottom_radius = 0.018
		cup.height = 0.035
		cup.radial_segments = 8
		cup.rings = 1
		Blocks.mesh(self, cup, tea_top + Vector3(-0.08 + k * 0.05, 0.018, 0.09), Color("#FFF8EA"))
	# Túi bánh hiện cạnh ấm trà khi giao xong
	_bag = Node3D.new()
	_bag.position = tea_top + Vector3(-0.07, 0, -0.06)
	add_child(_bag)
	Blocks.box(_bag, Vector3(0.16, 0.1, 0.1), Vector3(0, 0.05, 0), Color("#F4F1EA"))
	Blocks.box(_bag, Vector3(0.2, 0.05, 0.05), Vector3(0, 0.12, 0), Color("#D98E2B"))
	_bag.visible = false


## Một ông ngồi ghế đánh cờ, quay mặt về -Z cục bộ (yaw xoay cả người).
## Va chạm nằm ở thân tĩnh riêng; phần nhìn (thân trên, tay, đầu) có pivot để diễn.
func _man(pos: Vector3, yaw: float, shirt: Color, title: String) -> Dictionary:
	var body := StaticBody3D.new()
	body.collision_layer = Blocks.LAYER_PROP
	body.position = pos
	body.rotation.y = yaw
	add_child(body)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.5, 1.1, 0.55)
	shape.shape = bs
	shape.position = Vector3(0, 0.55, -0.05)
	body.add_child(shape)
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	Blocks.box(root, Vector3(0.4, 0.13, 0.36), Vector3(0, 0.33, -0.12), PANTS)     # đùi (ghế thấp, gối co cao)
	Blocks.box(root, Vector3(0.36, 0.3, 0.13), Vector3(0, 0.16, -0.3), PANTS)      # cẳng chân
	var torso := Node3D.new()
	torso.position = Vector3(0, 0.38, 0.04)
	root.add_child(torso)
	Blocks.box(torso, Vector3(0.44, 0.52, 0.28), Vector3(0, 0.27, 0), shirt)
	var head := Node3D.new()
	head.position = Vector3(0, 0.68, -0.02)
	torso.add_child(head)
	var hs := SphereMesh.new()
	hs.radius = 0.16
	hs.height = 0.32
	hs.radial_segments = 10
	hs.rings = 5
	Blocks.mesh(head, hs, Vector3.ZERO, SKIN)
	Blocks.box(head, Vector3(0.22, 0.04, 0.2), Vector3(0, 0.13, 0.02), Color("#DADADA"))  # tóc bạc
	var arms := []
	for sx in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.27, 0.48, 0)
		torso.add_child(arm)
		Blocks.box(arm, Vector3(0.09, 0.42, 0.09), Vector3(0, -0.2, 0), shirt)
		Blocks.box(arm, Vector3(0.09, 0.09, 0.09), Vector3(0, -0.44, 0), SKIN)
		arms.append(arm)
	# Thoại hai ông lệch về hai phía, cao thấp khác nhau để không đè lên nhau khi cùng mắng
	var speech := Blocks.label(self, "", pos + Vector3(signf(pos.x - CENTER.x) * 0.35, 1.65 if pos.x < CENTER.x else 2.0, 0), 36, Color("#FFF8EA"))
	speech.visible = false
	Blocks.label(root, title, Vector3(0, 1.45, 0), 28, Color("#F2E3B8"))
	return {"root": root, "torso": torso, "head": head, "arm_l": arms[0], "arm_r": arms[1],
		"speech": speech, "state": "danh_co", "t": 0.0, "yaw": yaw, "speech_t": 0.0}


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


## Gọi sau add_child: nối Bơ để nghe tiếng động.
func setup(p: Node3D, h: CanvasLayer = null) -> void:
	player = p
	hud = h
	if player and player.has_signal("noise_made") and not player.noise_made.is_connected(_on_noise):
		player.noise_made.connect(_on_noise)


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
	_bag.visible = true
	_say(0 if _checker == 1 else 1, "Ừ, để đó đi con." if on_check else "Cảm ơn con, để cạnh ấm trà.", 2.5)
	return on_check


func end_order() -> void:
	active = false


## Chiếu tướng ngay (test và cảnh chụp gọi; bình thường do đồng hồ trong _physics_process).
func checkmate_now() -> void:
	_check_t = _rng.randf_range(CHECK_EVERY.x, CHECK_EVERY.y)
	_window_t = CHECK_WINDOW
	distracted = true
	checks += 1
	_checker = _turn
	_set_state(_checker, "reo", CHECK_WINDOW)
	_set_state(1 - _checker, "reo", CHECK_WINDOW)
	_say(_checker, "Chiếu tướng!", 1.6)
	_crowd_label.text = "Hay! Hay quá!"
	_crowd_label.visible = true
	_sfx("chieu_tuong")
	chess_event.emit("chieu_tuong")


func _on_noise(pos: Vector3, radius: float) -> void:
	if not active or distracted:
		return
	var d := Vector2(pos.x - CENTER.x, pos.z - CENTER.z).length()
	if (radius >= BUMP_NOISE - 0.01 and d <= TABLE_RADIUS) or (radius >= SPRINT_NOISE - 0.01 and d <= NOTICE_RADIUS):
		_scold()
	elif radius >= WALK_NOISE - 0.01 and d <= NOTICE_RADIUS:
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
	_stun_player(SHUSH_STUN)
	_sfx("suyt")
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
	_sfx("quan_co_do")
	_toast("Hai ông mắng rồi: đơn này mất 1 sao!", 2.2)
	chess_event.emit("mang")


func _drop_piece(pc: Dictionary) -> void:
	pc.fallen = true
	var n: Node3D = pc.node
	var away := Vector3(n.position.x - CENTER.x, 0, n.position.z - CENTER.z).normalized()
	if away == Vector3.ZERO:
		away = Vector3.FORWARD
	var land := n.position + away * _rng.randf_range(0.35, 0.6)
	land.y = CENTER.y + 0.07
	var tw := create_tween()
	tw.tween_property(n, "position", n.position + away * 0.15 + Vector3.UP * 0.12, 0.15)
	tw.tween_property(n, "position", land, 0.25).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(n, "rotation:x", PI * 0.5, 0.25)


func _reset_piece(pc: Dictionary) -> void:
	pc.fallen = false
	pc.node.position = pc.base
	pc.node.rotation = Vector3.ZERO


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
	var step := Vector3(_rng.randi_range(-1, 1) * 0.055, 0, _rng.randi_range(-1, 1) * 0.053)
	var target: Vector3 = pc.base + step
	if absf(target.x - CENTER.x) > 0.24 or absf(target.z - CENTER.z) > 0.26:
		return
	pc.base = target
	create_tween().tween_property(pc.node, "position", target, 0.25).set_delay(0.5)


func _set_state(k: int, state: String, seconds: float) -> void:
	var m: Dictionary = _men[k]
	m.state = state
	m.t = seconds


func _say(k: int, text: String, seconds: float) -> void:
	var m: Dictionary = _men[k]
	var l: Label3D = m.speech
	l.text = text
	l.visible = true
	m.speech_t = seconds


## Khối tạm diễn bốn trạng thái: đánh cờ (thay phiên với tay ra bàn), suỵt (quay đầu, ngón tay lên môi),
## mắng (nhổm dậy, khua tay), reo (giơ hai tay).
func _animate_man(k: int, delta: float) -> void:
	var m: Dictionary = _men[k]
	m.t = maxf(m.t - delta, 0.0)
	if m.t <= 0.0:
		m.state = "danh_co"
	m.speech_t = maxf(m.speech_t - delta, 0.0)
	m.speech.visible = m.speech_t > 0.0
	var now := Time.get_ticks_msec() * 0.001
	var lift := 0.0
	var lean := 0.12
	var arm_l := 0.9   # tay đặt trên gối (đưa ra trước)
	var arm_r := 0.9
	var flap := 0.0
	var look := 0.0
	match m.state:
		"danh_co":
			if _turn == k and _turn_t < 0.9:
				arm_r = 1.2 + sin(_turn_t / 0.9 * PI) * 0.35  # với tay ra bàn đi nước
				lean = 0.25
		"suyt":
			arm_r = 2.7
			lean = -0.05
			if player:
				var to := player.global_position - (m.root as Node3D).global_position
				look = clampf(wrapf(atan2(-to.x, -to.z) - m.yaw, -PI, PI), -1.4, 1.4)
		"mang":
			lift = 0.22
			lean = -0.1
			arm_l = 2.3 + sin(now * 14.0) * 0.5
			arm_r = 2.3 + sin(now * 14.0 + 1.6) * 0.5
			flap = 0.3
		"reo":
			arm_l = 2.9 + sin(now * 10.0) * 0.15
			arm_r = 2.9 + sin(now * 10.0 + 0.5) * 0.15
			lift = 0.08 + absf(sin(now * 8.0)) * 0.05
	var w := 1.0 - exp(-14.0 * delta)
	var torso: Node3D = m.torso
	torso.position.y = lerpf(torso.position.y, 0.38 + lift, w)
	torso.rotation.x = lerpf(torso.rotation.x, -lean, w)
	(m.head as Node3D).rotation.y = lerpf((m.head as Node3D).rotation.y, look, w)
	(m.arm_l as Node3D).rotation.x = lerpf((m.arm_l as Node3D).rotation.x, arm_l, w)
	(m.arm_r as Node3D).rotation.x = lerpf((m.arm_r as Node3D).rotation.x, arm_r, w)
	(m.arm_l as Node3D).rotation.z = lerpf((m.arm_l as Node3D).rotation.z, -flap, w)
	(m.arm_r as Node3D).rotation.z = lerpf((m.arm_r as Node3D).rotation.z, flap, w)


func _animate_crowd(delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	var w := 1.0 - exp(-12.0 * delta)
	for s in _crowd:
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
