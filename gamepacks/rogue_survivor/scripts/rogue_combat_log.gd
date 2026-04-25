## RogueCombatLog - WoW 风格战斗日志、BBCode 格式化、筛选、导出
class_name RogueCombatLog

var _gm  # 主控制器引用

# 战斗日志
var _log_outer: VBoxContainer = null  # 日志面板外层容器（用于显示/隐藏）
var _combat_log: VBoxContainer = null
var _combat_log_full: Array[Dictionary] = []  # 完整日志记录
var _log_filter: String = "all"  # all/damage/heal/status/system
const MAX_LOG_DISPLAY := 500
var _log_scroll_ref: ScrollContainer = null

const SCHOOL_NAMES := ["Physical", "Frost", "Fire", "Nature", "Shadow", "Holy"]
const SCHOOL_COLORS: Array[Color] = [
	Color.WHITE, Color(0.4, 0.8, 1), Color(1, 0.5, 0.2),
	Color(0.3, 0.9, 0.3), Color(0.6, 0.3, 0.9), Color(1, 0.9, 0.4)
]
const LOG_CAT_DAMAGE := "damage"
const LOG_CAT_HEAL := "heal"
const LOG_CAT_STATUS := "status"
const LOG_CAT_SYSTEM := "system"

## WoW 风格 BBCode 颜色
const CLR_TIMESTAMP := "#808090"  # 时间戳：灰色
const CLR_PLAYER := "#ffffff"     # 我方：白色
const CLR_FRIENDLY := "#00ff00"   # 友方：绿色
const CLR_ENEMY := "#ff4444"      # 敌方：红色
const CLR_SPELL := "#ffff00"      # 技能名：黄色
const CLR_HEAL := "#44ff44"       # 治疗：绿色
const CLR_SYSTEM := "#ffff88"     # 系统：淡黄
const CLR_CRIT := "#ff8800"       # 暴击：橙色

const SCHOOL_CLR := {
	0: "#ffffff",   # Physical
	1: "#66ccff",   # Frost
	2: "#ff6622",   # Fire
	3: "#44ee44",   # Nature
	4: "#aa44ff",   # Shadow
	5: "#ffee44",   # Holy
}

