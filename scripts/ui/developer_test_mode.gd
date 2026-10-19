extends Node
## Hidden K-key narrative jump panel. Remove this script and its StoryUI hook for release builds.

var _root: Control
var _target: OptionButton
var _truth_value: SpinBox
var _blocked: bool = false

func _ready() -> void:
	set_process_unhandled_key_input(true)
	_build_panel()
	EventBus.modal_changed.connect(_on_modal_changed)
	if bool(GameState.data["flags"].get("developer_test_pending", false)):
		GameState.data["flags"].erase("developer_test_pending")
		GameState.commit()
		EventBus.modal_changed.emit(false)

func _unhandled_key_input(event: InputEvent) -> void:
	if _blocked or not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_K:
		_root.visible = not _root.visible
		EventBus.modal_changed.emit(_root.visible)
		get_viewport().set_input_as_handled()

func _build_panel() -> void:
	_root = Control.new()
	_root.name = "DeveloperTestMode"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.z_index = 100
	_root.hide()
	get_parent().add_child(_root)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(backdrop)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-270.0, -205.0)
	panel.size = Vector2(540.0, 410.0)
	panel.custom_minimum_size = panel.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(panel)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)

	var title: Label = Label.new()
	title.text = "开发者测试跳转"
	layout.add_child(title)

	var target_label: Label = Label.new()
	target_label.text = "跳转位置"
	layout.add_child(target_label)

	_target = OptionButton.new()
	_target.add_item("第一阶段：U盘话题已解锁，进入 AI 界面")
	_target.add_item("第二阶段开始：新话题尚未完成")
	_target.add_item("第二阶段：电脑密码输入前")
	_target.add_item("第二阶段结束前：投喂网文记录之前")
	_target.add_item("第三阶段开始：女主回家，两个话题已解锁")
	layout.add_child(_target)

	var truth_label: Label = Label.new()
	truth_label.text = "真相暴露度（truth_revealed）"
	layout.add_child(truth_label)

	_truth_value = SpinBox.new()
	_truth_value.min_value = 0.0
	_truth_value.max_value = 999.0
	_truth_value.step = 1.0
	_truth_value.value = float(GameState.get_truth())
	layout.add_child(_truth_value)

	var actions: HBoxContainer = HBoxContainer.new()
	layout.add_child(actions)
	var jump_button: Button = Button.new()
	jump_button.text = "跳转"
	jump_button.modulate = Color(0.45, 0.7, 1, 1)
	jump_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jump_button.custom_minimum_size = Vector2(150.0, 50.0)
	jump_button.mouse_filter = Control.MOUSE_FILTER_STOP
	jump_button.pressed.connect(_jump_to_selected_milestone)
	actions.add_child(jump_button)
	var close_button: Button = Button.new()
	close_button.text = "关闭"
	close_button.modulate = Color(0.45, 0.7, 1, 1)
	close_button.custom_minimum_size = Vector2(150.0, 50.0)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(_close_panel)
	actions.add_child(close_button)

func _on_modal_changed(blocked: bool) -> void:
	_blocked = blocked

func _close_panel() -> void:
	_root.hide()
	EventBus.modal_changed.emit(false)

