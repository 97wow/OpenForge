## RogueCardSystem — 抽卡 + 卡片 + 羁绊 + 吞噬
## 消耗木头抽卡，集齐羁绊激活套装效果，吞噬释放槽位保留效果
extends RefCounted

var _gm = null

# === 抽卡经济 ===
var draw_cost: int = 40        # 当前抽卡费用
const DRAW_COST_BASE := 40
const DRAW_COST_INCREMENT := 10
const DRAW_COST_MAX := 200

# === 卡池 ===
var _card_pool: Array[String] = []        # 当前可抽卡池（卡片 ID 列表）
var _unlocked_sets: Array[String] = []    # 已解锁的卡组 ID

# === 持有状态 ===
var held_cards: Array[Dictionary] = []    # 技能栏中的卡片 [{id, data}]
var consumed_cards: Array[Dictionary] = []  # 已吞噬的卡片（效果保留，不占槽位）
const MAX_HELD_CARDS := 8                 # 技能栏容量

# === 羁绊状态 ===
var _bond_progress: Dictionary = {}       # bond_id -> count（拥有该羁绊的卡数）
var _activated_bonds: Array[String] = []  # 已激活的羁绊 ID

# === 技能修改器注册表 ===
var _skill_modifiers: Dictionary = {}     # target_skill_key -> Array[{type, value, source}]

# === 抽卡次数（控制前3次必须是战备套装）===
var _draw_count: int = 0
var _prep_cards_remaining: Array[String] = []  # 战备卡剩余池

# === 抽卡 UI ===
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _draw_ui: Control = null

# === 全部卡片定义（数据驱动）===
# 每张卡片结构:
# {
#   "id": "card_shield_bash",
#   "name": "Shield Bash",
#   "bond_id": "warrior_bond",    # 所属羁绊
#   "tier": 1,                     # 稀有度 1=普通 2=稀有 3=史诗 4=传说
#   "stats": {"atk": 25, "hp": 200},  # 固定属性加成
#   "effects": [...],              # SpellSystem 效果
#   "consume_condition": {...},    # 吞噬条件
#   "unlock_sets": ["advanced_set"],  # 吞噬后解锁的卡组
# }
var _all_cards: Dictionary = {}   # card_id -> card_data (type=card)
var _all_bonds: Dictionary = {}   # bond_id -> bond_data (type=bond)
var _all_skills: Dictionary = {}  # skill_id -> data (type=skill/item)

func init(game_mode) -> void:
	_gm = game_mode
	_init_cards()
	_init_bonds()
	_build_initial_pool()
	# 前3次抽卡固定为战备套装（3→2→1）
	_prep_cards_remaining = ["1", "2", "3"]  # spell ID 1/2/3 = 战备三卡

# === 抽卡 ===

func draw_card() -> Dictionary:
	## 消耗木头，显示三选一 UI。如果已有隐藏的抽卡 UI，重新显示
	if _draw_ui and is_instance_valid(_draw_ui) and not _draw_ui.visible:
		_draw_ui.visible = true
		return {"picking": true}
	var wood: float = EngineAPI.get_resource("wood")
	if wood < draw_cost:
		return {}
	if _card_pool.is_empty():
		if _gm._combat_log_module:
			var I18n: Node = _gm.I18n
			_gm._combat_log_module._add_log(
				I18n.t("POOL_EMPTY") if I18n else "Card pool is empty!", Color(0.7, 0.7, 0.7))
		return {}
	if held_cards.size() >= MAX_HELD_CARDS:
		if _gm._combat_log_module:
			var I18n: Node = _gm.I18n
			_gm._combat_log_module._add_log(
				I18n.t("DRAW_FULL") if I18n else "Skill bar full!", Color(1, 0.5, 0.3))
		return {}

	EngineAPI.subtract_resource("wood", draw_cost)
	draw_cost = mini(draw_cost + DRAW_COST_INCREMENT, DRAW_COST_MAX)
	_draw_count += 1

	# 前3次：战备套装固定选择（3→2→1，每次都显示UI）
	if _prep_cards_remaining.size() > 0:
		var choices: Array[Dictionary] = []
		for pid in _prep_cards_remaining:
			var pdata: Dictionary = _all_cards.get(pid, {})
			if not pdata.is_empty():
				choices.append({"id": pid, "data": pdata})
		_show_card_pick_ui(choices, true)
		return {"picking": true}

	# 正常抽卡：随机3张三选一
	var random_choices: Array[Dictionary] = _draw_random_cards(3)
	if random_choices.is_empty():
		return {}
	_show_card_pick_ui(random_choices, false)
	return {"picking": true}

