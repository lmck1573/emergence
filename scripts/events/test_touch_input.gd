extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch")))
	root.get_node("GameState").data = load("res://scripts/save/save_manager.gd").default_state()
	root.set_meta("act3_test", true)
	for scene_path: String in [
		"res://scenes/explore/livingroom.tscn",
		"res://scenes/explore/house_overview.tscn",
	]:
		var scene: PackedScene = load(scene_path) as PackedScene
		assert(scene != null, "Could not load " + scene_path)
		var instance: Node = scene.instantiate()
		root.add_child(instance)
		await process_frame
		instance.queue_free()
		await process_frame
	var closeup: PackedScene = load("res://scenes/explore/phase3_next_closeup.tscn") as PackedScene
	assert(closeup != null)
	print("PASS touch input scene loading and mouse emulation setting")
	quit()
