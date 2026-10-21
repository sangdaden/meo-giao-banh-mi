class_name BoPreview
extends SubViewportContainer
## Bơ 3D trên bục tròn trong thế giới riêng. Kéo để xoay 360° (thả tay thì quay chậm dần),
## kéo dọc để nhìn cao thấp, lăn chuột để phóng to, bấm đúp để về góc ban đầu.
## Dùng ở tủ đồ và tủ kính trang chủ; chỉnh các biến dưới đây trước khi thêm vào cây.

const PlayerScript = preload("res://scripts/player.gd")
var start_yaw := PI + 0.65
var start_pitch := 0.22
var start_dist := 2.3
var target := Vector3(0, 0.27, -0.02)
var bg_color := Color("#9CCBC1")
var show_hint := true
var vp: SubViewport
var cat: Node3D
var cam: Camera3D
var yaw: float
var pitch: float
var dist: float
var spin := 0.0
var dragging := false
var _hint: Control

func _ready() -> void:
	yaw = start_yaw
	pitch = start_pitch
	dist = start_dist
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(vp)

	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = bg_color
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#BFD3DA")
	# Cùng mức sáng với màn giao bánh (main.gd): bản web Compatibility sáng hơn nên giảm bớt
	var compat := RenderingServer.get_rendering_device() == null
	e.ambient_light_energy = 0.3 if compat else 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR if compat else Environment.TONE_MAPPER_FILMIC
	we.environment = e
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_color = Color("#FFE8C4")
	sun.light_energy = 0.6 if compat else 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 6.0
	vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -150, 0)
	fill.light_color = Color("#CFE6E0")
	fill.light_energy = 0.15 if compat else 0.25
	vp.add_child(fill)

	# Bục: mặt giấy gói bánh, viền mực bên dưới
	_disc(0.5, 0.035, -0.0175, Color("#E2CFA8"))
	_disc(0.52, 0.03, -0.04, UiTheme.INK)

	cat = PlayerScript.new()
	cat.preview = true
	vp.add_child(cat)
	cat.set_physics_process(false)
	cam = Camera3D.new()
	cam.fov = 30.0
	cam.cull_mask = 0xFFFFF & ~PlayerScript.LAYER_FP_PAWS
	vp.add_child(cam)

	_hint = PanelContainer.new()
	_hint.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.INK, 0.78), 999, 12, Color(0, 0, 0, 0), 0))
	_hint.add_child(UiTheme.label("Kéo chuột hoặc vuốt để xoay 360°", 14, UiTheme.PAPER, "bold"))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.place(_hint, 0.5, 1.0, Rect2(-150, -50, 300, 36))
	_hint.visible = show_hint
	add_child(_hint)

func _disc(r: float, h: float, y: float, color: Color) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 48
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	m.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position.y = y
	vp.add_child(mi)

## Tắt thì Bơ đứng yên và khung 3D thôi vẽ (vd tủ kính trang chủ khi tủ đồ che lên).
func set_active(on: bool) -> void:
	if cat:
		cat.set_process(on)
	set_process(on)
	if vp:
		vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE if on else SubViewport.UPDATE_DISABLED

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.double_click:
				spin = 0.0
				var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tw.tween_property(self, "yaw", start_yaw + roundf((yaw - start_yaw) / TAU) * TAU, 0.5)
				tw.tween_property(self, "pitch", start_pitch, 0.5)
				tw.tween_property(self, "dist", start_dist, 0.5)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = maxf(dist - 0.15, start_dist * 0.57)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = minf(dist + 0.15, start_dist * 1.4)
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		yaw += event.relative.x * 0.012
		pitch = clampf(pitch + event.relative.y * 0.005, -0.05, 0.75)
		spin = event.relative.x * 0.012 * 60.0
		if _hint.visible:
			var tw := create_tween()
			tw.tween_property(_hint, "modulate:a", 0.0, 0.4)
			tw.tween_callback(_hint.hide)
		accept_event()

func _process(delta: float) -> void:
	if not dragging:
		yaw += spin * delta
		spin *= exp(-3.0 * delta)
	if cat and cat.visual:
		cat.visual.rotation.y = yaw
	var dir := Vector3(0, sin(pitch), cos(pitch))
	cam.position = target + dir * dist
	cam.look_at(target)


