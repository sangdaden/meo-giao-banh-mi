class_name ThuBay
extends Node3D
## Thứ Bảy · Dạo phố (gói việc thiet-ke-man/goi-viec-thu-bay.md). Không đồng hồ, không sao, không mũi tên chạy đơn,
## không có thua. main.gd thêm node này cho mọi ngày, ngày khác tự gỡ; ngày "mode": "free" không có đơn nên
## main.start_game() gọi begin() rồi để node này lo phần chơi.
## - Sổ hàng xóm (SoHangXom, Tab): 10 người, ai có việc nhờ thì trên đầu có dấu "!"; tới gần bấm E để giúp.
##   Mỗi việc một file trong scripts/viec_nho/. Giúp xong: Bơ tạo dáng, tự chụp ảnh chung dán vào trang, +1 tim, quà.
## - Trời đi theo việc: mỗi việc xong trời ngả thêm một nấc (sáng → trưa → chiều → hoàng hôn), ngủ trên mái tôn đủ
##   10 s cũng ngả một nấc. Không việc nào bị lỡ.
## - Giúp đủ DoKho "muc_chapter_after" người thì mở chương Chó Mực (scripts/viec_nho/muc.gd); xong thì Mực đi theo
##   Bơ (MucBan) và có thể kết ngày: lên "bồn nước" trên mái hiên cạnh lò bánh ngắm hoàng hôn, nhận thư mời Hội mèo.
## - Chụp ảnh tự do P (ChupAnh) bật cả ngày.
## Người dân G9, đồ việc nhờ G8, mèo lạ G10 là model thật; bồn nước kết ngày và vài đồ nhỏ còn khối tạm.
## Tự kiểm tra: godot --headless -- --autotest --ngay=thu_bay (bot giúp đủ 10 người, làm chương Mực rồi kết ngày).

const DAY := "thu_bay"
const VIEC := {
	"coba": preload("res://scripts/viec_nho/co_ba.gd"),
	"chutu": preload("res://scripts/viec_nho/chutu.gd"),
	"bena": preload("res://scripts/viec_nho/bena.gd"),
	"may": preload("res://scripts/viec_nho/may.gd"),
	"hung": preload("res://scripts/viec_nho/hung.gd"),
	"basau": preload("res://scripts/viec_nho/basau.gd"),
	"ongbay": preload("res://scripts/viec_nho/ongbay.gd"),
	"cohai": preload("res://scripts/viec_nho/cohai.gd"),
	"chunam": preload("res://scripts/viec_nho/chunam.gd"),
	"chithu": preload("res://scripts/viec_nho/chithu.gd"),
	"muc": preload("res://scripts/viec_nho/muc.gd"),
}
## Người nhờ chưa có trong phố hôm nay thì dựng ở đây (Cô Ba, Cô Hai, Chú Năm do residents.gd dựng; hai ông do
## ChessCorner). seat: ngồi ghế đẩu cao Nguoi.SEAT; chair: ghế có sẵn (ghế mây Bà Sáu). model: người đứng tạm.
## idle: clip đứng chờ (mặc định viec_rieng).
const PEOPLE := {
	"chutu": {"pos": Vector3(-1.0, 0, -6.63), "yaw": 0.0, "idle": "dung_cho"},  # Thứ Bảy Chú Tư đứng cả ngày (G9)
	"bena": {"pos": Vector3(24.0, 0, -15.6), "yaw": 0.0},
	"may": {"pos": Vector3(5.2, 0, 6.8), "yaw": PI},
	"hung": {"pos": Vector3(33.8, 0, 25.0), "yaw": 0.0, "seat": true},
	"basau": {"pos": CityProps.BA_SAU_CHAIR + Vector3(0, 0.08, -0.07), "yaw": PI, "chair": true},
	# Chị Thu (G1 Sang duyệt 22/10) đứng cạnh võng ru em bé
	"chithu": {"pos": Vector3(31.6, 0, -15.2), "yaw": -PI / 2.0, "idle": "ru_vong"},
}
## Động tác G9 (PR "Người dân vào game"): [lúc nhờ, lúc cảm ơn sau khi chụp]. Chưa có clip thì dùng noi / vui.
const REACT := {
	"coba": ["nem_banh", "khen_ngon"], "chutu": ["chi_len", "nhan_bao"], "bena": ["lo_dau", "bi_tim_thay"],
	"may": ["chi_bang", "vo_tay"], "hung": ["cui_tim", "nhan_oc"], "basau": ["chi_gian", "nhan_bong"],
	"ongbay": ["chi_quan_co", "reo"], "cohai": ["chong_nanh", "vo_tay"], "chunam": ["gai_dau", "chi_mai"],
}
const HAMMOCK := Vector3(30.6, 0, -15.6)
## Kết ngày: "bồn nước" (khối tạm) trên mái hiên khối 1 cạnh lò bánh; leo lên bằng chồng thùng góc khối (City.CORNER_STAIR)
const END_SPOT := Vector2(-28.8, -6.55)
## Mái tôn ấm để ngủ trưa (mái hiên khối 5 phía tây quán cà phê)
const NAP_SPOT := Vector2(1.0, 6.55)
const NAP_TIME := 10.0
const PIGEON_HOME := Vector3(-34.0, 0, 17.5)
const SKY := ["pho_sang", "pho_trua", "pho_chieu", "pho_hoang_hon"]
const SKY_STEPS := 6               ## số nấc từ sáng tới hoàng hôn
const TALK := 2.3                  ## tới gần người nhờ chừng này thì bấm E
const IDLE_LINE := "Đi dạo một vòng: ai có dấu ! trên đầu là đang cần Bơ giúp"

