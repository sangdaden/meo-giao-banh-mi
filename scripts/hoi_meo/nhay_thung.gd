extends TroThi
## Trò 2 · Nhảy chồng thùng (G11 chong_thung.glb, công viên khối 4 mé tây): 6 cột thùng xếp bậc, cột N cao 0,4·N m,
## cách nhau 0,62 m. Tới lượt tầng N thì cột N lắc (clip lac_N); Bơ đứng ở cột N−1, nhảy sang cột N đúng lúc
## nó yên (khung 0,77–0,9 s của nhịp 0,9 s, vòng nhịp vong_nhip trên mặt thùng chỉ lúc đáp) rồi đứng vững 1 giây.
## Đáp lúc thùng đang lắc thì rớt. Đối thủ: Bột (chắc chân, lên tới tầng 5), Lạc (nhảy kém, tầng 2, cổ vũ to nhất).
## Thong thả: 3 lần thử mỗi tầng (crate_tries), có vòng nhịp (crate_ring), khung đáp rộng ±0,25 s (crate_land_tol).
## Thử thách: 1 lần, không vòng, đúng khung 0,77–0,9 s.

const SPOT := ChuNhat.CRATES             ## gốc model chồng thùng, quay 90° (cột 1 ở nam, cột 6 ở bắc)
const ROT := PI / 2.0
const CRATE := 0.4
const PITCH := 0.62
const TIERS := 6
const BEAT := 0.9                         ## một nhịp lắc (s)
const CALM_FROM := 0.77                   ## khung đáp vững trong nhịp
const CALM_TO := 0.9
const HOLD := 1.0
const RIVAL_BEST := {"bot": 5, "lac": 2}

var tier := 1
var tries_left := 0
var best := 0
var _model: Node3D
var _ring: Node3D
var _beat_t := 0.0
var _on_top := 0.0
var _was_air := false
var _landed_ok := false   ## đã đáp lên cột đích lúc nó yên (rớt thì phải nhảy lại)
var _cool := 0.0


func title() -> String:
	return "Nhảy chồng thùng"


func rule() -> String:
	return "Nhảy sang cột thùng kế tiếp lúc nó đứng yên. Mỗi cột cao thêm 0,4 m."


func build() -> void:
	_model = DoHoi.put(self, "chong_thung", SPOT, ROT)
	DoHoi.anim(_model, "yen")
	for n in TIERS:
		var h := CRATE * (n + 1)
		Blocks.collider(self, Vector3(0.56, h, 0.56), column(n + 1) + Vector3(0, h / 2.0, 0), Blocks.LAYER_PROP)
	_ring = DoHoi.put(self, "vong_nhip", Vector3.ZERO)
	_ring.visible = false


## Tâm chân cột n (1…6) trên mặt đất.
func column(n: int) -> Vector3:
	return SPOT + Vector3(-1.55 + PITCH * (n - 1), 0, 0).rotated(Vector3.UP, ROT)


## Chỗ đứng trên cột n (0 = đất trước cột 1).
func _stand_spot(n: int) -> Vector3:
	if n <= 0:
		return column(1) + (column(1) - column(2)).normalized() * 1.0
	return column(n) + Vector3(0, CRATE * n, 0)


func begin() -> void:
	tier = 1
	best = 0
	_start_tier()
	put_player(_stand_spot(0), column(1))
	for id in ["bot", "lac"]:
		var m := cat(id)
		m.stop()
		m.global_position = SPOT + Vector3(1.4, 0, 1.6 + (0.8 if id == "lac" else 0.0))
		m.face(SPOT)
		m.set_pose("ngoi")
	toast("Nhảy chồng thùng! Nhảy sang cột thùng đang lắc đúng lúc nó đứng yên%s." % (" (vòng sáng)" if _ring_on() else ""), 4.0)


func _ring_on() -> bool:
	return bool(DoKho.v("crate_ring", false))


