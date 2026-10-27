extends ViecNho
## Trang 7 · Ông Bảy, Ông Tám: làm trọng tài, tìm 3 quân cờ lăn mất (gầm ghế đá, bụi cây, xe đạp) và mang
## từng quân về bàn. Chạy nhanh sát bàn thì ấm trà rung (chỉ nhắc, không thua).

const PIECES := [Vector3(-38.0, 0, 10.55), Vector3(-33.5, 0, 12.6), Vector3(-25.6, 0, 12.2)]
## Ba quân đỏ lấy từ bộ cờ góc cờ đã duyệt (D3, trang https://claude.ai/artifact/QfaygXEzM4AGMyFNogyzqc): cỡ thật ø3,7 cm
const PIECE_MODELS := ["quan_do_xe", "quan_do_ma", "quan_do_phao"]

var _rattles := 0
var _rattle_cd := 0.0


func begin() -> void:
	line = "Hai ông: tìm 3 quân cờ, mang từng quân về bàn · 0/3"
	carry_each = true
	return_to = ChessCorner.DROP
	return_name = "bàn cờ"
	# Xe đạp dựng (model xe_dap G1); va chạm vẫn là thanh ngang cũ để quân cờ dưới gầm còn với được
	Blocks.collider(self, Vector3(1.5, 0.08, 0.06), PIECES[2] + Vector3(0, 0.75, -0.35), Blocks.LAYER_PROP)
	DoThem.put(self, "xe_dap", PIECES[2] + Vector3(0, 0, -0.35))
	for i in PIECES.size():
		var piece := _piece(PIECE_MODELS[i], true)
		add_child(piece)
		add_target(PIECES[i], piece, 0.7, 0.6)
	carry_with(func(): return _piece(PIECE_MODELS[_index], false))


## Quân cờ thật: lying = lăn nằm nghiêng ngoài phố (có vòng sáng như khối tạm cũ), không thì đứng (Bơ ngậm).
static func _piece(ten: String, lying: bool) -> Node3D:
	var n := Node3D.new()
	var mi := PhoModels.put(n, "../goc_co/" + ten, Vector3(0, 0.0185 if lying else 0.0, 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if lying:
		mi.rotation.x = PI / 2.0
		glow_ring(n, Vector3(0.07, 0.04, 0.07))
	return n


func tick(delta: float) -> void:
	super.tick(delta)
	_rattle_cd -= delta
	if player.stance == "sprint" and player.global_position.distance_to(ChessCorner.TEA) < 1.8 and _rattle_cd <= 0.0:
		_rattles += 1
		_rattle_cd = 3.0
		_sfx("glass_rattle")
		day.toast("Ấm trà rung rinh! Tới gần bàn thì đi chậm thôi.", 2.0)


func on_got(_i: int) -> void:
	day.toast("Tìm được một quân cờ! Mang về bàn cho hai ông.", 2.0)


func on_returned(_i: int) -> void:
	var n := got_count()
	_sfx("chess_slap")
	line = "Hai ông: tìm 3 quân cờ, mang từng quân về bàn · %d/3" % n
	day.task_line(line)
	if n < 3:
		day.toast("Ông Bảy: \"Đúng quân này rồi!\" (%d/3)" % n, 1.8)