func _draw_random_cards(count: int) -> Array[Dictionary]:
	## 从卡池随机抽 N 张不重复的卡
	var result: Array[Dictionary] = []
	var pool_copy: Array[String] = _card_pool.duplicate()
	for _i in range(count):
		if pool_copy.is_empty():
			break
		var idx: int = randi() % pool_copy.size()
		var cid: String = pool_copy[idx]
		pool_copy.remove_at(idx)
		var cdata: Dictionary = _all_cards.get(cid, {})
		if not cdata.is_empty():
			result.append({"id": cid, "data": cdata})
	return result

func _show_card_pick_ui(choices: Array[Dictionary], is_prep: bool = false) -> void:
	## 显示三选一卡片选择 UI
	var ui_layer: CanvasLayer = _gm.get_tree().current_scene.get_node_or_null("UI")
	if ui_layer == null:
		return
	if _draw_ui and is_instance_valid(_draw_ui):
		_draw_ui.queue_free()
	var I18n: Node = _gm.I18n

	_draw_ui = Control.new()
	_draw_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_ui.z_index = 50
	ui_layer.add_child(_draw_ui)

	# 透明遮罩（不遮挡、不拦截点击）
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_ui.add_child(overlay)

	# 标题 + 卡片容器（屏幕居中）
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.anchor_left = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -250
	vbox.offset_right = 250
	vbox.offset_top = -150
	vbox.offset_bottom = 150
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_ui.add_child(vbox)

	var title := Label.new()
	title.text = I18n.t("CHOOSE_CARD") if I18n else "Choose a Card"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	vbox.add_child(title)

	# 三张卡片横排
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	for choice in choices:
		var cdata: Dictionary = choice.get("data", {})
		var cid: String = choice.get("id", "")
		var card_panel := _create_card_panel(cdata)
		card_panel.gui_input.connect(_on_card_panel_input.bind(cid, cdata))
		hbox.add_child(card_panel)

	# 操作按钮行（仅正常抽卡时显示，战备阶段不显示）
	if not is_prep:
		var btn_hbox := HBoxContainer.new()
		btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_hbox.add_theme_constant_override("separation", 12)
		vbox.add_child(btn_hbox)

		var refresh_btn := Button.new()
		refresh_btn.text = I18n.t("CARD_REFRESH") if I18n else "刷新"
		refresh_btn.custom_minimum_size = Vector2(80, 30)
		refresh_btn.add_theme_font_size_override("font_size", 12)
		refresh_btn.pressed.connect(func() -> void:
			if _draw_ui and is_instance_valid(_draw_ui):
				_draw_ui.queue_free()
				_draw_ui = null
			var new_choices: Array[Dictionary] = _draw_random_cards(3)
			if not new_choices.is_empty():
				_show_card_pick_ui(new_choices, false)
		)
		btn_hbox.add_child(refresh_btn)

		var skip_btn := Button.new()
		skip_btn.text = I18n.t("CARD_SKIP") if I18n else "跳过"
		skip_btn.custom_minimum_size = Vector2(80, 30)
		skip_btn.add_theme_font_size_override("font_size", 12)
		skip_btn.pressed.connect(func() -> void:
			if _draw_ui and is_instance_valid(_draw_ui):
				_draw_ui.queue_free()
				_draw_ui = null
		)
		btn_hbox.add_child(skip_btn)

		var hide_btn := Button.new()
		hide_btn.text = I18n.t("CARD_HIDE") if I18n else "隐藏"
		hide_btn.custom_minimum_size = Vector2(80, 30)
		hide_btn.add_theme_font_size_override("font_size", 12)
		hide_btn.pressed.connect(func() -> void:
			if _draw_ui and is_instance_valid(_draw_ui):
				_draw_ui.visible = false
		)
		btn_hbox.add_child(hide_btn)