var main: Node3D
var player: CharacterBody3D
var dog: CharacterBody3D
var hud: CanvasLayer
var ui: ThuBayHud
var photo: ChupAnh
var pigeons: BoCau
var people := {}                   ## id -> Nguoi
var autotest := false

var _started := false
var _active: ViecNho
var _active_id := ""
var _bubbles := {}                 ## id -> BongThoai
var _celebrating := false
var _sky_t := 0.0
var _sky_goal := 0.0
var _steps := 0
var _lamps: Node3D
var _nap := 0.0
var _napped := false
var _still := 0.0
var _end_ready := false
var _ended := false
var _end_nodes: Array[Node3D] = []
var _near_id := ""
var _bot_frames := 0
var _bot_end := false
var _hang_told := false            ## đã nhắc cách leo lên/buông mép một lần


func _ready() -> void:
	name = "ThuBay"
	main = get_parent()
	var d: Dictionary = main.get("day") if main.get("day") != null else {}
	if d.get("id", "") != DAY:
		queue_free()
		return
	player = main.get("player")
	dog = main.get("dog")
	autotest = "--autotest" in OS.get_cmdline_user_args()
	player.climb_moves = true  # mái hiên, giàn bông giấy: bám mép, đạp tường
	player.ledge_grabbed.connect(_on_ledge_grabbed)
	_add_action("goi", KEY_Q, JOY_BUTTON_LEFT_SHOULDER)
	_add_action("so_hang_xom", KEY_TAB, JOY_BUTTON_BACK)
	_add_action("chup_anh", KEY_P, -1)
	_build_people()
	add_to_group("ban_do_nho")  # ghim người nhờ việc trên bản đồ nhỏ: ban_do_pins()
	var nap := ViecNho.trinket(Vector3(0.9, 0.02, 0.6), Color("#B9826A"), "box")
	add_child(nap)
	nap.global_position = ViecNho.surface(get_world_3d(), NAP_SPOT.x, NAP_SPOT.y)
	pigeons = BoCau.new()
	pigeons.player = player
	add_child(pigeons)
	pigeons.perch_at(PIGEON_HOME)
	ui = ThuBayHud.new()
	ui.day = self
	add_child(ui)
	ui.visible = false
	photo = ChupAnh.new()
	photo.player = player
	add_child(photo)
	photo.extra_hide = [ui]
	dog.set_tag_visible(false)  # Thứ Bảy Mực mất thẻ tên từ sáng
	dog.awake = false


## main.start_game() gọi khi vào ngày (lúc này file lưu đã sẵn, kể cả file riêng của tự kiểm tra).
func begin() -> void:
	hud = main.get("hud")
	photo.hud = hud
	_started = true
	ui.visible = true
	if hud.has_method("show_minimap"):
		hud.show_minimap(true)
	_steps = mini(SoHangXom.done_ids().size(), SKY_STEPS)
	_sky_goal = float(_steps) / SKY_STEPS
	_sky_t = _sky_goal
	_apply_sky(_sky_t)
	_refresh_bubbles()
	if SoHangXom.muc_friend():
		_befriend(false)
	elif muc_chapter_open():
		dog.play_clip("nam_buon")
	ui.set_line(IDLE_LINE)
	var data := Days.get_day(DAY)
	if not autotest and hud.has_method("show_day_card"):
		hud.show_day_card("%s · %s" % [data.name, data.title], data.intro, [
			"Ai có dấu ! trên đầu là đang cần Bơ giúp: tới gần bấm E",
			"Tab mở Sổ hàng xóm · P chụp ảnh",
			"Không đồng hồ, không sao: cứ thong thả dạo phố",
		], 6.0)
	# Mẹo lần đầu "Chó Mực đang ngủ, rón rén" không đúng hôm nay (Mực không canh hẻm): bỏ qua trong lượt này
	for c in main.get_children():
		if c is FirstHints:
			var seen: PackedStringArray = c.get("_seen")
			seen.append("muc")
			c.set("_seen", seen)
	var residents: Node = main.get("residents")
	if residents and residents.has_method("say"):
		residents.say("Thứ Bảy rồi, cô cho Bơ nghỉ! Cầm cuốn sổ đi chơi, ai cần gì thì giúp nha.", 5.0, "vay")


