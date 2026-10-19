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
@onready var _sound_button: Button = $Overlay/SoundButton
@onready var _sound_label: Label = $Overlay/SoundButton/SoundLabel
@onready var _dialogue: DialogueSystem = $Overlay/DialogueSystem
@onready var _puzzle_panel: ColorRect = $Overlay/PuzzlePanel
@onready var _diary_panel: ColorRect = $Overlay/DiaryPanel
@onready var _diary_entries: RichTextLabel = $Overlay/DiaryPanel/DiaryFrame/DiaryEntries
@onready var _digit_1: Label = $Overlay/PuzzlePanel/PuzzleFrame/Digit1
@onready var _digit_2: Label = $Overlay/PuzzlePanel/PuzzleFrame/Digit2
@onready var _digit_3: Label = $Overlay/PuzzlePanel/PuzzleFrame/Digit3
@onready var _digit_4: Label = $Overlay/PuzzlePanel/PuzzleFrame/Digit4
var _puzzle_id: String = ""
var _pages: Array[String] = []
var _page: int = 0
var _text_id: String = ""
var _next_label: String = ""
var _can_previous: bool = false
var _event_id: String = ""
var _toast_queue: Array[String] = []
var _ending: bool = false
var _inspection_dialogue: String = ""
var _muted: bool = false
var _global_save: Button
var _global_save_default_position: Vector2
## Canonical dialogue ranges exclude script directions and split investigation steps.
const INVESTIGATION_DIALOGUES: Dictionary = {
	"ft_livingroom_tv": ["dlg_tv", 0, 3],
	"ft_livingroom_empty_pot": ["dlg_flowerpot", 0, 4],
	"ft_livingroom_document": ["dlg_death_cert", 0, 2],
	"ft_livingroom_tea_egg": ["dlg_tea_egg", 0, 6],
	"ft_kitchen_fridge": ["dlg_fridge", 0, 6],
	"ft_bowls_look": ["dlg_couple_bowls", 0, 7],
	"ft_balcony_lounger": ["dlg_balcony_chair", 0, 3],
	"ft_balcony_window": ["dlg_window", 0, 6],
	"ft_balcony_flowerpots": ["dlg_withered_plants", 0, 4],
	"ft_unlock_master_bedroom": ["dlg_master_bedroom", 0, 3],
	"ft_master_floorboard": ["dlg_master_bedroom", 3, 16],
	"ft_folder_social": ["dlg_pc_social", 0, 17],
}

