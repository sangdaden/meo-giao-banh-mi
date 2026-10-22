extends TroThi
## Trò 2 · Nhảy chồng thùng cạnh ghế đá: mỗi tầng chồng cao thêm 0,4 m, thùng trên cùng lắc.
## Bậc thùng bên cạnh dẫn lên tới sát đỉnh, Bơ nhảy lên thùng trên cùng lúc nó đứng yên và đứng vững 1 giây.
## Đáp lúc thùng đang lắc mạnh thì rớt. Đối thủ: Bột (chắc chân, lên tới tầng 5), Lạc (nhảy kém, tầng 2, cổ vũ to nhất).
## Thong thả: 3 lần thử mỗi tầng (crate_tries), vòng chỉ nhịp đáp (crate_ring). Thử thách: 1 lần, không vòng nhịp.

const SPOT := Vector3(-25.5, 0, 23.0)   ## chân chồng thùng (công viên khối 4, cạnh ghế đá)
const STEP_DIR := Vector3(1.0, 0, 0)    ## bậc thùng xếp về phía đông
const CRATE := 0.4
const TIERS := 6
const WOBBLE_HZ := 0.45
const CALM := 0.45                       ## |lắc| dưới mức này (0..1) là lúc đáp được
const HOLD := 1.0
const RIVAL_BEST := {"bot": 5, "lac": 2}

var tier := 1
var tries_left := 0
var best := 0
var _stack: Node3D
var _top: Node3D
var _ring: MeshInstance3D
var _wob := 0.0
var _on_top := 0.0
var _was_air := false
var _cool := 0.0


func title() -> String:
	return "Nhảy chồng thùng"


func rule() -> String:
	return "Nhảy lên thùng trên cùng lúc nó đứng yên. Mỗi tầng cao thêm 0,4 m."


func begin() -> void:
	tier = 1
	best = 0
	_build_tier()
	put_player(SPOT + Vector3(-1.6, 0, 0.6), SPOT)
	for id in ["bot", "lac"]:
		var m := cat(id)
		m.stop()
		m.global_position = SPOT + Vector3(-1.4, 0, -1.0 - (0.8 if id == "lac" else 0.0))
		m.face(SPOT)
		m.set_pose("ngoi")
	toast("Nhảy chồng thùng! Leo bậc rồi nhảy lên thùng trên cùng lúc nó đứng yên%s." % (" (vòng xanh)" if _ring_on() else ""), 4.0)


func _ring_on() -> bool:
	return bool(DoKho.v("crate_ring", false))


func _top_y() -> float:
	return SPOT.y + CRATE * tier


func _build_tier() -> void:
	if _stack:
		_stack.queue_free()
	_stack = Node3D.new()
	add_child(_stack)
	_stack.global_position = SPOT
	tries_left = int(DoKho.v("crate_tries", 1))
	# Chồng chính: tier-1 thùng đứng yên + thùng trên cùng lắc (hình), va chạm là hộp tĩnh cả chồng
	for k in tier - 1:
		_crate(_stack, Vector3(0, CRATE * k + CRATE / 2.0, 0))
	_top = Node3D.new()
	_stack.add_child(_top)
	_top.position = Vector3(0, CRATE * (tier - 1), 0)
	_crate(_top, Vector3(0, CRATE / 2.0, 0), Color("#C98B4A"))
	Blocks.collider(_stack, Vector3(0.7, CRATE * tier, 0.7), Vector3(0, CRATE * tier / 2.0, 0), Blocks.LAYER_PROP)
	# Bậc thang thùng tới sát đỉnh (mỗi bậc thấp hơn bậc sau 0,4 m)
	for s in tier - 1:
		var h := CRATE * (s + 1)
		var c := STEP_DIR * (0.85 * (tier - 1 - s))
		Blocks.solid_box(_stack, Vector3(0.75, h, 0.75), c + Vector3(0, h / 2.0, 0), Color("#A5784A"), Blocks.LAYER_PROP)
	if _ring_on():
		_ring = TroThi.ring(_stack, SPOT + Vector3(0, _top_y() - 0.03, 0), Color("#7DB46C"), 0.55)
	Blocks.label(_stack, "Tầng %d" % tier, Vector3(0.9, _top_y() + 0.9, 0.6), 24)
	_rivals_try()


