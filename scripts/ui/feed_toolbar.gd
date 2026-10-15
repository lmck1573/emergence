extends Control
## Persistent feed toolbar for the AI interface.

const TYPE_LABELS: Dictionary = {
	"hobby": "爱好",
	"exp": "经历",
	"work": "作品",
	"clue": "线索",
	"topic": "话题",
}
const TYPE_MARKS: Dictionary = {
	"hobby": "爱",
	"exp": "经",
	"work": "作",
	"clue": "线",
	"topic": "话",
}
const TYPE_COLORS: Dictionary = {
	"hobby": Color("#78c7b8"),
	"exp": Color("#e3a76f"),
	"work": Color("#84a8dc"),
	"clue": Color("#d77e79"),
	"topic": Color("#c1a3d9"),
}
const TILE_SIZE: Vector2 = Vector2(68, 68)
const ITEMS_PER_COLUMN: int = 8

var _game_state: Node
var _left_items: VBoxContainer
var _right_items: VBoxContainer
var _history_panel: PanelContainer
var _history_rows: VBoxContainer
var _history_toggle: Button
var _progress_label: Label
var _progress_bar: ProgressBar


func _ready() -> void:
	_game_state = get_node_or_null("/root/GameState")
	_build_interface()
	if _game_state == null:
		push_error("FeedToolbar requires /root/GameState")
		return
	_game_state.connect("feed_state_changed", _on_feed_state_changed)
	_game_state.connect("content_obtained", _on_collection_changed)
	_game_state.connect("topic_unlocked", _on_collection_changed)
	_game_state.connect("feed_progress_changed", _on_feed_progress_changed)
	_refresh_all()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var toolbar := PanelContainer.new()
	toolbar.name = "FeedToolbar"
	toolbar.position = Vector2(24, 72)
	toolbar.mouse_filter = Control.MOUSE_FILTER_STOP
	toolbar.add_theme_stylebox_override("panel", _panel_style(Color("#202a31")))
	add_child(toolbar)

	var toolbar_content := VBoxContainer.new()
	toolbar_content.add_theme_constant_override("separation", 9)
	toolbar.add_child(toolbar_content)

	var heading := Label.new()
	heading.text = "投喂"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color("#e8eee9"))
	heading.add_theme_font_size_override("font_size", 16)
	toolbar_content.add_child(heading)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 8)
	toolbar_content.add_child(columns)
	_left_items = VBoxContainer.new()
	_left_items.add_theme_constant_override("separation", 6)
	columns.add_child(_left_items)
	_right_items = VBoxContainer.new()
	_right_items.add_theme_constant_override("separation", 6)
	columns.add_child(_right_items)

	_history_toggle = Button.new()
	_history_toggle.name = "HistoryToggle"
	_history_toggle.text = "历史投喂  v"
	_history_toggle.tooltip_text = "展开或收起历史投喂记录"
	_history_toggle.custom_minimum_size = Vector2(146, 34)
	_history_toggle.pressed.connect(_toggle_history)
	toolbar_content.add_child(_history_toggle)

	_history_panel = PanelContainer.new()
	_history_panel.name = "FeedHistory"
	_history_panel.visible = false
	_history_panel.custom_minimum_size = Vector2(0, 0)
	_history_panel.add_theme_stylebox_override("panel", _panel_style(Color("#26343b")))
	toolbar_content.add_child(_history_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(150, 220)
	_history_panel.add_child(scroll)
	_history_rows = VBoxContainer.new()
	_history_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_history_rows)

	var progress_panel := PanelContainer.new()
	progress_panel.name = "FeedProgress"
	progress_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	progress_panel.offset_left = -292
	progress_panel.offset_top = -86
	progress_panel.offset_right = -24
	progress_panel.offset_bottom = -24
	progress_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_panel.add_theme_stylebox_override("panel", _panel_style(Color("#202a31")))
	add_child(progress_panel)
	var progress_content := VBoxContainer.new()
	progress_content.add_theme_constant_override("separation", 5)
	progress_panel.add_child(progress_content)
	_progress_label = Label.new()
	_progress_label.text = "第1阶段投喂进度  0 / 0"
	_progress_label.add_theme_color_override("font_color", Color("#e8eee9"))
	progress_content.add_child(_progress_label)
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(238, 12)
	_progress_bar.show_percentage = false
	progress_content.add_child(_progress_bar)


