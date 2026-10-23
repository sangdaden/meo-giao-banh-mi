class_name SanThuong
extends Node3D
## Đường sân thượng Thứ Tư (gói việc thiet-ke-man/goi-viec-thu-tu.md). Phần nhìn là model G5 (ThuTuModels):
## cầu thang sắt, ván, giàn sắt, cổng chào, chuồng bồ câu; va chạm là hộp vô hình.
## Dãy nhà phía nam của khối 1 → 2 → 3 (dãy nhìn ra đường lớn). Hộp va chạm nhà của City chỉ là khối cao bằng
## đỉnh model trừ 1 m, nên mái tôn dốc nhô cao hơn tới 1 m còn sân thượng có bồn nước thì thấp hơn 3 m. Hôm nay
## hạ hộp xuống và lát mặt va chạm theo mái thật (ROOF_PROFILE, đo từ model), đường đi tính theo mặt mái đó.
## - Bậc mái: hai nhà lệch mái thì có cầu thang sắt (va chạm là dốc 36°, nhìn là bậc) dựa tường nhà cao,
##   đặt trên mái nhà thấp, chạy dọc chiều sâu nhà. Xuống chỗ lệch hơn 3,9 m thì nhảy xuống đoạn cuối (≤ 1,6 m).
## - Qua đường: ván gỗ rộng 0,25 m dài 2 m (đi thăng bằng, ThangBang) + giàn sắt bắc ngang đường có lan can.
## - Lên: chồng thùng cạnh lò → mái hiên khối 1 → cầu thang sắt trên mái hiên → mái lò → mái khối 1.
## - Xuống: cầu thang sắt gấp khúc ở dải vỉa hè đầu khối 2 (sau tạp hóa Cô Hai) và đầu khối 3 (hẻm Bé Na).
## - Cổng chào bắc qua đường lớn ngang mái hiên (2,96 m): lối khô sang đầu hẻm 42 (đơn 4, Chú Năm).
## Dấu chân vàng vẽ dọc lối đi; routes[...] là các điểm đi lần lượt (bài thử tests/test_thu_tu.gd đi theo).

const STEEL := Color("#4A4E4F")
const STEEL_DARK := Color("#34383A")
const PAW := Color("#F2C14E")

