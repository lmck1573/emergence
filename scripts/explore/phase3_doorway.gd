extends Control
## Holds on the authored CG placeholder until the reunion line is dismissed.


func _ready() -> void:
	var flow: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/act3_flow.json")) as Dictionary
	$CGPlaceholder.texture = load(str(flow["cg_images"]["reunion"])) as Texture2D
	var image: Texture2D = preload("res://scripts/ui/game_picture_catalog.gd").texture("reunion")
	if image != null:
		$CGPlaceholder.texture = image
	_play_reunion()


func _play_reunion() -> void:
	EventBus.dialogue_requested.emit("dlg_act3_reunion")
	await EventBus.dialogue_finished
	EventBus.command_requested.emit("black_flash")
	await EventBus.command_finished
	GameState.data["current_scene"] = "phase3_livingroom"
	GameState.commit()
	get_tree().call_deferred("change_scene_to_file", "res://scenes/explore/phase3_livingroom.tscn")
