class_name DoKho
## Độ khó của game ở một chỗ. Mặc định là "Thong thả" (Sang 21/10: game phải dễ và thân thiện hơn).
## "Thử thách" giữ nguyên các con số cũ của từng màn, bật ở Cài đặt > Chế độ thử thách.
## Mỗi chỗ dùng gọi DoKho.v("khóa", số_cũ): Thong thả trả số trong bảng EASY, Thử thách trả số cũ.
## Bảng so sánh trước/sau: trang "Chơi thong thả" (thiet-ke-man/de-tho.html).

const EASY := {
	# Đồng hồ và sao
	"order_time_mult": 2.0,      # thời gian mỗi đơn ×2 (Thứ Hai 18–30 s thành 36–60 s)
	"two_star_ratio": 0.0,       # ★★ chỉ cần giao kịp giờ
	"three_star_ratio": 0.25,    # ★★★ còn từ 25% giờ và bánh nguyên vẹn, không đòi sao bếp
	"late_tip": 5000,            # trễ giờ vẫn được 1 sao và 5.000đ boa
	"bread_cool": 90.0,          # bánh nguội hẳn sau 90 s (chỉ để nhìn)
	"fall_break_height": 4.0,    # rơi từ trên 4 m mới mất sao nguyên vẹn
	# Chó Mực
	"bite_penalty": 0.0,         # bị đớp không mất giây, chỉ mất sao nguyên vẹn
	"dog_sleep": 8.0,
	"dog_peek": 1.5,
	"dog_see": 6.0,
	"dog_confirm": 2.5,
	"dog_calm": 2.0,
	"dog_chase_speed": 5.0,      # bằng Bơ đi bộ, chạy nhanh là thoát
	"dog_leash": 10.0,
	# Xe máy
	"hit_strength": 6.0,         # hất khoảng 0,8 m
	"hit_stun": 0.4,
	# Giỏ Bé Na, xe ôm Chú Năm
	"basket_period_mult": 1.4,   # giỏ đưa chậm hơn
	"basket_reach": 0.7,
	"basket_retry": 0.5,
	"xe_om_away": 4.0,
	# Góc cờ
	"chess_notice": 2.0,
	"shush_stun": 0.0,           # bị suỵt chỉ nghe tiếng, không khựng
	"chess_scold_star": false,   # bị mắng chỉ mất nhiệm vụ phụ, không mất sao
	"check_every_min": 6.0,
	"check_every_max": 8.0,
	"check_window": 3.0,
	# Túi trứng
	"fragile_fall": 2.0,         # đáp từ trên 2 m mới vỡ
	"fragile_bump_speed": 6.0,   # chỉ va khi đang chạy nhanh mới vỡ
	"eggs_lose_at": 1,           # còn 1 quả trở xuống ổ trứng mới mất sao (Thử thách: 3)
	# Chợ
	"market_bump_stun": 0.15,
	"spill_speed": 6.5,          # chỉ chạy nhanh đụng thúng mới đổ
	"market_walkers": 10,
	# Leo chung cư (bếp: luồng "Thiết kế lại màn bếp" tự đọc DoKho.hard())
	"apartment_time": 90.0,
}


## Bài tự kiểm tra đặt tạm: 1 = ép Thử thách, -1 = ép Thong thả, 0 = theo Cài đặt.
static var force := 0


## true khi người chơi bật Chế độ thử thách ở Cài đặt.
static func hard() -> bool:
	if force != 0:
		return force > 0
	return bool(GameSettings.get_value("thu_thach"))


static func v(key: String, hard_value: Variant) -> Variant:
	if hard() or not EASY.has(key):
		return hard_value
	return EASY[key]
