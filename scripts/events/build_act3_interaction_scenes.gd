extends SceneTree
## Creates editable stage-three room scenes with movable heroine targets.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog_script: GDScript = load("res://scripts/ui/game_picture_catalog.gd") as GDScript
	var main_path: String = "res://scenes/explore/phase3_kitchen.tscn"
	_build_kitchen(catalog_script, main_path)
	var rooms: Dictionary = {
		"balcony": "phase3_balcony",
		"master_bedroom": "phase3_master_bedroom",
		"livingroom": "phase3_livingroom",
		"wife_room": "phase3_wife_room",
	}
	for key: String in rooms:
		var root_node: Control = Control.new()
		root_node.name = "Phase3" + key.to_pascal_case() + "Closeup"
		root_node.size = Vector2(1920, 1080)
		var background: ColorRect = ColorRect.new()
		background.name = "Background"
		background.color = Color.BLACK
		background.size = root_node.size
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_node.add_child(background)
		background.owner = root_node
		var picture: TextureRect = TextureRect.new()
		picture.name = "GameArea"
		picture.position = Vector2(480, 60)
		picture.size = Vector2(960, 960)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.texture = catalog_script.room(str(rooms[key]), true)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_node.add_child(picture)
		picture.owner = root_node
		_add_target(root_node, picture)
		if key == "wife_room":
			_add_named_target(root_node, picture, "ComputerInteraction", "电脑", Vector2(640, 500))
		_save(root_node, "res://scenes/explore/phase3_%s_closeup.tscn" % key)
		root_node.queue_free()
	var computer_root: Control = Control.new()
	computer_root.name = "Phase3ComputerCloseup"
	computer_root.size = Vector2(1920, 1080)
	var computer_background: ColorRect = ColorRect.new()
	computer_background.name = "Background"
	computer_background.color = Color.BLACK
	computer_background.size = computer_root.size
	computer_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	computer_root.add_child(computer_background)
	computer_background.owner = computer_root
	var computer_picture: TextureRect = TextureRect.new()
	computer_picture.name = "GameArea"
	computer_picture.position = Vector2(480, 60)
	computer_picture.size = Vector2(960, 960)
	computer_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	computer_picture.texture = catalog_script.room("computer_desk", true)
	computer_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	computer_root.add_child(computer_picture)
	computer_picture.owner = computer_root
	_add_named_target(computer_root, computer_picture, "DrawerInteraction", "抽屉", Vector2(670, 680))
	_save(computer_root, "res://scenes/explore/phase3_computer_closeup.tscn")
	computer_root.queue_free()
	_build_true_ending_computer(catalog_script)
	quit()

func _build_true_ending_computer(catalog_script: GDScript) -> void:
	var root_node: Control = Control.new()
	root_node.name = "Phase3TrueEndingComputer"
	root_node.size = Vector2(1920, 1080)
	root_node.set_script(load("res://scripts/explore/phase3_true_ending_computer.gd"))
	var background: ColorRect = ColorRect.new()
	background.name = "Background"
	background.color = Color.BLACK
	background.size = root_node.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_node.add_child(background)
	background.owner = root_node
	var picture: TextureRect = TextureRect.new()
	picture.name = "GameArea"
	picture.position = Vector2(480, 60)
	picture.size = Vector2(960, 960)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture = catalog_script.room("computer_desk", true)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_node.add_child(picture)
	picture.owner = root_node
	_add_named_target(root_node, picture, "DrawerInteraction", "抽屉", Vector2(822, 343))
	var story_ui: Node = (load("res://scenes/ui/story_ui.tscn") as PackedScene).instantiate()
	story_ui.name = "StoryUI"
	root_node.add_child(story_ui)
	story_ui.owner = root_node
	_save(root_node, "res://scenes/explore/phase3_true_ending_computer.tscn")
	root_node.queue_free()

