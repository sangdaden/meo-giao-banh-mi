extends Node
## Âm thanh toàn game (autoload tên "Sound", khai báo trong project.godot).
## Ba bus con của Master: Music (nhạc nền), SFX (hiệu ứng), Ambience (tiếng nền phố, bếp).
## Gọi từ bất cứ đâu:
##   Sound.play("jump")                 phát một hiệu ứng (tên file trong assets/audio/, bỏ đuôi)
##   Sound.play("step")                 tên có nhiều biến thể (step_1..step_4) thì chọn ngẫu nhiên
##   Sound.music("delivery")            đổi nhạc nền, chuyển mượt; Sound.music("") để tắt
##   Sound.ambience("street")           đổi tiếng nền
##   Sound.loop("sizzle") / Sound.stop_loop("sizzle")   tiếng lặp ngắn trong bếp
##   Sound.set_volume("Music", 0.5)     âm lượng 0..1, tự lưu vào user://am_thanh.cfg
## Tên không có file thì bỏ qua, chỉ cảnh báo một lần, nên gọi trước khi có file cũng không sao.
## Mọi file do tools/sound/synth.py tự tạo ra, xem assets/audio/NGUON.md.

const DIR := "res://assets/audio/"
const BUSES := ["Music", "SFX", "Ambience"]
const SETTINGS_PATH := "user://am_thanh.cfg"
const SoundPanel := preload("res://scripts/sound_panel.gd")

## Cân tiếng to nhỏ với nhau (dB). Tiếng không có trong bảng là 0 dB.
const LEVEL := {
	"step": -17.0, "jump": -9.0, "land": -11.0, "meow": -6.0, "meow_short": -8.0,
	"pickup": -4.0, "deliver": -3.0, "star": -6.0, "fail": -6.0,
	"tick": -7.0, "tick_urgent": -5.0,
	"bark": -2.0, "bark_single": -2.0, "growl": -4.0, "bite": -2.0,
	"ui_click": -10.0, "ui_start": -5.0,
	"knead": -6.0, "chop": -6.0, "crunch": -4.0, "sauce": -6.0, "wrap": -8.0,
	"burn": -5.0, "water": -7.0, "spray": -9.0,
	"snore": -10.0, "sniff": -8.0, "tag_jingle": -12.0, "sneak": -22.0,
	"moto_pass": -4.0, "moto_idle": -12.0, "horn": -8.0,
	"basket_lower": -6.0, "basket_drop": -5.0, "glass_rattle": -7.0, "glass_tip": -4.0, "oil_slip": -5.0,
	"oven_open": -5.0, "oven_ding": -6.0, "sizzle": -10.0, "oven_fire": -10.0,
	"jingle_win": -3.0, "jingle_lose": -3.0,
	# Thứ Hai lượt 2: mặt đất, sự kiện, giọng người
	"step_metal": -14.0, "step_wood": -16.0, "step_grass": -19.0,
	"splash": -5.0, "stamp": -4.0, "coin": -7.0, "record": -5.0, "bike_hit": -3.0,
	"meow_startle": -5.0, "squish": -5.0, "paper_slip": -8.0,
	"coba_hello": -5.0, "coba_order": -6.0, "coba_good": -5.0, "coba_ok": -5.0, "thanks": -7.0,
	# Thứ Ba: chợ, góc cờ, tạp hóa
	"scale_clank": -8.0, "chess_slap": -3.0, "chess_rattle": -3.0, "shush": -6.0, "scold": -5.0,
	"check_cheer": -4.0, "egg_crack": -2.0, "nylon": -14.0, "cart_rattle": -8.0, "cart_bump": -4.0,
	"basket_topple": -3.0, "oops": -8.0,
}
## Tiếng có nhiều bản: play("step") chọn ngẫu nhiên step_1..step_4, đổi cao độ nhẹ cho đỡ lặp.
const VARIANTS := {"step": 4, "knead": 3, "chop": 3, "sneak": 3, "moto_pass": 2,
	"step_metal": 3, "step_wood": 3, "step_grass": 3, "coba_order": 3,
	"chess_slap": 3, "nylon": 3, "scold": 4, "oops": 2}
## Cùng một tiếng gọi hai lần sát nhau (hai script cùng bắt một sự kiện) thì chỉ phát một lần.
const REPEAT_GAP_MS := 60
const SFX_VOICES := 16
const FADE := 1.2

