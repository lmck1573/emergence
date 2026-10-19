extends RefCounted
## Reads editor-saved picture slots without instantiating the gameplay scene.
const CATALOG_SCENE: String = "res://scenes/explore/phase3_kitchen.tscn"

static func settings() -> Dictionary:
	var packed: PackedScene = load(CATALOG_SCENE) as PackedScene
	var state: SceneState = packed.get_state()
	var result: Dictionary = {}
	for index: int in range(state.get_node_property_count(0)):
		result[str(state.get_node_property_name(0, index))] = state.get_node_property_value(0, index)
	return result

static func texture(key: String) -> Texture2D:
	return settings().get(key) as Texture2D

static func frames(key: String, fallback: Array[Texture2D]) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	var value: Variant = settings().get(key, [])
	if value is Array:
		for item: Variant in value:
			if not item is Texture2D:
				return fallback
			result.append(item as Texture2D)
	if key == "ai_eye_animation" and result.size() != 4:
		return fallback
	return fallback if result.is_empty() else result

static func room(key: String, third_phase: bool = false) -> Texture2D:
	var values: Dictionary = settings()
	var image: Texture2D = values.get("phase3_" + key) as Texture2D if third_phase else null
	return image if image != null else values.get(key) as Texture2D

static func apply_picture(root: Node, path: String, image: Texture2D) -> void:
	if image == null:
		return
	var view: TextureRect = root.get_node_or_null(NodePath(path)) as TextureRect
	if view != null:
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.texture = image

static func apply_scene(root: Node) -> void:
	if root == null:
		return
	var key: String = root.scene_file_path.get_file().get_basename()
	match key:
		"house_overview": apply_picture(root, "Background", texture(key))
		"livingroom", "kitchen", "balcony", "master_bedroom", "wife_room", "computer_desk":
			# The computer desk scene keeps its room image in a child TextureRect.
			var image: Texture2D = room(key)
			var area: Node = root.get_node_or_null("GameArea")
			if area is TextureRect:
				apply_picture(root, "GameArea", image)
			elif area != null:
				for child: Node in area.get_children():
					if child is TextureRect:
						apply_picture(area, str(child.name), image)
			if key == "computer_desk" and root.has_method("refresh_computer_picture"):
				root.call("refresh_computer_picture")
		"ai_interface_phase2": apply_picture(root, "Layout/GameArea", texture("ai_phase2"))
		"phase3_livingroom": apply_picture(root, "GameArea", room("livingroom", true))
		"phase3_next_closeup": apply_picture(root, "GameArea", room("master_bedroom", true))
		"phase3_opening":
			apply_picture(root, "ComputerScreenCG", texture("phase3_computer_black"))
			apply_picture(root, "CultivationInterface/Frame", texture("phase3_cultivation"))
