## 天赋页 + 许愿池 - 局外进度系统
extends Control

const SAVE_NS := "rogue_survivor_progress"

var _meta_data: Dictionary = {}
var _star_dust: int = 0
var _gold: int = 0
var _talent_levels: Dictionary = {}  # talent_id -> level
var _talent_buttons: Dictionary = {}  # talent_id -> Button
var _dust_label: Label = null
var _gold_label: Label = null
var _wish_result_label: Label = null

func _ready() -> void:
	# 加载元进度配置
	var path := "res://gamepacks/rogue_survivor/meta_progress.json"
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			_meta_data = json.data

	# 从存档读取
	_star_dust = int(SaveSystem.load_data(SAVE_NS, "star_dust", 0))
	_gold = int(SaveSystem.load_data(SAVE_NS, "gold", 0))
	var saved_talents: Variant = SaveSystem.load_data(SAVE_NS, "talents", {})
	if saved_talents is Dictionary:
		_talent_levels = saved_talents

	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 15)
	add_child(main_vbox)

	# 顶部：标题 + 资源
	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 30)
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(top_hbox)

	var title := Label.new()
	title.text = I18n.t("TALENTS_TITLE")
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	top_hbox.add_child(title)

	_dust_label = Label.new()
	_dust_label.add_theme_font_size_override("font_size", 16)
	_dust_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	top_hbox.add_child(_dust_label)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	top_hbox.add_child(_gold_label)

	_update_resource_display()

	# 天赋网格
	var talents: Dictionary = _meta_data.get("talents", {})
	var talent_grid := GridContainer.new()
	talent_grid.columns = 4
	talent_grid.add_theme_constant_override("h_separation", 12)
	talent_grid.add_theme_constant_override("v_separation", 12)
	talent_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_vbox.add_child(talent_grid)

	for tid in talents:
		var tdata: Dictionary = talents[tid]
		var current_level: int = int(_talent_levels.get(tid, 0))
		var max_level: int = tdata.get("max_level", 10)
		@warning_ignore("unused_variable")
		var cost: int = tdata.get("cost_base", 5) + current_level * tdata.get("cost_per_level", 3)

		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(200, 130)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.18, 0.9)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		var icon_color: Color = Color.from_string(tdata.get("icon_color", "#ffffff"), Color.WHITE)
		style.border_color = icon_color.darkened(0.3)
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_width_left = 2
		style.border_width_right = 2
		panel.add_theme_stylebox_override("panel", style)
		talent_grid.add_child(panel)

		var pvbox := VBoxContainer.new()
		pvbox.add_theme_constant_override("separation", 4)
		panel.add_child(pvbox)

		var name_lbl := Label.new()
		name_lbl.text = I18n.t(tdata.get("name_key", tid))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", icon_color)
		pvbox.add_child(name_lbl)

		var level_lbl := Label.new()
		level_lbl.text = "%d / %d" % [current_level, max_level]
		level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_lbl.add_theme_font_size_override("font_size", 12)
		level_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
		level_lbl.name = "LevelLabel"
		pvbox.add_child(level_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = I18n.t(tdata.get("desc_key", ""))
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		pvbox.add_child(desc_lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 30)
		btn.name = "UpgradeBtn"
		_update_talent_button(btn, tid, tdata)
		btn.pressed.connect(_on_talent_upgrade.bind(tid))
		pvbox.add_child(btn)
		_talent_buttons[tid] = panel

	# 分隔线
	main_vbox.add_child(HSeparator.new())

	# 许愿池
	var wish_hbox := HBoxContainer.new()
	wish_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	wish_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(wish_hbox)

	var wish_title := Label.new()
	wish_title.text = I18n.t("WISHING_WELL")
	wish_title.add_theme_font_size_override("font_size", 20)
	wish_title.add_theme_color_override("font_color", Color(0.5, 0.7, 1))
	wish_hbox.add_child(wish_title)

	var wish_cost: int = _meta_data.get("wishing_well", {}).get("cost", 100)
	var wish_btn := Button.new()
	wish_btn.text = I18n.t("WISH") + " (%d %s)" % [wish_cost, I18n.t("GOLD")]
	wish_btn.custom_minimum_size = Vector2(180, 40)
	wish_btn.pressed.connect(_on_wish)
	wish_btn.name = "WishButton"
	wish_hbox.add_child(wish_btn)

	_wish_result_label = Label.new()
	_wish_result_label.add_theme_font_size_override("font_size", 16)
	_wish_result_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	wish_hbox.add_child(_wish_result_label)

	# 重置 + 返回按钮
	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(bottom_hbox)

	var reset_btn := Button.new()
	reset_btn.text = I18n.t("RESET_TALENTS")
	reset_btn.custom_minimum_size = Vector2(140, 35)
	reset_btn.pressed.connect(_on_reset_talents)
	bottom_hbox.add_child(reset_btn)

	var back_btn := Button.new()
	back_btn.text = I18n.t("BACK")
	back_btn.custom_minimum_size = Vector2(140, 35)
	back_btn.pressed.connect(func() -> void: SceneManager.goto_scene("lobby"))
	bottom_hbox.add_child(back_btn)

func _update_resource_display() -> void:
	if _dust_label:
		_dust_label.text = "%s: %d" % [I18n.t("STAR_DUST"), _star_dust]
	if _gold_label:
		_gold_label.text = "%s: %d" % [I18n.t("GOLD"), _gold]

func _update_talent_button(btn: Button, tid: String, tdata: Dictionary) -> void:
	var current_level: int = int(_talent_levels.get(tid, 0))
	var max_level: int = tdata.get("max_level", 10)
	if current_level >= max_level:
		btn.text = I18n.t("TALENT_MAX")
		btn.disabled = true
	else:
		var cost: int = tdata.get("cost_base", 5) + current_level * tdata.get("cost_per_level", 3)
		btn.text = I18n.t("UPGRADE") + " (%d)" % cost
		btn.disabled = _star_dust < cost

func _on_talent_upgrade(tid: String) -> void:
	var talents: Dictionary = _meta_data.get("talents", {})
	if not talents.has(tid):
		return
	var tdata: Dictionary = talents[tid]
	var current_level: int = int(_talent_levels.get(tid, 0))
	var max_level: int = tdata.get("max_level", 10)
	if current_level >= max_level:
		return
	var cost: int = tdata.get("cost_base", 5) + current_level * tdata.get("cost_per_level", 3)
	if _star_dust < cost:
		return

	_star_dust -= cost
	_talent_levels[tid] = current_level + 1
	_save_progress()
	_rebuild_talent_ui()

func _on_wish() -> void:
	var well: Dictionary = _meta_data.get("wishing_well", {})
	var cost: int = well.get("cost", 100)
	if _gold < cost:
		_wish_result_label.text = I18n.t("NOT_ENOUGH_GOLD")
		_wish_result_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		return

	_gold -= cost
	var pool: Array = well.get("pool", [])
	var total_weight: float = 0.0
	for entry in pool:
		total_weight += float((entry as Dictionary).get("weight", 1))

	var roll := randf() * total_weight
	var accumulated := 0.0
	var result: Dictionary = {}
	for entry in pool:
		accumulated += float((entry as Dictionary).get("weight", 1))
		if roll <= accumulated:
			result = entry as Dictionary
			break

	# 应用结果
	var result_text := ""
	match result.get("type", ""):
		"star_dust":
			var amount: int = result.get("amount", 5)
			_star_dust += amount
			result_text = I18n.t("STAR_DUST_AMOUNT", [str(amount)])
			_wish_result_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		"gold_bonus":
			var amount: int = result.get("amount", 100)
			_gold += amount
			result_text = "+%d %s!" % [amount, I18n.t("GOLD")]
			_wish_result_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
		"card_unlock":
			result_text = I18n.t("CARD_UNLOCKED")
			_wish_result_label.add_theme_color_override("font_color", Color(0.7, 0.3, 1))

	_wish_result_label.text = result_text
	_save_progress()
	_update_resource_display()

func _on_reset_talents() -> void:
	# 退还所有 Star Dust
	var talents: Dictionary = _meta_data.get("talents", {})
	var refund := 0
	for tid in _talent_levels:
		var tdata: Dictionary = talents.get(tid, {})
		var level: int = int(_talent_levels[tid])
		for i in range(level):
			refund += tdata.get("cost_base", 5) + i * tdata.get("cost_per_level", 3)
	_star_dust += refund
	_talent_levels.clear()
	_save_progress()
	_rebuild_talent_ui()

func _rebuild_talent_ui() -> void:
	# 简单方式：清理并重建
	for child in get_children():
		child.queue_free()
	_talent_buttons.clear()
	_build_ui()

func _save_progress() -> void:
	SaveSystem.save_data(SAVE_NS, "star_dust", _star_dust)
	SaveSystem.save_data(SAVE_NS, "gold", _gold)
	SaveSystem.save_data(SAVE_NS, "talents", _talent_levels)

## 获取天赋加成（供战斗时调用）
static func get_talent_bonuses() -> Dictionary:
	var bonuses: Dictionary = {}
	var path := "res://gamepacks/rogue_survivor/meta_progress.json"
	if not FileAccess.file_exists(path):
		return bonuses
	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return bonuses
	var meta: Dictionary = json.data
	var talents: Dictionary = meta.get("talents", {})
	var saved: Variant = SaveSystem.load_data("rogue_survivor_progress", "talents", {})
	if not saved is Dictionary:
		return bonuses
	for tid in saved:
		var level: int = int((saved as Dictionary)[tid])
		if level <= 0:
			continue
		var tdata: Dictionary = talents.get(tid, {})
		var stat: String = tdata.get("stat", "")
		var per_level: float = tdata.get("effect_per_level", 0.0)
		if stat != "":
			bonuses[stat] = bonuses.get(stat, 0.0) + per_level * level
	return bonuses
