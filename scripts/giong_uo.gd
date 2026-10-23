class_name GiongUO
extends Node
## Giọng ú ớ (mã E1): nhân vật "nói" bằng tiếng líu lo kiểu Animal Crossing, mỗi âm tiết trong câu thoại
## là một tiếng ngắn. Dấu thanh tiếng Việt quyết định cao độ (sắc đi lên, huyền đi xuống, hỏi trũng, ngã gãy,
## nặng ngắn và trầm), nguyên âm quyết định âm sắc (a, e, i, o, u, ơ, ư), phụ âm đầu thêm tiếng gió/âm mũi.
## Mỗi người một giọng (cao độ, khổ giọng, tốc độ, run giọng). Toàn bộ tự tổng hợp bằng code ngay trong game,
## không có file âm thanh, không dùng mẫu bên ngoài.
##
## Dùng:  GiongUO.noi("Cô Ba", "Chào Bơ! Sáng nay có 5 đơn.")           # không vị trí
##        GiongUO.noi("Ông Bảy", "Suỵt!", ong_bay_node)                  # nhỏ dần theo khoảng cách camera
##        GiongUO.noi("meo:Bà Mướp", "Về đích!", meo)                    # mèo Hội mèo: tiếng meo meo
##        GiongUO.dung("Cô Ba")                                          # ngắt giữa chừng
## Người nói câu mới thì câu cũ của người đó dừng. Game tạm dừng thì giọng dừng theo.

const SR := 16000
const LEVEL_DB := -9.0       ## cân với tiếng hiệu ứng khác (Sound.LEVEL)
const MAX_DIST := 26.0       ## xa camera hơn thì không nghe
const MAX_SYL := 32          ## câu dài thì chỉ "nói" chừng này âm tiết đầu
const POOL := 6

## Nguyên âm: ba formant của giọng đàn ông trưởng thành (Hz). Giọng khác nhân với "form".
const VOWELS := {
	"a": [760.0, 1250.0, 2500.0], "e": [480.0, 1900.0, 2550.0], "i": [300.0, 2250.0, 3000.0],
	"o": [480.0, 860.0, 2400.0], "u": [320.0, 760.0, 2300.0], "ơ": [500.0, 1350.0, 2450.0],
	"ư": [340.0, 1350.0, 2300.0],
}
## Ký tự có dấu -> [nguyên âm, thanh]. Thanh: 0 ngang, 1 huyền, 2 sắc, 3 hỏi, 4 ngã, 5 nặng.
const _TONE_ROWS := {
	"a": "aàáảãạ", "ă": "ăằắẳẵặ", "â": "âầấẩẫậ", "e": "eèéẻẽẹ", "ê": "êềếểễệ", "i": "iìíỉĩị",
	"o": "oòóỏõọ", "ô": "ôồốổỗộ", "ơ": "ơờớởỡợ", "u": "uùúủũụ", "ư": "ưừứửữự", "y": "yỳýỷỹỵ",
}
const _VOWEL_OF := {"a": "a", "ă": "a", "â": "ơ", "e": "e", "ê": "e", "i": "i", "y": "i",
	"o": "o", "ô": "o", "ơ": "ơ", "u": "u", "ư": "ư"}

