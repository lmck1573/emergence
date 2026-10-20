extends Control
## Third-phase living room navigation and save controls.

@onready var _leave_button: Button = $GameArea/LeaveButton
@onready var _save_button: Button = $GameArea/SaveButton
var _blocked: bool = false
var _can_leave: bool = false
var _transitioning: bool = false


func _ready() -> void:
	_leave_button.hide()
	_save_button.hide()
	GameState.data["current_scene"] = "phase3_livingroom"
	GameState.commit()
	EventBus.modal_changed.connect(_on_modal_changed)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
	EventBus.leave_pressed.connect(_leave_livingroom)
	_save_button.pressed.connect(_save)
	for topic_id: String in ["topic_dream", "topic_where_did_you_go"]:
		GameState.unlock_topic(topic_id)
	_can_leave = GameState.is_event_completed("event_act3_topics_complete")
	EventBus.leave_visibility_requested.emit(_can_leave)


func _on_modal_changed(blocked: bool) -> void:
	_blocked = blocked
	_save_button.disabled = blocked
	_leave_button.hide()


func _on_dialogue_finished(dialogue_id: String) -> void:
	if dialogue_id != "dlg_act3_after_topics":
		return
	_can_leave = true
	EventBus.leave_visibility_requested.emit(true)


func _leave_livingroom() -> void:
	if _blocked or not _can_leave or _transitioning:
		return
	_transitioning = true
	EventBus.leave_visibility_requested.emit(false)
	EventBus.command_requested.emit("black_flash")
	await EventBus.command_finished
	GameState.data["current_scene"] = "phase3_kitchen"
	GameState.commit()
	get_tree().call_deferred("change_scene_to_file", "res://scenes/explore/phase3_kitchen.tscn")


func _save() -> void:
	if _blocked:
		return
	EventBus.audio_cue_requested.emit("sfx_save")
	EventBus.toast_requested.emit("已保存" if GameState.save() else "保存失败")
