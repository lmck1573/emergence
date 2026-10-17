extends Control
## AI screen navigation and read-only completeness display.
@onready var _completeness: Button = $Layout/CompletenessButton
@onready var _save_button: Button = $Layout/SaveButton
@onready var _return_button: Button = $Layout/ReturnButton
@onready var _agreement: Button = $Layout/GameArea/AgreementButton
@onready var _guide: Button = $Layout/GameArea/GuideButton
var _blocked: bool = false

func _ready() -> void:
	GameState.completeness_changed.connect(_refresh_completeness)
	EventBus.state_changed.connect(_refresh)
	EventBus.modal_changed.connect(_lock)
	_save_button.pressed.connect(_save)
	_return_button.pressed.connect(_return)
	_agreement.pressed.connect(func() -> void: EventBus.opening_requested.emit("agreement", "ft_opening_agreement"))
	_guide.pressed.connect(func() -> void: EventBus.opening_requested.emit("guide", "ft_opening_cultivation_guide"))
	_refresh()

func _refresh() -> void:
	_refresh_completeness(GameState.get_completeness())
	_return_button.visible = not _blocked and GameState.is_region_unlocked("house_overview")
	_return_button.disabled = _blocked or not _return_button.visible

func _refresh_completeness(value: float) -> void:
	_completeness.text = "人格完整度：%.1f%%" % value

func _lock(blocked: bool) -> void:
	_blocked = blocked
	_refresh()
	_save_button.disabled = blocked
	_agreement.disabled = blocked
	_guide.disabled = blocked
	_completeness.disabled = blocked
	_save_button.visible = not blocked
	_agreement.visible = not blocked
	_guide.visible = not blocked
	_completeness.visible = not blocked

func _save() -> void:
	EventBus.toast_requested.emit("已保存" if GameState.save() else "保存失败")

func _return() -> void:
	GameState.data["current_scene"] = "house_overview"
	GameState.commit()
	get_tree().change_scene_to_file("res://scenes/explore/house_overview.tscn")