## 变量名 -> 翻译 key 映射
const STAT_TR_MAP := {
	# 攻击
	"hero_crit_chance": "STAT_CRIT_CHANCE",
	"hero_crit_damage_bonus": "STAT_CRIT_DMG_BONUS",
	"hero_crit_armor_reduce": "STAT_CRIT_ARMOR_REDUCE",
	"hero_attack_speed_pct": "STAT_ATTACK_SPEED",
	"hero_extra_projectiles": "STAT_EXTRA_PROJ",
	"hero_spread_angle": "STAT_SPREAD_ANGLE",
	# 穿透/分裂
	"hero_pierce_chance": "STAT_PIERCE_CHANCE",
	"hero_pierce_count": "STAT_PIERCE_COUNT",
	"hero_pierce_damage_ratio": "STAT_PIERCE_DMG_RATIO",
	"hero_split_chance": "STAT_SPLIT_CHANCE",
	"hero_split_count": "STAT_SPLIT_COUNT",
	"hero_split_damage_ratio": "STAT_SPLIT_DMG_RATIO",
	# 元素
	"hero_ignite_chance": "STAT_IGNITE_CHANCE",
	"hero_burn_damage_amp": "STAT_BURN_DMG_AMP",
	"hero_burn_spread": "STAT_BURN_SPREAD",
	"hero_slow_chance": "STAT_SLOW_CHANCE",
	"hero_slow_pct": "STAT_SLOW_AMOUNT",
	"hero_slow_damage_amp": "STAT_SLOW_DMG_AMP",
	"hero_freeze_shatter": "STAT_FREEZE_SHATTER",
	"hero_poison_chance": "STAT_POISON_CHANCE",
	"hero_poison_max_stacks": "STAT_POISON_STACKS",
	"hero_poison_slow": "STAT_POISON_SLOW",
	# 闪电链
	"hero_chain_chance": "STAT_CHAIN_CHANCE",
	"hero_chain_count": "STAT_CHAIN_COUNT",
	"hero_chain_stun": "STAT_CHAIN_STUN",
	"hero_chain_range": "STAT_CHAIN_RANGE",
	# 生存
	"hero_life_steal": "STAT_LIFE_STEAL",
	"hero_low_hp_lifesteal_mult": "STAT_LOW_HP_LS_MULT",
	"hero_hp_regen": "STAT_HP_REGEN",
	"hero_death_rewind": "STAT_DEATH_REWIND",
	# 死神
	"hero_execute_threshold": "STAT_EXECUTE_THRESHOLD",
	"hero_kill_damage_bonus": "STAT_KILL_DMG_BONUS",
	"hero_kill_stack_damage": "STAT_KILL_STACK_DMG",
	"hero_kill_streak_crit": "STAT_KILL_STREAK_CRIT",
	"hero_permanent_damage_per_kill": "STAT_PERM_DMG_PER_KILL",
	# 风暴
	"hero_shockwave_every_n": "STAT_SHOCKWAVE_EVERY_N",
	"hero_shockwave_radius": "STAT_SHOCKWAVE_RADIUS",
	"hero_shockwave_stun": "STAT_SHOCKWAVE_STUN",
	"hero_shockwave_pull": "STAT_SHOCKWAVE_PULL",
	# 时间
	"hero_time_slow_aura": "STAT_TIME_SLOW_AURA",
	"hero_time_stop": "STAT_TIME_STOP",
	"hero_time_stop_duration": "STAT_TIME_STOP_DUR",
	# 转职
	"hero_berserker_rage": "STAT_BERSERKER_RAGE",
	"hero_shadow_step": "STAT_SHADOW_STEP",
	"hero_spell_amp": "STAT_SPELL_AMP",
	"hero_necro_raise_chance": "STAT_NECRO_RAISE",
	# 新增套装/卡片属性
	"hero_all_damage_pct": "STAT_ALL_DMG_PCT",
	"hero_all_defense_pct": "STAT_ALL_DEF_PCT",
	"hero_all_stats_pct": "STAT_ALL_STATS_PCT",
	"hero_aoe_damage_pct": "STAT_AOE_DMG_PCT",
	"hero_armor_shred": "STAT_ARMOR_SHRED",
	"hero_attack_range": "STAT_ATTACK_RANGE",
	"hero_backstab_damage_pct": "STAT_BACKSTAB_DMG",
	"hero_battlefield_reshape": "STAT_BATTLEFIELD_RESHAPE",
	"hero_blink_attack_speed": "STAT_BLINK_ASPD",
	"hero_blink_interval": "STAT_BLINK_INTERVAL",
	"hero_crit_explosion": "STAT_CRIT_EXPLOSION",
	"hero_damage_aura": "STAT_DAMAGE_AURA",
	"hero_dragon_armor": "STAT_DRAGON_ARMOR",
	"hero_dragon_breath_damage": "STAT_DRAGON_BREATH",
	"hero_element_damage_pct": "STAT_ELEMENT_DMG",
	"hero_element_fusion_damage": "STAT_ELEMENT_FUSION",
	"hero_element_immune_duration": "STAT_ELEMENT_IMMUNE",
	"hero_fire_damage_pct": "STAT_FIRE_DMG_PCT",
	"hero_flight_speed_pct": "STAT_FLIGHT_SPEED",
	"hero_fusion_explosion_damage": "STAT_FUSION_EXPLOSION",
	"hero_homing_projectile": "STAT_HOMING",
	"hero_ice_fire_alternate": "STAT_ICE_FIRE_ALT",
	"hero_ice_fire_amp": "STAT_ICE_FIRE_AMP",
	"hero_invincible_interval": "STAT_INVINCIBLE_CD",
	"hero_kill_crit_bonus": "STAT_KILL_CRIT",
	"hero_kill_heal_pct": "STAT_KILL_HEAL",
	"hero_knockback_force": "STAT_KNOCKBACK",
	"hero_low_hp_attack_speed": "STAT_LOW_HP_ASPD",
	"hero_low_hp_damage_bonus": "STAT_LOW_HP_DMG",
	"hero_low_hp_invincible_duration": "STAT_LOW_HP_INVINCIBLE",
	"hero_mark_damage_amp": "STAT_MARK_DMG_AMP",
	"hero_mark_duration": "STAT_MARK_DURATION",
	"hero_poison_dps": "STAT_POISON_DPS_VAR",
	"hero_random_buff_interval": "STAT_RANDOM_BUFF_CD",
	"hero_random_crit_effect": "STAT_RANDOM_CRIT_EFF",
	"hero_random_effect_on_hit": "STAT_RANDOM_ON_HIT",
	"hero_random_element_chance": "STAT_RANDOM_ELEMENT",
	"hero_random_kill_reward_multi": "STAT_RANDOM_KILL_REWARD",
	"hero_revive_on_death": "STAT_REVIVE",
	"hero_screen_nuke_cooldown": "STAT_SCREEN_NUKE_CD",
	"hero_shadow_clone": "STAT_SHADOW_CLONE",
	"hero_shadow_damage_pct": "STAT_SHADOW_DMG_PCT",
	"hero_shield_interval": "STAT_SHIELD_INTERVAL_VAR",
	"hero_slow_field_radius": "STAT_SLOW_FIELD",
	"hero_soul_shockwave_threshold": "STAT_SOUL_SHOCKWAVE",
	"hero_stealth_kill_mana": "STAT_STEALTH_KILL",
	"hero_summon_damage_bonus": "STAT_SUMMON_DMG",
	"hero_summon_on_kill_chance": "STAT_SUMMON_ON_KILL",
	"hero_time_rewind": "STAT_TIME_REWIND",
	# MOD_STAT misc_value (无 hero_ 前缀也能匹配)
	"poison_dps": "STAT_POISON_DPS",
	"shield_interval": "STAT_SHIELD_INTERVAL",
	"reflect_damage": "STAT_REFLECT_DMG",
	"kill_heal_pct": "STAT_KILL_HEAL",
	"chain_stun_duration": "STAT_CHAIN_STUN",
}

