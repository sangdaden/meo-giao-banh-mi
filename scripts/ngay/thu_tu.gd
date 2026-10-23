extends RefCounted
## Thứ Tư: dữ liệu ngày này (đơn, lời Cô Ba, đồ riêng). scripts/days.gd đọc DATA qua tên file.
## Thêm hay sửa một ngày chỉ đụng file của ngày đó; các khóa ghi ở đầu scripts/days.gd.
# Gói việc thiet-ke-man/goi-viec-thu-tu.md. Khóa riêng Thứ Tư (scripts/thu_tu.gd đọc):
#   flood: Vector2(mức nước m, giây) dâng/rút lúc nhận đơn · pigeons: "roof" | "street" · clear: tạnh mưa
#   rooftop_hint: nhắc đường sân thượng. Cô Hai nhận ở cửa sau tạp hóa (cuối cầu thang sắt), cách giao
#   "counter_shop" chưa có cảnh riêng nên deliveries.gd dựng Cô Hai đứng chờ.
const DATA := {
	"nodes": ["res://scripts/thu_tu.gd"],
	"title": "Mưa chiều",
	"blurb": "Mưa lớn, đường ngập dần. Đi đường sân thượng, giữ thăng bằng trên ván, tránh xe tạt nước và đàn bồ câu.",
	"intro": "Cô Ba: \"Mưa lớn rồi Bơ ơi, bánh cô bọc ni-lông kỹ rồi. Đường lớn sắp ngập, lên sân thượng mà đi cho khô nha!\"",
	"time_mult": 1.0,
	"extras": {"rain": true, "rooftop": true, "pigeons": true},
	"orders": [
		{"who": "Chị Mây", "place": "Cà phê Mây", "item": "2 ổ thịt nguội", "pos": Vector3(5.4, 0, 5.4), "time": 20.0, "color": Color("#7FB7A4"), "delivery": "counter", "side_quest": "duoi_mai_hien"},
		{"who": "Cô Hai", "place": "Tạp hóa", "item": "1 ổ pate", "note": "nhieu_do_chua", "pos": Vector3(7.8, 0, -16.0), "time": 22.0, "color": Color("#E39C7A"), "delivery": "counter_shop", "side_quest": "van_vung", "flood": Vector2(0.12, 20.0), "rooftop_hint": true},
		{"who": "Bé Na", "place": "Chung cư", "item": "2 ổ trứng", "pos": Vector3(24.0, 0, -15.6), "time": 24.0, "color": Color("#D7A9C4"), "delivery": "basket", "side_quest": "bo_cau_yen", "pigeons": "roof"},
		{"who": "Chú Năm", "place": "Xe ôm đầu hẻm 42", "item": "1 ổ thịt nguội", "note": "khong_ot", "pos": Vector3(-17.5, 0, 10.0), "time": 24.0, "color": Color("#4F7FA8"), "delivery": "on_seat", "side_quest": "khong_bi_tat", "flood": Vector2(0.25, 15.0)},
		{"who": "Chú Tư", "place": "Sạp báo", "item": "2 ổ chả cá", "pos": Vector3(-1, 0, -6), "time": 18.0, "color": Color("#3D5A80"), "delivery": "hand", "side_quest": "khong_truot", "flood": Vector2(0.0, 20.0), "pigeons": "street", "clear": true},
	],
	# Bảng "Cách chơi" trong menu Esc: phím chung + các dòng này (scripts/ui/chu_huong_dan.gd)
	"help": [["E", "giao bánh"]],
	"help_note": "Mưa lớn, đường ngập dần: leo lên sân thượng mà đi. Trên ván hẹp Bơ tự đi chậm, đừng giữ Shift kẻo chao. Tránh xe tạt nước và đàn bồ câu.",
}
