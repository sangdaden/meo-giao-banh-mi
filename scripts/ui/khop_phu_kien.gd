class_name KhopPhuKien
extends RefCounted
## Cho phụ kiện ôm đúng thân từng giống mèo (Sang 26/10: "thay đồ bị sai": quai kính lơ lửng, chuông hở khỏi vòng,
## dây lưng thòng, đồ đuôi trôi trên mèo cụt đuôi).
## Model phụ kiện dựng theo Bơ chuẩn; trên giống khác chỉ co giãn theo cỡ đầu, cỡ thân nên dây quai hở ra hoặc chìm vào lông.
## Ở đây, lúc gắn đồ (OutfitView.attach), dựa vào chính lưới thân mèo đang mặc:
## - BAM: dây, quai, đế lót được ép sát mặt da (giữ bề dày, cách da 2,5 mm);
## - THEO: khoá, nơ, thân túi... dời theo phần dây nó gắn vào; đồ treo (chuông, lục lạc) móc khoen lên vòng cổ;
## - đồ đuôi dời cả món cho nút buộc nằm đúng giữa đuôi (mèo cụt đuôi Tam Thể, Thỏ Ngọc).
## Mọi số đo trong hệ toạ độ model (cùng hệ với điểm gắn trong skin.json).

## Món -> các bộ phận ép sát da
const BAM := {
	"kinhbaoho": ["Day_Thun"], "kinhphicong": ["Day_Da", "Khoa_Day"], "bitmat": ["Day_Bit"], "khautrang": ["Quai_Thun"],
	"mubaohiem": ["Quai_Cam"], "mucoi": ["Quai_Da"], "nonla": ["Quai_Lua"], "nonsinhnhat": ["Day_Chun"],
	"chuong": ["Vong_Da"], "vongluclac": ["Day_Tet"], "nobuom": ["Day_No"],
	"coduua": ["Day_Buoc"], "denlong": ["Day_Buoc"], "bongbay": ["Day_Buoc"],
	"baolixi": ["De_Lot", "Day_Tet"], "camen": ["De_Lot", "Day_Buoc"], "thung": ["De_Lot", "Dai_Than", "Dai_Nguc"],
	"tuibanh": ["Quai", "Dem_Vai"], "giomay": ["Quai", "Dem_Vai"], "giodan": ["Quai", "Dem_Vai"],
	"canhthienthan": ["De_Canh", "Day_Canh"], "dongganh": ["Khan_Lot"],
}
## Món -> {bộ phận: phần nó bám theo}. "" = theo đỉnh dây gần nhất (khoá, nơ); tên phần = theo cả phần đó (thân túi trên đế)
const THEO := {
	"bitmat": {"Khoen": ""},
	"mubaohiem": {"Khoa_Cai": ""}, "mucoi": {"Khoa_Da": ""}, "nonla": {"No_Quai": ""},
	"chuong": {"Khoa_Vong": ""}, "vongluclac": {"Khoa_Day": ""}, "nobuom": {"Khoa_No": "", "No_Buom": ""},
	"baolixi": {"Bao_Li_Xi": "De_Lot", "Vien_Vang": "De_Lot", "Dau_Tron": "De_Lot", "Tua_Vang": "De_Lot"},
	"camen": {"Ca_Men": "De_Lot", "Khung_Cam": "De_Lot", "Num_Nap": "De_Lot", "Khoa_Gai": "De_Lot", "Tem": "De_Lot"},
	"thung": {"Thung": "De_Lot", "Nap_Thung": "De_Lot", "Khoa_Keo": "De_Lot", "Tay_Keo": "De_Lot", "Quai_Xach": "De_Lot",
		"Khoa_Nguc": "Dai_Nguc"},
	"canhthienthan": {"Canh_Trai": "De_Canh", "Canh_Phai": "De_Canh"},
}
## Đồ treo trên vòng cổ: cả chùm (chuông + bi + khoen) móc lên điểm thấp nhất phía trước của vòng
const TREO := {"chuong": ["Chuong", "Bi_Chuong", "Khoen"], "vongluclac": ["Luc_Lac", "Bi_Luc_Lac", "Khoen_Lac", "Xuong_Ca", "Khoen_Ca"]}
## Đồ đuôi: nút buộc (phần này) nằm giữa đuôi; không có thì lấy điểm gắn
const NUT_DUOI := {"coduua": "Day_Buoc", "denlong": "Day_Buoc", "bongbay": "Day_Buoc", "noduoi": "No_Duoi"}

