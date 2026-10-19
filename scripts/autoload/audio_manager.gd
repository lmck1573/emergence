extends Node
## Audio resources are assigned on the AudioManager scene in the editor.

@export_group("Background Music")
@export var title_bgm: AudioStream
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
@export var doorbell: AudioStream
@export var fire: AudioStream
@export var door_open: AudioStream
@export var park: AudioStream
@export var birds: AudioStream
@export var restaurant: AudioStream
@export var phone_ring: AudioStream
@export var phone_answer: AudioStream
@export var knock: AudioStream

@onready var _bgm_player: AudioStreamPlayer = $BGM
@onready var _effect_player: AudioStreamPlayer = $Effect
@onready var _ui_player: AudioStreamPlayer = $UI
@onready var _character_player: AudioStreamPlayer = $Character

var _muted: bool = false
var _game_started: bool = false
var _phase_bgm_started: int = 0
var _active_bgm_id: String = ""
var _last_cue: String = ""
var _last_cue_msec: int = -1000
var _active_effect_id: String = ""
var _bgm_tween: Tween

func _ready() -> void:
	_muted = bool(GameState.data.get("settings", {}).get("muted", false))
	AudioServer.set_bus_mute(0, _muted)
	_bgm_player.finished.connect(_on_bgm_finished)
	get_tree().scene_changed.connect(_on_scene_changed)
	get_tree().node_added.connect(_on_node_added)
	EventBus.audio_cue_requested.connect(play_cue)
	EventBus.audio_cue_stop_requested.connect(stop_cue)
	EventBus.character_sound_requested.connect(play_character)
	EventBus.phase_bgm_requested.connect(play_phase_bgm)
	EventBus.audio_mute_requested.connect(set_muted)
	EventBus.game_started.connect(begin_game)
	EventBus.state_changed.connect(_sync_phase2_background)
	EventBus.feed_requested.connect(func(_id: String) -> void: play_cue("sfx_feed"))
	EventBus.choice_made.connect(func(_id: String, _option: String) -> void: play_cue("sfx_choice"))
	EventBus.toast_requested.connect(func(_message: String) -> void: play_cue("sfx_toast"))
	_wire_scene_buttons.call_deferred()

func is_muted() -> bool:
	return _muted

func stop_bgm() -> void:
	if _bgm_tween != null and _bgm_tween.is_running():
		_bgm_tween.kill()
	_bgm_player.stop()
	_active_bgm_id = ""

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
	var saved_phase: int = int(GameState.data["flags"].get("phase_bgm_started", 0))
	_phase_bgm_started = saved_phase if saved_phase == GameState.get_current_phase() else 0
	if _phase_bgm_started > 0:
		play_bgm("bgm_phase_%d" % _phase_bgm_started)

func play_phase_bgm(phase: int) -> void:
	if phase < 1 or phase > 3:
		return
	stop_bgm()
	_phase_bgm_started = 0
	GameState.data["flags"].erase("phase_bgm_started")
	GameState.commit()

func play_bgm(bgm_id: String) -> void:
	if _phase2_white_noise_only() and bgm_id == "bgm_phase_2":
		bgm_id = "bgm_title"
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
	if not _muted and _bgm_player.stream != null and (_game_started or _active_bgm_id == "bgm_title"):
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
	if player == _effect_player:
		_active_effect_id = cue_id

func stop_cue(cue_id: String) -> void:
	if cue_id == _active_effect_id:
		_effect_player.stop()
		_active_effect_id = ""

func _on_scene_changed() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	if not _game_started:
		return
	if scene.scene_file_path == "res://scenes/ui/start_screen.tscn":
		_game_started = false
		_phase_bgm_started = 0
		return
	var phase: int = GameState.get_current_phase()
	var path: String = scene.scene_file_path
	if _phase2_white_noise_only():
		_sync_phase2_background()
	elif phase <= 2 and path in ["res://scenes/ui/ai_interface.tscn", "res://scenes/ui/ai_interface_phase2.tscn"] and _phase_bgm_started != phase:
		play_bgm("bgm_title")
	elif phase == 1 and path.begins_with("res://scenes/explore/") and path != "res://scenes/explore/house_overview.tscn":
		_start_phase_bgm(phase)
	elif phase == 2 and path == "res://scenes/explore/wife_room.tscn":
		_start_phase_bgm(phase)
	elif phase == 3 and path == "res://scenes/explore/phase3_livingroom.tscn":
		_start_phase_bgm(phase)
	_wire_scene_buttons.call_deferred()

func _phase2_white_noise_only() -> bool:
	return GameState.get_current_phase() == 2 and GameState.is_event_completed("event_diary_password_hint")

func _sync_phase2_background() -> void:
	if _phase2_white_noise_only() and _active_bgm_id != "bgm_title":
		stop_bgm()
		play_bgm("bgm_title")

func _start_phase_bgm(phase: int) -> void:
	if _phase_bgm_started == phase:
		return
	_phase_bgm_started = phase
	GameState.data["flags"]["phase_bgm_started"] = phase
	GameState.commit()
	play_bgm("bgm_phase_%d" % phase)

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
	if button.name not in ["AgreementButton", "GuideButton"] and not button.has_meta("preserve_button_background"):
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = Color(27.0 / 255.0, 110.0 / 255.0, 247.0 / 255.0, 0.5)
			button.add_theme_stylebox_override(state, style)
	button.mouse_entered.connect(func() -> void: EventBus.audio_cue_requested.emit("sfx_hover"))
	button.pressed.connect(func() -> void: EventBus.audio_cue_requested.emit("sfx_click"))

func _get_bgm(bgm_id: String) -> AudioStream:
	match bgm_id:
		"bgm_title": return title_bgm
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
		"sfx_doorbell": return doorbell
		"sfx_fire": return fire
		"sfx_door_open": return door_open
		"sfx_park": return park
		"sfx_birds": return birds
		"sfx_restaurant": return restaurant
		"sfx_phone_ring": return phone_ring
		"sfx_phone_answer": return phone_answer
		"sfx_knock": return knock
	return null