func _ready() -> void:
	_apply_catalog.call_deferred()
	if bool(GameState.data["flags"].get("phase2_reveal_pending", false)):
		_fade.color = Color.BLACK
		_fade.modulate.a = 1.0
		_fade.show()
		_reveal_phase2.call_deferred()
	_sound_button.add_to_group("act3_ending_ui")
	_sound_button.size = Vector2(100.0, 50.0)
	_sound_button.custom_minimum_size = _sound_button.size
	_toast.add_theme_color_override("font_color", Color.BLACK)
	var global_save: Button = preload("res://scripts/ui/global_save_button.gd").new()
	$Overlay.add_child(global_save)
	_global_save = global_save
	_global_save_default_position = global_save.position
	var developer_mode: Node = preload("res://scripts/ui/developer_test_mode.gd").new()
	add_child(developer_mode)
	EventBus.fulltext_requested.connect(_open_text)
	EventBus.choice_requested.connect(_show_choice)
	EventBus.toast_requested.connect(_show_toast)
	EventBus.ending_requested.connect(_end)
	EventBus.command_requested.connect(_command)
	EventBus.transition_requested.connect(_transition)
	EventBus.dialogue_requested.connect(_dialogue.play_dialogue)
	_dialogue.dialogue_started.connect(func(_id: String) -> void: EventBus.modal_changed.emit(true))
	_dialogue.dialogue_finished.connect(_dialogue_finished)
	_exit.pressed.connect(_close_text)
	_next.pressed.connect(_next_page)
	_previous.pressed.connect(_previous_page)
	_yes.pressed.connect(_choose.bind("yes"))
	_no.pressed.connect(_choose.bind("no"))
	_timer.timeout.connect(_pop_toast)
	_sound_button.pressed.connect(_toggle_sound)
	EventBus.modal_changed.connect(_on_modal_changed)
	EventBus.audio_mute_changed.connect(_on_audio_mute_changed)
	EventBus.puzzle_requested.connect(_show_puzzle)
	EventBus.diary_viewer_requested.connect(_show_diary_viewer)
	$Overlay/PuzzlePanel/PuzzleFrame/Submit.pressed.connect(_submit_puzzle)
	$Overlay/PuzzlePanel/PuzzleFrame/Cancel.pressed.connect(_close_puzzle)
	$Overlay/PuzzlePanel/PuzzleFrame/Digit1Up.pressed.connect(_adjust_digit.bind(_digit_1, 1))
	$Overlay/PuzzlePanel/PuzzleFrame/Digit1Down.pressed.connect(_adjust_digit.bind(_digit_1, -1))
	$Overlay/PuzzlePanel/PuzzleFrame/Digit2Up.pressed.connect(_adjust_digit.bind(_digit_2, 1))
	$Overlay/PuzzlePanel/PuzzleFrame/Digit2Down.pressed.connect(_adjust_digit.bind(_digit_2, -1))
	$Overlay/PuzzlePanel/PuzzleFrame/Digit3Up.pressed.connect(_adjust_digit.bind(_digit_3, 1))
	$Overlay/PuzzlePanel/PuzzleFrame/Digit3Down.pressed.connect(_adjust_digit.bind(_digit_3, -1))
	$Overlay/PuzzlePanel/PuzzleFrame/Digit4Up.pressed.connect(_adjust_digit.bind(_digit_4, 1))
	$Overlay/PuzzlePanel/PuzzleFrame/Digit4Down.pressed.connect(_adjust_digit.bind(_digit_4, -1))
	$Overlay/DiaryPanel/DiaryFrame/DiaryClose.pressed.connect(_close_diary_viewer)
	_muted = bool(GameState.data.get("settings", {}).get("muted", false))
	_sync_sound_button()

func _apply_catalog() -> void:
	var catalog: GDScript = preload("res://scripts/ui/game_picture_catalog.gd")
	catalog.apply_scene(get_tree().current_scene)
	catalog.apply_picture(self, "Overlay/PhaseTransitionAnimation/PortraitSequence", catalog.texture("phase_transition_image"))

func _reveal_phase2() -> void:
	GameState.data["flags"].erase("phase2_reveal_pending")
	EventBus.modal_changed.emit(true)
	var reveal: Tween = create_tween()
	reveal.tween_property(_fade, "modulate:a", 0.0, 0.6)
	await reveal.finished
	_fade.hide()
	EventBus.modal_changed.emit(false)

func _open_text(id: String, next_label: String, can_previous: bool) -> void:
	_text_id = id
	_pages = ContentDB.get_fulltext_pages(id)
	_page = 0
	_next_label = next_label
	_can_previous = can_previous
	_reader.hide()
	_scroll.show()
	_reader.self_modulate.a = 1.0
	var reader_color: Color = _reader.color
	reader_color.a = 1.0
	_reader.color = reader_color
	if INVESTIGATION_DIALOGUES.has(id):
		var selection: Array[Variant] = INVESTIGATION_DIALOGUES[id]
		_inspection_dialogue = str(selection[0])
		_dialogue.play_dialogue(_inspection_dialogue, int(selection[1]), int(selection[2]))
		return
	if id in ["ft_balcony_cushion", "ft_wiferoom_entry", "ft_wiferoom_photo_wall", "ft_wiferoom_toy", "ft_wiferoom_computer", "ft_computer_power", "ft_computer_drawer", "ft_computer_notebooks", "ft_computer_unlocked", "ft_folder_games", "ft_folder_social", "ft_folder_bills"]:
		_inspection_dialogue = id
		var lines: Array[Dictionary] = []
		for page: String in _pages:
			for line: String in page.split("\n\n"):
				if not line.is_empty():
					lines.append({"speaker": "protagonist", "text": line})
		_dialogue.play_lines(id, lines)
		return
	_reader.show()
	EventBus.modal_changed.emit(true)
	_refresh_page()

