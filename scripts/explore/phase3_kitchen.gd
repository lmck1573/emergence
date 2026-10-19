extends Control
## Third-phase kitchen landing scene.

@export_group("统一画面：封面与动画")
@export var title_image: Texture2D
@export var title_animation: Array[Texture2D] = []
@export var ai_eye_animation: Array[Texture2D] = []
@export var phase_transition_image: Texture2D
@export_group("统一画面：地图与房间特写")
@export var house_overview: Texture2D
@export var livingroom: Texture2D
@export var kitchen: Texture2D
@export var balcony: Texture2D
@export var master_bedroom: Texture2D
@export var wife_room: Texture2D
@export var computer_desk: Texture2D
@export_group("第二阶段电脑CG")
@export var computer_locked: Texture2D
@export var computer_unlocked: Texture2D
@export_group("统一画面：AI界面")
@export var ai_phase2: Texture2D
@export_group("统一画面：第三阶段场景（留空沿用房间图）")
@export var phase3_livingroom: Texture2D
@export var phase3_kitchen: Texture2D
@export var phase3_balcony: Texture2D
@export var phase3_master_bedroom: Texture2D
@export var phase3_wife_room: Texture2D
@export var phase3_computer_desk: Texture2D
@export var phase3_computer_black: Texture2D
@export var phase3_cultivation: Texture2D
@export var reunion: Texture2D

@export_group("结局CG：堪称执念的爱")
@export var burning_room: Texture2D
@export_group("结局CG：新的生命")
@export var break_journal_lock: Texture2D
@export var break_drawer_lock: Texture2D
@export var opened_journal: Texture2D
@export_group("真结局CG：手机回忆")
@export var phone_year4: Texture2D
@export var phone_march: Texture2D
@export_group("真结局CG：公园")
@export var park_lake: Texture2D
@export var park_turn: Texture2D
@export var park_birds: Texture2D
@export var park_face: Texture2D
@export_group("真结局CG：餐厅与酒店")
@export var restaurant: Texture2D
@export var hotel_night: Texture2D
@export var hotel_day: Texture2D
@export var restaurant_usb: Texture2D
@export_group("真结局CG：抽屉")
@export var divorce_drawer: Texture2D

@onready var _save_button: Button = $GameArea/SaveButton
var _blocked: bool = false


func _ready() -> void:
	$GameArea.hide()
	var director: Node = preload("res://scripts/events/act3_director.gd").new()
	director.set("cg_textures", {
		"burning_room": burning_room,
		"break_journal_lock": break_journal_lock,
		"break_drawer_lock": break_drawer_lock,
		"opened_journal": opened_journal,
		"phone_year4": phone_year4,
		"phone_march": phone_march,
		"park_lake": park_lake,
		"park_turn": park_turn,
		"park_birds": park_birds,
		"park_face": park_face,
		"restaurant": restaurant,
		"hotel_night": hotel_night,
		"hotel_day": hotel_day,
		"restaurant_usb": restaurant_usb,
		"divorce_drawer": divorce_drawer,
	})
	add_child(director)
	_save_button.hide()
	GameState.data["current_scene"] = "phase3_kitchen"
	GameState.commit()
	EventBus.modal_changed.connect(_on_modal_changed)
	_save_button.pressed.connect(_save)


func _on_modal_changed(blocked: bool) -> void:
	_blocked = blocked
	_save_button.disabled = blocked


func _save() -> void:
	if _blocked:
		return
	EventBus.audio_cue_requested.emit("sfx_save")
	EventBus.toast_requested.emit("已保存" if GameState.save() else "保存失败")