func _on_card_panel_input(event: InputEvent, card_id: String, card_data: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_card_picked(card_id, card_data)

func _create_card_panel(cdata: Dictionary) -> PanelContainer:
	## 创建单张卡片面板
	var tier: int = cdata.get("tier", 1)
	var tier_color: Color = _get_tier_color(tier)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(140, 180)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.14, 0.95)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_color = Color(tier_color.r, tier_color.g, tier_color.b, 0.8)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)

	# 卡名
	var name_label := Label.new()
	name_label.text = _get_card_display_name(cdata)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", tier_color)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_label)

	# 羁绊
	var bond_id: String = _safe_id(cdata.get("bond_id", ""))
	if bond_id != "" and bond_id != "0":
		var bond_label := Label.new()
		bond_label.text = "<%s>" % _get_bond_display_name(bond_id)
		bond_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bond_label.add_theme_font_size_override("font_size", 9)
		bond_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.8))
		bond_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(bond_label)

	# 技能效果描述
	var card_desc: String = get_card_desc(cdata)
	if card_desc != "":
		vb.add_child(HSeparator.new())
		var desc_label := Label.new()
		desc_label.text = card_desc
		desc_label.add_theme_font_size_override("font_size", 9)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.custom_minimum_size = Vector2(120, 0)
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(desc_label)

	vb.add_child(HSeparator.new())

	# 属性列表
	var stats: Dictionary = cdata.get("stats", {})
	for stat_key: String in stats:
		var stat_label := Label.new()
		var val: float = float(stats[stat_key])
		var display: String = _format_stat(stat_key, val)
		stat_label.text = display
		stat_label.add_theme_font_size_override("font_size", 10)
		stat_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(stat_label)

	# === Hover 效果：略微放大 ===
	panel.pivot_offset = panel.custom_minimum_size / 2.0
	panel.mouse_entered.connect(func() -> void:
		panel.create_tween().tween_property(panel, "scale", Vector2(1.05, 1.05), 0.1)
	)
	panel.mouse_exited.connect(func() -> void:
		panel.create_tween().tween_property(panel, "scale", Vector2(1.0, 1.0), 0.08)
	)

	return panel

func _format_stat(key: String, val: float) -> String:
	var I18n: Node = _gm.I18n if _gm else null
	var t := func(k: String) -> String: return I18n.t(k) if I18n else k
	# 属性名映射到 i18n key
	var stat_keys := {
		"atk": "STAT_ATK", "hp": "STAT_HP", "armor": "STAT_ARMOR",
		"str": "STR", "strength": "STR", "agi": "AGI", "agility": "AGI",
		"int": "INT", "intelligence": "INT",
		"aspd_pct": "STAT_ASPD", "crit_rate": "STAT_CRIT",
		"crit_dmg": "STAT_CRIT_DMG", "gold_per_sec": "STAT_GOLD_SEC",
		"regen": "STAT_REGEN", "wood": "WOOD", "gold": "GOLD",
		"move_speed": "STAT_SPEED", "splash_pct": "STAT_SPLASH",
		"str_pct": "STR", "agi_pct": "AGI", "int_pct": "INT",
		"all_stat": "STAT_ALL", "boss_dmg": "STAT_BOSS_DMG",
	}
	var label: String = t.call(stat_keys.get(key, key))
	# 百分比属性
	var pct_keys := ["aspd_pct", "crit_rate", "crit_dmg", "splash_pct", "str_pct", "agi_pct", "int_pct", "boss_dmg"]
	if key in pct_keys:
		return "%s +%d%%" % [label, int(val * 100)]
	return "%s +%d" % [label, int(val)]

func _on_card_picked(card_id: String, card_data: Dictionary) -> void:
	## 玩家选择了一张卡
	if _draw_ui and is_instance_valid(_draw_ui):
		_draw_ui.queue_free()
		_draw_ui = null

	# 从战备池移除已选卡
	if card_id in _prep_cards_remaining:
		_prep_cards_remaining.erase(card_id)

	if held_cards.size() >= MAX_HELD_CARDS:
		return

	# Store timestamps for timer/level_up consume conditions
	card_data["_obtained_at"] = Time.get_ticks_msec()
	card_data["_obtained_level"] = int(EngineAPI.get_variable("hero_level", 1))
	held_cards.append({"id": card_id, "data": card_data})
	# 已选卡从卡池移除（不会再抽到）
	if card_id in _card_pool:
		_card_pool.erase(card_id)
	# stats 全部通过 SpellSystem → AuraManager MOD_STAT 处理
	# HP/MP/Armor 同步由框架层 _sync_health_from_stat 自动完成
	if not _use_spell_system:
		_apply_card_stats(card_data)  # 旧路径回退
	_update_bond_progress(card_data)
	# 主题羁绊（跨套装）复核——依赖 held_cards / consumed_cards 的当前状态
	if _gm and _gm._theme_bond_module:
		_gm._theme_bond_module.check_bonds()
	# 卡片获取时触发效果（如 invest 注册 midas 修改器）
	_apply_on_obtain_effects(card_id)
	# 通过 SpellSystem 施放卡片 spell（apply 永久 aura 挂载 proc）
	_cast_card_spell(card_id)
	# 公告
	if _gm._hud_module:
		var cname: String = _get_card_display_name(card_data)
		var bname: String = _get_bond_display_name(_safe_id(card_data.get("bond_id", "")))
		_gm._hud_module.add_announcement(
			"[b]%s[/b] <%s>" % [cname, bname],
			_get_tier_color(card_data.get("tier", 1))
		)

	if _gm._combat_log_module:
		_gm._combat_log_module._add_log(
			"[DRAW] %s" % _get_card_display_name(card_data),
			_get_tier_color(card_data.get("tier", 1))
		)

	if card_data.get("auto_consume", false):
		consume_card(held_cards.size() - 1)

