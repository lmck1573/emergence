extends Node
## Audio resources are assigned on the AudioManager scene in the editor.

@export_group("Background Music")
@export var phase_one_bgm: AudioStream
@export var phase_two_bgm: AudioStream
@export var phase_three_bgm: AudioStream

@export_group("Dialogue")
@export var protagonist_character: AudioStream
@export var ai_character: AudioStream
@export var system_character: AudioStream

@export_group("Interface")
@export var ui_hover: AudioStream
@export var ui_click: AudioStream
@export var feed: AudioStream
@export var choice: AudioStream
@export var save_cue: AudioStream
@export var toast: AudioStream

@export_group("Scene Effects")
@export var floorboard_creak: AudioStream
@export var window_creak: AudioStream
@export var lounger_rock: AudioStream
@export var fridge_open: AudioStream
@export var heartbeat: AudioStream
@export var tinnitus: AudioStream
@export var puzzle_correct: AudioStream
@export var puzzle_wrong: AudioStream

@onready var _bgm_player: AudioStreamPlayer = $BGM
@onready var _effect_player: AudioStreamPlayer = $Effect
@onready var _ui_player: AudioStreamPlayer = $UI
@onready var _character_player: AudioStreamPlayer = $Character

var _muted: bool = false
var _game_started: bool = false
var _remaining_transitions: int = 0
var _pending_phase: int = 0
var _active_bgm_id: String = ""
var _last_cue: String = ""
var _last_cue_msec: int = -1000
var _bgm_tween: Tween

func _ready() -> void:
	_muted = bool(GameState.data.get("settings", {}).get("muted", false))
	AudioServer.set_bus_mute(0, _muted)
	_bgm_player.finished.connect(_on_bgm_finished)
	get_tree().scene_changed.connect(_on_scene_changed)
	get_tree().node_added.connect(_on_node_added)
	EventBus.audio_cue_requested.connect(play_cue)
	EventBus.character_sound_requested.connect(play_character)
	EventBus.phase_bgm_requested.connect(play_phase_bgm)
	EventBus.audio_mute_requested.connect(set_muted)
	EventBus.game_started.connect(begin_game)
	EventBus.feed_requested.connect(func(_id: String) -> void: play_cue("sfx_feed"))
	EventBus.choice_made.connect(func(_id: String, _option: String) -> void: play_cue("sfx_choice"))
	EventBus.toast_requested.connect(func(_message: String) -> void: play_cue("sfx_toast"))
	_wire_scene_buttons.call_deferred()

func is_muted() -> bool:
	return _muted

func set_muted(value: bool) -> void:
	if _muted == value:
		return
	_muted = value
	AudioServer.set_bus_mute(0, value)
	GameState.data["settings"]["muted"] = value
	GameState.commit()
	EventBus.audio_mute_changed.emit(value)
	if not value and not _active_bgm_id.is_empty():
		play_bgm(_active_bgm_id)

func begin_game() -> void:
	_game_started = true
	_pending_phase = GameState.get_current_phase()
	_remaining_transitions = randi_range(1, 2)
	_active_bgm_id = ""
	_bgm_player.stop()

func play_phase_bgm(phase: int) -> void:
	if phase < 1 or phase > 3:
		return
	play_bgm("bgm_phase_%d" % phase)

func play_bgm(bgm_id: String) -> void:
	var stream: AudioStream = _get_bgm(bgm_id)
	if stream == null:
		return
	_active_bgm_id = bgm_id
	if _muted:
		return
	if _bgm_player.stream == stream and _bgm_player.playing:
		return
	if _bgm_tween != null and _bgm_tween.is_running():
		_bgm_tween.kill()
	if _bgm_player.playing:
		_bgm_tween = create_tween()
		_bgm_tween.tween_property(_bgm_player, "volume_db", -50.0, 0.25)
		_bgm_tween.tween_callback(_start_bgm.bind(stream))
	else:
		_start_bgm(stream)

func _start_bgm(stream: AudioStream) -> void:
	_bgm_player.stream = stream
	_bgm_player.volume_db = -30.0
	_bgm_player.play()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_player, "volume_db", 0.0, 0.25)

func _on_bgm_finished() -> void:
	if _game_started and not _muted and _bgm_player.stream != null:
		_bgm_player.play()

func play_character(speaker: String) -> void:
	if _muted:
		return
	var stream: AudioStream
	match speaker:
		"protagonist": stream = protagonist_character
		"ai": stream = ai_character
		"system": stream = system_character
	if stream == null:
		return
	_character_player.stream = stream
	_character_player.play()

func play_cue(cue_id: String) -> void:
	if _muted:
		return
	var now: int = Time.get_ticks_msec()
	if cue_id == _last_cue and now - _last_cue_msec < 100:
		return
	_last_cue = cue_id
	_last_cue_msec = now
	var stream: AudioStream = _get_cue(cue_id)
	if stream == null:
		return
	var player: AudioStreamPlayer = _ui_player if cue_id == "sfx_hover" or cue_id == "sfx_click" else _effect_player
	player.stream = stream
	player.play()

func _on_scene_changed() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	if not _game_started:
		return
	if scene.scene_file_path == "res://scenes/ui/start_screen.tscn":
		_game_started = false
		_pending_phase = 0
		_active_bgm_id = ""
		_bgm_player.stop()
		return
	if _pending_phase == 0:
		return
	_remaining_transitions -= 1
	if _remaining_transitions <= 0:
		play_bgm("bgm_phase_%d" % _pending_phase)
		_pending_phase = 0
	_wire_scene_buttons.call_deferred()

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_wire_button(node as BaseButton)

func _wire_scene_buttons() -> void:
	var scene: Node = get_tree().current_scene
	if scene != null:
		_wire_buttons_recursive(scene)

func _wire_buttons_recursive(node: Node) -> void:
	if node is BaseButton:
		_wire_button(node as BaseButton)
	for child: Node in node.get_children():
		_wire_buttons_recursive(child)

func _wire_button(button: BaseButton) -> void:
	if button.has_meta("audio_manager_wired"):
		return
	button.set_meta("audio_manager_wired", true)
	button.mouse_entered.connect(func() -> void: EventBus.audio_cue_requested.emit("sfx_hover"))
	button.pressed.connect(func() -> void: EventBus.audio_cue_requested.emit("sfx_click"))

func _get_bgm(bgm_id: String) -> AudioStream:
	match bgm_id:
		"bgm_phase_1": return phase_one_bgm
		"bgm_phase_2": return phase_two_bgm
		"bgm_phase_3": return phase_three_bgm
	return null

func _get_cue(cue_id: String) -> AudioStream:
	match cue_id:
		"sfx_hover": return ui_hover
		"sfx_click": return ui_click
		"sfx_feed": return feed
		"sfx_choice": return choice
		"sfx_save": return save_cue
		"sfx_toast": return toast
		"sfx_floorboard_creak": return floorboard_creak
		"sfx_window_creak": return window_creak
		"sfx_lounger_rock": return lounger_rock
		"sfx_fridge_open": return fridge_open
		"sfx_heartbeat": return heartbeat
		"sfx_tinnitus": return tinnitus
		"sfx_puzzle_correct": return puzzle_correct
		"sfx_puzzle_wrong": return puzzle_wrong
	return null