func _dialogue_finished(id: String) -> void:
	if _inspection_dialogue.is_empty():
		EventBus.modal_changed.emit(false)
		EventBus.dialogue_finished.emit(id)
		return
	if id != _inspection_dialogue:
		return
	if id == "dlg_pc_social":
		await _play_social_account_effect()
	_inspection_dialogue = ""
	_page = maxi(0, _pages.size() - 1)
	if not _next_label.is_empty():
		# Reuse editor-authored navigation without the full-screen reading background.
		_scroll.hide()
		var reader_color: Color = _reader.color
		reader_color.a = 0.0
		_reader.color = reader_color
		_reader.show()
		_refresh_page()
	else:
		_close_text()

func _play_social_account_effect() -> void:
	EventBus.audio_cue_requested.emit("sfx_heartbeat")
	_fade.color = Color(0.8, 0.02, 0.02, 1.0)
	_fade.modulate.a = 0.0
	_fade.show()
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "modulate:a", 0.32, 0.2)
	await tween.finished
	await get_tree().create_timer(3.0).timeout
	EventBus.audio_cue_requested.emit("sfx_tinnitus")
	_prompt.text = "我应该告诉她吗？"
	_yes.show()
	_no.show()
	_yes.disabled = true
	_no.disabled = true
	_choice.show()
	EventBus.modal_changed.emit(true)
	await get_tree().create_timer(3.0).timeout
	tween = create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, 0.8)
	await tween.finished
	_choice.hide()
	_yes.disabled = false
	_no.disabled = false
	tween = create_tween()
	tween.tween_property(_fade, "modulate:a", 0.0, 0.8)
	await tween.finished
	_fade.hide()
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade.modulate.a = 1.0
	EventBus.audio_cue_stop_requested.emit("sfx_tinnitus")
	EventBus.modal_changed.emit(false)

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
	var reader_color: Color = _reader.color
	reader_color.a = 1.0
	_reader.color = reader_color
	_text_id = ""
	# Empty ID reports early close; only the last page counts as read.
	EventBus.fulltext_finished.emit(id if _page >= _pages.size() - 1 else "")
	EventBus.modal_changed.emit(false)

func _show_puzzle(puzzle_id: String) -> void:
	_puzzle_id = puzzle_id
	_puzzle_panel.show()
	EventBus.modal_changed.emit(true)

func _show_diary_viewer() -> void:
	var puzzle: Dictionary = ContentDB.get_puzzle("puzzle_diary_password")
	var entries: Array[Dictionary] = []
	entries.assign(puzzle.get("diary_entries", []))
	var diary_text: String = ""
	for entry: Dictionary in entries:
		diary_text += "%s\n%s\n\n" % [str(entry.get("date", "")), str(entry.get("text", ""))]
	_diary_entries.text = diary_text.strip_edges()
	_diary_panel.show()
	EventBus.modal_changed.emit(true)

func _close_diary_viewer() -> void:
	_diary_panel.hide()
	EventBus.modal_changed.emit(false)

func _adjust_digit(digit: Label, amount: int) -> void:
	if _puzzle_id.is_empty():
		return
	var next_value: int = int(digit.text) + amount
	if next_value > 9:
		next_value = 0
	elif next_value < 0:
		next_value = 9
	digit.text = str(next_value)

func _submit_puzzle() -> void:
	var answer: String = _digit_1.text + _digit_2.text + _digit_3.text + _digit_4.text
	EventBus.puzzle_submitted.emit(_puzzle_id, answer)
	var puzzle: Dictionary = ContentDB.get_puzzle(_puzzle_id)
	if answer == str(puzzle.get("answer", "")):
		_close_puzzle()
	else:
		_show_toast("密码错误")

