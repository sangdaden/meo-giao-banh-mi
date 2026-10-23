extends RefCounted
## Thứ Sáu: dữ liệu ngày này (đơn, lời Cô Ba, đồ riêng). scripts/days.gd đọc DATA qua tên file.
## Thêm hay sửa một ngày chỉ đụng file của ngày đó; các khóa ghi ở đầu scripts/days.gd.
# Thứ Sáu chiều tà (gói việc thiet-ke-man/goi-viec-thu-sau.md): giờ là số Thử thách, Thong thả ×2 qua DoKho.
# Ba cách giao mới call, lift, gio_table ở scripts/thu_sau.gd. Đơn "gio": ngậm túi 3 ổ tới nhà Bà Sáu.
# Thong thả 6 ổ / 2 chuyến, mỗi chuyến giờ riêng. Thử thách (orders_hard) 10 ổ / 4 chuyến, đơn "gio_group"
# dùng chung đồng hồ gio_shared_time giây. Cảnh tiệm xe, sân giỗ là khối tạm chờ model G6, G7.
const DATA := {
	"nodes": ["res://scripts/thu_sau.gd"],
	"title": "Đám giỗ Bà Sáu",
	"blurb": "Chiều tan tầm: gọi khách bằng tiếng meo, cầu nâng tiệm xe, rồi chạy nhiều chuyến bánh cho đám giỗ nhà Bà Sáu.",
	"intro": "Cô Ba: \"Chiều nay giỗ ông nhà Bà Sáu, cô làm thêm cả mâm bánh. Bơ chạy mấy chuyến giùm cô nha, thằng Mực bữa nay thức hoài đó!\"",
	"time_mult": 1.0,
	"extras": {"evening": true, "gio": true, "dog_alert": true},
	"orders": [
		{"who": "Chị Mây", "place": "Cà phê Mây", "item": "2 ổ thịt nguội", "pos": Vector3(5.4, 0, 4.6), "time": 20.0, "color": Color("#7FB7A4"), "delivery": "call", "side_quest": "goi_mot_tieng"},
		{"who": "Anh Hùng", "place": "Sửa xe", "item": "3 ổ xíu mại", "pos": ThuSau.LIFT_SPOT, "time": 26.0, "color": Color("#5E6F6C"), "delivery": "lift", "side_quest": "truoc_goi_hai"},
		{"who": "Cô Hai", "place": "Tạp hóa", "item": "1 bó nhang + hộp đèn cầy", "kind": "errand", "errand_item": "nhang", "pos": Vector3(7.8, 0, -18.9), "time": 22.0, "color": Color("#E39C7A"), "delivery": "errand_nhe", "side_quest": "khong_dung_nguoi"},
		{"who": "Bà Sáu", "place": "Nhà bông giấy", "item": "3 ổ chả cá (chuyến 1)", "pos": ThuSau.GIO_GATE, "time": 24.0, "color": Color("#C8412F"), "delivery": "call", "side_quest": "muc_ngu_yen", "boss": true, "gio": true},
		{"who": "Bà Sáu", "place": "Nhà bông giấy", "item": "3 ổ chả cá + mâm nhang (chuyến 2)", "pos": ThuSau.GIO_TABLE, "time": 24.0, "color": Color("#C8412F"), "delivery": "gio_table", "side_quest": "vao_tu_gian", "boss": true, "gio": true, "dog_start": "peek"},
	],
	"orders_hard": [
		{"who": "Chị Mây", "place": "Cà phê Mây", "item": "2 ổ thịt nguội", "pos": Vector3(5.4, 0, 4.6), "time": 20.0, "color": Color("#7FB7A4"), "delivery": "call", "side_quest": "goi_mot_tieng"},
		{"who": "Anh Hùng", "place": "Sửa xe", "item": "3 ổ xíu mại", "pos": ThuSau.LIFT_SPOT, "time": 26.0, "color": Color("#5E6F6C"), "delivery": "lift", "side_quest": "truoc_goi_hai"},
		{"who": "Cô Hai", "place": "Tạp hóa", "item": "1 bó nhang + hộp đèn cầy", "kind": "errand", "errand_item": "nhang", "pos": Vector3(7.8, 0, -18.9), "time": 22.0, "color": Color("#E39C7A"), "delivery": "errand_nhe", "side_quest": "khong_dung_nguoi"},
		{"who": "Bà Sáu", "place": "Nhà bông giấy", "item": "3 ổ chả cá (chuyến 1)", "pos": ThuSau.GIO_GATE, "time": 120.0, "color": Color("#C8412F"), "delivery": "call", "side_quest": "muc_ngu_yen", "boss": true, "gio": true, "gio_group": true},
		{"who": "Bà Sáu", "place": "Nhà bông giấy", "item": "3 ổ chả cá + mâm nhang (chuyến 2)", "pos": ThuSau.GIO_TABLE, "time": 120.0, "color": Color("#C8412F"), "delivery": "gio_table", "side_quest": "vao_tu_gian", "boss": true, "gio": true, "gio_group": true, "dog_start": "peek"},
		{"who": "Bà Sáu", "place": "Nhà bông giấy", "item": "2 ổ chả cá (chuyến 3)", "pos": ThuSau.GIO_GATE, "time": 120.0, "color": Color("#C8412F"), "delivery": "call", "boss": true, "gio": true, "gio_group": true},
		{"who": "Bà Sáu", "place": "Nhà bông giấy", "item": "2 ổ chả cá (chuyến 4)", "pos": ThuSau.GIO_TABLE, "time": 120.0, "color": Color("#C8412F"), "delivery": "gio_table", "boss": true, "gio": true, "gio_group": true},
	],
}