const SLOPE := deg_to_rad(36.0)      ## dốc cầu thang (CharacterBody3D đi được tới 45°)
const RAMP_W := 1.1                  ## bề ngang cầu thang trên mái
const RAMP_FOOT_Z := -8.0            ## chân cầu thang trên mái: phía mặt tiền (mái từ z -14,3 tới -7)
const RAMP_MAX_RISE := 3.9           ## cao nhất một cầu thang lên được (dài 5,4 m, vừa chiều sâu nhà)
const ROW_Z := Vector2(-14.3, -7.0)  ## dãy nhà phía nam khối 1–3
const CROSS_Z := -10.6               ## đường ván qua hai ngã đường dọc
const PLANK_LEN := 2.0
const PLANK_W := 0.25                ## ván thật 0,25 m (phác thảo G2); va chạm Thong thả rộng hơn cho dễ đứng
const PLANK_THICK := 0.04
const GANTRY_W := 0.9
const FLIGHT_RISE := 3.6             ## mỗi đợt cầu thang gấp khúc cao nhất 3,6 m
const FLIGHT_W := 0.95
const AWNING_TOP := 2.96             ## mặt mái hiên (CityProps.awning)
## Cổng chào bắc qua đường lớn: x giữa, bề ngang; mép bắc nối mái hiên khối 1, mép nam xuống dốc tới đầu hẻm 42
const ARCH_X := -23.75
const ARCH_W := 0.9
const ARCH_Z := Vector2(-6.9, 7.15)
const ARCH_GAP := 5.9                ## lan can phía đông cổng dừng ở đây (tính từ giữa cổng) để bước ra chiếu nghỉ
const ARCH_WEST_FROM := -6.0         ## lan can phía tây bắt đầu từ đây (đầu bắc để trống, lối từ mái hiên vào)
const ARCH_STAIR_RUN := 3.96         ## cầu thang cổng chào: 18 bậc 0,22 m
## Mặt mái thật của từng mẫu nhà (đo từ model bằng tia chiếu xuống, tools/do_mai_nha.py): độ cao mặt trên ở
## 3 dải ngang (25 %, 50 %, 75 % bề ngang) tại 16 điểm cách mặt tiền 0; 0,5; ...; 7,5 m vào trong (-1 = hết nhà).
const ROOF_PROFILE := {
	"nha_A": [[10.60, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, -1.00], [10.60, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 12.25, 13.21, 13.42, 12.25, 12.25, -1.00], [10.60, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 12.25, 13.21, 13.42, 12.25, 12.25, -1.00]],
	"nha_B": [[13.83, 13.77, 13.71, 13.65, 13.59, 13.53, 13.47, 13.41, 13.35, 13.29, 13.23, 13.17, 13.11, 13.05, 12.99, -1.00], [13.86, 13.80, 13.74, 13.68, 13.62, 13.56, 13.50, 13.44, 13.38, 13.32, 13.30, 13.30, 13.30, 13.30, 13.30, -1.00], [13.89, 13.83, 13.77, 13.71, 13.65, 13.59, 13.53, 13.47, 13.41, 13.35, 13.29, 13.23, 13.17, 13.11, 13.05, -1.00]],
	"nha_C": [[6.84, 7.05, 7.27, 7.49, 7.71, 7.93, 8.15, 8.36, 8.17, 7.95, 7.73, 7.51, 7.30, 7.08, 6.86, 6.64], [6.81, 7.03, 7.25, 7.47, 7.68, 7.90, 8.12, 8.34, 8.20, 7.98, 7.76, 7.54, 7.32, 7.10, 6.88, 6.66], [6.77, 6.99, 7.21, 7.43, 7.65, 7.87, 8.09, 8.31, 8.24, 8.02, 7.80, 7.58, 7.36, 7.14, 6.92, 6.70]],
	"nha_D": [[10.55, 10.16, 10.38, 10.61, 10.84, 11.07, 11.30, 11.68, 11.30, 11.07, 10.85, 10.62, 10.39, 10.16, 9.93, -1.00], [11.20, 10.12, 10.35, 10.58, 10.81, 11.03, 11.26, 11.68, 11.34, 11.11, 10.88, 10.65, 10.42, 10.20, 9.97, -1.00], [10.55, 10.21, 10.44, 10.67, 10.89, 11.12, 11.35, 11.68, 11.25, 11.02, 10.79, 10.57, 10.34, 10.11, 9.88, -1.00]],
	"nha_E": [[7.68, 7.62, 7.56, 7.50, 7.44, 7.38, 7.32, 7.26, 7.20, 7.14, 7.08, 7.02, 6.96, 6.90, 6.84, -1.00], [7.69, 7.63, 7.57, 7.51, 7.45, 7.39, 7.33, 7.27, 7.21, 7.15, 7.10, 7.10, 7.10, 7.10, 7.10, -1.00], [7.69, 7.63, 7.57, 7.51, 7.45, 7.39, 7.33, 7.27, 7.21, 7.15, 7.09, 7.03, 6.97, 6.91, 6.85, -1.00]],
	"nha_F": [[10.60, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, -1.00], [10.60, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, -1.00], [10.60, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 9.75, 12.25, 13.75, 13.84, 12.25, 12.25, -1.00]],
	"nha_G": [[13.70, 12.85, 12.85, 12.85, 12.85, 12.85, 12.85, 12.85, 12.85, 12.85, 12.85, 12.85, 12.85, 12.85, 12.85, -1.00], [13.70, 12.85, 12.85, 12.85, 12.85, 12.85, 12.85, 12.85, 12.85, 12.85, 15.35, 15.35, 15.35, 15.35, 15.35, -1.00], [13.70, 12.85, 12.85, 12.85, 12.85, 12.85, 12.85, 12.85, 12.85, 12.85, 15.35, 16.31, 16.52, 15.35, 15.35, -1.00]],
	"nha_H": [[6.77, 6.99, 7.21, 7.43, 7.65, 7.87, 8.09, 8.31, 8.24, 8.02, 7.80, 7.58, 7.36, 7.14, 6.92, 6.70], [6.75, 6.95, 7.16, 7.38, 7.60, 7.82, 8.04, 8.26, 8.28, 8.06, 7.84, 7.62, 7.40, 7.18, 6.97, 6.75], [6.75, 6.97, 7.19, 7.41, 7.63, 7.85, 8.07, 8.29, 8.26, 8.04, 7.82, 7.60, 7.38, 7.16, 6.94, 6.72]],
	"nha_I": [[10.74, 10.68, 10.62, 10.56, 10.50, 10.44, 10.38, 10.32, 10.26, 10.20, 10.14, 10.08, 10.02, 9.96, 9.90, -1.00], [10.80, 10.74, 10.68, 10.62, 10.56, 10.50, 10.44, 10.38, 10.32, 10.26, 10.20, 10.20, 10.20, 10.20, 10.20, -1.00], [10.75, 10.69, 10.63, 10.57, 10.51, 10.45, 10.39, 10.33, 10.27, 10.21, 10.15, 10.09, 10.03, 9.97, 9.91, -1.00]],
	"nha_K": [[10.55, 10.19, 10.42, 10.65, 10.88, 11.11, 11.33, 11.68, 11.27, 11.04, 10.81, 10.58, 10.35, 10.13, 9.90, -1.00], [11.20, 10.12, 10.34, 10.57, 10.80, 11.03, 11.26, 11.68, 11.34, 11.12, 10.89, 10.66, 10.43, 10.20, 9.97, -1.00], [10.55, 10.12, 10.35, 10.58, 10.80, 11.03, 11.26, 11.68, 11.34, 11.11, 10.89, 10.66, 10.43, 10.20, 9.97, -1.00]],
	"lo_banh": [[7.45, 7.02, 7.25, 7.48, 7.71, 7.94, 8.16, 8.58, 8.24, 8.01, 7.78, 7.55, 7.32, 7.10, 6.87, -1.00], [8.10, 7.09, 7.32, 7.55, 7.78, 8.01, 8.23, 8.58, 8.17, 7.94, 7.71, 7.48, 7.25, 7.03, 6.80, -1.00], [7.45, 7.04, 7.27, 7.50, 7.73, 7.95, 8.18, 8.58, 8.22, 7.99, 7.76, 7.53, 7.31, 7.08, 6.85, -1.00]],
}
const FACE_Z := -7.0                 ## mặt tiền dãy nam (ROW_Z.y); mái đo vào trong theo -Z
const MAX_DROP := 1.6                ## nhảy xuống chỗ lệch tới chừng này thì khỏi cầu thang
const COOP_DOOR := Vector3(-0.525, 0.88, 0.322)  ## bản lề cửa lưới ô dưới bên trái, mặt trước chuồng (+Z)

