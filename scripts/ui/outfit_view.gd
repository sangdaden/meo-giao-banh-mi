class_name OutfitView
extends RefCounted
## Gắn model phụ kiện (assets/models/skin/phu_kien/<id>.glb) vào xương của mèo.
## Toạ độ trong glb tính từ điểm gắn trên Bơ chuẩn (tools/xuat_skin_game.py); skin.json ghi điểm gắn
## của từng giống, nên cùng một món đeo được lên giống khác: đồ đầu theo tâm và cỡ đầu, đồ khác theo điểm gắn.

const DIR := "res://assets/models/skin/"
## Điểm gắn -> xương mang nó (bộ 22 xương; tên sau là của bộ 16 xương cũ, dùng nếu model chưa đổi)
const BONE := {
	"head": ["head"], "neck": ["chest", "spine"], "back": ["chest", "spine"],
	"tail_mid": ["tail_2"], "tail_tip": ["tail_4"],
	"pawFL": ["paw_FL", "leg_FL"], "pawFR": ["paw_FR", "leg_FR"], "pawBL": ["paw_BL", "leg_BL"], "pawBR": ["paw_BR", "leg_BR"],
	# Cổ tất, cổ ủng, cổ giày patin: theo xương cẳng chân để không bị bàn chân bẻ gập
	"legFL": ["forearm_FL", "leg_FL"], "legFR": ["forearm_FR", "leg_FR"], "legBL": ["shin_BL", "leg_BL"], "legBR": ["shin_BR", "leg_BR"],
}

## Mũ trùm kín đầu: cụp tai xuống cho khỏi đâm xuyên mũ (thêm vào cờ "ears" trong skin.json).
## Mũ bảo hiểm và mũ len làm kỹ (22/10) có lỗ cho tai thò ra nên không cụp nữa (Sang: không được mất tai).
const EARS_DOWN := []
## Đầu Bơ D cao hơn đầu mèo mẫu bên luồng skin: nâng vài món đội đầu lên (m, theo trục dọc của đầu)
const LIFT := {"muphuthuy": 0.012}
## Giỏ giao bánh: ổ bánh bên trong chỉ hiện khi Bơ đang mang bánh
const BASKETS := ["giomay", "giodan"]

static var _meta := {}


static func meta() -> Dictionary:
	if _meta.is_empty() and FileAccess.file_exists(DIR + "skin.json"):
		_meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "skin.json"))
	return _meta


static func has_model(id: String) -> bool:
	return ResourceLoader.exists(DIR + "phu_kien/%s.glb" % id)


static func has_breed(breed: String) -> bool:
	return breed == "bo" or ResourceLoader.exists(DIR + "giong/%s_duc.glb" % breed)


## Model giống `breed` theo giới tính. Bản cái (<id>_cai.glb) chưa xuất thì dùng bản đực; null = Bơ chuẩn.
static func breed_scene(breed: String, sex := "duc") -> PackedScene:
	if has_sex_model(breed, sex) and sex == "cai":
		return load(DIR + "giong/%s_cai.glb" % breed)
	if breed == "bo" or not has_breed(breed):
		return null
	return load(DIR + "giong/%s_duc.glb" % breed)


## Có model riêng cho giới tính này chưa (Bơ đực là model chuẩn assets/models/bo.glb).
static func has_sex_model(breed: String, sex: String) -> bool:
	if sex == "duc":
		return has_breed(breed)
	return ResourceLoader.exists(DIR + "giong/%s_cai.glb" % breed)


## Đồ chân có đế cao (giày patin) nâng cả thân mèo lên (m), ghi ở "lift" trong skin.json.
static func lift(id: String) -> float:
	return float(meta().get("phu_kien", {}).get(id, {}).get("lift", 0.0))


static func ears_down(id: String) -> bool:
	return id in EARS_DOWN or str(meta().get("phu_kien", {}).get(id, {}).get("ears", "")) == "down"


