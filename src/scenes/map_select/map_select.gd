## 地图选择页
extends Control

@onready var back_btn: Button = $TopBar/BackButton
@onready var map_list: VBoxContainer = $ScrollContainer/MapList

func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	_populate_maps()

func _populate_maps() -> void:
	# 当前只有一张地图，后续可从服务器/本地扫描
	_add_map_card(
		"demo_plains",
		"Demo Plains - Tower Defense",
		"Classic tower defense on open plains.\nDefend against 6 waves of enemies.",
		"Difficulty: Easy",
		"tower_defense"
	)
	_add_map_card(
		"dark_forest",
		"Dark Forest - Rogue Survivor",
		"A corrupted forest teeming with dark creatures.\nDefend the Life Fountain for 10 minutes.",
		"Difficulty: Normal | Coming Soon",
		"rogue_survivor",
		true
	)
	_add_map_card(
		"coming_soon",
		"More Maps Coming...",
		"New maps will be available in future updates.",
		"",
		"",
		true
	)

func _add_map_card(map_id: String, title: String, desc: String,
		difficulty: String, pack_id: String, locked: bool = false) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(700, 120)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	card.add_child(hbox)

	# 地图预览（占位色块）
	var preview := ColorRect.new()
	preview.custom_minimum_size = Vector2(160, 100)
	preview.color = Color(0.2, 0.3, 0.15) if not locked else Color(0.2, 0.2, 0.2)
	hbox.add_child(preview)

	# 文字区
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 22)
	if locked:
		title_lbl.modulate = Color(0.5, 0.5, 0.5)
	vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)

	if difficulty != "":
		var diff_lbl := Label.new()
		diff_lbl.text = difficulty
		diff_lbl.add_theme_font_size_override("font_size", 13)
		diff_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		vbox.add_child(diff_lbl)

	# 开始按钮
	if not locked:
		var btn := Button.new()
		btn.text = "Enter"
		btn.custom_minimum_size = Vector2(100, 40)
		btn.pressed.connect(_on_map_selected.bind(pack_id, map_id))
		hbox.add_child(btn)

	map_list.add_child(card)

func _on_map_selected(pack_id: String, map_id: String) -> void:
	SceneManager.goto_scene("battle", {"pack_id": pack_id, "map_id": map_id})

func _on_back() -> void:
	SceneManager.goto_scene("lobby")