## Lần đầu bám mép (chồng thùng, xe bánh mì...): nhắc cách leo lên hay buông, kẻo tưởng Bơ bị kẹt.
func _on_ledge_grabbed() -> void:
	if not _hang_told:
		_hang_told = true
		toast(player.hang_hint(), 3.0)


func toast(text: String, seconds := 2.0) -> void:
	if hud:
		hud.show_toast(text, seconds)
	_voice_quote(text)


## Thông báo có lời người nói ("Chị Mây: \"...\"", "Cô Ba nếm thử: \"...\"") thì người đó nói ú ớ câu trong ngoặc.
func _voice_quote(text: String) -> void:
	var q := text.find("\"")
	if q < 0:
		return
	var words := text.substr(0, q).replace(".", " ").replace(":", " ").split(" ", false)
	# Tên người: hai chữ ngay trước lời ("... Chị Thu: \"") hoặc hai chữ đầu ("Cô Ba nếm thử: \"")
	var who := ""
	for start in [words.size() - 2, 0]:
		if start >= 0 and words.size() >= 2 and GiongUO.BY_TITLE.has(words[start]):
			who = words[start] + " " + words[start + 1]
			break
	if who == "":
		return
	GiongUO.noi(who, text.substr(q + 1).trim_suffix("\"").get_slice("\"", 0))


func task_line(text: String) -> void:
	if ui and _active:
		ui.set_line(text)


func active_id() -> String:
	return _active_id


## Dòng tóm tắt dưới chữ "Tạm dừng" (main.gd hỏi khi bấm Esc): tim thân thiết và việc đang làm, không có "Đơn 1/5".
func pause_info() -> String:
	var line := ui.line_text() if ui else ""
	return "Dạo phố · ♥ %d/%d%s" % [SoHangXom.hearts(), SoHangXom.PEOPLE_PAGES, (" · " + line) if line != "" else ""]


func muc_chapter_open() -> bool:
	return SoHangXom.muc_friend() or SoHangXom.hearts() >= int(DoKho.v("muc_chapter_after", 3))


## Ghim cho bản đồ nhỏ: mỗi người trong Sổ hàng xóm một trái tim; giúp xong thì có dấu tích.
func ban_do_pins() -> Array:
	var pins := []
	for p in SoHangXom.pages():
		var n: Node3D = people.get(p.id)
		if n == null or not is_instance_valid(n):
			continue
		var st := "done" if SoHangXom.is_done(p.id) else ("now" if p.id == _active_id else "next")
		pins.append({"pos": n.global_position, "kind": "favour", "text": "", "color": Color("#D7A9C4"), "state": st, "name": p.who})
	return pins


## Chỗ Bơ đứng trả đồ cho người nhờ (trước mặt người đó, trên mặt đất).
func person_spot(id: String) -> Vector3:
	var n: Nguoi = people.get(id)
	if n == null:
		return Vector3.INF
	var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, n.global_rotation.y)
	var p := n.global_position + fwd * 0.9
	p.y = 0.0
	return p


func hammock_spot() -> Vector3:
	return HAMMOCK


# ---------------------------------------------------------------- vòng chơi

func _physics_process(delta: float) -> void:
	if not _started or _ended:
		return
	if autotest:
		_bot_step()
	if ui.choosing() or ui.book_open or photo.active:
		return
	if _active:
		_active.tick(delta)
	_check_talk()
	_check_nap(delta)
	if _end_ready and not _active and _near(_end_pos(), 1.3, 0.8):
		_end_day()


func _process(delta: float) -> void:
	if not _started:
		return
	if muc_chapter_open() and not SoHangXom.muc_friend():
		var zzz: Node3D = dog.get("_zzz")  # Mực nằm buồn chứ không ngủ
		if zzz:
			zzz.visible = false
	if not is_equal_approx(_sky_t, _sky_goal):
		_sky_t = move_toward(_sky_t, _sky_goal, delta * 0.12)
		_apply_sky(_sky_t)
	if _ended or ui.choosing():
		return
	if Input.is_action_just_pressed("so_hang_xom") and not photo.active:
		ui.toggle_book()
		player.can_move = not ui.book_open
		if not autotest:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if ui.book_open else Input.MOUSE_MODE_CAPTURED
	elif Input.is_action_just_pressed("chup_anh") and not ui.book_open:
		photo.toggle()
	elif photo.active and Input.is_action_just_pressed("pause"):
		photo.close()


