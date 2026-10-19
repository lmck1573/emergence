extends Node2D
## 客厅探索场景控制器：返回地图、物品名称栏、物体悬停/点击接线。
## 点击物体 → 播放其对应的对话（可反复）。

signal object_clicked(object_id: String)

@onready var _name_label: Label = $GameArea/NameBar/NameLabel
@onready var _return_button: Button = $GameArea/ReturnButton
@onready var _dialogue: DialogueSystem = find_child("DialogueSystem", true, false) as DialogueSystem

var _dialogue_playing: bool = false
var _pending_object_id: String = ""
var _pending_dialogue_id: String = ""
var _active_object_id: String = ""
var _active_dialogue_id: String = ""


func _ready() -> void:
	_return_button.text = "◀"
	_return_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue.dialogue_started.connect(_on_dialogue_started)
	_dialogue.dialogue_finished.connect(_on_dialogue_finished)
	for node: Node in get_tree().get_nodes_in_group("interactive_object"):
		var obj := node as InteractiveObject
		if obj == null:
			continue
		obj.hovered.connect(_on_object_hovered)
		obj.unhovered.connect(_on_object_unhovered)
		obj.clicked.connect(_on_object_clicked)


func _on_return_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/explore/house_overview.tscn")


func _on_object_hovered(display_name: String) -> void:
	if _dialogue_playing:
		return
	_name_label.text = display_name


func _on_object_unhovered() -> void:
	if _dialogue_playing:
		return
	_name_label.text = ""


func _on_object_clicked(object_id: String, dialogue_id: String) -> void:
	if _dialogue_playing:
		return
	object_clicked.emit(object_id)
	_name_label.text = ""
	if dialogue_id != "":
		_pending_object_id = object_id
		_pending_dialogue_id = dialogue_id
		_dialogue.play_dialogue(dialogue_id)


func _on_dialogue_started(dialogue_id: String) -> void:
	_dialogue_playing = true
	if dialogue_id == _pending_dialogue_id:
		_active_object_id = _pending_object_id
		_active_dialogue_id = dialogue_id


func _on_dialogue_finished(dialogue_id: String) -> void:
	_dialogue_playing = false
	if dialogue_id == _active_dialogue_id and _active_object_id != "":
		var step_id: String = ContentDB.get_first_step_id(_active_object_id)
		if not step_id.is_empty():
			EventBus.object_step_completed.emit(_active_object_id, step_id)
	_pending_object_id = ""
	_pending_dialogue_id = ""
	_active_object_id = ""
	_active_dialogue_id = ""