func consume_card(slot_index: int) -> bool:
	## 吞噬指定槽位的卡片（释放槽位，保留效果）
	if slot_index < 0 or slot_index >= held_cards.size():
		return false
	var entry: Dictionary = held_cards[slot_index]
	var card_data: Dictionary = entry.get("data", {})

	# 检查吞噬条件
	if not _check_consume_condition(card_data):
		return false

	# 从技能栏移除，加入已吞噬列表
	held_cards.remove_at(slot_index)
	consumed_cards.append(entry)

	# 解锁后续卡组
	var unlock_sets: Array = card_data.get("unlock_sets", [])
	for set_id in unlock_sets:
		_unlock_card_set(str(set_id))

	if _gm._combat_log_module:
		var I18n: Node = _gm.I18n
		var cname: String = _get_card_display_name(card_data)
		var msg: String = I18n.t("CONSUME_DONE", [cname]) if I18n else "%s consumed!" % cname
		_gm._combat_log_module._add_log(msg, Color(0.8, 0.6, 1))
	return true

# === 羁绊 ===

func _update_bond_progress(card_data: Dictionary) -> void:
	var bond_id: String = _safe_id(card_data.get("bond_id", ""))
	if bond_id == "" or bond_id == "0":
		return
	_bond_progress[bond_id] = _bond_progress.get(bond_id, 0) + 1
	# 检查羁绊激活
	var bond_def: Dictionary = _all_bonds.get(bond_id, {})
	var required: int = bond_def.get("required", 3)
	if _bond_progress[bond_id] >= required and bond_id not in _activated_bonds:
		_activate_bond(bond_id, bond_def)

func _activate_bond(bond_id: String, bond_def: Dictionary) -> void:
	_activated_bonds.append(bond_id)
	var stats: Dictionary = bond_def.get("stats", {})
	_apply_stats_to_hero(stats)
	if _gm._combat_log_module:
		var I18n: Node = _gm.I18n
		var bname: String = _get_bond_display_name(bond_id)
		var msg: String = I18n.t("BOND_ACTIVATED", [bname]) if I18n else "%s activated!" % bname
		_gm._combat_log_module._add_log(msg, Color(1, 0.85, 0.3))
	EventBus.emit_event("bond_activated", {"bond_id": bond_id})
	# 公告
	if _gm._hud_module:
		var bname2: String = _get_bond_display_name(bond_id)
		_gm._hud_module.add_announcement(
			"[b]%s[/b] %s" % [bname2, _gm.I18n.t("BOND_ACTIVATED", [""]).replace(" !", "!") if _gm.I18n else "Activated!"],
			Color(1, 0.85, 0.3)
		)
	# 自动吞噬该羁绊的所有卡片（释放槽位，效果保留）
	_auto_consume_bond(bond_id)

func _auto_consume_bond(bond_id: String) -> void:
	## 羁绊激活后，自动吞噬属于该羁绊的所有已持有卡片
	var to_consume: Array[int] = []
	for i in range(held_cards.size()):
		var cdata: Dictionary = held_cards[i].get("data", {})
		if _safe_id(cdata.get("bond_id", "")) == bond_id:
			to_consume.append(i)
	# 从后往前移除（避免索引偏移）
	to_consume.reverse()
	for idx in to_consume:
		var entry: Dictionary = held_cards[idx]
		held_cards.remove_at(idx)
		consumed_cards.append(entry)
	if to_consume.size() > 0 and _gm._combat_log_module:
		var I18n: Node = _gm.I18n
		var bname: String = _get_bond_display_name(bond_id)
		var msg: String = I18n.t("CONSUME_DONE", [bname]) if I18n else "%s consumed!" % bname
		_gm._combat_log_module._add_log(msg, Color(0.8, 0.6, 1))

func get_bond_progress(bond_id: String) -> int:
	return _bond_progress.get(bond_id, 0)

func is_bond_activated(bond_id: String) -> bool:
	return bond_id in _activated_bonds

