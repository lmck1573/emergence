extends SceneTree
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	set_meta("act3_test", true)
	var state: Node = root.get_node("GameState")
	state.data = load("res://scripts/save/save_manager.gd").default_state()
	state.data["phase"] = 2
	state.data["current_scene"] = "computer_desk"
	state.data["events_completed"] = ["event_computer_unlocked"]
	change_scene_to_file("res://scenes/explore/computer_locked.tscn")
	for index: int in range(6): await process_frame
	assert(current_scene.get_node("LockedEntry").visible, "Password marker missing")
	assert(current_scene.get_node("LockedEntry").input_pickable, "Password marker disabled")
	assert(not current_scene.has_node("PowerButton"))
	for key: String in ["LockedDrawer", "Notebooks", "balcony_lounger"]:
		assert(current_scene.get_node(key).visible, "Other point missing: " + key)
		assert(current_scene.get_node(key).input_pickable)
	state.data["puzzles"]["puzzle_diary_password"] = {"unlocked": true, "completed": true}
	current_scene.call("refresh_computer_picture")
	for index: int in range(8): await process_frame
	assert(current_scene.scene_file_path.ends_with("computer_unlocked.tscn"))
	for key: String in ["FolderGames", "FolderSocial", "FolderBills"]:
		assert(current_scene.get_node(key).visible)
		assert(current_scene.get_node(key).input_pickable)
	assert(not current_scene.has_node("LockedEntry"))
	for key: String in ["LockedDrawer", "Notebooks", "balcony_lounger"]:
		assert(current_scene.get_node(key).visible, "Other point missing: " + key)
		assert(current_scene.get_node(key).input_pickable)
	var old: Node = current_scene
	root.remove_child(old)
	old.call("refresh_computer_picture")
	old.queue_free()
	print("PASS computer markers, unlock scene transition, detached refresh")
	quit()