func _refresh_all() -> void:
	_refresh_items()
	_refresh_history()
	_refresh_progress()


func _refresh_items() -> void:
	_clear_children(_left_items)
	_clear_children(_right_items)
	var items: Array[Dictionary] = _game_state.call("get_feedable_items")
	for index: int in range(items.size()):
		var item: Dictionary = items[index]
		var parent: VBoxContainer = _left_items if index < ITEMS_PER_COLUMN else _right_items
		parent.add_child(_make_feed_button(item))


func _make_feed_button(item: Dictionary) -> Button:
	var item_id: String = str(item.get("item_id", ""))
	var item_type: String = str(item.get("item_type", ""))
	var display_name: String = str(item.get("display_name", item_id))
	var type_label: String = TYPE_LABELS.get(item_type, item_type)
	var button := Button.new()
	button.name = "Feed_" + item_id
	button.text = TYPE_MARKS.get(item_type, "物")
	button.tooltip_text = "%s\n%s" % [display_name, type_label]
	button.custom_minimum_size = TILE_SIZE
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color("#f1f4ef"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_stylebox_override("normal", _tile_style(Color("#303c43"), TYPE_COLORS.get(item_type, Color("#9bb1a6"))))
	button.add_theme_stylebox_override("hover", _tile_style(Color("#3d4d54"), TYPE_COLORS.get(item_type, Color("#9bb1a6"))))
	button.add_theme_stylebox_override("pressed", _tile_style(Color("#263239"), TYPE_COLORS.get(item_type, Color("#9bb1a6"))))
	button.pressed.connect(_on_feed_button_pressed.bind(item_id))
	return button


func _refresh_history() -> void:
	_clear_children(_history_rows)
	var history: Array[Dictionary] = _game_state.call("get_feed_history")
	for entry: Dictionary in history:
		var row := Label.new()
		var type_label: String = TYPE_LABELS.get(str(entry.get("type", "")), str(entry.get("type", "")))
		row.text = "%s\n%s  ·  第%s阶段" % [entry.get("display_name", entry.get("item_id", "")), type_label, entry.get("feed_stage", "")]
		row.tooltip_text = str(entry.get("fed_at", ""))
		row.custom_minimum_size = Vector2(142, 42)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_theme_color_override("font_color", Color("#d6dfda"))
		_history_rows.add_child(row)


func _refresh_progress() -> void:
	var progress: Dictionary = _game_state.call("get_feed_progress")
	var stage: int = int(progress.get("feed_stage", 1))
	var fed: int = int(progress.get("fed_count", 0))
	var total: int = int(progress.get("total_count", 0))
	_progress_label.text = "第%s阶段投喂进度  %s / %s" % [stage, fed, total]
	_progress_bar.max_value = maxf(1.0, float(total))
	_progress_bar.value = fed


func _on_feed_button_pressed(item_id: String) -> void:
	if _game_state.call("feed_item", item_id):
		_refresh_all()


func _on_feed_state_changed(_item_id: String) -> void:
	_refresh_all()


func _on_collection_changed(_item_id: String) -> void:
	_refresh_items()


func _on_feed_progress_changed(_stage: int, _fed: int, _total: int) -> void:
	_refresh_progress()


func _toggle_history() -> void:
	_history_panel.visible = not _history_panel.visible
	_history_toggle.text = "历史投喂  ^" if _history_panel.visible else "历史投喂  v"
	_refresh_history()


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _panel_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color("#52636a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	return style


func _tile_style(background: Color, accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(4)
	return style
