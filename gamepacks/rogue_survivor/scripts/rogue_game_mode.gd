## Rogue Survivor - 肉鸽生存射击主脚本（主控制器）
## 存活10分钟后击杀终极BOSS获胜
extends GamePackScript

## I18n 引用（Autoload 在动态加载脚本中可能不直接可用）
@onready var I18n: Node = get_node_or_null("/root/I18n")

const ARENA_SIZE := Vector2(48.0, 27.0)  # 紧凑地图
# 水晶在右侧中央，刷怪点在左侧（同一水平线）
const PLAYER_FOUNTAIN_POS := Vector3(40.0, 0, 13.5)  # 右侧中央
const ENEMY_FOUNTAIN_POS := Vector3(5.0, 0, 13.5)    # 左侧中央（装饰用）
const HERO_START_POS := Vector3(35.0, 0, 13.5)
# 怪物刷新点：左侧水平排列（与水晶同一水平线）
const SPAWN_POINTS: Array[Vector3] = [
	Vector3(2.0, 0, 9.0),
	Vector3(2.0, 0, 13.5),
	Vector3(2.0, 0, 18.0),
]

const GAME_DURATION := 600.0
const WAVE_INTERVAL := 7.0
const MAX_SUMMONS := 8  # 召唤物数量上限
const SUMMON_LIFESPAN := 15.0  # 召唤物存活秒数
const TOTAL_WAVES := 9999  # 无限波次
const XP_PER_LEVEL_BASE := 30
const XP_PER_LEVEL_GROWTH := 20

var hero: Node3D = null
var player_fountain: Node3D = null
var _game_timer: float = 0.0
var _respawn_timer: float = 0.0
var _hero_dead: bool = false
var _wave_timer: float = 0.0
# 以下变量由子模块通过 _gm.xxx 访问，主文件不直接使用
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _current_wave: int = 0
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _hero_level: int = 1
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _xp_to_next: int = XP_PER_LEVEL_BASE
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _card_manager = null
var _difficulty: Dictionary = {}
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _kills: int = 0
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _bosses_killed: int = 0
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _total_damage_dealt: float = 0.0
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _total_damage_taken: float = 0.0
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _total_healing: float = 0.0
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _max_hit: float = 0.0
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _shaman_heal_timer: float = 0.0
const SHAMAN_HEAL_TICK := 2.0
const EFFECT_INTERNAL_CD := 0.5
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _promoted: bool = false
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _promoted_class: String = ""
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _base_damage: float = 0.0
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _base_cooldown: float = 0.0
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _base_max_hp: float = 0.0
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _base_armor: float = 0.0
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _base_speed: float = 0.0

# === 模块 preload ===
const _CombatClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_combat.gd")
const _CardUIClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_card_ui.gd")
const _HUDClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_hud.gd")
const _CombatLogClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_combat_log.gd")
const _TooltipClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_tooltip.gd")
const _RelicClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_relic.gd")
const _TestArenaClass = preload("res://gamepacks/rogue_survivor/scripts/test_arena_panel.gd")
const _ThemeBondClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd")
const _EliteClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_elite.gd")
const _WaveSystemClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_wave_system.gd")
const _EquipmentClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_equipment.gd")
const _CardSysClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_card_system.gd")
const _AbilityValuesClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_ability_values.gd")
const _VFXClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_vfx.gd")
const _HUDUnitInfoClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_hud_unit_info.gd")
const _StatFormulaClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_stat_formula.gd")
const _ArenaClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_arena.gd")
const _HeroClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_hero.gd")
const _RewardsClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_rewards.gd")
const _SpawnerClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_spawner.gd")
const _UIPanelsClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_ui_panels.gd")
const _SelfTestClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_self_test.gd")

var _combat_module = null
var _card_ui_module = null
var _hud_module = null
var _hud_unit_info = null
var _wave_system = null
var _equipment = null
var _card_sys = null
var _consume_check_timer: float = 0.0
var _ability_values = null
var _combat_log_module = null
var _tooltip_module = null
var _relic_module = null
var _theme_bond_module = null
var _elite_module = null
var _vfx_module = null
var _test_arena = null
var _stat_formula = null
var _arena_module = null
var _hero_module = null
var _rewards_module = null
var _spawner = null
var _ui_panels = null
var _self_test = null

