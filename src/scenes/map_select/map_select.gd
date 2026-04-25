## 地图选择页
extends Control

@onready var back_btn: Button = $TopBar/BackButton
@onready var map_list: VBoxContainer = $ScrollContainer/MapList

func _ready() -> void:
	back_btn.text = I18n.t("BACK")
	$TopBar/TitleLabel.text = I18n.t("SELECT_MAP") if $TopBar.has_node("TitleLabel") else ""
	back_btn.pressed.connect(_on_back)
	_populate_maps()

func _populate_maps() -> void:
	_add_map_card(
		"demo_plains",
		I18n.t("MAP_DEMO_PLAINS"),
		I18n.t("MAP_DEMO_PLAINS_DESC"),
		I18n.t("DIFFICULTY") + ": " + I18n.t("DIFF_N1"),
		"tower_defense"
	)
	_add_map_card(
		"dark_forest",
		I18n.t("MAP_DARK_FOREST"),
		I18n.t("MAP_DARK_FOREST_DESC"),
		I18n.t("DIFFICULTY") + ": " + I18n.t("DIFF_N2"),
		"rogue_survivor"
	)
	_add_map_card(
		"test_arena",
		"[DEBUG] Test Arena",
		"Framework test: UnitFlags / CC / Faction / TargetUtil / Damage Pipeline",
		"",
		"rogue_survivor"
	)
	_add_map_card(
		"coming_soon",
		I18n.t("COMING_SOON"),
		I18n.t("MAP_COMING_SOON_DESC"),
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
		btn.text = I18n.t("ENTER")
		btn.custom_minimum_size = Vector2(100, 40)
		btn.pressed.connect(_on_map_selected.bind(pack_id, map_id))
		hbox.add_child(btn)

	map_list.add_child(card)

func _on_map_selected(pack_id: String, map_id: String) -> void:
	# 测试地图直接进入战斗（跳过角色/难度选择）
	if map_id == "test_arena":
		SceneManager.goto_scene("battle", {
			"pack_id": pack_id, "map_id": map_id,
			"hero_class": "warrior", "test_mode": true,
			"difficulty": {"level": 1, "hp_mult": 1.0, "dmg_mult": 1.0, "count_mult": 1.0, "reward_mult": 1.0, "name": "TEST"}
		})
		return
	# 直接进入战斗场景（难度和英雄在游戏内选择）
	SceneManager.goto_scene("battle", {"pack_id": pack_id, "map_id": map_id})

func _register_pack_scenes(pack_id: String) -> void:
	var pack_path := "res://gamepacks/%s" % pack_id
	var json_path := pack_path + "/pack.json"
	if not FileAccess.file_exists(json_path):
		return
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		return
	var scenes: Dictionary = (json.data as Dictionary).get("scenes", {})
	for scene_id in scenes:
		SceneManager.register_scene(scene_id, pack_path + "/" + str(scenes[scene_id]))

func _on_back() -> void:
	SceneManager.goto_scene("lobby")
