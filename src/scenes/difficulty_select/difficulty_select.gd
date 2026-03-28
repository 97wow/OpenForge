## 难度选择场景
extends Control

var _scene_data: Dictionary = {}

const DIFFICULTIES := [
	{"level": 1, "name": "N1", "desc_key": "DIFF_N1", "color": Color(0.5, 0.8, 0.5),
	 "hp_mult": 1.0, "dmg_mult": 1.0, "count_mult": 1.0, "reward_mult": 1.0},
	{"level": 2, "name": "N2", "desc_key": "DIFF_N2", "color": Color(0.7, 0.7, 0.3),
	 "hp_mult": 1.3, "dmg_mult": 1.2, "count_mult": 1.15, "reward_mult": 1.5},
	{"level": 3, "name": "N3", "desc_key": "DIFF_N3", "color": Color(0.9, 0.5, 0.2),
	 "hp_mult": 1.7, "dmg_mult": 1.4, "count_mult": 1.3, "reward_mult": 2.0},
	{"level": 5, "name": "N5", "desc_key": "DIFF_N5", "color": Color(0.9, 0.3, 0.3),
	 "hp_mult": 2.5, "dmg_mult": 1.8, "count_mult": 1.5, "reward_mult": 3.0},
	{"level": 10, "name": "N10", "desc_key": "DIFF_N10", "color": Color(0.7, 0.2, 0.9),
	 "hp_mult": 5.0, "dmg_mult": 3.0, "count_mult": 2.0, "reward_mult": 5.0},
]

func _ready() -> void:
	_scene_data = SceneManager.pending_data.duplicate()
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_theme_constant_override("separation", 15)
	add_child(outer)

	var title := Label.new()
	title.text = tr("SELECT_DIFFICULTY")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	outer.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 15)
	outer.add_child(hbox)

	for diff in DIFFICULTIES:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 120)

		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vbox)

		var name_lbl := Label.new()
		name_lbl.text = diff["name"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_color_override("font_color", diff["color"])
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = tr(diff["desc_key"])
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(desc_lbl)

		var mult_lbl := Label.new()
		mult_lbl.text = "HP×%.1f DMG×%.1f" % [diff["hp_mult"], diff["dmg_mult"]]
		mult_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mult_lbl.add_theme_font_size_override("font_size", 10)
		mult_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		mult_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(mult_lbl)

		var reward_lbl := Label.new()
		reward_lbl.text = tr("REWARD") + " ×%.1f" % diff["reward_mult"]
		reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_lbl.add_theme_font_size_override("font_size", 10)
		reward_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
		reward_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(reward_lbl)

		btn.pressed.connect(_on_difficulty_selected.bind(diff))
		hbox.add_child(btn)

	var back_btn := Button.new()
	back_btn.text = tr("BACK")
	back_btn.custom_minimum_size = Vector2(120, 35)
	back_btn.pressed.connect(func() -> void: SceneManager.goto_scene("character_select", _scene_data))
	outer.add_child(back_btn)

func _on_difficulty_selected(diff: Dictionary) -> void:
	_scene_data["difficulty"] = diff
	SceneManager.goto_scene("battle", _scene_data)
