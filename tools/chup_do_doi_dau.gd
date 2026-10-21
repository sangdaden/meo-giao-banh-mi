extends SceneTree
## Soát đồ đội đầu trên mọi giống: mỗi giống × mỗi món một ảnh cận đầu (góc 3/4 trước).
## Ảnh ra: <thư_mục>/<giống>__<món>.png
##   godot --path . -s tools/chup_do_doi_dau.gd -- <thư_mục_ra> [giống,..|all] [món,..|all] [món_mặt|""] [cai]

## Đeo kèm một món mặt nếu truyền tham số thứ 4 (vd. riamep) để xem đồ đầu và đồ mặt cùng lúc
var FACE := ""
## "cai" để chụp mèo cái (tham số thứ 5)
var SEX := ""


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var breeds: Array = ["bo"]
	for g in OutfitView.meta().get("giong", {}):
		if g.ends_with("_duc"):
			breeds.append(g.trim_suffix("_duc"))
	if args.size() > 1 and args[1] != "all":
		breeds = Array(args[1].split(","))
	var items: Array = []
	for a in Outfit.ACCS:
		if a[3] == "head":
			items.append(a[0])
	if args.size() > 2 and args[2] != "all":
		items = Array(args[2].split(","))
	if args.size() > 3:
		FACE = args[3]
	if args.size() > 4:
		SEX = args[4]
	var p := BoPreview.new()
	p.show_hint = false
	p.size = Vector2(360, 360)
	root.add_child(p)
	await process_frame
	var c = p.cat
	c.set_process(false)
	p.set_process(false)
	for b in breeds:
		for id in items:
			var worn := {"head": id, "face": FACE}
			if SEX != "":
				c.set_breed.callv([b, worn, SEX])  # set_breed(id, worn, sex) có từ PR Tủ đồ Đực / Cái
			else:
				c.set_breed(b, worn)
			for i in 30:
				c._animate(1.0 / 60.0, 0.0, 0.0, true)
			c.visual.rotation.y = PI - 0.6
			var t := Vector3(0, 0.42, 0.05)
			p.cam.position = t + Vector3(0, 0.25, 1.0).normalized() * 1.0
			p.cam.look_at(t)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			p.vp.get_texture().get_image().save_png(out.path_join("%s%s__%s.png" % [b, "_" + SEX if SEX != "" else "", id]))
	print("đã chụp ", out)
	quit()