var volumes := {"Master": 0.8, "Music": 0.55, "SFX": 0.85, "Ambience": 0.6}
var muted := false

var _cache := {}
var _warned := {}
var _pool: Array[AudioStreamPlayer] = []
var _ui: AudioStreamPlayer
var _music: Array[AudioStreamPlayer] = []  # hai máy phát để chuyển nhạc mượt
var _music_name := ""
var _amb: Array[AudioStreamPlayer] = []
var _amb_name := ""
var _loops := {}
var _tweens := {}
var _sfx_root: Node
var _panel: CanvasLayer
var _last_start := {}
var _debug := "--sound-log" in OS.get_cmdline_user_args()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # nhạc và bảng âm lượng vẫn chạy khi tạm dừng
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	# Hiệu ứng trong lúc chơi dừng theo game khi bấm Esc
	_sfx_root = Node.new()
	_sfx_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_sfx_root)
	for i in SFX_VOICES:
		_pool.append(_player(_sfx_root, "SFX"))
	_ui = _player(self, "SFX")
	for i in 2:
		_music.append(_player(self, "Music"))
		_amb.append(_player(self, "Ambience"))
	_load_settings()
	_panel = SoundPanel.new()
	add_child(_panel)


## Tắt hết khi thoát game để Godot không báo rò bộ nhớ lúc đóng.
func _exit_tree() -> void:
	for p in find_children("*", "AudioStreamPlayer", true, false):
		p.stop()
		p.stream = null
	_cache.clear()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		set_muted(not muted)
		_panel.flash("Đã tắt tiếng (M)" if muted else "Đã bật tiếng (M)")


# ---------------------------------------------------------------- phát

## Phát một hiệu ứng. volume_db cộng thêm vào mức trong bảng LEVEL.
func play(sound_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_start.get(sound_name, -REPEAT_GAP_MS)) < REPEAT_GAP_MS:
		return
	_last_start[sound_name] = now
	var file := sound_name
	if VARIANTS.has(sound_name):
		file = "%s_%d" % [sound_name, randi_range(1, VARIANTS[sound_name])]
		pitch *= randf_range(0.92, 1.08)
	var stream := _stream(file)
	if stream == null:
		return
	var p := _free_voice()
	p.stream = stream
	p.volume_db = _level(sound_name) + volume_db
	p.pitch_scale = pitch
	p.play()
	if OS.is_debug_build() and _debug: print("[sfx] ", file)


## Hiệu ứng giao diện: vẫn phát khi game đang tạm dừng.
## Phát tiếng có vị trí trong thế giới 3D: càng xa camera càng nhỏ, quá max_dist thì không phát.
## Âm lượng tính một lần lúc bắt đầu (bản web không đổi được âm lượng khi đang phát),
## nên hợp với tiếng ngắn như sủa, còi, xe chạy ngang.
func play_at(sound_name: String, pos: Vector3, max_dist := 30.0, volume_db := 0.0, pitch := 1.0) -> void:
	var cam := get_viewport().get_camera_3d()
	var d := cam.global_position.distance_to(pos) if cam else 0.0
	if d > max_dist:
		return
	# Giảm 6 dB mỗi khi khoảng cách gấp đôi, tính từ 3 m; gần mép max_dist thì nhỏ dần về 0
	var atten := -20.0 * log(maxf(d, 3.0) / 3.0) / log(10.0)
	var edge := clampf((max_dist - d) / (max_dist * 0.25), 0.0, 1.0)
	play(sound_name, volume_db + atten + linear_to_db(maxf(edge, 0.001)), pitch)


func play_ui(sound_name := "ui_click") -> void:
	var stream := _stream(sound_name)
	if stream:
		_ui.stream = stream
		_ui.volume_db = _level(sound_name)
		_ui.play()


## Đổi nhạc nền: "menu", "delivery", "chase", "kitchen", hoặc "" để tắt dần.
## Nhạc phát lặp; tên jingle_* thì phát một lần.
func music(track: String, fade := FADE) -> void:
	if track == _music_name:
		return
	_music_name = track
	_crossfade(_music, "music_" + track if track != "" and not track.begins_with("jingle") else track, fade)


func ambience(track: String, fade := 2.0) -> void:
	if track == _amb_name:
		return
	_amb_name = track
	_crossfade(_amb, "amb_" + track if track != "" else "", fade)