func _build_kitchen(catalog_script: GDScript, path: String) -> void:
	var root_node: Control = Control.new()
	root_node.name = "Phase3Kitchen"
	root_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_node.set_script(load("res://scripts/explore/phase3_kitchen.gd"))
	for property: String in ["house_overview", "livingroom", "kitchen", "balcony", "master_bedroom", "wife_room", "computer_desk", "computer_locked", "computer_unlocked", "ai_phase2", "phase3_livingroom", "phase3_kitchen", "phase3_balcony", "phase3_master_bedroom", "phase3_wife_room", "phone_year4", "phone_march"]:
		var texture_path: String = ""
		match property:
			"house_overview": texture_path = "res://artassests/地图完整.PNG"
			"livingroom": texture_path = "res://artassests/场景特写/客厅1.png"
			"kitchen": texture_path = "res://artassests/场景特写/厨房1.png"
			"balcony": texture_path = "res://artassests/场景特写/烟台1.png"
			"master_bedroom": texture_path = "res://artassests/场景特写/主卧1.png"
			"wife_room": texture_path = "res://artassests/场景特写/女主的房间1.png"
			"computer_desk": texture_path = "res://artassests/场景特写/女主电脑特写1.png"
			"computer_locked": texture_path = "res://artassests/场景特写/女主电脑特写2.png"
			"computer_unlocked": texture_path = "res://artassests/场景特写/女主电脑特写3.png"
			"ai_phase2": texture_path = "res://artassests/场景特写/第二阶段人格培养界面.png"
			"phase3_livingroom": texture_path = "res://artassests/场景特写/客厅2.png"
			"phase3_kitchen": texture_path = "res://artassests/场景特写/厨房2.png"
			"phase3_balcony": texture_path = "res://artassests/场景特写/阳台2.png"
			"phase3_master_bedroom": texture_path = "res://artassests/场景特写/主卧1.png"
			"phase3_wife_room": texture_path = "res://artassests/场景特写/女主的房间2.png"
			"phone_year4", "phone_march": texture_path = "res://artassests/第三阶段CG/手机聊天界面.png"
		root_node.set(property, load(texture_path) as Texture2D)
	var guide: ColorRect = ColorRect.new()
	guide.name = "EditorGameAreaGuide"
	guide.position = Vector2(480, 60)
	guide.size = Vector2(960, 960)
	guide.z_index = -100
	guide.set_script(load("res://scripts/ui/editor_game_area_guide.gd"))
	root_node.add_child(guide)
	guide.owner = root_node
	var background: ColorRect = ColorRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color.BLACK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_node.add_child(background)
	background.owner = root_node
	var game_area: TextureRect = TextureRect.new()
	game_area.name = "GameArea"
	game_area.position = Vector2(480, 60)
	game_area.size = Vector2(960, 960)
	game_area.texture = load("res://artassests/厨房草稿.png") as Texture2D
	game_area.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	root_node.add_child(game_area)
	game_area.owner = root_node
	var save_button: Button = Button.new()
	save_button.name = "SaveButton"
	save_button.position = Vector2(240, 865)
	save_button.size = Vector2(60, 50)
	save_button.modulate = Color(0.45, 0.7, 1, 1)
	game_area.add_child(save_button)
	save_button.owner = root_node
	var save_label: Label = Label.new()
	save_label.name = "Label"
	save_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	save_label.text = "存档"
	save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	save_button.add_child(save_label)
	save_label.owner = root_node
	_add_target(root_node, game_area)
	var story_ui: Node = (load("res://scenes/ui/story_ui.tscn") as PackedScene).instantiate()
	story_ui.name = "StoryUI"
	root_node.add_child(story_ui)
	story_ui.owner = root_node
	_save(root_node, path)
	root_node.queue_free()

func _add_target(owner_node: Node, picture: Control) -> void:
	_add_named_target(owner_node, picture, "HeroineInteraction", "女主", Vector2(455, 525))

func _add_named_target(owner_node: Node, picture: Control, node_name: String, label: String, at: Vector2) -> void:
	if picture.has_node(node_name):
		return
	var button: Button = Button.new()
	button.name = node_name
	button.position = at
	button.size = Vector2(50, 50)
	button.tooltip_text = label
	button.set_meta("preserve_button_background", true)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(27.0 / 255.0, 110.0 / 255.0, 247.0 / 255.0, 0.5)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, style)
	picture.add_child(button)
	button.owner = owner_node

func _save(root_node: Node, path: String) -> void:
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(root_node) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	assert(ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) != null)
	print("SAVED ", path)