## Ván đang có: [{xf: Transform3D (gốc ở giữa mặt ván, trục X dọc ván), len, w}] (ThangBang đọc)
var planks: Array = []
## Lối đi theo đơn: "co_hai" (đơn 2), "be_na" (đơn 3), "chu_nam" (đơn 4); mỗi lối là các điểm nối tiếp
var routes := {}
## Chuồng bồ câu trên mái và chỗ đàn bồ câu đậu kiếm ăn trước chuồng (giữa lối đơn 3)
var coop := Vector3.ZERO
var perch := Vector3.ZERO
## Mái từng khối: [[x0, x1, cao hộp City, mẫu nhà, hộp va chạm]] từ tây sang đông
var roofs: Array = []
## Cửa lưới chuồng bồ câu (xoay quanh trục đứng để mở)
var coop_door: Node3D

var _paws: Array[Transform3D] = []
var _easy := true


## Dựng đường sân thượng sau City.build. Gọi trước khi Bơ vào cảnh.
func build(city_root: Node3D) -> void:
	name = "SanThuong"
	_easy = not DoKho.hard()
	roofs = _scan_roofs(city_root)
	if roofs.size() < 3 or roofs[0].size() < 2 or roofs[1].size() < 2 or roofs[2].is_empty():
		push_warning("SanThuong: không tìm thấy đủ mái nhà ba khối")
		return
	for row: Array in roofs:
		for h: Array in row:
			_fit_roof(h)
	var main_line: Array = []
	# Lên: chồng thùng cạnh lò (thùng cao nhất 2,4 m) → mái hiên → cầu thang trên mái hiên → mái nhà kế cuối khối 1
	var b1: Array = roofs[0]
	var last: Array = b1[b1.size() - 1]
	var entry: Array = b1[b1.size() - 2]
	var crate_top_x := ARCH_X - ARCH_W / 2.0 - 0.4 - 0.4  # thùng trên cùng nằm ngay tây cổng chào
	CityProps._stair(self, Vector3(crate_top_x - 1.6, 0, -5.6), 1.0)
	var entry_y := roof_y(entry, FACE_Z - 0.5, entry[1] - 0.5)
	var r0_top := Vector3(entry[1] + 0.1, entry_y, -6.5)
	var r0_len: float = (entry_y - AWNING_TOP) / tan(deg_to_rad(40.0))
	var r0_foot := Vector3(r0_top.x + r0_len, AWNING_TOP, -6.5)
	_ramp(r0_foot, r0_top, 0.9)
	_rails_along(r0_foot, r0_top, 0.9, [-1.0])  # phía đường; phía kia là mặt tiền
	_flat(Vector3(r0_top.x - 0.5, entry_y, -6.8), Vector3(1.0, 0, 1.6))  # chiếu nghỉ, chồm lên mái nhà
	main_line.append_array([Vector3(crate_top_x, 2.4, -5.6), Vector3(crate_top_x, AWNING_TOP, -6.5), r0_foot, r0_top,
		Vector3(r0_top.x - 0.5, roof_y(entry, -7.3, r0_top.x - 0.5), -7.3)])
	# Khối 1 → 2 → 3 trên mái
	var houses1: Array = b1.slice(b1.size() - 2)
	_walk_block(houses1, main_line)
	_crossing(last, roofs[1][0], main_line)
	var b2: Array = roofs[1]
	_walk_block(b2, main_line)
	# Đơn 2: xuống cầu thang gấp khúc dải vỉa hè đầu đông khối 2, vào hẻm giữa tới cửa sau tạp hóa
	var co_hai: Array = main_line.duplicate()
	var b2_last: Array = b2[b2.size() - 1]
	_switchback(b2_last[1], 1.0, roof_y(b2_last, ROW_Z.x + 0.05), co_hai)
	co_hai.append_array([Vector3(b2_last[1] + 1.55, 0, -15.2), Vector3(9.0, 0, -15.2)])
	routes["co_hai"] = co_hai
	# Đơn 3: qua đường x = 16 sang mái khối 3, xuống cầu thang dải vỉa hè đầu tây khối 3, vào hẻm Bé Na
	var be_na: Array = main_line.duplicate()
	var c1: Array = roofs[2][0]
	_crossing(b2_last, c1, be_na)
	be_na.append(Vector3(c1[0] + 0.4, roof_y(c1, -13.6), -13.6))
	_switchback(c1[0], -1.0, roof_y(c1, ROW_Z.x + 0.05), be_na)
	be_na.append_array([Vector3(c1[0] - 1.55, 0, -15.0), Vector3(c1[0] + 0.6, 0, -15.0)])
	routes["be_na"] = be_na
	# Đơn 4: mái hiên khối 1 → cổng chào qua đường lớn → dốc xuống đầu hẻm 42
	routes["chu_nam"] = _arch(crate_top_x)
	var spots := coop_spots(b2)
	coop = spots[0]
	perch = spots[1]
	_coop(coop)
	for key in routes:
		_paw_trail(routes[key])
	_draw_paws()
	Blocks.merge_static(self)


