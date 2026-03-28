## 角色选择场景
## 3 职业选择后进入战斗
extends Control

var _selected_class: String = ""
var _scene_data: Dictionary = {}

const CLASSES := [
	{
		"id": "warrior", "name": "Warrior", "icon": "STR",
		"color": Color(0.9, 0.22, 0.21),
		"desc": "High damage, slow attack.\nTanky with heavy armor.\n\n+3 STR / +2 STA / +1 DEF per level",
		"stats": "HP: 200 | DMG: 20 | SPD: 0.5s | Range: 280",
	},
	{
		"id": "ranger", "name": "Ranger", "icon": "AGI",
		"color": Color(0.26, 0.63, 0.28),
		"desc": "Extremely fast attacks.\nLong range, high mobility.\n\n+3 AGI / +1 STR / +1 STA per level",
		"stats": "HP: 120 | DMG: 7 | SPD: 0.2s | Range: 400",
	},
	{
		"id": "mage", "name": "Mage", "icon": "INT",
		"color": Color(0.49, 0.34, 0.76),
		"desc": "High burst damage.\nSlow attack, very fragile.\n\n+3 INT / +1 AGI / +1 STA per level",
		"stats": "HP: 100 | DMG: 25 | SPD: 0.6s | Range: 320",
	},
]

func _ready() -> void:
	_scene_data = SceneManager.pending_data.duplicate()
	_build_ui()

func _build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.1)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(bg)

	# 标题
	var title := Label.new()
	title.text = "Choose Your Hero"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchors_preset = Control.PRESET_TOP_WIDE
	title.offset_top = 60
	title.offset_bottom = 110
	title.add_theme_font_size_override("font_size", 36)
	add_child(title)

	# 3 个角色卡片
	var hbox := HBoxContainer.new()
	hbox.anchors_preset = Control.PRESET_CENTER
	hbox.offset_left = -480
	hbox.offset_top = -180
	hbox.offset_right = 480
	hbox.offset_bottom = 220
	hbox.add_theme_constant_override("separation", 30)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hbox)

	for cls in CLASSES:
		var card := _create_class_card(cls)
		hbox.add_child(card)

	# 返回按钮
	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.anchors_preset = Control.PRESET_BOTTOM_LEFT
	back_btn.offset_left = 20
	back_btn.offset_top = -50
	back_btn.offset_right = 120
	back_btn.offset_bottom = -15
	back_btn.pressed.connect(func() -> void: SceneManager.goto_scene("map_select"))
	add_child(back_btn)

func _create_class_card(cls: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 380)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# 职业图标（彩色方块）
	var icon_container := CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(icon_container)

	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(60, 60)
	icon.color = cls["color"]
	icon_container.add_child(icon)

	# 职业名
	var name_label := Label.new()
	name_label.text = cls["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(name_label)

	# 主属性标签
	var attr_label := Label.new()
	attr_label.text = "[ %s ]" % cls["icon"]
	attr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attr_label.add_theme_font_size_override("font_size", 14)
	attr_label.add_theme_color_override("font_color", cls["color"])
	vbox.add_child(attr_label)

	# 数值
	var stats_label := Label.new()
	stats_label.text = cls["stats"]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(stats_label)

	# 描述
	var desc_label := Label.new()
	desc_label.text = cls["desc"]
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	# 间距
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# 选择按钮
	var btn := Button.new()
	btn.text = "Select %s" % cls["name"]
	btn.custom_minimum_size = Vector2(0, 45)
	btn.pressed.connect(_on_class_selected.bind(cls["id"]))
	vbox.add_child(btn)

	return card

func _on_class_selected(class_id: String) -> void:
	_scene_data["hero_class"] = class_id
	SceneManager.pending_data = _scene_data
	SceneManager.goto_scene("battle")
