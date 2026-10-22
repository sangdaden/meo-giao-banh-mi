extends ViecNho
## Trang 10 · Chị Thu: ru em bé. Nằm cạnh võng kêu rừ rừ đủ DoKho "hum_time" giây (Thong thả 10 s; đi lại gần
## võng vẫn được). Thử thách 15 s và phải nằm yên hoặc rón rén, chạy nhanh thì em bé cựa mình, đếm lại.
## Bản này võng treo ở hẻm sau chung cư (khối tạm); cảnh tầng 3 trong chung cư chờ G1 (luồng "Màn leo chung cư").

var _hammock := Vector3.ZERO
var _hum := 0.0
var _humming := false
var _need := 10.0


func begin() -> void:
	_hammock = day.hammock_spot()
	_need = float(DoKho.v("hum_time", 15.0))
	line = "Chị Thu: nằm cạnh võng kêu rừ rừ ru em bé · 0/%d s" % int(_need)


func tick(delta: float) -> void:
	if is_done():
		return
	var near := _near(_hammock, 1.6, 1.0)
	var still: bool = Vector2(player.velocity.x, player.velocity.z).length() < 0.3 or player.stance in ["sneak", "crouch"]
	var ok: bool = near and (bool(DoKho.v("hum_noise_ok", false)) or still)
	if near and player.stance == "sprint" and not bool(DoKho.v("hum_noise_ok", false)) and _hum > 0.0:
		_hum = 0.0
		day.toast("Em bé cựa mình... rón rén lại gần rồi ru lại nha.", 2.0)
	if ok:
		_hum += delta
		if not _humming and still:
			_humming = true
			player.play_clip("ngu_cuon")
			_sfx("snore")
		line = "Chị Thu: rừ rừ... %d/%d s" % [int(_hum), int(_need)]
		day.task_line(line)
		if _hum >= _need:
			player.stop_clip()
			day.toast("Em bé ngủ ngon rồi. Chị Thu: \"Cảm ơn Bơ nha!\"", 2.5)
			finish()
	elif _humming:
		_humming = false
		player.stop_clip()


func bot_goal() -> Vector3:
	return _hammock + Vector3(0.6, 0, 0.6)
