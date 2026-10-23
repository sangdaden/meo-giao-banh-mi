class_name TuChoiPho
extends RefCounted
## Bot tự chơi cảnh phố (godot --headless --path . -- --autotest [--ngay=thu_ba] [--don=N]) và chấm kết quả.
## Tách khỏi main.gd để việc mở rộng bot (chơi hết tuần, chụp ảnh từng đơn) không đụng vòng chơi chính.
## m là node main (scripts/main.gd).


## true: Bơ do bot ngoài điều khiển (tests/bot_ca_tuan.gd --bot-di chạy bộ thật), bỏ bước dịch chuyển bên dưới.
## Phần chấm cuối ngày (verdict) vẫn chạy như thường.
static var walk_bot := false


## Mỗi 20 khung: mèo tự "dịch chuyển" tới lò rồi tới khách, ghé qua Chó Mực ở đơn boss để thử bị đớp.
static func step(m: Node) -> void:
	if walk_bot:
		return
	m._autotest_frames += 1
	if m._autotest_frames % 20 != 0:
		return
	m.rig.first_person = not m.rig.first_person  # thử đổi góc nhìn liên tục
	var goal: Vector3 = m._current_goal()
	if m.player.carrying and not m._finishing and not m._is_errand(m.orders[m.order_index]):
		goal = m.deliveries.stand_point(m.order_index)
	if m._finishing:
		pass
	elif m.player.carrying and m.orders[m.order_index].get("boss", false) and not m._bitten:
		goal = m.dog.global_position + Vector3(0.3, 0, 0.3)
		m.dog.hear(goal, 10.0)  # giả tiếng chạy nhanh sát ổ: Mực nghi ngờ rồi đuổi
	elif not m.player.carrying and m.order_index == 1 and Scoring.stamps_today.is_empty() and not m.stamps.remaining().is_empty():
		goal = m.stamps.remaining()[0] - Vector3(0, 0.2, 0)  # trên đường về lò ghé nhặt một con tem
	m.player.global_position = goal + Vector3(0, 0.2, 0)
	m.player.velocity = Vector3.ZERO


## Hết ngày: in AUTOTEST ... OK/FAIL và thoát (ngày Thứ Hai đạt thì chuyển sang cảnh chung cư thử tiếp).
static func verdict(m: Node, summary: Dictionary) -> void:
	if PlayMode.single_order():
		# Một đơn lẻ (-- --autotest --don=N): giao được, lưu sao đơn, không đụng kỷ lục cả ngày
		var ok1: bool = m.results.size() == 1 and m.results[0] > 0 and Scoring.best_stars(PlayMode.order) == m.results[0]
		ok1 = ok1 and GameState.get_day("so_lan_choi", 0) == 0 and int(GameState.get_day("sao_cao_nhat", -1)) == -1
		if m.day.id == "thu_hai" and PlayMode.order == 0:
			ok1 = ok1 and m.score_rows[0].side_ok  # tờ báo Chú Tư phải về tới lò dù chơi lẻ
		print("AUTOTEST DON ", PlayMode.order + 1, " ", "OK" if ok1 else "FAIL")
		m.get_tree().quit(0 if ok1 else 1)
	elif m.day.id != "thu_hai":
		# Ngày khác (-- --autotest --ngay=thu_ba): đủ 5 đơn, có boa, lưu đúng mục của ngày
		var ok2: bool = m.results.size() == m.orders.size() and m.results.all(func(s): return s > 0) and summary.tip > 0
		ok2 = ok2 and GameState.get_day("so_lan_choi", 0) == 1 and GameState.get_day("so_lan_choi", 0, "thu_hai") == 0
		print("AUTOTEST ", m.day.id.to_upper(), " ", "OK" if ok2 else "FAIL")
		m.get_tree().quit(0 if ok2 else 1)
	else:
		# Chó Mực phải đi đúng: nghe tiếng thì nghi ngờ, còn tiếng thì đuổi, rồi đớp
		# (phần mệt về ổ thử riêng trong tools/dog_test.gd)
		var dog_ok: bool = m._dog_states.slice(0, 3) == [m.dog.State.SUSPICIOUS, m.dog.State.CHASE, m.dog.State.BITE]
		print("[autotest] Chó Mực: ", m._dog_states.map(func(s): return m.dog.STATE_NAMES[s]))
		var ok: bool = m.results.size() == 5 and m.results.all(func(s): return s > 0) and m._bitten and dog_ok
		ok = ok and summary.tip > 0 and summary.stamps >= 1 and Scoring.self_test()
		ok = ok and Shop.total_stars() == summary.stars and Shop.self_test() and m.hud.self_test_menu()
		# Mèo cái chưa xuất model thì dùng bản đực, không được rơi về Bơ
		ok = ok and (OutfitView.has_sex_model("muop", "cai") or OutfitView.breed_scene("muop", "cai") == OutfitView.breed_scene("muop", "duc"))
		ok = ok and GameState.get_day("so_lan_choi", 0) == 1 and Scoring.best_time(0) > 0.0
		# Autotest bị Chó Mực đớp ở đơn 5 nên nhiệm vụ phụ đơn đó trượt; 4 đơn đầu phải đạt cả
		ok = ok and m.deliveries.side_ok.slice(0, 4).all(func(v): return v) and m.score_rows[0].side_ok
		if not ok:
			print("AUTOTEST FAIL")
			m.get_tree().quit(1)
			return
		# Màn giao đạt: chạy tiếp cảnh leo chung cư (Thứ Năm), cảnh đó in "AUTOTEST OK" khi xong
		print("AUTOTEST GIAO OK")
		m.get_tree().change_scene_to_file.call_deferred(PlayMode.CHUNG_CU_SCENE)