func init(game_mode) -> void:
	_gm = game_mode

func create_log_panel(ui_layer: CanvasLayer) -> void:
	var log_outer := VBoxContainer.new()
	_log_outer = log_outer
	log_outer.anchor_left = 0.0
	log_outer.anchor_top = 0.0
	log_outer.offset_left = 5
	log_outer.offset_top = 38
	log_outer.offset_right = 300
	log_outer.offset_bottom = 350
	log_outer.add_theme_constant_override("separation", 2)
	ui_layer.add_child(log_outer)

	# 筛选+导出按钮（紧凑一行）
	var filter_hbox := HBoxContainer.new()
	filter_hbox.add_theme_constant_override("separation", 1)
	log_outer.add_child(filter_hbox)

	# 筛选下拉按钮
	var filter_opt := OptionButton.new()
	filter_opt.add_theme_font_size_override("font_size", 9)
	filter_opt.custom_minimum_size = Vector2(80, 20)
	filter_opt.add_item(I18n.t("LOG_FILTER_ALL"), 0)
	filter_opt.add_item(I18n.t("LOG_FILTER_DMG"), 1)
	filter_opt.add_item(I18n.t("LOG_FILTER_HEAL"), 2)
	filter_opt.add_item(I18n.t("LOG_FILTER_STATUS"), 3)
	filter_opt.add_item(I18n.t("LOG_FILTER_SYS"), 4)
	filter_opt.item_selected.connect(_on_log_filter_selected)
	filter_hbox.add_child(filter_opt)

	# 导出按钮
	var export_btn := Button.new()
	export_btn.text = I18n.t("EXPORT")
	export_btn.custom_minimum_size = Vector2(55, 20)
	export_btn.add_theme_font_size_override("font_size", 9)
	export_btn.pressed.connect(_on_export_log)
	filter_hbox.add_child(export_btn)

	# 日志面板
	var log_panel := PanelContainer.new()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0, 0, 0, 0.5)
	log_style.content_margin_left = 4
	log_style.content_margin_right = 4
	log_style.content_margin_top = 4
	log_style.content_margin_bottom = 4
	log_style.corner_radius_top_left = 4
	log_style.corner_radius_top_right = 4
	log_style.corner_radius_bottom_left = 4
	log_style.corner_radius_bottom_right = 4
	log_panel.add_theme_stylebox_override("panel", log_style)
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_outer.add_child(log_panel)

	var log_scroll := ScrollContainer.new()
	log_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	log_panel.add_child(log_scroll)
	_log_scroll_ref = log_scroll

	_combat_log = VBoxContainer.new()
	_combat_log.add_theme_constant_override("separation", 1)
	_combat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_scroll.add_child(_combat_log)

