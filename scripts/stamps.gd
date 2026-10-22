extends Node3D
## 5 tem Cô Ba giấu trên đường về lò (chỉ hiện khi Bơ không mang bánh).
## Model đã duyệt (luồng "Phác thảo đồ và động tác Thứ Hai"): tem.glb lúc chờ, tem_nhat.glb lúc nhặt.
## Gốc model ở mặt đất (vòng sáng Ø 14 cm), ổ bánh 18 cm đã lơ lửng sẵn 12 cm trong model.
## Vị trí tạm trên các chồng thùng và góc bản đồ có sẵn; luồng Bản đồ Thứ Hai dời vào mái hiên, cuối hẻm, sau bể nước.

signal collected(index: int, count: int)

const STAMP_MODEL := preload("res://assets/models/tem.glb")
const PICKED_MODEL := preload("res://assets/models/tem_nhat.glb")
## Vị trí mặt đất đặt tem
const SPOTS := [
	City.CORNER_STAIR + Vector3(0, 1.6, 0),  # đỉnh chồng thùng bậc thang gần lò
	Vector3(22.5, 0.8, 25.4),  # trên thùng vỉa hè khối 6, phía tây tiệm sửa xe
	Vector3(10.45, 0.8, 18.5), # trên thùng sát hông khối 5
	Vector3(-41, 0, 28),       # góc xa công viên, sau hàng rào
	Vector3(41, 0, -28.5),     # cuối đường phía bắc khối 3
]
const PICK_RADIUS := 0.8
const LOAF_HEIGHT := 0.15  # tâm ổ bánh so với gốc model
const SPIN_SPEED := PI / 2.0  # 90° mỗi giây
const BOB_AMOUNT := 0.02  # nhấp nhô ±2 cm
const PICK_SCALE := 1.25
const PICK_TIME := 0.4
const GLOW := Color("#F2C94C")

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
		var model: Node3D = s.get_child(0)
		model.rotation.y += delta * SPIN_SPEED
		model.position.y = sin(t * 2.5 + s.position.x) * BOB_AMOUNT
		if (s.global_position + Vector3.UP * LOAF_HEIGHT).distance_to(player.global_position + Vector3.UP * 0.2) < PICK_RADIUS:
			var i: int = s.get_meta("index")
			_items.erase(s)
			_play_pick(s)
			collected.emit(i, Scoring.collect_stamp(i))


## Danh sách vị trí tem chưa nhặt (cho tự kiểm tra).
func remaining() -> Array:
	return _items.map(func(s): return s.global_position)


func _make_stamp() -> Node3D:
	var root := Node3D.new()
	root.add_child(_model(STAMP_MODEL))
	return root


## Nhặt: đổi sang model có đốm lấp lánh, phóng 1,25 lần trong 0,4 giây rồi ẩn.
func _play_pick(s: Node3D) -> void:
	var old: Node3D = s.get_child(0)
	var picked := _model(PICKED_MODEL)
	picked.transform = old.transform
	s.remove_child(old)
	old.queue_free()
	s.add_child(picked)
	var tw := s.create_tween()
	tw.tween_property(picked, "scale", Vector3.ONE * PICK_SCALE, PICK_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(picked, "rotation:y", picked.rotation.y + PI, PICK_TIME)
	tw.tween_callback(s.queue_free)


## Tạo model và thêm phát sáng nhẹ màu vàng để thấy tem từ xa.
func _model(scene: PackedScene) -> Node3D:
	var m: Node3D = scene.instantiate()
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for k in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(k) as BaseMaterial3D
			if base == null:
				continue
			var mat := base.duplicate() as BaseMaterial3D
			mat.emission_enabled = true
			mat.emission = GLOW
			mat.emission_energy_multiplier = 0.25
			mi.set_surface_override_material(k, mat)
	return m
