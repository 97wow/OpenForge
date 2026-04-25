## RogueUIPanels — 暂停菜单 + 游戏开始前选择 UI（难度/英雄）
## 从 rogue_game_mode.gd 提取
extends RefCounted

var _gm = null  # rogue_game_mode 引用
var _pause_menu: Control = null
var _selection_ui: Control = null

func init(game_mode) -> void:
	_gm = game_mode

# === 暂停菜单 ===

func show_pause_menu() -> void:
	if _pause_menu:
		return
	_gm.get_tree().paused = true
	var ui_layer: CanvasLayer = _gm.get_tree().current_scene.get_node_or_null("UI")
	if ui_layer == null:
		return
	var I18n: Node = _gm.I18n
	_pause_menu = Control.new()
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(_pause_menu)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_menu.add_child(overlay)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.offset_left = -100
	vbox.offset_right = 100
	vbox.offset_top = -80
	vbox.offset_bottom = 80
	vbox.add_theme_constant_override("separation", 12)
	_pause_menu.add_child(vbox)

	var title := Label.new()
	title.text = I18n.t("PAUSED")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = I18n.t("RESUME")
	resume_btn.custom_minimum_size = Vector2(0, 38)
	resume_btn.pressed.connect(close_pause_menu)
	vbox.add_child(resume_btn)

	var quit_btn := Button.new()
	quit_btn.text = I18n.t("QUIT")
	quit_btn.custom_minimum_size = Vector2(0, 38)
	quit_btn.pressed.connect(func() -> void:
		_gm.get_tree().paused = false
		SceneManager.goto_scene("lobby")
	)
	vbox.add_child(quit_btn)

func close_pause_menu() -> void:
	if _pause_menu and is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
		_pause_menu = null
	_gm.get_tree().paused = false

func is_pause_menu_open() -> bool:
	return _pause_menu != null and is_instance_valid(_pause_menu)

# === 游戏开始选择 UI ===

func show_selection_ui() -> void:
	## 游戏内选择 UI：先选难度，再选英雄，选完才开始刷怪
	var ui_layer: CanvasLayer = _gm.get_tree().current_scene.get_node_or_null("UI")
	if ui_layer == null:
		return
	_selection_ui = Control.new()
	_selection_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(_selection_ui)

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_selection_ui.add_child(overlay)

	_show_difficulty_step()

func _show_difficulty_step() -> void:
	for child in _selection_ui.get_children():
		if child is VBoxContainer:
			child.queue_free()
	var I18n: Node = _gm.I18n

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.offset_left = -150
	vbox.offset_right = 150
	vbox.offset_top = -120
	vbox.offset_bottom = 120
	vbox.add_theme_constant_override("separation", 10)
	_selection_ui.add_child(vbox)

	var title := Label.new()
	title.text = I18n.t("SELECT_DIFF_TITLE") if I18n else "Select Difficulty"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	vbox.add_child(title)

	var difficulties := [
		{"name_key": "DIFF_EASY", "level": 1, "hp_mult": 0.8, "dmg_mult": 0.8, "count_mult": 0.8, "reward_mult": 0.8},
		{"name_key": "DIFF_NORMAL", "level": 2, "hp_mult": 1.0, "dmg_mult": 1.0, "count_mult": 1.0, "reward_mult": 1.0},
		{"name_key": "DIFF_HARD", "level": 3, "hp_mult": 1.5, "dmg_mult": 1.3, "count_mult": 1.2, "reward_mult": 1.3},
		{"name_key": "DIFF_NIGHTMARE", "level": 4, "hp_mult": 2.0, "dmg_mult": 1.6, "count_mult": 1.5, "reward_mult": 1.5},
	]
	for diff in difficulties:
		var btn := Button.new()
		var diff_name: String = I18n.t(diff["name_key"]) if I18n else diff["name_key"]
		btn.text = "%s (Lv.%d)" % [diff_name, diff["level"]]
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_size_override("font_size", 14)
		var d: Dictionary = diff
		btn.pressed.connect(func() -> void:
			_gm._difficulty = d
			_gm.set_var("difficulty_level", d.get("level", 1))
			_gm.set_var("difficulty_name", d.get("name", "Normal"))
			_show_hero_step()
		)
		vbox.add_child(btn)

func _show_hero_step() -> void:
	for child in _selection_ui.get_children():
		if child is VBoxContainer:
			child.queue_free()
	var I18n: Node = _gm.I18n

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.offset_left = -150
	vbox.offset_right = 150
	vbox.offset_top = -100
	vbox.offset_bottom = 100
	vbox.add_theme_constant_override("separation", 10)
	_selection_ui.add_child(vbox)

	var hero_title := Label.new()
	hero_title.text = I18n.t("SELECT_HERO_TITLE") if I18n else "Select Hero"
	hero_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_title.add_theme_font_size_override("font_size", 20)
	hero_title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	vbox.add_child(hero_title)

	var heroes := [
		{"id": "warrior", "name_key": "WARRIOR", "color": Color(0.9, 0.2, 0.2)},
		{"id": "ranger", "name_key": "RANGER", "color": Color(0.2, 0.6, 0.2)},
		{"id": "mage", "name_key": "MAGE", "color": Color(0.5, 0.3, 0.8)},
	]
	for h in heroes:
		var btn := Button.new()
		btn.text = I18n.t(h["name_key"]) if I18n else h["name_key"]
		btn.custom_minimum_size = Vector2(0, 40)
		btn.add_theme_font_size_override("font_size", 16)
		var hid: String = h["id"]
		btn.pressed.connect(func() -> void:
			_selection_ui.queue_free()
			_selection_ui = null
			_gm._start_game_with_hero(hid)
		)
		vbox.add_child(btn)
