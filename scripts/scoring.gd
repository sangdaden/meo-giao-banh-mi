class_name Scoring
## Chấm điểm một ngày giao bánh: sao từng đơn, tiền boa, hạng ngày, tem Cô Ba, kỷ lục và lưu game.
## Luật lấy từ trang thiết kế màn chơi (mục 09, 10), Sang duyệt 21/10/2026.
## main.gd gọi begin_day() lúc bắt đầu, order_done() mỗi lần giao, end_day() khi hết 5 đơn.

## ★ giao kịp giờ, ★★ còn từ 35% thời gian, ★★★ thêm bánh nguyên vẹn và ổ bếp từ 2 sao.
const TWO_STAR_RATIO := 0.35
const KITCHEN_STARS_FOR_THREE := 2
## Trễ giờ thì khách vẫn nhận nhưng chỉ được 1 sao, không có tiền boa.
const LATE_STARS := 1
const TIP_PER_STAR := 5000
const TIP_SIDE_QUEST := 3000
const TIP_PERFECT_DAY := 20000  # Cô Ba thưởng khi đủ 15 sao
const STARS_PER_ORDER := 3
## Ổ bánh 3 sao bếp cho thêm 2 giây vào đúng đơn đó.
const KITCHEN_BONUS_SECONDS := 2.0
const STAMPS_PER_DAY := 5
## Hạng của ngày theo tổng sao: thường dưới 8, giòn 8–12, vàng từ 13.
const RANKS := [["vang", 13, "Bánh mì vàng"], ["gion", 8, "Bánh mì giòn"], ["thuong", 0, "Bánh mì thường"]]
## Tên hiển thị của nhiệm vụ phụ (id do khóa "side_quest" của đơn trong scripts/days.gd đặt).
const SIDE_QUEST_NAMES := {
	"bao_co_ba": "Ngậm tờ báo về cho Cô Ba",
	"gio_nhip_dau": "Bỏ bánh vào giỏ ngay nhịp đầu",
	"khong_do_ly": "Không đổ ly nào",
	"khong_dau": "Không giẫm vũng dầu",
	"muc_ngu_yen": "Để Chó Mực ngủ yên",
	"em_be_ngu_yen": "Để em bé tầng 3 ngủ yên",
	# Thứ Ba (gói việc thiet-ke-man/goi-viec-thu-ba.md)
	"kip_xe_om": "Giao trước khi khách xe ôm tới",
	"du_6_trung": "Về lò còn đủ 6 quả trứng",
	"dat_luc_chieu": "Đặt túi lúc chiếu tướng",
	"khong_dung_nguoi": "Không đụng người đi chợ nào",
	"khong_do_thung": "Không làm đổ thúng nào",
}

static var orders: Array = []  # kết quả từng đơn trong ngày, mỗi phần tử là Dictionary
static var stamps_today: Array = []  # chỉ số tem nhặt được trong lần chơi này
static var _ghosts: Dictionary = {}  # order_index -> PackedVector3Array lần chạy này


static func begin_day(which := "thu_hai") -> void:
	GameState.day = which
	orders.clear()
	stamps_today.clear()
	_ghosts.clear()


## Sao bếp của ổ thứ i (0–3), -1 nếu chưa chơi màn bếp (khi đó không xét điều kiện bếp).
static func kitchen_star_for(i: int) -> int:
	var per := GameState.kitchen_stars_per_bread
	if i >= 0 and i < per.size():
		return per[i]
	if GameState.from_kitchen:
		return GameState.kitchen_stars
	return -1


## Số giây cộng vào đồng hồ của đơn i nhờ màn bếp.
static func bonus_seconds(i: int) -> float:
	if GameState.kitchen_stars_per_bread.is_empty():
		return GameState.kitchen_bonus  # màn bếp chưa chấm từng ổ: giữ cách cộng chung cũ
	return KITCHEN_BONUS_SECONDS if kitchen_star_for(i) >= 3 else 0.0


## Tính sao cho một đơn mà không ghi lại (dùng cho cả HUD lẫn tự kiểm tra).
## info: {time_ratio: 0..1 thời gian còn lại, late: bool, intact: bool, kitchen_star: int, side_quest_ok: bool}
static func stars_for(info: Dictionary) -> int:
	if info.get("late", false) or float(info.get("time_ratio", 0.0)) <= 0.0:
		return LATE_STARS
	if float(info.get("time_ratio", 0.0)) < TWO_STAR_RATIO:
		return 1
	var ks: int = int(info.get("kitchen_star", -1))
	var kitchen_ok := ks < 0 or ks >= KITCHEN_STARS_FOR_THREE
	return 3 if info.get("intact", true) and kitchen_ok else 2


static func tip_for(stars: int, late: bool, side_ok: bool) -> int:
	if late:
		return 0
	return stars * TIP_PER_STAR + (TIP_SIDE_QUEST if side_ok else 0)