func _close_puzzle() -> void:
	_puzzle_panel.hide()
	_puzzle_id = ""
	EventBus.modal_changed.emit(false)

func _show_choice(event_id: String, choice: Dictionary) -> void:
	_event_id = event_id
	_prompt.text = str(choice.get("prompt", ""))
	if event_id in ["event_usb_truth", "event_webnovel_truth"]:
		_global_save.position = _choice.position + Vector2(_choice.size.x - _global_save.size.x - 30.0, 30.0)
	_choice.show()
	EventBus.modal_changed.emit(true)

func _choose(option: String) -> void:
	_choice.hide()
	_global_save.position = _global_save_default_position
	EventBus.choice_made.emit(_event_id, option)

func _show_toast(message: String) -> void:
	_toast_queue.append(message)
	if _timer.is_stopped():
		_pop_toast()

func _on_modal_changed(blocked: bool) -> void:
	_sound_button.visible = not blocked

func _toggle_sound() -> void:
	EventBus.audio_mute_requested.emit(not _muted)

func _on_audio_mute_changed(muted: bool) -> void:
	_muted = muted
	_sync_sound_button()

func _sync_sound_button() -> void:
	_sound_label.text = "音效：关" if _muted else "音效：开"

func _pop_toast() -> void:
	if _toast_queue.is_empty():
		_toast.hide()
		return
	_toast.text = _toast_queue.pop_front()
	_toast.show()
	_timer.start()

func _command(id: String) -> void:
	if id == "doorbell_blackout":
		EventBus.modal_changed.emit(true)
		_fade.color = Color.BLACK
		_fade.modulate.a = 1.0
		_fade.show()
		EventBus.audio_cue_requested.emit("sfx_doorbell")
		var doorbell: AudioStream = AudioManager.doorbell
		var duration: float = doorbell.get_length() if doorbell != null else 3.0
		await get_tree().create_timer(maxf(duration, 0.1)).timeout
		_fade.hide()
		EventBus.modal_changed.emit(false)
	if id == "doorbell":
		EventBus.audio_cue_requested.emit("sfx_doorbell")
	if id == "phase1_end_black_flash":
		EventBus.modal_changed.emit(true)
		_fade.color = Color.BLACK
		_fade.modulate.a = 0.0
		_fade.show()
		var transition_tween: Tween = create_tween()
		transition_tween.tween_property(_fade, "modulate:a", 1.0, 0.6)
		await transition_tween.finished
	if id == "black_flash":
		_fade.modulate.a = 1.0
		_fade.show()
		await get_tree().create_timer(0.1).timeout
		_fade.hide()
	if id == "black_fade":
		_fade.color = Color(0.0, 0.0, 0.0, 1.0)
		_fade.modulate.a = 0.0
		_fade.show()
		var fade_tween: Tween = create_tween()
		fade_tween.tween_property(_fade, "modulate:a", 1.0, 0.6)
		await fade_tween.finished
		_fade.hide()
	if id == "black_reveal":
		_fade.color = Color(0.0, 0.0, 0.0, 1.0)
		_fade.modulate.a = 1.0
		_fade.show()
		var reveal_tween: Tween = create_tween()
		reveal_tween.tween_property(_fade, "modulate:a", 0.0, 0.6)
		await reveal_tween.finished
		_fade.hide()
	EventBus.command_finished.emit(id)

func _transition(id: String) -> void:
	if id == "phase1_end":
		_fade.modulate.a = 0.0
		_fade.show()
		var tween: Tween = create_tween()
		tween.tween_property(_fade, "modulate:a", 1.0, 0.25)
		await tween.finished
		await get_tree().create_timer(0.2).timeout
		tween = create_tween()
		tween.tween_property(_fade, "modulate:a", 0.0, 0.25)
		await tween.finished
		_fade.hide()
	EventBus.transition_finished.emit(id)

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
