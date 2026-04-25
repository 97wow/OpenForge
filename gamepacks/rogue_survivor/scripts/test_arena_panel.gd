## TestArenaPanel — 框架测试调试面板（标签式布局）
## 测试所有框架系统：Phase1 战斗核心 + Phase2 游戏内容支撑
## 通过 test_mode=true 进入地图时自动加载

var _gm  # rogue_game_mode 引用
var _log_label: RichTextLabel = null
# 施法条
var _cast_bar_bg: ColorRect = null
var _cast_bar_fill: ColorRect = null
var _cast_bar_label: Label = null
var _cast_bar_tween: Tween = null
# 技能栏配置：[spell_id, 显示名, 快捷键名, 描述]
const SKILL_BAR: Array = [
	["test_frost_bolt", "冰箭", "Q", "瞬发 50冰霜伤害+减速"],
	["test_fireball", "火球", "W", "读条2秒 120火焰伤害"],
	["test_drain_life", "吸血", "E", "引导4秒 每秒25伤害+15治疗"],
	["test_stun_bolt", "雷击", "R", "瞬发 30自然伤害+3秒眩晕"],
	["test_heal", "治疗", "1", "读条1.5秒 治疗自身80"],
	["", "", "2", ""],
	["", "", "3", ""],
	["", "", "4", ""],
]
var _skill_labels: Array = []  # CD 显示用

# Phase 2 测试用跟踪
var _test_area_aura_id: int = -1
var _test_spawn_group_id: String = ""
var _test_inventory_panel = null  # InventoryPanel
var _test_instance_id: int = -1
var _test_quest_registered: bool = false

func init(game_mode) -> void:
	_gm = game_mode

func create_panel() -> void:
	var ui_layer: CanvasLayer = _gm.get_tree().current_scene.get_node_or_null("UI")
	if ui_layer == null:
		return

	# 清空 UI 层（测试模式不用 rogue_survivor HUD）
	for child in ui_layer.get_children():
		child.queue_free()

	# 关闭英雄自动攻击
	if _gm.hero and is_instance_valid(_gm.hero):
		var pi: Node = EngineAPI.get_component(_gm.hero, "player_input")
		if pi:
			pi.auto_attack_enabled = false

	# === 左侧标签面板 ===
	var panel := PanelContainer.new()
	panel.anchor_right = 0.0
	panel.offset_left = 5
	panel.offset_top = 5
	panel.offset_right = 300
	panel.offset_bottom = 750
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.92)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	ui_layer.add_child(panel)

	# TabContainer（横向标签栏）
	var tabs := TabContainer.new()
	tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tabs.add_theme_font_size_override("font_size", 10)
	tabs.clip_tabs = false
	tabs.tab_alignment = TabBar.ALIGNMENT_LEFT
	panel.add_child(tabs)

	# --- Tab 1: 战斗核心 ---
	_create_tab_combat(tabs)
	# --- Tab 2: Area Aura ---
	_create_tab_area_aura(tabs)
	# --- Tab 3: 免疫系统 ---
	_create_tab_immunity(tabs)
	# --- Tab 4: 重生/阵营 ---
	_create_tab_spawn_faction(tabs)
	# --- Tab 5: 移动生成器 ---
	_create_tab_movement(tabs)
	# --- Tab 6: 掉落/背包 ---
	_create_tab_loot(tabs)
	# --- Tab 7: DR/Boss ---
	_create_tab_dr_boss(tabs)
	# --- Tab 8: 任务/成就 ---
	_create_tab_quest_achievement(tabs)
	# --- Tab 9: 网络/录制 ---
	_create_tab_network_replay(tabs)
	# --- Tab 10: 等级/对话/存档/镜头/音频 ---
	_create_tab_core_systems(tabs)

	# === 右侧日志面板 ===
	_log_label = RichTextLabel.new()
	_log_label.anchor_left = 1.0
	_log_label.anchor_right = 1.0
	_log_label.anchor_top = 0.0
	_log_label.anchor_bottom = 1.0
	_log_label.offset_left = -420
	_log_label.offset_top = 5
	_log_label.offset_right = -5
	_log_label.offset_bottom = -100
	_log_label.bbcode_enabled = true
	_log_label.scroll_following = true
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0.02, 0.02, 0.06, 0.92)
	log_style.content_margin_left = 8
	log_style.content_margin_right = 8
	log_style.content_margin_top = 6
	log_style.content_margin_bottom = 6
	log_style.corner_radius_top_left = 6
	log_style.corner_radius_top_right = 6
	_log_label.add_theme_stylebox_override("normal", log_style)
	_log_label.add_theme_font_size_override("normal_font_size", 11)
	ui_layer.add_child(_log_label)

	# === 底部技能栏 + 施法条 ===
	_create_skill_bar(ui_layer)
	_create_cast_bar(ui_layer)

	# 监听事件
	EventBus.connect_event("unit_flags_changed", _on_flags_changed)
	EventBus.connect_event("entity_damaged", _on_entity_damaged)
	EventBus.connect_event("ai_entered_combat", _on_ai_combat)
	EventBus.connect_event("ai_enter_evade", _on_ai_evade)
	EventBus.connect_event("ai_returned_home", _on_ai_home)
	EventBus.connect_event("entity_killed", _on_entity_killed)
	EventBus.connect_event("spell_interrupted", _on_spell_interrupted)
	EventBus.connect_event("spell_cast_start", _on_cast_bar_start)
	EventBus.connect_event("spell_channel_start", _on_channel_bar_start)
	EventBus.connect_event("spell_cast", _on_cast_bar_end)
	EventBus.connect_event("spell_interrupted", _on_cast_bar_interrupted)
	EventBus.connect_event("area_aura_created", _on_area_aura_event.bind("created"))
	EventBus.connect_event("area_aura_destroyed", _on_area_aura_event.bind("destroyed"))
	EventBus.connect_event("immunity_changed", _on_immunity_changed)
	EventBus.connect_event("entity_respawned", _on_entity_respawned)
	EventBus.connect_event("faction_changed", _on_faction_changed)
	EventBus.connect_event("reputation_changed", _on_reputation_changed)
	EventBus.connect_event("movement_arrived", _on_movement_arrived)
	EventBus.connect_event("dr_applied", _on_dr_applied)
	EventBus.connect_event("encounter_started", _on_encounter_event.bind("started"))
	EventBus.connect_event("encounter_completed", _on_encounter_event.bind("completed"))
	EventBus.connect_event("encounter_failed", _on_encounter_event.bind("failed"))
	EventBus.connect_event("encounter_phase_changed", _on_encounter_event.bind("phase"))
	EventBus.connect_event("quest_objective_updated", _on_quest_objective)
	EventBus.connect_event("quest_complete", _on_quest_event.bind("complete"))
	EventBus.connect_event("quest_turned_in", _on_quest_event.bind("turned_in"))
	EventBus.connect_event("achievement_completed", _on_achievement_event.bind("completed"))
	EventBus.connect_event("replay_event", _on_replay_event)
	EventBus.connect_event("replay_playback_finished", _on_replay_finished)
	EventBus.connect_event("level_up", _on_level_up)
	EventBus.connect_event("xp_gained", _on_xp_gained)
	EventBus.connect_event("dialogue_node_entered", _on_dialogue_node)
	EventBus.connect_event("dialogue_ended", _on_dialogue_ended)

	_log("[color=yellow]>>> 测试竞技场已就绪 <<<[/color]")
	_log("使用左侧标签页测试各项框架功能")

# =============================================================================
# TAB 1: 战斗核心（Phase 1 原有功能）
# =============================================================================