func _check_talk() -> void:
	var best := ""
	var best_d := TALK
	for id in _bubbles:
		if id == _active_id or SoHangXom.is_done(id) or (id == SoHangXom.MUC and not muc_chapter_open()):
			continue
		var n: Node3D = dog if id == SoHangXom.MUC else people.get(id)
		if n == null:
			continue
		var d := player.global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = id
	if best != _near_id:
		_near_id = best
		if best != "":
			var p := SoHangXom.page(best)
			ui.set_line("E: giúp %s · %s" % [p.get("who", "Chó Mực"), p.get("task", "Mực nằm buồn, cổ trống trơn")])
		else:
			ui.set_line(_active.line if _active else (IDLE_LINE if not _end_ready else "Lên bồn nước trên mái hiên cạnh lò bánh để ngắm hoàng hôn và kết ngày"))
	if best != "" and Input.is_action_just_pressed("deliver") and not _celebrating:
		_start(best)


func _start(id: String) -> void:
	if _active:
		_active.queue_free()  # đổi việc giữa chừng: việc cũ vẫn còn trong sổ, không mất gì
	_active_id = id
	_active = VIEC[id].new()
	_active.name = "Viec_" + id
	add_child(_active)
	_active.setup(self)
	_active.finished.connect(_on_finished.bind(id), CONNECT_DEFERRED)
	_active.begin()
	_near_id = "?"
	ui.set_line(_active.line)
	ui.refresh()
	_refresh_bubbles()
	var n: Nguoi = people.get(id)
	if n:
		_react(n, REACT.get(id, ["noi"])[0], 2.4, "noi")
	if id == SoHangXom.MUC:
		toast("Mực nằm buồn, cổ trống trơn. Thẻ tên của nó rơi đâu mất rồi...", 3.0)
	else:
		var p := SoHangXom.page(id)
		toast("%s nhờ: %s" % [p.who, p.task], 3.0)


func _on_finished(id: String) -> void:
	if _active:
		_active.queue_free()
	_active = null
	_active_id = ""
	_celebrating = true
	if id == SoHangXom.MUC:
		_befriend(true)
		return
	var p := SoHangXom.page(id)
	var n: Nguoi = people.get(id)
	if n:
		n.play_for("vui", 2.5)
	var shot: AnhChung = null
	if AnhChung.has(id):  # bố cục G9: Bơ vào chỗ cạnh người, máy ảnh tạm trước mặt
		shot = AnhChung.new()
		add_child(shot)
		shot.setup(id, player, people)
		_bubbles[id].visible = false
	else:
		player.play_clip(str(p.get("pose", "chup_vay")))
	get_tree().create_timer(0.9).timeout.connect(func():
		photo.snap(id)
		var r := SoHangXom.mark(id)
		var gift := ("đổi thành %s (đã có món này)" % Shop.money(r.money)) if r.money > 0 else str(p.gift_name)
		toast("Dán ảnh chung với %s vào trang %d! ♥ +1 · Quà: %s" % [p.who, p.page, gift], 3.5)
		_sfx("jingle_win")
		_sky_step()
		_refresh_bubbles()
		ui.refresh()
		if SoHangXom.hearts() == int(DoKho.v("muc_chapter_after", 3)) and not SoHangXom.muc_friend():
			get_tree().create_timer(3.6).timeout.connect(func():
				toast("Bà Sáu: \"Thằng Mực bữa nay buồn lắm, Bơ ghé cuối hẻm 42 coi nó sao nha.\"", 4.0))
			dog.play_clip("nam_buon")
		elif SoHangXom.full():
			toast("Đủ 10 trang sổ! Chủ Nhật Bơ được ngồi hàng ghế đầu Hội mèo.", 4.0)
	)
	get_tree().create_timer(2.6).timeout.connect(func():
		if shot and is_instance_valid(shot):
			shot.done()  # trả Bơ về chỗ cũ, tắt máy ảnh tạm
		if n and is_instance_valid(n) and REACT.has(id):
			_react(n, REACT[id][1], 2.0, "vui")
		player.stop_clip()
		_celebrating = false
		_near_id = "?")


## Người làm động tác G9: clip một lần thì chơi xong tự về idle, clip lặp thì chơi secs giây; chưa có clip thì fallback.
func _react(n: Nguoi, clip: String, secs: float, fallback: String) -> void:
	if n.anim and n.anim.has_animation(clip):
		if clip in Nguoi.ONE_SHOT:
			n.play_once(clip)
		else:
			n.play_for(clip, secs)
	else:
		n.play_for(fallback, secs)