# === 时间戳 ===

func _log_timestamp() -> String:
	@warning_ignore("integer_division")
	var m: int = int(_gm._game_timer) / 60
	@warning_ignore("integer_division")
	var s: int = int(_gm._game_timer) % 60
	@warning_ignore("integer_division")
	var ms: int = int(fmod(_gm._game_timer, 1.0) * 10)
	return "%d:%02d.%d" % [m, s, ms]

func _add_log(text: String, color: Color = Color(0.7, 0.7, 0.8), category: String = LOG_CAT_SYSTEM) -> void:
	# 非 BBCode 的纯文本调用自动包装颜色
	var display_text := text
	if not "[color=" in text:
		var hex := "#%02x%02x%02x" % [int(color.r * 255), int(color.g * 255), int(color.b * 255)]
		display_text = "[color=%s]%s[/color]" % [hex, text]
	# 存入完整日志
	_combat_log_full.append({"time": _log_timestamp(), "text": display_text, "color": color, "cat": category})
	# 筛选显示
	if _log_filter != "all" and category != _log_filter:
		return
	_display_log_line(display_text, color)

func _display_log_line(text: String, _color: Color) -> void:
	if _combat_log == null:
		return
	while _combat_log.get_child_count() >= MAX_LOG_DISPLAY:
		var old: Node = _combat_log.get_child(0)
		_combat_log.remove_child(old)
		old.queue_free()
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.text = text  # 已经是 BBCode 格式
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.add_theme_font_size_override("normal_font_size", 9)
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_log.add_child(rtl)
	# 自动滚到最新日志
	if _log_scroll_ref and is_instance_valid(_log_scroll_ref):
		await _gm.get_tree().process_frame
		if _log_scroll_ref and is_instance_valid(_log_scroll_ref):
			_log_scroll_ref.scroll_vertical = int(_log_scroll_ref.get_v_scroll_bar().max_value)

func _refresh_log_display() -> void:
	if _combat_log == null:
		return
	for child in _combat_log.get_children():
		child.queue_free()
	var shown := 0
	for idx in range(_combat_log_full.size() - 1, -1, -1):
		var entry: Dictionary = _combat_log_full[idx]
		if _log_filter != "all" and entry.get("cat", "") != _log_filter:
			continue
		_display_log_line(entry.get("text", ""), entry.get("color", Color.WHITE))
		shown += 1
		if shown >= MAX_LOG_DISPLAY:
			break

func export_combat_log() -> String:
	## 导出完整战斗日志为纯文本（去掉 BBCode 标签）
	var lines: PackedStringArray = []
	var regex := RegEx.new()
	regex.compile("\\[/?color[^\\]]*\\]")
	for entry in _combat_log_full:
		var raw: String = entry.get("text", "")
		var clean: String = regex.sub(raw, "", true)
		lines.append("[%s][%s] %s" % [entry.get("time", ""), entry.get("cat", ""), clean])
	return "\n".join(lines)