## Giọng từng người. f0: cao độ gốc (Hz) · form: khổ giọng (1 đàn ông, ~1,15 phụ nữ, ~1,3 trẻ con)
## syl: giây mỗi âm tiết · rng: độ rộng lên xuống của dấu thanh · tilt: càng lớn càng mềm/ồm
## breath: hơi gió · vib: run giọng (người già) · kind: "nguoi", "meo", "cho"
const VOICES := {
	"Cô Ba": {"f0": 235.0, "form": 1.13, "syl": 0.085, "rng": 1.0, "tilt": 0.95, "breath": 0.05},
	"Chú Tư": {"f0": 128.0, "form": 0.98, "syl": 0.088, "rng": 0.9, "tilt": 1.0, "breath": 0.06},
	"Bé Na": {"f0": 360.0, "form": 1.32, "syl": 0.068, "rng": 1.35, "tilt": 0.8, "breath": 0.04},
	"Chị Mây": {"f0": 270.0, "form": 1.18, "syl": 0.075, "rng": 1.15, "tilt": 0.85, "breath": 0.07},
	"Anh Hùng": {"f0": 145.0, "form": 1.02, "syl": 0.078, "rng": 1.0, "tilt": 0.9, "breath": 0.05},
	"Bà Sáu": {"f0": 215.0, "form": 1.08, "syl": 0.105, "rng": 0.85, "tilt": 1.15, "breath": 0.12, "vib": 0.035},
	"Ông Bảy": {"f0": 112.0, "form": 0.94, "syl": 0.1, "rng": 0.8, "tilt": 1.2, "breath": 0.1, "vib": 0.02},
	"Ông Tám": {"f0": 138.0, "form": 0.97, "syl": 0.095, "rng": 0.9, "tilt": 1.05, "breath": 0.09, "vib": 0.025},
	"Cô Hai": {"f0": 225.0, "form": 1.1, "syl": 0.09, "rng": 0.95, "tilt": 1.0, "breath": 0.06},
	"Chú Năm": {"f0": 120.0, "form": 0.96, "syl": 0.09, "rng": 0.85, "tilt": 1.05, "breath": 0.07},
	"Chị Thu": {"f0": 255.0, "form": 1.16, "syl": 0.082, "rng": 1.0, "tilt": 0.95, "breath": 0.1},
	"Bà Mướp": {"f0": 430.0, "form": 1.25, "syl": 0.11, "rng": 0.9, "tilt": 1.05, "breath": 0.08, "vib": 0.03, "kind": "meo"},
	"Chó Mực": {"f0": 150.0, "form": 0.78, "syl": 0.11, "rng": 0.7, "tilt": 0.9, "breath": 0.22, "kind": "cho"},
}
## Người không có trong bảng: lấy giọng theo cách xưng hô, rồi lệch cao độ một chút theo tên.
const BY_TITLE := {
	"Bà": {"f0": 210.0, "form": 1.07, "syl": 0.1, "rng": 0.85, "tilt": 1.1, "breath": 0.11, "vib": 0.03},
	"Ông": {"f0": 118.0, "form": 0.95, "syl": 0.098, "rng": 0.85, "tilt": 1.15, "breath": 0.09, "vib": 0.02},
	"Cô": {"f0": 230.0, "form": 1.12, "syl": 0.085, "rng": 1.0, "tilt": 0.95, "breath": 0.06},
	"Chị": {"f0": 262.0, "form": 1.17, "syl": 0.078, "rng": 1.1, "tilt": 0.9, "breath": 0.07},
	"Chú": {"f0": 125.0, "form": 0.98, "syl": 0.088, "rng": 0.9, "tilt": 1.0, "breath": 0.06},
	"Anh": {"f0": 148.0, "form": 1.02, "syl": 0.078, "rng": 1.0, "tilt": 0.9, "breath": 0.05},
	"Bé": {"f0": 350.0, "form": 1.3, "syl": 0.068, "rng": 1.3, "tilt": 0.8, "breath": 0.04},
}
const CAT_VOICE := {"f0": 560.0, "form": 1.3, "syl": 0.09, "rng": 1.2, "tilt": 0.9, "breath": 0.06, "kind": "meo"}

static var _mgr: GiongUO
static var _cache := {}  ## "giọng|nguyên âm|thanh|đầu|tắc" -> AudioStreamWAV

var _talks := {}         ## who -> {syl: Array, i: int, t: float, at: Node3D, v: Dictionary, who: String}
var _pool: Array[AudioStreamPlayer] = []


## Nhân vật who nói câu text (chữ trong bong bóng). at: node của người nói để tính xa gần, null = nghe rõ.
static func noi(who: String, text: String, at: Node3D = null) -> void:
	var m := _manager()
	if m == null:
		return
	var syl := syllables(text)
	if syl.is_empty():
		return
	m._talks[who] = {"syl": syl, "i": 0, "t": 0.0, "at": at, "v": voice(who), "who": who}


## Như noi() nhưng lấy giọng từ node người nói: Nguoi (theo id, Nguoi.NAMES) hoặc MeoNpc (theo tên).
static func noi_theo(n: Node3D, text: String) -> void:
	var who := ai(n)
	if who != "":
		noi(who, text, n)


static func ai(n: Node) -> String:
	if n == null or not is_instance_valid(n):
		return ""
	if n is MeoNpc:
		return "meo:" + (n as MeoNpc).ten
	var pid = n.get("id")
	if pid is String and pid != "":
		return Nguoi.NAMES.get(pid, pid)
	return ""


static func dung(who: String) -> void:
	if _mgr and is_instance_valid(_mgr):
		_mgr._talks.erase(who)


## Có ai đang nói không (để test).
static func dang_noi(who := "") -> bool:
	if _mgr == null or not is_instance_valid(_mgr):
		return false
	return not _mgr._talks.is_empty() if who == "" else _mgr._talks.has(who)