## Chương Mực xong (hoặc vào ngày khi đã làm bạn từ trước): Mực đeo lại thẻ, vẫy đuôi, ăn bánh, rồi đi theo Bơ.
func _befriend(story: bool) -> void:
	dog.set_tag_visible(true)
	if not story:
		MucBan.attach(dog, player, pigeons)
		_show_end_spot()
		_celebrating = false
		return
	dog.play_clip("vay_duoi")
	player.play_clip("ngoi_goi")
	toast("Mực vẫy đuôi lần đầu tiên! Bơ chia cho nó ổ bánh Cô Ba gửi.", 3.0)
	var loaf := ViecNho.trinket(Vector3(0.24, 0.08, 0.09), Color("#E0A458"))
	add_child(loaf)
	loaf.global_position = dog.global_position + Vector3(0, 0.02, 0.45).rotated(Vector3.UP, dog.rotation.y)
	get_tree().create_timer(1.6).timeout.connect(func(): dog.play_clip("an_banh"))
	get_tree().create_timer(1.0).timeout.connect(func():
		photo.snap(SoHangXom.MUC)
		SoHangXom.mark(SoHangXom.MUC)
		_sky_step()
		_refresh_bubbles()
		ui.refresh())
	get_tree().create_timer(4.4).timeout.connect(func():
		loaf.queue_free()
		player.stop_clip()
		MucBan.attach(dog, player, pigeons)
		_show_end_spot()
		_celebrating = false
		_near_id = "?"
		toast("Mực đi theo Bơ rồi! Trang 11 dán vào cuối sổ. Muốn kết ngày thì lên bồn nước cạnh lò bánh ngắm hoàng hôn.", 4.5))


## Ngủ trên mái tôn ấm: đứng yên 1,5 s thì cuộn tròn ngủ, đủ 10 s trời ngả một nấc (một lần mỗi ngày).
func _check_nap(delta: float) -> void:
	if _napped or _active:
		return
	var on_roof := _near(ViecNho.surface(get_world_3d(), NAP_SPOT.x, NAP_SPOT.y), 0.9, 0.5)
	var still := Vector2(player.velocity.x, player.velocity.z).length() < 0.2
	if on_roof and still:
		_still += delta
		if _still > 1.5:
			if _nap == 0.0:
				player.play_clip("ngu_cuon")
				toast("Mái tôn ấm quá... Bơ cuộn tròn ngủ một giấc.", 2.5)
			_nap += delta
			if _nap >= NAP_TIME:
				_napped = true
				player.stop_clip()
				_sky_step()
				toast("Bơ thức dậy, trời đã ngả sang chiều hơn.", 2.5)
	else:
		if _nap > 0.0:
			player.stop_clip()
		_still = 0.0
		_nap = 0.0


func _sky_step() -> void:
	_steps = mini(_steps + 1, SKY_STEPS)
	_sky_goal = float(_steps) / SKY_STEPS


func _end_day() -> void:
	_ended = true
	_sky_goal = 1.0
	if hud.has_method("show_minimap"):
		hud.show_minimap(false)
	player.can_move = false
	player.play_clip("chup_nam")
	GameState.set_day("thu_moi", true, DAY)
	GameState.set_day("so_lan_choi", int(GameState.get_day("so_lan_choi", 0, DAY)) + 1, DAY)
	PlayMode.day_done(DAY)  # chơi liền các ngày: lần sau Bắt đầu là Chủ Nhật (hay Tuần mới)
	GameState.write_save()
	toast("Mèo lạ trên mái: \"Tối mai Hội mèo ở công viên nha, đây là thư mời của Bơ!\"", 3.5)
	var n := SoHangXom.hearts()
	var lines := ["♥ %d/%d trang Sổ hàng xóm" % [n, SoHangXom.PEOPLE_PAGES], "Đã làm bạn với Chó Mực: Mực sẽ đi theo Bơ",
		"Nhận thư mời Hội mèo Chủ Nhật"]
	if SoHangXom.full():
		lines.append("Đủ 10 trang: Chủ Nhật Bơ ngồi hàng ghế đầu, có huy chương \"Hàng xóm thân\"")
	else:
		lines.append("Còn %d người chưa giúp: việc vẫn nằm trong sổ cho Tuần mới" % (SoHangXom.PEOPLE_PAGES - n))
	if photo.count > 0:
		lines.append("Chụp %d ảnh tự do, ảnh mới nhất dán lên bìa sổ" % photo.count)
	print("[thu_bay] ket ngay: ", SoHangXom.done_ids(), " troi ", _steps, "/", SKY_STEPS)
	get_tree().create_timer(0.1 if autotest else 2.6).timeout.connect(func():
		_main_state("END")  # Enter chơi lại như ngày khác
		ui.show_end(lines)
		if autotest:
			_bot_finish())
	if not ui.end_closed.is_connected(_on_end_closed):
		ui.end_closed.connect(_on_end_closed)


