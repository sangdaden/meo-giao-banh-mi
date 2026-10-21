class_name BoPaw
extends Node3D
## Chân trước của Bơ (một bên), dùng chung cho cận cảnh trong bếp và góc nhìn thứ nhất.
## Theo chân Bơ kiểu D: cẳng tay cam có vằn nâu đỏ mảnh ở mặt ngoài, mặt trong nhạt,
## "tất" kem ở cổ chân, bàn chân tròn dẹt có 4 ngón, đệm ngón và đệm gan chân màu hồng.
##
## Gốc node ở giữa bàn chân, ngón chỉ về -Z. Cẳng tay chạy về +Z (phía người nhìn), gập ở khuỷu,
## rồi cánh tay trên đi xuống, như mèo nhoài người chống chân lên bàn.
## Kích thước (size 1): bàn chân rộng ~9 cm, cẳng tay ~7 cm, cánh tay trên ~16 cm; to hơn chân Bơ
## thật một chút cho dễ nhìn ở cận cảnh, giống tay nhân vật ở góc nhìn thứ nhất.
## Dùng: var p := BoPaw.create(-1.0) (trái) hoặc BoPaw.create(1.0) (phải), rồi add_child(p).
## Góc nhìn thứ nhất: BoPaw.create(side, size, "dung"): gốc node ở mặt đất dưới bàn chân, vai ở trên.
## Màu lông theo giống mèo đang dùng trong tủ đồ (Outfit.breed()): Bơ giữ shader bo_fur như cũ; giống khác
## lấy màu nền nướng từ model giống (assets/textures/chan_meo/, tools/nuong_chan_meo.gd) rồi vẽ thêm vằn/đốm.

const FUR_SHADER := preload("res://shaders/bo_fur.gdshader")
const BEAN := Color("#EFAFAA")
## Màu lông Bơ D. Phải đặt từ GDScript: giá trị mặc định của uniform source_color trong shader
## không được đổi sRGB → linear ở Forward+ (bản PC), làm lông bản PC nhạt hẳn so với bản web.
const FUR := Color(0.91, 0.57, 0.23)
const STRIPE := Color(0.70, 0.36, 0.15)
const CREAM := Color(0.98, 0.90, 0.78)
const SKIN_SHADER := preload("res://shaders/meo_chan.gdshader")
const SKIN_DIR := "res://assets/textures/chan_meo/"
## Hoa văn vẽ thêm lên chân theo kiểu lông của giống (meo-3d/skins/olddata.js): [kiểu, màu vằn, số vằn]
## kiểu: 1 vằn, 2 đốm hoa thị, 3 lấm tấm. Giống không có ở đây là lông trơn / hai màu / màu điểm, ảnh nướng đã đủ.
const MARKS := {
	"muop": [1, "#4A463F", 5.0], "bingo": [1, "#E8792A", 4.0], "lantet": [1, "#F2C14E", 3.0],
	"vobanh": [1, "#B5661E", 3.0], "hocon": [2, "#5A3A1E", 0.0], "caphesua": [3, "#5E3820", 0.0],
	"que": [3, "#7E3F1C", 0.0],
}
static var _paw_info := {}

@export var side := 1.0           ## -1 chân trái, 1 chân phải (khuỷu chĩa ra ngoài)
@export var size := 1.0           ## tỉ lệ so với số đo gốc
@export_enum("bep", "dung") var pose := "bep"  ## bep: chống lên bàn (cận cảnh); dung: cẳng chân dựng thẳng xuống đất
@export var breed := ""           ## giống mèo (id trong Outfit.BREEDS); "" = giống đang dùng trong tủ đồ

var arm: MeshInstance3D           ## ống cẳng tay + cánh tay
var _top := Vector3.ZERO          ## điểm vai (đầu trên của ống), trong hệ toạ độ node trước khi nhân size
var foot: Node3D                  ## bàn chân (có thể xoay riêng để gập cổ chân)


static func create(paw_side: float, paw_size := 1.0, paw_pose := "bep", paw_breed := "") -> BoPaw:
	var p := BoPaw.new()
	p.side = paw_side
	p.size = paw_size
	p.pose = paw_pose
	p.breed = paw_breed
	return p


