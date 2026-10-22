class_name ThuTuModels
## Model G5 Thứ Tư (assets/models/thu_tu, Sang duyệt 2026-10-22). Màu nằm ở màu đỉnh như đồ Thứ Sáu,
## nên dùng chung vật liệu và cách đổi màu sRGB cho bản web của ThuSau.
## Cầu thang sắt, giàn sắt, cổng chào, chuồng bồ câu dựng lại đúng kích thước đường sân thượng
## (thiet-ke-man/thu-tu-game/scripts/do4_game.py); cỡ khác thì kéo giãn bản gần nhất.

const DIR := "res://assets/models/thu_tu/%s.glb"
## Cầu thang có sẵn: [cao, ngang, rộng] (m). Gốc ở chân thang giữa bề ngang, lên theo -Z, chiếu nghỉ 0,9 ở đỉnh.
const STAIRS := [[4.08, 4.86235, 0.9], [3.19679, 4.4, 1.1], [3.23311, 4.45, 1.1], [3.323333, 4.253673, 0.95],
	[3.44, 4.402999, 0.95]]
## Giàn sắt có sẵn: [cao đầu tây, chênh đầu đông, dài] (m). Gốc ở giữa sàn trên mặt đất.
const GANTRIES := [[11.594, 0.004, 8.15], [11.594, -3.272, 8.15]]

static var _scenes := {}


## Đặt một món; trả node gốc của model.
static func put(parent: Node, model: String, pos: Vector3, rot_y := 0.0, scale := Vector3.ONE) -> Node3D:
	if not _scenes.has(model):
		_scenes[model] = load(DIR % model)
	var n: Node3D = _scenes[model].instantiate()
	n.name = model
	n.position = pos
	n.rotation.y = rot_y
	n.scale = scale
	parent.add_child(n)
	var web := RenderingServer.get_rendering_device() == null
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var src: Mesh = mi.mesh
		if web:
			mi.mesh = ThuSau._srgb_mesh(src, "thu_tu:" + model + ":" + str(mi.name))
		for i in src.get_surface_count():
			mi.set_surface_override_material(i, ThuSau._material(""))
	return n


## Cầu thang sắt từ foot (thấp) lên top (cao), rộng `width`.
static func stairs(parent: Node, foot: Vector3, top: Vector3, width: float) -> Node3D:
	var d := top - foot
	var run := Vector2(d.x, d.z).length()
	var best: Array = STAIRS[0]
	var err := INF
	for s: Array in STAIRS:
		var e := absf(s[0] - d.y) + absf(s[1] - run) + 2.0 * absf(s[2] - width)
		if e < err:
			err = e
			best = s
	var n := put(parent, _stair_name(best), foot, atan2(-d.x, -d.z))
	if err > 0.05:
		n.scale = Vector3(width / best[2], d.y / best[0], run / best[1])
	return n


static func _stair_name(s: Array) -> String:
	return "cau_thang_%d_%d_%d" % [roundi(s[0] * 100.0), roundi(s[1] * 100.0), roundi(s[2] * 100.0)]


## Giàn sắt từ a (đầu tây) sang b (đầu đông), cùng z.
static func gantry(parent: Node, a: Vector3, b: Vector3) -> Node3D:
	var best: Array = GANTRIES[0]
	for g: Array in GANTRIES:
		if absf(g[1] - (b.y - a.y)) < absf(best[1] - (b.y - a.y)):
			best = g
	var n := put(parent, "gian_sat_%d_%d_%d" % [roundi(best[0] * 100), roundi(best[1] * 100), roundi(best[2] * 100)],
		Vector3((a.x + b.x) / 2.0, 0, a.z))
	var sx: float = (b.x - a.x) / float(best[2])
	var sy: float = a.y / float(best[0])
	if absf(sx - 1.0) > 0.01 or absf(sy - 1.0) > 0.01 or absf(best[1] - (b.y - a.y)) > 0.05:
		n.scale = Vector3(sx, sy, 1.0)
	return n
