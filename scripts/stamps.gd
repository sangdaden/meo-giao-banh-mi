extends Node3D
## 5 tem Cô Ba giấu trên đường về lò (chỉ hiện khi Bơ không mang bánh).
## Hình tạm: ổ bánh có nơ đỏ bằng khối, chờ phác thảo tem ở luồng "Phác thảo đồ và động tác Thứ Hai".
## Vị trí tạm trên các chồng thùng và góc bản đồ có sẵn; luồng Bản đồ Thứ Hai dời vào mái hiên, cuối hẻm, sau bể nước.

signal collected(index: int, count: int)

const SPOTS := [
	Vector3(-25.8, 1.9, -2),   # đỉnh chồng thùng bậc thang gần lò
	Vector3(26, 1.1, 27.5),    # trên thùng gần tiệm sửa xe
	Vector3(14, 1.1, 18),      # trên thùng trong khối 5
	Vector3(-41, 0.4, 28),     # góc xa công viên, sau hàng rào
	Vector3(41, 0.4, -28.5),   # cuối đường phía bắc khối 3
]
const PICK_RADIUS := 0.8

var player: Node3D
var _items: Array[Node3D] = []


func _ready() -> void:
	var got := Scoring.stamps_collected()
	for i in SPOTS.size():
		var s := _make_stamp()
		s.position = SPOTS[i]
		s.name = "Tem%d" % (i + 1)
		s.set_meta("index", i)
		add_child(s)
		if i in got:
			s.queue_free()
		else:
			_items.append(s)


## Hiện hay ẩn cả bộ tem (main.gd gọi mỗi khung: ẩn khi đang mang bánh).
func set_active(on: bool) -> void:
	for s in _items:
		s.visible = on


func _process(delta: float) -> void:
	if player == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	for s in _items.duplicate():
		if not s.visible:
			continue
		s.rotation.y += delta * 1.6
		s.get_child(0).position.y = sin(t * 3.0 + s.position.x) * 0.06
		if s.global_position.distance_to(player.global_position + Vector3.UP * 0.2) < PICK_RADIUS:
			var i: int = s.get_meta("index")
			_items.erase(s)
			s.queue_free()
			collected.emit(i, Scoring.collect_stamp(i))


## Danh sách vị trí tem chưa nhặt (cho tự kiểm tra).
func remaining() -> Array:
	return _items.map(func(s): return s.global_position)


func _make_stamp() -> Node3D:
	var root := Node3D.new()
	var bob := Node3D.new()
	root.add_child(bob)
	var loaf := CapsuleMesh.new()
	loaf.radius = 0.09
	loaf.height = 0.42
	loaf.radial_segments = 10
	loaf.rings = 3
	var m := Blocks.mesh(bob, loaf, Vector3.ZERO, Color("#E0A040"))
	m.rotation_degrees.z = 90
	# Nơ đỏ buộc giữa ổ
	Blocks.box(bob, Vector3(0.05, 0.2, 0.2), Vector3(0, 0, 0), Color("#C8412F"))
	var wing := Blocks.box(bob, Vector3(0.12, 0.07, 0.03), Vector3(-0.06, 0.12, 0.0), Color("#C8412F"))
	wing.rotation_degrees.z = 25
	wing = Blocks.box(bob, Vector3(0.12, 0.07, 0.03), Vector3(0.06, 0.12, 0.0), Color("#C8412F"))
	wing.rotation_degrees.z = -25
	# Quầng sáng nhẹ để thấy từ xa
	var glow := SphereMesh.new()
	glow.radius = 0.32
	glow.height = 0.64
	glow.radial_segments = 12
	glow.rings = 6
	var g := Blocks.mesh(bob, glow, Vector3.ZERO, Color(1.0, 0.85, 0.4, 0.22), true)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root