## Vị trí gốc (trong không gian model) của một điểm gắn trên giống `breed`.
static func _socket_xform(sock: String, breed: String, sex := "duc") -> Transform3D:
	var m := meta()
	var gs: Dictionary = m.get("giong", {})
	var g: Dictionary = gs.get(breed + "_" + sex, gs.get(breed + "_duc", {}))
	if sock == "head":
		var bo_head: Dictionary = m.get("bo_head", {})
		var h: Dictionary = g if g.has("basis") else bo_head
		var b: Array = h.get("basis", [1, 0, 0, 0, 1, 0, 0, 0, 1])
		var basis := Basis(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), Vector3(b[6], b[7], b[8]))
		var hc := _v(h.get("hc", [0, 0.43, 0.17]))
		var piv := _v(h.get("pivot", [0, 0.34, 0.12]))
		var k := 1.0
		if h != bo_head and bo_head.has("hr"):
			k = (_v(h.hr) / _v(bo_head.hr)).dot(Vector3.ONE) / 3.0  # đầu to/nhỏ hơn Bơ thì đồ đội đầu to/nhỏ theo
		return Transform3D(basis * Basis.from_scale(Vector3.ONE * k), basis * (hc - piv) + piv)
	var socks: Dictionary = g.get("sockets", m.get("bo_sockets", {}))
	if sock.begins_with("leg"):
		sock = "paw" + sock.substr(3)  # phần cổ xuất cùng gốc với bàn chân
	# Mèo cái nhỏ hơn 7%, Lân Tết to hơn 6%: đồ đeo thân (túi, khăn, tất...) co giãn theo cỡ model
	return Transform3D(Basis.from_scale(Vector3.ONE * float(g.get("size", 1.0))), _v(socks.get(sock, [0, 0.3, 0])))


static func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


## Gắn món `id` vào skel. Trả về các node đã thêm (để gỡ ra sau).
## light: dùng bản nhẹ phu_kien_nhe/ nếu có (mèo NPC trên bản web, gói G10).
static func attach(skel: Skeleton3D, id: String, breed := "bo", sex := "duc", light := false) -> Array:
	var out := []
	if not has_model(id):
		return out
	var info: Dictionary = meta().get("phu_kien", {}).get(id, {}).get("objects", {})
	var path := DIR + "phu_kien/%s.glb" % id
	if light and ResourceLoader.exists(DIR + "phu_kien_nhe/%s.glb" % id):
		path = DIR + "phu_kien_nhe/%s.glb" % id
	var scene: Node3D = load(path).instantiate()
	var compat := RenderingServer.get_rendering_device() == null
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var oi: Dictionary = info.get(str(mi.name), info.get(str(mi.get_parent().name), {}))
		var sock: String = oi.get("sock", "back")
		var bone := -1
		for n in BONE.get(sock, BONE.back):
			bone = skel.find_bone(n) if bone < 0 else bone
		if bone < 0:
			continue
		var att := BoneAttachment3D.new()
		att.bone_idx = bone
		skel.add_child(att)
		var holder := Node3D.new()
		var xf := _socket_xform(sock, breed, sex)
		if sock == "head":
			xf.origin += xf.basis.y.normalized() * float(LIFT.get(id, 0.0))
		holder.transform = skel.get_bone_global_rest(bone).affine_inverse() * xf
		att.add_child(holder)
		var copy := MeshInstance3D.new()
		copy.mesh = mi.mesh
		if compat:
			copy.mesh = srgb_mesh(mi.mesh)
		holder.add_child(copy)
		# Ổ bánh trong giỏ giao bánh (hiện khi đang mang bánh). Chỉ giỏ: bánh xe patin, huy hiệu bánh nổi cũng tên "Banh"
		if id in BASKETS and (str(mi.name).begins_with("Banh") or str(mi.get_parent().name).begins_with("Banh")):
			copy.set_meta("loaf", true)
		style(copy, oi)
		if not oi.get("shadow", true):
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # vành mũ rộng làm tối cả mặt
		copy.layers = 1 << 10  # cùng lớp thân Bơ: góc nhìn thứ nhất không vẽ
		out.append(att)
	scene.free()
	return out


