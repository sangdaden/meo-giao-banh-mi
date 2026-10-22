class_name VanhPho
## Vành phố gần + phông chân trời quanh vùng chơi (gói P1 "Thiết kế lại khu phố", Sang duyệt 22/10).
## Bàn giao: /mnt/project-files/thiet-ke-lai-khu-pho/p1-vanh-pho/BAN-GIAO.md, model dựng bằng Blender (vanh.py, bien.py).
## - Vùng chơi 96 x 60 m giữ nguyên; vành nhà, đường chạy tiếp, kênh phía tây ra tới x ±110, z ±94 chỉ để nhìn.
## - Phông chân trời: vòng trụ R 200 m có trong vanh_pho.glb, ảnh đổi theo buổi (sáng, chiều, mưa, tối), không dính sương.
## - Mép mềm thay tường thấp: lan can kênh, dãy nhà vành và món chặn ở 6 đầu đường. Bơ chạm đầu đường thì quay đầu,
##   kèm một câu nhắc. Tường vô hình nằm ở lớp đồ (LAYER_PROP) nên camera không bị kéo vào, xe không bị chặn.
## Nhà vành còn là bản tạm: gói P2 thay theo nha_vanh.json (x, z giữa mặt tiền, w, d, h, hướng mặt tiền, gần/xa).

const GLB := "res://assets/models/vanh/vanh_pho.glb"
const HOUSES := "res://assets/models/vanh/nha_vanh.json"
const SKY_DIR := "res://assets/textures/chan_troi/chan_troi_%s.png"
## Buổi của AnhSang -> ảnh chân trời
const SKY_FOR := {
	"pho_sang": "sang", "pho_cho": "sang", "pho_trua": "sang",
	"pho_chieu": "chieu", "pho_hoang_hon": "chieu", "pho_mua": "mua", "pho_toi": "toi",
}

## Mép vùng chơi (tường vô hình cao, lớp đồ): tây là lan can kênh, các phía kia ngay trước dãy nhà vành.
const EDGE_W := -48.45
const EDGE_E := 48.8
const EDGE_N := -31.2
const EDGE_S := 31.2

## 6 đầu đường: vùng chạm (x, z, cỡ x, cỡ z) ngay trong tường, hướng quay đầu về vùng chơi, câu nhắc.
const EXITS := [
	{"name": "dong", "rect": Rect2(47.0, -5.0, 1.8, 10.0), "back": Vector3.LEFT,
		"say": "Đường đang sửa, mình đi vòng về lò thôi."},
	{"name": "bac_cho", "rect": Rect2(-22.0, -31.2, 8.0, 1.8), "back": Vector3.BACK,
		"say": "Chợ đông quá, lạc mất bây giờ. Quay về giao bánh!"},
	{"name": "bac_x16", "rect": Rect2(12.0, -31.2, 8.0, 1.8), "back": Vector3.BACK,
		"say": "Bên đó đang đào cống, lò bánh ở phía này mà."},
	{"name": "nam_x16", "rect": Rect2(12.0, 29.4, 8.0, 1.8), "back": Vector3.FORWARD,
		"say": "Lô cốt chắn rồi, quay lại thôi."},
	{"name": "hem_nam", "rect": Rect2(-19.5, 29.4, 3.0, 1.8), "back": Vector3.FORWARD,
		"say": "Cổng hẻm khóa rồi. Giao bánh ở trong này thôi."},
	{"name": "cau", "rect": Rect2(-48.45, -6.0, 1.8, 12.0), "back": Vector3.RIGHT,
		"say": "Qua cầu là xa lò lắm rồi."},
]

## Mặt cầu kênh (đường lớn z −6…6): vồng nhẹ, xe máy chạy theo độ cao này
const BRIDGE_X := [-62.0, -58.6, -55.3, -52.0, -48.6]
const BRIDGE_Y := [0.0, 0.35, 0.45, 0.35, 0.0]
## Chợ ngoài đầu đường x = −18 phía bắc: xe chạy chậm (traffic.gd thêm vào slow_zones)
const MARKET_SLOW := Rect2(-22.0, -50.0, 8.0, 19.0)

## Số lát chia vành phố theo góc quanh tâm (frustum cắt lát sau lưng camera)
const SECTORS := 8
const BUBBLE_TIME := 2.6
const COOLDOWN := 4.0


