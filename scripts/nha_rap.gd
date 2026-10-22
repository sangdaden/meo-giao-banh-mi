class_name NhaRap
## Bộ ráp nhà theo tầng P2 (Sang duyệt 22/10 10:19, trang https://claude.ai/artifact/8N5AF4xQaQ6HwjgDxR5qrr bản 2):
## 8 kiểu trệt, 6 kiểu lầu, 5 kiểu mái, 4 bề ngang 3,2 / 4,0 / 4,8 / 6,0 m, 10 màu sơn, 21 bảng hiệu riêng từng tiệm.
## Bàn giao: /mnt/project-files/thiet-ke-lai-khu-pho/p2-bo-rap-nha/BAN-GIAO.md. Mảnh xuất bằng tools/nha_rap (README ở đó).
##
## - Mỗi căn ghép trệt + lầu + mái thành một mesh màu đỉnh (mặt tường "son" đổi sang màu sơn của căn), dùng chung
##   PhoModels.material() nên Blocks.merge_static gộp theo ô 24 m và tự làm LOD như nhà cũ.
## - Mảnh trệt bản game không có bạt riêng: mái hiên 2,9 m liền dãy của CityProps.awning vẫn là chỗ Bơ chạy, trú mưa.
##   Vì thế bảng hiệu là mảnh riêng, nâng lên trên mái hiên (đáy 3,02 m) và đẩy ra trước mặt lầu 1 (ban công, chuồng cọp).
##   Chữ bảng hiệu là ảnh atlas (tools/nha_rap/atlas_chu.py, đúng phông từng bảng) dán lên tấm phẳng trước bảng.
## - Họ nhà (HO) giữ số lầu + kiểu mái của mẫu nhà lấp cũ ở cùng ô, để độ cao mái dãy nam khối 1–3 (đường sân thượng
##   Thứ Tư), lối leo, bám mép các ngày khác như cũ. Mặt mái cho SanThuong lấy từ profile mái của bộ ráp (roof_profile).
## - Đồ gắn tường P4 (số nhà, máy lạnh, chậu ban công, lồng chim, dây phơi, bảng hiệu dọc) đặt ở điểm gắn gan_* của mảnh,
##   gộp ô 8 m, tắt sau 28 m, không đổ bóng (góc phố nặng nhất đã sát 400k tam giác).

const DIR := "res://assets/models/nha_rap/"
const META := DIR + "nha_rap.json"
const CHU_TEX := "res://assets/textures/nha_rap/chu_bang.png"
const P4 := "res://assets/models/pho/chi_tiet/"
const WIDTHS := [3.2, 4.0, 4.8, 6.0]
const G0 := 3.4   ## cao tầng trệt
const F := 3.1    ## cao mỗi lầu
const SIGN_BOTTOM := 3.02  ## đáy bảng hiệu: ngay trên mặt mái hiên 2,96 m
const SON := {
	"vang_nghe": "#E2C07E", "xanh_ngoc": "#77AD9C", "cam_dat": "#DB957A", "bac_ha": "#B6CFC8", "kem": "#EEDDB2",
	"hong_phan": "#CFA0BA", "da_troi": "#9FBEDD", "vang_chanh": "#DCD27A", "la_non": "#A9C68A", "xam_trang": "#D6D0C2",
}
## Kiểu trệt và trọng số chọn (phố có nhiều nhà ở hơn tiệm)
const TRET := {"nha_o": 4, "tap_hoa": 1, "quan_pho": 1, "sua_dt": 1, "tiem_may": 1, "tiem_thuoc": 1, "gui_xe": 1, "hot_toc": 1}
const LAU := ["ban_cong", "cua_chop", "lo_gia", "chuong_cop", "kinh_lua", "tuong_kin"]
## Họ nhà theo mẫu nhà lấp cũ cùng ô: [số lầu, các kiểu mái được chọn]. Độ cao mái khớp số đo cũ trong
## SanThuong.ROOF_PROFILE (sân thượng 9,75 / 12,85 m, tôn 7,3 / 10,4 / 13,5 m mép trước, ngói nóc 8,4 / 11,6 m).
const HO := {
	"nha_A": [2, ["tum"]], "nha_B": [3, ["ton"]], "nha_C": [1, ["ngoi"]], "nha_D": [2, ["ngoi"]], "nha_E": [1, ["ton"]],
	"nha_F": [2, ["san_thuong", "luoi"]], "nha_G": [3, ["tum"]], "nha_H": [1, ["ngoi"]], "nha_I": [2, ["ton"]], "nha_K": [2, ["ngoi"]],
}
## Mái ở các dãy không thuộc đường sân thượng Thứ Tư: chọn tự do (cùng số lầu với mẫu cũ), trọng số
const MAI_TU_DO := {"san_thuong": 3, "tum": 2, "ton": 2, "luoi": 2, "ngoi": 1}
## Lầu nhô ra trước mặt tiền ít (bảng hiệu dọc chìa ra được, không đụng ban công)
const FLAT_LAU := ["cua_chop", "lo_gia", "tuong_kin"]
## Chữ bảng hiệu dọc theo kiểu tiệm
const DOC := {"tap_hoa": "TẠP HÓA", "quan_pho": "PHỞ", "sua_dt": "ĐIỆN THOẠI", "tiem_may": "TIỆM MAY",
	"tiem_thuoc": "NHÀ THUỐC", "gui_xe": "GIỮ XE", "hot_toc": "HỚT TÓC"}
