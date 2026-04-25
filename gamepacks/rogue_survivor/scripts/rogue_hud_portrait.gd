## RogueHudPortrait — 底部中央：肖像 + HP/MP/XP + 右侧基础属性
## hover 属性面板显示完整详细属性
extends RefCounted

var _gm
var _portrait_rect: ColorRect = null
var _hp_bar_fill: ColorRect = null
var _hp_bar_label: Label = null
var _mp_bar_fill: ColorRect = null
var _mp_bar_label: Label = null
var _xp_bar_fill: ColorRect = null
var _level_label: Label = null
# 右侧基础属性 label
var _atk_label: Label = null
var _aspd_label: Label = null
var _range_label: Label = null
var _str_label: Label = null
var _agi_label: Label = null
var _int_label: Label = null

func create(ui_layer: CanvasLayer, _I18n: Node) -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 1.0; panel.anchor_bottom = 1.0
	panel.offset_left = -230; panel.offset_right = 230
	panel.offset_top = -170; panel.offset_bottom = -2
	var style := _dark_panel_style()
	panel.add_theme_stylebox_override("panel", style)
	ui_layer.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# === 左：肖像框 ===
	var portrait_panel := PanelContainer.new()
	portrait_panel.custom_minimum_size = Vector2(110, 0)
	var ps := _dark_panel_style()
	ps.border_color = Color(0.3, 0.25, 0.45, 0.6)
	portrait_panel.add_theme_stylebox_override("panel", ps)
	hbox.add_child(portrait_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait_panel.add_child(vbox)

	_portrait_rect = ColorRect.new()
	_portrait_rect.custom_minimum_size = Vector2(75, 65)
	_portrait_rect.color = Color(0.2, 0.35, 0.6)
	_portrait_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_portrait_rect)

	var hp_bg := _bar(vbox, Color(0.15, 0.05, 0.05), 13)
	_hp_bar_fill = _fill(hp_bg, Color(0.2, 0.75, 0.2))
	_hp_bar_label = _bar_label(hp_bg, "HP")

	var mp_bg := _bar(vbox, Color(0.05, 0.05, 0.15), 13)
	_mp_bar_fill = _fill(mp_bg, Color(0.25, 0.4, 0.85))
	_mp_bar_label = _bar_label(mp_bg, "MP")

	var xp_bg := _bar(vbox, Color(0.1, 0.08, 0.02), 7)
	_xp_bar_fill = _fill(xp_bg, Color(0.85, 0.7, 0.15))

	_level_label = Label.new()
	_level_label.text = "Lv.1"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 10)
	_level_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vbox.add_child(_level_label)

	# === 右：基础属性（hover 显示详细）===
	var stats_panel := PanelContainer.new()
	stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sp_style := _dark_panel_style()
	sp_style.border_color = Color(0.2, 0.2, 0.3, 0.4)
	stats_panel.add_theme_stylebox_override("panel", sp_style)
	stats_panel.mouse_entered.connect(_on_stats_hover)
	stats_panel.mouse_exited.connect(_on_stats_unhover)
	hbox.add_child(stats_panel)

	var sg := GridContainer.new()
	sg.columns = 2
	sg.add_theme_constant_override("h_separation", 8)
	sg.add_theme_constant_override("v_separation", 1)
	stats_panel.add_child(sg)

	_atk_label = _stat_lbl(sg, "ATK: --", Color(1, 0.7, 0.3))
	_str_label = _stat_lbl(sg, "STR: --", Color(0.9, 0.4, 0.3))
	_aspd_label = _stat_lbl(sg, "ASPD: --", Color(0.7, 0.8, 1))
	_agi_label = _stat_lbl(sg, "AGI: --", Color(0.3, 0.9, 0.4))
	_range_label = _stat_lbl(sg, "RNG: --", Color(0.8, 0.8, 0.6))
	_int_label = _stat_lbl(sg, "INT: --", Color(0.5, 0.6, 1))