func _ready() -> void:
	if breed == "":
		breed = Outfit.breed()
	if breed != "bo" and not ResourceLoader.exists(SKIN_DIR + breed + ".png"):
		breed = "bo"
	var wrist := Vector3(0, 0.014, 0.035)
	var elbow := wrist + Vector3(side * 0.15, -0.35, 1.0).normalized() * 0.07
	var shoulder := elbow + Vector3(side * 0.1, -1.0, 0.6).normalized() * 0.16
	if pose == "dung":
		# Đứng: bàn chân chạm đất (y = 0 là đáy đệm chân), cẳng chân dựng đứng, vai cao ~0,27 m (size 1)
		wrist = Vector3(0, 0.05, 0.012)
		elbow = Vector3(side * 0.008, 0.15, 0.022)
		shoulder = Vector3(side * 0.015, 0.27, -0.005)
	arm = MeshInstance3D.new()
	arm.name = "CanhTay"
	var start := Vector3(0, 0.004, 0.0)
	var up_ref := Vector3.UP
	if pose == "dung":
		start = Vector3(0, 0.03, 0.0)
		up_ref = Vector3.FORWARD  # chân dựng đứng: vằn ở mặt trước (phía mèo nhìn)
	var radii := [0.032, 0.032, 0.04, 0.05]
	if pose == "dung":
		radii = [0.033, 0.034, 0.047, 0.062]
	arm.mesh = tube([start, wrist, elbow, shoulder], radii, 18, 8, up_ref)
	arm.material_override = fur_mat(0.0) if breed == "bo" else _skin_mat(false)
	if pose != "dung" and breed == "bo":
		(arm.material_override as ShaderMaterial).set_shader_parameter("stripe_count", 3.5)
		(arm.material_override as ShaderMaterial).set_shader_parameter("sock", 0.22)
	_add_shells(arm.material_override)
	add_child(arm)
	_top = shoulder
	if pose == "dung":
		# Bịt miệng ống ở vai cho khỏi hở khi nhìn từ trên xuống
		var cap := MeshInstance3D.new()
		cap.name = "NapVai"
		var cs := SphereMesh.new()
		cs.radius = radii[-1]
		cs.height = radii[-1] * 2.0
		cs.radial_segments = 18
		cs.rings = 9
		cap.mesh = cs
		cap.material_override = arm.material_override
		cap.position = shoulder
		add_child(cap)

	foot = Node3D.new()
	foot.name = "BanChan"
	if pose == "dung":
		foot.position.y = 0.028  # nhấc bàn chân lên để đệm chân vừa chạm đất (y = 0)
	add_child(foot)
	var cream := fur_mat(1.0) if breed == "bo" else _skin_mat(true)
	_add_shells(cream)
	var pink := StandardMaterial3D.new()
	pink.albedo_color = BEAN if breed == "bo" else _bean_color()
	pink.roughness = 0.6
	_ball(foot, 0.04, Vector3(0, 0.004, 0.006), Vector3(1.08, 0.66, 1.12), cream)
	_ball(foot, 0.034, Vector3(0, 0.012, 0.03), Vector3(1.0, 0.85, 1.0), cream)          # lông cổ chân nối vào cẳng tay
	for i in 4:
		var x := -0.03 + i * 0.02
		var z := -0.036 if i in [0, 3] else -0.043
		_ball(foot, 0.0165, Vector3(x, 0.004, z), Vector3(1.0, 0.8, 1.1), cream)          # ngón
		_ball(foot, 0.011, Vector3(x, -0.011, z - 0.002), Vector3(1.0, 0.5, 1.0), pink)   # đệm ngón
	_ball(foot, 0.019, Vector3(0, -0.017, 0.006), Vector3(1.35, 0.4, 1.0), pink)          # đệm gan chân
	foot.scale = Vector3.ONE * 1.12
	scale = Vector3.ONE * size


## Điểm vai (đầu trên của chân) trong hệ toạ độ của node, chưa nhân size.
## Góc nhìn thứ nhất dùng điểm này để gắn chân vào thân. Gọi sau khi node đã add_child (_ready đã chạy).
func top_point() -> Vector3:
	return _top


func _ball(parent: Node3D, r: float, pos: Vector3, squash: Vector3, mat: Material) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = mat
	mi.position = pos
	mi.scale = squash
	parent.add_child(mi)