## Món -> nhóm bộ phận cứng được thu gọn rồi đặt sát mặt (khoảng cách gần nhất tới da = CACH) theo trục trước của đầu.
## co: tỉ lệ (ngang, dọc, sâu) quanh mặt sau của nhóm. Kính bảo hộ cũ sâu 7 cm, nhô trước mõm như kính lặn.
## cong: uốn hai mép khung về sau (m) cho ôm theo mặt cong.
const NGOI := {"kinhbaoho": {"parts": ["Khung_BH", "Kinh_BH"], "co": Vector3(1.0, 0.85, 0.55), "cong": 0.02,
	"noi": {"day": "Day_Thun", "khoa": ""}}}
## noi: sau khi ép, kéo hai đầu dây (và khoá) tới mép khung để dây liền với khung, không hở
## Bộ phận bỏ hẳn: dây cằm ly cà phê ép vào mặt thì cắt ngang má như vết xước, để trống đẹp hơn;
## kẹp quai kính bảo hộ thừa ra khi dây đã nối thẳng vào khung
const AN := {"lycaphe": ["Day_Cam"], "kinhbaoho": ["Khoa_Day"]}

const CACH := 0.0025      # dây cách mặt da
const BAN_KINH := 0.012   # vùng lấy mặt trong của dây (bề dày dây) và làm mượt
const XA_NHAT := 0.07     # hở xa hơn thế thì coi như không phải chỗ bám (để nguyên)
const O := 0.015          # ô lưới tìm đỉnh gần

static var _than := {}
static var _cache := {}