func update() -> void:
	if not _gm.hero or not is_instance_valid(_gm.hero): return
	var health: Node = EngineAPI.get_component(_gm.hero, "health")
	if health == null: return
	if _hp_bar_fill and health.max_hp > 0:
		_hp_bar_fill.anchor_right = clampf(health.current_hp / health.max_hp, 0.0, 1.0)
		_hp_bar_label.text = "%d/%d" % [int(health.current_hp), int(health.max_hp)]
	if _mp_bar_fill and health.get("max_mp") != null and health.max_mp > 0:
		_mp_bar_fill.anchor_right = clampf(health.current_mp / health.max_mp, 0.0, 1.0)
		_mp_bar_label.text = "%d/%d" % [int(health.current_mp), int(health.max_mp)]
	if _xp_bar_fill and _gm._xp_to_next > 0:
		_xp_bar_fill.anchor_right = clampf(EngineAPI.get_resource("xp") / float(_gm._xp_to_next), 0.0, 1.0)
	_level_label.text = "Lv.%d" % _gm._hero_level

	# 基础属性
	var I18n_r: Node = _gm.I18n
	var inp: Node = EngineAPI.get_component(_gm.hero, "player_input")
	if inp:
		var atk_name: String = I18n_r.t("STAT_ATK") if I18n_r else "ATK"
		var aspd_name: String = I18n_r.t("STAT_ASPD") if I18n_r else "ASPD"
		var rng_name: String = I18n_r.t("STAT_SPEED") if I18n_r else "RNG"
		_atk_label.text = "%s: %d" % [atk_name, int(inp.projectile_damage)]
		_aspd_label.text = "%s: %.2f" % [aspd_name, inp.shoot_cooldown]
		_range_label.text = "%s: %d" % [rng_name, int(inp.attack_range)]
	if _gm.hero is GameEntity:
		var m: Dictionary = (_gm.hero as GameEntity).meta
		var lvl: int = _gm._hero_level - 1
		# War3 风格：白字(基础) + 绿字(加成)
		var hero_node: Node3D = _gm.hero
		var w_str: int = m.get("base_str", 5) + lvl * m.get("level_str", 1)
		var w_agi: int = m.get("base_agi", 5) + lvl * m.get("level_agi", 1)
		var w_int: int = m.get("base_int", 5) + lvl * m.get("level_int", 1)
		var g_str: int = int(EngineAPI.get_green_stat(hero_node, "str"))
		var g_agi: int = int(EngineAPI.get_green_stat(hero_node, "agi"))
		var g_int: int = int(EngineAPI.get_green_stat(hero_node, "int"))
		_str_label.text = "STR: %d +%d" % [w_str, g_str] if g_str > 0 else "STR: %d" % w_str
		_agi_label.text = "AGI: %d +%d" % [w_agi, g_agi] if g_agi > 0 else "AGI: %d" % w_agi
		_int_label.text = "INT: %d +%d" % [w_int, g_int] if g_int > 0 else "INT: %d" % w_int

