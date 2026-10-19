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
	state.data["flags"]["wife_room_entered"] = true
	change_scene_to_file("res://scenes/explore/computer_locked.tscn")
	for index: int in range(6): await process_frame
	assert(current_scene.get_node("LockedEntry").visible, "Password marker missing")
	assert(current_scene.get_node("LockedEntry").input_pickable, "Password marker disabled")
	assert(not current_scene.has_node("PowerButton"))
	for key: String in ["LockedDrawer", "Notebooks", "balcony_lounger"]:
		assert(current_scene.get_node(key).visible, "Other point missing: " + key)
		assert(current_scene.get_node(key).input_pickable)
	current_scene.call("_on_return_button_pressed")
	for index: int in range(6): await process_frame
	assert(current_scene.scene_file_path.ends_with("wife_room.tscn"), "Locked computer should return to wife's room")
	assert(state.data["current_scene"] == "wife_room")
	current_scene.call("_clicked", "wiferoom_computer", "")
	for index: int in range(6): await process_frame
	assert(current_scene.scene_file_path.ends_with("computer_desk.tscn"), "First visit should show desktop before power-on")
	state.data["objects"]["computer_power_button"] = ["look"]
	current_scene.call("_on_return_button_pressed")
	for index: int in range(6): await process_frame
	current_scene.call("_clicked", "wiferoom_computer", "")
	for index: int in range(6): await process_frame
	assert(current_scene.scene_file_path.ends_with("computer_locked.tscn"), "Re-entry should show the locked screen directly")
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
	current_scene.call("_on_return_button_pressed")
	for index: int in range(6): await process_frame
	assert(current_scene.scene_file_path.ends_with("wife_room.tscn"), "Unlocked computer should return to wife's room")
	current_scene.call("_clicked", "wiferoom_computer", "")
	for index: int in range(6): await process_frame
	assert(current_scene.scene_file_path.ends_with("computer_unlocked.tscn"), "Re-entry should show the latest unlocked screen directly")
	var old: Node = current_scene
	root.remove_child(old)
	old.call("refresh_computer_picture")
	old.queue_free()
	print("PASS computer markers, unlock scene transition, detached refresh")
	quit()