## Vật liệu cho phụ kiện: màu đỉnh, độ nhám theo loại chất liệu như blend.py.
## Đồ vải bay (có "cloth" trong skin.json) dùng shader vai_bay; player.gd đẩy tốc độ vào qua cloth_drive().
static func style(mi: MeshInstance3D, oi: Dictionary) -> void:
	var kind: String = oi.get("kind", "cloth")
	var tex: Texture2D = load(DIR + str(oi.tex)) if oi.has("tex") else null  # hoa văn lặp (ô caro, chấm bi)
	if oi.has("cloth"):
		var sm := ShaderMaterial.new()
		sm.shader = preload("res://shaders/vai_bay.gdshader")
		sm.set_shader_parameter("hinge", _v(oi.cloth.get("hinge", [0, 0.056, 0.12])))
		sm.set_shader_parameter("mode", int(oi.cloth.get("mode", 0)))  # 1 lá cờ, 2 đồ treo lắc
		sm.set_shader_parameter("amp", float(oi.cloth.get("amp", 1.0)))
		sm.set_shader_parameter("ridge", float(oi.cloth.get("ridge", 1.0)))
		sm.set_shader_parameter("lac_dir", float(oi.cloth.get("dir", 1.0)))
		sm.set_shader_parameter("axle", float(oi.cloth.get("axle", 0.0)))  # 3: bánh xe patin, nửa trục trước/sau
		if tex:
			sm.set_shader_parameter("use_tex", true)
			sm.set_shader_parameter("tex", tex)
		var rough := {"gloss": .25, "metal": .4, "paper": .85, "wood": .7}
		sm.set_shader_parameter("roughness_v", rough.get(kind, 0.9))
		sm.set_shader_parameter("emit", float(oi.get("emit", 0.0)))
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, sm)
		mi.set_meta("cloth", sm)
		mi.extra_cull_margin = 0.3  # áo bay ra khỏi khung bao của mesh nghỉ
		return
	var rough := {"fur": .78, "cloth": .9, "skin": .55, "plastic": .35, "rubber": .6, "metal": .4, "glass": .05,
		"wood": .7, "gloss": .2, "paper": .85}
	for i in mi.mesh.get_surface_count():
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = tex == null
		if tex:
			m.albedo_texture = tex
			m.texture_repeat = true
		m.roughness = rough.get(kind, 0.7)
		m.metallic = float(oi.get("metal", 0.0)) if kind != "metal" else maxf(float(oi.get("metal", 1.0)), 0.6)
		var alpha := float(oi.get("alpha", 1.0))
		if alpha < 1.0 or kind == "glass":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(1, 1, 1, minf(alpha, 0.45) if kind == "glass" else alpha)
		if float(oi.get("emit", 0.0)) > 0.0:
			m.emission_enabled = true
			m.emission_energy_multiplier = float(oi.emit)
		if kind in ["cloth", "fur"]:
			m.rim_enabled = true
			m.rim = 0.3
		mi.set_surface_override_material(i, m)


## Bản web (Compatibility) không đổi màu đỉnh linear -> sRGB như Forward+: đổi sẵn để màu giống nhau.
static func srgb_mesh(src: Mesh) -> ArrayMesh:
	var dst := ArrayMesh.new()
	for i in src.get_surface_count():
		var arrays := src.surface_get_arrays(i)
		var cols = arrays[Mesh.ARRAY_COLOR]
		if cols is PackedColorArray:
			for k in cols.size():
				cols[k] = cols[k].linear_to_srgb()
			arrays[Mesh.ARRAY_COLOR] = cols
		dst.add_surface_from_arrays(src.surface_get_primitive_type(i), arrays)
	return dst


## Các vật liệu vải bay trong những node phụ kiện đã gắn.
static func cloth_mats(nodes: Array) -> Array:
	var out := []
	for n in nodes:
		if not is_instance_valid(n):
			continue
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if mi.has_meta("cloth"):
				out.append(mi.get_meta("cloth"))
	return out


## Ổ bánh trong giỏ giao bánh (bộ phận tên Banh*): player.gd chỉ cho hiện khi đang mang bánh.
static func loaves(nodes: Array) -> Array:
	var out := []
	for n in nodes:
		if not is_instance_valid(n):
			continue
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if mi.has_meta("loaf"):
				out.append(mi)
	return out


## Đẩy chuyển động của mèo vào vải bay: speed 0..1, fall -1..1 (dương là đang rơi), turn -1..1.
static func cloth_drive(mats: Array, speed: float, fall: float, turn: float, roll := 0.0) -> void:
	for m: ShaderMaterial in mats:
		m.set_shader_parameter("roll", roll)
		m.set_shader_parameter("speed", speed)
		m.set_shader_parameter("fall", fall)
		m.set_shader_parameter("turn", turn)
