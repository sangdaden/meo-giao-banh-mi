class_name DenToi
extends Node3D
## Đèn lồng buổi chiều tối (Thứ Sáu chiều tà, Thứ Bảy hoàng hôn, Chủ Nhật tối hội), gói G4.
## Mỗi mặt tiền dọc đường lớn treo một đèn lồng phát sáng: cả dãy là một MultiMesh (1 lệnh vẽ).
## Ánh sáng thật chỉ có vài OmniLight không đổ bóng, mỗi 0,3 giây dời tới các đèn gần mèo nhất:
## trên web mỗi đèn vẽ lại các vật trong tầm của nó nên giữ ít (docs/ngan-sach-hieu-nang.md).

const LIGHTS := [6, 4]           ## số đèn thật [Forward+, Compatibility]
const COLOR := Color("#FF8A4A")
const RANGE := 6.0
const ENERGY := 1.6              ## nhân với strength của preset
const HANG_Y := 2.55             ## đèn lồng treo dưới mái hiên
const FRONT_Z := 6.4             ## mặt tiền hai dãy nhà nhìn ra đường lớn (z = ±)
const STEP := 7.0

var strength := 1.0
var anchors: Array[Vector3] = []
var _lights: Array[OmniLight3D] = []
var _t := 0.0


func _ready() -> void:
	var x := -42.0
	while x <= 42.0:
		for a in [Vector3(x, HANG_Y, -FRONT_Z), Vector3(x + STEP / 2.0, HANG_Y, FRONT_Z)]:
			if absf(a.x + 18.0) > 4.5 and absf(a.x - 16.0) > 4.5:  # không treo giữa hai ngã tư
				anchors.append(a)
		x += STEP
	_make_lanterns()
	var n: int = LIGHTS[1 if AnhSang.is_compat() else 0]
	for i in n:
		var l := OmniLight3D.new()
		l.light_color = COLOR
		l.light_energy = ENERGY * strength
		l.omni_range = RANGE
		l.omni_attenuation = 1.4
		l.shadow_enabled = false
		l.light_specular = 0.3
		l.add_to_group("den_phu")
		add_child(l)
		_lights.append(l)
	_place()


func _process(delta: float) -> void:
	_t += delta
	if _t >= 0.3:
		_t = 0.0
		_place()


func _place() -> void:
	var cam := get_viewport().get_camera_3d()
	var c := cam.global_position if cam else Vector3.ZERO
	var near := anchors.duplicate()
	near.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(c) < b.distance_squared_to(c))
	for i in _lights.size():
		_lights[i].position = near[i] + Vector3(0, -0.25, 0)


func _make_lanterns() -> void:
	var s := SphereMesh.new()
	s.radius = 0.19
	s.height = 0.32
	s.radial_segments = 10
	s.rings = 5
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#C8412F")   # đèn lồng đỏ như model đèn lồng ở khu phố
	m.emission_enabled = true
	m.emission = Color("#E0482C")
	m.emission_energy_multiplier = 0.9 * strength
	s.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = s
	mm.instance_count = anchors.size()
	for i in anchors.size():
		mm.set_instance_transform(i, Transform3D(Basis(), anchors[i]))
	var mi := MultiMeshInstance3D.new()
	mi.name = "DenLong"
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
