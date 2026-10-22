extends ViecNho
## Trang 7 · Ông Bảy, Ông Tám: làm trọng tài, tìm 3 quân cờ lăn mất (gầm ghế đá, bụi cây, xe đạp) và mang
## từng quân về bàn. Chạy nhanh sát bàn thì ấm trà rung (chỉ nhắc, không thua).

const PIECES := [Vector3(-38.0, 0, 10.55), Vector3(-33.5, 0, 12.6), Vector3(-25.6, 0, 12.2)]

var _rattles := 0
var _rattle_cd := 0.0


func begin() -> void:
	line = "Hai ông: tìm 3 quân cờ, mang từng quân về bàn · 0/3"
	carry_each = true
	return_to = ChessCorner.DROP
	return_name = "bàn cờ"
	# Xe đạp dựng (khối tạm)
	Blocks.solid_box(self, Vector3(1.5, 0.08, 0.06), PIECES[2] + Vector3(0, 0.75, -0.35), Color("#2E7C80"), Blocks.LAYER_PROP)
	for wx in [-0.55, 0.55]:
		var w := TorusMesh.new()
		w.inner_radius = 0.28
		w.outer_radius = 0.32
		var wm := Blocks.mesh(self, w, PIECES[2] + Vector3(wx, 0.32, -0.35), Color("#2B2724"))
		wm.rotation.x = PI / 2.0
	for p in PIECES:
		var piece := trinket(Vector3(0.07, 0.03, 0.07), Color("#C8412F"), "cyl")
		add_child(piece)
		add_target(p, piece, 0.7, 0.6)
	carry_with(func(): return trinket(Vector3(0.07, 0.03, 0.07), Color("#C8412F"), "cyl"))


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
