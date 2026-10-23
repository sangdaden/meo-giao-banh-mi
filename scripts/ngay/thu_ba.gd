extends RefCounted
## Thứ Ba: dữ liệu ngày này (đơn, lời Cô Ba, đồ riêng). scripts/days.gd đọc DATA qua tên file.
## Thêm hay sửa một ngày chỉ đụng file của ngày đó; các khóa ghi ở đầu scripts/days.gd.
# Số giây trong bảng gói việc đã là Thứ Hai × 0,92, nên time_mult giữ 1.0 để khỏi nhân hai lần.
# Chỗ đứng của Chú Năm, Cô Hai, góc cờ là tạm; các gói T3-2/3/4/6 dời theo bố cục chợ, tạp hóa, góc cờ.
const DATA := {
	"nodes": ["res://scripts/market.gd"],
	"title": "Chợ đông",
	"blurb": "Chợ tạm chiếm đường lớn, hàng rong chặn hẻm. Có đơn mua trứng về lò và đơn cho hai ông đánh cờ.",
	"intro": "Cô Ba: \"Bữa nay chợ đông lắm Bơ ơi. Lò hết trứng rồi, ghé Cô Hai mua giùm cô một túi nha!\"",
	"time_mult": 1.0,
	"extras": {"market": true, "chess_corner": true, "shop_tap_hoa": true, "dog_sleeps_at_alley_mouth": true},
	"orders": [
		{"who": "Chú Năm", "place": "Xe ôm đầu hẻm 42", "item": "1 ổ thịt nguội", "note": "khong_ot", "pos": Vector3(-17.5, 0, 10.0), "time": 17.0, "color": Color("#4F7FA8"), "delivery": "on_seat", "side_quest": "kip_xe_om"},
		{"who": "Cô Hai", "place": "Tạp hóa", "item": "1 túi 6 trứng", "kind": "errand", "errand_item": "trung6", "quick_assemble": true, "pos": Vector3(7.8, 0, -18.9), "time": 25.0, "color": Color("#E39C7A"), "delivery": "errand", "side_quest": "du_6_trung"},
		{"who": "Ông Bảy, Ông Tám", "place": "Góc cờ công viên", "item": "1 ổ pate, 1 ổ trứng", "pos": ChessCorner.DROP, "time": 22.0, "color": Color("#7A8B5A"), "delivery": "beside_tea", "side_quest": "dat_luc_chieu"},
		{"who": "Bé Na", "place": "Chung cư", "item": "2 ổ trứng", "note": "them_pate", "pos": Vector3(24.0, 0, -15.6), "time": 22.0, "color": Color("#D7A9C4"), "delivery": "basket", "basket_period": 2.0, "side_quest": "khong_dung_nguoi"},
		{"who": "Anh Hùng", "place": "Sửa xe", "item": "3 ổ xíu mại", "pos": Vector3(30.6, 0, 25.3), "time": 28.0, "color": Color("#5E6F6C"), "delivery": "under_car", "side_quest": "khong_do_thung"},
	],
}
