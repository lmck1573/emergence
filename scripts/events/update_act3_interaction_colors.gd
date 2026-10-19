extends SceneTree
## Updates saved third-phase interaction markers without changing their geometry.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var paths: PackedStringArray = [
		"res://scenes/explore/phase3_kitchen.tscn",
		"res://scenes/explore/phase3_balcony_closeup.tscn",
		"res://scenes/explore/phase3_master_bedroom_closeup.tscn",
		"res://scenes/explore/phase3_livingroom_closeup.tscn",
		"res://scenes/explore/phase3_wife_room_closeup.tscn",
		"res://scenes/explore/phase3_computer_closeup.tscn",
	]
	for path: String in paths:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			continue
		var root_node: Node = packed.instantiate()
		var changed: bool = false
		for child: Node in root_node.find_children("*", "Button", true, false):
			var button: Button = child as Button
			if button == null or button.name not in ["HeroineInteraction", "ComputerInteraction", "DrawerInteraction"]:
				continue
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = Color(27.0 / 255.0, 110.0 / 255.0, 247.0 / 255.0, 0.5)
			for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
				button.add_theme_stylebox_override(state, style)
			changed = true
		if changed:
			var updated: PackedScene = PackedScene.new()
			assert(updated.pack(root_node) == OK)
			assert(ResourceSaver.save(updated, path) == OK)
		root_node.free()
	quit()
