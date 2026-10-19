extends Control
## Plays the third-phase computer blackout sequence from this scene.

@onready var _cultivation_interface: Control = $CultivationInterface
@onready var _computer_cg: TextureRect = $ComputerScreenCG


func _ready() -> void:
	if bool(GameState.data.get("flags", {}).get("phase3_opening_pending", false)):
		_play_opening()


func _play_opening() -> void:
	GameState.data["flags"].erase("phase3_opening_pending")
	GameState.commit()
	EventBus.dialogue_requested.emit("dlg_act3_opening")
	await EventBus.dialogue_finished
	EventBus.command_requested.emit("black_fade")
	await EventBus.command_finished
	_computer_cg.hide()
	EventBus.dialogue_requested.emit("dlg_act3_absence")
	await EventBus.dialogue_finished
	_cultivation_interface.show()
	EventBus.command_requested.emit("black_reveal")
	await EventBus.command_finished
	EventBus.dialogue_requested.emit("dlg_act3_confession")
	await EventBus.command_finished
	GameState.data["current_scene"] = "phase3_doorway"
	GameState.commit()
	get_tree().call_deferred("change_scene_to_file", "res://scenes/explore/phase3_doorway.tscn")
