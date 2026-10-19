extends Control
## AI screen navigation and read-only completeness display.
const EYE_FRAME_SECONDS: float = 1.0 / 7.0
const EYE_PAUSE_SECONDS: float = 3.0
const EYE_OPENING_ORDER: Array[int] = [0, 1, 2, 3]
const EYE_LOOP_ORDER: Array[int] = [2, 1, 0, 0, 1, 2, 3]
const EYE_TEXTURES: Array[Texture2D] = [
	preload("res://artassests/第一阶段AI交互界面女主动画/AI眨眼1.png"),
	preload("res://artassests/第一阶段AI交互界面女主动画/AI眨眼2.png"),
	preload("res://artassests/第一阶段AI交互界面女主动画/AI眨眼3.png"),
	preload("res://artassests/第一阶段AI交互界面女主动画/AI眨眼4.png"),
]
@onready var _game_area: TextureRect = $Layout/GameArea
@onready var _completeness: Button = $Layout/CompletenessButton
@onready var _completeness_label: Label = $Layout/CompletenessButton/Label
@onready var _save_button: Button = $Layout/SaveButton
@onready var _return_button: Button = $Layout/ReturnButton
@onready var _agreement: TextureButton = $Layout/GameArea/AgreementButton
@onready var _guide: TextureButton = $Layout/GameArea/GuideButton
var _blocked: bool = false
var _documents_visible: bool = true
var _eye_frame_index: int = 0
var _eye_elapsed: float = 0.0
var _eye_pause_elapsed: float = 0.0
var _eye_is_pausing: bool = false
var _eye_is_opening: bool = true
var _eye_textures: Array[Texture2D] = []

func _ready() -> void:
	_eye_textures = preload("res://scripts/ui/game_picture_catalog.gd").frames("ai_eye_animation", EYE_TEXTURES)
	_return_button.text = "◀"
	_return_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_process(scene_file_path == "res://scenes/ui/ai_interface.tscn")
	if is_processing():
		_game_area.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_game_area.stretch_mode = TextureRect.STRETCH_SCALE
		_game_area.texture = _eye_textures[EYE_OPENING_ORDER[0]]
	_save_button.hide()
	_documents_visible = get_tree().current_scene == null or get_tree().current_scene.scene_file_path != "res://scenes/ui/ai_interface_phase2.tscn"
	GameState.completeness_changed.connect(_refresh_completeness)
	EventBus.state_changed.connect(_refresh)
	EventBus.modal_changed.connect(_lock)
	_save_button.pressed.connect(_save)
	_return_button.pressed.connect(_return)
	_agreement.pressed.connect(func() -> void: EventBus.opening_requested.emit("agreement", "ft_opening_agreement"))
	_guide.pressed.connect(func() -> void: EventBus.opening_requested.emit("guide", "ft_opening_cultivation_guide"))
	_refresh()

func _process(delta: float) -> void:
	if _eye_is_pausing:
		_eye_pause_elapsed += delta
		if _eye_pause_elapsed >= EYE_PAUSE_SECONDS:
			_eye_is_pausing = false
			_eye_pause_elapsed = 0.0
			_eye_frame_index = -1
			_eye_is_opening = false
		_eye_elapsed = 0.0
		return

	_eye_elapsed += delta
	while _eye_elapsed >= EYE_FRAME_SECONDS:
		_eye_elapsed -= EYE_FRAME_SECONDS
		var frame_order: Array[int] = EYE_OPENING_ORDER if _eye_is_opening else EYE_LOOP_ORDER
		_eye_frame_index += 1
		if _eye_frame_index >= frame_order.size():
			_eye_is_pausing = true
			_eye_pause_elapsed = 0.0
			_eye_frame_index = frame_order.size() - 1
			_eye_elapsed = 0.0
			return
		_game_area.texture = _eye_textures[frame_order[_eye_frame_index]]

func _refresh() -> void:
	_refresh_completeness(GameState.get_completeness())
	var can_return_to_map: bool = GameState.is_region_unlocked("house_overview")
	if GameState.get_current_phase() == 2:
		can_return_to_map = can_return_to_map and GameState.is_event_completed("event_unlock_wife_room")
	_return_button.visible = not _blocked and can_return_to_map
	_return_button.disabled = _blocked or not _return_button.visible

func _refresh_completeness(value: float) -> void:
	_completeness_label.text = "人格完整度：%.1f%%" % value

func _lock(blocked: bool) -> void:
	_blocked = blocked
	_refresh()
	_save_button.disabled = blocked
	_agreement.disabled = blocked
	_guide.disabled = blocked
	_completeness.disabled = blocked
	_save_button.hide()
	_agreement.visible = _documents_visible and not blocked
	_guide.visible = _documents_visible and not blocked
	_completeness.visible = not blocked

func _save() -> void:
	EventBus.audio_cue_requested.emit("sfx_save")
	EventBus.toast_requested.emit("已保存" if GameState.save() else "保存失败")

func _return() -> void:
	GameState.data["current_scene"] = "house_overview"
	GameState.commit()
	get_tree().change_scene_to_file("res://scenes/explore/house_overview.tscn")