## Chuồng bồ câu: sân thượng phẳng nhất khối 2 (đơn 3 đi ngang), lệch về phía tây chừa chỗ bồn nước.
## Trả [chỗ chuồng, chỗ đàn đậu]. b2: nhà dãy nam khối 2 (_scan_roofs(...)[1]). z: chỗ chuồng theo chiều sâu mái.
static func coop_spots(b2: Array, z := -12.4) -> Array:
	var flat: Array = b2[0]
	for h in b2:
		if _flatness(h) < _flatness(flat):
			flat = h
	var cx: float = flat[0] + (flat[1] - flat[0]) * 0.3
	return [Vector3(cx, roof_y(flat, z, cx), z), Vector3((flat[0] + flat[1]) / 2.0, roof_y(flat, -10.4), -10.4)]


## Chuồng bồ câu trên mái khối 2 của phố đã dựng (root: nút chứa nhà, như main): [chỗ chuồng, chỗ đứng trên gờ
## tường mặt tiền ngay trước chuồng]. Rỗng nếu không đo được mái. Thứ Bảy (bồ câu non) đặt chuồng sát mép mái
## phía đường (z -7,9), chim đậu trên gờ cho thấy được từ vỉa hè.
static func coop_in(root: Node3D, z := -12.4) -> Array:
	var roofs := _scan_roofs(root)
	if roofs[1].is_empty():
		return []
	var c: Vector3 = coop_spots(roofs[1], z)[0]
	var ledge := c.y
	for h: Array in roofs[1]:
		var prof := _prof(h)
		if c.x > h[0] and c.x < h[1] and not prof.is_empty():
			ledge = maxf(ledge, prof[1][0])
	return [c, Vector3(c.x, ledge, FACE_Z - 0.12)]


# ---------------------------------------------------------------- đo mái

## Hộp va chạm nhà dãy nam khối 1–3 (cao trên 4 m, chân ở đất), xếp theo x. Trả [[khối1], [khối2], [khối3]],
## mỗi nhà [x0, x1, cao hộp, mẫu nhà (meta "model" City gắn, "" nếu không rõ), hộp va chạm].
static func _scan_roofs(root: Node3D) -> Array:
	var out := [[], [], []]
	for n in root.get_children():
		var body := n as StaticBody3D
		if body == null or body.get_child_count() == 0:
			continue
		var cs := body.get_child(0) as CollisionShape3D
		if cs == null or not cs.shape is BoxShape3D:
			continue
		var s: Vector3 = (cs.shape as BoxShape3D).size
		var p: Vector3 = body.position + cs.position
		if s.x > 12.0 or p.y + s.y / 2.0 < 4.0 or p.y - s.y / 2.0 > 4.0:
			continue  # chỉ thân nhà (có thể chừa tầng trệt rỗng), bỏ vách mỏng, cột, tường bao
		if absf(p.z - s.z / 2.0 - ROW_Z.x) > 0.1 or absf(p.z + s.z / 2.0 - ROW_Z.y) > 0.1:
			continue
		var b := 0 if p.x < -22.0 else (1 if p.x < 12.0 else 2)
		out[b].append([p.x - s.x / 2.0, p.x + s.x / 2.0, p.y + s.y / 2.0, String(body.get_meta("model", "")), body])
	for row: Array in out:
		row.sort_custom(func(a, c): return a[0] < c[0])
	return out


## Mặt mái của nhà `h`: mẫu nhà cũ đo sẵn, hoặc nhà ráp P2 (City gắn khóa căn "rap:..." vào meta "model").
static func _prof(h: Array) -> Array:
	var name: String = h[3]
	return ROOF_PROFILE.get(name, []) if ROOF_PROFILE.has(name) else NhaRap.roof_profile(name)


## Độ cao mặt mái nhà `h` ở z (thế giới), theo dải ngang gần x nhất (mặc định giữa nhà).
static func roof_y(h: Array, z: float, x := NAN) -> float:
	var prof: Array = _prof(h)
	if prof.is_empty():
		return h[2]
	var k := 1
	if not is_nan(x):
		k = clampi(roundi((x - h[0]) / (h[1] - h[0]) * 4.0) - 1, 0, 2)
	var row: Array = prof[k]
	var t := clampf((FACE_Z - z) / 0.5, 1.0, 14.0)  # bỏ điểm 0 (gờ, biển mặt tiền) và phần sau nhà
	var i := mini(int(t), 13)
	return lerpf(row[i], row[i + 1], t - i)


## Mái lệch nhiều nhất bao nhiêu (sân thượng phẳng ~0, mái tôn ~1,5 m).
static func _flatness(h: Array) -> float:
	var prof: Array = _prof(h)
	if prof.is_empty():
		return 0.5
	var row: Array = prof[0]
	var lo := INF
	var hi := -INF
	for i in range(1, 15):
		lo = minf(lo, row[i])
		hi = maxf(hi, row[i])
	return hi - lo