## Dựng vành phố, phông chân trời và mép mềm. Gọi trong City.build (trước Blocks.merge_static: mesh ở đây
## mang vật liệu trên bề mặt chứ không qua material_override nên merge_static để nguyên).
static func build(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "VanhPho"
	root.add_to_group("vanh_pho")
	parent.add_child(root)
	_meshes(root)
	_house_bodies(root)
	_edges(root)
	var edge := MepMem.new()
	edge.name = "MepMem"
	root.add_child(edge)


## Đổi ảnh chân trời theo buổi (Thứ Bảy ngả trời dần thì gọi lại).
static func set_sky(tree: SceneTree, buoi: String) -> void:
	for n in tree.get_nodes_in_group("vanh_pho"):
		var mi: MeshInstance3D = n.get_node_or_null("ChanTroi")
		if mi and mi.get_meta("buoi", "") != buoi:
			mi.set_meta("buoi", buoi)
			(mi.mesh.surface_get_material(0) as StandardMaterial3D).albedo_texture = load(SKY_DIR % buoi)


## Độ cao mặt đường dưới (x, z): chỉ cầu kênh là không bằng 0.
static func road_y(x: float, z: float) -> float:
	if absf(z) > 6.0 or x < BRIDGE_X[0] or x > BRIDGE_X[-1]:
		return 0.0
	for i in BRIDGE_X.size() - 1:
		if x <= BRIDGE_X[i + 1]:
			return lerpf(BRIDGE_Y[i], BRIDGE_Y[i + 1], (x - BRIDGE_X[i]) / (BRIDGE_X[i + 1] - BRIDGE_X[i]))
	return 0.0


static func _meshes(root: Node3D) -> void:
	var scene: PackedScene = load(GLB)
	var src := scene.instantiate()
	# Bản web (Compatibility) không đổi màu đỉnh linear sang sRGB như Forward+ (giống PhoModels.mesh)
	var to_srgb := RenderingServer.get_rendering_device() == null
	var buoi: String = SKY_FOR.get(AnhSang.preset_for_day(PlayMode.day), "sang")
	# Mọi phần màu đỉnh (nhà, cây, cột, đường, mép mềm) gộp rồi chia 8 lát quanh tâm bản đồ:
	# camera ở trong vùng chơi chỉ thấy vài lát, các lát sau lưng bị cắt khỏi khung, đỡ tam giác.
	var sectors: Array = []
	for k in SECTORS:
		sectors.append([PackedVector3Array(), PackedVector3Array(), PackedColorArray()])
	for n: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
		var part := String(n.name)
		if part in ["ChanTroi", "Nuoc"]:
			var dst := ArrayMesh.new()
			dst.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, n.mesh.surface_get_arrays(0))
			dst.surface_set_material(0, _material(part, n.mesh.surface_get_material(0), buoi))
			var mi := MeshInstance3D.new()
			mi.name = part
			mi.mesh = dst
			mi.transform = n.transform
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if part == "ChanTroi":
				mi.set_meta("buoi", buoi)
			root.add_child(mi)
			continue
		for i in n.mesh.get_surface_count():
			var a := n.mesh.surface_get_arrays(i)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var nm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var c: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			for t in range(0, idx.size(), 3):
				var i0 := idx[t]
				var i1 := idx[t + 1]
				var i2 := idx[t + 2]
				var mid := n.transform * ((v[i0] + v[i1] + v[i2]) / 3.0)
				var s: Array = sectors[posmod(floori((atan2(mid.z, mid.x) + PI) / TAU * SECTORS), SECTORS)]
				for j in [i0, i1, i2]:
					s[0].append(n.transform * v[j])
					s[1].append(n.transform.basis * nm[j])
					var col: Color = c[j] if not c.is_empty() else Color.WHITE
					s[2].append(col.linear_to_srgb() if to_srgb else col)
	src.free()
	var mat := _material("VanhPho", null, buoi)
	for k in SECTORS:
		var s: Array = sectors[k]
		if s[0].is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s[0]
		arrays[Mesh.ARRAY_NORMAL] = s[1]
		arrays[Mesh.ARRAY_COLOR] = s[2]
		var dst := ArrayMesh.new()
		dst.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		dst.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.name = "Lat%d" % k
		mi.mesh = dst
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)


