extends Control
class_name FeedToolbar
## Fixed scene-authored entries, populated only by setting visibility and text.
@onready var _feed_button: Button = $Layout/Toolbar/Buttons/FeedButton
@onready var _topic_button: Button = $Layout/Toolbar/Buttons/TopicButton
@onready var _feed_panel: PanelContainer = $Layout/FeedPanel
@onready var _topic_panel: PanelContainer = $Layout/TopicPanel
@onready var _feed_items: VBoxContainer = $Layout/FeedPanel/PanelContent/ScrollContainer/Items
@onready var _topic_items: VBoxContainer = $Layout/TopicPanel/PanelContent/ScrollContainer/Items
@onready var _blocker: Control = $Layout/Blocker
@onready var _feed_close: Button = $Layout/FeedPanel/PanelContent/Close
@onready var _topic_close: Button = $Layout/TopicPanel/PanelContent/Close
@onready var _toolbar: Control = $Layout/Toolbar
var _own_modal: bool = false
var _locked: bool = false
var _ai_scene: bool = false

func _ready() -> void:
	_feed_panel.hide()
	_topic_panel.hide()
	_blocker.hide()
	_feed_button.pressed.connect(_open.bind(true))
	_topic_button.pressed.connect(_open.bind(false))
	_feed_close.pressed.connect(_close)
	_topic_close.pressed.connect(_close)
	EventBus.modal_changed.connect(set_interaction_locked)
	EventBus.state_changed.connect(_refresh)
	for child: Node in _feed_items.get_children():
		var entry: Button = child as Button
		entry.pressed.connect(_select.bind(String(entry.name), true))
	for child: Node in _topic_items.get_children():
		var entry: Button = child as Button
		entry.pressed.connect(_select.bind(String(entry.name), false))
	_refresh()
	_refresh_scene_context.call_deferred()

func _refresh_scene_context() -> void:
	_ai_scene = get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://scenes/ui/ai_interface.tscn"
	_refresh()

func set_interaction_locked(locked: bool) -> void:
	_locked = locked
	_feed_button.disabled = locked
	_topic_button.disabled = locked
	visible = _ai_scene and (not locked or _own_modal)
	_toolbar.visible = _ai_scene and not locked

func _open(feed: bool) -> void:
	if not _ai_scene or _locked:
		return
	_own_modal = true
	_blocker.show()
	_feed_panel.visible = feed
	_topic_panel.visible = not feed
	_refresh()
	EventBus.modal_changed.emit(true)

func _close() -> void:
	_feed_panel.hide()
	_topic_panel.hide()
	_blocker.hide()
	_own_modal = false
	EventBus.modal_changed.emit(false)

func _select(id: String, feed: bool) -> void:
	if not _own_modal:
		return
	_close()
	if feed:
		EventBus.feed_requested.emit(id)
	else:
		EventBus.topic_requested.emit(id)

func _refresh() -> void:
	set_interaction_locked(_locked)
	for child: Node in _feed_items.get_children():
		var entry: Button = child as Button
		var id: String = String(entry.name)
		var item: Dictionary = ContentDB.get_content(id)
		entry.text = str(item.get("display_name", ""))
		entry.visible = GameState.is_content_obtained(id) and not GameState.is_content_fed(id) and int(item.get("phase", 0)) == GameState.get_current_phase() and bool(item.get("feedable", false))
		if not entry.visible:
			entry.text = ""
	for child: Node in _topic_items.get_children():
		var entry: Button = child as Button
		var id: String = String(entry.name)
		var item: Dictionary = ContentDB.get_topic(id)
		entry.text = str(item.get("display_name", ""))
		entry.visible = GameState.is_topic_unlocked(id) and int(item.get("phase", 0)) == GameState.get_current_phase()
		if not entry.visible:
			entry.text = ""