## Giọng của một người. "meo:<tên>" là mèo, "Chó Mực" là chó.
static func voice(who: String) -> Dictionary:
	var cat := who.begins_with("meo:")
	var name := who.substr(4) if cat else who
	if VOICES.has(name):
		return VOICES[name]
	var words := name.split(" ", false)
	if words.size() >= 2 and VOICES.has(words[0] + " " + words[1]):
		return VOICES[words[0] + " " + words[1]]
	var base: Dictionary = CAT_VOICE if cat else BY_TITLE.get(words[0] if words.size() > 0 else "", BY_TITLE["Chị"])
	var v := base.duplicate()
	var h := absi(name.hash()) % 1000 / 1000.0  # cùng tên luôn cùng giọng
	v.f0 = float(v.f0) * lerpf(0.88, 1.12, h)
	v.syl = float(v.syl) * lerpf(0.94, 1.06, fmod(h * 7.0, 1.0))
	return v


## Tách câu thành âm tiết: [{vowel, tone, onset ("" | "mui" | "gio"), stop, gap, end}].
## gap: số âm tiết lặng sau đó (dấu phẩy, chấm). end: "?" hay "!" cho âm tiết cuối câu.
static func syllables(text: String) -> Array:
	var out := []
	var word := ""
	for ch in (text + " "):
		if ch == " " or ch in ",.!?;:…\"“”()-–—\n":
			if word != "":
				var s := _syllable(word)
				if not s.is_empty():
					out.append(s)
				word = ""
			if not out.is_empty() and ch != " " and ch != "\"" and ch != "“" and ch != "”":
				var last: Dictionary = out[-1]
				if ch in ",;:-–—":
					last.gap = maxf(last.gap, 1.6)
				elif ch in ".!?…\n":
					last.gap = maxf(last.gap, 2.6)
					if ch == "?" or ch == "!":
						last.end = ch
		else:
			word += ch
		if out.size() >= MAX_SYL:
			break
	return out


static func _syllable(word: String) -> Dictionary:
	var w := word.to_lower()
	var tone := 0
	var marked := ""   # nguyên âm mang dấu thanh
	var shaped := ""   # nguyên âm có mũ/móc (ơ, ư, ê, ô, â, ă)
	var first := -1
	var lastv := -1
	for i in w.length():
		var base := _base_of(w[i])
		if base == "":
			continue
		if first < 0:
			first = i
		lastv = i
		var k: int = (_TONE_ROWS[base] as String).find(w[i])
		if k > 0:
			tone = k
			marked = _VOWEL_OF[base]
		if shaped == "" and base in ["ơ", "ư", "ê", "ô", "â", "ă"]:
			shaped = _VOWEL_OF[base]
	if first < 0:
		# Chữ số: vẫn "nói" một tiếng a
		return {"vowel": "a", "tone": 0, "onset": "", "stop": false, "gap": 0.0, "end": ""} if w.is_valid_int() else {}
	var head := w.substr(0, first)
	var tail := w.substr(lastv + 1)
	var vowel := marked if marked != "" else shaped
	if vowel == "":
		# Không dấu: bỏ âm đệm (qu, gi) và bán âm cuối (ai, ao, ui...) để lấy nguyên âm chính
		var cl := w.substr(first, lastv - first + 1)
		if cl.length() >= 2 and ((head == "q" and cl[0] == "u") or (head == "g" and cl[0] == "i")):
			cl = cl.substr(1)
		var c := cl[0]
		if cl.length() >= 2 and cl[-1] in "iuyo":
			c = cl[cl.length() - 2]
		elif cl.length() >= 2 and cl[0] in "ou" and cl[1] in "aeă":
			c = cl[1]  # hoa, khoe, thuở
		vowel = _VOWEL_OF.get(_base_of(c), "a")  # chữ lạ (tiếng Anh, viết tắt): đọc là a
	var onset := ""
	if head in ["m", "n", "ng", "ngh", "nh"]:
		onset = "mui"
	elif head in ["t", "th", "c", "k", "kh", "ch", "tr", "p", "ph", "s", "x", "h", "q"]:
		onset = "gio"
	var stop := tail in ["p", "t", "c", "ch"]
	return {"vowel": vowel, "tone": tone, "onset": onset, "stop": stop, "gap": 0.0, "end": ""}


static func _base_of(c: String) -> String:
	for base: String in _TONE_ROWS:
		if (_TONE_ROWS[base] as String).find(c) >= 0:
			return base
	return ""


static func _manager() -> GiongUO:
	if _mgr and is_instance_valid(_mgr):
		return _mgr
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	_mgr = GiongUO.new()
	_mgr.name = "GiongUO"
	tree.root.add_child.call_deferred(_mgr)
	return _mgr


