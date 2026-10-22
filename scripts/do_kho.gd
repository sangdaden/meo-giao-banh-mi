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
	"basket_ground": true,       # Bơ kêu meo, giỏ thả xuống đất (Thử thách: nhảy lên xe máy đón giỏ đung đưa)
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
	"ledge_reach": 1.15,         # với tới mép cao 2,45 m (trước 2,2 m)
	"wall_kick_max": 4,          # đạp tường 4 lần (trước 3)
	"hang_auto_pull": 0.3,       # đang bám mép, giữ phím đi tới 0,3 s là tự leo lên (trước chỉ Space)
	"wall_gap_max": 2.0,         # khe rộng tới 2 m vẫn bật tường được (trước 1,5 m)
	"pipe_speed": 2.0,           # leo ống nước 2 m/s (trước 1,4)
	"baby_min_noise": 7.0,       # chỉ tiếng to (chạy nhanh, đáp mạnh) làm em bé trở mình; đi thường không sao
	"lift_wait_min": 2.0,        # thang máy xuống 2–5 s (trước 4–10)
	"lift_wait_max": 5.0,
	"lift_block_chance": 0.15,   # Ông Bảy chắn cửa 15% (trước 30%), đứng 1,5 s (trước 2,5)
	"lift_block_time": 1.5,
	"lift_stuck_chance": 0.1,    # thang kẹt 10% (trước 20%), kẹt 1,5 s (trước 3)
	"lift_stuck_time": 1.5,
	"rattle_throw": 2.5,         # cục nóng rung đứng được 2,5 s mới hất (trước 1,4)
	# Thứ Sáu chiều tà, đám giỗ (scripts/thu_sau.gd)
	"gio_trips": 2,              # chuyến giỗ (Thử thách 4)
	"gio_shared_time": 0.0,      # 0 = mỗi chuyến giờ riêng (Thử thách: chung 120 s cho 4 chuyến)
	"dog_sleep_t6": 6.0,         # Mực Thứ Sáu ngủ chập chờn (Thử thách 4 / 3)
	"dog_peek_t6": 2.0,
	"lift_period": 3.5,          # cầu nâng tiệm xe một lượt lên xuống (Thử thách 2,5 s)
	"air_push": 0.4,             # vòi hơi thổi Bơ dạt 0,4 m (Thử thách 1,2)
	"tyre_stun": 0.2,
	"kid_trip_stun": 0.15,
	"water_stun": 0.0,           # dính nước tưới chỉ giũ lông, không khựng
	"thorn_slow": 0.8,           # gai giàn bông giấy làm chậm còn 80% (Thử thách 50%)
	"call_radius": 7.0,          # ngồi gọi khách nghe xa 7 m (Thử thách 5)
	# Thứ Tư mưa (gói việc thiet-ke-man/goi-viec-thu-tu.md)
	"puddle_slip_speed": 7.5,    # chỉ chạy nhanh qua vũng mới trượt (Thử thách: 5,5 m/s)
	"puddle_slip_time": 0.25,
	"balance_fall": false,       # chạy nhanh trên ván: chao 0,6 s rồi đứng lại (Thử thách: rơi khỏi ván)
	"balance_speed": 2.5,
	"flood_slow": 0.5,           # lội nước còn 50% tốc độ (Thử thách: 40%)
	"splash_stun": 0.2,          # xe tạt nước khựng 0,2 s (Thử thách: 0,6)
	"pigeon_blind": 1.0,         # bồ câu che mắt 1 s (Thử thách: 2)
	"pigeon_notice": 1.5,        # đi trong 1,5 m mới làm chim bay (Thử thách: 3 m)
	"rain_grace": 5.0,           # nhiệm vụ "dưới mái hiên": được dầm mưa tổng 5 s lúc qua đường (Thử thách: 3)
	# Thứ Năm trưa oi (gói việc thiet-ke-man/goi-viec-thu-nam.md, scripts/thu_nam.gd)
	"shelf_height": 1.6,         # nóc tủ báo Chú Tư (Thử thách 1,9 m)
	"ice_melt_time": 120.0,      # bịch đá tan hết sau 120 s (Thử thách 45), chỉ để nhìn và nhiệm vụ phụ
	"heat_slow": 1.0,            # 1 = tắt; Thử thách: đứng nắng trên mặt đường lâu thì còn 85% tốc độ
	"loft_call_basket": true,    # đứng trước quầy bấm Q thì Chị Mây thả giỏ (Thử thách: phải leo lên gác)
	"tu_wake_noise": 7.5,        # chỉ tiếng to (chạy nhanh, đáp mạnh) làm Chú Tư thức (Thử thách: cả đi thường, 6)
	# Thứ Bảy dạo phố (gói việc thiet-ke-man/goi-viec-thu-bay.md): cả hai chế độ đều không đồng hồ
	"paper_wait": 999.0,         # tờ báo Chú Tư chờ ở mỗi chặng mãi (Thử thách: 6 s rồi bay về chỗ cũ)
	"hum_time": 10.0,            # ru em bé 10 s (Thử thách: 15)
	"hum_noise_ok": true,        # đi thường gần võng vẫn được (Thử thách: phải đứng yên hoặc rón rén)
	"muc_chapter_after": 3,      # giúp 3 người thì mở chương Chó Mực (Thử thách cũng 3)
	# thorn_slow (gai giàn bông giấy) dùng chung với Thứ Sáu ở trên
	# Chủ Nhật Hội mèo (gói việc thiet-ke-man/goi-viec-chu-nhat.md, scripts/hoi_meo/)
	"race_rival_mult": 0.85,     # đua mái nhà: Mít, Bột chậm 15% (Thử thách: đúng tốc độ)
	"race_respawn_flag": true,   # rơi khỏi mái thì về cờ vừa qua (Thử thách: xuống đất leo lại)
	"crate_tries": 3,            # nhảy chồng thùng: 3 lần thử mỗi tầng (Thử thách: 1)
	"crate_ring": true,          # vòng xanh chỉ lúc thùng đứng yên (Thử thách: không có)
	"crate_land_tol": 0.25,      # khung đáp vững của chồng thùng G11 rộng thêm ±0,25 s (Thử thách: đúng 0,77–0,9 s)
	"hide_time": 0.0,            # trốn tìm không giờ (Thử thách: 180 s)
	"hide_hint_after": 30.0,     # 30 s chưa tìm thấy thì chuông kêu to, mũi tên chỉ tới (Thử thách: tắt)
	"relay_rival_mult": 0.8,     # tiếp sức: đội bạn chậm 20% (Thử thách: đúng tốc độ)
	"relay_drop": false,         # nhả túi sớm không rơi (Thử thách: rơi, phải nhặt)
	"costume_borrow": true,      # thi trang phục được mượn đồ chưa mua (Thử thách: chỉ đồ đã có)
	# Bản đồ nhỏ (scripts/ui/ban_do_nho.gd)
	"map_path": true,            # đường chấm đỏ chỉ đường tới đích (Thử thách: chỉ có ghim, tự tìm đường)
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