## Hạ hộp va chạm nhà xuống chỗ thấp nhất của mái rồi lát các tấm nghiêng theo mái thật, mỗi dải ngang một lượt
## (dải nào giống dải giữa thì gộp). Bồn nước, chòi cầu thang trên sân thượng thành vách dốc đứng.
func _fit_roof(h: Array) -> void:
	var prof: Array = _prof(h)
	var body: StaticBody3D = h[4]
	if prof.is_empty() or body == null:
		return
	var lo := INF
	for row: Array in prof:
		for i in range(1, 15):
			lo = minf(lo, row[i])
	var cs := body.get_child(0) as CollisionShape3D
	var box := (cs.shape as BoxShape3D).duplicate() as BoxShape3D
	box.size.y = lo - 0.05
	cs.shape = box
	cs.position.y = box.size.y / 2.0 - body.position.y
	var x0: float = h[0]
	var w: float = h[1] - h[0]
	var same := true
	for k in [0, 2]:
		for i in range(1, 15):
			if absf(prof[k][i] - prof[1][i]) > 0.1:
				same = false
	var bands := [[x0, w, prof[1]]] if same else [[x0, w / 3.0, prof[0]], [x0 + w / 3.0, w / 3.0, prof[1]], [x0 + w * 2.0 / 3.0, w / 3.0, prof[2]]]
	# Mặt mái là một tấm lưới tam giác (không có cạnh hộp gờ lên giữa các đoạn), mỗi dải ngang một dải lưới;
	# bậc giữa hai dải (bồn nước, chòi) có vách đứng nối hai mép.
	var faces := PackedVector3Array()
	var prev_row: Array = []
	for band: Array in bands:
		var row: Array = band[2]
		var xa: float = band[0]
		var xb: float = band[0] + band[1]
		var pts: Array[Vector3] = []
		for i in range(1, 15):
			var z := FACE_Z - 0.5 * i
			var y: float = row[i]
			if i == 1:
				z = FACE_Z
			if i == 14:
				z = ROW_Z.x
				y = row[13] + (row[14] - row[13]) * (absf(ROW_Z.x - FACE_Z) - 6.5) / 0.5
			pts.append(Vector3(0, y, z))
		for i in pts.size() - 1:
			var p0 := pts[i]
			var p1 := pts[i + 1]
			faces.append_array([Vector3(xa, p0.y, p0.z), Vector3(xb, p0.y, p0.z), Vector3(xb, p1.y, p1.z),
				Vector3(xa, p0.y, p0.z), Vector3(xb, p1.y, p1.z), Vector3(xa, p1.y, p1.z)])
		if not prev_row.is_empty():
			for i in pts.size() - 1:
				var q0: Vector3 = prev_row[i]
				var q1: Vector3 = prev_row[i + 1]
				var lo0 := minf(q0.y, pts[i].y)
				var hi0 := maxf(q0.y, pts[i].y)
				var lo1 := minf(q1.y, pts[i + 1].y)
				var hi1 := maxf(q1.y, pts[i + 1].y)
				if hi0 - lo0 > 0.05 or hi1 - lo1 > 0.05:
					faces.append_array([Vector3(xa, lo0, q0.z), Vector3(xa, hi0, q0.z), Vector3(xa, hi1, q1.z),
						Vector3(xa, lo0, q0.z), Vector3(xa, hi1, q1.z), Vector3(xa, lo1, q1.z)])
		prev_row = pts
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var roof := StaticBody3D.new()
	roof.name = "MaiThat"
	roof.collision_layer = Blocks.LAYER_WORLD
	var cs2 := CollisionShape3D.new()
	cs2.shape = shape
	roof.add_child(cs2)
	add_child(roof)


# ---------------------------------------------------------------- lối đi trên mái

## Đi từ nhà đầu tới nhà cuối của một khối. Mỗi bức tường chung tìm chỗ hai mái lệch ít nhất: lệch ít thì bước
## (hoặc nhảy xuống tới MAX_DROP), lệch nhiều thì cầu thang sắt chạy dọc chiều sâu nhà, chân ở phía mặt tiền.
func _walk_block(houses: Array, line: Array) -> void:
	var tan_s := tan(SLOPE)
	for i in houses.size() - 1:
		var a: Array = houses[i]
		var b: Array = houses[i + 1]
		var wall: float = (a[1] + b[0]) / 2.0
		var best_z := RAMP_FOOT_Z
		var best_dh := INF
		var z := -7.6
		while z > -13.8:
			var dh := roof_y(b, z, b[0] + 0.3) - roof_y(a, z, a[1] - 0.3)
			if absf(dh) < absf(best_dh) - 0.01:
				best_dh = dh
				best_z = z
			z -= 0.1
		if best_dh > -MAX_DROP and best_dh < 0.3:
			# Bước sang (hoặc nhảy xuống) ở chỗ hai mái gần bằng nhau
			line.append_array([Vector3(wall - 0.5, roof_y(a, best_z, wall - 0.5), best_z), Vector3(wall + 0.6, roof_y(b, best_z, wall + 0.6), best_z)])
			continue
		var up := best_dh > 0.0
		var low: Array = a if up else b
		var high: Array = b if up else a
		var xc: float = wall - 0.2 - RAMP_W / 2.0 if up else wall + 0.2 + RAMP_W / 2.0
		var foot := Vector3(xc, roof_y(low, RAMP_FOOT_Z, xc), RAMP_FOOT_Z)
		# Đỉnh thang: chỗ đường dốc 36° từ chân gặp mặt mái nhà cao (tối đa RAMP_MAX_RISE, thiếu thì nhảy xuống)
		var top := foot
		var err := INF
		z = RAMP_FOOT_Z - 1.0
		while z > -13.6:
			var y := foot.y + (RAMP_FOOT_Z - z) * tan_s
			if y - foot.y > RAMP_MAX_RISE:
				break
			var e := absf(roof_y(high, z - 0.45, wall + (0.5 if up else -0.5)) - y)
			if e < err:
				err = e
				top = Vector3(xc, y, z)
			z -= 0.05
		_ramp(foot, top, RAMP_W)
		var land_x := wall - 0.1 if up else wall + 0.25
		_flat(Vector3(land_x, top.y, top.z - 0.45), Vector3(RAMP_W + (1.3 if up else 1.1), 0, 0.9))
		var hx := wall + (0.7 if up else -0.5)
		if up:
			line.append_array([Vector3(xc, roof_y(a, RAMP_FOOT_Z + 0.5, xc), RAMP_FOOT_Z + 0.5), foot, top,
				Vector3(hx, roof_y(b, top.z - 0.35, hx), top.z - 0.35)])
		else:
			line.append_array([Vector3(hx, roof_y(a, top.z - 0.35, hx), top.z - 0.35), Vector3(xc, top.y, top.z - 0.35), top, foot,
				Vector3(xc, roof_y(b, RAMP_FOOT_Z + 0.5, xc), RAMP_FOOT_Z + 0.5)])