## Tiếng lặp ngắn (xèo chảo, lửa lò). Gọi nhiều lần không sao.
func loop(sound_name: String, volume_db := 0.0) -> void:
	if _loops.has(sound_name):
		return
	var stream := _stream(sound_name, true)
	if stream == null:
		return
	var p := _player(_sfx_root, "SFX")
	p.stream = stream
	p.volume_db = _level(sound_name) + volume_db
	p.play()
	_loops[sound_name] = p


func stop_loop(sound_name: String, fade := 0.3) -> void:
	var p: AudioStreamPlayer = _loops.get(sound_name)
	if p == null:
		return
	_loops.erase(sound_name)
	var tw := p.create_tween()
	tw.tween_property(p, "volume_db", -60.0, fade)
	tw.tween_callback(p.queue_free)


func stop_all_loops() -> void:
	for n in _loops.keys():
		stop_loop(n)


# ---------------------------------------------------------------- âm lượng

func get_volume(bus: String) -> float:
	return volumes.get(bus, 1.0)


func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func set_muted(on: bool) -> void:
	muted = on
	_apply_volumes()
	_save_settings()


func _apply_volumes() -> void:
	for bus in volumes:
		var i := AudioServer.get_bus_index(bus)
		if i == -1:
			continue
		var v: float = volumes[bus]
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v * v, 0.0001)))  # bình phương: thanh trượt nghe đều tai hơn
		AudioServer.set_bus_mute(i, v <= 0.001 or (muted and bus == "Master"))


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for bus in volumes:
			volumes[bus] = float(cfg.get_value("volume", bus, volumes[bus]))
		muted = bool(cfg.get_value("volume", "muted", false))
	_apply_volumes()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus in volumes:
		cfg.set_value("volume", bus, volumes[bus])
	cfg.set_value("volume", "muted", muted)
	cfg.save(SETTINGS_PATH)


# ---------------------------------------------------------------- bên trong

func _player(parent: Node, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	parent.add_child(p)
	return p


func _free_voice() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	# Hết máy rảnh: lấy máy đã phát lâu nhất
	var oldest := _pool[0]
	for p in _pool:
		if p.get_playback_position() > oldest.get_playback_position():
			oldest = p
	return oldest


func _level(sound_name: String) -> float:
	if LEVEL.has(sound_name):
		return LEVEL[sound_name]
	for k in LEVEL:
		if sound_name.begins_with(k):
			return LEVEL[k]
	return 0.0


func _stream(file: String, looping := false) -> AudioStream:
	if _cache.has(file):
		return _cache[file]
	var stream: AudioStream = null
	for ext in [".wav", ".ogg"]:
		if ResourceLoader.exists(DIR + file + ext):
			stream = load(DIR + file + ext)
			break
	if stream == null:
		if not _warned.has(file):
			_warned[file] = true
			push_warning("Sound: chưa có file âm thanh '%s'" % file)
		return null
	if looping or file.begins_with("music_") or file.begins_with("amb_") or file in ["sizzle", "oven_fire", "snore", "moto_idle", "cart_rattle"]:
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_cache[file] = stream
	return stream


func _crossfade(pair: Array[AudioStreamPlayer], file: String, fade: float) -> void:
	var old := pair[0]
	var new := pair[1]
	pair.reverse()
	# Bản web phát kiểu "sample": đổi volume_db lúc đang phát không có tác dụng,
	# nên không chuyển mượt mà dừng/phát thẳng ở đúng mức.
	if OS.has_feature("web"):
		fade = 0.0
	if old.playing:
		if fade <= 0.0:
			old.stop()
		else:
			var tw := _fresh_tween(old)
			tw.tween_property(old, "volume_db", -60.0, fade)
			tw.tween_callback(old.stop)
	var stream := _stream(file) if file != "" else null
	if stream == null:
		return
	new.stream = stream
	new.volume_db = _level(file) if fade <= 0.0 else -40.0
	new.play()
	if OS.is_debug_build() and _debug: print("[music] ", file)
	if fade > 0.0:
		_fresh_tween(new).tween_property(new, "volume_db", _level(file), fade * 0.6)


## Mỗi máy phát chỉ một tween, để đổi nhạc qua lại nhanh không bị tween cũ tắt nhầm.
func _fresh_tween(p: AudioStreamPlayer) -> Tween:
	var old: Tween = _tweens.get(p)
	if old and old.is_valid():
		old.kill()
	var tw := create_tween()
	_tweens[p] = tw
	return tw
