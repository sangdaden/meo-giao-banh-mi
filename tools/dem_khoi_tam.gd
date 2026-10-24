extends SceneTree
## Đếm khối tạm (mesh hình học dựng sẵn: hộp, trụ, cầu...) theo từng ngày, cho bảng việc tới 1.0 (W3).
## Ghi mọi MeshInstance3D / MultiMesh dùng BoxMesh, CylinderMesh... lúc được thêm vào cây (kể cả cái về sau bị gộp
## bằng Blocks.merge_static), nhóm theo node cha có tên và script gần nhất.
## Chạy: godot --headless --path . -s tools/dem_khoi_tam.gd -- [ra.json] [ngay1,ngay2,...]

const DAYS := ["thu_hai", "thu_ba", "thu_tu", "thu_nam", "thu_sau", "thu_bay", "chu_nhat"]
const SCENES := {"bep": "res://scenes/kitchen.tscn", "chung_cu": "res://scenes/chung_cu.tscn", "day_choi": "res://scenes/day_choi.tscn"}

var out := "user://khoi_tam.json"
var rows := {}      ## nhóm -> {n, tri_vi_du, kieu}
var result := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	GameState.use_test_save("user://luu_game_dem_khoi_tam.cfg")
	node_added.connect(_on_added)
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _prim(m: Mesh) -> String:
	if m is BoxMesh: return "hop"
	if m is CylinderMesh: return "tru"
	if m is SphereMesh: return "cau"
	if m is CapsuleMesh: return "nhong"
	if m is PrismMesh: return "lang_tru"
	if m is TorusMesh: return "vong"
	return ""


func _group(n: Node) -> String:
	# Node cha gần nhất có script (bỏ qua node chung main/city), ghép với tên node trực tiếp chứa mesh
	var p := n.get_parent()
	var near: String = String(p.name) if p else ""
	var scr := ""
	var q := p
	while q:
		var s: Script = q.get_script()
		if s and s.resource_path != "":
			scr = s.resource_path.get_file().get_basename()
			break
		q = q.get_parent()
	return "%s/%s" % [scr, String(near).rstrip("0123456789").rstrip("_")]


func _on_added(n: Node) -> void:
	var kind: String = ""
	if n is MeshInstance3D:
		kind = _prim(n.mesh) if n.mesh else ""
	elif n is MultiMeshInstance3D and n.multimesh and n.multimesh.mesh:
		kind = _prim(n.multimesh.mesh)
	if kind == "":
		return
	# Mesh vô hình (vùng va chạm, vật cản ẩn) không tính
	if n is GeometryInstance3D and not n.visible:
		return
	var g := _group(n)
	var cnt: int = 1
	if n is MultiMeshInstance3D:
		cnt = n.multimesh.instance_count
	if not rows.has(g):
		rows[g] = {"n": 0, "kieu": kind, "mau": {}}
	rows[g].n += cnt
	# Mẫu: cỡ khối + vị trí (để biết là đường/vỉa hè hay đồ vật thay bằng khối)
	if n is MeshInstance3D and rows[g].mau.size() < 400:
		var sz: Vector3 = n.mesh.get_aabb().size
		var key := "%s %.1fx%.1fx%.1f" % [String(n.name).rstrip("0123456789"), sz.x, sz.y, sz.z]
		rows[g].mau[key] = int(rows[g].mau.get(key, 0)) + 1


func _run() -> void:
	var only: Array = DAYS + SCENES.keys()
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		only = Array(args[1].split(","))
	for key in only:
		rows = {}
		if key in DAYS:
			PlayMode.day = key
			change_scene_to_file("res://scenes/main.tscn")
		else:
			PlayMode.day = "thu_hai"
			change_scene_to_file(SCENES[key])
		await _wait(45)
		result[key] = rows.duplicate(true)
		var tot := 0
		for g in rows:
			tot += int(rows[g].n)
		print("KHOI_TAM %s: %d khối, %d nhóm" % [key, tot, rows.size()])
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "  ", true))
	f.close()
	print("DEM KHOI TAM OK -> ", ProjectSettings.globalize_path(out))
	quit()