const WALL_CELL := 8.0
const WALL_VIEW := 22.0
const TEXT_CELL := 24.0
const TEXT_VIEW := 45.0
const GROUP := "nha_rap"

static var _meta := {}
static var _parts := {}     ## tên mảnh -> [[arrays, là mặt sơn]]
static var _houses := {}    ## khóa căn -> ArrayMesh
static var _profiles := {}  ## khóa căn (meta "model" của hộp thân) -> mặt mái kiểu SanThuong.ROOF_PROFILE
static var _walls := {}     ## khóa ô -> SurfaceTool đồ gắn tường
static var _texts := {}     ## khóa ô -> SurfaceTool chữ
static var _signs := {}     ## kiểu tiệm -> lượt đã dùng (xoay vòng 3 bảng)
static var _text_mat: StandardMaterial3D
static var _number := 0
static var houses: Array = []  ## [{spec, x0, w, face_z, faces_south}] (test, công cụ đo đọc)


static func meta() -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string(META))
	return _meta


## Xoá trạng thái trước khi dựng phố mới (City.build gọi đầu tiên).
static func begin() -> void:
	_walls.clear()
	_texts.clear()
	_signs.clear()
	_number = 0
	houses.clear()


## Bề ngang chuẩn gần nhất (game giãn x tối đa ±0,4 m như nhà cũ; ô lẻ rộng hơn thì giãn thêm).
static func kit_width(w: float) -> float:
	var best: float = WIDTHS[0]
	for k: float in WIDTHS:
		if absf(k - w) < absf(best - w):
			best = k
	return best


## Chọn một căn trong họ của mẫu nhà lấp cũ. rng riêng của căn (City không bị lệch chuỗi số ngẫu nhiên).
## keep_roof: dãy có đường sân thượng Thứ Tư (dãy nam khối 1–3), giữ đúng kiểu mái của mẫu cũ cho mái cao như cũ.
static func spec_for(model: String, w: float, rng: RandomNumberGenerator, keep_roof := true) -> Dictionary:
	var ho: Array = HO.get(model, [2, ["san_thuong"]])
	var tret := _weighted(TRET, rng)
	var lau: Array = []
	for i in int(ho[0]):
		# lầu trên hay lặp lại lầu dưới như nhà thật
		lau.append(lau[i - 1] if i > 0 and rng.randf() < 0.45 else LAU[rng.randi() % LAU.size()])
	var roofs: Array = ho[1]
	var mai: String = roofs[rng.randi() % roofs.size()] if keep_roof else _weighted(MAI_TU_DO, rng)
	var s := {"w": kit_width(w), "tret": tret, "lau": lau, "mai": mai,
		"son": SON.keys()[rng.randi() % SON.size()], "bang": ""}
	if tret != "nha_o":
		var names := _sign_names(tret)
		var n: int = _signs.get(tret, rng.randi() % names.size())
		_signs[tret] = n + 1
		s.bang = names[n % names.size()]
	return s