func _on_end_closed(action: String) -> void:
	if action == "menu":
		PlayMode.back_to_menu(get_tree())
		return
	if action == "home":
		PlayMode.go_home(get_tree())
		return
	if action == "next":
		PlayMode.go_next_day(get_tree())
		return
	# Dạo tiếp: trời giữ hoàng hôn, muốn kết lại thì rời bồn nước rồi quay lại
	_ended = false
	_end_ready = false
	_main_state("PLAY")
	player.stop_clip()
	player.can_move = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().create_timer(4.0).timeout.connect(func(): _end_ready = true)


# ---------------------------------------------------------------- dựng cảnh

func _build_people() -> void:
	for id in PEOPLE:
		var spec: Dictionary = PEOPLE[id]
		var model: String = spec.get("model", id)
		if Nguoi.in_scene(get_tree(), model):
			continue
		var n := Nguoi.make(model, spec.get("idle", "viec_rieng"))
		n.position = spec.pos
		n.rotation.y = spec.yaw
		add_child(n)
		n.look_target = player
		if spec.get("seat", false):
			var h: float = Nguoi.SEAT.get(model, 0.45)
			var back := Vector3(0, 0, -0.08).rotated(Vector3.UP, spec.yaw)
			Blocks.solid_box(self, Vector3(0.36, h, 0.36), spec.pos + back + Vector3(0, h / 2.0, 0), Color("#3D7FC1"), Blocks.LAYER_PROP)
			n.add_collision(Vector3(0.5, 1.15, 0.65), Vector3(0, 0.58, 0.08))
		elif not spec.get("chair", false):
			n.add_collision(Vector3(0.5, 1.6, 0.35), Vector3(0, 0.8, 0))
		if id == "chutu":
			var stand := Blocks.collider(self, Vector3(1.7, 0.95, 0.7), Vector3(0.4, 0.475, -6.6), Blocks.LAYER_PROP)
			PhoModels.put(stand, "sap_bao", Vector3(0, -0.475, 0))
		if id == "chithu":
			# Võng và em bé (khối tạm, chờ G1): hai cọc, tấm võng, em bé quấn khăn
			for dx in [-0.9, 0.9]:
				Blocks.solid_box(self, Vector3(0.08, 1.1, 0.08), HAMMOCK + Vector3(dx, 0.55, 0), Color("#9B6A3A"), Blocks.LAYER_PROP)
			Blocks.box(self, Vector3(1.4, 0.06, 0.5), HAMMOCK + Vector3(0, 0.55, 0), Color("#E39C7A"))
			Blocks.box(self, Vector3(0.36, 0.14, 0.2), HAMMOCK + Vector3(0, 0.64, 0), Color("#FFF8EA"))
			Blocks.label(self, "Chị Thu (tạm)", spec.pos + Vector3(0, 2.0, 0), 36)
		people[id] = n
	# Người phố đã dựng sẵn: Cô Ba (residents.gd), Cô Hai, Chú Năm (hàng xóm residents.gd), Ông Bảy (ChessCorner)
	var residents: Node = main.get("residents")
	if residents and residents.get("coba"):
		people["coba"] = residents.coba
	for n in get_tree().get_nodes_in_group(Nguoi.GROUP):
		var nid: String = (n as Nguoi).id
		if nid in ["cohai", "chunam", "ongbay"] and not people.has(nid):
			people[nid] = n
	for p in SoHangXom.pages():
		_bubbles[p.id] = _bubble(people.get(p.id))
	_bubbles[SoHangXom.MUC] = _bubble(dog, 0.95)


func _bubble(who: Node3D, h := -1.0) -> BongThoai:
	var b := BongThoai.new()
	b.follow = who
	b.height = h
	b.visible = false
	add_child(b)
	return b


## Bong bóng G9: "cho" có việc nhờ, "dang" đang giúp, "xong" đã dán trang sổ.
func _refresh_bubbles() -> void:
	for id in _bubbles:
		var b: BongThoai = _bubbles[id]
		var open: bool = id != SoHangXom.MUC or muc_chapter_open()
		if not open or b.follow == null:
			b.set_state("")
		elif SoHangXom.is_done(id):
			b.set_state("xong")
		else:
			b.set_state("dang" if id == _active_id else "cho")


func _end_pos() -> Vector3:
	return ViecNho.surface(get_world_3d(), END_SPOT.x, END_SPOT.y)