func _pack_ready() -> void:
	# 初始化模块
	_combat_log_module = _CombatLogClass.new()
	_combat_log_module.init(self)
	_tooltip_module = _TooltipClass.new()
	_tooltip_module.init(self)
	_combat_module = _CombatClass.new()
	_combat_module.init(self)
	_card_ui_module = null
	_relic_module = null  # 老宝物系统已禁用
	_theme_bond_module = _ThemeBondClass.new()
	_theme_bond_module.init(self)
	_elite_module = _EliteClass.new()
	_elite_module.init(self)
	_hud_module = _HUDClass.new()
	_hud_module.init(self)
	_hud_unit_info = _HUDUnitInfoClass.new()
	_hud_unit_info.init(self)
	_wave_system = _WaveSystemClass.new()
	_wave_system.init(self)
	_equipment = _EquipmentClass.new()
	_equipment.init(self)
	_card_sys = _CardSysClass.new()
	_card_sys.init(self)
	_stat_formula = _StatFormulaClass.new()
	_stat_formula.init(self)
	_arena_module = _ArenaClass.new()
	_arena_module.init(self)
	_hero_module = _HeroClass.new()
	_hero_module.init(self)
	_rewards_module = _RewardsClass.new()
	_rewards_module.init(self)
	_spawner = _SpawnerClass.new()
	_spawner.init(self)
	_ui_panels = _UIPanelsClass.new()
	_ui_panels.init(self)
	_self_test = _SelfTestClass.new()
	_self_test.init(self)
	# 注册自定义 spell effect handler（GamePack 级，对标 TC SpellScript）
	var spell_sys: Node = EngineAPI.get_system("spell")
	if spell_sys:
		spell_sys.register_effect_handler("INSTANT_KILL", _effect_instant_kill)
		spell_sys.register_effect_handler("ADD_GREEN_STAT", _effect_add_green_stat)
		spell_sys.register_effect_handler("ADD_GREEN_PERCENT", _effect_add_green_percent)
	_ability_values = _AbilityValuesClass.new()
	_ability_values.init(self)
	_vfx_module = _VFXClass.new()
	_vfx_module.init(self)

	listen("player_shoot", _on_player_shoot)
	listen("projectile_hit", _on_projectile_hit)
	listen("entity_destroyed", _on_entity_destroyed)
	listen("entity_killed", _on_entity_killed)
	listen("resource_changed", _on_resource_changed)
	listen("resource_gained_by_spell", _on_resource_gained_by_spell)
	listen("entity_damaged", _on_stat_damaged)
	listen("entity_healed", _on_stat_healed)
	listen("loot_picked_up", _on_loot_picked_up)
	listen("inventory_full", _on_inventory_full)
	listen("proc_triggered", _on_proc_triggered)
	listen("spell_cast", _on_proc_spell_cast)

	# 先绘制地图和 HUD，不刷怪（等玩家选完难度+英雄后再开始）
	_arena_module.draw_arena()
	_hud_module.create_hud()
	var ui_layer: CanvasLayer = get_tree().current_scene.get_node_or_null("UI")
	if ui_layer:
		_hud_unit_info.create(ui_layer)
	_spawn_fountains()

	# 测试模式：跳过选择，直接开始
	var is_test: bool = SceneManager.pending_data.get("test_mode", false)
	if is_test:
		_difficulty = {"level": 1, "hp_mult": 1.0, "dmg_mult": 1.0, "count_mult": 1.0, "reward_mult": 1.0, "name": "N1"}
		_start_game_with_hero("warrior")
		_test_arena = _TestArenaClass.new()
		_test_arena.init(self)
		_test_arena.create_panel()
		_wave_timer = -999.0
	else:
		EngineAPI.set_game_state("selecting")
		_ui_panels.show_selection_ui()

	# BGM
	EngineAPI.play_bgm("res://assets/audio/bgm/battle_01.mp3", 2.0)

func _start_game_with_hero(hero_class: String) -> void:
	## 选择完成后：生成英雄 + 初始化系统 + 开始波次
	SceneManager.pending_data["hero_class"] = hero_class
	set_var("hero_class", hero_class)
	_hero_module.spawn_hero()

	# 初始资源
	EngineAPI.add_resource("gold", 100000)  # TODO: 测试用，正式改回 360
	EngineAPI.add_resource("wood", 100000)  # TODO: 测试用，正式改回 22
	EngineAPI.add_resource("kills", 25)

	# 每秒资源产出
	EngineAPI.set_variable("base_gold_per_sec", 3.0)
	EngineAPI.set_variable("base_wood_per_sec", 2.0)

	EngineAPI.set_game_state("playing")

	if _wave_system:
		_wave_system.start_wave(0)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _ui_panels.is_pause_menu_open():
			_ui_panels.close_pause_menu()
		else:
			_ui_panels.show_pause_menu()
	# F 键抽卡
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			if _card_sys:
				_card_sys.draw_card()
	# F12 自检
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12 and _self_test:
			_self_test.run_all_tests()
	# 测试模式：技能栏按键
	if _test_arena and _test_arena.has_method("handle_input"):
		_test_arena.handle_input(event)

