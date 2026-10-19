extends Control
class_name Act3View
## Single-image stage, click targets and ending presentation.
## The active scene interaction was clicked.
signal activated
## The private-room decision was selected.
signal decision(value: String)
var picture: TextureRect
var target: Button
var leave: Button
var yes: Button
var no: Button
var caption: Label
var _cover: ColorRect
var _choice_backdrop: ColorRect
var _target_style: StyleBoxFlat

func _ready() -> void:
	add_to_group("act3_test_view")
	position = Vector2(480, 60)
	size = Vector2(960, 960)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture = TextureRect.new()
	picture.size = size
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	_cover = ColorRect.new()
	_cover.size = size
	_cover.color = Color.BLACK
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cover)
	target = Button.new()
	target.position = Vector2(455, 525)
	target.size = Vector2(50, 50)
	_target_style = StyleBoxFlat.new()
	_target_style.bg_color = Color(27.0 / 255.0, 110.0 / 255.0, 247.0 / 255.0, 0.5)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		target.add_theme_stylebox_override(state, _target_style)
	target.set_meta("preserve_button_background", true)
	target.pressed.connect(func() -> void: activated.emit())
	add_child(target)
	leave = _button("◀", Vector2(40, 40))
	leave.alignment = HORIZONTAL_ALIGNMENT_CENTER
	leave.pressed.connect(func() -> void: activated.emit())
	caption = Label.new()
	caption.size = size
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 28)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	_choice_backdrop = ColorRect.new()
	_choice_backdrop.size = size
	_choice_backdrop.color = Color(0.05, 0.05, 0.06, 0.95)
	_choice_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_choice_backdrop.z_index = 1
	add_child(_choice_backdrop)
	yes = _button("是", Vector2(350, 550))
	no = _button("否", Vector2(550, 550))
	yes.z_index = 2
	no.z_index = 2
	caption.z_index = 2
	caption.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 1))
	yes.pressed.connect(func() -> void: decision.emit("yes"))
	no.pressed.connect(func() -> void: decision.emit("no"))
	clear_controls()
	EventBus.modal_changed.connect(_modal)

func _button(label: String, at: Vector2) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.position = at
	button.size = Vector2(70, 50)
	button.modulate = Color(0.45, 0.7, 1.0, 1.0)
	add_child(button)
	return button

func clear_controls() -> void:
	target.hide()
	leave.hide()
	yes.hide()
	no.hide()
	_choice_backdrop.hide()
	caption.text = ""

func show_image(path: String) -> void:
	show_texture(load(path) as Texture2D)

func show_texture(texture: Texture2D) -> void:
	picture.texture = texture
	_cover.hide()
	clear_controls()

func black() -> void:
	_cover.show()
	clear_controls()

func show_target(label: String, at: Vector2 = Vector2(455, 525)) -> void:
	target.tooltip_text = label
	target.position = at
	target.size = Vector2(50, 50)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		target.add_theme_stylebox_override(state, _target_style)
	if label == "电脑": target.position = Vector2(640, 500)
	if label == "抽屉": target.position = Vector2(670, 680)
	if label == "笔记本": target.position = Vector2(380, 590)
	target.show()

func show_continue_area() -> void:
	var transparent_style: StyleBoxFlat = StyleBoxFlat.new()
	transparent_style.bg_color = Color(0, 0, 0, 0)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		target.add_theme_stylebox_override(state, transparent_style)
	target.position = Vector2.ZERO
	target.size = size
	target.tooltip_text = ""
	target.show()

func _modal(blocked: bool) -> void:
	target.disabled = blocked
	leave.disabled = blocked
	yes.disabled = blocked
	no.disabled = blocked
