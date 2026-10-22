extends SceneTree
## Kiểm tra model gói phác thảo G1 đã duyệt (bên trong chung cư + Thứ Năm ngoài phố): mỗi .glb mở được
## và có đủ node theo tên bộ phận trên trang phác thảo (node xuất có tiền tố "w_").
## Chạy: godot --headless --path . -s tests/test_model_g1.gd

const MODELS := {
	"res://assets/models/chung_cu/vong.glb": ["khung_vong", "vai_vong", "day_vong"],
	"res://assets/models/chung_cu/em_be.glb": ["em_be_ngu", "em_be_cua", "em_be_khoc"],
	"res://assets/models/chung_cu/thang_may.glb": ["khung_long", "kinh_long", "cabin", "canh_cua", "bang_goi", "den_tang"],
	"res://assets/models/chung_cu/cua_thang.glb": ["canh_cua_dong", "canh_cua_mo", "canh_cua_ket", "bien_ket_ket"],
	"res://assets/models/chung_cu/gia_phoi.glb": ["khung_gia", "do_phoi"],
	"res://assets/models/chung_cu/ong_gay.glb": ["ong", "dau_gay", "kep", "vach_bam"],
	"res://assets/models/chung_cu/may_lanh.glb": ["cuc_nong", "pat", "long_sat"],
	"res://assets/models/chung_cu/may_lanh_rung.glb": ["cuc_nong_rung", "long_sat_rung", "rung_rung"],
	"res://assets/models/thu_nam/bich_da.glb": ["tui_day", "tui_nua", "tui_tan", "da_day", "da_nua", "da_tan", "nuoc_nua", "nuoc_tan"],
	"res://assets/models/thu_nam/gac_lung.glb": ["san_gac", "cot_gac", "lan_can", "thang_go", "do_tren_gac", "chong_thung", "may_lanh_gac"],
	"res://assets/models/thu_nam/gio.glb": ["gio_tren", "day_tren", "gio_tha", "day_tha"],
	"res://assets/models/thu_nam/vong_hung.glb": ["moc_vong", "day_vong_hung", "vai_vong_hung"],
	"res://assets/models/thu_nam/cua_cuon.glb": ["hop_cuon", "ray_cua", "la_cua", "khoa_cua", "bien_nghi"],
}

var fails := 0


func _init() -> void:
	for path in MODELS:
		var ps := load(path) as PackedScene
		if ps == null:
			print("  LỖI  không mở được " + path)
			fails += 1
			continue
		var n := ps.instantiate()
		var thieu: Array = []
		for part in MODELS[path]:
			if n.find_child("w_" + part, true, false) == null:
				thieu.append(part)
		print(("  OK   " if thieu.is_empty() else "  LỖI  ") + path.get_file() + ("" if thieu.is_empty() else " thiếu " + str(thieu)))
		fails += thieu.size()
		n.free()
	var nguoi := load("res://assets/models/nguoi/chithu.glb") as PackedScene
	var ct := nguoi.instantiate() if nguoi else null
	var sk: Skeleton3D = ct.find_children("*", "Skeleton3D", true, false)[0] if ct else null
	var ok := sk != null and sk.get_bone_count() == 19
	print(("  OK   " if ok else "  LỖI  ") + "chithu.glb có khung 19 xương")
	if not ok:
		fails += 1
	if ct:
		ct.free()
	print("MODEL G1 OK" if fails == 0 else "MODEL G1 LỖI: %d" % fails)
	quit(1 if fails else 0)