func get_all_bonds() -> Dictionary:
	return _all_bonds

func get_activated_bonds() -> Array[String]:
	return _activated_bonds

# === 技能修改器 ===

func register_skill_modifier(target_key: String, modifier_type: String, value: Variant, source: String) -> void:
	## 注册一个修改另一技能行为的修改器
	## 例如: "invest" 卡修改 "goldtouch" 使其命中3个目标
	if not _skill_modifiers.has(target_key):
		_skill_modifiers[target_key] = []
	_skill_modifiers[target_key].append({
		"type": modifier_type,   # "target_count", "damage_mult", "cooldown_reduction", etc.
		"value": value,
		"source": source,
	})

func get_skill_modifier(target_key: String, modifier_type: String, default_value: Variant = null) -> Variant:
	## 获取某技能的指定修改器值（返回第一个匹配）
	if not _skill_modifiers.has(target_key):
		return default_value
	for mod in _skill_modifiers[target_key]:
		if mod["type"] == modifier_type:
			return mod["value"]
	return default_value

func get_all_modifiers(target_key: String) -> Array:
	## 获取某技能的所有修改器
	return _skill_modifiers.get(target_key, [])

# === 自动吞噬检查 ===

func check_consume_conditions() -> void:
	## 周期性检查持有卡片是否满足吞噬条件（由 game_mode _pack_process 每秒调用）
	var to_consume: Array[int] = []
	for i in range(held_cards.size()):
		var entry: Dictionary = held_cards[i]
		var cdata: Dictionary = entry.get("data", {})
		var cond: Dictionary = cdata.get("consume_condition", {})
		if cond.is_empty():
			continue
		var ctype: String = cond.get("type", "")
		if ctype == "auto" or ctype == "consumed_by":
			continue  # auto 在 pick 时处理; consumed_by 由外部触发
		if _check_consume_condition(cdata):
			to_consume.append(i)
	# 从后往前消耗（避免索引偏移）
	to_consume.reverse()
	for idx in to_consume:
		consume_card(idx)

# === 卡池管理 ===

func _build_initial_pool() -> void:
	_card_pool.clear()
	# 初始只有"基础"套装的卡
	for card_id in _all_cards:
		var card: Dictionary = _all_cards[card_id]
		var set_id: String = card.get("set_id", "basic")
		if set_id == "basic" or set_id in _unlocked_sets:
			_card_pool.append(card_id)

func _unlock_card_set(set_id: String) -> void:
	if set_id in _unlocked_sets:
		return
	_unlocked_sets.append(set_id)
	# 收集已持有/已吞噬的卡片 ID，避免重复加入卡池
	var owned_ids: Array[String] = []
	for h in held_cards:
		owned_ids.append(h.get("id", ""))
	for c in consumed_cards:
		owned_ids.append(c.get("id", ""))
	# 把该卡组的卡加入卡池（跳过已持有/已吞噬的）
	for card_id in _all_cards:
		var card: Dictionary = _all_cards[card_id]
		if card.get("set_id", "") == set_id and card_id not in _card_pool and card_id not in owned_ids:
			_card_pool.append(card_id)
	if _gm._combat_log_module:
		var I18n: Node = _gm.I18n
		var msg: String = I18n.t("POOL_UNLOCKED", [set_id]) if I18n else "New set: %s" % set_id
		_gm._combat_log_module._add_log(msg, Color(0.5, 1, 0.8))

# === 属性应用 ===

func _apply_card_stats(card_data: Dictionary) -> void:
	var stats: Dictionary = card_data.get("stats", {})
	_apply_stats_to_hero(stats)

