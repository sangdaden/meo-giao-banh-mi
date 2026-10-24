extends SceneTree
## Rà ngày mưa (Thứ Tư): in mọi người dân có xương và con vật đứng ngoài trời không mái che,
## kèm đồ đang mặc (áo mưa *_mua) và đồ đang cầm (dù). Dùng để soát logic ngày mưa.
## Chạy: godot --headless --path . -s tools/soat_mua.gd [-- --ngay=thu_tu]

var day := "thu_tu"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ngay="):
			day = a.substr(7)
	PlayMode.day = day
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 40:
		await physics_frame
	var main: Node = current_scene
	var space: PhysicsDirectSpaceState3D = (main as Node3D).get_world_3d().direct_space_state
	var seen := {}
	for group in [Nguoi.GROUP, "con_vat", "nguoi_qua_duong"]:
		for n in get_nodes_in_group(group):
			if not n is Node3D or seen.has(n):
				continue
			seen[n] = true
			var p: Vector3 = (n as Node3D).global_position
			var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.9, 0), p + Vector3(0, 20, 0), 0xFFFFFFFF)
			var hit: Dictionary = space.intersect_ray(q)
			var what := String(n.get("model_id")) if n.get("model_id") else String(n.get("id")) if n.get("id") != null else String(n.name)
			var held := []
			for c in (n as Node).find_children("*", "Node3D", true, false):
				if String(c.name).contains("du") or String(c.scene_file_path).contains("du_"):
					held.append(String(c.scene_file_path).get_file())
			print(("" if (n as Node3D).is_visible_in_tree() else "an ") + "%s\t%-22s\t%s\t%s\t%s\t%s" % ["CHE" if not hit.is_empty() else "TROI", what, group,
				str(p.snapped(Vector3(0.1, 0.1, 0.1))), (n as Node).get_parent().name, ",".join(held)])
	quit()
