extends Control
## Dedicated final-ending computer scene with its own editable drawer target.
signal drawer_unlocked

@onready var _drawer_button: Button = $GameArea/DrawerInteraction
@onready var _picture: TextureRect = $GameArea
var _blocked: bool = false
var _puzzle_solved: bool = false

func _ready() -> void:
	add_to_group("true_ending_computer_test")
	_picture.texture = preload("res://scripts/ui/game_picture_catalog.gd").room("computer_desk", true)
	_drawer_button.pressed.connect(_open_drawer_puzzle)
	EventBus.modal_changed.connect(_on_modal_changed)
	EventBus.puzzle_submitted.connect(_on_puzzle_submitted)
	_drawer_button.disabled = _blocked

func _open_drawer_puzzle() -> void:
	if _blocked or _puzzle_solved:
		return
	EventBus.audio_cue_requested.emit("sfx_click")
	EventBus.puzzle_requested.emit("puzzle_act3_drawer_password")

func _on_modal_changed(blocked: bool) -> void:
	_blocked = blocked
	_drawer_button.disabled = blocked or _puzzle_solved

func _on_puzzle_submitted(puzzle_id: String, answer: String) -> void:
	if puzzle_id != "puzzle_act3_drawer_password":
		return
	if answer != "0413":
		EventBus.audio_cue_requested.emit("sfx_puzzle_wrong")
		return
	_puzzle_solved = true
	_drawer_button.disabled = true
	GameState.complete_puzzle(puzzle_id)
	EventBus.audio_cue_requested.emit("sfx_puzzle_correct")
	drawer_unlocked.emit()