func _pack_process(delta: float) -> void:
	_game_timer += delta
	_wave_timer += delta
	_combat_module.process_boss_skills(delta)
	_combat_module.process_shaman_heals(delta)
	_elite_module.process_elites(delta)

	# Hero respawn countdown
	if _hero_dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0:
			_hero_dead = false
			_hero_module.spawn_hero()
			var cam: Node = EngineAPI.get_system("camera")
			if cam and cam.has_method("follow") and hero and is_instance_valid(hero):
				cam.follow(hero, 8.0)
			_combat_log_module._add_log(I18n.t("HERO_RESPAWN"), Color(0.3, 1, 0.3))
		return

	# 新波次系统处理
	if _wave_system and _wave_system.wave_active:
		_wave_system.process(delta)

	# 旧波次兼容（测试模式或 wave_system 未激活时）
	if not _wave_system or not _wave_system.wave_active:
		if _wave_timer >= WAVE_INTERVAL:
			_spawner.spawn_wave()
			_wave_timer = 0.0

	# 基础每秒资源产出
	var base_gps: float = float(EngineAPI.get_variable("base_gold_per_sec", 0.0))
	var base_wps: float = float(EngineAPI.get_variable("base_wood_per_sec", 0.0))
	if base_gps > 0:
		EngineAPI.add_resource("gold", base_gps * delta)
	if base_wps > 0:
		EngineAPI.add_resource("wood", base_wps * delta)

	# 装备系统
	if _equipment:
		_equipment.process(delta)

	# 回血
	var hp_regen: float = float(EngineAPI.get_variable("hero_hp_regen", 0.0))
	if hp_regen > 0 and hero and is_instance_valid(hero):
		var hcomp: Node = EngineAPI.get_component(hero, "health")
		if hcomp and hcomp.has_method("heal"):
			hcomp.heal(hp_regen * delta, hero, "regen")

	# 周期性检查卡片吞噬条件（每秒一次）
	if _card_sys:
		_consume_check_timer += delta
		if _consume_check_timer >= 1.0:
			_consume_check_timer = 0.0
			_card_sys.check_consume_conditions()

	_stat_formula.apply()
	_hud_module.update_hud()
	if _hud_unit_info: _hud_unit_info.update(delta)
	_tooltip_module.update_tooltip_position()

# === 委托到模块的事件处理器 ===

func _on_player_shoot(data: Dictionary) -> void:
	_combat_module.on_player_shoot(data)

func _on_projectile_hit(data: Dictionary) -> void:
	_combat_module.on_projectile_hit(data)

func _on_entity_killed(data: Dictionary) -> void:
	_rewards_module.on_entity_killed(data)

func _on_resource_gained_by_spell(data: Dictionary) -> void:
	_rewards_module.on_resource_gained_by_spell(data)

func _on_loot_picked_up(data: Dictionary) -> void:
	_rewards_module.on_loot_picked_up(data)

func _on_inventory_full(data: Dictionary) -> void:
	_rewards_module.on_inventory_full(data)

func _on_stat_damaged(data: Dictionary) -> void:
	_rewards_module.on_stat_damaged(data)

func _on_stat_healed(data: Dictionary) -> void:
	_rewards_module.on_stat_healed(data)

func _on_resource_changed(data: Dictionary) -> void:
	_rewards_module.on_resource_changed(data)

func _on_proc_triggered(data: Dictionary) -> void:
	## Proc 触发时显示公告
	var trigger_spell: String = data.get("trigger_spell", "")
	if trigger_spell == "" or _hud_module == null:
		return
	var spell_name: String = trigger_spell
	if _card_sys:
		var card_id: String = trigger_spell.replace("card_", "").replace("_proc", "")
		var resolved: String = _card_sys.get_spell_name(card_id)
		if resolved != card_id:
			spell_name = resolved
	_hud_module.add_announcement("[b]%s[/b]" % spell_name, Color(1, 0.85, 0.3))

