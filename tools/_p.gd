extends SceneTree
func _initialize():
	PlayMode.day = OS.get_cmdline_user_args()[0]
	_run.call_deferred()
func _run():
	change_scene_to_file("res://scenes/main.tscn")
	for i in 90: await process_frame
	var best := 0
	for i in 30:
		await process_frame
		best = maxi(best, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	print("TRIS ", PlayMode.day, " ", best, " draw ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	quit()
