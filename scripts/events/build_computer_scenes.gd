extends SceneTree
## Builds computer screens with native Godot serialization.
func _initialize() -> void:
	for mode: String in ["locked", "unlocked"]:
		var source: PackedScene = load("res://scenes/explore/computer_desk.tscn") as PackedScene
		var scene: Node = source.instantiate()
		scene.name = "ComputerLocked" if mode == "locked" else "ComputerUnlocked"
		for child: Node in scene.get_children():
			if child is Area2D:
				var id: String = str(child.get("object_id"))
				var screen_point: bool = id in ["computer_power_button", "computer_locked_entry", "computer_folder_games", "computer_folder_social", "computer_folder_bills"]
				var keep: bool = not screen_point or (id == "computer_locked_entry" if mode == "locked" else id in ["computer_folder_games", "computer_folder_social", "computer_folder_bills"])
				if not keep:
					scene.remove_child(child)
					child.queue_free()
		for path: String in ["GameArea/MonitorFrame", "GameArea/MonitorScreen", "GameArea/ScreenTitle", "GameArea/Title"]:
			var decoration: Node = scene.get_node(path)
			decoration.get_parent().remove_child(decoration)
			decoration.queue_free()
		var packed: PackedScene = PackedScene.new()
		packed.pack(scene)
		var result: Error = ResourceSaver.save(packed, "res://scenes/explore/computer_%s.tscn" % mode)
		print("computer_%s: %s" % [mode, error_string(result)])
		scene.queue_free()
	quit()