static func key_of(s: Dictionary) -> String:
	return "rap:%s_%d|%s|%s|%s" % [s.tret, roundi(s.w * 10), ",".join(s.lau), s.mai, s.son]


## Mặt trên cùng của tường (chỗ đặt mái)
static func top_of(s: Dictionary) -> float:
	return G0 + F * (s.lau as Array).size()


## Độ cao hộp va chạm thân nhà: mặt sân thượng, hoặc giữa mái dốc (như nhà cũ: đỉnh model trừ phần mái).
static func body_height(s: Dictionary) -> float:
	var m: Dictionary = _piece_meta("mai_%s_%d" % [s.mai, roundi(s.w * 10)]).mai
	var hi := 0.0
	for p: Array in m.mat:
		hi = maxf(hi, p[1])
	return top_of(s) + (hi if m.kieu == "bang" else hi * 0.5)


## Đặt một căn vào dãy phố như PhoModels.put_house: x0 mép trái (trục X thế giới), w bề ngang ô,
## face_z mặt tiền, faces_south mặt tiền nhìn +z. Trả khóa căn (gắn vào meta "model" của hộp thân cho SanThuong).
static func put_house(parent: Node3D, s: Dictionary, x0: float, w: float, face_z: float, faces_south: bool, rng: RandomNumberGenerator) -> String:
	var sx := w / float(s.w)
	var xf := Transform3D(Basis.from_scale(Vector3(sx, 1, 1)), Vector3(x0, 0, face_z))
	if not faces_south:
		xf = Transform3D(Basis(Vector3.UP, PI) * Basis.from_scale(Vector3(sx, 1, 1)), Vector3(x0 + w, 0, face_z))
	var mi := MeshInstance3D.new()
	mi.name = "NhaRap"
	mi.mesh = house_mesh(s)
	mi.material_override = PhoModels.material()
	mi.transform = xf
	parent.add_child(mi)
	var key := key_of(s)
	if not _profiles.has(key):
		_profiles[key] = _profile(s)
	if not faces_south:
		_profiles[key + "|n"] = _mirror(_profiles[key])
		key += "|n"
	if s.bang != "":
		_sign(parent, s, xf)
	_wall_items(s, xf, rng)
	houses.append({"spec": s, "x0": x0, "w": w, "face_z": face_z, "faces_south": faces_south})
	return key


## Mặt mái đo sẵn (định dạng SanThuong.ROOF_PROFILE): 3 dải ngang 25/50/75 %, 16 điểm cách mặt tiền 0..7,5 m.
static func roof_profile(model: String) -> Array:
	return _profiles.get(model, [])


## Gộp đồ gắn tường và chữ bảng hiệu thành mesh theo ô (City.build gọi sau khi dựng hết các khối).
static func commit(parent: Node3D) -> void:
	for key: String in _walls:
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, _walls[key].commit_to_arrays(), [], {}, PhoModels.material())
		im.generate_lods(25, 60, [])
		_commit_one(parent, im.get_mesh(), WALL_VIEW, "DoGanTuong")
	for key: String in _texts:
		var m: ArrayMesh = _texts[key].commit()
		m.surface_set_material(0, text_material())
		_commit_one(parent, m, TEXT_VIEW, "ChuBangHieu")
	_walls.clear()
	_texts.clear()


