extends SceneTree
## Heatmap chỗ lúng túng (P3): gộp các file ket_*.csv của nhật ký chơi thử (scripts/nhat_ky.gd) lên bản đồ khu phố.
## Chỉ tính màn phố (man = pho); chỗ lúng túng ở bếp, chung cư, sân sau đếm riêng trong file tóm tắt.
## Không cần màn hình (vẽ thẳng vào Image theo cùng dữ liệu nhà của bản đồ lớn phím B, bắc ở trên).
## Chạy:
##   godot --headless --path . -s tools/heatmap_ket.gd -- <anh_ra.png> <file.csv hoặc thư mục>...
## Ra: <anh_ra.png> (đốm đỏ = đứng lâu, chấm xanh = đứng yên, chấm tím = đi vòng, ô số = hạng cụm)
##     và <anh_ra>_top.csv (20 cụm nặng nhất theo tổng số giây, cùng số với ô số trên ảnh).
## Thư mục thì tìm mọi ket_*.csv bên trong (cả thư mục con), ví dụ thư mục ket-qua của bộ chơi thử.

const PX := 10.0           ## điểm ảnh mỗi mét
const SIGMA := 2.0         ## độ loang của một chỗ (mét)
const GOM := 5.0           ## gom các chỗ cách tâm cụm dưới 5 m thành một khi xếp hạng
const SO_ANH := 9          ## đánh số bao nhiêu cụm nặng nhất lên ảnh
## Chữ số 3 × 5 điểm để đánh số cụm lên ảnh (Image không vẽ được chữ)
const SO := ["111101101101111", "010110010010111", "111001111100111", "111001111001111", "101101111001001",
	"111100111001111", "111100111101111", "111001010010010", "111101111101111", "111101111001111"]

var su_kien: Array = []    # mỗi phần tử: Dictionary theo cột CSV
var khac_pho := {}         # màn -> [số chỗ, tổng giây]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Cần: -- <anh_ra.png> <file.csv hoặc thư mục>...")
		quit(1)
		return
	var out: String = args[0]
	for a in args.slice(1):
		_doc(a)
	var top := xep_hang(su_kien)
	var anh := ve(su_kien, top)
	anh.save_png(out)
	var f := FileAccess.open(out.get_basename() + "_top.csv", FileAccess.WRITE)
	f.store_line("hang,cho,x,z,so_lan,tong_giay,so_nguoi,dung_yen,di_vong,don")
	for i in top.size():
		var t: Dictionary = top[i]
		f.store_line("%d,%s,%.0f,%.0f,%d,%.0f,%d,%d,%d,%s" % [i + 1, t.cho, t.x, t.z, t.so_lan, t.giay, t.nguoi.size(),
			t.dung_yen, t.di_vong, " ".join(t.don.keys())])
	for m in khac_pho:
		f.store_line("-,màn %s,,,%d,%.0f,,,," % [m, khac_pho[m][0], khac_pho[m][1]])
	f.close()
	print("HEATMAP OK: %d chỗ ngoài phố, %d chỗ ở màn khác -> %s" % [su_kien.size(),
		khac_pho.values().reduce(func(s, v): return s + v[0], 0), out])
	quit()


func _doc(duong: String) -> void:
	if DirAccess.dir_exists_absolute(duong):
		for f in DirAccess.get_files_at(duong):
			if f.begins_with("ket_") and f.ends_with(".csv"):
				_doc(duong.path_join(f))
		for d in DirAccess.get_directories_at(duong):
			_doc(duong.path_join(d))
		return
	var f := FileAccess.open(duong, FileAccess.READ)
	if f == null:
		push_warning("Không mở được " + duong)
		return
	var cot := f.get_csv_line()
	while not f.eof_reached():
		var dong := f.get_csv_line()
		if dong.size() != cot.size():
			continue
		var e := {}
		for i in cot.size():
			e[cot[i]] = dong[i]
		if e.man == "pho":
			su_kien.append(e)
		else:
			var k: Array = khac_pho.get(e.man, [0, 0.0])
			khac_pho[e.man] = [k[0] + 1, k[1] + float(e.giay)]


static func _r(r: Rect2) -> Rect2i:
	var a := BanDoNho.AREA
	return Rect2i(Vector2i(((r.position - a.position) * PX).round()), Vector2i((r.size * PX).round()))


static func _p(x: float, z: float) -> Vector2:
	return (Vector2(x, z) - BanDoNho.AREA.position) * PX


