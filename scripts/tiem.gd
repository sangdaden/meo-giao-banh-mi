class_name Tiem
## Đồ trang trí tiệm Cô Ba (Sang duyệt 21/10/2026, trang https://claude.ai/artifact/HY5St6ehdPN7yuARTAqSaG).
## Chỉ để ngắm: không đổi luật bếp, không thêm sao, boa hay thời gian.
## Hồ sơ ở mục [chung] của GameState: tiem_da_mua (id đã mua), tiem_dang_bay (id đang bày).
## Tủ đồ (tab "Tiệm") gọi grant khi mua, set_shown khi bật tắt; bếp và mặt tiền Lò bánh đọc shown lúc dựng cảnh.

const IDS := ["meo_vay_tay", "chau_mai", "den_long_tiem", "bang_hieu_go"]
const NAMES := {
	"meo_vay_tay": "Mèo vẫy tay", "chau_mai": "Chậu mai Tết",
	"den_long_tiem": "Đèn lồng đỏ", "bang_hieu_go": "Bảng hiệu gỗ",
}
const DIR := "res://assets/models/tiem/"


static func owned(id: String) -> bool:
	return id in GameState.get_global("tiem_da_mua", [])


## Đang bày (chỉ món đã mua mới bày được).
## Chạy với "-- --tiem-het" thì bày đủ 4 món (chụp ảnh kiểm tra, không đụng hồ sơ).
static func shown(id: String) -> bool:
	if "--tiem-het" in OS.get_cmdline_user_args():
		return true
	return owned(id) and id in GameState.get_global("tiem_dang_bay", [])


## Bật hoặc tắt bày một món đã mua, lưu ngay.
static func set_shown(id: String, on: bool) -> void:
	var list: Array = GameState.get_global("tiem_dang_bay", []).duplicate()
	if on and owned(id) and not id in list:
		list.append(id)
	elif not on:
		list.erase(id)
	GameState.set_global("tiem_dang_bay", list)
	GameState.write_save()


## Thêm món vào đồ đã mua (Shop trừ tiền trước khi gọi). Mua xong thì tự bày.
static func grant(id: String) -> void:
	if not id in IDS or owned(id):
		return
	var list: Array = GameState.get_global("tiem_da_mua", []).duplicate()
	list.append(id)
	GameState.set_global("tiem_da_mua", list)
	set_shown(id, true)


## Dựng model một món (Node3D gốc của .glb), có AnimationPlayer thì chơi clip lặp đầu tiên.
## start_offset: lệch thời điểm bắt đầu clip (hai đèn lồng không đung đưa cùng nhịp).
static func make(id: String, start_offset := 0.0) -> Node3D:
	var node: Node3D = load(DIR + id + ".glb").instantiate()
	if RenderingServer.get_rendering_device() == null and DisplayServer.get_name() != "headless":
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			mi.mesh = _srgb(id + mi.name, mi.mesh)
	for ap: AnimationPlayer in node.find_children("*", "AnimationPlayer", true, false):
		var list := ap.get_animation_list()
		if list.is_empty():
			continue
		ap.get_animation(list[0]).loop_mode = Animation.LOOP_LINEAR
		ap.play(list[0])
		ap.seek(start_offset, true)
	return node


static var _srgb_meshes := {}


## Bản web (Compatibility) đọc màu đỉnh như sRGB: đổi COLOR_0 tuyến tính sang sRGB một lần mỗi mesh,
## giữ vật liệu và dữ liệu xương của từng mặt.
static func _srgb(key: String, src: Mesh) -> Mesh:
	if _srgb_meshes.has(key):
		return _srgb_meshes[key]
	var dst := ArrayMesh.new()
	for i in src.get_surface_count():
		var arrays := src.surface_get_arrays(i)
		if arrays[Mesh.ARRAY_COLOR] != null:
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for k in cols.size():
				cols[k] = cols[k].linear_to_srgb()
			arrays[Mesh.ARRAY_COLOR] = cols
		dst.add_surface_from_arrays(src.surface_get_primitive_type(i), arrays, [], {}, src.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		dst.surface_set_material(i, src.surface_get_material(i))
	_srgb_meshes[key] = dst
	return dst
