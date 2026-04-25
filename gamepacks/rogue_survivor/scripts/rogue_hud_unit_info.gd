## RogueHUDUnitInfo - 选中实体信息浮动面板（左下角）
## 显示名称、def_id、HP条、属性网格、活跃 buff/aura 方块
extends RefCounted

var _gm = null
var _panel: PanelContainer = null
var _current_entity = null  # Variant，可能被 freed

# UI 引用
var _name_label: Label = null
var _def_id_label: Label = null
var _hp_bar_bg: ColorRect = null
var _hp_bar_fill: ColorRect = null
var _hp_text: Label = null
var _stat_labels: Dictionary = {}  # key → Label
var _buff_container: HBoxContainer = null

const STAT_KEYS: Array = ["ATK", "SPD", "ARM", "RES", "MOV", "RNG"]
const PANEL_WIDTH: float = 220.0
const PANEL_HEIGHT: float = 260.0

func init(game_mode) -> void:
	_gm = game_mode

func create(ui_layer: CanvasLayer) -> void:
	# --- 主面板（左下角）---
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 8
	_panel.offset_top = -PANEL_HEIGHT - 60
	_panel.offset_right = PANEL_WIDTH + 8
	_panel.offset_bottom = -60
	_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_color = Color(0.3, 0.3, 0.45, 0.6)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)
	ui_layer.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	# --- 名称（大号，阵营染色）---
	_name_label = Label.new()
	_name_label.text = ""
	_name_label.add_theme_font_size_override("font_size", 15)
	_name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	vbox.add_child(_name_label)

	# --- def_id（小号灰色）---
	_def_id_label = Label.new()
	_def_id_label.text = ""
	_def_id_label.add_theme_font_size_override("font_size", 9)
	_def_id_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	vbox.add_child(_def_id_label)

	# --- HP 条 ---
	var hp_container := Control.new()
	hp_container.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(hp_container)

	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0.15, 0.1, 0.1, 0.9)
	_hp_bar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_container.add_child(_hp_bar_bg)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color = Color(0.2, 0.75, 0.2)
	_hp_bar_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_bar_fill.offset_left = 1
	_hp_bar_fill.offset_top = 1
	_hp_bar_fill.offset_right = -1
	_hp_bar_fill.offset_bottom = -1
	hp_container.add_child(_hp_bar_fill)

	_hp_text = Label.new()
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_text.add_theme_font_size_override("font_size", 10)
	_hp_text.add_theme_color_override("font_color", Color.WHITE)
	hp_container.add_child(_hp_text)

	# --- 属性网格（2列）---
	vbox.add_child(HSeparator.new())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 2)
	vbox.add_child(grid)

	var stat_colors := {
		"ATK": Color(1, 0.4, 0.35),
		"SPD": Color(0.4, 0.85, 1),
		"ARM": Color(0.7, 0.7, 0.8),
		"RES": Color(0.6, 0.5, 1),
		"MOV": Color(0.4, 1, 0.5),
		"RNG": Color(1, 0.85, 0.4),
	}
	for key in STAT_KEYS:
		var lbl := Label.new()
		lbl.text = "%s: --" % key
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", stat_colors.get(key, Color.WHITE))
		grid.add_child(lbl)
		_stat_labels[key] = lbl

	# --- Buff / Aura 行 ---
	vbox.add_child(HSeparator.new())
	var buff_title := Label.new()
	buff_title.text = "Buffs"
	buff_title.add_theme_font_size_override("font_size", 9)
	buff_title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(buff_title)

	_buff_container = HBoxContainer.new()
	_buff_container.add_theme_constant_override("separation", 3)
	vbox.add_child(_buff_container)

	# --- 连接事件 ---
	EventBus.connect_event("entity_selected", _on_entity_selected)
	EventBus.connect_event("entity_deselected", _on_entity_deselected)

func update(_delta: float) -> void:
	if _panel == null or not is_instance_valid(_panel) or not _panel.visible:
		return
	# 如果当前实体已失效，回退到英雄
	if _current_entity == null or not is_instance_valid(_current_entity):
		_try_show_hero()
		return
	_refresh_entity_data(_current_entity)

func show_entity(entity) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	_current_entity = entity
	if _panel and is_instance_valid(_panel):
		_panel.visible = true
		_refresh_entity_data(entity)

func hide_panel() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.visible = false
	_current_entity = null

# --- 事件回调 ---

func _on_entity_selected(data: Dictionary) -> void:
	var entity = data.get("entity", null)
	if entity != null and is_instance_valid(entity):
		show_entity(entity)

func _on_entity_deselected(_data: Dictionary) -> void:
	hide_panel()

func _try_show_hero() -> void:
	if _gm and _gm.hero and is_instance_valid(_gm.hero):
		show_entity(_gm.hero)
	else:
		hide_panel()

# --- 数据刷新 ---

