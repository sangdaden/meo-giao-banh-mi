extends RefCounted
## Thứ Hai: dữ liệu ngày này (đơn, lời Cô Ba, đồ riêng). scripts/days.gd đọc DATA qua tên file.
## Thêm hay sửa một ngày chỉ đụng file của ngày đó; các khóa ghi ở đầu scripts/days.gd.
const DATA := {
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
		{"who": "Bà Sáu", "place": "Nhà bông giấy", "item": "1 ổ chả cá", "pos": CityProps.BA_SAU_CHAIR, "time": 24.0, "color": Color("#C8412F"), "delivery": "chair", "side_quest": "muc_ngu_yen", "boss": true},
	],
}
