extends RefCounted
## Chủ Nhật: dữ liệu ngày này (đơn, lời Cô Ba, đồ riêng). scripts/days.gd đọc DATA qua tên file.
## Thêm hay sửa một ngày chỉ đụng file của ngày đó; các khóa ghi ở đầu scripts/days.gd.
# Chủ Nhật Hội mèo (gói việc thiet-ke-man/goi-viec-chu-nhat.md): sáng một đơn khay bánh không tính giờ
# ("time": 0), tối Hội mèo do scripts/chu_nhat.gd lo (main.hand_off), 5 trò ở scripts/hoi_meo/.
const DATA := {
	"nodes": ["res://scripts/chu_nhat.gd"],
	"title": "Hội mèo",
	"mode": "festival",
	"blurb": "Sáng mang khay bánh mì mini tới công viên. Tối Hội mèo: đua mái nhà, nhảy thùng, trốn tìm, giao tiếp sức, thi trang phục. Không ai thua!",
	"intro": "Cô Ba: \"Tối nay hội mèo đó Bơ! Mình làm khay bánh mì mini mang tới góp vui nha.\"",
	"time_mult": 1.0,
	"extras": {"festival": true},
	"orders": [
		{"who": "Bà Mướp", "place": "Công viên khối 4", "item": "1 khay bánh mì mini", "pos": Vector3(-33.0, 0, 21.0), "time": 0.0, "color": Color("#8E8A80"), "delivery": "tray"},
	],
}
