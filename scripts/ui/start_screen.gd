extends Control
## Centered 960x960 opening screen. Any click starts the opening animation.

@export var opening_frames: Array[Texture2D] = []
@export_range(0.1, 60.0) var opening_fps: float = 7.0
@export_range(0.0, 10.0) var last_frame_hold: float = 1.0

@onready var _game_viewport: TextureRect = $GameViewport
@onready var _black_fade: ColorRect = $BlackFade
var _started: bool = false
var _story_prompt: ConfirmationDialog
var _story_choice_made: bool = false


func _ready() -> void:
	var catalog: GDScript = preload("res://scripts/ui/game_picture_catalog.gd")
	opening_frames = catalog.frames("title_animation", opening_frames)
	catalog.apply_picture(self, "GameViewport", catalog.texture("title_image"))
	set_process_input(true)
	AudioManager.play_bgm("bgm_title")

func _continue_story() -> void:
	var saved: Dictionary = SaveManager.load_save()
	GameState.data = saved if not saved.is_empty() else SaveManager.default_state()
	_story_choice_made = true
	_enter_game()

func _new_story() -> void:
	if not SaveManager.clear_story():
		_story_prompt.dialog_text = "无法清除存档，请检查文件权限。"
		_story_prompt.popup_centered()
		return
	GameState.data = SaveManager.default_state()
	_story_choice_made = true
	_enter_game()


func _input(event: InputEvent) -> void:
	if _started:
		return
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed and _game_viewport.get_global_rect().has_point(touch_event.position):
			_start_opening()
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and _game_viewport.get_global_rect().has_point(mouse_event.position):
			_start_opening()


func _start_opening() -> void:
	_started = true
	for frame: Texture2D in opening_frames:
		_game_viewport.texture = frame
		await get_tree().create_timer(1.0 / maxf(opening_fps, 0.1)).timeout
	await get_tree().create_timer(last_frame_hold).timeout
	_fade_to_game()


func _fade_to_game() -> void:
	_black_fade.modulate.a = 0.0
	_black_fade.show()
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(_black_fade, "modulate:a", 1.0, 0.45)
	fade_tween.tween_callback(_enter_game)


func _enter_game() -> void:
	if SaveManager.has_ending_record() and not _story_choice_made and not get_tree().has_meta("act3_test"):
		_story_prompt = ConfirmationDialog.new()
		_story_prompt.title = "选择故事"
		_story_prompt.dialog_text = "从上次存档处继续，还是开启新的故事？"
		_story_prompt.ok_button_text = "继续上次存档"
		_story_prompt.cancel_button_text = "开启新的故事"
		_story_prompt.unresizable = true
		_story_prompt.dialog_close_on_escape = false
		_story_prompt.borderless = true
		add_child(_story_prompt)
		_story_prompt.confirmed.connect(_continue_story)
		_story_prompt.canceled.connect(_new_story)
		_story_prompt.popup_centered(Vector2i(460, 160))
		return
	EventBus.game_started.emit()
	if GameState.get_current_phase() == 3:
		var flags: Dictionary = GameState.data.get("flags", {})
		if flags.has("act3_route"):
			get_tree().change_scene_to_file("res://scenes/explore/phase3_kitchen.tscn")
			return
		var current: String = str(GameState.data.get("current_scene", "phase3_opening"))
		if current == "phase3_opening": flags["phase3_opening_pending"] = true
		var path: String = "res://scenes/explore/%s.tscn" % current
		if ResourceLoader.exists(path):
			get_tree().change_scene_to_file(path)
			return
	if GameState.get_current_phase() == 2:
		var phase2_scene: String = str(GameState.data.get("current_scene", "ai_interface_phase2"))
		var phase2_puzzle: Dictionary = GameState.data.get("puzzles", {}).get("puzzle_diary_password", {})
		var phase2_path: String = "res://scenes/ui/ai_interface_phase2.tscn"
		if phase2_scene in ["computer_desk", "computer_locked", "computer_unlocked"]:
			phase2_path = "res://scenes/explore/%s.tscn" % phase2_scene
			if phase2_scene == "computer_locked" and bool(phase2_puzzle.get("completed", false)):
				phase2_path = "res://scenes/explore/computer_unlocked.tscn"
		if ResourceLoader.exists(phase2_path):
			get_tree().change_scene_to_file(phase2_path)
			return
	get_tree().change_scene_to_file("res://scenes/ui/ai_interface.tscn")