func _on_export_log() -> void:
	var log_text := export_combat_log()
	var path := "user://combat_log_%d.txt" % int(Time.get_unix_time_from_system())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(log_text)
		_add_log("[SYSTEM] Log exported: %s" % path, Color(0.5, 0.8, 0.5))

func _on_log_filter_selected(index: int) -> void:
	var filter_ids := ["all", LOG_CAT_DAMAGE, LOG_CAT_HEAL, LOG_CAT_STATUS, LOG_CAT_SYSTEM]
	_log_filter = filter_ids[index] if index < filter_ids.size() else "all"
	_refresh_log_display()

# === BBCode 格式化 ===

func _bb(text: String, color: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]

func _bb_ts() -> String:
	return _bb(_log_timestamp() + ">", CLR_TIMESTAMP)

func _bb_entity(entity: Variant) -> String:
	var I18n: Node = _gm.I18n
	var ename := _get_entity_name(entity)
	if entity == _gm.hero:
		return _bb(I18n.t("LOG_YOU"), CLR_PLAYER)
	if _is_player_entity(entity):
		return _bb(ename, CLR_FRIENDLY)
	return _bb(ename, CLR_ENEMY)

func _bb_spell(spell_name: String) -> String:
	return _bb(spell_name, CLR_SPELL)

func _bb_school_dmg(amount: int, dt: int) -> String:
	var I18n: Node = _gm.I18n
	var school_keys := ["DMG_PHYSICAL", "DMG_FROST", "DMG_FIRE", "DMG_NATURE", "DMG_SHADOW", "DMG_HOLY"]
	var key: String = school_keys[dt] if dt < school_keys.size() else "DMG_PHYSICAL"
	var sc: String = SCHOOL_CLR.get(dt, "#ffffff")
	return _bb(str(amount), "#ffffff") + " " + _bb(I18n.t(key), sc)

# === 实体辅助 ===

func _translate_ability(ability: String) -> String:
	var I18n: Node = _gm.I18n
	var key := "ABILITY_" + ability.to_upper()
	var result: String = I18n.t(key)
	if result != key:
		return result
	return ability.replace("_", " ").capitalize()

func _is_projectile(entity: Variant) -> bool:
	if entity is GameEntity:
		return (entity as GameEntity).has_tag("projectile")
	return false

func _get_entity_name(entity: Variant) -> String:
	if entity == null or not is_instance_valid(entity):
		return "?"
	if entity is GameEntity:
		var did: String = (entity as GameEntity).def_id
		# 优先查翻译 ENTITY_xxx，fallback 到 def_id
		var I18n: Node = _gm.I18n
		if I18n:
			var tr_key: String = "ENTITY_" + did.to_upper()
			var translated: String = I18n.t(tr_key)
			if translated != tr_key:
				return translated
		return did
	return "?"

func _is_player_entity(entity: Variant) -> bool:
	if entity is GameEntity:
		return (entity as GameEntity).faction == "player"
	return false

# === Spell 详情文本 ===