## Qua đường dọc giữa hai khối: ván, giàn sắt (dốc theo độ cao hai mái), ván.
func _crossing(west: Array, east: Array, line: Array) -> void:
	var xw: float = west[1]
	var xe: float = east[0]
	var hw := roof_y(west, CROSS_Z, xw - 0.3)
	var he := roof_y(east, CROSS_Z, xe + 0.3)
	line.append(Vector3(xw - 0.6, hw, CROSS_Z))
	_plank(Vector3(xw - 0.3, hw, CROSS_Z), Vector3(xw + PLANK_LEN, hw, CROSS_Z))
	var g0 := Vector3(xw + PLANK_LEN, hw, CROSS_Z)
	var g1 := Vector3(xe - PLANK_LEN, he, CROSS_Z)
	_gantry(g0, g1)
	_plank(Vector3(xe - PLANK_LEN, he, CROSS_Z), Vector3(xe + 0.3, he, CROSS_Z))
	line.append_array([g0 - Vector3(PLANK_LEN, 0, 0), g0, g1, g1 + Vector3(PLANK_LEN, 0, 0), Vector3(xe + 0.6, he, CROSS_Z)])


## Cầu thang sắt gấp khúc trong dải vỉa hè 2,1 m ở đầu khối (giữa nhà cuối và đường dọc).
## side = 1: dải nằm phía đông nhà (x_edge là mép đông mái), -1: phía tây. Đỉnh ở phía bắc (z -14),
## đợt đầu sát tường đi xuống về phía nam, các đợt sau đổi bên. Đi dưới các đợt trên vẫn đủ cao.
func _switchback(x_edge: float, side: float, height: float, line: Array) -> void:
	var n := int(ceil(height / FLIGHT_RISE))
	var rise := height / n
	var lf := rise / tan(deg_to_rad(38.0))
	var x_in := x_edge + side * (0.05 + FLIGHT_W / 2.0)
	var x_out := x_edge + side * (0.15 + FLIGHT_W * 1.5)
	var z_n := -14.0
	var z_s := z_n + lf
	var mid := (x_in + x_out) / 2.0
	var width := absf(x_out - x_in) + FLIGHT_W
	# Chiếu nghỉ trên cùng, chồm lên mép mái
	_flat(Vector3(x_in - side * 0.4, height, z_n - 0.35), Vector3(FLIGHT_W + 0.8, 0, 0.7))
	line.append_array([Vector3(x_in - side * 0.5, height, z_n - 0.35), Vector3(x_in, height, z_n - 0.3)])
	var h := height
	for k in n:
		var x := x_in if k % 2 == 0 else x_out
		var from_z := z_n if k % 2 == 0 else z_s
		var to_z := z_s if k % 2 == 0 else z_n
		var a := Vector3(x, h, from_z)
		var b := Vector3(x, h - rise, to_z)
		_ramp(b, a, FLIGHT_W)
		# Lan can phía hở: đợt sát tường chắn sang làn ngoài, đợt làn ngoài chắn phía đường
		var rail_x := x + side * (FLIGHT_W / 2.0 + 0.03)
		_slope_rail(Vector3(rail_x, b.y, b.z), Vector3(rail_x, a.y, a.z))
		h -= rise
		line.append_array([a, b])
		if k < n - 1:
			# Chiếu nghỉ đổi bên
			var lz := z_s + 0.45 if k % 2 == 0 else z_n - 0.45
			_flat(Vector3(mid, h, lz), Vector3(width, 0, 0.9))
			_rail_wall(Vector3(mid, h, lz + (0.48 if k % 2 == 0 else -0.48)), Vector3(width, 0, 0.06), 1.0)
			line.append(Vector3(x_out if k % 2 == 0 else x_in, h, lz))
	# Xuống tới đất: bước ra, sang làn ngoài rồi đi lên phía bắc dưới các đợt thang
	var end_z := z_s + 0.5 if n % 2 == 1 else z_n - 0.5
	line.append_array([Vector3(x_in, 0, end_z), Vector3(x_out, 0, end_z)])