func _apply_stats_to_hero(stats: Dictionary) -> void:
	var hero: Node3D = _gm.hero if _gm else null
	for stat_key: String in stats:
		var value: float = float(stats[stat_key])
		match stat_key:
			# --- 属性类：通过 StatSystem 绿字加成 ---
			"atk":
				if hero:
					EngineAPI.add_green_stat(hero, "atk", value)
			"hp":
				if hero:
					EngineAPI.add_green_stat(hero, "hp", value)
					# 同步更新 HealthComponent 当前值
					var health: Node = EngineAPI.get_component(hero, "health")
					if health:
						health.max_hp += value
						health.current_hp += value
			"armor":
				if hero:
					EngineAPI.add_green_stat(hero, "armor", value)
			"str", "strength":
				if hero:
					EngineAPI.add_green_stat(hero, "str", value)
			"agi", "agility":
				if hero:
					EngineAPI.add_green_stat(hero, "agi", value)
			"int", "intelligence":
				if hero:
					EngineAPI.add_green_stat(hero, "int", value)
			"all_stat":
				if hero:
					for s in ["str", "agi", "int"]:
						EngineAPI.add_green_stat(hero, s, value)
			# --- 百分比类：通过 StatSystem 绿字百分比 ---
			"str_pct":
				if hero:
					EngineAPI.add_green_percent(hero, "str", value)
			"agi_pct":
				if hero:
					EngineAPI.add_green_percent(hero, "agi", value)
			"int_pct":
				if hero:
					EngineAPI.add_green_percent(hero, "int", value)
			"aspd_pct":
				if hero:
					EngineAPI.add_green_percent(hero, "aspd", value)
			"crit_rate":
				if hero:
					EngineAPI.add_green_stat(hero, "crit_rate", value)
			"crit_dmg":
				if hero:
					EngineAPI.add_green_stat(hero, "crit_dmg", value)
			"regen":
				if hero:
					EngineAPI.add_green_stat(hero, "regen", value)
			"move_speed":
				if hero:
					EngineAPI.add_green_stat(hero, "move_speed", value)
			"splash_pct":
				if hero:
					EngineAPI.add_green_percent(hero, "splash", value)
			"boss_dmg":
				if hero:
					EngineAPI.add_green_percent(hero, "boss_dmg", value)
			# --- 资源/经济类：保持 variable/resource 方式 ---
			"gold_per_sec":
				var cur: float = float(EngineAPI.get_variable("hero_gold_per_sec", 0.0))
				EngineAPI.set_variable("hero_gold_per_sec", cur + value)
			"wood":
				EngineAPI.add_resource("wood", value)
			"gold":
				EngineAPI.add_resource("gold", value)

# === 卡片获取时效果 ===

## 迁移开关：启用后卡片效果走 SpellSystem，关闭则走旧 rogue_card_effects.gd
## 两者不可同时启用，否则效果会双倍触发
## 验证新路径后将此设为 true 并删除 rogue_card_effects.gd 中对应的旧代码
var _use_spell_system: bool = true

func _cast_card_spell(card_id: String) -> void:
	## 通过 SpellSystem 施放卡片 spell，挂载永久 aura/proc
	if not _use_spell_system:
		return  # 迁移未启用，效果仍由 rogue_card_effects.gd 处理
	var spell_sys: Node = EngineAPI.get_system("spell")
	if spell_sys == null:
		push_warning("[CardSystem] SpellSystem is null, cannot cast card spell")
		return
	var spell_key: String = "card_%s" % card_id
	if not spell_sys.has_spell(spell_key):
		push_warning("[CardSystem] Spell '%s' not registered, skipping cast" % spell_key)
		return
	var hero: Node3D = _gm.hero if _gm else null
	if hero == null or not is_instance_valid(hero):
		push_warning("[CardSystem] Hero is null, cannot cast spell")
		return
	spell_sys.cast(spell_key, hero)

func _apply_on_obtain_effects(card_id: String) -> void:
	## 数据驱动的获取时效果（从 spells.json 的 on_obtain 字段读取）
	var card_data: Dictionary = _all_cards.get(card_id, {})
	var on_obtain: Array = card_data.get("on_obtain", [])
	for action_def in on_obtain:
		if not (action_def is Dictionary):
			continue
		var action: String = action_def.get("action", "")
		match action:
			"register_modifier":
				var target: String = _safe_id(action_def.get("target_spell", ""))
				var key: String = action_def.get("key", "")
				var value = action_def.get("value", 0)
				register_skill_modifier(target, key, value, card_id)
			"unlock_set":
				var set_id: String = str(action_def.get("set_id", ""))
				_unlock_card_set(set_id)
			"unlock_card":
				var unlock_id: String = _safe_id(action_def.get("card_id", ""))
				if unlock_id not in _card_pool and _all_cards.has(unlock_id):
					_card_pool.append(unlock_id)

# === 吞噬条件检查 ===