func _ready() -> void:
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		add_child(p)
		_pool.append(p)


func _process(delta: float) -> void:
	for who in _talks.keys():
		var tk: Dictionary = _talks[who]
		if tk.at != null and not is_instance_valid(tk.at):
			_talks.erase(who)
			continue
		tk.t -= delta
		if tk.t > 0.0:
			continue
		var s: Dictionary = tk.syl[tk.i]
		var v: Dictionary = tk.v
		_say_one(tk, s, v)
		tk.i += 1
		tk.t += float(v.syl) * ((0.72 if s.stop else 1.0) + 0.18 + float(s.gap))
		if tk.i >= tk.syl.size():
			_talks.erase(who)
	_warm()


## Mỗi khung tạo trước tối đa một tiếng sắp nói (bản web tạo tiếng chậm hơn, rải ra cho khỏi giật).
func _warm() -> void:
	for tk: Dictionary in _talks.values():
		for j in range(tk.i, mini(tk.i + 8, tk.syl.size())):
			var s: Dictionary = tk.syl[j]
			if not _cache.has(_key(tk.who, s)):
				blip(tk.who, tk.v, s)
				return


func _say_one(tk: Dictionary, s: Dictionary, v: Dictionary) -> void:
	var db := LEVEL_DB
	if tk.at != null:
		var cam := get_viewport().get_camera_3d()
		var d := cam.global_position.distance_to((tk.at as Node3D).global_position) if cam else 0.0
		if d > MAX_DIST:
			return
		db += -20.0 * log(maxf(d, 4.0) / 4.0) / log(10.0)
	var p := _pool[0]
	for q in _pool:
		if not q.playing:
			p = q
			break
	p.stream = blip(tk.who, v, s)
	p.volume_db = db
	p.pitch_scale = 1.0
	p.play()


## Một tiếng ứng với một âm tiết. Có bộ nhớ đệm theo giọng + âm tiết.
static func blip(who: String, v: Dictionary, s: Dictionary) -> AudioStreamWAV:
	var key := _key(who, s)
	if _cache.has(key):
		return _cache[key]
	var wav := render(v, s, absi(key.hash()))
	_cache[key] = wav
	return wav


static func _key(who: String, s: Dictionary) -> String:
	return "%s|%s|%d|%s|%s|%s" % [who, s.vowel, s.tone, s.onset, s.stop, s.end]


## Cao độ (tỉ lệ so với f0) ở thời điểm x (0..1) của âm tiết, theo dấu thanh.
static func contour(tone: int, x: float, rng: float, end: String) -> float:
	var c := 0.0
	match tone:
		0: c = -0.03 * x
		1: c = -0.06 - 0.12 * x
		2: c = 0.02 + 0.26 * x * x
		3: c = -0.04 - 0.2 * sin(x * PI) + 0.08 * x
		4: c = 0.0 - 0.14 * sin(minf(x / 0.5, 1.0) * PI * 0.5) + (0.38 * (x - 0.5) / 0.5 if x > 0.5 else 0.0)
		5: c = -0.08 - 0.18 * x
	if end == "?":
		c += 0.22 * x
	elif end == "!":
		c += 0.08
	return 1.0 + c * rng


