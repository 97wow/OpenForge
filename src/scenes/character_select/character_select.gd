## 角色选择场景
## 3 职业选择后进入战斗
extends Control

var _scene_data: Dictionary = {}

const CLASSES := [
	{
		"id": "warrior", "name_key": "WARRIOR", "icon_key": "STR",
		"color": Color(0.9, 0.22, 0.21),
		"desc_key": "WARRIOR_DESC",
		"stats": "HP: 250 | DMG: 35 | SPD: 2.4s | Range: 250\nPhysical Attack",
	},
	{
		"id": "ranger", "name_key": "RANGER", "icon_key": "AGI",
		"color": Color(0.26, 0.63, 0.28),
		"desc_key": "RANGER_DESC",
		"stats": "HP: 150 | DMG: 12 | SPD: 1.6s | Range: 420\nPhysical Attack",
	},
	{
		"id": "mage", "name_key": "MAGE", "icon_key": "INT",
		"color": Color(0.49, 0.34, 0.76),
		"desc_key": "MAGE_DESC",
		"stats": "HP: 120 | DMG: 25 | SPD: 2.2s | Range: 350\nFire Damage (Fireball)",
	},
]

func _ready() -> void:
	_scene_data = SceneManager.pending_data.duplicate()
	_build_ui()

func _build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 用 VBox 包裹所有内容实现整体居中
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_theme_constant_override("separation", 20)
	add_child(outer)

	# 标题
	var title := Label.new()
	title.text = tr("CHOOSE_HERO")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	outer.add_child(title)

	# 3 个角色卡片
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 30)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(hbox)

	for cls in CLASSES:
		var card := _create_class_card(cls)
		hbox.add_child(card)

	# 返回按钮
	var back_btn := Button.new()
	back_btn.text = tr("BACK")
	back_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
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
	name_label.text = tr(cls["name_key"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(name_label)

	# 主属性标签
	var attr_label := Label.new()
	attr_label.text = "[ %s ]" % tr(cls["icon_key"])
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
	desc_label.text = tr(cls["desc_key"])
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
	btn.text = tr("SELECT_CLASS").format([tr(cls["name_key"])])
	btn.custom_minimum_size = Vector2(0, 45)
	btn.pressed.connect(_on_class_selected.bind(cls["id"]))
	vbox.add_child(btn)

	return card

func _on_class_selected(class_id: String) -> void:
	_scene_data["hero_class"] = class_id
	SceneManager.goto_scene("difficulty_select", _scene_data)
