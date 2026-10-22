extends SceneTree
## Cảnh tủ đồ cho trailer: mèo xoay chậm trên bục, mỗi phách nhạc (0,6 giây ở 100 BPM) đổi một giống và bộ đồ.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 \
##     --write-movie <ra.avi> -s tools/trailer/quay_tu_do.gd

const BEAT := 0.6
## giống, đồ mặc {ô: id}
const LOOKS := [
	["bo", {"neck": "khando", "back": "tuibanh"}],
	["muop", {"head": "nonla", "neck": "khanran"}],
	["mun", {"head": "muphuthuy", "face": "bitmat"}],
	["tuyet", {"head": "vuongmien", "back": "canhthienthan"}],
	["xiem", {"face": "kinhram", "neck": "vonghoa", "back": "phaovit"}],
	["tamthe", {"head": "hoadambut", "neck": "chuong"}],
	["khoaimon", {"head": "mubaohiem", "face": "kinhphicong", "back": "thung"}],
	["caphesua", {"head": "mudaubep", "neck": "nobuom"}],
	["bosua", {"head": "munlen", "feet": "tatsoc"}],
	["hocon", {"head": "bangdo", "tail": "coduua", "feet": "giaypatin"}],
	["lantet", {"head": "canhmai", "neck": "khanlen", "back": "baolixi"}],
	["thongoc", {"tail": "denlong"}],
	["bo", {"neck": "khando", "back": "aochoang"}],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var p := BoPreview.new()
	p.show_hint = false
	p.bg_color = Color("#9CCBC1")
	p.start_dist = 1.55
	p.start_pitch = 0.16
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(p)
	await process_frame
	p.size = root.get_visible_rect().size
	p.spin = 0.9
	p.cat.set_breed("bo", LOOKS[0][1])
	var frames := int((LOOKS.size() * BEAT + 0.6) * 30.0)
	var k := 1
	for i in frames:
		p.spin = 0.9
		if k < LOOKS.size() and i >= int(k * BEAT * 30.0):
			p.cat.set_breed(LOOKS[k][0], LOOKS[k][1])
			k += 1
		await process_frame
	quit()