func _create_tab_combat(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "战斗"
	tabs.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	_section(vbox, "-- 生成 --")
	_btn(vbox, "生成 3 哥布林", _spawn_enemies.bind("goblin", 3))
	_btn(vbox, "生成 3 骷髅", _spawn_enemies.bind("skeleton", 3))
	_btn(vbox, "生成 1 弓箭手", _spawn_enemies.bind("archer", 1))
	_btn(vbox, "生成 1 石像鬼", _spawn_enemies.bind("golem", 1))
	_btn(vbox, "生成骨龙 BOSS", _spawn_enemies.bind("bone_dragon", 1))
	_btn(vbox, "生成训练假人", _spawn_training_dummy)
	_btn(vbox, "清除所有敌人", _kill_all_enemies)

	_section(vbox, "-- CC 控制 --")
	_btn(vbox, "眩晕英雄 3秒", _apply_cc_to_hero.bind("CC_STUN", 3.0))
	_btn(vbox, "定身英雄 3秒", _apply_cc_to_hero.bind("CC_ROOT", 3.0))
	_btn(vbox, "沉默英雄 3秒", _apply_cc_to_hero.bind("CC_SILENCE", 3.0))
	_btn(vbox, "恐惧英雄 3秒", _apply_cc_to_hero.bind("CC_FEAR", 3.0))
	_btn(vbox, "眩晕所有敌人 3秒", _apply_cc_to_enemies.bind("CC_STUN", 3.0))

	_section(vbox, "-- 旧免疫（UnitFlag）--")
	_btn(vbox, "英雄 免伤 开", _set_hero_flag.bind(UnitFlags.IMMUNE_DAMAGE, true))
	_btn(vbox, "英雄 免伤 关", _set_hero_flag.bind(UnitFlags.IMMUNE_DAMAGE, false))
	_btn(vbox, "英雄 免控 开", _set_hero_flag.bind(UnitFlags.IMMUNE_CC, true))
	_btn(vbox, "英雄 免控 关", _set_hero_flag.bind(UnitFlags.IMMUNE_CC, false))

	_section(vbox, "-- 仇恨/伤害 --")
	_btn(vbox, "查看最近敌人仇恨列表", _show_threat_list)
	_btn(vbox, "嘲讽最近敌人 5秒", _taunt_nearest)
	_btn(vbox, "测试脱战：传送到远处", _test_evade)
	_btn(vbox, "加 100 吸收盾", _add_absorb_shield)
	_btn(vbox, "对最近敌人 999 伤害", _deal_test_damage)

	_section(vbox, "-- 施法 --")
	_btn(vbox, "读条施法 2秒", _test_cast_time)
	_btn(vbox, "引导施法 3秒", _test_channel)

	_section(vbox, "-- 目标查询 --")
	_btn(vbox, "英雄的敌对目标", _log_query.bind("hostiles"))
	_btn(vbox, "英雄的友方单位", _log_query.bind("allies"))
	_btn(vbox, "敌人眼中的敌对目标", _log_query.bind("enemy_hostiles"))

# =============================================================================
# TAB 2: Area Aura（地面持续效果）
# =============================================================================

func _create_tab_area_aura(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "地面效果"
	tabs.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	_section(vbox, "-- AREA_DAMAGE（伤害区）--")
	_hint(vbox, "在英雄前方创建持续伤害区域")
	_btn(vbox, "火焰区（火圈 10秒）", _create_test_area.bind("AREA_DAMAGE", "fire", "ENEMY"))
	_btn(vbox, "冰霜区（冰圈 10秒）", _create_test_area.bind("AREA_DAMAGE", "frost", "ENEMY"))
	_btn(vbox, "暗影区（毒池 10秒）", _create_test_area.bind("AREA_DAMAGE", "shadow", "ENEMY"))
	_btn(vbox, "自然区（毒雾 10秒）", _create_test_area.bind("AREA_DAMAGE", "nature", "ENEMY"))

	_section(vbox, "-- AREA_HEAL（治疗区）--")
	_hint(vbox, "在英雄脚下创建治疗光环")
	_btn(vbox, "治疗泉（跟随英雄 8秒）", _create_heal_area)

	_section(vbox, "-- AREA_SLOW（减速区）--")
	_hint(vbox, "进入时减速50%，离开恢复")
	_btn(vbox, "冰霜减速区 10秒", _create_slow_area)

	_section(vbox, "-- 管理 --")
	_btn(vbox, "销毁最近创建的区域", _destroy_last_area)
	_btn(vbox, "查看所有活跃 Area Aura", _list_area_auras)

func _create_test_area(area_type: String, school: String, target_filter: String) -> void:
	var hero_pos: Vector3 = _gm.hero.global_position if _gm.hero else Vector3(9.6, 0, 5.4)
	var pos := hero_pos + Vector3(-1.5, 0, 0)
	var area_sys: Node = EngineAPI.get_system("area_aura")
	if area_sys == null:
		_log("[color=red]AreaAuraSystem 未注册[/color]")
		return
	var area_id: int = area_sys.call("create_area_aura", {
		"caster": _gm.hero,
		"position": pos,
		"radius": 1.2,
		"duration": 10.0,
		"period": 1.0,
		"type": area_type,
		"school": school,
		"base_points": 15.0,
		"target_filter": target_filter,
		"spell_id": "test_%s_%s" % [area_type.to_lower(), school],
	})
	_test_area_aura_id = area_id
	_log("[color=orange]>>> 创建 %s（%s）[/color] ID=%d 半径=1.2 持续10秒" % [area_type, school, area_id])
	_log("  位置=(%d,%d) 每秒15伤害 目标=%s" % [int(pos.x), int(pos.y), target_filter])

func _create_heal_area() -> void:
	var hero_pos: Vector3 = _gm.hero.global_position if _gm.hero else Vector3(9.6, 0, 5.4)
	var area_sys: Node = EngineAPI.get_system("area_aura")
	if area_sys == null:
		_log("[color=red]AreaAuraSystem 未注册[/color]")
		return
	var area_id: int = area_sys.call("create_area_aura", {
		"caster": _gm.hero,
		"position": hero_pos,
		"radius": 1.0,
		"duration": 8.0,
		"period": 1.0,
		"type": "AREA_HEAL",
		"school": "holy",
		"base_points": 20.0,
		"target_filter": "ALLY",
		"spell_id": "test_healing_spring",
		"follow_caster": true,
	})
	_test_area_aura_id = area_id
	_log("[color=green]>>> 创建治疗泉[/color] ID=%d 跟随英雄 每秒20治疗 持续8秒" % area_id)

func _create_slow_area() -> void:
	var hero_pos: Vector3 = _gm.hero.global_position if _gm.hero else Vector3(9.6, 0, 5.4)
	var pos := hero_pos + Vector3(-1.5, 0, 0)
	var area_sys: Node = EngineAPI.get_system("area_aura")
	if area_sys == null:
		return
	var area_id: int = area_sys.call("create_area_aura", {
		"caster": _gm.hero,
		"position": pos,
		"radius": 1.3,
		"duration": 10.0,
		"period": 0.5,
		"type": "AREA_SLOW",
		"school": "frost",
		"base_points": 0.5,
		"target_filter": "ENEMY",
		"spell_id": "test_frost_zone",
	})
	_test_area_aura_id = area_id
	_log("[color=cyan]>>> 创建冰霜减速区[/color] ID=%d 50%%减速 持续10秒" % area_id)

func _destroy_last_area() -> void:
	if _test_area_aura_id < 0:
		_log("[color=yellow]没有可销毁的 Area Aura[/color]")
		return
	EngineAPI.destroy_area_aura(_test_area_aura_id)
	_log("[color=red]>>> 销毁 Area Aura ID=%d[/color]" % _test_area_aura_id)
	_test_area_aura_id = -1

func _list_area_auras() -> void:
	var area_sys: Node = EngineAPI.get_system("area_aura")
	if area_sys == null:
		return
	var all: Dictionary = area_sys.call("get_all_area_auras")
	_log("[color=yellow]--- 活跃 Area Aura（%d个）---[/color]" % all.size())
	for aid in all:
		var a: Dictionary = all[aid]
		_log("  ID=%d type=%s school=%s 剩余=%.1f秒" % [
			aid, a.get("type", "?"), a.get("school", "?"), a.get("remaining", 0)])

func _on_area_aura_event(data: Dictionary, event_type: String) -> void:
	if event_type == "created":
		# 已在创建时手动 log
		pass
	elif event_type == "destroyed":
		var aid: int = data.get("area_id", -1)
		_log("[color=gray]Area Aura ID=%d 已消失[/color]" % aid)

# =============================================================================
# TAB 3: 免疫系统（ImmunitySystem）
# =============================================================================

func _create_tab_immunity(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "免疫"
	tabs.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	_section(vbox, "-- 学校免疫 --")
	_hint(vbox, "授予后，该学校伤害变为0")
	_btn(vbox, "英雄 免疫火焰 开", _toggle_school_immunity.bind("fire", true))
	_btn(vbox, "英雄 免疫火焰 关", _toggle_school_immunity.bind("fire", false))
	_btn(vbox, "英雄 免疫冰霜 开", _toggle_school_immunity.bind("frost", true))
	_btn(vbox, "英雄 免疫冰霜 关", _toggle_school_immunity.bind("frost", false))
	_btn(vbox, "英雄 免疫暗影 开", _toggle_school_immunity.bind("shadow", true))
	_btn(vbox, "英雄 免疫暗影 关", _toggle_school_immunity.bind("shadow", false))
	_btn(vbox, "英雄 免疫全魔法 开", _toggle_school_immunity.bind("all_magic", true))
	_btn(vbox, "英雄 免疫全魔法 关", _toggle_school_immunity.bind("all_magic", false))

	_section(vbox, "-- 机制免疫 --")
	_hint(vbox, "授予后，对应CC无法施加+自动驱散")
	_btn(vbox, "英雄 免疫眩晕 开", _toggle_mechanic_immunity.bind("STUN", true))
	_btn(vbox, "英雄 免疫眩晕 关", _toggle_mechanic_immunity.bind("STUN", false))
	_btn(vbox, "英雄 免疫定身 开", _toggle_mechanic_immunity.bind("ROOT", true))
	_btn(vbox, "英雄 免疫定身 关", _toggle_mechanic_immunity.bind("ROOT", false))
	_btn(vbox, "英雄 免疫恐惧 开", _toggle_mechanic_immunity.bind("FEAR", true))
	_btn(vbox, "英雄 免疫恐惧 关", _toggle_mechanic_immunity.bind("FEAR", false))
	_btn(vbox, "英雄 免疫减速 开", _toggle_mechanic_immunity.bind("SLOW", true))
	_btn(vbox, "英雄 免疫减速 关", _toggle_mechanic_immunity.bind("SLOW", false))

	_section(vbox, "-- 查询 --")
	_btn(vbox, "查看英雄免疫状态", _show_immunity_status)

	_section(vbox, "-- 验证组合 --")
	_hint(vbox, "先开免疫眩晕，再点眩晕英雄 → 应无效")
	_hint(vbox, "先眩晕英雄，再开免疫眩晕 → 应立即驱散")
	_hint(vbox, "开免疫火焰+创建火焰区 → 英雄进入无伤")

func _toggle_school_immunity(school_str: String, grant: bool) -> void:
	if _gm.hero == null or not is_instance_valid(_gm.hero):
		return
	var imm_sys: Node = EngineAPI.get_system("immunity")
	if imm_sys == null:
		_log("[color=red]ImmunitySystem 未注册[/color]")
		return
	var school_mask: int = ImmunitySystem.school_from_string(school_str)
	if grant:
		imm_sys.call("grant_school_immunity", _gm.hero, school_mask, "test_" + school_str)
		_log("[color=green]>>> 英雄 获得 %s 免疫[/color]" % ImmunitySystem.school_to_string(school_mask))
	else:
		imm_sys.call("revoke_school_immunity", _gm.hero, "test_" + school_str)
		_log("[color=red]>>> 英雄 失去 %s 免疫[/color]" % school_str)

func _toggle_mechanic_immunity(mechanic: String, grant: bool) -> void:
	if _gm.hero == null or not is_instance_valid(_gm.hero):
		return
	var imm_sys: Node = EngineAPI.get_system("immunity")
	if imm_sys == null:
		_log("[color=red]ImmunitySystem 未注册[/color]")
		return
	if grant:
		imm_sys.call("grant_mechanic_immunity", _gm.hero, mechanic, "test_" + mechanic)
		_log("[color=green]>>> 英雄 获得 %s 机制免疫[/color]" % mechanic)
	else:
		imm_sys.call("revoke_mechanic_immunity", _gm.hero, mechanic, "test_" + mechanic)
		_log("[color=red]>>> 英雄 失去 %s 机制免疫[/color]" % mechanic)

func _show_immunity_status() -> void:
	if _gm.hero == null or not is_instance_valid(_gm.hero):
		return
	var imm_sys: Node = EngineAPI.get_system("immunity")
	if imm_sys == null:
		return
	var info: Dictionary = imm_sys.call("get_immunities", _gm.hero)
	var school_mask: int = info.get("school_mask", 0)
	var mechanics: Array = info.get("mechanics", [])
	_log("[color=yellow]--- 英雄免疫状态 ---[/color]")
	_log("  学校免疫: %s" % (ImmunitySystem.school_to_string(school_mask) if school_mask != 0 else "无"))
	_log("  机制免疫: %s" % (", ".join(mechanics) if mechanics.size() > 0 else "无"))

func _on_immunity_changed(data: Dictionary) -> void:
	var entity = data.get("entity")
	var e_name: String = (entity as GameEntity).def_id if entity is GameEntity else "?"
	var granted: bool = data.get("granted", false)
	var imm_type: String = data.get("type", "")
	if imm_type == "school":
		var mask: int = data.get("school_mask", 0)
		_log("[color=purple]免疫变化[/color] %s %s %s" % [
			e_name, "获得" if granted else "失去",
			ImmunitySystem.school_to_string(mask)])
	elif imm_type == "mechanic":
		_log("[color=purple]免疫变化[/color] %s %s %s免疫" % [
			e_name, "获得" if granted else "失去", data.get("mechanic", "?")])

# =============================================================================
# TAB 4: 重生 + 多阵营
# =============================================================================

func _create_tab_spawn_faction(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "重生/阵营"
	tabs.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	_section(vbox, "-- Respawn 系统 --")
	_hint(vbox, "注册刷新组后，杀死敌人会在5秒后重生")
	_btn(vbox, "注册哥布林刷新组（3只 5秒重生）", _register_test_spawn_group)
	_btn(vbox, "生成刷新组", _activate_spawn_group)
	_btn(vbox, "强制重生所有待重生", _force_respawn_all)
	_btn(vbox, "关闭刷新组", _disable_spawn_group)
	_btn(vbox, "查看待重生列表", _show_pending_respawns)

	_section(vbox, "-- 阵营测试 --")
	_btn(vbox, "生成友方暗影兽（10秒）", _spawn_friendly)
	_btn(vbox, "生成中立石像鬼", _spawn_neutral)

	_section(vbox, "-- 多阵营系统 --")
	_hint(vbox, "注册自定义阵营+动态修改关系")
	_btn(vbox, "注册第三阵营 'undead'", _register_undead_faction)
	_btn(vbox, "生成亡灵阵营骷髅", _spawn_undead_enemy)
	_btn(vbox, "undead 对 player 设为友好", _set_undead_friendly)
	_btn(vbox, "undead 对 player 恢复敌对", _set_undead_hostile)

	_section(vbox, "-- 声望系统 --")
	_btn(vbox, "对 undead +3000 声望", _add_undead_rep.bind(3000))
	_btn(vbox, "对 undead -3000 声望", _add_undead_rep.bind(-3000))
	_btn(vbox, "查看所有声望", _show_reputation)
	_btn(vbox, "查看阵营关系", _show_faction_reactions)

func _register_test_spawn_group() -> void:
	var respawn_sys: Node = EngineAPI.get_system("respawn")
	if respawn_sys == null:
		_log("[color=red]RespawnSystem 未注册[/color]")
		return
	var hero_pos: Vector3 = _gm.hero.global_position if _gm.hero else Vector3(9.6, 0, 5.4)
	_test_spawn_group_id = respawn_sys.call("register_spawn_group", {
		"group_id": "test_goblins",
		"entries": [
			{"def_id": "goblin", "position": hero_pos + Vector3(-2.0, 0, -0.5)},
			{"def_id": "goblin", "position": hero_pos + Vector3(-2.0, 0, 0)},
			{"def_id": "goblin", "position": hero_pos + Vector3(-2.0, 0, 0.5)},
		],
		"respawn_time": 5.0,
		"max_alive": 3,
	})
	_log("[color=green]>>> 注册刷新组[/color] '%s' | 3只哥布林 | 5秒重生 | 最多存活3只" % _test_spawn_group_id)

func _activate_spawn_group() -> void:
	if _test_spawn_group_id == "":
		_log("[color=red]请先注册刷新组[/color]")
		return
	var spawned: Array = EngineAPI.spawn_group(_test_spawn_group_id)
	_log("[color=green]>>> 生成刷新组[/color] 生成了 %d 只" % spawned.size())

func _force_respawn_all() -> void:
	if _test_spawn_group_id == "":
		_log("[color=red]请先注册刷新组[/color]")
		return
	var respawn_sys: Node = EngineAPI.get_system("respawn")
	if respawn_sys:
		respawn_sys.call("force_respawn", _test_spawn_group_id)
	_log("[color=green]>>> 强制重生所有待重生实体[/color]")

func _disable_spawn_group() -> void:
	if _test_spawn_group_id == "":
		return
	var respawn_sys: Node = EngineAPI.get_system("respawn")
	if respawn_sys:
		respawn_sys.call("set_group_enabled", _test_spawn_group_id, false)
	_log("[color=red]>>> 关闭刷新组[/color] '%s'" % _test_spawn_group_id)

func _show_pending_respawns() -> void:
	var respawn_sys: Node = EngineAPI.get_system("respawn")
	if respawn_sys == null:
		return
	var pending: Array = respawn_sys.call("get_pending_respawns")
	_log("[color=yellow]--- 待重生列表（%d个）---[/color]" % pending.size())
	for p in pending:
		_log("  组=%s 实体=%s 剩余=%.1f秒" % [p.get("group_id", "?"), p.get("def_id", "?"), p.get("remaining", 0)])
	if pending.is_empty():
		_log("  （无待重生）")

func _on_entity_respawned(data: Dictionary) -> void:
	var entity = data.get("entity")
	var group_id: String = data.get("group_id", "")
	var e_name: String = (entity as GameEntity).def_id if entity is GameEntity else "?"
	_log("[color=green]重生[/color] %s（组=%s）" % [e_name, group_id])

func _register_undead_faction() -> void:
	var faction_sys: Node = EngineAPI.get_system("faction")
	if faction_sys == null:
		_log("[color=red]FactionSystem 未注册[/color]")
		return
	faction_sys.call("register_faction", {
		"faction_id": "undead",
		"name_key": "FACTION_UNDEAD",
		"base_reactions": {
			"player": FactionSystem.Reaction.HOSTILE,
			"enemy": FactionSystem.Reaction.NEUTRAL,
			"neutral": FactionSystem.Reaction.NEUTRAL,
		},
	})
	_log("[color=purple]>>> 注册阵营 'undead'[/color] | 对player敌对 | 对enemy中立")

func _spawn_undead_enemy() -> void:
	var hero_pos: Vector3 = _gm.hero.global_position if _gm.hero else Vector3(9.6, 0, 5.4)
	var pos := hero_pos + Vector3(-2.0, 0, 0)
	var e: Node3D = _gm.spawn("skeleton", pos, {
		"faction": "undead",
		"tags": ["undead", "mobile", "ground", "enemy"],
	})
	if e and e is GameEntity:
		# 通过 FactionSystem 设置阵营
		var faction_sys: Node = EngineAPI.get_system("faction")
		if faction_sys:
			faction_sys.call("set_entity_faction", e, "undead")
		_log("[color=purple]+ 生成亡灵骷髅[/color] | 阵营=undead | 与player关系取决于FactionSystem")

func _set_undead_friendly() -> void:
	var faction_sys: Node = EngineAPI.get_system("faction")
	if faction_sys:
		faction_sys.call("set_reaction_override", "undead", "player", FactionSystem.Reaction.FRIENDLY)
		# 阵营关系不传递：需要手动设置每对敌对关系
		faction_sys.call("set_reaction_override", "undead", "enemy", FactionSystem.Reaction.HOSTILE)
	_log("[color=green]>>> undead↔player=FRIENDLY, undead↔enemy=HOSTILE[/color]")

func _set_undead_hostile() -> void:
	var faction_sys: Node = EngineAPI.get_system("faction")
	if faction_sys:
		faction_sys.call("set_reaction_override", "undead", "player", FactionSystem.Reaction.HOSTILE)
	_log("[color=red]>>> undead ↔ player 关系改为 HOSTILE[/color]")

func _add_undead_rep(amount: float) -> void:
	var faction_sys: Node = EngineAPI.get_system("faction")
	if faction_sys:
		faction_sys.call("add_reputation", "player", "undead", amount)
	var sign_str: String = "+" if amount > 0 else ""
	_log("[color=cyan]>>> player 对 undead 声望 %s%.0f[/color]" % [sign_str, amount])

func _show_reputation() -> void:
	var faction_sys: Node = EngineAPI.get_system("faction")
	if faction_sys == null:
		return
	_log("[color=yellow]--- 声望 ---[/color]")
	for fid in ["player", "enemy", "neutral", "undead"]:
		var rep: float = faction_sys.call("get_reputation", "player", fid)
		var rank: int = faction_sys.call("get_reputation_rank", "player", fid)
		if rep != 0:
			_log("  %s: %.0f (%s)" % [fid, rep, FactionSystem.rank_to_string(rank)])

func _show_faction_reactions() -> void:
	var faction_sys: Node = EngineAPI.get_system("faction")
	if faction_sys == null:
		return
	var factions: Array = faction_sys.call("get_all_factions")
	_log("[color=yellow]--- 阵营关系 ---[/color]")
	for a in factions:
		for b in factions:
			if a >= b:
				continue
			var reaction: int = faction_sys.call("get_reaction", a, b)
			_log("  %s ↔ %s: %s" % [a, b, FactionSystem.rank_to_string(reaction)])

func _on_faction_changed(data: Dictionary) -> void:
	var entity = data.get("entity")
	var e_name: String = (entity as GameEntity).def_id if entity is GameEntity else "?"
	_log("[color=purple]阵营变化[/color] %s: %s → %s" % [e_name, data.get("old_faction", "?"), data.get("new_faction", "?")])

func _on_reputation_changed(data: Dictionary) -> void:
	var fid: String = data.get("faction_id", "?")
	var old_val: float = data.get("old_value", 0)
	var new_val: float = data.get("new_value", 0)
	var rank_changed: bool = data.get("rank_changed", false)
	var msg := "声望: %s %.0f → %.0f" % [fid, old_val, new_val]
	if rank_changed:
		msg += " [等级变化→%s]" % FactionSystem.rank_to_string(data.get("new_rank", 0))
	_log("[color=cyan]%s[/color]" % msg)

# =============================================================================
# TAB 5: 移动生成器（MovementGenerator）
# =============================================================================

func _create_tab_movement(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "移动"
	tabs.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	_section(vbox, "-- 移动行为 --")
	_hint(vbox, "先生成怪物再测试")
	_btn(vbox, "最近敌人 → 随机闲逛", _test_move_random)
	_btn(vbox, "最近敌人 → 逃离英雄 3秒", _test_move_flee)
	_btn(vbox, "最近敌人 → 移动到指定点", _test_move_point)
	_btn(vbox, "最近敌人 → 跟随英雄", _test_move_follow)

	_section(vbox, "-- 强制位移 --")
	_hint(vbox, "击退/冲锋，最高优先级")
	_btn(vbox, "击退最近敌人", _test_knockback)
	_btn(vbox, "英雄冲锋到最近敌人", _test_charge)

	_section(vbox, "-- 恐惧联动 --")
	_hint(vbox, "FEARED flag→自动CONFUSED移动")
	_btn(vbox, "恐惧最近敌人 5秒", _test_fear_movement)

	_section(vbox, "-- 管理 --")
	_btn(vbox, "清除最近敌人所有移动", _test_clear_movement)
	_btn(vbox, "查看最近敌人移动栈", _show_move_stack)

func _get_nearest_enemy() -> GameEntity:
	if _gm.hero == null or not is_instance_valid(_gm.hero):
		return null
	var enemies: Array = EngineAPI.find_entities_by_tag("enemy")
	var nearest: GameEntity = null
	var nearest_dist := INF
	for e in enemies:
		if not is_instance_valid(e) or not (e is GameEntity):
			continue
		var d: float = _gm.hero.global_position.distance_squared_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e as GameEntity
	return nearest

func _test_move_random() -> void:
	var enemy: GameEntity = _get_nearest_enemy()
	if enemy == null:
		_log("[color=red]没有敌人[/color]")
		return
	var move_gen: Node = EngineAPI.get_system("movement_gen")
	if move_gen:
		move_gen.call("move_random", enemy, 1.5, 1.0, 3.0)
	_log("[color=cyan]>>> %s 开始随机闲逛（半径1.5）[/color]" % enemy.def_id)

func _test_move_flee() -> void:
	var enemy: GameEntity = _get_nearest_enemy()
	if enemy == null:
		_log("[color=red]没有敌人[/color]")
		return
	var move_gen: Node = EngineAPI.get_system("movement_gen")
	if move_gen and _gm.hero is GameEntity:
		move_gen.call("move_flee", enemy, _gm.hero, 3.0)
	_log("[color=cyan]>>> %s 逃离英雄 3秒[/color]" % enemy.def_id)

func _test_move_point() -> void:
	var enemy: GameEntity = _get_nearest_enemy()
	if enemy == null:
		_log("[color=red]没有敌人[/color]")
		return
	var target_pos := Vector2(9.6, 5.4)  # 世界中心
	var move_gen: Node = EngineAPI.get_system("movement_gen")
	if move_gen:
		move_gen.call("move_point", enemy, target_pos)
	_log("[color=cyan]>>> %s 移动到世界中心 (9.6,5.4)[/color]" % enemy.def_id)

func _test_move_follow() -> void:
	var enemy: GameEntity = _get_nearest_enemy()
	if enemy == null:
		_log("[color=red]没有敌人[/color]")
		return
	var move_gen: Node = EngineAPI.get_system("movement_gen")
	if move_gen and _gm.hero is GameEntity:
		move_gen.call("move_follow", enemy, _gm.hero, 0.8)
	_log("[color=cyan]>>> %s 跟随英雄（距离0.8停下）[/color]" % enemy.def_id)

func _test_knockback() -> void:
	var enemy: GameEntity = _get_nearest_enemy()
	if enemy == null:
		_log("[color=red]没有敌人[/color]")
		return
	var hero_pos: Vector3 = _gm.hero.global_position if _gm.hero else Vector3(9.6, 0, 5.4)
	var dir: Vector3 = hero_pos.direction_to(enemy.global_position)
	var knockback_pos: Vector3 = enemy.global_position + dir * 2.0
	var move_gen: Node = EngineAPI.get_system("movement_gen")
	if move_gen:
		move_gen.call("move_effect", enemy, knockback_pos, 0.3, 4.0)
	_log("[color=orange]>>> 击退 %s 2.0m[/color]" % enemy.def_id)

func _test_charge() -> void:
	var enemy: GameEntity = _get_nearest_enemy()
	if enemy == null:
		_log("[color=red]没有敌人[/color]")
		return
	if _gm.hero == null or not (_gm.hero is GameEntity):
		return
	var move_gen: Node = EngineAPI.get_system("movement_gen")
	if move_gen:
		move_gen.call("move_effect", _gm.hero, enemy.global_position, 0.2, 5.0)
	_log("[color=orange]>>> 英雄冲锋到 %s[/color]" % enemy.def_id)

func _test_fear_movement() -> void:
	var enemy: GameEntity = _get_nearest_enemy()
	if enemy == null:
		_log("[color=red]没有敌人[/color]")
		return
	# 通过 CC aura 施加恐惧（会自动触发 FEARED flag → MovementGenerator CONFUSED）
	var aura_mgr: Node = EngineAPI.get_system("aura")
	if aura_mgr:
		aura_mgr.call("apply_aura", _gm.hero, enemy,
			{"aura": "CC_FEAR", "base_points": 0},
			{"id": "test_fear_move", "school": "shadow"}, 5.0)
	_spawn_cc_vfx(enemy, "CC_FEAR", 5.0)
	_log("[color=purple]>>> 恐惧 %s 5秒（应随机乱跑）[/color]" % enemy.def_id)

func _test_clear_movement() -> void:
	var enemy: GameEntity = _get_nearest_enemy()
	if enemy == null:
		_log("[color=red]没有敌人[/color]")
		return
	var move_gen: Node = EngineAPI.get_system("movement_gen")
	if move_gen:
		move_gen.call("clear_movement", enemy)
	_log("[color=red]>>> 清除 %s 所有移动行为[/color]" % enemy.def_id)

func _show_move_stack() -> void:
	var enemy: GameEntity = _get_nearest_enemy()
	if enemy == null:
		_log("[color=red]没有敌人[/color]")
		return
	var move_gen: Node = EngineAPI.get_system("movement_gen")
	if move_gen == null:
		return
	var current: Dictionary = move_gen.call("get_current_movement", enemy)
	_log("[color=yellow]--- %s 移动栈 ---[/color]" % enemy.def_id)
	if current.is_empty():
		_log("  （空栈）")
	else:
		var type_names := ["IDLE", "RANDOM", "WAYPOINT", "FOLLOW", "CHASE", "FLEE", "CONFUSED", "POINT", "HOME", "EFFECT"]
		var t: int = current.get("type", 0)
		var name_str: String = type_names[t] if t < type_names.size() else "?"
		_log("  当前: %s | 速度×%.1f | 剩余=%.1f秒" % [
			name_str, current.get("speed_factor", 1.0),
			maxf(current.get("duration", 0) - current.get("elapsed", 0), 0)])

func _on_movement_arrived(data: Dictionary) -> void:
	var entity = data.get("entity")
	var e_name: String = (entity as GameEntity).def_id if entity is GameEntity else "?"
	var type_names := ["IDLE", "RANDOM", "WAYPOINT", "FOLLOW", "CHASE", "FLEE", "CONFUSED", "POINT", "HOME", "EFFECT"]
	var mt: int = data.get("move_type", 0)
	_log("[color=green]到达[/color] %s 完成 %s 移动" % [e_name, type_names[mt] if mt < type_names.size() else "?"])

# =============================================================================
# TAB 6: 掉落/背包
# =============================================================================

func _create_tab_loot(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "掉落"
	tabs.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	_section(vbox, "-- 掉落表 Roll --")
	_hint(vbox, "Roll 结果在英雄附近生成地面掉落物")
	_btn(vbox, "Roll 哥布林掉落", _test_roll_loot.bind("goblin_loot"))
	_btn(vbox, "Roll 骷髅掉落", _test_roll_loot.bind("skeleton_loot"))
	_btn(vbox, "Roll 暗影掉落", _test_roll_loot.bind("shadow_loot"))
	_btn(vbox, "Roll BOSS 掉落", _test_roll_loot.bind("boss_loot"))

	_section(vbox, "-- 指定物品掉落 --")
	_btn(vbox, "掉落白色物品", _test_drop_rarity.bind("common"))
	_btn(vbox, "掉落绿色物品", _test_drop_rarity.bind("uncommon"))
	_btn(vbox, "掉落蓝色物品", _test_drop_rarity.bind("rare"))
	_btn(vbox, "掉落紫色物品", _test_drop_rarity.bind("epic"))
	_btn(vbox, "掉落橙色物品", _test_drop_rarity.bind("legendary"))

	_section(vbox, "-- 背包 --")
	_btn(vbox, "打开/关闭背包", _test_toggle_inventory)
	_btn(vbox, "添加随机物品到背包", _test_add_random_to_inv)
	_btn(vbox, "打印背包内容", _test_print_inventory)
	_btn(vbox, "清空背包", _test_clear_inventory)

	_section(vbox, "-- 拾取设置 --")
	_btn(vbox, "自动拾取: 开", _test_set_autopickup.bind(true))
	_btn(vbox, "自动拾取: 关", _test_set_autopickup.bind(false))
	_btn(vbox, "手动拾取最近掉落", _test_manual_pickup)
	_hint(vbox, "关闭自动拾取后，掉落物留在地面")

func _test_roll_loot(table_id: String) -> void:
	var items: Array = EngineAPI.roll_loot(table_id)
	if items.is_empty():
		_log("[color=gray]%s: 无掉落[/color]" % table_id)
		return
	var hero_pos: Vector3 = _gm.hero.global_position if _gm.hero else Vector3(9.6, 0, 5.4)
	for item in items:
		if not item is Dictionary:
			continue
		if item.get("type") == "item":
			var offset := Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
			EngineAPI.spawn_loot_entity(item, hero_pos + offset)
			var item_sys: Node = EngineAPI.get_system("item")
			var n: String = item_sys.call("get_item_display_name", item) if item_sys else "?"
			var r: String = item.get("def", {}).get("rarity", "common")
			_log("[color=green]掉落: %s (%s)[/color]" % [n, r])
		elif item.get("type") == "currency":
			_log("[color=yellow]+%d %s[/color]" % [item.get("amount", 0), item.get("currency", "gold")])

func _test_drop_rarity(rarity: String) -> void:
	var item_sys: Node = EngineAPI.get_system("item")
	if item_sys == null:
		return
	# 找该稀有度的一个物品
	var all_ids: Array = item_sys.call("get_all_item_ids")
	for item_id in all_ids:
		var def: Dictionary = item_sys.call("get_item_def", item_id)
		if def.get("rarity", "") == rarity:
			var item: Dictionary = item_sys.call("create_item_instance", item_id)
			if not item.is_empty():
				var hero_pos: Vector3 = _gm.hero.global_position if _gm.hero else Vector3(9.6, 0, 5.4)
				var offset := Vector3(randf_range(-0.3, 0.3), 0, randf_range(0.2, 0.5))
				EngineAPI.spawn_loot_entity(item, hero_pos + offset)
				_log("[color=green]掉落 %s: %s[/color]" % [rarity, item_sys.call("get_item_display_name", item)])
				return
	_log("[color=red]没有 %s 稀有度的物品[/color]" % rarity)

func _test_toggle_inventory() -> void:
	if _test_inventory_panel == null:
		# 初始化英雄背包（测试模式可能没走 game_mode 初始化）
		EngineAPI.init_inventory(_gm.hero, 20)
		_test_inventory_panel = InventoryPanel.new()
		_test_inventory_panel.setup(_gm.hero, 5)
		_test_inventory_panel.anchor_left = 0.35
		_test_inventory_panel.anchor_right = 0.65
		_test_inventory_panel.anchor_top = 0.15
		_test_inventory_panel.anchor_bottom = 0.85
		var ui_layer: CanvasLayer = _gm.get_tree().current_scene.get_node_or_null("UI")
		if ui_layer:
			ui_layer.add_child(_test_inventory_panel)
		_log("[color=cyan]背包面板已创建[/color]")
	else:
		_test_inventory_panel.toggle()

func _test_add_random_to_inv() -> void:
	var item_sys: Node = EngineAPI.get_system("item")
	if item_sys == null or not is_instance_valid(_gm.hero):
		return
	EngineAPI.init_inventory(_gm.hero, 20)  # 确保已初始化
	var all_ids: Array = item_sys.call("get_all_item_ids")
	if all_ids.is_empty():
		return
	var random_id: String = all_ids[randi() % all_ids.size()]
	var item: Dictionary = item_sys.call("create_item_instance", random_id)
	var added: bool = EngineAPI.inventory_add(_gm.hero, item)
	if added:
		_log("[color=green]+背包: %s[/color]" % item_sys.call("get_item_display_name", item))
	else:
		_log("[color=red]背包已满！[/color]")

func _test_print_inventory() -> void:
	var items: Array = EngineAPI.inventory_get(_gm.hero)
	var item_sys: Node = EngineAPI.get_system("item")
	_log("[color=yellow]--- 背包（%d件）---[/color]" % items.size())
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var n: String = item_sys.call("get_item_display_name", item) if item_sys else "?"
		var r: String = item.get("def", {}).get("rarity", "common")
		_log("  [%d] %s (%s)" % [i, n, r])
	if items.is_empty():
		_log("  （空）")

func _test_clear_inventory() -> void:
	var items: Array = EngineAPI.inventory_get(_gm.hero)
	for i in range(items.size() - 1, -1, -1):
		EngineAPI.inventory_remove(_gm.hero, i)
	_log("[color=yellow]背包已清空[/color]")

func _test_set_autopickup(enabled: bool) -> void:
	if not is_instance_valid(_gm.hero):
		return
	var pickup: Node = EngineAPI.get_component(_gm.hero, "pickup")
	if pickup:
		pickup.auto_pickup_enabled = enabled
		_log("自动拾取: %s" % ("开" if enabled else "关"))
	else:
		_log("[color=red]英雄没有 pickup 组件[/color]")

func _test_manual_pickup() -> void:
	var pickup: Node = EngineAPI.get_component(_gm.hero, "pickup")
	if pickup and pickup.has_method("interact_pickup"):
		pickup.call("interact_pickup")
		_log("手动拾取触发")
	else:
		_log("[color=red]英雄没有 pickup 组件[/color]")

# =============================================================================
# TAB 7: DR / Boss 脚本
# =============================================================================

func _create_tab_dr_boss(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "DR/Boss"
	tabs.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	_section(vbox, "-- CC 递减测试 --")
	_hint(vbox, "先生成训练假人，连续眩晕观察递减")
	_btn(vbox, "眩晕训练假人 5秒", _test_dr_stun)
	_btn(vbox, "查看训练假人 DR 状态", _test_dr_info)
	_btn(vbox, "重置训练假人 DR", _test_dr_reset)
	_hint(vbox, "预期：第1次5秒→第2次2.5秒→第3次1.25秒→第4次免疫")

	_section(vbox, "-- Boss 副本测试 --")
	_hint(vbox, "创建副本→注册Boss→开始战斗→测试阶段切换")
	_btn(vbox, "创建副本 + 注册骨龙Boss", _test_create_instance)
	_btn(vbox, "开始 Boss 战斗", _test_start_encounter)
	_btn(vbox, "切换到 P2", _test_phase_2)
	_btn(vbox, "触发狂暴", _test_enrage)
	_btn(vbox, "Boss 召唤小怪", _test_boss_summon)
	_btn(vbox, "重置 Boss（重试）", _test_reset_encounter)
	_btn(vbox, "查看副本状态", _test_instance_status)

func _test_dr_stun() -> void:
	var dummy: GameEntity = _find_training_dummy()
	if dummy == null:
		_log("[color=red]请先生成训练假人[/color]")
		return
	var aura_mgr: Node = EngineAPI.get_system("aura")
	if aura_mgr:
		aura_mgr.call("apply_aura", _gm.hero, dummy,
			{"aura": "CC_STUN", "base_points": 0},
			{"id": "test_dr_stun", "school": "physical"}, 5.0)
	_spawn_cc_vfx(dummy, "CC_STUN", 5.0)

func _test_dr_info() -> void:
	var dummy: GameEntity = _find_training_dummy()
	if dummy == null:
		_log("[color=red]请先生成训练假人[/color]")
		return
	var dr_sys: Node = EngineAPI.get_system("dr")
	if dr_sys == null:
		return
	var info: Dictionary = dr_sys.call("get_dr_info", dummy)
	_log("[color=yellow]--- DR 状态 ---[/color]")
	if info.is_empty():
		_log("  (无递减)")
	for group in info:
		var d: Dictionary = info[group]
		_log("  %s: Lv%d (%d%%) 重置%.1fs" % [group, d["level"], int(d["multiplier"] * 100), d["reset_in"]])

func _test_dr_reset() -> void:
	var dummy: GameEntity = _find_training_dummy()
	if dummy == null:
		return
	var dr_sys: Node = EngineAPI.get_system("dr")
	if dr_sys:
		dr_sys.call("reset_dr", dummy)
	_log("[color=green]DR 已重置[/color]")

func _find_training_dummy() -> GameEntity:
	var all: Array = EngineAPI.find_entities_by_tag("enemy")
	for e in all:
		if is_instance_valid(e) and e is GameEntity and (e as GameEntity).def_id == "training_dummy":
			return e as GameEntity
	return null

func _test_create_instance() -> void:
	var enc_sys: Node = EngineAPI.get_system("encounter")
	if enc_sys == null:
		_log("[color=red]EncounterSystem 未注册[/color]")
		return
	_test_instance_id = enc_sys.call("create_instance", {"boss_order": ["bone_dragon"]})
	# 生成骨龙
	var hero_pos: Vector3 = _gm.hero.global_position if _gm.hero else Vector3(9.6, 0, 5.4)
	var boss: Node3D = _gm.spawn("bone_dragon", hero_pos + Vector3(-2.5, 0, 0))
	if boss and boss is GameEntity:
		enc_sys.call("register_boss", _test_instance_id, "bone_dragon", {
			"entities": [boss],
			"phases": 3,
			"enrage_time": 60.0,
			"boundary_center": hero_pos,
			"boundary_radius": 4.0,
			"script": {
				"on_start": func(_enc: Dictionary) -> void: _log("[color=orange]Boss 战斗开始！[/color]"),
				"on_phase_change": func(_enc: Dictionary, old_p: int, new_p: int) -> void: _log("[color=orange]阶段 %d → %d[/color]" % [old_p, new_p]),
				"on_boss_killed": func(enc: Dictionary) -> void: _log("[color=green]Boss 被击杀！耗时 %.1fs[/color]" % enc.get("elapsed", 0)),
				"on_enrage": func(_enc: Dictionary) -> void: _log("[color=red]Boss 狂暴！[/color]"),
				"on_fail": func(_enc: Dictionary) -> void: _log("[color=red]Boss 战斗失败[/color]"),
				"on_reset": func(_enc: Dictionary) -> void: _log("[color=yellow]Boss 重置[/color]"),
			},
		})
		_log("[color=green]副本已创建 ID=%d，骨龙已注册[/color]" % _test_instance_id)

func _test_start_encounter() -> void:
	if _test_instance_id < 0:
		_log("[color=red]请先创建副本[/color]")
		return
	var enc_sys: Node = EngineAPI.get_system("encounter")
	if enc_sys:
		var ok: bool = enc_sys.call("start_encounter", _test_instance_id, "bone_dragon")
		if not ok:
			_log("[color=red]无法开始（状态不对？）[/color]")

func _test_phase_2() -> void:
	if _test_instance_id < 0:
		return
	var enc_sys: Node = EngineAPI.get_system("encounter")
	if enc_sys:
		enc_sys.call("set_phase", _test_instance_id, "bone_dragon", 2)

func _test_enrage() -> void:
	if _test_instance_id < 0:
		return
	# 直接设 elapsed 超过 enrage_time
	var enc_sys: Node = EngineAPI.get_system("encounter")
	if enc_sys:
		var inst: Dictionary = enc_sys.call("get_instance", _test_instance_id)
		var boss: Dictionary = inst.get("bosses", {}).get("bone_dragon", {})
		if not boss.is_empty():
			boss["elapsed"] = boss.get("enrage_time", 60.0)
			_log("[color=yellow]已设置 elapsed = enrage_time，下帧触发狂暴[/color]")

func _test_boss_summon() -> void:
	if _test_instance_id < 0:
		_log("[color=red]请先创建副本[/color]")
		return
	var hero_pos: Vector3 = _gm.hero.global_position if _gm.hero else Vector3(9.6, 0, 5.4)
	var add: Node3D = _gm.spawn("skeleton", hero_pos + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)))
	if add and add is GameEntity:
		var enc_sys: Node = EngineAPI.get_system("encounter")
		if enc_sys:
			enc_sys.call("register_summon", _test_instance_id, "bone_dragon", add)
		_log("[color=orange]Boss 召唤骷髅小怪（Boss 死亡时自动清理）[/color]")

func _test_reset_encounter() -> void:
	if _test_instance_id < 0:
		return
	var enc_sys: Node = EngineAPI.get_system("encounter")
	if enc_sys:
		enc_sys.call("reset_encounter", _test_instance_id, "bone_dragon")

func _test_instance_status() -> void:
	if _test_instance_id < 0:
		_log("[color=red]无副本[/color]")
		return
	var enc_sys: Node = EngineAPI.get_system("encounter")
	if enc_sys == null:
		return
	var states: Dictionary = enc_sys.call("get_all_boss_states", _test_instance_id)
	var state_names := ["NOT_STARTED", "IN_PROGRESS", "FAILED", "DONE"]
	_log("[color=yellow]--- 副本 %d 状态 ---[/color]" % _test_instance_id)
	for bid in states:
		var s: int = states[bid]
		var phase: int = enc_sys.call("get_phase", _test_instance_id, bid)
		var elapsed: float = enc_sys.call("get_elapsed", _test_instance_id, bid)
		_log("  %s: %s P%d %.1fs" % [bid, state_names[s] if s < state_names.size() else "?", phase, elapsed])

func _on_dr_applied(data: Dictionary) -> void:
	var entity = data.get("entity")
	var e_name: String = (entity as GameEntity).def_id if entity is GameEntity else "?"
	var group: String = data.get("group", "?")
	var mult: float = data.get("multiplier", 1.0)
	_log("[color=purple]DR[/color] %s %s → %d%%" % [e_name, group, int(mult * 100)])

func _on_encounter_event(data: Dictionary, event_type: String) -> void:
	var boss_id: String = data.get("boss_id", "?")
	match event_type:
		"started": _log("[color=orange]Encounter[/color] %s 开始" % boss_id)
		"completed": _log("[color=green]Encounter[/color] %s 击杀 %.1fs" % [boss_id, data.get("elapsed", 0)])
		"failed": _log("[color=red]Encounter[/color] %s 失败" % boss_id)
		"phase": _log("[color=orange]Encounter[/color] %s P%d→P%d" % [boss_id, data.get("old_phase", 0), data.get("new_phase", 0)])

# =============================================================================
# TAB 8: 任务 / 成就
# =============================================================================

func _create_tab_quest_achievement(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "任务/成就"
	tabs.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	_section(vbox, "-- 任务系统 --")
	_btn(vbox, "注册测试任务（杀3哥布林）", _test_register_quest)
	_btn(vbox, "接取任务", _test_accept_quest)
	_btn(vbox, "查看任务进度", _test_quest_progress)
	_btn(vbox, "交付任务", _test_turn_in_quest)
	_hint(vbox, "接取后杀哥布林，进度自动推进")

	_section(vbox, "-- 成就系统 --")
	_btn(vbox, "注册测试成就（杀5敌人）", _test_register_achievement)
	_btn(vbox, "查看成就进度", _test_achievement_progress)
	_btn(vbox, "领取成就奖励", _test_claim_achievement)
	_hint(vbox, "杀敌自动推进，OR模式测试用")

	_section(vbox, "-- 寻路 --")
	_btn(vbox, "检查 NavigationServer 状态", _test_nav_status)
	_btn(vbox, "LoS: 英雄→最近敌人", _test_los)

func _test_register_quest() -> void:
	var quest_sys: Node = EngineAPI.get_system("quest")
	if quest_sys == null:
		_log("[color=red]QuestSystem 未注册[/color]")
		return
	quest_sys.call("register_quest", {
		"id": "test_kill_goblins",
		"name_key": "TEST_QUEST",
		"objectives": [
			{"type": "kill", "target": "goblin", "count": 3},
		],
		"rewards": {"gold": 50, "xp": 100},
		"choice_rewards": [
			{"gold": 25},
			{"items": ["rusty_sword"]},
		],
	})
	_test_quest_registered = true
	_log("[color=green]任务已注册: 杀3哥布林 (奖励50金+100经验，可选+25金或铁剑)[/color]")

func _test_accept_quest() -> void:
	if not _test_quest_registered:
		_log("[color=red]请先注册任务[/color]")
		return
	var quest_sys: Node = EngineAPI.get_system("quest")
	if quest_sys:
		var ok: bool = quest_sys.call("accept_quest", "player", "test_kill_goblins")
		_log("接取任务: %s" % ("成功" if ok else "失败（已接/未满足条件）"))

func _test_quest_progress() -> void:
	var quest_sys: Node = EngineAPI.get_system("quest")
	if quest_sys == null:
		return
	var progress: Dictionary = quest_sys.call("get_quest_progress", "player", "test_kill_goblins")
	if progress.is_empty():
		_log("[color=gray]未接取该任务[/color]")
		return
	var state_names := ["UNAVAILABLE", "AVAILABLE", "IN_PROGRESS", "COMPLETE", "TURNED_IN", "FAILED"]
	var s: int = progress.get("state", 0)
	_log("[color=yellow]--- 任务进度 ---[/color]")
	_log("  状态: %s" % (state_names[s] if s < state_names.size() else "?"))
	for obj in progress.get("objectives", []):
		_log("  [%s] %s: %d/%d %s" % [
			obj.get("type", "?"), obj.get("target", ""),
			obj.get("current", 0), obj.get("required", 0),
			"✓" if obj.get("completed", false) else ""])

func _test_turn_in_quest() -> void:
	var quest_sys: Node = EngineAPI.get_system("quest")
	if quest_sys:
		var ok: bool = quest_sys.call("turn_in_quest", "player", "test_kill_goblins", 0)
		_log("交付任务: %s（选择奖励#0）" % ("成功" if ok else "失败（未完成？）"))

func _test_register_achievement() -> void:
	var ach_sys: Node = EngineAPI.get_system("achievement")
	if ach_sys == null:
		return
	ach_sys.call("register_achievement", {
		"id": "test_killer",
		"name_key": "ACH_KILLER",
		"criteria": [
			{"type": "kill_count", "target": "", "count": 5},
		],
		"rewards": {"gold": 200},
		"points": 10,
	})
	ach_sys.call("register_achievement", {
		"id": "test_or_mode",
		"name_key": "ACH_OR_TEST",
		"criteria_logic": "OR",
		"criteria": [
			{"type": "kill_creature", "target": "bone_dragon", "count": 1},
			{"type": "kill_creature", "target": "golem", "count": 1},
		],
		"rewards": {"gold": 100},
		"points": 5,
	})
	_log("[color=green]成就已注册: 杀5敌(AND) + 杀骨龙或石像鬼(OR)[/color]")

func _test_achievement_progress() -> void:
	var ach_sys: Node = EngineAPI.get_system("achievement")
	if ach_sys == null:
		return
	_log("[color=yellow]--- 成就进度 ---[/color]")
	for aid in ["test_killer", "test_or_mode"]:
		var p: Dictionary = ach_sys.call("get_achievement_progress", "player", aid)
		var state_names := ["LOCKED", "COMPLETED", "CLAIMED"]
		var s: int = p.get("state", 0)
		_log("  %s: %s" % [aid, state_names[s] if s < state_names.size() else "?"])
		for c in p.get("criteria", []):
			_log("    [%s] %s: %d/%d" % [c["type"], c["target"], c["current"], c["required"]])

func _test_claim_achievement() -> void:
	var ach_sys: Node = EngineAPI.get_system("achievement")
	if ach_sys == null:
		return
	for aid in ["test_killer", "test_or_mode"]:
		var ok: bool = ach_sys.call("claim_achievement", "player", aid)
		if ok:
			_log("[color=green]领取成就奖励: %s[/color]" % aid)

func _test_nav_status() -> void:
	var path_sys: Node = EngineAPI.get_system("pathfinding")
	if path_sys == null:
		_log("[color=red]PathfindingSystem 未注册[/color]")
		return
	var has_nav: bool = path_sys.call("has_navigation")
	_log("NavigationServer2D: %s" % ("可用" if has_nav else "不可用（回退直线）"))

func _test_los() -> void:
	var path_sys: Node = EngineAPI.get_system("pathfinding")
	if path_sys == null or _gm.hero == null:
		return
	var enemy: GameEntity = _get_nearest_enemy()
	if enemy == null:
		_log("[color=red]没有敌人[/color]")
		return
	var has_los: bool = path_sys.call("has_line_of_sight",
		_gm.hero.global_position, enemy.global_position)
	_log("LoS 英雄→%s: %s" % [enemy.def_id, "有视线" if has_los else "被遮挡"])

func _on_quest_objective(data: Dictionary) -> void:
	var qid: String = data.get("quest_id", "")
	_log("[color=cyan]任务进度[/color] %s: %d/%d" % [qid, data.get("current", 0), data.get("required", 0)])

func _on_quest_event(data: Dictionary, event_type: String) -> void:
	var qid: String = data.get("quest_id", "")
	match event_type:
		"complete": _log("[color=green]任务完成[/color] %s（可交付）" % qid)
		"turned_in": _log("[color=green]任务交付[/color] %s 奖励已发放" % qid)

func _on_achievement_event(data: Dictionary, event_type: String) -> void:
	var aid: String = data.get("achievement_id", "")
	if event_type == "completed":
		_log("[color=green]成就达成[/color] %s (+%d点)" % [aid, data.get("points", 0)])

# =============================================================================
# TAB 9: 网络 / 录制 (Phase 4)
# =============================================================================

func _create_tab_network_replay(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "网络/录制"
	tabs.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	_section(vbox, "-- 聊天系统 --")
	_btn(vbox, "发送全局消息", _test_chat_global)
	_btn(vbox, "发送5条测试限速", _test_chat_rate_limit)
	_btn(vbox, "禁言 player 10秒", _test_chat_mute)
	_btn(vbox, "查看聊天历史", _test_chat_history)

	_section(vbox, "-- 录制/回放 --")
	_btn(vbox, "开始录制", _test_replay_start)
	_btn(vbox, "停止录制", _test_replay_stop)
	_btn(vbox, "开始回放", _test_replay_play)
	_btn(vbox, "暂停/继续", _test_replay_toggle_pause)
	_btn(vbox, "2倍速/正常速", _test_replay_speed)
	_btn(vbox, "查看录制信息", _test_replay_info)

	_section(vbox, "-- 网络系统（信息）--")
	_btn(vbox, "查看网络状态", _test_net_status)
	_btn(vbox, "查看房间系统状态", _test_room_status)
	_hint(vbox, "网络连接需实际多客户端测试")

func _test_chat_global() -> void:
	var chat_sys: Node = EngineAPI.get_system("chat")
	if chat_sys == null:
		_log("[color=red]ChatSystem 未注册[/color]")
		return
	chat_sys.call("join_channel", "player", "global")
	var ok: bool = chat_sys.call("send_message", "player", "global", "Hello from Test Arena!")
	_log("发送全局消息: %s" % ("成功" if ok else "失败"))

func _test_chat_rate_limit() -> void:
	var chat_sys: Node = EngineAPI.get_system("chat")
	if chat_sys == null:
		return
	chat_sys.call("join_channel", "player", "global")
	var sent := 0
	var blocked := 0
	for i in range(12):
		var ok: bool = chat_sys.call("send_message", "player", "global", "Spam test %d" % i)
		if ok: sent += 1
		else: blocked += 1
	_log("限速测试: %d条发送, %d条被拦截" % [sent, blocked])

func _test_chat_mute() -> void:
	var chat_sys: Node = EngineAPI.get_system("chat")
	if chat_sys == null:
		return
	chat_sys.call("mute_player", "player", 10.0, "测试禁言")
	_log("[color=red]player 已被禁言 10秒[/color]")
	# 尝试发消息
	var ok: bool = chat_sys.call("send_message", "player", "global", "I'm muted?")
	_log("禁言中发消息: %s" % ("成功(BUG!)" if ok else "被拒绝(正确)"))

func _test_chat_history() -> void:
	var chat_sys: Node = EngineAPI.get_system("chat")
	if chat_sys == null:
		return
	var history: Array = chat_sys.call("get_history", "global", 5)
	_log("[color=yellow]--- 最近5条消息 ---[/color]")
	for msg in history:
		_log("  [%s] %s" % [msg.get("sender_id", "?"), msg.get("text", "")])
	if history.is_empty():
		_log("  (无消息)")

func _test_replay_start() -> void:
	var replay_sys: Node = EngineAPI.get_system("replay")
	if replay_sys == null:
		_log("[color=red]ReplaySystem 未注册[/color]")
		return
	replay_sys.call("start_recording", {"map": "test_arena"})
	_log("[color=green]录制开始[/color]（杀怪/施法/受伤都会被记录）")

func _test_replay_stop() -> void:
	var replay_sys: Node = EngineAPI.get_system("replay")
	if replay_sys == null:
		return
	var data: Dictionary = replay_sys.call("stop_recording")
	var meta: Dictionary = data.get("metadata", {})
	_log("[color=yellow]录制停止[/color] %.1fs %d事件 %d关键帧 种子=%d" % [
		meta.get("duration", 0), meta.get("event_count", 0),
		data.get("keyframes", []).size(), data.get("rng_seed", 0)])

func _test_replay_play() -> void:
	var replay_sys: Node = EngineAPI.get_system("replay")
	if replay_sys == null:
		return
	replay_sys.call("start_playback", 1.0)
	_log("[color=cyan]回放开始（1x速度）[/color]")

func _test_replay_toggle_pause() -> void:
	var replay_sys: Node = EngineAPI.get_system("replay")
	if replay_sys == null:
		return
	var s: int = replay_sys.state
	if s == 2:  # PLAYING
		replay_sys.call("pause_playback")
		_log("回放暂停")
	elif s == 3:  # PAUSED
		replay_sys.call("resume_playback")
		_log("回放继续")

func _test_replay_speed() -> void:
	var replay_sys: Node = EngineAPI.get_system("replay")
	if replay_sys == null:
		return
	var current: float = replay_sys._playback_speed
	var new_speed: float = 2.0 if current <= 1.0 else 1.0
	replay_sys.call("set_playback_speed", new_speed)
	_log("回放速度: %.0fx" % new_speed)

func _test_replay_info() -> void:
	var replay_sys: Node = EngineAPI.get_system("replay")
	if replay_sys == null:
		return
	var progress: Dictionary = replay_sys.call("get_playback_progress")
	var state_names := ["IDLE", "RECORDING", "PLAYING", "PAUSED"]
	var s: int = progress.get("state", 0)
	_log("[color=yellow]--- 录制/回放 ---[/color]")
	_log("  状态: %s" % (state_names[s] if s < state_names.size() else "?"))
	_log("  时间: %.1f/%.1f (%.0f%%)" % [
		progress.get("time", 0), progress.get("total_time", 0),
		progress.get("progress", 0) * 100])
	_log("  事件: %d/%d 速度: %.1fx" % [
		progress.get("event_index", 0), progress.get("total_events", 0),
		progress.get("speed", 1)])

func _test_net_status() -> void:
	var net_sys: Node = EngineAPI.get_system("network")
	if net_sys == null:
		_log("[color=red]NetworkSystem 未注册[/color]")
		return
	var role_names := ["NONE", "SERVER", "CLIENT"]
	var r: int = net_sys.role
	_log("[color=yellow]--- 网络状态 ---[/color]")
	_log("  角色: %s | PeerID: %d" % [role_names[r] if r < role_names.size() else "?", net_sys.local_peer_id])
	_log("  连接数: %d | Tick率: %dHz" % [net_sys.connected_peers.size(), net_sys.tick_rate])
	_log("  兴趣半径: %.0f | 插值延迟: %.2fs" % [net_sys.relevance_radius, net_sys.interpolation_delay])

func _test_room_status() -> void:
	var room_sys: Node = EngineAPI.get_system("room")
	if room_sys == null:
		_log("[color=red]RoomSystem 未注册[/color]")
		return
	var rooms: Array = room_sys.call("get_room_list")
	_log("[color=yellow]--- 房间列表 ---[/color]")
	if rooms.is_empty():
		_log("  (无房间)")
	for r in rooms:
		_log("  %s [%s] %d/%d" % [r.get("name", "?"), r.get("game_mode", "?"),
			r.get("players", 0), r.get("max_players", 0)])

# === 回放事件可视化 ===

func _on_replay_event(data: Dictionary) -> void:
	## 回放事件到来时，在日志中重现（可视化回放）
	var event_name: String = data.get("original_event", "")
	var event_data: Dictionary = data.get("data", {})
	var time: float = data.get("time", 0.0)
	# 格式化事件为可读文本
	var text := "[color=gray][%.1fs][/color] " % time
	match event_name:
		"entity_damaged":
			var src = event_data.get("source", {})
			var tgt = event_data.get("entity", {})
			var src_name: String = src.get("def_id", "?") if src is Dictionary else "?"
			var tgt_name: String = tgt.get("def_id", "?") if tgt is Dictionary else "?"
			text += "%s→%s [b]%.0f伤害[/b]" % [src_name, tgt_name, event_data.get("amount", 0)]
		"entity_killed":
			var tgt = event_data.get("entity", {})
			var killer = event_data.get("killer", {})
			var tgt_name: String = tgt.get("def_id", "?") if tgt is Dictionary else "?"
			var k_name: String = killer.get("def_id", "?") if killer is Dictionary else "?"
			text += "[color=red]击杀[/color] %s 被 %s 击杀" % [tgt_name, k_name]
		"spell_cast":
			text += "施放 %s" % event_data.get("spell_id", "?")
		"aura_applied":
			text += "Aura %s → %s" % [event_data.get("aura_type", "?"), event_data.get("aura_id", "?")]
		"entity_spawned":
			var e = event_data.get("entity", {})
			var def_id: String = e.get("def_id", "?") if e is Dictionary else "?"
			text += "[color=green]+[/color] %s" % def_id
		_:
			text += "%s" % event_name
	_log(text)

func _on_replay_finished(_data: Dictionary) -> void:
	_log("[color=yellow]>>> 回放结束 <<<[/color]")

# =============================================================================
# TAB 10: 等级 / 对话 / 存档 / 镜头 / 音频
# =============================================================================

func _create_tab_core_systems(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "核心"
	tabs.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	_section(vbox, "-- 等级/经验 --")
	_btn(vbox, "初始化英雄等级(Lv1)", _test_init_level)
	_btn(vbox, "给英雄 +100 XP", _test_add_xp.bind(100))
	_btn(vbox, "给英雄 +500 XP", _test_add_xp.bind(500))
	_btn(vbox, "直接设为 Lv10", _test_set_level.bind(10))
	_btn(vbox, "查看等级信息", _test_level_info)
	_hint(vbox, "杀哥布林自动获得XP（meta xp_reward）")

	_section(vbox, "-- 对话系统 --")
	_btn(vbox, "注册测试对话", _test_register_dialogue)
	_btn(vbox, "开始对话", _test_start_dialogue)
	_btn(vbox, "选择选项 1", _test_select_option.bind(0))
	_btn(vbox, "选择选项 2", _test_select_option.bind(1))
	_btn(vbox, "下一页", _test_next_page)
	_btn(vbox, "结束对话", _test_end_dialogue)

	_section(vbox, "-- 存档 --")
	_btn(vbox, "保存到槽位 0", _test_save.bind(0))
	_btn(vbox, "加载槽位 0", _test_load.bind(0))
	_btn(vbox, "查看所有槽位", _test_slot_info)

	_section(vbox, "-- 镜头 --")
	_btn(vbox, "跟随英雄", _test_cam_follow)
	_btn(vbox, "镜头震动", _test_cam_shake)
	_btn(vbox, "放大 (zoom in)", _test_cam_zoom_in)
	_btn(vbox, "缩小 (zoom out)", _test_cam_zoom_out)
	_btn(vbox, "移动到屏幕中心", _test_cam_move_center)

	_section(vbox, "-- 音频（需音频文件）--")
	_btn(vbox, "查看音频系统状态", _test_audio_info)
	_hint(vbox, "实际播放需要 res:// 下有音频资源")

# --- 等级 ---

func _test_init_level() -> void:
	if _gm.hero == null or not is_instance_valid(_gm.hero):
		return
	var level_sys: Node = EngineAPI.get_system("level")
	if level_sys == null:
		_log("[color=red]LevelSystem 未注册[/color]")
		return
	level_sys.call("init_level", _gm.hero, {
		"level": 1, "xp": 0, "curve": "linear",
		"skill_points_per_level": 2,
	})
	_log("[color=green]英雄等级初始化: Lv1 XP=0[/color]")

func _test_add_xp(amount: int) -> void:
	if _gm.hero == null or not is_instance_valid(_gm.hero):
		return
	EngineAPI.add_xp(_gm.hero, amount)

func _test_set_level(lv: int) -> void:
	if _gm.hero == null or not is_instance_valid(_gm.hero):
		return
	var level_sys: Node = EngineAPI.get_system("level")
	if level_sys:
		level_sys.call("set_level", _gm.hero, lv)

func _test_level_info() -> void:
	if _gm.hero == null or not is_instance_valid(_gm.hero):
		return
	var level_sys: Node = EngineAPI.get_system("level")
	if level_sys == null:
		_log("[color=red]LevelSystem 未注册[/color]")
		return
	var info: Dictionary = level_sys.call("get_level_data", _gm.hero)
	if info.is_empty():
		_log("[color=gray]未初始化等级（先点初始化）[/color]")
		return
	_log("[color=yellow]--- 等级信息 ---[/color]")
	_log("  Lv%d | XP: %d/%d (%.0f%%)" % [
		info.get("level", 1), info.get("xp", 0),
		info.get("xp_to_next", 0),
		float(info.get("xp", 0)) / maxf(float(info.get("xp_to_next", 1)), 1.0) * 100])
	_log("  技能点: %d | 最大等级: %d" % [info.get("skill_points", 0), info.get("max_level", 50)])

func _on_level_up(data: Dictionary) -> void:
	var entity = data.get("entity")
	var e_name: String = (entity as GameEntity).def_id if entity is GameEntity else "?"
	_log("[color=green]升级！[/color] %s → Lv%d (技能点: %d)" % [
		e_name, data.get("new_level", 0), data.get("skill_points", 0)])

func _on_xp_gained(data: Dictionary) -> void:
	var amount: int = data.get("amount", 0)
	_log("[color=cyan]+%d XP[/color] (总计: %d)" % [amount, data.get("total_xp", 0)])

# --- 对话 ---

func _test_register_dialogue() -> void:
	var dlg_sys: Node = EngineAPI.get_system("dialogue")
	if dlg_sys == null:
		_log("[color=red]DialogueSystem 未注册[/color]")
		return
	dlg_sys.call("register_dialogue", {
		"id": "test_npc_talk",
		"nodes": {
			"start": {
				"speaker_key": "NPC_BLACKSMITH",
				"text_keys": ["DIALOG_PAGE_1", "DIALOG_PAGE_2"],
				"options": [
					{"text_key": "OPT_SHOP", "action": "close"},
					{"text_key": "OPT_QUEST", "next": "quest_info"},
					{"text_key": "OPT_BYE", "action": "close"},
				],
			},
			"quest_info": {
				"speaker_key": "NPC_BLACKSMITH",
				"text_key": "DIALOG_QUEST_DESC",
				"options": [
					{"text_key": "OPT_ACCEPT", "action": "accept_quest", "action_data": {"quest_id": "test_kill_goblins"}},
					{"text_key": "OPT_DECLINE", "action": "close"},
				],
			},
		},
	})
	_log("[color=green]对话已注册: test_npc_talk（2页+3选项+子节点）[/color]")

func _test_start_dialogue() -> void:
	var dlg_sys: Node = EngineAPI.get_system("dialogue")
	if dlg_sys == null:
		return
	var ok: bool = dlg_sys.call("start_dialogue", "test_npc_talk", _gm.hero)
	if not ok:
		_log("[color=red]对话未注册（先点注册）[/color]")

func _test_select_option(idx: int) -> void:
	var dlg_sys: Node = EngineAPI.get_system("dialogue")
	if dlg_sys:
		dlg_sys.call("select_option", idx)

func _test_next_page() -> void:
	var dlg_sys: Node = EngineAPI.get_system("dialogue")
	if dlg_sys:
		var has_next: bool = dlg_sys.call("next_page")
		if not has_next:
			_log("[color=gray]已是最后一页[/color]")

func _test_end_dialogue() -> void:
	var dlg_sys: Node = EngineAPI.get_system("dialogue")
	if dlg_sys:
		dlg_sys.call("end_dialogue")

func _on_dialogue_node(data: Dictionary) -> void:
	var node_id: String = data.get("node_id", "")
	var text_key: String = data.get("text_key", "")
	var pages: int = data.get("total_pages", 1)
	var options: Array = data.get("options", [])
	_log("[color=cyan]对话[/color] 节点=%s 文本=%s 页数=%d" % [node_id, text_key, pages])
	for i in range(options.size()):
		_log("  [%d] %s" % [i, options[i].get("text_key", "?")])

func _on_dialogue_ended(_data: Dictionary) -> void:
	_log("[color=gray]对话结束[/color]")

# --- 存档 ---

func _test_save(slot: int) -> void:
	var ok: bool = SaveSystem.save_game_snapshot(slot)
	_log("保存到槽位 %d: %s" % [slot, "成功" if ok else "失败"])

func _test_load(slot: int) -> void:
	var data: Dictionary = SaveSystem.load_game_snapshot(slot)
	if data.is_empty():
		_log("[color=red]槽位 %d 无存档[/color]" % slot)
		return
	_log("[color=green]加载槽位 %d[/color]" % slot)
	_log("  时间: %s | 游戏时间: %.0fs" % [data.get("save_time", "?"), data.get("play_time", 0)])
	_log("  等级: %s | 版本: %d" % [str(data.get("level_data", {}).get("level", "?")), data.get("save_version", 0)])
	var inv_count: int = data.get("inventory", []).size()
	var quest_count: int = data.get("quest_progress", {}).size()
	_log("  背包: %d件 | 任务: %d | 声望: %d阵营" % [inv_count, quest_count, data.get("reputations", {}).size()])
	# 可选：应用快照
	# SaveSystem.apply_snapshot(data)

func _test_slot_info() -> void:
	var slots: Array = SaveSystem.get_all_slot_info()
	_log("[color=yellow]--- 存档槽位 ---[/color]")
	for s in slots:
		if s.get("exists", false):
			_log("  [%d] Lv%s %s %.0fs" % [s["slot"], str(s.get("level", "?")), s.get("save_time", ""), s.get("play_time", 0)])
		else:
			_log("  [%d] (空)" % s["slot"])

# --- 镜头 ---

func _ensure_camera() -> Node:
	## 确保 CameraSystem 存在于场景中
	var cam: Node = EngineAPI.get_system("camera")
	if cam != null:
		return cam
	# 动态创建 CameraSystem（Camera3D 子类，必须在场景树中）
	var camera_script: GDScript = load("res://src/systems/camera_system.gd")
	if camera_script == null:
		_log("[color=red]camera_system.gd 加载失败[/color]")
		return null
	var new_cam: Camera3D = Camera3D.new()
	new_cam.set_script(camera_script)
	var scene_root: Node = _gm.get_tree().current_scene
	if scene_root:
		scene_root.add_child(new_cam)
		new_cam.make_current()
		_log("[color=green]CameraSystem 已创建并激活[/color]")
	return EngineAPI.get_system("camera")

func _test_cam_follow() -> void:
	var cam: Node = _ensure_camera()
	if cam == null:
		return
	if _gm.hero and is_instance_valid(_gm.hero):
		cam.call("follow", _gm.hero, 5.0)
		_log("[color=green]镜头跟随英雄[/color]")

func _test_cam_shake() -> void:
	var cam: Node = _ensure_camera()
	if cam:
		cam.call("shake", 0.6, 1.5)
		_log("镜头震动 (trauma=0.6)")

func _test_cam_zoom_in() -> void:
	var cam: Node = _ensure_camera()
	if cam:
		cam.call("zoom_in", 0.2)
		_log("镜头放大")

func _test_cam_zoom_out() -> void:
	var cam: Node = _ensure_camera()
	if cam:
		cam.call("zoom_out", 0.2)
		_log("镜头缩小")

func _test_cam_move_center() -> void:
	var cam: Node = _ensure_camera()
	if cam:
		cam.call("move_to", Vector3(9.6, 0, 5.4), 0.8)
		_log("镜头过渡到屏幕中心")

# --- 音频 ---

func _test_audio_info() -> void:
	var audio: Node = EngineAPI.get_system("audio")
	if audio == null:
		_log("[color=red]AudioManager 未注册[/color]")
		return
	_log("[color=yellow]--- 音频系统 ---[/color]")
	_log("  总线: %d 个" % AudioServer.bus_count)
	for i in range(AudioServer.bus_count):
		_log("    [%d] %s (%.0fdB)" % [i, AudioServer.get_bus_name(i), AudioServer.get_bus_volume_db(i)])
	_log("  BGM: %s" % (audio.get_current_bgm() if audio.get_current_bgm() != "" else "无"))
	_log("  音量: Master=%.0f%% BGM=%.0f%% SFX=%.0f%% Amb=%.0f%%" % [
		audio.get_volume("master") * 100, audio.get_volume("bgm") * 100,
		audio.get_volume("sfx") * 100, audio.get_volume("ambience") * 100])

# =============================================================================
# 原有功能实现（Phase 1 保留）
# =============================================================================

func _log(text: String) -> void:
	if _log_label:
		_log_label.append_text(text + "\n")

func _spawn_enemies(enemy_id: String, count: int) -> void:
	for i in range(count):
		var pos := Vector3(randf_range(3.0, 8.0), 0, randf_range(2.0, 6.0))
		var e: Node3D = _gm.spawn(enemy_id, pos)
		if e and e is GameEntity:
			_log("[color=red]+ 生成[/color] %s | 阵营=%s | 位置=(%d,%d)" % [
				enemy_id, (e as GameEntity).faction, int(pos.x), int(pos.z)])

func _spawn_training_dummy() -> void:
	var hero_pos: Vector3 = _gm.hero.global_position if _gm.hero else Vector3(9.6, 0, 5.4)
	var pos := hero_pos + Vector3(-1.5, 0, 0)
	var e: Node3D = _gm.spawn("training_dummy", pos)
	if e and e is GameEntity:
		_log("[color=#aa8844]+ 训练假人[/color] 血量=99999 护甲=10 | 不移动 不攻击")

func _kill_all_enemies() -> void:
	var enemies: Array = EngineAPI.find_entities_by_tag("enemy")
	var count := 0
	for e in enemies:
		if is_instance_valid(e):
			EngineAPI.destroy_entity(e)
			count += 1
	_log("[color=red]x 清除了 %d 个敌人[/color]" % count)

func _apply_cc_to_hero(cc_type: String, duration: float) -> void:
	if _gm.hero == null or not is_instance_valid(_gm.hero):
		_log("[color=red]错误：英雄不存在[/color]")
		return
	_apply_cc_to_entity(_gm.hero, cc_type, duration)
	_log("[color=cyan]>>> 对英雄施加【%s】%.0f秒[/color]" % [_cc_name(cc_type), duration])
	_log_hero_state()

func _apply_cc_to_enemies(cc_type: String, duration: float) -> void:
	var enemies: Array = EngineAPI.find_entities_by_tag("enemy")
	var count := 0
	for e in enemies:
		if is_instance_valid(e):
			_apply_cc_to_entity(e, cc_type, duration)
			count += 1
	_log("[color=cyan]>>> 对 %d 个敌人施加【%s】%.0f秒[/color]" % [count, _cc_name(cc_type), duration])

func _apply_cc_to_entity(target: Node3D, cc_type: String, duration: float) -> void:
	var aura_mgr: Node = EngineAPI.get_system("aura")
	if aura_mgr:
		aura_mgr.call("apply_aura", _gm.hero, target,
			{"aura": cc_type, "base_points": 0},
			{"id": "test_%s" % cc_type.to_lower(), "school": "physical"}, duration)
	_spawn_cc_vfx(target, cc_type, duration)

func _set_hero_flag(flag: int, enabled: bool) -> void:
	if _gm.hero == null or not is_instance_valid(_gm.hero) or not (_gm.hero is GameEntity):
		return
	var ge: GameEntity = _gm.hero as GameEntity
	var flag_name: String = UnitFlags.flag_to_string(flag)
	if enabled:
		ge.set_unit_flag(flag)
		_log("[color=green]>>> 英雄 开启 %s[/color]" % flag_name)
	else:
		ge.clear_unit_flag(flag)
		_log("[color=green]>>> 英雄 关闭 %s[/color]" % flag_name)

func _show_threat_list() -> void:
	var enemies: Array = EngineAPI.find_entities_by_tag("enemy")
	if enemies.is_empty():
		_log("[color=red]场上没有敌人[/color]")
		return
	var nearest: GameEntity = _get_nearest_enemy()
	if nearest == null:
		return
	var threat_mgr: Node = EngineAPI.get_system("threat")
	if threat_mgr == null:
		return
	var state_name: String = ["IDLE", "COMBAT", "EVADING", "HOME"][nearest.meta.get("ai_state", 0)]
	_log("[color=yellow]--- %s 仇恨列表 (AI=%s) ---[/color]" % [nearest.def_id, state_name])
	var list: Array = threat_mgr.call("get_threat_list_debug", nearest)
	if list.is_empty():
		_log("  （空）")
	for entry in list:
		_log("  %s : %.0f" % [entry["name"], entry["threat"]])

func _taunt_nearest() -> void:
	if _gm.hero == null or not is_instance_valid(_gm.hero):
		return
	var nearest: GameEntity = _get_nearest_enemy()
	if nearest == null:
		_log("[color=red]没有敌人[/color]")
		return
	EngineAPI.apply_taunt(nearest, _gm.hero, 5.0)
	_log("[color=orange]>>> 嘲讽 %s 5秒[/color]" % nearest.def_id)

func _test_evade() -> void:
	var enemies: Array = EngineAPI.find_entities_by_tag("enemy")
	if enemies.is_empty():
		_log("[color=red]没有敌人[/color]")
		return
	var target: GameEntity = enemies[0] as GameEntity
	if target.meta.get("ai_state", 0) != 1:
		EngineAPI.add_threat(target, _gm.hero, 1.0)
	var home: Vector3 = target.meta.get("home_position", target.global_position)
	target.global_position = home + Vector3(8.0, 0, 0)
	_log("[color=orange]>>> 传送 %s 远离8.0m → 触发脱战[/color]" % target.def_id)

func _add_absorb_shield() -> void:
	if _gm.hero == null or not is_instance_valid(_gm.hero):
		return
	var aura_mgr: Node = EngineAPI.get_system("aura")
	if aura_mgr:
		aura_mgr.call("apply_aura", _gm.hero, _gm.hero,
			{"aura": "SCHOOL_ABSORB", "base_points": 100},
			{"id": "test_shield", "school": "physical"}, 30.0)
	_log("[color=cyan]>>> 英雄 +100 吸收盾（30秒）[/color]")

func _deal_test_damage() -> void:
	var enemies: Array = EngineAPI.find_entities_by_tag("enemy")
	if enemies.is_empty():
		_log("[color=red]没有敌人[/color]")
		return
	var target: GameEntity = enemies[0] as GameEntity
	var result: Dictionary = DamagePipeline.deal_damage({
		"attacker": _gm.hero, "target": target,
		"base_amount": 999.0, "school": 0, "ability": "test_nuke",
	})
	_log("[color=red]>>> 对 %s 造成 999 伤害[/color] | 有效=%.0f 击杀=%s" % [
		target.def_id, result.get("effective_damage", 0), str(result.get("killed", false))])

func _test_cast_time() -> void:
	if _gm.hero == null:
		return
	var spell_sys: Node = EngineAPI.get_system("spell")
	if spell_sys == null:
		return
	var success: bool = spell_sys.call("cast", "chain_lightning_passive", _gm.hero, _gm.hero, {
		"cast_time": 2.0, "interruptible": true
	})
	_log("[color=cyan]>>> 读条 2秒 %s[/color]" % ("成功" if success else "失败"))

func _test_channel() -> void:
	if _gm.hero == null:
		return
	var spell_sys: Node = EngineAPI.get_system("spell")
	if spell_sys == null:
		return
	var success: bool = spell_sys.call("cast", "chain_lightning_passive", _gm.hero, _gm.hero, {
		"channel_time": 3.0, "channel_period": 1.0
	})
	_log("[color=cyan]>>> 引导 3秒 %s[/color]" % ("成功" if success else "失败"))

func _spawn_friendly() -> void:
	var pos := Vector3(randf_range(5.0, 7.0), 0, randf_range(4.0, 6.0))
	var e: Node3D = _gm.spawn("shadow", pos, {
		"faction": "player",
		"tags": ["friendly", "mobile", "ground", "summon"],
		"lifespan": 10.0,
		"components": {
			"ai_move_to": {"target_tag": "enemy", "attack_range": 0.6},
			"combat": {"damage": 20, "attack_speed": 1.5, "range": 0.6,
				"attack_type": "single", "target_filter_tag": "enemy", "targeting": "closest"},
		},
	})
	if e and e is GameEntity:
		_log("[color=green]+ 友方暗影兽[/color] | 阵营=%s | 10秒消失" % (e as GameEntity).faction)

func _spawn_neutral() -> void:
	var pos := Vector3(randf_range(5.0, 7.0), 0, randf_range(3.0, 5.0))
	var e: Node3D = _gm.spawn("golem", pos, {
		"faction": "neutral",
		"tags": ["neutral", "mobile", "ground"],
	})
	if e and e is GameEntity:
		_log("[color=gray]+ 中立石像鬼[/color] | 阵营=%s" % (e as GameEntity).faction)

func _log_query(query_type: String) -> void:
	match query_type:
		"hostiles":
			if not _gm.hero or not is_instance_valid(_gm.hero):
				return
			var targets: Array = EngineAPI.find_hostiles_in_area(_gm.hero, _gm.hero.global_position, 99.99)
			_log("[color=yellow]--- 敌对目标（%d）---[/color]" % targets.size())
			for t in targets:
				if t is GameEntity:
					_log("  %s | %s" % [(t as GameEntity).def_id, (t as GameEntity).faction])
		"allies":
			if not _gm.hero or not is_instance_valid(_gm.hero):
				return
			var targets: Array = EngineAPI.find_allies_in_area(_gm.hero, _gm.hero.global_position, 99.99)
			_log("[color=green]--- 友方（%d）---[/color]" % targets.size())
			for t in targets:
				if t is GameEntity:
					_log("  %s | %s" % [(t as GameEntity).def_id, (t as GameEntity).faction])
		"enemy_hostiles":
			var enemies: Array = EngineAPI.find_entities_by_tag("enemy")
			if enemies.is_empty():
				_log("[color=red]没有敌人[/color]")
				return
			var first: GameEntity = enemies[0] as GameEntity
			var targets: Array = EngineAPI.find_hostiles_in_area(first, first.global_position, 99.99)
			_log("[color=red]--- %s 的敌对目标（%d）---[/color]" % [first.def_id, targets.size()])
			for t in targets:
				if t is GameEntity:
					_log("  %s | %s" % [(t as GameEntity).def_id, (t as GameEntity).faction])

# === 事件监听 ===

func _on_flags_changed(data: Dictionary) -> void:
	var entity = data.get("entity")
	if entity is GameEntity:
		var ge: GameEntity = entity as GameEntity
		_log("[color=purple]标志[/color] %s: %s → %s" % [ge.def_id,
			UnitFlags.flag_to_string(data.get("old_flags", 0)),
			UnitFlags.flag_to_string(data.get("new_flags", 0))])

func _on_entity_damaged(data: Dictionary) -> void:
	var entity = data.get("entity")
	var source = data.get("source")
	var amount: float = data.get("amount", 0)
	var ability: String = str(data.get("ability", ""))
	var e_name: String = (entity as GameEntity).def_id if entity is GameEntity else "?"
	var s_name: String = (source as GameEntity).def_id if source is GameEntity else "?"
	_log("%s→%s [b]%.0f[/b]（%s）" % [s_name, e_name, amount, ability])

func _on_ai_combat(data: Dictionary) -> void:
	var entity = data.get("entity")
	var aggro = data.get("aggro")
	if entity is GameEntity:
		var aggro_name: String = (aggro as GameEntity).def_id if aggro is GameEntity else "?"
		_log("[color=orange]AI战斗[/color] %s → %s" % [(entity as GameEntity).def_id, aggro_name])

func _on_ai_evade(data: Dictionary) -> void:
	var entity = data.get("entity")
	if entity is GameEntity:
		_log("[color=blue]AI脱战[/color] %s" % (entity as GameEntity).def_id)

func _on_ai_home(data: Dictionary) -> void:
	var entity = data.get("entity")
	if entity is GameEntity:
		_log("[color=green]AI归位[/color] %s" % (entity as GameEntity).def_id)

func _on_entity_killed(data: Dictionary) -> void:
	var entity = data.get("entity")
	var killer = data.get("killer")
	var e_name: String = (entity as GameEntity).def_id if entity is GameEntity else "?"
	var k_name: String = (killer as GameEntity).def_id if killer is GameEntity else "?"
	_log("[color=red]击杀[/color] %s 被 %s 击杀" % [e_name, k_name])

func _on_spell_interrupted(data: Dictionary) -> void:
	var caster = data.get("caster")
	var spell_id: String = str(data.get("spell_id", ""))
	var name_str: String = (caster as GameEntity).def_id if caster is GameEntity else "?"
	_log("[color=orange]打断[/color] %s 的 %s" % [name_str, spell_id])

func _log_hero_state() -> void:
	if _gm.hero and _gm.hero is GameEntity:
		var ge: GameEntity = _gm.hero as GameEntity
		_log("  移动=%s 攻击=%s 施法=%s" % [
			str(TargetUtil.can_move(ge)), str(TargetUtil.can_attack(ge)), str(TargetUtil.can_cast(ge))])

# === CC 视觉特效 ===

func _spawn_cc_vfx(entity: Node3D, cc_type: String, duration: float) -> void:
	if not is_instance_valid(entity):
		return
	var vfx := Node3D.new()
	vfx.name = "CC_VFX_%s" % cc_type
	var old: Node = entity.get_node_or_null(NodePath(vfx.name))
	if old:
		old.queue_free()
	entity.add_child(vfx)
	match cc_type:
		"CC_STUN": _create_stun_stars(vfx)
		"CC_ROOT": _create_root_circle(vfx)
		"CC_SILENCE": _create_silence_seal(vfx)
		"CC_FEAR": _create_fear_smoke(vfx)
	# 延迟后移除
	_gm.get_tree().create_timer(duration).timeout.connect(func() -> void:
		if is_instance_valid(vfx):
			vfx.queue_free()
	)

func _create_stun_stars(parent: Node3D) -> void:
	var orbit := Node3D.new()
	orbit.position = Vector3(0, 2.0, 0)
	parent.add_child(orbit)
	for i in range(3):
		var star := Label3D.new()
		star.text = "*"
		star.font_size = 48
		star.modulate = Color(1, 0.9, 0.2)
		star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		var angle: float = TAU / 3.0 * i
		star.position = Vector3(cos(angle) * 0.5, 0, sin(angle) * 0.5)
		orbit.add_child(star)
	var tw := orbit.create_tween().set_loops()
	tw.tween_property(orbit, "rotation:y", TAU, 1.0).as_relative()

func _create_root_circle(parent: Node3D) -> void:
	var ring := MeshInstance3D.new()
	ring.position = Vector3(0, 0.05, 0)
	parent.add_child(ring)
	var col := Color(0.3, 0.7, 1.0, 0.6)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(col.r, col.g, col.b)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.set_surface_override_material(0, mat)
	ring.rotation_degrees.x = 90
	var tw := ring.create_tween().set_loops()
	tw.tween_property(ring, "scale", Vector3(1.15, 1.15, 1.15), 0.5).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(ring, "scale", Vector3(1.0, 1.0, 1.0), 0.5).set_ease(Tween.EASE_IN_OUT)

func _create_silence_seal(parent: Node3D) -> void:
	var seal := Label3D.new()
	seal.text = "X"
	seal.font_size = 64
	seal.modulate = Color(0.7, 0.2, 0.9, 0.8)
	seal.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	seal.position = Vector3(0, 2.0, 0)
	parent.add_child(seal)
	var tw := seal.create_tween().set_loops()
	tw.tween_property(seal, "modulate:a", 0.4, 0.4)
	tw.tween_property(seal, "modulate:a", 1.0, 0.4)

func _create_fear_smoke(parent: Node3D) -> void:
	var fear := Label3D.new()
	fear.text = "!!"
	fear.font_size = 64
	fear.modulate = Color(0.6, 0.15, 0.8)
	fear.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fear.position = Vector3(0, 2.2, 0)
	parent.add_child(fear)
	var tw := fear.create_tween().set_loops()
	tw.tween_property(fear, "position:x", fear.position.x + 0.15, 0.05)
	tw.tween_property(fear, "position:x", fear.position.x - 0.15, 0.05)
	tw.tween_property(fear, "position:x", fear.position.x, 0.05)
	tw.tween_interval(0.3)

# === 施法条 ===

func _create_cast_bar(ui_layer: CanvasLayer) -> void:
	_cast_bar_bg = ColorRect.new()
	_cast_bar_bg.anchor_left = 0.5
	_cast_bar_bg.anchor_right = 0.5
	_cast_bar_bg.anchor_top = 1.0
	_cast_bar_bg.anchor_bottom = 1.0
	_cast_bar_bg.offset_left = -160
	_cast_bar_bg.offset_right = 160
	_cast_bar_bg.offset_top = -90
	_cast_bar_bg.offset_bottom = -68
	_cast_bar_bg.color = Color(0.06, 0.06, 0.12, 0.95)
	_cast_bar_bg.visible = false
	ui_layer.add_child(_cast_bar_bg)
	_cast_bar_fill = ColorRect.new()
	_cast_bar_fill.anchor_top = 0.0
	_cast_bar_fill.anchor_bottom = 1.0
	_cast_bar_fill.anchor_left = 0.0
	_cast_bar_fill.anchor_right = 0.0
	_cast_bar_fill.offset_left = 2
	_cast_bar_fill.offset_top = 2
	_cast_bar_fill.offset_right = 2
	_cast_bar_fill.offset_bottom = -2
	_cast_bar_fill.color = Color(1.0, 0.7, 0.2)
	_cast_bar_bg.add_child(_cast_bar_fill)
	_cast_bar_label = Label.new()
	_cast_bar_label.anchor_left = 0.0
	_cast_bar_label.anchor_right = 1.0
	_cast_bar_label.anchor_top = 0.0
	_cast_bar_label.anchor_bottom = 0.0
	_cast_bar_label.offset_top = -16
	_cast_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cast_bar_label.add_theme_font_size_override("font_size", 12)
	_cast_bar_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_cast_bar_bg.add_child(_cast_bar_label)

func _show_cast_bar(spell_name: String, duration: float, color: Color, reverse: bool) -> void:
	if _cast_bar_tween and is_instance_valid(_cast_bar_tween):
		_cast_bar_tween.kill()
	_cast_bar_bg.visible = true
	_cast_bar_label.text = spell_name
	_cast_bar_label.add_theme_color_override("font_color", color)
	_cast_bar_fill.color = color
	var max_w: float = 316.0
	if reverse:
		_cast_bar_fill.offset_right = 2 + max_w
		_cast_bar_tween = _cast_bar_fill.create_tween()
		_cast_bar_tween.tween_property(_cast_bar_fill, "offset_right", 2.0, duration)
		_cast_bar_tween.tween_callback(func() -> void: _cast_bar_bg.visible = false)
	else:
		_cast_bar_fill.offset_right = 2
		_cast_bar_tween = _cast_bar_fill.create_tween()
		_cast_bar_tween.tween_property(_cast_bar_fill, "offset_right", 2 + max_w, duration)
		_cast_bar_tween.tween_callback(func() -> void: _cast_bar_bg.visible = false)

func _on_cast_bar_start(data: Dictionary) -> void:
	var spell_id: String = str(data.get("spell_id", ""))
	var cast_time: float = data.get("cast_time", 1.0)
	_show_cast_bar(spell_id.replace("test_", "").replace("_", " ").capitalize(), cast_time, Color(1.0, 0.7, 0.2), false)

func _on_channel_bar_start(data: Dictionary) -> void:
	var spell_id: String = str(data.get("spell_id", ""))
	var channel_time: float = data.get("channel_time", 1.0)
	_show_cast_bar(spell_id.replace("test_", "").replace("_", " ").capitalize(), channel_time, Color(0.4, 0.7, 1.0), true)

func _on_cast_bar_end(_data: Dictionary) -> void:
	if _cast_bar_tween and is_instance_valid(_cast_bar_tween):
		_cast_bar_tween.kill()
	_cast_bar_bg.visible = false

func _on_cast_bar_interrupted(_data: Dictionary) -> void:
	if _cast_bar_tween and is_instance_valid(_cast_bar_tween):
		_cast_bar_tween.kill()
	_cast_bar_fill.color = Color(1, 0.2, 0.2)
	_cast_bar_label.text += " - INTERRUPTED"
	_cast_bar_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	if _gm.get_tree():
		_gm.get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if _cast_bar_bg and is_instance_valid(_cast_bar_bg):
				_cast_bar_bg.visible = false
		)

# === 技能栏 ===

func _create_skill_bar(ui_layer: CanvasLayer) -> void:
	var bar := HBoxContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -300
	bar.offset_top = -60
	bar.offset_right = 300
	bar.offset_bottom = -8
	bar.add_theme_constant_override("separation", 6)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	ui_layer.add_child(bar)
	_skill_labels.clear()
	for i in range(SKILL_BAR.size()):
		var skill: Array = SKILL_BAR[i]
		var spell_id: String = skill[0]
		var display: String = skill[1]
		var key_name: String = skill[2]
		var desc: String = skill[3]
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(68, 50)
		var ss := StyleBoxFlat.new()
		ss.bg_color = Color(0.08, 0.07, 0.14, 0.9) if spell_id != "" else Color(0.05, 0.05, 0.08, 0.6)
		ss.corner_radius_top_left = 4
		ss.corner_radius_top_right = 4
		ss.corner_radius_bottom_left = 4
		ss.corner_radius_bottom_right = 4
		ss.border_color = Color(0.4, 0.35, 0.6, 0.7) if spell_id != "" else Color(0.2, 0.2, 0.3, 0.3)
		ss.border_width_top = 1
		ss.border_width_bottom = 1
		ss.border_width_left = 1
		ss.border_width_right = 1
		ss.content_margin_left = 4
		ss.content_margin_right = 4
		ss.content_margin_top = 2
		ss.content_margin_bottom = 2
		slot.add_theme_stylebox_override("panel", ss)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 1)
		slot.add_child(vb)
		var key_lbl := Label.new()
		key_lbl.text = key_name
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.add_theme_font_size_override("font_size", 10)
		key_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vb.add_child(key_lbl)
		var name_lbl := Label.new()
		name_lbl.text = display if display != "" else "-"
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.5) if spell_id != "" else Color(0.3, 0.3, 0.3))
		vb.add_child(name_lbl)
		var status_lbl := Label.new()
		status_lbl.text = desc.left(8) if desc.length() > 8 else desc
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_lbl.add_theme_font_size_override("font_size", 8)
		status_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		vb.add_child(status_lbl)
		_skill_labels.append(status_lbl)
		if desc != "":
			slot.tooltip_text = "%s [%s]\n%s" % [display, key_name, desc]
		bar.add_child(slot)

func _find_nearest_enemy() -> Node3D:
	if _gm.hero == null or not is_instance_valid(_gm.hero):
		return null
	var targets: Array = EngineAPI.find_hostiles_in_area(_gm.hero, _gm.hero.global_position, 99.99)
	if targets.is_empty():
		return null
	var closest: Node3D = null
	var closest_dist := INF
	for t in targets:
		if not is_instance_valid(t):
			continue
		var d: float = _gm.hero.global_position.distance_squared_to(t.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = t
	return closest

func handle_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var key_map := {
		KEY_Q: 0, KEY_W: 1, KEY_E: 2, KEY_R: 3,
		KEY_1: 4, KEY_2: 5, KEY_3: 6, KEY_4: 7,
	}
	var idx: int = key_map.get(event.keycode, -1)
	if idx < 0 or idx >= SKILL_BAR.size():
		return
	var spell_id: String = SKILL_BAR[idx][0]
	if spell_id == "":
		return
	_cast_skill(spell_id, SKILL_BAR[idx][1])

func _cast_skill(spell_id: String, display_name: String) -> void:
	if _gm.hero == null or not is_instance_valid(_gm.hero):
		return
	var spell_sys: Node = EngineAPI.get_system("spell")
	if spell_sys == null:
		return
	var target: Node3D = _gm.hero
	if spell_id != "test_heal":
		var enemy: Node3D = _find_nearest_enemy()
		if enemy:
			target = enemy
		else:
			_log("[color=red]没有目标[/color]")
			return
	var success: bool = spell_sys.call("cast", spell_id, _gm.hero, target)
	if success:
		_log("[color=cyan]>>> 【%s】→ %s[/color]" % [display_name, (target as GameEntity).def_id if target is GameEntity else "self"])
	else:
		var ge: GameEntity = _gm.hero as GameEntity
		if ge.has_any_flag(UnitFlags.CAST_PREVENTING):
			_log("[color=red]施法阻止（%s）[/color]" % UnitFlags.flag_to_string(ge.unit_flags))
		elif ge.has_unit_flag(UnitFlags.CASTING):
			_log("[color=yellow]读条中...[/color]")
		elif ge.has_unit_flag(UnitFlags.CHANNELING):
			_log("[color=yellow]引导中...[/color]")
		else:
			_log("[color=yellow]施法失败[/color]")

# === 辅助 ===

func _cc_name(cc_type: String) -> String:
	match cc_type:
		"CC_STUN": return "眩晕"
		"CC_ROOT": return "定身"
		"CC_SILENCE": return "沉默"
		"CC_FEAR": return "恐惧"
		_: return cc_type

## 可折叠 section：点击标题展开/收起，返回内容容器供后续 _btn/_hint 使用
var _current_section_content: VBoxContainer = null

func _section(parent: VBoxContainer, text: String, collapsed: bool = true) -> void:
	## 创建可折叠 section header + content 容器
	var header := Button.new()
	header.text = ("▶ " if collapsed else "▼ ") + text
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.flat = true
	header.custom_minimum_size = Vector2(0, 22)
	parent.add_child(header)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	content.visible = not collapsed
	parent.add_child(content)
	_current_section_content = content
	# 点击折叠/展开
	header.pressed.connect(func() -> void:
		content.visible = not content.visible
		header.text = ("▼ " if content.visible else "▶ ") + text
	)

func _hint(parent: VBoxContainer, text: String) -> void:
	var target: VBoxContainer = _current_section_content if _current_section_content else parent
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	target.add_child(lbl)

func _btn(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var target: VBoxContainer = _current_section_content if _current_section_content else parent
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 24)
	btn.add_theme_font_size_override("font_size", 10)
	btn.pressed.connect(callback)
	target.add_child(btn)