func _top_y() -> float:
	return SPOT.y + CRATE * tier


func _start_tier() -> void:
	tries_left = int(DoKho.v("crate_tries", 1))
	_beat_t = 0.0
	DoHoi.anim(_model, "lac_%d" % tier, 1.2 / BEAT)  # clip lắc dài 1,2 s, chạy khớp nhịp 0,9 s
	_ring.global_position = column(tier) + Vector3(0, _top_y() + 0.001, 0)
	DoHoi.anim(_ring, "nhip", 1.0333 / BEAT)
	_rivals_try()


## Thùng đích đang yên (đáp được) không.
func _calm() -> bool:
	var tol := float(DoKho.v("crate_land_tol", 0.0))
	var t := fposmod(_beat_t, BEAT)
	return (t >= CALM_FROM - tol and t <= CALM_TO + tol) or (t + BEAT <= CALM_TO + tol)


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
	_beat_t += delta
	_ring.visible = _ring_on()
	var p := player.global_position
	var on_top := player.is_on_floor() and TroThi.flat_dist(p, column(tier)) < 0.4 and absf(p.y - _top_y()) < 0.2
	if on_top and _was_air and _cool <= 0.0:
		if not _calm():
			_fall()
			return
		_landed_ok = true
	if not on_top:
		_landed_ok = false
	# Cột cao hơn chưa tới lượt: đẩy nhẹ về, không mất lượt thử
	if player.is_on_floor() and _was_air and _cool <= 0.0 and tier < TIERS:
		for n in range(tier + 1, TIERS + 1):
			if TroThi.flat_dist(p, column(n)) < 0.4 and absf(p.y - CRATE * n) < 0.2:
				_cool = 1.0
				put_player(_stand_spot(tier), column(tier + 1))
				toast("Chưa tới lượt cột %d! Đứng vững trên cột %d trước đã." % [n, tier], 2.0)
				break
	_was_air = not player.is_on_floor()
	_on_top = _on_top + delta if on_top and _landed_ok else 0.0
	if _on_top >= HOLD:
		_clear()


func _fall() -> void:
	_cool = 1.0
	_on_top = 0.0
	_landed_ok = false
	# Thùng hất Bơ về lại cột trước (tầng 1 thì xuống đất trước chồng thùng)
	put_player(_stand_spot(tier - 1), column(tier))
	if player.has_method("play_startle"):
		player.play_startle()
	tries_left -= 1
	if tries_left <= 0:
		_end()
	else:
		toast("Thùng lắc quá, rớt rồi! Còn %d lần thử. Đợi thùng đứng yên rồi nhảy." % tries_left, 2.5)


func _clear() -> void:
	best = tier
	_on_top = 0.0
	_landed_ok = false
	cat("lac").say("Hay quá Bơ ơiii!", 2.0)
	if tier >= TIERS:
		_end()
		return
	tier += 1
	toast("Qua tầng %d! Cột kế bên lắc rồi kìa." % best, 2.0)
	_start_tier()


func _end() -> void:
	var rank := 1
	for id in RIVAL_BEST:
		if RIVAL_BEST[id] > best:
			rank += 1
	DoHoi.anim(_model, "yen")
	_ring.visible = false
	score = best
	finish(rank, "lên tới tầng %d" % best)


func goal() -> Vector3:
	return column(tier) + Vector3(0, _top_y(), 0) if running else Vector3.INF


func status() -> String:
	return "Tầng %d/%d · còn %d lần thử · cao nhất: tầng %d" % [tier, TIERS, tries_left, best]


## Bot: đứng lên cột đích lúc thùng yên, qua đủ 6 tầng.
func bot(_delta: float) -> void:
	if int(clock * 60.0) % 15 != 0 or _on_top > 0.0:
		return
	if _calm():
		put_player(column(tier) + Vector3(0, _top_y() + 0.05, 0))
		_was_air = false
		_landed_ok = true