static func _material(part: String, src: Material, buoi: String) -> Material:
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if part == "ChanTroi":
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = load(SKY_DIR % buoi)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.disable_fog = true
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		return m
	if part == "Nuoc":
		m.albedo_color = (src as StandardMaterial3D).albedo_color if src is StandardMaterial3D else Color("#4E6B5E")
		m.roughness = 0.08
		m.metallic_specular = 0.7
		return m
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	return m


## Hộp va chạm thân nhà vành dãy gần (lớp thế giới: camera không chui vào nhà).
static func _house_bodies(root: Node3D) -> void:
	var f := FileAccess.open(HOUSES, FileAccess.READ)
	if f == null:
		return
	var face_dir := {"n": Vector3(0, 0, -1), "s": Vector3(0, 0, 1), "e": Vector3(1, 0, 0), "w": Vector3(-1, 0, 0)}
	for h: Dictionary in JSON.parse_string(f.get_as_text()):
		if not h.gan:
			continue
		var dir: Vector3 = face_dir[h.huong]
		var w: float = h.w
		var d: float = h.d
		var hh: float = h.h
		var size := Vector3(d, hh, w) if h.huong in ["e", "w"] else Vector3(w, hh, d)
		Blocks.collider(root, size, Vector3(h.x, hh / 2.0, h.z) - dir * d / 2.0)


## Tường vô hình bao vùng chơi, ở lớp đồ: Bơ và Chó Mực không qua được, camera và xe không bị chặn.
static func _edges(root: Node3D) -> void:
	var mid_x := (EDGE_W + EDGE_E) / 2.0
	var walls := [
		[Vector3(1, 20, EDGE_S - EDGE_N + 2), Vector3(EDGE_W - 0.5, 10, 0)],
		[Vector3(1, 20, EDGE_S - EDGE_N + 2), Vector3(EDGE_E + 0.5, 10, 0)],
		[Vector3(EDGE_E - EDGE_W + 2, 20, 1), Vector3(mid_x, 10, EDGE_N - 0.5)],
		[Vector3(EDGE_E - EDGE_W + 2, 20, 1), Vector3(mid_x, 10, EDGE_S + 0.5)],
	]
	for wall in walls:
		var body := Blocks.collider(root, wall[0], wall[1], Blocks.LAYER_PROP)
		body.name = "MepVungChoi"
	# Nền va chạm vùng chơi tới sát mép (mặt đất nhìn thấy của City chỉ phủ 96 x 60 m)
	Blocks.collider(root, Vector3(EDGE_E - EDGE_W + 1.0, 1.0, EDGE_S - EDGE_N + 1.0), Vector3(mid_x, -0.5, 0.0))


## Bơ tới đầu đường thì quay đầu về vùng chơi và nói một câu (mỗi đầu đường nghỉ vài giây mới nói lại).
class MepMem extends Node3D:
	var _player: Node3D
	var _bubble: Label3D
	var _until := 0.0
	var _cd := {}

	func _ready() -> void:
		_bubble = Label3D.new()
		_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bubble.font_size = 40
		_bubble.pixel_size = 0.004
		_bubble.outline_size = 12
		_bubble.modulate = Color("#FFF8EA")
		_bubble.outline_modulate = Color("#3D2A1E")
		_bubble.width = 520.0
		_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_bubble.no_depth_test = true
		_bubble.visible = false
		add_child(_bubble)

	func _physics_process(delta: float) -> void:
		for k in _cd.keys():
			_cd[k] = maxf(_cd[k] - delta, 0.0)
		if _player == null or not is_instance_valid(_player):
			_player = get_parent().get_parent().get("player")  # main (cảnh giao bánh) giữ biến player
			return
		var p := _player.global_position
		for e: Dictionary in EXITS:
			if (e.rect as Rect2).has_point(Vector2(p.x, p.z)) and _cd.get(e.name, 0.0) <= 0.0:
				_cd[e.name] = COOLDOWN
				if _player.has_method("turn_back"):
					_player.turn_back(e.back)
				_bubble.text = e.say
				_until = BUBBLE_TIME
		_until -= delta
		_bubble.visible = _until > 0.0
		if _bubble.visible:
			_bubble.global_position = p + Vector3(0, 1.3, 0)