func _jump_to_selected_milestone() -> void:
	var state: Dictionary = SaveManager.default_state()
	var phase2_start: bool = _target.selected == 1
	var password_checkpoint: bool = _target.selected == 2
	var webnovel_checkpoint: bool = _target.selected == 3
	var reunion_checkpoint: bool = _target.selected == 4
	var target_phase: int = 2 if phase2_start or password_checkpoint or webnovel_checkpoint else 1
	if reunion_checkpoint:
		target_phase = 3
	state["phase"] = target_phase
	state["truth_revealed"] = int(_truth_value.value)
	state["completeness"] = 40.0 if password_checkpoint or webnovel_checkpoint else 0.0
	state["flags"]["developer_test_pending"] = true
	if reunion_checkpoint:
		state["current_scene"] = "phase3_livingroom"
		state["completeness"] = 80.0
		state["events_completed"] = ["event_phase1_end", "event_act3_start"]
		state["regions_unlocked"] = ["phase3_livingroom"]
	elif phase2_start:
		state["current_scene"] = "ai_interface"
		state["regions_unlocked"] = ["ai_interface", "house_overview"]
		state["events_completed"].append("event_phase1_end")
		state["events_completed"].append("event_phase1_usb_topic")
		state["topics_unlocked"] = ["topic_usb", "topic_new_appearance", "topic_new_stage"]
		state["topics_completed"] = ["topic_usb"]
		state["contents_obtained"] = ["work_usb"]
		state["flags"]["pending_grant_toasts"] = ["获得对话：新的外貌", "获得对话：新的阶段"]
	elif password_checkpoint:
		state["current_scene"] = "computer_desk"
		state["regions_unlocked"] = ["ai_interface", "house_overview", "wife_room"]
		state["events_completed"].append("event_phase1_end")
		state["events_completed"].append("event_unlock_wife_room")
		state["events_completed"].append("event_phase1_usb_topic")
		state["topics_unlocked"] = ["topic_usb", "topic_new_appearance", "topic_new_stage", "topic_travel", "topic_locked_computer"]
		state["topics_completed"] = ["topic_usb", "topic_new_appearance", "topic_new_stage", "topic_locked_computer"]
		state["contents_obtained"] = ["hobby_travel", "hobby_plush", "work_diary"]
		state["contents_fed"] = ["hobby_travel", "hobby_plush", "work_diary"]
		state["flags"]["wife_room_entered"] = true
		state["flags"]["pending_ai_dialogue"] = ""
		state["regions_unlocked"].append("computer_desk")
		state["player_choices"]["event_usb_truth"] = "yes"
	elif webnovel_checkpoint:
		state["current_scene"] = "ai_interface_phase2"
		state["regions_unlocked"] = ["ai_interface", "house_overview", "wife_room", "computer_desk"]
		state["events_completed"] = ["event_phase1_end", "event_phase1_usb_topic", "event_unlock_wife_room", "event_diary_password_hint", "event_computer_unlocked"]
		state["topics_unlocked"] = ["topic_usb", "topic_new_appearance", "topic_new_stage", "topic_travel", "topic_locked_computer", "topic_locked_drawer", "topic_handwriting", "topic_games", "topic_writing"]
		state["topics_completed"] = ["topic_usb", "topic_new_appearance", "topic_new_stage", "topic_travel", "topic_locked_computer", "topic_locked_drawer", "topic_handwriting", "topic_games"]
		state["contents_obtained"] = ["hobby_travel", "hobby_plush", "work_diary", "hobby_games", "work_chat_records", "exp_bills"]
		state["contents_fed"] = ["hobby_travel", "hobby_plush", "work_diary", "hobby_games", "work_chat_records", "exp_bills"]
		state["player_choices"].erase("event_webnovel_truth")
		state["topics_completed"].erase("topic_writing")
		state["flags"]["wife_room_entered"] = true
		state["puzzles"]["puzzle_diary_password"] = {"unlocked": true, "completed": true}
	else:
		state["current_scene"] = "ai_interface"
		state["regions_unlocked"] = ["ai_interface", "house_overview"]
		state["events_completed"].append("event_phase1_usb_topic")
		state["contents_obtained"] = ["work_usb"]
		state["topics_unlocked"] = ["topic_usb"]
	GameState.data = state
	var destination: String = "res://scenes/explore/computer_desk.tscn" if password_checkpoint else "res://scenes/ui/ai_interface.tscn"
	if phase2_start or webnovel_checkpoint:
		destination = "res://scenes/ui/ai_interface_phase2.tscn"
	if reunion_checkpoint:
		destination = "res://scenes/explore/phase3_livingroom.tscn"
	get_tree().change_scene_to_file(destination)