func _on_proc_spell_cast(data: Dictionary) -> void:
	## 周期型 proc 也显示公告
	var spell_id: String = data.get("spell_id", "")
	if not spell_id.ends_with("_proc") or _hud_module == null:
		return
	var card_id: String = spell_id.replace("card_", "").replace("_proc", "")
	var spell_name: String = card_id
	if _card_sys:
		var resolved: String = _card_sys.get_spell_name(card_id)
		if resolved != card_id:
			spell_name = resolved
	_hud_module.add_announcement("[b]%s[/b]" % spell_name, Color(0.5, 0.7, 1))

# === 自定义 spell effect handler ===

func _effect_add_green_stat(caster: Node3D, _target: Node3D, effect: Dictionary, _spell: Dictionary) -> void:
	var stat: String = effect.get("stat", "")
	var value: float = effect.get("base_points", 0.0)
	if stat != "" and caster and is_instance_valid(caster):
		EngineAPI.add_green_stat(caster, stat, value)

func _effect_add_green_percent(caster: Node3D, _target: Node3D, effect: Dictionary, _spell: Dictionary) -> void:
	var stat: String = effect.get("stat", "")
	var value: float = effect.get("base_points", 0.0)
	if stat != "" and caster and is_instance_valid(caster):
		EngineAPI.add_green_percent(caster, stat, value)

func _effect_instant_kill(caster: Node3D, target: Node3D, effect: Dictionary, _spell: Dictionary) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not (target is GameEntity):
		return
	var ge: GameEntity = target as GameEntity
	var filter: Dictionary = effect.get("filter", {})
	var exclude: Array = filter.get("exclude_tags", [])
	for tag in exclude:
		if ge.has_tag(tag):
			return
	var health: Node = EngineAPI.get_component(target, "health")
	if health:
		health.take_damage(health.current_hp + 100.0, caster, 0, "midas_touch", true)
	var bonus_gold: int = effect.get("bonus_gold", 20)
	var bonus_xp: int = effect.get("bonus_xp", 25)
	EngineAPI.add_resource("gold", bonus_gold)
	EngineAPI.add_resource("xp", bonus_xp)
	_rewards_module.spawn_resource_text(target, "+%d" % bonus_gold, Color(1, 0.85, 0.2))
	if _hud_module:
		_hud_module.add_announcement("[b]Midas![/b] +%d Gold" % bonus_gold, Color(1, 0.85, 0.2))

# === 初始化辅助 ===

func _spawn_fountains() -> void:
	player_fountain = spawn("life_fountain", PLAYER_FOUNTAIN_POS)

func _on_challenge_wave() -> void:
	_spawner.on_challenge_wave()

func _on_challenge_boss() -> void:
	_spawner.on_challenge_boss()

func _on_entity_destroyed(data: Dictionary) -> void:
	_rewards_module.on_entity_destroyed(data)

# === 胜负 ===

func _victory(reason: String) -> void:
	if EngineAPI.get_game_state() != "playing":
		return
	EngineAPI.set_game_state("victory")
	emit("game_victory", {"reason": reason})
	_rewards_module.save_battle_rewards(true)
	_rewards_module.show_game_over(true, reason)

func _defeat(reason: String) -> void:
	if EngineAPI.get_game_state() != "playing":
		return
	EngineAPI.set_game_state("defeat")
	emit("game_defeat", {"reason": reason})
	_rewards_module.save_battle_rewards(false)
	_rewards_module.show_game_over(false, reason)

func _get_entity_name(entity: Variant) -> String:
	if entity == null or not is_instance_valid(entity):
		return "?"
	if entity is GameEntity:
		return (entity as GameEntity).def_id
	return "?"

func _on_item_dropped(item: Dictionary, _pos: Vector3) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	var item_sys: Node = EngineAPI.get_system("item")
	if item_sys == null:
		return
	var def: Dictionary = item.get("def", {})
	var item_type: String = def.get("type", "")
	var item_name: String = item_sys.call("get_item_display_name", item)
	var rarity: String = def.get("rarity", "common")

	var target_slot := ""
	match item_type:
		"weapon": target_slot = "weapon"
		"armor": target_slot = "armor"
		"accessory":
			for acc_slot in ["accessory_1", "accessory_2", "accessory_3", "accessory_4"]:
				var existing: Dictionary = item_sys.call("get_equipped_in_slot", hero, acc_slot)
				if existing.is_empty():
					target_slot = acc_slot
					break
			if target_slot == "":
				target_slot = "accessory_1"

	if target_slot != "":
		var _old: Dictionary = item_sys.call("equip_item", hero, target_slot, item)
		var color: Color = item_sys.call("get_rarity_color", rarity)
		_combat_log_module._add_log("[DROP] %s (%s)" % [item_name, I18n.t(rarity.to_upper())], color)