## parts: [{name, mesh, xf (hệ món -> hệ model), hinge (nếu có)}]. Trả về {name: {mesh, hinge}} cho phần đã đổi.
static func fit(skel: Skeleton3D, id: String, key: String, parts: Array) -> Dictionary:
	var bam: Array = BAM.get(id, [])
	var theo: Dictionary = THEO.get(id, {})
	var treo: Array = TREO.get(id, [])
	var nut: String = NUT_DUOI.get(id, "")
	if bam.is_empty() and nut == "" and not AN.has(id):
		return {}
	var ck := "%s|%s" % [id, key]
	if _cache.has(ck):
		return _cache[ck]
	var body := OutfitView._body_of(skel)
	if body == null:
		return {}
	var th := _than_of(body, skel)
	# Đỉnh mọi phần trong hệ model
	var pos := {}
	for p in parts:
		pos[p.name] = _verts(p.mesh, p.xf)
	var moved := {}  # name -> PackedVector3Array (vị trí mới, hệ model)
	var shift_all := Vector3.ZERO
	# 1. Đồ đuôi: dời cả món cho nút buộc vào giữa đuôi
	if nut != "":
		var anchor := Vector3.ZERO
		if pos.has(nut):
			anchor = _mean(pos[nut])
		else:
			anchor = parts[0].xf.origin
		shift_all = _tail_center(th, anchor) - anchor
		if shift_all.length() > 0.06:
			shift_all = Vector3.ZERO
		for n in pos:
			var vs: PackedVector3Array = pos[n].duplicate()
			for i in vs.size():
				vs[i] += shift_all
			pos[n] = vs
			moved[n] = vs
	var ngoi_disp := {}
	# 1b. Nhóm cứng (khung kính) thu gọn và ngồi sát mặt
	var ngoi: Dictionary = NGOI.get(id, {})
	if not ngoi.is_empty():
		var g: Array = ngoi.parts.filter(func(n): return pos.has(n))
		var xb: Basis = parts[0].xf.basis
		var ax := xb.x.normalized()
		var ay := xb.y.normalized()
		var az := xb.z.normalized()
		var all := PackedVector3Array()
		for n in g:
			all.append_array(pos[n])
		var c := _mean(all)
		var back := INF
		for v in all:
			back = minf(back, (v - c).dot(az))
		var piv := c + az * back
		var co: Vector3 = ngoi.co
		var rong := 0.0
		for v in all:
			rong = maxf(rong, absf((v - c).dot(ax)))
		var goc := {}
		for n in g:
			goc[n] = pos[n]
			var vs: PackedVector3Array = pos[n].duplicate()
			for i in vs.size():
				var q := vs[i] - piv
				var x := q.dot(ax) / maxf(rong, 0.001)
				vs[i] = piv + ax * q.dot(ax) * co.x + ay * q.dot(ay) * co.y + az * (q.dot(az) * co.z - float(ngoi.get("cong", 0.0)) * x * x)
			pos[n] = vs
		# lùi cả nhóm theo trục trước cho tới khi chạm da
		var lo := INF
		for n in g:
			for v in pos[n]:
				var k := _near(th, v)
				if k >= 0:
					lo = minf(lo, (v - th.pos[k]).dot(th.nrm[k]) / maxf(th.nrm[k].dot(az), 0.3))
		var back_off := -az * clampf(lo - CACH, -0.03, 0.04) if lo < INF else Vector3.ZERO
		for n in g:
			moved[n] = _add(pos[n], back_off)
			var d := PackedVector3Array()
			d.resize(moved[n].size())
			for i in d.size():
				d[i] = moved[n][i] - goc[n][i]
			ngoi_disp[n] = d
			pos[n] = goc[n]  # các phần đi theo đo từ chỗ cũ
	# 2. Ép dây sát da
	var disp := {}  # name -> PackedVector3Array dịch chuyển của phần ép
	for n in bam:
		if not pos.has(n):
			continue
		var old: PackedVector3Array = pos[n]
		var nv := old
		for lan in 3:  # mỗi lượt đo lại theo pháp tuyến chỗ mới: 3 lượt là dây nằm yên trên da
			nv = _hug(th, nv)
		var d := PackedVector3Array()
		d.resize(old.size())
		for i in old.size():
			d[i] = nv[i] - old[i]
		disp[n] = d
		moved[n] = nv
	# 2b. Nối đầu dây vào mép khung (kính bảo hộ)
	if ngoi.has("noi"):
		var nd: String = ngoi.noi.day
		var nk: String = ngoi.noi.khoa
		var az: Vector3 = parts[0].xf.basis.z.normalized()
		var ax: Vector3 = parts[0].xf.basis.x.normalized()
		var khung := PackedVector3Array()
		for n in ngoi.parts:
			if moved.has(n):
				khung.append_array(moved[n])
		var c0 := _mean(khung)
		for side in [-1.0, 1.0]:
			var e := c0
			for v in khung:
				if (v - c0).dot(ax) * side > (e - c0).dot(ax) * side:
					e = v
			e -= ax * side * 0.004  # chạm vào trong mép khung một chút
			for n in [nd, nk]:
				if not moved.has(n):
					continue
				var vs: PackedVector3Array = moved[n].duplicate()
				var tip := -INF
				var s_pt := Vector3.ZERO
				for v in vs:
					if (v - c0).dot(ax) * side > 0 and v.dot(az) > tip:
						tip = v.dot(az)
						s_pt = v
				if tip == -INF:
					continue
				var d := e - s_pt
				d -= az * minf(d.dot(az), 0.0)  # chỉ kéo tới, không đẩy lùi
				for i in vs.size():
					if (vs[i] - c0).dot(ax) * side <= 0:
						continue
					var w := 1.0 if n == nk else clampf(1.0 - (tip - vs[i].dot(az)) / 0.05, 0.0, 1.0)
					vs[i] += d * w
				moved[n] = vs
		for lan in 2:  # đoạn vừa kéo đi thẳng qua má: ép lại lên da
			moved[nd] = _hug(th, moved[nd])
	var hinge_off := {}
	# 3. Khoá, nơ, thân túi đi theo dây
	for n in theo:
		if not pos.has(n):
			continue
		var tgt: String = theo[n]
		var off := Vector3.ZERO
		if tgt.begins_with("@"):
			var only := {tgt.substr(1): ngoi_disp.get(tgt.substr(1), disp.get(tgt.substr(1)))}
			off = _nearest_disp(pos, only, _mean(pos[n])) if only.values()[0] != null else Vector3.ZERO
		elif tgt != "" and disp.has(tgt):
			off = _mean(disp[tgt])
		else:
			off = _nearest_disp(pos, disp, _mean(pos[n]))
		moved[n] = _add(pos[n], off)
		hinge_off[n] = shift_all + off
	# 4. Chùm đồ treo móc lên vòng cổ
	if not treo.is_empty() and not bam.is_empty() and moved.has(bam[0]):
		var top := Vector3(0, -INF, 0)
		for n in treo:
			if pos.has(n):
				for v in pos[n]:
					if v.y > top.y:
						top = v
		var ring: PackedVector3Array = moved[bam[0]]
		var best := Vector3.ZERO
		var bd := INF
		for v in ring:
			var d := Vector2(v.x - top.x, v.z - top.z).length() + maxf(v.y - top.y, 0.0) * 0.2
			if d < bd:
				bd = d
				best = v
		var off := best + Vector3(0, 0.002, 0) - top
		for n in treo:
			if pos.has(n):
				moved[n] = _add(pos[n], off)
				hinge_off[n] = shift_all + off
	# Ghi lại lưới mới (hệ món)
	var out := {}
	for n in AN.get(id, []):
		out[n] = {"an": true}
	for p in parts:
		if not moved.has(p.name):
			continue
		var hv: Vector3 = hinge_off.get(p.name, shift_all)
		var res := {"mesh": _rebuild(p.mesh, p.xf, moved[p.name])}
		if p.get("hinge") != null:
			res.hinge = p.hinge + p.xf.basis.inverse() * hv
		out[p.name] = res
	_cache[ck] = out
	return out


