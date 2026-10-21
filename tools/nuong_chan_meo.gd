extends SceneTree
## Nướng màu chân trước của từng giống mèo (assets/models/skin/giong/<id>_duc.glb) ra ảnh nhỏ cho BoPaw.
## Mỗi giống một ảnh 32 × 48, nửa trái là chân trước FL, nửa phải là chân FR (Bò Sữa hai chân khác màu).
## Mỗi nửa: trục ngang quanh chân (0 = mặt trước, 0,25 = mặt ngoài, 0,5 = sau, 0,75 = trong),
## trục dọc theo chiều cao chân (dưới = bàn chân, trên = vai). Lấy màu đỉnh của các đỉnh thuộc chân đó
## (upperarm, forearm, paw), nên tất trắng, màu điểm, chân hai màu đều theo đúng model trong tủ đồ.
## Model trong game ít đỉnh nên vằn mảnh không lên được: BoPaw vẽ thêm vằn/đốm theo kiểu lông của giống.
## Kèm assets/textures/chan_meo/chan_meo.json: màu bàn chân mỗi bên.
## Chạy có màn hình (cần dữ liệu đỉnh): xvfb-run godot --path . --script tools/nuong_chan_meo.gd

const OUT := "res://assets/textures/chan_meo/"
const W := 16
const H := 48


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var info := {}
	for b in Outfit.BREEDS:
		var id: String = b[0]
		if not OutfitView.has_breed(id) or id == "bo":
			continue
		var img := Image.create(W * 2, H, false, Image.FORMAT_RGB8)
		var r := {}
		for k in 2:
			var leg := "FL" if k == 0 else "FR"
			var paw := _bake(id, leg, img, k * W)
			if paw == Color.BLACK:
				push_error("Không nướng được %s %s" % [id, leg])
			r["paw_" + leg] = "#" + paw.to_html(false)
		img.save_png(ProjectSettings.globalize_path(OUT + id + ".png"))
		info[id] = r
		print("chan_meo ", id, " ", r)
	var f := FileAccess.open(OUT + "chan_meo.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(info, "\t", true))
	f.close()
	quit()


## Nướng một chân vào img từ cột x0. Trả về màu bàn chân (sRGB), hoặc đen nếu không có đỉnh.
func _bake(id: String, leg: String, img: Image, x0: int) -> Color:
	var root: Node = OutfitView.breed_scene(id).instantiate()
	var best: MeshInstance3D
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if best == null or mi.mesh.get_surface_count() > best.mesh.get_surface_count():
			best = mi
	var skel := best.get_node_or_null(best.skeleton) as Skeleton3D
	var leg_bind := {}
	for i in best.skin.get_bind_count():
		var name := best.skin.get_bind_name(i)
		if name == "" and skel:
			name = skel.get_bone_name(best.skin.get_bind_bone(i))
		if name in ["upperarm_" + leg, "forearm_" + leg, "paw_" + leg]:
			leg_bind[i] = name
	var pts := []  # [pos, color, bone name, normal]
	for s in best.mesh.get_surface_count():
		var mat := best.mesh.surface_get_material(s)
		if mat and not mat.resource_name.begins_with("Long"):
			continue
		var a := best.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var cols: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var bones = a[Mesh.ARRAY_BONES]
		var weights = a[Mesh.ARRAY_WEIGHTS]
		var per: int = bones.size() / verts.size()
		for k in verts.size():
			var top := 0
			for j in per:
				if weights[k * per + j] > weights[k * per + top]:
					top = j
			var bi: int = bones[k * per + top]
			if leg_bind.has(bi) and weights[k * per + top] > 0.5:
				pts.append([verts[k], cols[k], leg_bind[bi], norms[k]])
	root.free()
	if pts.size() < 50:
		return Color.BLACK
	var y0 := INF
	var y1 := -INF
	for p in pts:
		y0 = minf(y0, p[0].y)
		y1 = maxf(y1, p[0].y)
	# Tâm chân ở từng độ cao (chân hơi nghiêng nên không lấy một tâm chung)
	var cx := []
	var cz := []
	var cn := []
	for i in H:
		cx.append(0.0)
		cz.append(0.0)
		cn.append(0)
	for p in pts:
		var row := _row(p[0].y, y0, y1)
		cx[row] += p[0].x
		cz[row] += p[0].z
		cn[row] += 1
	for i in H:
		if cn[i] > 0:
			cx[i] /= cn[i]
			cz[i] /= cn[i]
	var sum := []
	var cnt := []
	for i in W * H:
		sum.append(Color(0, 0, 0, 0))
		cnt.append(0)
	for p in pts:
		var row := _row(p[0].y, y0, y1)
		var dx: float = p[0].x - cx[row]
		var dz: float = p[0].z - cz[row]
		var side := -1.0 if leg == "FL" else 1.0  # FL nằm phía -x: mặt ngoài của nó là -x
		var u := fposmod(atan2(side * dx, dz) / TAU, 1.0)
		var col := clampi(int(u * W), 0, W - 1)
		var c: Color = p[1]
		sum[row * W + col] += c
		cnt[row * W + col] += 1
	var filled := []
	for i in W * H:
		filled.append(cnt[i] > 0)
		if cnt[i] > 0:
			sum[i] = sum[i] / cnt[i]
	# Ô trống: lấy trung bình các ô kề đã có màu, lặp tới khi kín
	for pass_i in 64:
		var any := false
		for y in H:
			for x in W:
				var i := y * W + x
				if filled[i]:
					continue
				var acc := Color(0, 0, 0, 0)
				var n := 0
				for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
					var nx := posmod(x + d[0], W)
					var ny: int = y + d[1]
					if ny < 0 or ny >= H or not filled[ny * W + nx]:
						continue
					acc += sum[ny * W + nx]
					n += 1
				if n > 0:
					sum[i] = acc / n
					filled[i] = true
					any = true
		if not any:
			break
	for y in H:
		for x in W:
			# Ảnh: hàng trên cùng là vai, hàng dưới cùng là bàn chân (UV.y của ống BoPaw = 0 ở bàn chân)
			img.set_pixel(x0 + x, H - 1 - y, (sum[y * W + x] as Color).linear_to_srgb())
	# Màu bàn chân: trung bình 4 hàng dưới cùng
	var paw := Color(0, 0, 0, 0)
	for y in 4:
		for x in W:
			paw += sum[y * W + x]
	return (paw / (4 * W)).linear_to_srgb()


func _row(y: float, y0: float, y1: float) -> int:
	return clampi(int((y - y0) / (y1 - y0) * H), 0, H - 1)
