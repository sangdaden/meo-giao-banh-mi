extends RefCounted
## Thứ Năm: dữ liệu ngày này (đơn, lời Cô Ba, đồ riêng). scripts/days.gd đọc DATA qua tên file.
## Thêm hay sửa một ngày chỉ đụng file của ngày đó; các khóa ghi ở đầu scripts/days.gd.
# Thứ Năm trưa oi (gói việc thiet-ke-man/goi-viec-thu-nam.md): giờ là số Thử thách, Thong thả ×2 qua DoKho.
# Cả ngày bám mép, đạp tường. Bốn cách giao mới shelf, shutter, loft, scene ở scripts/thu_nam.gd.
# Đơn 5 "scene": tới cổng LÔ B thì sang cảnh chung_cu.tscn (đồng hồ apartment_time), giao xong quay về phố.
const DATA := {
	"nodes": ["res://scripts/thu_nam.gd"],
	"title": "Lên tầng năm",
	"blurb": "Trưa oi, cả ngày leo trèo: bám mép lên nóc tủ báo, đạp tường qua khe hông tiệm xe, rồi leo chung cư lên tầng 5 cho Bé Na.",
	"intro": "Cô Ba: \"Trưa nay nóng quá Bơ ơi. Đơn chót lên tận tầng năm cho Bé Na, leo nổi không con?\"",
	"time_mult": 1.0,
	"extras": {"climb_all_day": true, "noon": true},
	"orders": [
		{"who": "Chú Tư", "place": "Sạp báo", "item": "1 ổ pate", "pos": Vector3(-2.3, 0, -6.0), "time": 18.0, "color": Color("#3D5A80"), "delivery": "shelf", "side_quest": "tu_ngu_yen"},
		{"who": "Anh Hùng", "place": "Sửa xe", "item": "3 ổ xíu mại", "pos": Vector3(31.8, 0, 23.0), "time": 24.0, "color": Color("#5E6F6C"), "delivery": "shutter", "side_quest": "dap_lien"},
		{"who": "Cô Hai", "place": "Tạp hóa", "item": "1 bịch đá cục", "kind": "errand", "errand_item": "da", "pos": Vector3(7.8, 0, -18.9), "time": 22.0, "color": Color("#E39C7A"), "delivery": "errand_da", "side_quest": "da_con_nua"},
		{"who": "Chị Mây", "place": "Cà phê Mây", "item": "2 ổ thịt nguội + 1 ly đá", "pos": Vector3(7.5, 0, 5.4), "time": 22.0, "color": Color("#7FB7A4"), "delivery": "loft", "side_quest": "len_gac"},
		{"who": "Bé Na", "place": "Chung cư, căn 5B-1", "item": "2 ổ trứng", "kind": "deliver", "pos": ThuNam.GATE, "time": 30.0, "color": Color("#D7A9C4"), "delivery": "scene", "side_quest": "em_be_ngu_yen"},
	],
}