## Sau chương Mực: bồn nước (khối tạm) và 2 mèo lạ trên mái hiên cạnh lò bánh.
func _show_end_spot() -> void:
	_end_ready = true
	if not _end_nodes.is_empty():
		return
	var top := _end_pos()
	var tank := CylinderMesh.new()
	tank.top_radius = 0.42
	tank.bottom_radius = 0.42
	tank.height = 0.8
	tank.radial_segments = 16
	var tn := Node3D.new()
	add_child(tn)
	Blocks.mesh(tn, tank, top + Vector3(-0.9, 0.4, -0.15), Color("#3D7FB8"))
	_end_nodes.append(tn)
	var card := ViecNho.prop("thiep_moi", false)  # thiệp Hội mèo đứng trên nắp bồn nước (G8)
	tn.add_child(card)
	card.global_position = top + Vector3(-0.9, 0.8, -0.15)
	card.rotation.y = PI * 0.75
	var letter := ViecNho.prop("thu_moi", false)  # phong bì mèo lạ ngậm tới, đặt trước chân
	tn.add_child(letter)
	letter.global_position = top + Vector3(0.55, 0.0, 0.15)
	letter.rotation.y = PI * 0.6
	var mark := ViecNho.trinket(Vector3(0.8, 0.02, 0.8), Color("#F2C14E"), "cyl")
	add_child(mark)
	mark.global_position = top
	_end_nodes.append(mark)
	for k in 2:
		var cat := _stray_cat(["mun", "gung"][k], ["mun", "xoigac"][k])
		if cat:
			add_child(cat)
			cat.global_position = top + Vector3(0.8 + k * 0.6, 0, -0.1)
			cat.rotation.y = PI * 0.75
			_end_nodes.append(cat)


## Mèo lạ: MeoNpc của luồng Chủ Nhật nếu đã có (cast "mun", "gung"), không thì model giống mèo đứng yên.
func _stray_cat(cast_id: String, breed: String) -> Node3D:
	if ResourceLoader.exists("res://scripts/meo_npc.gd"):
		var npc_script: Script = load("res://scripts/meo_npc.gd")
		if npc_script.has_method("from_cast"):
			var npc: Node3D = npc_script.from_cast(cast_id)
			if npc:
				npc.call_deferred("set_pose", "ngoi")
				return npc
	var scene := OutfitView.breed_scene(breed, "duc")
	return scene.instantiate() if scene else null


# ---------------------------------------------------------------- trời theo việc

## t 0..1: sáng → trưa → chiều → hoàng hôn, nội suy các preset AnhSang.
func _apply_sky(t: float) -> void:
	var world: WorldEnvironment = main.get_node_or_null("MoiTruong")
	var sun: DirectionalLight3D = main.get_node_or_null("MatTroi")
	var fill: DirectionalLight3D = main.get_node_or_null("AnhTroi")
	if world == null or sun == null:
		return
	var q := 1 if AnhSang.is_compat() else 0
	var f := clampf(t, 0.0, 1.0) * (SKY.size() - 1)
	var i := mini(int(f), SKY.size() - 2)
	var k := f - i
	var a: Dictionary = AnhSang.PRESETS[SKY[i]]
	var b: Dictionary = AnhSang.PRESETS[SKY[i + 1]]
	var env := world.environment
	env.ambient_light_color = (a.ambient as Color).lerp(b.ambient, k)
	env.ambient_light_energy = lerpf(a.ambient_energy[q], b.ambient_energy[q], k)
	env.tonemap_exposure = lerpf(a.exposure[q], b.exposure[q], k)
	if env.fog_enabled and a.has("fog") and b.has("fog"):
		env.fog_light_color = (a.fog as Color).lerp(b.fog, k)
		env.fog_density = lerpf(a.fog_density[q], b.fog_density[q], k)
	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		var sm := env.sky.sky_material as ProceduralSkyMaterial
		sm.sky_top_color = (a.sky_top as Color).lerp(b.sky_top, k)
		sm.sky_horizon_color = (a.sky_horizon as Color).lerp(b.sky_horizon, k)
		sm.ground_horizon_color = (a.ground_horizon as Color).lerp(b.ground_horizon, k)
		sm.ground_bottom_color = (a.ground_bottom as Color).lerp(b.ground_bottom, k)
	sun.rotation_degrees = (a.sun_rot as Vector3).lerp(b.sun_rot, k)
	sun.light_color = (a.sun_color as Color).lerp(b.sun_color, k)
	sun.light_energy = lerpf(a.sun_energy[q], b.sun_energy[q], k)
	AnhSang.sun_disc(sun, (a.sky_horizon as Color).lerp(b.sky_horizon, k))
	var rim: VienSang = main.get_node_or_null("VienSang")
	if rim:
		rim.strength = lerpf(a.rim[q] if a.has("rim") else 0.0, b.rim[q] if b.has("rim") else 0.0, k)
	if fill:
		fill.rotation_degrees = (a.fill_rot as Vector3).lerp(b.fill_rot, k)
		fill.light_color = (a.fill_color as Color).lerp(b.fill_color, k)
		fill.light_energy = lerpf(a.fill_energy[q], b.fill_energy[q], k)
	VanhPho.set_sky(get_tree(), "chieu" if t >= 0.5 else "sang")  # phông chân trời ngả theo
	# Từ chiều thì thắp đèn lồng (DenToi giống Thứ Sáu, Thứ Bảy)
	if t >= 0.6 and _lamps == null:
		_lamps = DenToi.new()
		_lamps.name = "DenToi"
		_lamps.strength = AnhSang.PRESETS.pho_hoang_hon.get("lights", 1.0)
		_lamps.add_to_group("den_toi")
		main.add_child(_lamps)
		Tiem.glow(get_tree(), _lamps.strength)