## Cổng chào bắc qua đường lớn ngang mái hiên khối 1 (model cong_chao_game), đầu nam có chiếu nghỉ và cầu thang
## sắt xuống phía đông, tới đầu hẻm 42.
func _arch(crate_top_x: float) -> Array:
	var len_z := ARCH_Z.y - ARCH_Z.x
	var mid_z := (ARCH_Z.x + ARCH_Z.y) / 2.0
	var beam := Blocks.collider(self, Vector3(ARCH_W, 0.14, len_z), Vector3(ARCH_X, AWNING_TOP - 0.07, mid_z))
	beam.name = "CongChao"
	ThuTuModels.put(self, "cong_chao_game", Vector3(ARCH_X, 0, mid_z), -PI / 2.0)
	# Mép tây dầm (x -24,2) gối lên mái hiên khối 1 (tới x -24,1). Hai khung cổng mỗi khung hai cột đứng ngoài lối đi.
	for z in [ARCH_Z.x + 1.3, ARCH_Z.y - 1.45]:
		for sx in [-1.0, 1.0]:
			Blocks.collider(self, Vector3(0.3, 4.6, 0.3), Vector3(ARCH_X + sx * 0.65, 2.3, z), Blocks.LAYER_PROP)
	# Lan can: phía tây chừa đầu bắc (bước từ mái hiên khối 1 vào), phía đông dừng trước chiếu nghỉ cầu thang
	var west_z := mid_z + ARCH_WEST_FROM
	_rail_wall(Vector3(ARCH_X - ARCH_W / 2.0 - 0.03, AWNING_TOP, (west_z + ARCH_Z.y) / 2.0), Vector3(0.06, 0, ARCH_Z.y - west_z), 1.0, false)
	var gap_z := mid_z + ARCH_GAP
	_rail_wall(Vector3(ARCH_X + ARCH_W / 2.0 + 0.03, AWNING_TOP, (ARCH_Z.x + 0.3 + gap_z) / 2.0), Vector3(0.06, 0, gap_z - ARCH_Z.x - 0.3), 1.0, false)
	# Chiếu nghỉ 0,9 m rồi cầu thang (model: 18 bậc, ngang 3,96 m)
	var stair_z := ARCH_Z.y - 0.45
	var land_x := ARCH_X + ARCH_W / 2.0
	_flat(Vector3(land_x + 0.45, AWNING_TOP, stair_z), Vector3(0.9, 0, 1.05), false)
	var top := Vector3(land_x + 0.9, AWNING_TOP, stair_z)
	var foot := top + Vector3(ARCH_STAIR_RUN, -AWNING_TOP, 0)
	_ramp(foot, top, 0.9, false)
	_rails_along(foot, top, 0.9, [1.0, -1.0])
	return [Vector3(crate_top_x, 2.4, -5.6), Vector3(crate_top_x, AWNING_TOP, -6.5), Vector3(ARCH_X, AWNING_TOP, -6.5),
		Vector3(ARCH_X, AWNING_TOP, stair_z), Vector3(land_x + 0.45, AWNING_TOP, stair_z), top, foot, foot + Vector3(0.8, 0, 1.2)]


# ---------------------------------------------------------------- khối

## Mặt dốc đi được từ foot (thấp) tới top (cao) theo một trục X hoặc Z; nhìn là cầu thang sắt G5 (dress).
func _ramp(foot: Vector3, top: Vector3, width: float, dress := true) -> void:
	var d := top - foot
	var horiz := Vector3(d.x, 0, d.z)
	var run := horiz.length()
	var length := Vector3(run, d.y, 0).length()
	var body := StaticBody3D.new()
	body.collision_layer = Blocks.LAYER_WORLD
	add_child(body)
	var basis := Basis.looking_at(-d.normalized(), Vector3.UP)  # trục Z cục bộ dọc dốc
	var thick := 0.2
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	# Dài thêm 0,3 m phía chân (chìm vào mặt dưới), đầu trên dừng đúng mép cho khỏi gờ với chiếu nghỉ
	bs.size = Vector3(width, thick, length + 0.3)
	shape.shape = bs
	body.add_child(shape)
	body.transform = Transform3D(basis, (foot + top) / 2.0 - basis.z * 0.15 - basis.y * (thick / 2.0))
	if dress:
		ThuTuModels.stairs(self, foot, top, width)


## Lan can hai bên dốc: side 1 = bên phải hướng đi lên, -1 = bên trái.
func _rails_along(foot: Vector3, top: Vector3, width: float, sides: Array) -> void:
	var horiz := Vector3(top.x - foot.x, 0, top.z - foot.z).normalized()
	for s in sides:
		var off: Vector3 = horiz.cross(Vector3.UP) * float(s) * (width / 2.0 + 0.03)
		_slope_rail(foot + off, top + off)


## Lan can theo dốc (tay vịn đã có trên model): va chạm vô hình là các đoạn tường đứng 0,6 m nối bậc
## (không chồm ra chiếu nghỉ), cao 1 m trên mặt dốc.
func _slope_rail(foot: Vector3, top: Vector3) -> void:
	var d := top - foot
	var horiz := Vector3(d.x, 0, d.z)
	var run := horiz.length()
	var n := maxi(1, int(ceil(run / 0.6)))
	for k in n:
		var p0 := foot.lerp(top, float(k) / n)
		var p1 := foot.lerp(top, float(k + 1) / n)
		var lo := minf(p0.y, p1.y) - 0.1
		var hi := maxf(p0.y, p1.y) + 1.0
		var c := (p0 + p1) / 2.0
		var seg := Vector3(absf(p1.x - p0.x), 0, absf(p1.z - p0.z))
		Blocks.collider(self, Vector3(maxf(seg.x, 0.06), hi - lo, maxf(seg.z, 0.06)), Vector3(c.x, (lo + hi) / 2.0, c.z))