func get_spell_detail_text(spell_id: String) -> String:
	var I18n: Node = _gm.I18n
	var spell_sys: Node = EngineAPI.get_system("spell")
	if spell_sys == null:
		return ""
	var spell: Dictionary = spell_sys.call("get_spell", spell_id)
	if spell.is_empty():
		return ""
	var parts: PackedStringArray = []
	var effects: Array = spell.get("effects", [])
	for effect in effects:
		if not effect is Dictionary:
			continue
		var etype: String = effect.get("type", "")
		match etype:
			"SET_VARIABLE":
				var key: String = effect.get("key", "")
				var val: float = effect.get("base_points", 0.0)
				var mode: String = effect.get("mode", "set")
				var tr_key: String = STAT_TR_MAP.get(key, "")
				var display: String = I18n.t(tr_key) if tr_key != "" else _humanize_var_name(key)
				var val_text: String = _format_stat_value(val, key)
				if mode == "add":
					parts.append("%s +%s" % [display, val_text])
				else:
					parts.append("%s %s" % [display, val_text])
			"APPLY_AURA":
				var aura: String = effect.get("aura", "")
				var bp: float = effect.get("base_points", 0.0)
				var dur: float = effect.get("duration", 0.0)
				var proc: Dictionary = effect.get("proc", {})
				if aura == "PROC_TRIGGER_SPELL":
					var chance: float = proc.get("chance", 100)
					parts.append(I18n.t("SPELL_DETAIL_PROC", [str(int(chance))]))
				elif aura == "PERIODIC_DAMAGE":
					var period: float = effect.get("period", 1.0)
					parts.append(I18n.t("SPELL_DETAIL_DOT", [str(bp), str(period), str(dur)]))
				elif aura == "PERIODIC_HEAL":
					var period: float = effect.get("period", 1.0)
					parts.append(I18n.t("SPELL_DETAIL_HOT", [str(bp), str(period), str(dur)]))
				elif aura == "MOD_SPEED_SLOW":
					parts.append(I18n.t("SPELL_DETAIL_SLOW", [str(int(bp * 100)), str(dur)]))
				elif aura == "MOD_SPEED":
					parts.append(I18n.t("SPELL_DETAIL_HASTE", [str(int(bp * 100)), str(dur)]))
				elif aura == "SCHOOL_ABSORB":
					parts.append(I18n.t("SPELL_DETAIL_ABSORB", [str(int(bp)), str(dur)]))
				elif aura == "DAMAGE_SHIELD":
					parts.append(I18n.t("SPELL_DETAIL_REFLECT", [str(int(bp * 100))]))
				elif aura == "MOD_STAT":
					var stat_name: String = effect.get("misc_value", "")
					var tr_key: String = STAT_TR_MAP.get("hero_" + stat_name, STAT_TR_MAP.get(stat_name, ""))
					var stat_display: String = I18n.t(tr_key) if tr_key != "" else _humanize_var_name(stat_name)
					parts.append("%s +%s" % [stat_display, _format_stat_value(bp, stat_name)])
				elif bp != 0:
					var aura_tr: String = I18n.t("AURA_" + aura)
					if aura_tr == "AURA_" + aura:
						aura_tr = aura.replace("_", " ").capitalize()
					parts.append("%s %.1f (%ss)" % [aura_tr, bp, str(dur)])
			"SCHOOL_DAMAGE":
				var bp: float = effect.get("base_points", 0.0)
				parts.append(I18n.t("SPELL_DETAIL_DMG", [str(int(bp))]))
	return "\n".join(parts)

func _humanize_var_name(key: String) -> String:
	return key.replace("hero_", "").replace("_", " ").capitalize()

func _format_stat_value(val: float, key: String) -> String:
	if key.ends_with("_chance") or key.ends_with("_pct") or key.ends_with("_ratio") \
		or key.ends_with("_amp") or key.ends_with("_mult") or key.ends_with("_steal") \
		or key == "hero_spell_amp":
		return "%.0f%%" % (val * 100)
	elif val == int(val):
		return str(int(val))
	else:
		return "%.1f" % val

# === 日志事件处理器 ===

func _on_log_damaged(data: Dictionary) -> void:
	var I18n: Node = _gm.I18n
	var target = data.get("entity")
	var source = data.get("source")
	if _is_projectile(target):
		return
	var amount: float = data.get("amount", 0)
	if amount < 1:
		return
	var dt: int = data.get("damage_type", 0)
	var ability: String = data.get("ability", "")
	var school_keys := ["DMG_PHYSICAL", "DMG_FROST", "DMG_FIRE", "DMG_NATURE", "DMG_SHADOW", "DMG_HOLY"]
	var skey: String = school_keys[dt] if dt < school_keys.size() else "DMG_PHYSICAL"
	var sc: String = SCHOOL_CLR.get(dt, "#ffffff")
	var msg: String
	if ability != "":
		var ab_display: String = _translate_ability(ability)
		msg = I18n.t("LOG_ABILITY_DMG", [_bb_entity(source), _bb(ab_display, CLR_SPELL), _bb_entity(target), _bb(str(int(amount)), "#ffffff"), _bb(I18n.t(skey), sc)])
	else:
		msg = I18n.t("LOG_DMG", [_bb_entity(source), _bb_entity(target), _bb(str(int(amount)), "#ffffff"), _bb(I18n.t(skey), sc)])
	_add_log("%s %s" % [_bb_ts(), msg], Color.WHITE, LOG_CAT_DAMAGE)