static func _verts(mesh: Mesh, xf: Transform3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in mesh.get_surface_count():
		for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			out.append(xf * v)
	return out


static func _rebuild(src: Mesh, xf: Transform3D, vs_model: PackedVector3Array) -> ArrayMesh:
	var inv := xf.affine_inverse()
	var dst := ArrayMesh.new()
	var k := 0
	for s in src.get_surface_count():
		var a := src.surface_get_arrays(s)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		for i in vs.size():
			vs[i] = inv * vs_model[k]
			k += 1
		a[Mesh.ARRAY_VERTEX] = vs
		dst.add_surface_from_arrays(src.surface_get_primitive_type(s), a)
		var m := src.surface_get_material(s)
		if m:
			dst.surface_set_material(s, m)
	return dst


static func _mean(vs: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for v in vs:
		c += v
	return c / maxf(vs.size(), 1)


static func _add(vs: PackedVector3Array, off: Vector3) -> PackedVector3Array:
	var o := vs.duplicate()
	for i in o.size():
		o[i] += off
	return o


static func _nearest_disp(pos: Dictionary, disp: Dictionary, c: Vector3) -> Vector3:
	var bd := INF
	var off := Vector3.ZERO
	for n in disp:
		var vs: PackedVector3Array = pos[n]
		for i in vs.size():
			var d := vs[i].distance_squared_to(c)
			if d < bd:
				bd = d
				off = disp[n][i]
	return off


## Lưới thân: vị trí, pháp tuyến (hệ model), xương mạnh nhất của từng đỉnh, lưới ô để tìm nhanh.
static func _than_of(body: MeshInstance3D, skel: Skeleton3D) -> Dictionary:
	var key := body.mesh.get_instance_id()
	if _than.has(key):
		return _than[key]
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var tail := PackedByteArray()
	var grid := {}
	var nb := body.transform.basis.inverse().transposed()
	for s in body.mesh.get_surface_count():
		var mat := body.mesh.surface_get_material(s)
		var mn := str(mat.resource_name) if mat else ""
		if mn.begins_with("Mat") or mn.begins_with("Sang") or mn.begins_with("Khan"):
			continue  # mắt nằm trong hốc mắt, khăn liền của Bơ đực (tắt khi đeo đồ cổ): không phải mặt da
		var a := body.mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var bo = a[Mesh.ARRAY_BONES]
		var we = a[Mesh.ARRAY_WEIGHTS]
		var n: int = bo.size() / maxi(vs.size(), 1) if bo is PackedInt32Array else 0
		for i in vs.size():
			var p := body.transform * vs[i]
			var t := 0
			if n > 0:
				var best := 0
				var bw := -1.0
				for j in n:
					if we[i * n + j] > bw:
						bw = we[i * n + j]
						best = bo[i * n + j]
				var bi := body.skin.get_bind_bone(best) if body.skin else -1
				var bn := skel.get_bone_name(bi) if bi >= 0 else (str(body.skin.get_bind_name(best)) if body.skin else "")
				t = 1 if bn.begins_with("tail") else 0
			var c := Vector3i((p / O).floor())
			if not grid.has(c):
				grid[c] = PackedInt32Array()
			grid[c].append(pos.size())
			pos.append(p)
			nrm.append((nb * ns[i]).normalized() if ns.size() > i else Vector3.UP)
			tail.append(t)
	var th := {"pos": pos, "nrm": nrm, "tail": tail, "grid": grid}
	_than[key] = th
	return th


static func _near(th: Dictionary, p: Vector3, only_tail := false) -> int:
	var c := Vector3i((p / O).floor())
	var best := -1
	var bd := INF
	for r in [1, 2, 3, 5]:
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				for dz in range(-r, r + 1):
					var cell = th.grid.get(c + Vector3i(dx, dy, dz))
					if cell == null:
						continue
					for k in cell:
						if only_tail and th.tail[k] == 0:
							continue
						var d: float = p.distance_squared_to(th.pos[k])
						if d < bd:
							bd = d
							best = k
		if best >= 0:
			return best
	return best


## Tâm đuôi gần điểm `p`: trung bình các đỉnh đuôi trong vòng 2,5 cm quanh đỉnh đuôi gần nhất.
static func _tail_center(th: Dictionary, p: Vector3) -> Vector3:
	var k := _near(th, p, true)
	if k < 0:
		return p
	var q: Vector3 = th.pos[k]
	var c := Vector3.ZERO
	var n := 0
	for i in th.pos.size():
		if th.tail[i] == 1 and th.pos[i].distance_to(q) < 0.025:
			c += th.pos[i]
			n += 1
	return c / n if n > 0 else p


## Ép một dải dây sát da: mặt trong của dây (đỉnh thấp nhất trong vùng BAN_KINH) cách da CACH, giữ nguyên bề dày.
static func _hug(th: Dictionary, vs: PackedVector3Array) -> PackedVector3Array:
	var n := vs.size()
	var h := PackedFloat32Array()
	var nk := PackedVector3Array()
	h.resize(n)
	nk.resize(n)
	var ok := PackedByteArray()
	ok.resize(n)
	var grid := {}
	for i in n:
		var k := _near(th, vs[i])
		if k >= 0:
			nk[i] = th.nrm[k]
			h[i] = (vs[i] - th.pos[k]).dot(nk[i])
			ok[i] = 1
		var c := Vector3i((vs[i] / BAN_KINH).floor())
		if not grid.has(c):
			grid[c] = PackedInt32Array()
		grid[c].append(i)
	# mặt trong của dây quanh từng đỉnh
	var d := PackedFloat32Array()
	d.resize(n)
	for i in n:
		var lo := INF
		for j in _around(grid, vs, i):
			if ok[j] == 1:
				lo = minf(lo, h[j])
		var dd := lo - CACH
		d[i] = dd if absf(dd) < XA_NHAT else 0.0
	# làm mượt độ dời theo các đỉnh lân cận
	var out := vs.duplicate()
	for i in n:
		var acc := Vector3.ZERO
		var m := 0
		for j in _around(grid, vs, i):
			if ok[j] == 1:
				acc += -nk[j] * d[j]
				m += 1
		if m > 0:
			out[i] = vs[i] + acc / m
	return out


static func _around(grid: Dictionary, vs: PackedVector3Array, i: int) -> Array:
	var c := Vector3i((vs[i] / BAN_KINH).floor())
	var out := []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				var cell = grid.get(c + Vector3i(dx, dy, dz))
				if cell == null:
					continue
				for j in cell:
					if vs[i].distance_to(vs[j]) <= BAN_KINH:
						out.append(j)
	return out
