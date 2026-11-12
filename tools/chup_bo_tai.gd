extends SceneTree
## PH3: chụp Bơ chạy nhanh nhìn ngang, nền trong suốt, 8 khung một nhịp chân, cho thanh tải của vỏ trang web
## (web/vo_trang.html). Dùng đúng model bo.glb (dựng trong Blender) và động tác chạy trong game.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/chup_bo_tai.gd -- <thư_mục_ra>
##   python3 tools/web/lam_bo_tai.py <thư_mục_ra>     (ghép 8 khung thành dải webp, nhúng vào web/vo_trang.html)
## Ảnh ra: <thư_mục>/bo_chay_<0..7>.png (để ngoài thư mục project).

const FRAMES := 8
const SPEED := 5.5


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var p := BoPreview.new()
	p.show_hint = false
	p.size = Vector2(320, 240)
	root.add_child(p)
	await process_frame
	p.vp.transparent_bg = true
	for n in p.vp.get_children():
		if n is WorldEnvironment:
			n.environment.background_mode = Environment.BG_CLEAR_COLOR
		elif n is MeshInstance3D:
			n.visible = false  # bục tròn
		elif n is DirectionalLight3D:
			n.shadow_enabled = false
	var c = p.cat
	c.set_process(false)
	p.set_process(false)
	c.preview = false
	c.stance = "walk"
	for i in 240:
		c._animate(1.0 / 60.0, SPEED, 0.0, true)
	# Bắt đầu nhịp ở lúc pha chân về 0, chụp đều 8 khung trong một vòng 2π
	var start: float = c._phase
	var step := TAU / FRAMES
	c.visual.rotation.y = -PI * 0.5
	p.cam.position = p.target + Vector3(0, 0.05, 2.1)
	p.cam.look_at(p.target)
	for k in FRAMES:
		var want := start + step * k
		var guard := 0
		while c._phase < want and guard < 400:
			c._animate(1.0 / 240.0, SPEED, 0.0, true)
			guard += 1
		c.visual.rotation.y = -PI * 0.5
		c.visual.position = Vector3.ZERO
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		p.vp.get_texture().get_image().save_png(out.path_join("bo_chay_%d.png" % k))
	print("đã chụp ", FRAMES, " khung vào ", out)
	quit()