func _check_consume_condition(card_data: Dictionary) -> bool:
	var cond: Dictionary = card_data.get("consume_condition", {})
	if cond.is_empty():
		return true  # 无条件，可随时吞噬
	var ctype: String = cond.get("type", "")
	match ctype:
		"auto":
			return true
		"bond_count":
			var bond_id: String = _safe_id(cond.get("bond_id", card_data.get("bond_id", "")))
			var required: int = cond.get("count", 3)
			return _bond_progress.get(bond_id, 0) >= required
		"bond_count_repeating":
			var bond_id: String = _safe_id(cond.get("bond_id", card_data.get("bond_id", "")))
			var per_batch: int = cond.get("count", 3)
			var total_owned: int = _bond_progress.get(bond_id, 0)
			# 已吞噬的该羁绊卡片数
			var consumed_count: int = 0
			for c in consumed_cards:
				if str(c.get("data", {}).get("bond_id", "")) == bond_id:
					consumed_count += 1
			# 当前应该吞噬的总批次 = total_owned / per_batch（向下取整）
			# 每批吞噬 per_batch 张，已吞噬 consumed_count 张
			@warning_ignore("INTEGER_DIVISION")
			var expected_consumed: int = (total_owned / per_batch) * per_batch
			return consumed_count < expected_consumed
		"kills":
			return int(EngineAPI.get_resource("kills")) >= cond.get("count", 0)
		"held_time":
			return true  # TODO: track hold duration
		"has_card":
			var need_id: String = _safe_id(cond.get("card_id", ""))
			for h in held_cards:
				if h.get("id", "") == need_id:
					return true
			for c in consumed_cards:
				if c.get("id", "") == need_id:
					return true
			return false
		"consumed_by":
			# Triggered externally by another card's effect; never auto-consume
			return false
		"timer":
			var required_time: float = cond.get("seconds", 0.0)
			var obtained_at: int = int(card_data.get("_obtained_at", 0))
			if obtained_at <= 0:
				return false
			var elapsed_ms: int = Time.get_ticks_msec() - obtained_at
			return elapsed_ms >= int(required_time * 1000.0)
		"attack_count":
			var required_attacks: int = cond.get("count", 0)
			var current_attacks: int = int(EngineAPI.get_variable("total_attacks", 0))
			return current_attacks >= required_attacks
		"mana_spent":
			var required_mana: float = cond.get("amount", 0.0)
			var current_mana: float = float(EngineAPI.get_variable("total_mana_spent", 0.0))
			return current_mana >= required_mana
		"level_up":
			var required_levels: int = cond.get("count", 0)
			var obtained_level: int = int(card_data.get("_obtained_level", 0))
			var current_level: int = int(EngineAPI.get_variable("hero_level", 1))
			return (current_level - obtained_level) >= required_levels
		"card_count":
			var required_total: int = cond.get("count", 0)
			return (held_cards.size() + consumed_cards.size()) >= required_total
		"ability_value":
			var ability_id: String = cond.get("ability_id", "")
			var threshold: float = cond.get("threshold", 0.0)
			if _gm and _gm.get("_ability_values") and _gm._ability_values:
				return _gm._ability_values.get_value(ability_id) >= threshold
			return false
	return true

# === 工具 ===

func _get_current_lang() -> String:
	if _gm and _gm.I18n and _gm.I18n.has_method("get_locale"):
		return _gm.I18n.get_locale()
	return "zh_CN"

func _get_card_display_name(card_data: Dictionary) -> String:
	return get_spell_name(card_data.get("id", ""))

func _safe_id(val) -> String:
	## 安全转换 ID 为整数字符串（避免 23.0 这种浮点格式）
	if val is float:
		return str(int(val))
	return str(val)

func build_card_bbcode(card_data: Dictionary) -> String:
	## 统一的卡片信息 BBCode（三选一/技能栏tooltip/已获羁绊 共用）
	var lines: Array[String] = []
	# 羁绊名 + 进度
	var bond_id: String = _safe_id(card_data.get("bond_id", ""))
	if bond_id != "" and bond_id != "0":
		var bname: String = _get_bond_display_name(bond_id)
		var prog: int = get_bond_progress(bond_id)
		var bond_def: Dictionary = _all_bonds.get(bond_id, {})
		var req: int = bond_def.get("required", 3)
		var prog_text: String = " [%d/%d]" % [prog, req] if req > 0 else ""
		lines.append("[color=#9980cc]<%s%s>[/color]" % [bname, prog_text])
	# 技能效果描述
	var desc: String = get_card_desc(card_data)
	if desc != "":
		lines.append("[color=#aaaacc]%s[/color]" % desc)
	# 属性
	var stats: Dictionary = card_data.get("stats", {})
	if not stats.is_empty():
		lines.append("[color=#555566]────────────[/color]")
		for sk: String in stats:
			lines.append("[color=#88cc88]%s[/color]" % _format_stat(sk, float(stats[sk])))
	# 吞噬条件
	var cond: Dictionary = card_data.get("consume_condition", {})
	if not cond.is_empty():
		lines.append("[color=#555566]────────────[/color]")
		var ctype: String = cond.get("type", "")
		var ct_text := ""
		match ctype:
			"bond_count":
				var cb_id: String = _safe_id(cond.get("bond_id", bond_id))
				ct_text = "%s >= %d" % [_get_bond_display_name(cb_id), cond.get("count", 3)]
			"bond_count_repeating":
				var cb_id: String = _safe_id(cond.get("bond_id", bond_id))
				var cnt: int = cond.get("count", 3)
				ct_text = "%s x%d" % [_get_bond_display_name(cb_id), cnt]
			"auto":
				ct_text = "Auto"
			"kills":
				ct_text = "Kills >= %d" % cond.get("count", 0)
			"card_count":
				ct_text = "Cards >= %d" % cond.get("count", 0)
			"timer":
				ct_text = "Hold %.0fs" % cond.get("seconds", 0)
		if ct_text != "":
			lines.append("[color=#997755]%s[/color]" % ct_text)
	return "\n".join(lines)