func _crate(parent: Node3D, pos: Vector3, color := Color("#B5814E")) -> void:
	var m := Blocks.box(parent, Vector3(0.7, CRATE - 0.02, 0.7), pos, color)
	Blocks.box(m, Vector3(0.72, 0.05, 0.72), Vector3(0, CRATE / 2.0 - 0.05, 0), Color("#8A5E33"))


## Bột, Lạc thử tầng này (diễn nhanh: nhảy lên rồi xuống, hoặc rớt).
func _rivals_try() -> void:
	var lines := []
	for id in ["bot", "lac"]:
		var ok: bool = tier <= RIVAL_BEST[id]
		lines.append("%s %s" % [MeoNpc.CAST[id].ten, "qua" if ok else "rớt"])
		var m := cat(id)
		if m:
			m.say("Qua tầng %d!" % tier if ok else ("Ối, rớt rồi! Cố lên Bơ ơi!" if id == "lac" else "Hụt rồi!"), 2.5)
			m.play("nhay" if ok else "truot_chan")
	toast("Tầng %d: %s. Tới lượt Bơ!" % [tier, ", ".join(lines)], 2.5)


func tick(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	_wob = sin(clock * TAU * WOBBLE_HZ)
	var amp := 0.06 + 0.025 * tier
	if _top:
		_top.rotation.z = _wob * amp
		_top.rotation.x = cos(clock * TAU * WOBBLE_HZ * 0.7) * amp * 0.4
	var calm := absf(_wob) < CALM
	if _ring:
		_ring.visible = calm
	var p := player.global_position
	var on_top := player.is_on_floor() and TroThi.flat_dist(p, SPOT) < 0.45 and absf(p.y - _top_y()) < 0.2
	if on_top and _was_air and _cool <= 0.0 and not calm:
		_fall()
		return
	_was_air = not player.is_on_floor()
	_on_top = _on_top + delta if on_top else 0.0
	if _on_top >= HOLD:
		_clear()


func _fall() -> void:
	_cool = 1.0
	_on_top = 0.0
	player.knockback(SPOT + STEP_DIR * 0.3, 3.0, 0.5)
	tries_left -= 1
	if tries_left <= 0:
		_end()
	else:
		toast("Thùng lắc quá, rớt rồi! Còn %d lần thử. Đợi thùng đứng yên rồi nhảy." % tries_left, 2.5)


func _clear() -> void:
	best = tier
	_on_top = 0.0
	cat("lac").say("Hay quá Bơ ơiii!", 2.0)
	if tier >= TIERS:
		_end()
		return
	tier += 1
	toast("Qua tầng %d! Chồng thêm một thùng." % best, 2.0)
	_build_tier()
	put_player(SPOT + STEP_DIR * (0.85 * tier + 0.6), SPOT)


func _end() -> void:
	var rank := 1
	for id in RIVAL_BEST:
		if RIVAL_BEST[id] > best:
			rank += 1
	if _stack:
		_stack.queue_free()
		_stack = null
	finish(rank, "lên tới tầng %d" % best)


func goal() -> Vector3:
	return SPOT + Vector3(0, _top_y(), 0) if running else Vector3.INF


func status() -> String:
	return "Tầng %d/%d · còn %d lần thử · cao nhất: tầng %d" % [tier, TIERS, tries_left, best]


## Bot: đứng lên đỉnh lúc thùng yên, qua đủ 6 tầng.
func bot(_delta: float) -> void:
	if int(clock * 60.0) % 15 != 0 or _on_top > 0.0:
		return
	if absf(_wob) < CALM * 0.6:
		put_player(SPOT + Vector3(0, _top_y() + 0.05, 0))
		_was_air = false