static func _commit_one(parent: Node3D, m: Mesh, view: float, n: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = view
	mi.visibility_range_end_margin = 5.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mi.add_to_group(GROUP)
	parent.add_child(mi)


## Vật liệu chữ: ảnh atlas, cắt alpha (không cần xếp thứ tự trong suốt), tối thì tự sáng nhẹ (DenToi đổi).
static func text_material() -> StandardMaterial3D:
	if _text_mat == null:
		_text_mat = StandardMaterial3D.new()
		_text_mat.albedo_texture = load(CHU_TEX)
		_text_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_text_mat.alpha_scissor_threshold = 0.45
		_text_mat.roughness = 0.8
		_text_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_text_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return _text_mat


# ------------------------------------------------------------------ mesh một căn

static func house_mesh(s: Dictionary) -> ArrayMesh:
	var key := key_of(s)
	if _houses.has(key):
		return _houses[key]
	var w10 := roundi(s.w * 10)
	var parts := [["tret_%s_%d" % [s.tret, w10], 0.0]]
	for i in (s.lau as Array).size():
		parts.append(["lau_%s_%d" % [s.lau[i], w10], G0 + F * i])
	parts.append(["mai_%s_%d" % [s.mai, w10], top_of(s)])
	var paint := _vcolor(Color(SON[s.son]))
	var v := PackedVector3Array()
	var nm := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	for p: Array in parts:
		var up := Vector3(0, p[1], 0)
		for surf: Array in _piece(p[0]):
			var a: Array = surf[0]
			var base := v.size()
			var pv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			for q in pv:
				v.append(q + up)
			nm.append_array(a[Mesh.ARRAY_NORMAL])
			if surf[1]:
				for k in pv.size():
					c.append(paint)
			else:
				c.append_array(a[Mesh.ARRAY_COLOR])
			for i: int in a[Mesh.ARRAY_INDEX]:
				idx.append(base + i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = nm
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = idx
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_houses[key] = out
	return out


## Các mặt của một mảnh: [[arrays (màu đỉnh đã đổi cho bản web), là mặt sơn]]
static func _piece(name: String) -> Array:
	if _parts.has(name):
		return _parts[name]
	var path := DIR + ("bang/" if name.begins_with("bang_") else "manh/") + name + ".glb"
	var root: Node = (load(path) as PackedScene).instantiate()
	var src: Mesh = (root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	var web := RenderingServer.get_rendering_device() == null
	var out := []
	for i in src.get_surface_count():
		var a := src.surface_get_arrays(i)
		var mat := src.surface_get_material(i)
		var is_son := mat != null and mat.resource_name == "son"
		if a[Mesh.ARRAY_INDEX] == null:
			var seq := PackedInt32Array()
			seq.resize((a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
			for k in seq.size():
				seq[k] = k
			a[Mesh.ARRAY_INDEX] = seq
		if not is_son and web and a[Mesh.ARRAY_COLOR] != null:
			var cols: PackedColorArray = a[Mesh.ARRAY_COLOR]
			for k in cols.size():
				cols[k] = cols[k].linear_to_srgb()
			a[Mesh.ARRAY_COLOR] = cols
		out.append([a, is_son])
	root.free()
	_parts[name] = out
	return out


static func _piece_meta(name: String) -> Dictionary:
	return meta().manh.get(name, {})


## Màu sơn (sRGB) thành màu đỉnh như các mảnh: bản web giữ sRGB, Forward+ dùng tuyến tính
static func _vcolor(c: Color) -> Color:
	return c if RenderingServer.get_rendering_device() == null else c.srgb_to_linear()


static func _weighted(table: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in table:
		total += int(table[k])
	var r := rng.randi() % total
	for k: String in table:
		r -= int(table[k])
		if r < 0:
			return k
	return table.keys()[0]


static func _sign_names(tret: String) -> Array:
	var out := []
	for k: String in meta().bang:
		if k.ends_with("_40") and meta().bang[k].tiem == tret:
			out.append(k.trim_suffix("_40"))
	out.sort()
	return out


# ------------------------------------------------------------------ mái cho đường sân thượng

static func _profile(s: Dictionary) -> Array:
	var m: Dictionary = _piece_meta("mai_%s_%d" % [s.mai, roundi(s.w * 10)]).mai
	var base := top_of(s)
	var rows := []
	for xf in [0.25, 0.5, 0.75]:
		var x: float = float(s.w) * xf
		var row := []
		for i in 16:
			var d := 0.5 * i
			if d > 7.3:
				row.append(-1.0)
				continue
			var y := base + _along(m.mat, d)
			for o: Array in m.vat_can:
				if x >= o[0] and x <= o[1] and d >= o[2] and d <= o[3]:
					y = maxf(y, base + float(o[4]))
			row.append(snappedf(y, 0.01))
		rows.append(row)
	return rows


static func _along(pts: Array, d: float) -> float:
	if d <= pts[0][0]:
		return pts[0][1]
	for i in pts.size() - 1:
		if d <= pts[i + 1][0]:
			return lerpf(pts[i][1], pts[i + 1][1], (d - pts[i][0]) / (pts[i + 1][0] - pts[i][0]))
	return pts[-1][1]


## Nhà dãy bắc quay 180°: dải 25 % thành dải 75 % theo trục X thế giới
static func _mirror(rows: Array) -> Array:
	return [rows[2], rows[1], rows[0]]


# ------------------------------------------------------------------ bảng hiệu + chữ

## Phần nhô ra trước mặt tiền của lầu 1 (ban công 1,0 m, chuồng cọp 0,55 m...), hoặc mái nếu nhà một tầng
static func _front(s: Dictionary) -> float:
	var w10 := roundi(s.w * 10)
	var first: String = ("lau_%s_%d" % [s.lau[0], w10]) if not (s.lau as Array).is_empty() else ("mai_%s_%d" % [s.mai, w10])
	return maxf(float(_piece_meta(first).max[2]), 0.05)


static func _sign(parent: Node3D, s: Dictionary, xf: Transform3D) -> void:
	var name := "%s_%d" % [s.bang, roundi(s.w * 10)]
	var info: Dictionary = meta().bang[name]
	var lift := Vector3(0, SIGN_BOTTOM - float(info.min[1]), _front(s) - 0.02)
	var mi := MeshInstance3D.new()
	mi.name = "BangHieu"
	mi.mesh = _sign_mesh(name)
	mi.material_override = PhoModels.material()
	# bảng nằm sát mặt tiền trên mái hiên: bóng gần như không thấy, bớt ~4k tam giác bóng ở ngã tư
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = xf * Transform3D(Basis.IDENTITY, lift)
	parent.add_child(mi)
	for t: Dictionary in info.chu:
		var uv: Array = t.uv
		var z: float = float(t.z) + lift.z
		_quad(xf, Vector3(t.x[0], t.y[0] + lift.y, z), Vector3(t.x[1], t.y[0] + lift.y, z),
			Vector3(t.x[1], t.y[1] + lift.y, z), Vector3(t.x[0], t.y[1] + lift.y, z), uv)


static func _sign_mesh(name: String) -> ArrayMesh:
	if _houses.has(name):
		return _houses[name]
	var surf: Array = _piece(name)[0]
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surf[0])
	_houses[name] = out
	return out


## Tấm chữ a-b-c-d (ngược chiều kim đồng hồ nhìn từ trước) trong hệ căn nhà, uv [u0, v0, u1, v1] của atlas
static func _quad(xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv: Array) -> void:
	var p := xf * ((a + c) / 2.0)
	var key := "%d:%d" % [floori(p.x / TEXT_CELL), floori(p.z / TEXT_CELL)]
	if not _texts.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_texts[key] = st
	var t: SurfaceTool = _texts[key]
	var n := (xf.basis * Vector3.BACK).normalized()
	var pts := [[a, Vector2(uv[0], uv[3])], [b, Vector2(uv[2], uv[3])], [c, Vector2(uv[2], uv[1])],
		[a, Vector2(uv[0], uv[3])], [c, Vector2(uv[2], uv[1])], [d, Vector2(uv[0], uv[1])]]
	for q: Array in pts:
		t.set_normal(n)
		t.set_uv(q[1])
		t.add_vertex(xf * (q[0] as Vector3))


# ------------------------------------------------------------------ đồ gắn tường P4

static func _wall_items(s: Dictionary, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	var w10 := roundi(s.w * 10)
	var w: float = s.w
	var tret: Dictionary = _piece_meta("tret_%s_%d" % [s.tret, w10])
	# Biển số nhà trên trụ trái, dưới mái hiên (chỉ giữ một tấm của bộ ba biển P4)
	var so: Array = tret.gan.gan_so_nha[0]
	_number += 1
	_item("bien_so_nha#trai", xf, Vector3(so[0] + 0.1, so[1] - 0.11, so[2] + 0.02))
	var lau: Array = s.lau
	for i in lau.size():
		var kind: String = lau[i]
		var y0 := G0 + F * i
		var g: Dictionary = _piece_meta("lau_%s_%d" % [kind, w10]).gan
		var front := float(_piece_meta("lau_%s_%d" % [kind, w10]).max[2])
		var roll := rng.randf()
		if roll < 0.35 and g.has("gan_may_lanh_1"):
			var p: Array = g.gan_may_lanh_1[0]
			_item("may_lanh", xf, Vector3(minf(p[0], w - 0.55), y0 + 0.85, 0.2))
		elif roll < 0.6 and kind in ["ban_cong", "kinh_lua"]:
			# chậu móc ngoài lan can
			var pot: String = ["chau_ban_cong", "chau_ban_cong__rau", "chau_ban_cong__lan"][rng.randi() % 3]
			_item(pot, xf, Vector3(clampf(w * 0.3, 0.6, w - 0.6), y0 + 0.3, front + 0.22))
		elif roll < 0.72 and g.has("gan_long_chim") and kind in ["ban_cong", "lo_gia", "kinh_lua"]:
			var p: Array = g.gan_long_chim[0]
			_item("long_chim" if rng.randf() < 0.5 else "long_chim__che", xf, Vector3(p[0], y0 + 1.85, minf(p[2], front - 0.25)))
		elif roll < 0.85 and kind in ["ban_cong", "lo_gia"]:
			var sx := minf(1.0, (w - 0.5) / 3.53)
			_item("day_phoi", xf, Vector3(w / 2.0, y0 + 0.8, 0.45), sx)
	# Bảng hiệu dọc chìa ra vỉa hè: tiệm có lầu 1 phẳng (không ban công), đáy trên mái hiên
	if s.bang != "" and not lau.is_empty() and lau[0] in FLAT_LAU and rng.randf() < 0.6:
		_item("bang_doc", xf, Vector3(w - 0.08, 3.05, 0.425 + 0.05))


## Thêm một món P4 vào ô 8 m. pos trong hệ căn nhà (trước khi giãn x), sx giãn riêng món theo x.
static func _item(model: String, xf: Transform3D, pos: Vector3, sx := 1.0) -> void:
	var w := xf * pos
	var key := "%d:%d" % [floori(w.x / WALL_CELL), floori(w.z / WALL_CELL)]
	if not _walls.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_walls[key] = st
	# món không giãn theo bề ngang căn: bỏ phần giãn x của xf, chỉ giữ hướng quay
	var rot := Basis(Vector3.UP, PI) if xf.basis.x.x < 0.0 else Basis.IDENTITY
	_walls[key].append_from(_p4(model), 0, Transform3D(rot * Basis.from_scale(Vector3(sx, 1, 1)), w))


static func _p4(model: String) -> Mesh:
	if model.ends_with("#trai"):
		var base := model.trim_suffix("#trai")
		var key := DIR + base + "#trai"
		if not _houses.has(key):
			# bộ ba biển (18, 42/7, HẺM 42) dài 1,63 m: chỉ lấy tấm trái
			_houses[key] = _cut_x(PhoModels.mesh(P4 + base + ".glb"), -0.45)
		return _houses[key]
	return PhoModels.mesh(P4 + model + ".glb")


## Giữ tam giác có cả ba đỉnh x < x_max, rồi dời về giữa
static func _cut_x(src: Mesh, x_max: float) -> ArrayMesh:
	var a := src.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var keep := PackedInt32Array()
	var lo := INF
	var hi := -INF
	for t in range(0, idx.size(), 3):
		if v[idx[t]].x < x_max and v[idx[t + 1]].x < x_max and v[idx[t + 2]].x < x_max:
			keep.append_array([idx[t], idx[t + 1], idx[t + 2]])
			for j in 3:
				lo = minf(lo, v[idx[t + j]].x)
				hi = maxf(hi, v[idx[t + j]].x)
	var mid := (lo + hi) / 2.0
	for k in v.size():
		v[k].x -= mid
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_INDEX] = keep
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return out


# ------------------------------------------------------------------ nhà mốc trong vùng chơi

## Nhà đang xây 6 × 7,3 m (dãy nam khối 5, mặt tiền nhìn nam ở face_z): khung bê tông, giàn giáo trước mặt có ván so le,
## mỗi ván cao hơn ván trước 1,1 m (Bơ nhảy 1,3 m), ván đầu 1,17 m nhảy thẳng từ vỉa hè lên được. Đống gạch, cát,
## bao xi măng của model nằm ngoài vỉa hè 2 m nên cắt bỏ (không bày đồ dưới lòng đường). Không có mái hiên.
static func dang_xay(parent: Node3D, x0: float, face_z: float) -> void:
	var info: Dictionary = meta().moc.nha_dang_xay.info
	var mi := MeshInstance3D.new()
	mi.name = "NhaDangXay"
	mi.mesh = PhoModels.mesh_cut_front(DIR + "moc/nha_dang_xay.glb", 1.9)
	mi.material_override = PhoModels.material()
	mi.position = Vector3(x0, 0, face_z)
	parent.add_child(mi)
	var top: float = info.dinh
	var body := Blocks.collider(parent, Vector3(5.9, top, 7.3), Vector3(x0 + 3.0, top / 2.0, face_z - 3.65))
	body.name = "NhaDangXay"
	for v: Array in info.van:
		var plank := Blocks.collider(parent, Vector3(float(v[1]) - float(v[0]), 0.06, 1.2),
			Vector3(x0 + (float(v[0]) + float(v[1])) / 2.0, float(v[2]) - 0.03, face_z + 0.9), Blocks.LAYER_PROP)
		plank.name = "VanGianGiao"
		plank.add_to_group("van_gian_giao")


## Miếu thổ địa đầu hẻm 42 (bệ 0,8 m Bơ ngồi được), mặt quay ra đường lớn. Gọi sau ChiTietPho.build: thử vài chỗ,
## chỗ đầu tiên không chạm va chạm đã dựng (ChiTietPho đã gom) và không gần chỗ người dân đứng thì đặt.
const MIEU_CHO := [Vector3(-21.05, 0, 7.6), Vector3(-15.35, 0, 7.6), Vector3(-21.05, 0, 23.0)]
static var mieu_at := Vector3.INF

static func mieu(parent: Node3D) -> void:
	var b: Dictionary = meta().moc.mieu
	for p: Vector3 in MIEU_CHO:
		# quay 180°: mặt trước nhìn -z (ra đường lớn)
		var box := AABB(p + Vector3(-1.1, 0, -0.67), Vector3(2.2, 2.0, 2.0))
		var free := true
		for o: AABB in ChiTietPho._boxes:
			free = free and not o.intersects(box.grow(-0.02))
		for a: Array in ChiTietPho._avoid_pts:
			free = free and Vector2(p.x, p.z).distance_to(a[0]) > float(a[1]) + 0.8
		if not free:
			continue
		var body := StaticBody3D.new()
		body.name = "Mieu"
		body.collision_layer = Blocks.LAYER_PROP
		body.position = p
		body.rotation.y = PI
		parent.add_child(body)
		var mi := PhoModels.put(body, DIR + "moc/mieu.glb", Vector3.ZERO)
		mi.name = "MieuTho"
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s: Array in [[Vector3(0, 0.4, 0), Vector3(1.5, 0.8, 1.2)], [Vector3(0, 1.4, -0.15), Vector3(1.0, 1.2, 0.8)]]:
			var cs := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = s[1]
			cs.shape = shape
			cs.position = s[0]
			body.add_child(cs)
		mieu_at = p
		ChiTietPho._boxes.append(box)
		return
	ChiTietPho.skipped.append("mieu: không còn chỗ trống ở đầu hẻm 42")