func get_spell_name(spell_id) -> String:
	## 通用：根据 spell ID 获取当前语言的名称
	var sid: String = str(spell_id)
	if _spell_locale.has(sid):
		return _spell_locale[sid].get("name", sid)
	return sid

func get_spell_desc(spell_id) -> String:
	## 通用：根据 spell ID 获取当前语言的描述
	var sid: String = str(spell_id)
	if _spell_locale.has(sid):
		return _spell_locale[sid].get("desc", "")
	return ""

func _get_bond_display_name(bond_id: String) -> String:
	return get_spell_name(bond_id)

func get_card_desc(card_data: Dictionary) -> String:
	var sid: String = str(card_data.get("id", ""))
	if sid != "":
		return get_spell_desc(sid)
	return ""

func get_bond_desc(bond_id: String) -> String:
	return get_spell_desc(bond_id)

func _get_tier_color(tier: int) -> Color:
	match tier:
		1: return Color(0.85, 0.85, 0.85)   # 普通
		2: return Color(0.3, 0.6, 1.0)      # 稀有
		3: return Color(0.7, 0.3, 0.9)      # 史诗
		4: return Color(1.0, 0.6, 0.1)      # 传说
		_: return Color.WHITE

# === 卡片和羁绊定义（原创 IP）===

var _spell_locale: Dictionary = {}  # spell_id(string) -> {name, desc}

func _init_cards() -> void:
	## 从统一 spells.json 加载所有数据（卡片/羁绊/技能/物品）
	var spells_path := "res://gamepacks/rogue_survivor/data/spells.json"
	var json_text := FileAccess.get_file_as_string(spells_path)
	if json_text == "":
		push_warning("[CardSystem] Cannot read spells.json")
		return
	var json := JSON.new()
	if json.parse(json_text) != OK:
		push_warning("[CardSystem] Failed to parse spells.json: %s" % json.get_error_message())
		return
	var all_spells: Dictionary = json.data
	for spell_id: String in all_spells:
		var data: Dictionary = all_spells[spell_id]
		data["id"] = spell_id
		var spell_type: String = data.get("type", "")
		match spell_type:
			"card":
				_all_cards[spell_id] = data
			"bond":
				_all_bonds[spell_id] = data
			"skill", "item":
				_all_skills[spell_id] = data
	# 加载当前语言的翻译
	_load_spell_locale()
	# 将带 proc 的卡片注册到 SpellSystem（迁移至框架层）
	_register_card_spells()

const SpellConverter = preload("res://gamepacks/rogue_survivor/scripts/rogue_spell_converter.gd")

func _register_card_spells() -> void:
	var count: int = SpellConverter.register_card_spells(_all_cards)
	# 同时注册 skill/item 类型的 spell
	var skill_count: int = SpellConverter.register_card_spells(_all_skills)
	count += skill_count
	if count > 0:
		print("[CardSystem] Registered %d spells with SpellSystem" % count)

# _convert_to_spell_def 和 _build_proc_spell 已移至 rogue_spell_converter.gd
func _init_bonds() -> void:
	pass  # 已在 _init_cards 中统一加载

func _load_spell_locale() -> void:
	## 加载当前语言的 spell 翻译文件
	var lang: String = _get_current_lang()
	var locale_path := "res://gamepacks/rogue_survivor/data/spells_%s.json" % lang
	if not FileAccess.file_exists(locale_path):
		locale_path = "res://gamepacks/rogue_survivor/data/spells_en.json"
	var json_text := FileAccess.get_file_as_string(locale_path)
	if json_text == "":
		return
	var json := JSON.new()
	if json.parse(json_text) == OK:
		_spell_locale = json.data
