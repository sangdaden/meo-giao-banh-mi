class_name OutfitView
extends RefCounted
## Gắn model phụ kiện (assets/models/skin/phu_kien/<id>.glb) vào xương của mèo.
## Toạ độ trong glb tính từ điểm gắn trên Bơ chuẩn (tools/xuat_skin_game.py); skin.json ghi điểm gắn
## của từng giống, nên cùng một món đeo được lên giống khác: đồ đầu theo tâm và cỡ đầu, đồ khác theo điểm gắn.

const DIR := "res://assets/models/skin/"
## Điểm gắn -> xương mang nó
const BONE := {
	"head": "head", "neck": "spine", "back": "spine", "tail_mid": "tail_2", "tail_tip": "tail_4",
	"pawFL": "leg_FL", "pawFR": "leg_FR", "pawBL": "leg_BL", "pawBR": "leg_BR",
}

## Mũ trùm kín đầu: cụp tai xuống cho khỏi đâm xuyên mũ (thêm vào cờ "ears" trong skin.json)
const EARS_DOWN := ["mubaohiem", "munlen"]
## Đầu Bơ D cao hơn đầu mèo mẫu bên luồng skin: nâng vài món đội đầu lên (m, theo trục dọc của đầu)
const LIFT := {"muphuthuy": 0.035}

static var _meta := {}


static func meta() -> Dictionary:
	if _meta.is_empty() and FileAccess.file_exists(DIR + "skin.json"):
		_meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "skin.json"))
	return _meta


static func has_model(id: String) -> bool:
	return ResourceLoader.exists(DIR + "phu_kien/%s.glb" % id)


static func has_breed(breed: String) -> bool:
	return breed == "bo" or ResourceLoader.exists(DIR + "giong/%s_duc.glb" % breed)


static func breed_scene(breed: String) -> PackedScene:
	if breed == "bo" or not has_breed(breed):
		return null
	return load(DIR + "giong/%s_duc.glb" % breed)


static func ears_down(id: String) -> bool:
	return id in EARS_DOWN or str(meta().get("phu_kien", {}).get(id, {}).get("ears", "")) == "down"


## Vị trí gốc (trong không gian model) của một điểm gắn trên giống `breed`.
static func _socket_xform(sock: String, breed: String) -> Transform3D:
	var m := meta()
	var g: Dictionary = m.get("giong", {}).get(breed + "_duc", {})
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
	return Transform3D(Basis(), _v(socks.get(sock, [0, 0.3, 0])))


static func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


## Gắn món `id` vào skel. Trả về các node đã thêm (để gỡ ra sau).
static func attach(skel: Skeleton3D, id: String, breed := "bo") -> Array:
	var out := []
	if not has_model(id):
		return out
	var info: Dictionary = meta().get("phu_kien", {}).get(id, {}).get("objects", {})
	var scene: Node3D = load(DIR + "phu_kien/%s.glb" % id).instantiate()
	var compat := RenderingServer.get_rendering_device() == null
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var oi: Dictionary = info.get(str(mi.name), info.get(str(mi.get_parent().name), {}))
		var sock: String = oi.get("sock", "back")
		var bone := skel.find_bone(BONE.get(sock, "spine"))
		if bone < 0:
			continue
		var att := BoneAttachment3D.new()
		att.bone_idx = bone
		skel.add_child(att)
		var holder := Node3D.new()
		var xf := _socket_xform(sock, breed)
		if sock == "head":
			xf.origin += xf.basis.y.normalized() * float(LIFT.get(id, 0.0))
		holder.transform = skel.get_bone_global_rest(bone).affine_inverse() * xf
		att.add_child(holder)
		var copy := MeshInstance3D.new()
		copy.mesh = mi.mesh
		if compat:
			copy.mesh = srgb_mesh(mi.mesh)
		holder.add_child(copy)
		style(copy, oi)
		copy.layers = 1 << 10  # cùng lớp thân Bơ: góc nhìn thứ nhất không vẽ
		out.append(att)
	scene.free()
	return out


## Vật liệu cho phụ kiện: màu đỉnh, độ nhám theo loại chất liệu như blend.py.
static func style(mi: MeshInstance3D, oi: Dictionary) -> void:
	var kind: String = oi.get("kind", "cloth")
	var rough := {"fur": .78, "cloth": .9, "skin": .55, "plastic": .35, "rubber": .6, "metal": .4, "glass": .05,
		"wood": .7, "gloss": .2, "paper": .85}
	for i in mi.mesh.get_surface_count():
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
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
