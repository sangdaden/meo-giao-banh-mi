extends "res://tools/trailer/quay_canh.gd"
## Quay clip dọc 9:16 cho devlog (PH4). Dùng chung bộ diễn của trailer (tools/trailer/quay_canh.gd),
## chỉ khác danh sách cảnh: camera gần hơn, dựng cho khung dọc. Chạy:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 720x1280 --fixed-fps 30 \
##     --write-movie <ra.avi> -s tools/clip_doc/quay_clip_doc.gd -- <tên_clip>
## Cả bộ (quay + dựng mp4): tools/clip_doc/lam_clip.sh (README.md cùng thư mục).

const CLIPS := {
	# Leo ống nước chung cư (Thứ Năm), từ sát chân ống lên tới đầu ống
	"leo": {
		"scene": "chung_cu", "setup": "_leo_thap", "seconds": 3.6,
		"cam": {"mode": "track", "offset": Vector3(-1.9, -0.2, 1.0), "look": Vector3(0, 0.6, 0), "fov": 62.0},
		"steps": [["hold", "move_forward", 3.5]],
	},
	# Giao bánh cho Chú Tư (Thứ Hai): chạy tới, bấm E, khoảnh khắc giao bánh
	"giao": {
		"day": "thu_hai", "setup": "_cam_banh", "order": 0, "seconds": 6.0, "approach": 4.0,
		"cam": {"mode": "track", "offset": Vector3(1.5, 1.1, 2.2), "look": Vector3(0, 0.5, 0), "fov": 60.0},
		"steps": [["go_stand", "walk"], ["deliver"], ["wait", 4.0]],
	},
	# Mưa Thứ Tư: Bơ chạy dọc dãy mái hiên liền nhau phía bắc (z = -6,5, x từ -12 tới 10, cao 2,9 m)
	"mua_mai": {
		"day": "thu_tu", "setup": "_mua_ngap", "start": Vector3(-11.6, 3.1, -6.5), "yaw": -PI / 2, "seconds": 6.0,
		"cam": {"mode": "track", "offset": Vector3(-2.4, 1.6, 0.6), "look": Vector3(1.5, 0.0, 0), "fov": 62.0},
		"steps": [["go", Vector3(9.4, 0, -6.5), "walk"], ["wait", 1.0]],
	},
	# Hẻm 42: rón rén qua Chó Mực, Mực thức, Bơ phóng đi
	"muc": {
		"day": "thu_hai", "setup": "_cam_banh", "order": 4, "start": Vector3(-17.5, 0.1, 14.0), "yaw": PI, "seconds": 5.6,
		"cam": {"mode": "dolly", "from": Vector3(-17.4, 1.1, 18.4), "to": Vector3(-17.9, 1.5, 20.6),
			"at": Vector3(-17.8, 0.3, 14.6), "at_to": Vector3(-18.4, 0.3, 17.0), "fov": 62.0},
		"steps": [["go", Vector3(-17.5, 0, 15.3), "sneak"], ["wait", 0.9], ["go", Vector3(-17.5, 0, 16.6), "sneak"],
			["call", "_muc_thuc"], ["wait", 0.8],
			["go", Vector3(-18.9, 0, 20.9), "sprint"], ["wait", 1.5]],
	},
	# Lao ra phố: chạy dọc vỉa hè, nhảy liên tục, camera bám sau lưng hơi cao
	"chay": {
		"day": "thu_hai", "setup": "_no_traffic", "start": Vector3(-33, 0.1, -3.6), "yaw": -PI / 2, "seconds": 6.5,
		"cam": {"mode": "track", "offset": Vector3(-2.4, 1.3, 1.2), "look": Vector3(1.5, 0.3, 0), "fov": 62.0},
		"steps": [["go", Vector3(-28, 0, -3.6), "sprint"], ["jump"], ["go", Vector3(-22, 0, -3.6), "sprint"], ["jump"],
			["go", Vector3(-15, 0, -3.6), "sprint"], ["jump"], ["go", Vector3(2, 0, -3.6), "sprint"]],
	},
}


func _initialize() -> void:
	var name := "leo"
	for a in OS.get_cmdline_user_args():
		if a == "--debug":
			_debug = true
		elif not a.begins_with("--"):
			name = a
	shot = CLIPS[name].duplicate(true)
	PlayMode.day = shot.get("day", "thu_hai")
	GameState.day = PlayMode.day
	GameState.use_test_save("user://luu_game_clip_doc.cfg")
	_run.call_deferred()


## Như _leo_ong của trailer nhưng bắt đầu sát chân ống
func _leo_thap() -> void:
	await _leo_ong()
	_put(Vector3(-0.32, 1.2, main.PIPE.z))