## Cả câu thành một file (cho trang nghe thử và test): ghép các tiếng đúng nhịp như lúc chơi.
static func line_wav(who: String, text: String) -> AudioStreamWAV:
	var v := voice(who)
	var mix := PackedFloat32Array()
	var t := 0.0
	for s: Dictionary in syllables(text):
		var b := blip(who, v, s)
		var start := int(t * SR)
		var n := b.data.size() / 2
		if mix.size() < start + n:
			mix.resize(start + n)
		for i in n:
			mix[start + i] += b.data.decode_s16(i * 2) / 32767.0
		t += float(v.syl) * ((0.72 if s.stop else 1.0) + 0.18 + float(s.gap))
	var data := PackedByteArray()
	data.resize(mix.size() * 2)
	for i in mix.size():
		data.encode_s16(i * 2, int(clampf(mix[i] * 0.8, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.data = data
	return wav


## Tổng hợp cộng hài: nguồn thanh môn (các họa âm f0, f0*2...) nhân bao formant của nguyên âm,
## cộng hơi gió, phụ âm đầu (gió hoặc âm mũi), bao biên độ mượt. Ra AudioStreamWAV 16-bit mono 16 kHz.
static func render(v: Dictionary, s: Dictionary, seed_value := 1) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var kind: String = v.get("kind", "nguoi")
	var tone: int = s.tone
	var dur: float = float(v.syl) * (0.7 if s.stop else 1.0) * (0.78 if tone == 5 else 1.0) * (1.12 if tone in [3, 4] else 1.0)
	if kind == "meo":
		dur *= 1.25
	var n := int(dur * SR)
	var f0: float = float(v.f0) * rng.randf_range(0.97, 1.03)
	var form: float = v.form
	var fv: Array = VOWELS[s.vowel]
	var vib: float = v.get("vib", 0.0)
	var breath: float = v.breath
	var tilt: float = v.tilt
	var onset_n := int((0.016 if s.onset == "mui" else 0.011) * SR) if s.onset != "" else 0
	if kind == "meo":
		onset_n = int(0.03 * SR)  # tiếng "m" đầu của meo
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	var lp := 0.0
	var noise := seed_value & 0x7fffffff
	var amps := PackedFloat32Array()
	var peak := 0.0
	for i in n:
		var x := float(i) / n
		var t := float(i) / SR
		var f := f0 * contour(tone, x, float(v.rng), s.end)
		if vib > 0.0:
			f *= 1.0 + vib * sin(TAU * 5.5 * t)
		if kind == "cho":
			f *= 1.0 + rng.randf_range(-0.05, 0.05)
		phase = fmod(phase + TAU * f / SR, TAU)
		# Bao formant đổi theo f0 nên tính lại mỗi 64 mẫu
		if i % 64 == 0:
			var open := 1.0
			if onset_n > 0 and (s.onset == "mui" or kind == "meo"):
				open = clampf(float(i) / onset_n, 0.0, 1.0)
			amps = _harmonic_amps(f, fv, form, tilt, open, kind)
		# sin(k·φ) bằng truy hồi Chebyshev: s_k = 2cos(φ)·s_(k-1) − s_(k-2)
		var c2 := 2.0 * cos(phase)
		var sk1 := sin(phase)
		var sk2 := 0.0
		var y := 0.0
		for k in amps.size():
			y += amps[k] * sk1
			var nx := c2 * sk1 - sk2
			sk2 = sk1
			sk1 = nx
		# Hơi gió: nhiễu lọc thông thấp một cực
		noise = (noise * 1103515245 + 12345) & 0x7fffffff
		var nz := noise / 1073741823.5 - 1.0
		lp += (nz - lp) * 0.35
		y += lp * breath
		# Phụ âm đầu "gió" (t, ch, s, h...): tiếng xì ngắn trước nguyên âm, nguyên âm vào sau
		var env := 1.0
		if s.onset == "gio" and i < onset_n:
			y = (nz - lp) * 0.45 * (1.0 - float(i) / onset_n)
		elif s.onset == "gio":
			env *= clampf(float(i - onset_n) / (0.008 * SR), 0.0, 1.0)
		var att := clampf(t / 0.008, 0.0, 1.0)
		var rel := clampf((1.0 - x) / 0.35, 0.0, 1.0)
		env *= att * (0.5 - 0.5 * cos(rel * PI))
		if tone == 4:
			env *= 1.0 - 0.65 * exp(-pow((x - 0.48) / 0.07, 2.0))  # ngã: gãy giữa chừng
		y *= env
		buf[i] = y
		peak = maxf(peak, absf(y))
	var data := PackedByteArray()
	data.resize(n * 2)
	var g := 0.85 / maxf(peak, 0.0001)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i] * g, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.stereo = false
	wav.data = data
	return wav


## Biên độ từng họa âm: nghiêng phổ (tilt) nhân tổng ba đỉnh formant. open < 1: còn ngậm miệng (âm mũi).
static func _harmonic_amps(f: float, fv: Array, form: float, tilt: float, open: float, kind: String) -> PackedFloat32Array:
	var top := 4200.0 if kind != "cho" else 2600.0
	var count := clampi(int(top / f), 1, 16)
	var out := PackedFloat32Array()
	out.resize(count)
	var f1: float = lerpf(260.0, fv[0], open) * form
	var f2: float = lerpf(1100.0 if kind == "meo" else 1500.0, fv[1], open) * form
	var f3: float = float(fv[2]) * form
	var g2 := lerpf(0.25, 0.75, open)
	for k in count:
		var hf := f * (k + 1)
		var e := exp(-pow((hf - f1) / (110.0 * form), 2.0)) + g2 * exp(-pow((hf - f2) / (170.0 * form), 2.0)) \
			+ 0.3 * exp(-pow((hf - f3) / (260.0 * form), 2.0)) + 0.04
		out[k] = e * pow(k + 1, -tilt)
	return out
