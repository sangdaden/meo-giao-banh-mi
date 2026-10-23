extends RefCounted
## Thứ Bảy: dữ liệu ngày này (đơn, lời Cô Ba, đồ riêng). scripts/days.gd đọc DATA qua tên file.
## Thêm hay sửa một ngày chỉ đụng file của ngày đó; các khóa ghi ở đầu scripts/days.gd.
# Thứ Bảy dạo phố (gói việc thiet-ke-man/goi-viec-thu-bay.md): "mode": "free" = không có đơn giao, không đồng hồ,
# không sao. scripts/thu_bay.gd lo phần chơi: Sổ hàng xóm (scripts/so_hang_xom.gd), mỗi việc nhờ một file trong
# scripts/viec_nho/, chương Chó Mực (scripts/muc_ban.gd), chụp ảnh P (scripts/chup_anh.gd).
# Khóa của một việc nhờ: id (trùng file viec_nho/<id>.gd và id người dân), page (trang sổ), who, place,
# task (dòng việc trên sổ), skill, gift (id phụ kiện, "cong_thuc" = công thức mới), gift_name, pose (dáng Bơ trong ảnh chung).
const DATA := {
	"nodes": ["res://scripts/thu_bay.gd"],
	"title": "Dạo phố",
	"blurb": "Không có đồng hồ: đi giúp hàng xóm, chụp ảnh, và làm bạn với Chó Mực.",
	"intro": "Cô Ba: \"Thứ Bảy rồi, cô cho Bơ nghỉ! Cầm cuốn sổ này đi chơi một vòng, ai cần gì thì giúp người ta nha.\"",
	"mode": "free",
	"time_mult": 1.0,
	"extras": {"no_timer": true, "muc_friend": true},
	"orders": [],
	"favours": [
		{"id": "coba", "page": 1, "who": "Cô Ba", "place": "Lò bánh", "task": "Chọn 3 nhân cho ổ \"bánh mì Bơ\"", "skill": "bếp", "gift": "cong_thuc", "gift_name": "Công thức mới", "pose": "chup_dung"},
		{"id": "chutu", "page": 2, "who": "Chú Tư", "place": "Sạp báo", "task": "Đuổi theo tờ báo bị gió thổi lên mái hiên", "skill": "nhảy, mái hiên, bám mép", "gift": "kinhcan", "gift_name": "Kính cận", "pose": "chup_vay"},
		{"id": "bena", "page": 3, "who": "Bé Na", "place": "Chung cư", "task": "Trốn tìm: tìm Bé Na 3 lần", "skill": "leo, bám mép", "gift": "nobuom", "gift_name": "Nơ bướm", "pose": "chup_vay"},
		{"id": "may", "page": 4, "who": "Chị Mây", "place": "Cà phê Mây", "task": "Làm mèo mẫu: tạo 3 dáng theo bảng", "skill": "chụp ảnh", "gift": "lycaphe", "gift_name": "Ly cà phê đội đầu", "pose": "chup_dung"},
		{"id": "hung", "page": 5, "who": "Anh Hùng", "place": "Tiệm sửa xe", "task": "Tìm 4 con ốc lăn dưới gầm xe", "skill": "chui", "gift": "kinhbaoho", "gift_name": "Kính bảo hộ", "pose": "chup_nam"},
		{"id": "basau", "page": 6, "who": "Bà Sáu", "place": "Nhà bông giấy", "task": "Hái 5 chùm bông giấy trên giàn", "skill": "leo, thăng bằng", "gift": "hoadambut", "gift_name": "Hoa dâm bụt", "pose": "chup_dung"},
		{"id": "ongbay", "page": 7, "who": "Ông Bảy, Ông Tám", "place": "Góc cờ", "task": "Tìm 3 quân cờ lăn mất, đừng làm đổ ấm trà", "skill": "rón rén", "gift": "nonphot", "gift_name": "Nón phớt", "pose": "chup_nam"},
		{"id": "cohai", "page": 8, "who": "Cô Hai", "place": "Tạp hóa", "task": "Xếp lại tháp 6 lon trước tiệm", "skill": "nhảy, đẩy", "gift": "khanran", "gift_name": "Khăn rằn", "pose": "chup_vay"},
		{"id": "chunam", "page": 9, "who": "Chú Năm", "place": "Xe ôm đầu hẻm", "task": "Lấy mũ bảo hiểm khách bỏ quên trên mái hiên", "skill": "mái hiên", "gift": "mubaohiem", "gift_name": "Mũ bảo hiểm", "pose": "chup_dung"},
		{"id": "chithu", "page": 10, "who": "Chị Thu", "place": "Chung cư tầng 3", "task": "Ru em bé: nằm cạnh võng kêu rừ rừ", "skill": "rón rén", "gift": "chuong", "gift_name": "Vòng chuông", "pose": "chup_nam"},
	],
	# Bảng "Cách chơi" trong menu Esc: phím chung + các dòng này (scripts/ui/chu_huong_dan.gd)
	"help": [["E", "giúp người có dấu !"], ["Tab", "mở Sổ hàng xóm"], ["P", "chụp ảnh"], ["Space", "bám mép, đạp tường"]],
	"help_note": "Không đồng hồ, không thua. Chó Mực nằm buồn cuối hẻm 42, không đuổi ai: giúp vài người rồi hỏi Bà Sáu.",
}
