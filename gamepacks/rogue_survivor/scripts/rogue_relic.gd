## 宝物系统 - 每 N 击杀弹出 3 选 1 被动效果
## 独立于卡组的第三层策略选择
class_name RogueRelic

var _gm  # 主控引用
var _all_relics: Array = []
var _held_relics: Array[String] = []  # 已持有宝物 ID
var _next_relic_kills: int = 50  # 下次触发所需击杀数
const KILLS_PER_RELIC := 50
const MAX_RELICS := 6  # 最多持有 6 个宝物

func init(game_mode) -> void:
	_gm = game_mode
	_load_relics()

func _load_relics() -> void:
	var path: String = _gm.pack.pack_path.path_join("relics.json")
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Array:
		_all_relics = json.data

func check_relic_trigger() -> void:
	## 检查是否达到击杀阈值，弹出宝物选择
	if _gm._kills >= _next_relic_kills and _held_relics.size() < MAX_RELICS:
		_next_relic_kills += KILLS_PER_RELIC
		_show_relic_selection()

func _show_relic_selection() -> void:
	var choices: Array = _pick_three()
	if choices.is_empty():
		return

	var I18n: Node = _gm.I18n
	var ui_layer: CanvasLayer = _gm.get_tree().current_scene.get_node_or_null("UI")
	if ui_layer == null:
		return

	var panel := Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.name = "RelicUI"
	ui_layer.add_child(panel)

	# 标题
	var title_lbl := Label.new()
	title_lbl.text = I18n.t("RELIC_CHOOSE") if I18n else "Choose a Relic"
	title_lbl.anchor_left = 0.5
	title_lbl.anchor_right = 0.5
	title_lbl.offset_left = -100
	title_lbl.offset_right = 100
	title_lbl.offset_top = 60
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	panel.add_child(title_lbl)

	# 3 个宝物卡片
	var hbox := HBoxContainer.new()
	hbox.anchor_left = 0.5
	hbox.anchor_right = 0.5
	hbox.anchor_top = 0.5
	hbox.anchor_bottom = 0.5
	hbox.offset_left = -350
	hbox.offset_right = 350
	hbox.offset_top = -100
	hbox.offset_bottom = 100
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	for relic in choices:
		var btn := _create_relic_card(relic, panel)
		hbox.add_child(btn)

func _create_relic_card(relic: Dictionary, parent_panel: Control) -> Button:
	var I18n: Node = _gm.I18n
	var rarity: String = relic.get("rarity", "common")
	var rc := _rarity_color(rarity)
	var border_col := Color(rc.r * 0.7, rc.g * 0.7, rc.b * 0.7, 0.9)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(200, 180)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.12, 0.95)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_color = border_col
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.shadow_color = Color(rc.r, rc.g, rc.b, 0.2)
	style.shadow_size = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.border_color = rc
	hover.shadow_size = 6
	hover.shadow_color = Color(rc.r, rc.g, rc.b, 0.4)
	btn.add_theme_stylebox_override("hover", hover)

	btn.pressed.connect(_on_relic_selected.bind(relic, parent_panel))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	# 宝物名
	var name_lbl := Label.new()
	name_lbl.text = I18n.t(relic.get("name_key", "")) if I18n else relic.get("id", "")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", rc)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	# 稀有度
	var rarity_lbl := Label.new()
	rarity_lbl.text = I18n.t(rarity.to_upper()) if I18n else rarity
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 9)
	rarity_lbl.add_theme_color_override("font_color", Color(rc.r * 0.6, rc.g * 0.6, rc.b * 0.6))
	rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rarity_lbl)

	# 分隔
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(border_col.r, border_col.g, border_col.b, 0.3)
	vbox.add_child(sep)

	# 描述
	var desc_lbl := Label.new()
	desc_lbl.text = I18n.t(relic.get("desc_key", "")) if I18n else ""
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.custom_minimum_size = Vector2(170, 0)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)

	# 数值详情
	var effects: Array = relic.get("effects", [])
	var detail_text := ""
	for eff in effects:
		if not eff is Dictionary:
			continue
		var key: String = eff.get("key", "")
		var val: float = eff.get("base_points", 0)
		var tr_key: String = _gm._combat_log_module.STAT_TR_MAP.get(key, "")
		var display: String = I18n.t(tr_key) if tr_key != "" and I18n else key.replace("hero_", "").replace("_", " ").capitalize()
		if val > 0 and val < 1.0:
			detail_text += "%s +%.0f%%\n" % [display, val * 100]
		else:
			detail_text += "%s +%s\n" % [display, str(val)]
	if detail_text != "":
		var detail_lbl := Label.new()
		detail_lbl.text = detail_text.strip_edges()
		detail_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail_lbl.add_theme_font_size_override("font_size", 10)
		detail_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		detail_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(detail_lbl)

	return btn

func _on_relic_selected(relic: Dictionary, panel: Control) -> void:
	var I18n: Node = _gm.I18n
	var relic_id: String = relic.get("id", "")
	_held_relics.append(relic_id)

	# 应用效果（通过 SpellSystem 的 SET_VARIABLE）
	var effects: Array = relic.get("effects", [])
	for eff in effects:
		if not eff is Dictionary:
			continue
		var key: String = eff.get("key", "")
		var val: float = eff.get("base_points", 0)
		var mode: String = eff.get("mode", "set")
		if mode == "add":
			var current: float = float(EngineAPI.get_variable(key, 0.0))
			EngineAPI.set_variable(key, current + val)
		else:
			EngineAPI.set_variable(key, val)

	# 日志
	var name_text: String = I18n.t(relic.get("name_key", "")) if I18n else relic_id
	_gm._combat_log_module._add_log(
		"[RELIC] %s" % name_text, Color(1, 0.85, 0.3), "system"
	)

	# 关闭面板
	if panel and is_instance_valid(panel):
		panel.queue_free()

func _pick_three() -> Array:
	## 从未持有的宝物中随机选 3 个（按稀有度权重）
	var pool: Array = []
	for r in _all_relics:
		if r.get("id", "") not in _held_relics:
			pool.append(r)
	if pool.is_empty():
		return []
	pool.shuffle()
	var result: Array = []
	for i in range(mini(3, pool.size())):
		result.append(pool[i])
	return result

func get_held_relics() -> Array[String]:
	return _held_relics

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon": return Color(0.0, 0.44, 0.87)
		"rare": return Color(0.64, 0.21, 0.93)
		"legendary": return Color(1.0, 0.5, 0.0)
		_: return Color(0.85, 0.85, 0.85)