## Mặt phẳng đi được (chiếu nghỉ): pos là giữa mặt trên, size.y bỏ qua (dày 0,2 m). Tấm thép nhìn thấy thấp hơn
## mặt va chạm 1,5 cm cho khỏi chập với chiếu nghỉ của model cầu thang; show = false khi model đã có sàn.
func _flat(top_center: Vector3, size: Vector3, show := true) -> void:
	Blocks.collider(self, Vector3(size.x, 0.2, size.z), top_center - Vector3(0, 0.1, 0))
	if show:
		Blocks.box(self, Vector3(size.x, 0.2, size.z), top_center - Vector3(0, 0.115, 0), STEEL)


## Lan can: va chạm vô hình từ base.y cao `height`, có thanh vịn nhìn thấy ở trên cùng (show).
func _rail_wall(base: Vector3, size: Vector3, height: float, show := true) -> void:
	Blocks.collider(self, Vector3(maxf(size.x, 0.06), height, maxf(size.z, 0.06)), base + Vector3(0, height / 2.0, 0))
	if show:
		Blocks.box(self, Vector3(maxf(size.x, 0.04), 0.04, maxf(size.z, 0.04)), base + Vector3(0, height - 0.25, 0), STEEL_DARK)


## Ván gỗ bắc qua khe (model van_vua 2,0 m kéo theo chiều dài): gốc a, ngọn b cùng độ cao.
## Thong thả có lan can vô hình thấp hai bên cho khỏi rớt.
func _plank(a: Vector3, b: Vector3) -> void:
	var c := (a + b) / 2.0
	var length := a.distance_to(b)
	var w := 0.45 if _easy else 0.3
	var body := Blocks.collider(self, Vector3(length, PLANK_THICK + 0.1, w), c - Vector3(0, (PLANK_THICK + 0.1) / 2.0, 0))
	body.name = "Van"
	ThuTuModels.put(self, "van_vua", c - Vector3(0, 0.061, 0), 0.0, Vector3(length / 2.0, 1, 1))
	if _easy:
		for s in [-1.0, 1.0]:
			Blocks.collider(self, Vector3(length - 0.6, 0.6, 0.06), c + Vector3(0, 0.3, s * 0.33))  # mặt trong cách giữa ván 0,3 m (Bơ rộng 0,25)
	planks.append({"xf": Transform3D(Basis.IDENTITY, c), "len": length, "w": PLANK_W})


## Giàn sắt bắc ngang đường (model gian_sat_*: sàn rộng 0,9 m, giàn lan can hai bên, hai cột phía bắc, biển
## "Bánh mì Cô Ba" treo dưới bụng phía nam).
func _gantry(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := d.length()
	var basis := Basis.looking_at(-d.normalized(), Vector3.UP)
	var deck := Blocks.collider(self, Vector3(GANTRY_W, 0.12, length + 0.1), Vector3.ZERO)
	deck.transform = Transform3D(basis, (a + b) / 2.0 - basis.y * 0.06)
	for s in [-1.0, 1.0]:
		var off := Vector3(0, 0, s * (GANTRY_W / 2.0 + 0.03))
		_slope_rail(a + off, b + off)
	for p in [a, b]:
		Blocks.collider(self, Vector3(0.3, p.y, 0.3), Vector3(p.x, p.y / 2.0 - 0.1, p.z - GANTRY_W / 2.0 - 0.3), Blocks.LAYER_PROP)
	ThuTuModels.gantry(self, a, b)


## Chuồng bồ câu gỗ có cửa lưới (model chuong_bo_cau_game, gốc giữa thân; cửa gốc ở bản lề).
func _coop(p: Vector3) -> void:
	var body := Blocks.collider(self, Vector3(1.2, 1.7, 0.75), p + Vector3(0, 0.85, 0), Blocks.LAYER_PROP)
	body.name = "ChuongBoCau"
	ThuTuModels.put(self, "chuong_bo_cau_game", p)
	coop_door = ThuTuModels.put(self, "cua_chuong_game", p + COOP_DOOR)


# ---------------------------------------------------------------- dấu chân

func _paw_trail(pts: Array) -> void:
	var carry := 0.0
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var seg := a.distance_to(b)
		if seg < 0.01 or absf(b.y - a.y) > 0.3 and Vector2(b.x - a.x, b.z - a.z).length() < 0.6:
			continue  # bước nhảy, không vẽ dấu giữa không trung
		var dir := (b - a) / seg
		var yaw := atan2(-dir.x, -dir.z)
		var t := 1.2 - carry
		while t < seg:
			var p := a + dir * t
			_paws.append(Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 0.035, 0)))
			t += 1.2
		carry = seg - (t - 1.2)


func _draw_paws() -> void:
	if _paws.is_empty():
		return
	var arrow := PrismMesh.new()
	arrow.size = Vector3(0.22, 0.26, 0.02)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Mũi tên nằm phẳng, đỉnh chỉ -Z (hướng đi)
	var lay := Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO)
	for xf in _paws:
		st.append_from(arrow, 0, xf * lay)
	var mi := MeshInstance3D.new()
	mi.name = "DauChan"
	mi.mesh = st.commit()
	mi.material_override = Blocks.mat(PAW, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