# ---------------------------------------------------------------- tiện ích

func _near(pos: Vector3, r: float, ry: float) -> bool:
	var pp := player.global_position
	return Vector2(pp.x - pos.x, pp.z - pos.z).length() < r and absf(pp.y - pos.y) < ry


func _add_action(action: String, key: Key, button: int) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	var e := InputEventKey.new()
	e.physical_keycode = key
	InputMap.action_add_event(action, e)
	if button >= 0:
		var j := InputEventJoypadButton.new()
		j.button_index = button
		InputMap.action_add_event(action, j)


## Đặt trạng thái main.gd theo tên (MENU, PLAY, END...) để không phụ thuộc thứ tự enum.
func _main_state(state_name: String) -> void:
	var states: Dictionary = main.get_script().get_script_constant_map().get("State", {})
	if states.has(state_name):
		main.set("state", states[state_name])


# ---------------------------------------------------------------- tự kiểm tra

## Bot: lần lượt giúp đủ 10 người (dịch chuyển tới từng điểm của việc), làm chương Mực, rồi kết ngày.
func _bot_step() -> void:
	_bot_frames += 1
	if _bot_frames > 60 * 240:
		print("AUTOTEST THU_BAY FAIL (quá 4 phút) · đang làm: ", _active_id, " · sổ ", SoHangXom.done_ids())
		get_tree().quit(1)
		return
	if _celebrating or _ended or _bot_frames % 6 != 0:
		return
	if _active:
		var goal := _active.bot_goal()
		var crouch := false
		for t in _active.targets:
			if not t.got:
				crouch = t.need_crouch
				break
		if crouch:
			Input.action_press("crouch")
		else:
			Input.action_release("crouch")
		if goal.is_finite():
			_teleport(goal)
		_active.bot_act()
		return
	Input.action_release("crouch")
	for p in SoHangXom.pages():
		if not SoHangXom.is_done(p.id):
			var n: Node3D = people.get(p.id)
			if n:
				_teleport(person_spot(p.id) if person_spot(p.id).is_finite() else n.global_position)
			_start(p.id)
			return
	if not SoHangXom.muc_friend():
		if not muc_chapter_open():
			print("AUTOTEST THU_BAY FAIL: chương Mực chưa mở sau ", SoHangXom.hearts(), " người")
			get_tree().quit(1)
			return
		_teleport(dog.global_position + Vector3(1.2, 0, 0))
		_start(SoHangXom.MUC)
		return
	if _end_ready:
		_teleport(_end_pos())


func _teleport(pos: Vector3) -> void:
	player.global_position = pos + Vector3(0, 0.12, 0)
	player.velocity = Vector3.ZERO


func _bot_finish() -> void:
	var ok := SoHangXom.hearts() == SoHangXom.PEOPLE_PAGES and SoHangXom.full() and SoHangXom.muc_friend()
	ok = ok and int(GameState.get_day("so_lan_choi", 0, DAY)) == 1 and int(GameState.get_day("so_lan_choi", 0, "thu_hai")) == 0
	ok = ok and (GameState.get_day("banh_mi_bo", [], DAY) as Array).size() == 3 and bool(GameState.get_day("thu_moi", false, DAY))
	ok = ok and "kinhcan" in Shop.bought() and "nonphot" in Shop.bought()
	ok = ok and _steps == SKY_STEPS and _lamps != null and dog.get_node_or_null("MucBan") != null
	ok = ok and main.get("hud").order_card.visible == false
	print("[thu_bay] so ", SoHangXom.done_ids(), " troi ", _steps, " da_mua ", Shop.bought(), " vi ", Shop.wallet())
	print("AUTOTEST THU_BAY ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


## Tiếng động qua autoload Sound (không gọi thẳng tên autoload: chạy được cả khi chụp ảnh bằng -s).
func _sfx(sound_name: String) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd:
		snd.play(sound_name)