## Ghi kết quả một đơn. info như stars_for, thêm time (giây đã chạy) và side_quest (id, có thể rỗng).
## Trả về Dictionary để main.gd hiện toast và gửi cho bảng kết quả.
static func order_done(order_index: int, info: Dictionary) -> Dictionary:
	var late: bool = info.get("late", false) or float(info.get("time_ratio", 0.0)) <= 0.0
	var stars := stars_for(info)
	var side_id: String = info.get("side_quest", "")
	var side_ok: bool = side_id != "" and info.get("side_quest_ok", false)
	var time: float = info.get("time", 0.0)
	var best: float = _best_times()[order_index] if order_index < _best_times().size() else -1.0
	var r := {
		"index": order_index,
		"stars": stars,
		"late": late,
		"intact": info.get("intact", true),
		"kitchen_stars": int(info.get("kitchen_star", -1)),
		"side_quest": SIDE_QUEST_NAMES.get(side_id, side_id),
		"side_ok": side_ok,
		"tip": tip_for(stars, late, side_ok),
		"time": time,
		"best_time": best,
		"new_best": not late and (best < 0.0 or time < best),
	}
	while orders.size() <= order_index:
		orders.append({})
	orders[order_index] = r
	return r


## Ghi đường chạy của đơn (lấy mẫu 10 lần/giây) để làm bóng mờ nếu đây là lần nhanh nhất.
static func set_ghost(order_index: int, path: PackedVector3Array) -> void:
	_ghosts[order_index] = path


## Bóng mờ lần nhanh nhất đã lưu của đơn, rỗng nếu chưa có.
static func best_ghost(order_index: int) -> PackedVector3Array:
	var all: Dictionary = GameState.get_day("bong_mo", {})
	return all.get(order_index, PackedVector3Array())


static func best_time(order_index: int) -> float:
	var t := _best_times()
	return t[order_index] if order_index < t.size() else -1.0


static func _best_times() -> Array:
	return GameState.get_day("ky_luc_don", [])


static func total_stars() -> int:
	var n := 0
	for r in orders:
		n += int(r.get("stars", 0))
	return n


static func rank_of(stars: int) -> String:
	for r in RANKS:
		if stars >= r[1]:
			return r[0]
	return "thuong"


static func rank_name(rank: String) -> String:
	for r in RANKS:
		if r[0] == rank:
			return r[2]
	return rank


# ---------------------------------------------------------------- tem Cô Ba

## Tem đã nhặt của ngày (qua mọi lần chơi). Nhặt rồi thì không hiện lại.
static func stamps_collected() -> Array:
	return GameState.get_day("tem", [])


static func collect_stamp(i: int) -> int:
	var got: Array = stamps_collected().duplicate()
	if i not in got:
		got.append(i)
		got.sort()
		GameState.set_day("tem", got)
		GameState.write_save()  # lưu ngay, lỡ người chơi tắt giữa chừng
	if i not in stamps_today:
		stamps_today.append(i)
	return got.size()


# ---------------------------------------------------------------- kết thúc ngày

## Tổng kết ngày, cập nhật kỷ lục và ghi file lưu. Trả về summary cho hud.show_results.
static func end_day(stars_max := 15) -> Dictionary:
	var stars := total_stars()
	var tip := 0
	for r in orders:
		tip += int(r.get("tip", 0))
	var bonus := TIP_PERFECT_DAY if stars >= stars_max else 0
	tip += bonus
	var rank := rank_of(stars)

	var best_total: int = GameState.get_day("sao_cao_nhat", -1)
	var new_record := stars > best_total
	if new_record:
		GameState.set_day("sao_cao_nhat", stars)
	GameState.set_day("boa_cao_nhat", maxi(int(GameState.get_day("boa_cao_nhat", 0)), tip))
	if _rank_value(rank) > _rank_value(GameState.get_day("hang_cao_nhat", "")):
		GameState.set_day("hang_cao_nhat", rank)
	GameState.set_day("so_lan_choi", int(GameState.get_day("so_lan_choi", 0)) + 1)

	var wallet := _save_orders(tip)
	GameState.write_save()
	GameState.write_star_record(stars)

	return {
		"stars": stars,
		"stars_max": stars_max,
		"tip": tip,
		"bonus": bonus,
		"rank": rank,
		"stamps": stamps_today.size(),
		"stamps_total": STAMPS_PER_DAY,
		"stamps_all": GameState.stamps_all(),
		"new_record": new_record,
		"day": GameState.DAY_NAMES.get(GameState.day, GameState.day),
		"wallet": wallet,
	}


