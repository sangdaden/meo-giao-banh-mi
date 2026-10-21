class_name BoPaw
extends Node3D
## Chân trước của Bơ (một bên), dùng chung cho cận cảnh trong bếp và góc nhìn thứ nhất.
## Theo chân Bơ kiểu D: cẳng tay cam có vằn nâu đỏ mảnh ở mặt ngoài, mặt trong nhạt,
## "tất" kem ở cổ chân, bàn chân tròn dẹt có 4 ngón, đệm ngón và đệm gan chân màu hồng.
##
## Gốc node ở giữa bàn chân, ngón chỉ về -Z. Cẳng tay chạy về +Z (phía người nhìn), gập ở khuỷu,
## rồi cánh tay trên đi xuống, như mèo nhoài người chống chân lên bàn.
## Kích thước (size 1): bàn chân rộng ~9 cm, cẳng tay ~12 cm, cánh tay trên ~24 cm; to hơn chân Bơ
## thật một chút cho dễ nhìn ở cận cảnh, giống tay nhân vật ở góc nhìn thứ nhất.
## Dùng: var p := BoPaw.create(-1.0) (trái) hoặc BoPaw.create(1.0) (phải), rồi add_child(p).
## Góc nhìn thứ nhất: BoPaw.create(side, size, "dung"): gốc node ở mặt đất dưới bàn chân, vai ở trên.

const FUR_SHADER := preload("res://shaders/bo_fur.gdshader")
const BEAN := Color("#EFAFAA")

@export var side := 1.0           ## -1 chân trái, 1 chân phải (khuỷu chĩa ra ngoài)
@export var size := 1.0           ## tỉ lệ so với số đo gốc
@export_enum("bep", "dung") var pose := "bep"  ## bep: chống lên bàn (cận cảnh); dung: cẳng chân dựng thẳng xuống đất

var arm: MeshInstance3D           ## ống cẳng tay + cánh tay
var foot: Node3D                  ## bàn chân (có thể xoay riêng để gập cổ chân)


static func create(paw_side: float, paw_size := 1.0, paw_pose := "bep") -> BoPaw:
	var p := BoPaw.new()
	p.side = paw_side
	p.size = paw_size
	p.pose = paw_pose
	return p


func _ready() -> void:
	var wrist := Vector3(0, 0.014, 0.04)
	var elbow := wrist + Vector3(side * 0.25, -0.2, 1.0).normalized() * 0.12
	var shoulder := elbow + Vector3(side * 0.25, -1.0, 0.35).normalized() * 0.24
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
	arm.mesh = tube([start, wrist, elbow, shoulder], [0.033, 0.034, 0.047, 0.062], 18, 8, up_ref)
	arm.material_override = fur_mat(0.0)
	add_child(arm)

	foot = Node3D.new()
	foot.name = "BanChan"
	if pose == "dung":
		foot.position.y = 0.028  # nhấc bàn chân lên để đệm chân vừa chạm đất (y = 0)
	add_child(foot)
	var cream := fur_mat(1.0)
	var pink := StandardMaterial3D.new()
	pink.albedo_color = BEAN
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
	m.set_shader_parameter("all_cream", all_cream)
	return m


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