## Vật liệu lông Bơ (shaders/bo_fur.gdshader). all_cream = 1 cho bàn chân màu kem.
static func fur_mat(all_cream: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FUR_SHADER
	m.set_shader_parameter("fur", FUR)
	m.set_shader_parameter("stripe", STRIPE)
	m.set_shader_parameter("cream", CREAM)
	m.set_shader_parameter("all_cream", all_cream)
	return m


## Hai lớp lông viền (next_pass) đẩy ra 3 và 6 mm, có lỗ thưa: viền chân lởm chởm như lông thay vì ống trơn.
static func _add_shells(mat: ShaderMaterial) -> void:
	var last := mat
	for k in [0.003, 0.006]:
		var sh: ShaderMaterial = mat.duplicate()
		sh.set_shader_parameter("shell", k)
		last.next_pass = sh
		last = sh


## Vật liệu lông theo giống (không phải Bơ). foot = true: bàn chân một màu.
func _skin_mat(foot: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SKIN_SHADER
	m.set_shader_parameter("leg_tex", load(SKIN_DIR + breed + ".png"))
	# Camera đứng sau mèo: chân bên phải màn hình là chân FL của model (FL nằm phía -x, mèo quay lưng lại camera)
	m.set_shader_parameter("half_offset", 0.0 if side > 0.0 else 0.5)
	m.set_shader_parameter("mirror", 1.0 if side > 0.0 else 0.0)
	var row := _breed_row()
	m.set_shader_parameter("fur", Color(row[4]) if not row.is_empty() else Color.GRAY)
	var mk: Array = MARKS.get(breed, [0, "#000000", 0.0])
	m.set_shader_parameter("pattern", mk[0])
	m.set_shader_parameter("mark", Color(mk[1]))
	m.set_shader_parameter("stripe_count", mk[2])
	m.set_shader_parameter("hairless", 1.0 if breed == "chalua" else 0.0)
	m.set_shader_parameter("use_solid", 1.0 if foot else 0.0)
	m.set_shader_parameter("solid", _paw_color())
	return m


func _breed_row() -> Array:
	for b in Outfit.BREEDS:
		if b[0] == breed:
			return b
	return []


## Màu bàn chân của giống, đọc từ chan_meo.json (nướng cùng ảnh).
func _paw_color() -> Color:
	if _paw_info.is_empty() and FileAccess.file_exists(SKIN_DIR + "chan_meo.json"):
		_paw_info = JSON.parse_string(FileAccess.get_file_as_string(SKIN_DIR + "chan_meo.json"))
	var info: Dictionary = _paw_info.get(breed, {})
	return Color(info.get("paw_FL" if side > 0.0 else "paw_FR", "#FFFFFF"))


## Đệm chân: hồng như Bơ, trừ giống chân sẫm (Mun, Bí Ngô, Xiêm) thì đệm nâu sẫm.
func _bean_color() -> Color:
	var p := _paw_color()
	return Color("#4A3636") if p.get_luminance() < 0.35 else BEAN


## Ống trơn chạy qua các điểm (đường cong Catmull-Rom), bán kính nội suy theo từng điểm.
## UV.y = 0 ở điểm đầu, 1 ở điểm cuối; UV.x = 0 ở phía `up_ref` của ống (mặc định phía trên).
static func tube(points: Array, radii: Array, sides := 14, sub := 8, up_ref := Vector3.UP) -> ArrayMesh:
	var path: Array[Vector3] = []
	var rad: Array[float] = []
	for i in points.size() - 1:
		var p0: Vector3 = points[maxi(i - 1, 0)]
		var p1: Vector3 = points[i]
		var p2: Vector3 = points[i + 1]
		var p3: Vector3 = points[mini(i + 2, points.size() - 1)]
		for k in sub:
			var t := float(k) / sub
			path.append(p1.cubic_interpolate(p2, p0, p3, t))
			rad.append(lerpf(radii[i], radii[i + 1], smoothstep(0.0, 1.0, t)))
	path.append(points[-1])
	rad.append(radii[-1])
	var total := 0.0
	var lens: Array[float] = [0.0]
	for i in range(1, path.size()):
		total += path[i].distance_to(path[i - 1])
		lens.append(total)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in path.size():
		var tan := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var nrm := (up_ref - tan * tan.dot(up_ref)).normalized()
		var bin := tan.cross(nrm)
		for j in sides + 1:
			var a := TAU * j / sides
			var dir := nrm * cos(a) + bin * sin(a)
			st.set_normal(dir)
			st.set_uv(Vector2(float(j) / sides, lens[i] / total))
			st.add_vertex(path[i] + dir * rad[i])
	for i in path.size() - 1:
		for j in sides:
			var a := i * (sides + 1) + j
			var b := a + sides + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(b + 1)
	return st.commit()
