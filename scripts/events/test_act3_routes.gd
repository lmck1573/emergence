extends SceneTree
## Headless integration test; does not write player saves.
var _truth: int = 0
var _allow: bool = false
var GameState: Node
var EventBus: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	GameState = root.get_node("GameState")
	EventBus = root.get_node("EventBus")
	Engine.time_scale = 100.0
	set_meta("act3_test", true)
	for scenario: Dictionary in [{"truth": 0, "allow": false, "ending": "love"}, {"truth": 1, "allow": false, "ending": "life"}, {"truth": 2, "allow": false, "ending": "life"}, {"truth": 2, "allow": true, "ending": "truth"}]:
		_truth = int(scenario["truth"])
		_allow = bool(scenario["allow"])
		GameState.data = load("res://scripts/save/save_manager.gd").default_state()
		GameState.data["phase"] = 3
		GameState.data["truth_revealed"] = _truth
		change_scene_to_file("res://scenes/explore/phase3_kitchen.tscn")
		var frames: int = 0
		while frames < 15000:
			await process_frame
			frames += 1
			if current_scene == null: continue
			if current_scene.scene_file_path.ends_with("start_screen.tscn"):
				break
			var view: Control = null
			for node: Node in get_nodes_in_group("act3_test_view"):
				view = node as Control
			if view != null:
				if view.target.visible and not view.target.disabled: view.activated.emit()
				elif view.leave.visible and not view.leave.disabled: view.activated.emit()
				elif view.no.visible: view.decision.emit("yes" if _allow and view.yes.visible else "no")
			var ui: Node = current_scene.find_child("StoryUI", true, false)
			if ui != null:
				var dialogue: Control = ui.get_node("Overlay/DialogueSystem") as Control
				if bool(dialogue.get("_is_playing")): dialogue.call("_advance")
				var puzzle: String = str(ui.get("_puzzle_id"))
				if not puzzle.is_empty():
					EventBus.puzzle_submitted.emit(puzzle, "0413")
					ui.call("_close_puzzle")
		var actual: String = str(GameState.data["flags"].get("ending_id", ""))
		if actual != str(scenario["ending"]):
			push_error("Act3 failed: %s; flags=%s" % [scenario, GameState.data["flags"]])
			quit(1)
			return
		print("PASS truth=%d allow=%s ending=%s" % [_truth, _allow, actual])
	quit(0)
