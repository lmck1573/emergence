extends CanvasLayer
## Shared presentation. Every visual control is authored in the scene.
@onready var _reader: ColorRect = $Overlay/Reader
@onready var _text: Label = $Overlay/Reader/Scroll/Text
@onready var _scroll: ScrollContainer = $Overlay/Reader/Scroll
@onready var _exit: Button = $Overlay/Reader/Exit
@onready var _next: Button = $Overlay/Reader/Next
@onready var _previous: Button = $Overlay/Reader/Previous
@onready var _choice: ColorRect = $Overlay/Choice
@onready var _prompt: Label = $Overlay/Choice/Prompt
@onready var _yes: Button = $Overlay/Choice/Yes
@onready var _no: Button = $Overlay/Choice/No
@onready var _toast: Label = $Overlay/Toast
@onready var _timer: Timer = $ToastTimer
@onready var _fade: ColorRect = $Overlay/Fade
@onready var _dialogue: DialogueSystem = $Overlay/DialogueSystem
var _pages: Array[String] = []
var _page: int = 0
var _text_id: String = ""
var _next_label: String = ""
var _can_previous: bool = false
var _event_id: String = ""
var _toast_queue: Array[String] = []
var _ending: bool = false
var _inspection_dialogue: String = ""
## Canonical dialogue ranges exclude script directions and split investigation steps.
const INVESTIGATION_DIALOGUES: Dictionary = {
	"ft_livingroom_tv": ["dlg_tv", 0, 3],
	"ft_livingroom_empty_pot": ["dlg_flowerpot", 0, 4],
	"ft_livingroom_document": ["dlg_death_cert", 0, 2],
	"ft_livingroom_tea_egg": ["dlg_tea_egg", 0, 6],
	"ft_kitchen_fridge": ["dlg_fridge", 0, 6],
	"ft_bowls_look": ["dlg_couple_bowls", 0, 2],
	"ft_bowls_flip": ["dlg_couple_bowls", 2, 7],
	"ft_balcony_lounger": ["dlg_balcony_chair", 0, 3],
	"ft_balcony_window": ["dlg_window", 0, 6],
	"ft_balcony_flowerpots": ["dlg_withered_plants", 0, 4],
	"ft_unlock_master_bedroom": ["dlg_master_bedroom", 0, 3],
	"ft_master_floorboard": ["dlg_master_bedroom", 3, 16],
}

func _ready() -> void:
	EventBus.fulltext_requested.connect(_open_text)
	EventBus.choice_requested.connect(_show_choice)
	EventBus.toast_requested.connect(_show_toast)
	EventBus.ending_requested.connect(_end)
	EventBus.command_requested.connect(_command)
	EventBus.dialogue_requested.connect(_dialogue.play_dialogue)
	_dialogue.dialogue_started.connect(func(_id: String) -> void: EventBus.modal_changed.emit(true))
	_dialogue.dialogue_finished.connect(_dialogue_finished)
	_exit.pressed.connect(_close_text)
	_next.pressed.connect(_next_page)
	_previous.pressed.connect(_previous_page)
	_yes.pressed.connect(_choose.bind("yes"))
	_no.pressed.connect(_choose.bind("no"))
	_timer.timeout.connect(_pop_toast)

func _open_text(id: String, next_label: String, can_previous: bool) -> void:
	_text_id = id
	_pages = ContentDB.get_fulltext_pages(id)
	_page = 0
	_next_label = next_label
	_can_previous = can_previous
	_reader.hide()
	_scroll.show()
	_reader.self_modulate.a = 1.0
	if INVESTIGATION_DIALOGUES.has(id):
		var selection: Array[Variant] = INVESTIGATION_DIALOGUES[id]
		_inspection_dialogue = str(selection[0])
		_dialogue.play_dialogue(_inspection_dialogue, int(selection[1]), int(selection[2]))
		return
	if id == "ft_balcony_cushion":
		_inspection_dialogue = id
		var lines: Array[Dictionary] = []
		for page: String in _pages:
			lines.append({"speaker": "protagonist", "text": page})
		_dialogue.play_lines(id, lines)
		return
	_reader.show()
	EventBus.modal_changed.emit(true)
	_refresh_page()

func _dialogue_finished(id: String) -> void:
	if _inspection_dialogue.is_empty():
		EventBus.dialogue_finished.emit(id)
		return
	if id != _inspection_dialogue:
		return
	_inspection_dialogue = ""
	_page = maxi(0, _pages.size() - 1)
	if not _next_label.is_empty():
		# Reuse editor-authored navigation without the full-screen reading background.
		_scroll.hide()
		_reader.self_modulate.a = 0.0
		_reader.show()
		_refresh_page()
	else:
		_close_text()

func _refresh_page() -> void:
	_text.text = _pages[_page] if not _pages.is_empty() else ""
	_scroll.scroll_vertical = 0
	_next.visible = _page < _pages.size() - 1 or not _next_label.is_empty()
	_next.text = "下一页" if _page < _pages.size() - 1 else _next_label
	_previous.visible = _page > 0 or _can_previous

func _next_page() -> void:
	if _page < _pages.size() - 1:
		_page += 1
		_refresh_page()
	else:
		_reader.hide()
		EventBus.investigation_next.emit()

func _previous_page() -> void:
	if _page > 0:
		_page -= 1
		_refresh_page()
	else:
		EventBus.investigation_previous.emit()

func _close_text() -> void:
	var id: String = _text_id
	_reader.hide()
	_text_id = ""
	# Empty ID reports early close; only the last page counts as read.
	EventBus.fulltext_finished.emit(id if _page >= _pages.size() - 1 else "")
	EventBus.modal_changed.emit(false)

func _show_choice(event_id: String, choice: Dictionary) -> void:
	_event_id = event_id
	_prompt.text = str(choice.get("prompt", ""))
	_choice.show()
	EventBus.modal_changed.emit(true)

func _choose(option: String) -> void:
	_choice.hide()
	EventBus.choice_made.emit(_event_id, option)

func _show_toast(message: String) -> void:
	_toast_queue.append(message)
	if _timer.is_stopped():
		_pop_toast()

func _pop_toast() -> void:
	if _toast_queue.is_empty():
		_toast.hide()
		return
	_toast.text = _toast_queue.pop_front()
	_toast.show()
	_timer.start()

func _command(id: String) -> void:
	if id == "black_flash":
		_fade.modulate.a = 1.0
		_fade.show()
		await get_tree().create_timer(0.1).timeout
		_fade.hide()
	EventBus.command_finished.emit(id)

func _end() -> void:
	if _ending:
		return
	_ending = true
	EventBus.modal_changed.emit(true)
	_fade.modulate.a = 0.0
	_fade.show()
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, 0.5)
	await tween.finished
	EventBus.ending_finished.emit()
	get_tree().change_scene_to_file("res://scenes/ui/start_screen.tscn")

