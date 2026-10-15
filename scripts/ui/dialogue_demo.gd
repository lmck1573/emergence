extends Control
## 对话系统演示：三个按钮分别播放三段话题对话。

@onready var _dialogue: DialogueSystem = $DialogueSystem
@onready var _movie_button: Button = $Buttons/MovieButton
@onready var _missing_you_button: Button = $Buttons/MissingYouButton
@onready var _her_taste_button: Button = $Buttons/HerTasteButton


func _ready() -> void:
	_movie_button.pressed.connect(_on_movie_pressed)
	_missing_you_button.pressed.connect(_on_missing_you_pressed)
	_her_taste_button.pressed.connect(_on_her_taste_pressed)


func _on_movie_pressed() -> void:
	_dialogue.play_dialogue("dlg_topic_movie")


func _on_missing_you_pressed() -> void:
	_dialogue.play_dialogue("dlg_topic_missing_you")


func _on_her_taste_pressed() -> void:
	_dialogue.play_dialogue("dlg_topic_her_taste")
