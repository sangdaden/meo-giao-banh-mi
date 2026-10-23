extends SceneTree
## Chào mào trong lồng (K3, K4) trên phố thật:
## - K3: lồng treo theo hợp đồng ConVat; Bơ gọi (Q) gần lồng thì chim hót đáp (clip hot), lần đầu ghi bạn bốn chân,
##   hót đối đủ ChaoMao.PRAISE_AFTER lần thì chủ lồng khen; gọi xa quá thì chim không hót.
## - K4: phố có lồng long_chim ban công (NhaRap.bird_cages); ChaoMao.balconies đặt chim vào DoKho "chim_ban_cong"
##   lồng, mỗi lồng cách nhau hơn 10 m.
## Chạy: godot --headless --path . -s tests/test_chao_mao.gd

var world: Node3D
var fails := 0


func _init() -> void:
	DoKho.force = -1
	GameState.save_path = "user://test_chao_mao.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	_run.call_deferred()


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	City.build(world)
	await process_frame
	await _hang()
	await _balconies()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	print("CHAO MAO TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


func _hang() -> void:
	var praised := [0]
	var hook := Vector3(-20.0, 2.45, 30.0)
	var c := ChaoMao.hang(world, hook, false, PI / 2.0)
	c.praise = func(): praised[0] += 1
	await process_frame
	_check(c.is_in_group("con_vat") and c.has_method("on_called"), "lồng chào mào theo hợp đồng ConVat")
	_check(c.bird != null and c.bird.position.y < 0.0, "chim đậu trong lồng, dưới móc treo")
	var ground := Vector3(hook.x + 1.0, 0.0, hook.z)
	_check(ConVat.call_near(self, ground + Vector3(8.0, 0, 0)) == 0 and c.sings == 0, "gọi cách lồng 9 m thì chim không hót")
	_check(not ConVat.met("chao_mao"), "chưa gặp chào mào")
	ConVat.call_near(self, ground)
	_check(c.sings == 1 and c.anim.current_animation == "hot", "Bơ kêu meo dưới lồng thì chim hót đáp (clip hot)")
	_check(ConVat.met("chao_mao"), "lần đầu hót đáp thì ghi bạn bốn chân chào mào")
	c.sing()
	_check(c.sings == 1, "đang hót thì không hót chồng")
	for i in ChaoMao.PRAISE_AFTER - 1:
		await _seconds(ChaoMao.SING_TIME + 0.1)
		c.on_called(ground)
	_check(c.sings == ChaoMao.PRAISE_AFTER and praised[0] == 1, "hót đối %d lần thì chủ lồng khen" % ChaoMao.PRAISE_AFTER)
	await _seconds(ChaoMao.SING_TIME + 0.1)
	_check(c.anim.current_animation != "hot", "hót xong về động tác đứng chơi")
	c.queue_free()


func _balconies() -> void:
	var n := NhaRap.bird_cages.size()
	_check(n >= 3, "phố có lồng chim ban công để đặt chim (%d lồng)" % n)
	var birds := ChaoMao.balconies(world)
	_check(birds.size() == mini(3, n), "Thong thả: chim vào %d lồng ban công" % birds.size())
	for i in birds.size():
		var b: ChaoMao = birds[i]
		_check(b.nhe and b.global_position.y > 1.5, "chim ban công %d dùng bản nhẹ, ở trên cao (y %.1f)" % [i, b.global_position.y])
		for j in i:
			_check(b.global_position.distance_to(birds[j].global_position) > 10.0, "chim ban công %d và %d cách nhau hơn 10 m" % [j, i])
	for b in birds:
		b.queue_free()
	DoKho.force = 1
	birds = ChaoMao.balconies(world)
	_check(birds.size() == mini(int(DoKho.v("chim_ban_cong", 3)), n), "Thử thách vẫn có chim ban công")
	DoKho.force = -1


func _seconds(s: float) -> void:
	await create_timer(s).timeout


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1