## Lưu phần riêng từng đơn (kỷ lục giây, bóng mờ, sao cao nhất, huy hiệu) và cộng ví. Trả về ví mới.
static func _save_orders(tip: int) -> int:
	# Kỷ lục từng đơn (giây nhanh nhất, -1 là chưa có) và bóng mờ đi kèm
	var times: Array = _best_times().duplicate()
	var ghosts: Dictionary = (GameState.get_day("bong_mo", {}) as Dictionary).duplicate()
	for r in orders:
		var i: int = r.get("index", 0)
		while times.size() <= i:
			times.append(-1.0)
		if r.get("new_best", false):
			times[i] = r.time
			if _ghosts.has(i):
				ghosts[i] = _ghosts[i]
	GameState.set_day("ky_luc_don", times)
	# Sao cao nhất từng đơn, màn Chọn màn hiện cạnh từng đơn
	var best_stars: Array = (GameState.get_day("sao_don", []) as Array).duplicate()
	for r in orders:
		if r.is_empty():
			continue
		var i: int = r.get("index", 0)
		while best_stars.size() <= i:
			best_stars.append(0)
		best_stars[i] = maxi(int(best_stars[i]), int(r.get("stars", 0)))
	GameState.set_day("sao_don", best_stars)
	GameState.set_day("bong_mo", ghosts)

	# Huy hiệu nhiệm vụ phụ (giữ qua mọi lần chơi) và ví tiền boa để mở phụ kiện
	var badges: Array = (GameState.get_day("huy_hieu", []) as Array).duplicate()
	for r in orders:
		if r.get("side_ok", false) and r.side_quest not in badges:
			badges.append(r.side_quest)
	GameState.set_day("huy_hieu", badges)
	var wallet: int = int(GameState.get_global("vi_tien_boa", 0)) + tip
	GameState.set_global("vi_tien_boa", wallet)
	return wallet


## Chơi một đơn lẻ ở màn Chọn màn: lưu kỷ lục đơn và tiền boa, không tính kỷ lục cả ngày.
static func end_practice() -> Dictionary:
	var played := orders.filter(func(r): return not r.is_empty())  # order_done chừa chỗ trống cho các đơn trước
	var stars := total_stars()
	var tip := 0
	for r in played:
		tip += int(r.get("tip", 0))
	var wallet := _save_orders(tip)
	GameState.write_save()
	var one: Dictionary = played[0] if played.size() == 1 else {}
	return {
		"stars": stars,
		"stars_max": STARS_PER_ORDER * played.size(),
		"tip": tip,
		"rank": (["thuong", "thuong", "gion", "vang"][clampi(stars, 0, 3)]) if not one.is_empty() else rank_of(stars),
		"stamps": stamps_today.size(),
		"stamps_total": STAMPS_PER_DAY,
		"stamps_all": GameState.stamps_all(),
		"new_record": one.get("new_best", false) and float(one.get("best_time", -1.0)) >= 0.0,
		"day": GameState.DAY_NAMES.get(GameState.day, GameState.day),
		"wallet": wallet,
	}


## Sao cao nhất đã đạt ở đơn i (0 nếu chưa giao lần nào).
static func best_stars(order_index: int, which := "") -> int:
	var a: Array = GameState.get_day("sao_don", [], which)  # which rỗng = ngày đang chơi
	return int(a[order_index]) if order_index < a.size() else 0


static func _rank_value(rank: String) -> int:
	return {"thuong": 1, "gion": 2, "vang": 3}.get(rank, 0)


## Kiểm tra nhanh luật chấm điểm (autotest gọi). Không đụng file lưu.
static func self_test() -> bool:
	var cases := [
		[{"time_ratio": 0.6, "intact": true, "kitchen_star": 3}, 3],
		[{"time_ratio": 0.6, "intact": true, "kitchen_star": 1}, 2],
		[{"time_ratio": 0.6, "intact": false, "kitchen_star": 3}, 2],
		[{"time_ratio": 0.6, "intact": true, "kitchen_star": -1}, 3],
		[{"time_ratio": 0.35, "intact": true, "kitchen_star": 2}, 3],
		[{"time_ratio": 0.2, "intact": true, "kitchen_star": 3}, 1],
		[{"time_ratio": 0.0, "late": true, "intact": true, "kitchen_star": 3}, 1],
	]
	var ok := true
	for c in cases:
		if stars_for(c[0]) != c[1]:
			push_error("Scoring: %s ra %d sao, cần %d" % [c[0], stars_for(c[0]), c[1]])
			ok = false
	# Ngày hoàn hảo: 15 sao x 5.000 + 5 nhiệm vụ phụ x 3.000 + 20.000 = 110.000đ
	var best := 5 * tip_for(3, false, true) + TIP_PERFECT_DAY
	ok = ok and best == 110000 and tip_for(1, true, true) == 0
	ok = ok and rank_of(7) == "thuong" and rank_of(8) == "gion" and rank_of(12) == "gion" and rank_of(13) == "vang"
	if not ok:
		push_error("Scoring: tiền boa hoặc hạng sai")
	return ok