func _on_log_healed(data: Dictionary) -> void:
	var I18n: Node = _gm.I18n
	var target = data.get("entity")
	var source = data.get("source")
	var amount: float = data.get("amount", 0)
	var ability: String = data.get("ability", "")
	if amount < 1:
		return
	var msg: String
	if ability != "":
		var ab_display: String = _translate_ability(ability)
		msg = I18n.t("LOG_ABILITY_HEAL", [_bb_entity(source), _bb(ab_display, CLR_SPELL), _bb_entity(target), _bb(str(int(amount)), CLR_HEAL)])
	else:
		msg = I18n.t("LOG_HEAL", [_bb_entity(source), _bb_entity(target), _bb(str(int(amount)), CLR_HEAL)])
	_add_log("%s %s" % [_bb_ts(), msg], Color.WHITE, LOG_CAT_HEAL)

func _on_log_destroyed(data: Dictionary) -> void:
	var entity = data.get("entity")
	if _is_projectile(entity):
		return
	var msg: String = _gm.I18n.t("LOG_DEATH", [_bb_entity(entity)])
	_add_log("%s %s" % [_bb_ts(), msg], Color.WHITE, LOG_CAT_STATUS)

func _on_log_spell(data: Dictionary) -> void:
	var caster = data.get("caster")
	if caster == null or not is_instance_valid(caster):
		return
	if not (caster is GameEntity and (caster as GameEntity).has_tag("player")):
		return
	var spell_id: String = data.get("spell_id", "")
	var msg: String = _gm.I18n.t("LOG_SPELL_CAST", [_bb_entity(caster), _bb_spell(spell_id)])
	_add_log("%s %s" % [_bb_ts(), msg], Color.WHITE, LOG_CAT_STATUS)

func _on_log_aura(data: Dictionary) -> void:
	var I18n: Node = _gm.I18n
	var target = data.get("target")
	var aura_type: String = data.get("aura_type", "")
	if _is_projectile(target) or aura_type == "":
		return
	var aura_tr_key := "AURA_" + aura_type
	var aura_display: String = I18n.t(aura_tr_key)
	if aura_display == aura_tr_key:
		aura_display = aura_type.replace("_", " ").capitalize()
	var msg: String = I18n.t("LOG_AURA_GAIN", [_bb_entity(target), _bb(aura_display, CLR_SPELL)])
	_add_log("%s %s" % [_bb_ts(), msg], Color.WHITE, LOG_CAT_STATUS)

func _on_log_proc(data: Dictionary) -> void:
	var spell: String = data.get("trigger_spell", "")
	if spell == "":
		return
	var msg: String = _gm.I18n.t("LOG_PROC_TRIGGER", [_bb_spell(spell)])
	_add_log("%s %s" % [_bb_ts(), msg], Color.WHITE, LOG_CAT_STATUS)

func _on_log_wave(data: Dictionary) -> void:
	var I18n: Node = _gm.I18n
	var wave_idx: int = data.get("wave_index", 0)
	var count: int = data.get("enemy_count", 0)
	var is_boss: bool = data.get("is_boss", false)
	if is_boss:
		var msg: String = I18n.t("LOG_BOSS_WAVE", [wave_idx])
		_add_log("%s %s" % [_bb_ts(), _bb("=== " + msg + " ===", "#ff4411")], Color.WHITE, LOG_CAT_SYSTEM)
	else:
		var msg: String = I18n.t("LOG_WAVE", [wave_idx, count])
		_add_log("%s %s" % [_bb_ts(), _bb("-- " + msg + " --", CLR_SYSTEM)], Color.WHITE, LOG_CAT_SYSTEM)
