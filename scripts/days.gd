class_name Days
## Dữ liệu từng ngày trong tuần: đơn giao, hệ số thời gian, lời Cô Ba đầu ngày, đồ riêng của ngày.
## main.gd đọc ngày đang chơi qua Days.get_day(PlayMode.day); màn Chọn màn đọc để hiện danh sách đơn.
## Mã ngày trùng tên mục trong file lưu (GameState.DAY_NAMES): "thu_hai", "thu_ba", ...
## Theo trang thiết kế màn chơi (Sang duyệt 21/10/2026) và gói việc Thứ Ba (thiet-ke-man/goi-viec-thu-ba.md).
##
## Khóa của một đơn:
##   who, place, item, pos (chỗ khách), time (giây sau khi nhận), color (màu áo, màu thẻ)
##   delivery: cách giao trong deliveries.gd (hand | basket | counter | under_car | chair; ngày sau thêm
##             on_seat, beside_tea... chưa có thì deliveries.gd dựng người đứng chìa tay, bấm E đưa bánh)
##   side_quest: id nhiệm vụ phụ (tên hiển thị ở Scoring.SIDE_QUEST_NAMES)
##   boss: true nếu Chó Mực thức canh hẻm trong đơn này
##   kind: "deliver" (mặc định: nhận ở lò, giao cho khách) | "errand" (đơn ngược: tới chỗ khách lấy đồ, mang về lò)
##   note: ghi chú món trên phiếu: "" | "khong_ot" | "them_pate" | "nhieu_do_chua"
##   errand_item: món phải mang về khi kind = "errand" ("trung6" = túi 6 trứng)
##   basket_period: giây một lượt giỏ Bé Na đưa qua lại (deliveries.gd, mặc định của Thứ Hai)

## Thứ tự các ngày trong tuần
const ORDER := ["thu_hai", "thu_ba", "thu_tu", "thu_nam", "thu_sau", "thu_bay", "chu_nhat"]
## Bản chơi thử: mở sẵn mọi ngày đã làm. false thì ngày sau chỉ mở khi đã chơi xong ngày trước.
const PLAYTEST_UNLOCK_ALL := true

## Tên hiển thị của ghi chú món
const NOTE_NAMES := {"khong_ot": "không ớt", "them_pate": "thêm pate", "nhieu_do_chua": "nhiều đồ chua"}