func _on_stats_hover() -> void:
	if _gm._tooltip_module == null: return
	var lines: Array[String] = []
	var v := func(key: String, def: float) -> float: return float(EngineAPI.get_variable(key, def))
	# 攻击属性
	lines.append("[color=#ffcc66]── 攻击属性 ──[/color]")
	var inp: Node = EngineAPI.get_component(_gm.hero, "player_input") if _gm.hero else null
	if inp:
		lines.append("攻击力: %d" % int(inp.projectile_damage))
		lines.append("攻击速度: %.0f%%" % (v.call("hero_attack_speed_pct", 0.0) * 100))
		lines.append("攻击范围: %d" % int(inp.attack_range))
	lines.append("物理伤害: %.2f%%" % (v.call("hero_physical_damage_pct", 0.0) * 100))
	lines.append("法术伤害: %.2f%%" % (v.call("hero_spell_damage_pct", 0.0) * 100))
	lines.append("最终伤害: %.0f%%" % (v.call("hero_final_damage_pct", 0.0) * 100))
	var _total_crit: float = v.call("hero_crit_chance", 0.0)
	if _gm.hero and is_instance_valid(_gm.hero):
		_total_crit += EngineAPI.get_total_stat(_gm.hero, "crit_rate")
	lines.append("物理暴击率: %.2f%%" % (clampf(_total_crit, 0.0, 1.0) * 100))
	var _total_crit_dmg: float = v.call("hero_crit_damage_bonus", 0.0)
	if _gm.hero and is_instance_valid(_gm.hero):
		_total_crit_dmg += EngineAPI.get_total_stat(_gm.hero, "crit_dmg")
	lines.append("物理暴击伤害: %.0f%%" % ((1.5 + _total_crit_dmg) * 100))
	lines.append("BOSS增伤: %.0f%%" % (v.call("hero_boss_damage_pct", 0.0) * 100))
	# 资源属性
	lines.append("\n[color=#88cccc]── 资源属性 ──[/color]")
	lines.append("每秒回血: %.1f" % v.call("hero_regen_per_sec", 0.0))
	lines.append("生命偷取: %.0f%%" % (v.call("hero_life_steal", 0.0) * 100))
	lines.append("金币加成: %.0f%%" % (v.call("hero_gold_bonus_pct", 0.0) * 100))
	lines.append("经验加成: %.0f%%" % (v.call("hero_xp_bonus_pct", 0.0) * 100))
	lines.append("杀敌加成: %.0f%%" % (v.call("hero_kill_bonus_pct", 0.0) * 100))
	# 附加属性
	lines.append("\n[color=#ccaa66]── 附加属性 ──[/color]")
	lines.append("生命加成: %.0f%%" % (v.call("hero_hp_bonus_pct", 0.0) * 100))
	lines.append("攻击加成: %.0f%%" % (v.call("hero_atk_bonus_pct", 0.0) * 100))
	lines.append("冷却缩减: %.0f%%" % (v.call("hero_cdr_pct", 0.0) * 100))
	lines.append("移动速度: %.0f" % v.call("hero_move_speed_bonus", 0.0))
	# 属性加成说明
	lines.append("\n[color=#aaaacc]── 属性加成 ──[/color]")
	lines.append("[color=#888]每点力量+10HP +1.5回血/s[/color]")
	lines.append("[color=#888]每点敏捷+0.1%物伤 +0.3固伤[/color]")
	lines.append("[color=#888]每点智力+0.1%法伤 +0.3固伤[/color]")
	_gm._tooltip_module.show_tooltip("详细属性", "\n".join(lines), Color(0.9, 0.85, 0.7))

func _on_stats_unhover() -> void:
	if _gm._tooltip_module: _gm._tooltip_module.hide_tooltip()

# === Helpers ===

func _dark_panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.04, 0.08, 0.9)
	s.border_color = Color(0.25, 0.2, 0.35, 0.5)
	s.border_width_top = 1; s.border_width_bottom = 1; s.border_width_left = 1; s.border_width_right = 1
	s.corner_radius_top_left = 4; s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4; s.corner_radius_bottom_right = 4
	s.content_margin_left = 6; s.content_margin_right = 6
	s.content_margin_top = 4; s.content_margin_bottom = 4
	return s

func _bar(parent: Node, bg_color: Color, height: int) -> Control:
	var bg := Control.new()
	bg.custom_minimum_size = Vector2(0, height)
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rect := ColorRect.new(); rect.color = bg_color
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(rect); parent.add_child(bg); return bg

func _fill(bg: Control, color: Color) -> ColorRect:
	var f := ColorRect.new(); f.color = color
	f.anchor_left = 0; f.anchor_right = 1; f.anchor_top = 0; f.anchor_bottom = 1
	bg.add_child(f); return f

func _bar_label(bg: Control, text: String) -> Label:
	var l := Label.new()
	l.text = text; l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.add_theme_font_size_override("font_size", 9); bg.add_child(l); return l

func _stat_lbl(parent: Node, text: String, color: Color) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l); return l