## Bản đồ khu phố (giống bản đồ lớn phím B) + heatmap của các chỗ lúng túng.
static func ve(ds: Array, top: Array = []) -> Image:
	BanDoNho._build_static()
	var a := BanDoNho.AREA
	var w := int(a.size.x * PX)
	var h := int(a.size.y * PX)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(BanDoNho.ROAD)
	for i in City.BLOCKS.size():
		img.fill_rect(_r(City.BLOCKS[i]), BanDoNho.GRASS if i == City.PARK_INDEX else BanDoNho.SIDEWALK)
	img.fill_rect(_r(Rect2(-22.0, CityProps.HEM42_Z.x, 22.0 + CityProps.HEM42_X.x - 0.3,
		CityProps.HEM42_Z.y - CityProps.HEM42_Z.x)), BanDoNho.GRASS)
	img.fill_rect(_r(Rect2(CityProps.HEM42_X.x, CityProps.HEM42_Z.x, CityProps.HEM42_X.y - CityProps.HEM42_X.x,
		CityProps.HEM42_Z.y - CityProps.HEM42_Z.x)), BanDoNho.ALLEY)
	for hs in BanDoNho._houses:
		var r := _r(hs[0])
		img.fill_rect(r, BanDoNho.HOUSE_EDGE)
		img.fill_rect(r.grow(-2), hs[1])
	# Nhiệt: mỗi chỗ một đốm Gauss, nặng theo số giây
	var nhiet := PackedFloat32Array()
	nhiet.resize(w * h)
	var s_px := SIGMA * PX
	var bk := int(s_px * 3.0)
	var cao := 0.0
	for e in ds:
		var c := _p(float(e.x), float(e.z))
		var nang := maxf(float(e.giay), 1.0)
		for y in range(maxi(0, int(c.y) - bk), mini(h, int(c.y) + bk + 1)):
			for x in range(maxi(0, int(c.x) - bk), mini(w, int(c.x) + bk + 1)):
				var d2 := Vector2(x, y).distance_squared_to(c)
				var i := y * w + x
				nhiet[i] += nang * exp(-d2 / (2.0 * s_px * s_px))
				cao = maxf(cao, nhiet[i])
	if cao > 0.0:
		for y in h:
			for x in w:
				var v := nhiet[y * w + x] / cao
				if v < 0.03:
					continue
				var mau := Color(1.0, 0.85, 0.2).lerp(Color(0.9, 0.12, 0.08), clampf(v * 1.4, 0.0, 1.0))
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(mau, clampf(0.25 + v * 0.65, 0.0, 0.85)))
	for e in ds:
		var c := Vector2i(_p(float(e.x), float(e.z)).round())
		var mau := Color("#1d3f8f") if e.loai == "dung_yen" else Color("#7a2d9c")
		img.fill_rect(Rect2i(c - Vector2i(3, 3), Vector2i(7, 7)), Color.WHITE)
		img.fill_rect(Rect2i(c - Vector2i(2, 2), Vector2i(5, 5)), mau)
	for i in mini(top.size(), SO_ANH):
		_ve_so(img, Vector2i(_p(top[i].x, top[i].z).round()) + Vector2i(14, -24), i + 1)
	return img


static func _ve_so(img: Image, at: Vector2i, n: int) -> void:
	var k := 3  # mỗi điểm của chữ số là ô 3 × 3
	img.fill_rect(Rect2i(at - Vector2i(4, 4), Vector2i(3 * k + 8, 5 * k + 8)), Color("#2b2118"))
	img.fill_rect(Rect2i(at - Vector2i(3, 3), Vector2i(3 * k + 6, 5 * k + 6)), Color.WHITE)
	var m: String = SO[n % 10]
	for y in 5:
		for x in 3:
			if m[y * 3 + x] == "1":
				img.fill_rect(Rect2i(at + Vector2i(x * k, y * k), Vector2i(k, k)), Color("#2b2118"))


## Gom chỗ gần nhau thành cụm (chỗ lâu nhất làm tâm trước), xếp theo tổng số giây.
static func xep_hang(ds: Array, so := 20) -> Array:
	var thu_tu := ds.duplicate()
	thu_tu.sort_custom(func(p, q): return float(p.giay) > float(q.giay))
	var ds_o: Array = []
	for e in thu_tu:
		var p := Vector2(float(e.x), float(e.z))
		var t: Dictionary = {}
		for c in ds_o:
			if Vector2(c.sx / c.so_lan, c.sz / c.so_lan).distance_to(p) < GOM:
				t = c
				break
		if t.is_empty():
			t = {"sx": 0.0, "sz": 0.0, "so_lan": 0, "giay": 0.0, "nguoi": {}, "dung_yen": 0, "di_vong": 0, "don": {}}
			ds_o.append(t)
		t.sx += float(e.x)
		t.sz += float(e.z)
		t.so_lan += 1
		t.giay += float(e.giay)
		t.nguoi[e.ma_lan] = true
		t[e.loai] = t.get(e.loai, 0) + 1
		t.don["%s/%s" % [e.ngay, e.don]] = true
	for t in ds_o:
		t.x = t.sx / t.so_lan
		t.z = t.sz / t.so_lan
		t.cho = ten_cho(t.x, t.z)
	ds_o.sort_custom(func(p, q): return p.giay > q.giay)
	return ds_o.slice(0, so)


## Tên chỗ gần nhất (lò, nhà đặc biệt, tên chỗ của bản đồ lớn), xa quá 10 m thì ghi tọa độ (x, z).
static func ten_cho(x: float, z: float) -> String:
	BanDoNho._build_static()
	var p := Vector2(x, z)
	var ten := "(%.0f, %.0f)" % [x, z]
	var gan := 10.0
	var lo := Vector2(City.BAKERY_POINT.x, City.BAKERY_POINT.z)
	if lo.distance_to(p) < gan:
		gan = lo.distance_to(p)
		ten = "Lò Cô Ba"
	for hs in BanDoNho._houses:
		if hs[2] != "" and BanDoNho.SPECIAL.has(hs[2]):
			var d: float = (hs[0] as Rect2).get_center().distance_to(p)
			if d < gan:
				gan = d
				ten = BanDoNho.SPECIAL[hs[2]][1]
	for pn in BanDoNho.PLACE_NAMES:
		var d: float = (pn[1] as Vector2).distance_to(p)
		if d < gan:
			gan = d
			ten = pn[0]
	return ten