const DATA := {
	"thu_hai": {
		"title": "Mẻ bánh đầu tiên",
		"blurb": "Làm bánh trong bếp Cô Ba rồi giao 5 đơn. Đơn cuối phải lách qua Chó Mực ở hẻm 42.",
		"intro": "Cô Ba: \"Sáng nay 5 đơn nha Bơ. Đơn chót qua hẻm 42, nhớ rón rén kẻo thằng Mực nó thức!\"",
		"time_mult": 1.0,
		"extras": {},
		"orders": [
			{"who": "Chú Tư", "place": "Sạp báo", "item": "1 ổ pate", "pos": Vector3(-1, 0, -6), "time": 18.0, "color": Color("#3D5A80"), "delivery": "hand", "side_quest": "bao_co_ba"},
			{"who": "Bé Na", "place": "Chung cư", "item": "2 ổ trứng", "pos": Vector3(24.0, 0, -15.6), "time": 24.0, "color": Color("#D7A9C4"), "delivery": "basket", "side_quest": "gio_nhip_dau"},
			{"who": "Chị Mây", "place": "Cà phê Mây", "item": "2 ổ thịt nguội", "pos": Vector3(5.4, 0, 5.4), "time": 20.0, "color": Color("#7FB7A4"), "delivery": "counter", "side_quest": "khong_do_ly"},
			{"who": "Anh Hùng", "place": "Sửa xe", "item": "3 ổ xíu mại", "pos": Vector3(30.6, 0, 25.3), "time": 30.0, "color": Color("#5E6F6C"), "delivery": "under_car", "side_quest": "khong_dau"},
			{"who": "Bà Sáu", "place": "Nhà bông giấy", "item": "1 ổ chả cá", "pos": Vector3(-19.5, 0, 22), "time": 24.0, "color": Color("#C8412F"), "delivery": "chair", "side_quest": "muc_ngu_yen", "boss": true},
		],
	},
	# Số giây trong bảng gói việc đã là Thứ Hai × 0,92, nên time_mult giữ 1.0 để khỏi nhân hai lần.
	# Chỗ đứng của Chú Năm, Cô Hai, góc cờ là tạm (góc cờ đổi sang ChessCorner.DROP khi PR góc cờ vào); các gói T3-2/3/4/6 dời theo bố cục chợ, tạp hóa, góc cờ.
	"thu_ba": {
		"title": "Chợ đông",
		"blurb": "Chợ tạm chiếm đường lớn, hàng rong chặn hẻm. Có đơn mua trứng về lò và đơn cho hai ông đánh cờ.",
		"intro": "Cô Ba: \"Bữa nay chợ đông lắm Bơ ơi. Lò hết trứng rồi, ghé Cô Hai mua giùm cô một túi nha!\"",
		"time_mult": 1.0,
		"extras": {"market": true, "chess_corner": true, "shop_tap_hoa": true, "dog_sleeps_at_alley_mouth": true},
		"orders": [
			{"who": "Chú Năm", "place": "Xe ôm đầu hẻm 42", "item": "1 ổ thịt nguội", "note": "khong_ot", "pos": Vector3(-17.5, 0, 10.0), "time": 17.0, "color": Color("#4F7FA8"), "delivery": "on_seat", "side_quest": "kip_xe_om"},
			{"who": "Cô Hai", "place": "Tạp hóa", "item": "1 túi 6 trứng", "kind": "errand", "errand_item": "trung6", "pos": Vector3(7.8, 0, -18.9), "time": 25.0, "color": Color("#E39C7A"), "delivery": "errand", "side_quest": "du_6_trung"},
			{"who": "Ông Bảy, Ông Tám", "place": "Góc cờ công viên", "item": "1 ổ pate, 1 ổ trứng", "pos": Vector3(-30.0, 0, 9.0), "time": 22.0, "color": Color("#7A8B5A"), "delivery": "beside_tea", "side_quest": "dat_luc_chieu"},
			{"who": "Bé Na", "place": "Chung cư", "item": "2 ổ trứng", "note": "them_pate", "pos": Vector3(24.0, 0, -15.6), "time": 22.0, "color": Color("#D7A9C4"), "delivery": "basket", "basket_period": 2.0, "side_quest": "khong_dung_nguoi"},
			{"who": "Anh Hùng", "place": "Sửa xe", "item": "3 ổ xíu mại", "pos": Vector3(30.6, 0, 25.3), "time": 28.0, "color": Color("#5E6F6C"), "delivery": "under_car", "side_quest": "khong_do_thung"},
		],
	},
	"thu_tu": {"title": "Trời mưa", "blurb": "Mưa trơn trượt, đi đường sân thượng và giữ thăng bằng trên mép tường."},
	"thu_nam": {"title": "Chung cư", "blurb": "Giao lên các tầng chung cư: bám mép và bật tường để leo."},
	"thu_sau": {"title": "Đám giỗ Bà Sáu", "blurb": "Ngày đông khách nhất: tiệm sửa xe và nhà Bà Sáu đặt bánh cho đám giỗ."},
	"thu_bay": {"title": "Dạo phố", "blurb": "Không có đồng hồ: đi giúp hàng xóm, chụp ảnh, và làm bạn với Chó Mực."},
	"chu_nhat": {"title": "Hội mèo", "blurb": "Năm cuộc thi với mèo cả phố: đua sân thượng, nhảy thùng, trốn tìm, giao tiếp sức, thi trang phục."},
}


## Dữ liệu một ngày: {id, name, title, blurb, intro, time_mult, extras, orders}. Ngày chưa làm có orders rỗng.
static func get_day(id: String) -> Dictionary:
	var d: Dictionary = DATA.get(id, DATA.thu_hai)
	return {
		"id": id if DATA.has(id) else "thu_hai",
		"name": GameState.DAY_NAMES.get(id, id),
		"title": d.get("title", ""),
		"blurb": d.get("blurb", ""),
		"intro": d.get("intro", ""),
		"time_mult": float(d.get("time_mult", 1.0)),
		"extras": d.get("extras", {}),
		"orders": d.get("orders", []),
	}


static func orders(id: String) -> Array:
	return get_day(id).orders


## Ngày đã làm xong phần chơi (có đơn).
static func playable(id: String) -> bool:
	return not (DATA.get(id, {}) as Dictionary).get("orders", []).is_empty()


## Ngày chơi được và đã mở: bản chơi thử mở hết; không thì phải chơi hết ngày trước ít nhất một lần.
static func unlocked(id: String) -> bool:
	if not playable(id):
		return false
	var i := ORDER.find(id)
	if PLAYTEST_UNLOCK_ALL or i <= 0:
		return true
	return int(GameState.get_day("so_lan_choi", 0, ORDER[i - 1])) > 0


## Ngày kế tiếp trong tuần ("" nếu là Chủ Nhật).
static func next_day(id: String) -> String:
	var i := ORDER.find(id)
	return ORDER[i + 1] if i >= 0 and i + 1 < ORDER.size() else ""


static func note_name(note: String) -> String:
	return NOTE_NAMES.get(note, note)