func _refresh_entity_data(entity) -> void:
	if not is_instance_valid(entity):
		hide_panel()
		return

	# 名称 + 阵营色
	var display_name: String = ""
	if entity is GameEntity:
		display_name = entity.meta.get("name", entity.def_id)
	elif entity.has_method("get_meta_value"):
		display_name = str(entity.get_meta_value("name"))
	else:
		display_name = entity.name
	_name_label.text = display_name
	_name_label.add_theme_color_override("font_color", _get_faction_color(entity))

	# def_id
	var def_id: String = entity.def_id if entity is GameEntity else ""
	_def_id_label.text = def_id

	# HP
	var health: Node = _get_comp(entity, "health")
	if health:
		var cur: float = health.current_hp
		var mx: float = health.max_hp
		var ratio: float = cur / mx if mx > 0 else 0.0
		_hp_bar_fill.anchor_right = ratio
		_hp_text.text = "%d / %d" % [int(cur), int(mx)]
		# 血条颜色随比例变化
		if ratio > 0.5:
			_hp_bar_fill.color = Color(0.2, 0.75, 0.2)
		elif ratio > 0.25:
			_hp_bar_fill.color = Color(0.9, 0.7, 0.1)
		else:
			_hp_bar_fill.color = Color(0.85, 0.15, 0.1)
	else:
		_hp_bar_fill.anchor_right = 0.0
		_hp_text.text = "-- / --"

	# 属性
	var combat: Node = _get_comp(entity, "combat")
	var movement: Node = _get_comp(entity, "movement")
	var player_input: Node = _get_comp(entity, "player_input")

	# ATK
	var atk_val: float = 0.0
	if combat and "damage" in combat:
		atk_val = combat.damage
	elif player_input and "projectile_damage" in player_input:
		atk_val = player_input.projectile_damage
	_stat_labels["ATK"].text = "ATK: %d" % int(atk_val)

	# SPD (attack speed)
	var spd_val: float = 0.0
	if combat and "attack_speed" in combat:
		spd_val = combat.attack_speed
	elif player_input and "shoot_cooldown" in player_input:
		spd_val = player_input.shoot_cooldown
	_stat_labels["SPD"].text = "SPD: %.2f" % spd_val

	# ARM
	var arm_val: float = 0.0
	if health and "armor" in health:
		arm_val = health.armor
	_stat_labels["ARM"].text = "ARM: %d" % int(arm_val)

	# RES
	var res_val: float = 0.0
	if health and "magic_resist" in health:
		res_val = health.magic_resist
	_stat_labels["RES"].text = "RES: %d" % int(res_val)

	# MOV
	var mov_val: float = 0.0
	if movement and "current_speed" in movement:
		mov_val = movement.current_speed
	_stat_labels["MOV"].text = "MOV: %d" % int(mov_val)

	# RNG
	var rng_val: float = 0.0
	if combat and "attack_range" in combat:
		rng_val = combat.attack_range
	elif player_input and "attack_range" in player_input:
		rng_val = player_input.attack_range
	_stat_labels["RNG"].text = "RNG: %d" % int(rng_val)

	# Buff / Aura 方块
	_refresh_buffs(entity)

func _refresh_buffs(entity) -> void:
	if _buff_container == null:
		return
	for child in _buff_container.get_children():
		child.queue_free()

	# 从 AuraManager 获取当前 aura
	var aura_mgr: Node = EngineAPI.get_system("aura")
	if aura_mgr == null or not aura_mgr.has_method("get_auras_on"):
		return
	var auras: Array = aura_mgr.call("get_auras_on", entity)
	for aura in auras:
		if not aura is Dictionary:
			continue
		var square := ColorRect.new()
		square.custom_minimum_size = Vector2(14, 14)
		# 根据 aura 类型/学校着色
		var school: String = aura.get("school", "physical")
		square.color = _get_school_color(school)
		square.tooltip_text = aura.get("name", aura.get("aura_id", "?"))
		_buff_container.add_child(square)

# --- 工具方法 ---

func _get_comp(entity, comp_name: String) -> Node:
	if entity.has_method("get_component"):
		return entity.get_component(comp_name)
	return EngineAPI.get_component(entity, comp_name)

func _get_faction_color(entity) -> Color:
	var faction: String = ""
	if entity is GameEntity:
		faction = entity.faction
	elif entity.has_method("get") and entity.get("faction") != null:
		faction = str(entity.get("faction"))
	match faction:
		"player":
			return Color(0.3, 0.9, 0.4)
		"enemy":
			return Color(1, 0.35, 0.3)
		"neutral":
			return Color(1, 0.9, 0.5)
		_:
			return Color(0.85, 0.85, 0.85)

func _get_school_color(school: String) -> Color:
	match school:
		"physical":
			return Color(0.85, 0.85, 0.85)
		"frost":
			return Color(0.3, 0.6, 1.0)
		"fire":
			return Color(1.0, 0.45, 0.15)
		"nature":
			return Color(0.3, 0.9, 0.3)
		"shadow":
			return Color(0.6, 0.3, 0.9)
		"holy":
			return Color(1.0, 0.9, 0.4)
		_:
			return Color(0.5, 0.5, 0.6)
