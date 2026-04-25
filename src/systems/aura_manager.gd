## AuraManager - Aura 生命周期管理（框架层）
## 借鉴 TrinityCore AuraEffect 系统
## 处理：周期伤害/治疗、属性修改、触发施法、护盾吸收等
## GamePack 可注册自定义 AuraType Handler
class_name AuraManager
extends Node

# === Aura Handler 注册表 ===
# aura_type(String) -> { "apply": Callable, "remove": Callable, "tick": Callable }
var _aura_handlers: Dictionary = {}

# === 活跃 Aura ===
# entity_instance_id -> [AuraInstance, ...]
var _active_auras: Dictionary = {}

func _ready() -> void:
	EngineAPI.register_system("aura", self)
	_register_builtin_auras()

# === 应用 Aura ===

func apply_aura(caster: Node3D, target: Node3D, effect: Dictionary, spell: Dictionary, duration: float) -> void:
	if not is_instance_valid(target):
		return
	var aura_type: String = effect.get("aura", "")
	# IMMUNE_CC 前置检查：CC 类 aura 直接拒绝
	if aura_type in UnitFlags.CC_AURA_TO_FLAG and target is GameEntity:
		if (target as GameEntity).has_unit_flag(UnitFlags.IMMUNE_CC):
			return
	# ImmunitySystem 机制免疫检查（对标 TC MechanicImmunity）
	var immunity_sys: Node = EngineAPI.get_system("immunity")
	if immunity_sys and target is GameEntity:
		var mechanic: String = ImmunitySystem.mechanic_from_cc_aura(aura_type)
		if mechanic != "" and immunity_sys.call("is_immune_to_mechanic", target, mechanic):
			return
		# 减速机制免疫
		if aura_type in ["MOD_SPEED_SLOW", "AREA_SLOW"] and immunity_sys.call("is_immune_to_mechanic", target, ImmunitySystem.MECHANIC_SLOW):
			return
	# DiminishingReturns 递减（对标 TC：同类 CC 递减持续时间 + 强弱比较）
	var dr_sys: Node = EngineAPI.get_system("dr")
	if dr_sys and target is GameEntity and duration > 0:
		var diminished: float = dr_sys.call("get_diminished_duration", target, aura_type, duration)
		if diminished <= 0:
			return  # DR 免疫
		# 强弱比较：如果目标身上已有同组更长的 CC，拒绝覆盖
		if dr_sys.call("has_stronger_aura_with_dr", target, aura_type, diminished):
			return
		duration = diminished
		dr_sys.call("apply_dr", target, aura_type)

	var eid: int = target.get_instance_id()
	var spell_id: String = spell.get("id", "")
	# aura_id 需要区分同 spell 的不同效果（如多个 MOD_STAT 修改不同属性）
	var misc_val: String = effect.get("misc_value", "")
	var effect_idx: String = str(effect.get("_effect_index", ""))
	var aura_id := "%s_%s" % [spell_id, aura_type]
	if misc_val != "":
		aura_id += "_%s" % misc_val  # e.g. card_3_MOD_STAT_armor
	elif effect_idx != "":
		aura_id += "_%s" % effect_idx
	var stack_mode: String = effect.get("stack_mode", "refresh")
	var max_stacks: int = effect.get("max_stacks", 1)

	if not _active_auras.has(eid):
		_active_auras[eid] = []

	# 检查是否已存在同 ID 的 aura
	var existing: Dictionary = _find_aura(eid, aura_id)
	if not existing.is_empty():
		match stack_mode:
			"refresh":
				existing["remaining"] = duration
				return
			"stack":
				if existing["stacks"] < max_stacks:
					existing["stacks"] += 1
				existing["remaining"] = duration
				return
			"none":
				return  # 不叠加不刷新

	# 新建 Aura 实例
	var aura := {
		"aura_id": aura_id,
		"aura_type": aura_type,
		"spell_id": spell_id,
		"caster": caster,
		"target": target,
		"effect": effect,
		"spell": spell,
		"duration": duration,
		"remaining": duration,
		"period": effect.get("period", 0.0),
		"tick_timer": 0.0,
		"stacks": 1,
		"base_points": effect.get("base_points", 0.0),
		"modifier_ids": [],  # 用于属性修改类 aura 的清理
		"proc_id": "",       # 用于 proc 类 aura 的清理
	}

	_active_auras[eid].append(aura)

	# 调用 apply handler
	if _aura_handlers.has(aura_type):
		var handlers: Dictionary = _aura_handlers[aura_type]
		if handlers.has("apply") and handlers["apply"].is_valid():
			handlers["apply"].call(aura)
		# else: no apply handler (DUMMY etc.)
	# Hook: AURA_APPLY（对标 TC AuraScript::OnApply）
	var script_sys: Node = EngineAPI.get_system("spell_script")
	if script_sys:
		script_sys.fire_aura_hook(spell_id, "aura_apply", [aura])

	EventBus.emit_event("aura_applied", {
		"aura_id": aura_id,
		"target": target,
		"caster": caster,
		"aura_type": aura_type,
	})

func remove_aura(target: Node3D, aura_id: String) -> void:
	if not is_instance_valid(target):
		return
	var eid: int = target.get_instance_id()
	if not _active_auras.has(eid):
		return
	var auras: Array = _active_auras[eid]
	for i in range(auras.size() - 1, -1, -1):
		if auras[i]["aura_id"] == aura_id:
			_remove_aura_instance(auras[i])
			auras.remove_at(i)
			break

func has_aura(target: Node3D, aura_id: String) -> bool:
	var eid: int = target.get_instance_id()
	return not _find_aura(eid, aura_id).is_empty()

func get_aura_stacks(target: Node3D, aura_id: String) -> int:
	var eid: int = target.get_instance_id()
	var aura: Dictionary = _find_aura(eid, aura_id)
	return aura.get("stacks", 0)

# === 周期 Tick ===

func _process(delta: float) -> void:
	if EngineAPI.get_game_state() != "playing":
		return

	var entities_to_clean: Array = []

	for eid in _active_auras:
		var auras: Array = _active_auras[eid]
		var to_remove: Array[int] = []

		for i in range(auras.size()):
			var aura: Dictionary = auras[i]
			var target = aura.get("target")
			if target == null or not is_instance_valid(target):
				to_remove.append(i)
				continue

			# 持续时间递减（0 = 永久）
			if aura["duration"] > 0:
				aura["remaining"] -= delta
				if aura["remaining"] <= 0:
					to_remove.append(i)
					continue

			# 周期 tick
			if aura["period"] > 0:
				aura["tick_timer"] += delta
				if aura["tick_timer"] >= aura["period"]:
					aura["tick_timer"] -= aura["period"]
					_tick_aura(aura)

		# 倒序移除
		for idx in range(to_remove.size() - 1, -1, -1):
			var remove_idx: int = to_remove[idx]
			if remove_idx < auras.size():
				_remove_aura_instance(auras[remove_idx])
				auras.remove_at(remove_idx)

		if auras.is_empty():
			entities_to_clean.append(eid)

	for eid in entities_to_clean:
		_active_auras.erase(eid)

func _tick_aura(aura: Dictionary) -> void:
	var aura_type: String = aura["aura_type"]
	if _aura_handlers.has(aura_type):
		var handlers: Dictionary = _aura_handlers[aura_type]
		if handlers.has("tick") and handlers["tick"] != null and handlers["tick"].is_valid():
			handlers["tick"].call(aura)
	# Hook: AURA_TICK
	var script_sys: Node = EngineAPI.get_system("spell_script")
	if script_sys:
		script_sys.fire_aura_hook(aura.get("spell_id", ""), "aura_tick", [aura])

func _remove_aura_instance(aura: Dictionary) -> void:
	var aura_type: String = aura["aura_type"]
	if _aura_handlers.has(aura_type):
		var handlers: Dictionary = _aura_handlers[aura_type]
		if handlers.has("remove") and handlers["remove"] != null and handlers["remove"].is_valid():
			handlers["remove"].call(aura)
	# Hook: AURA_REMOVE
	var script_sys: Node = EngineAPI.get_system("spell_script")
	if script_sys:
		script_sys.fire_aura_hook(aura.get("spell_id", ""), "aura_remove", [aura])

	var target = aura.get("target")
	if target != null and is_instance_valid(target):
		EventBus.emit_event("aura_removed", {
			"aura_id": aura["aura_id"],
			"target": target,
			"aura_type": aura_type,
		})

func _find_aura(eid: int, aura_id: String) -> Dictionary:
	if not _active_auras.has(eid):
		return {}
	for aura in _active_auras[eid]:
		if aura["aura_id"] == aura_id:
			return aura
	return {}

# === Handler 注册 ===

func register_aura_handler(aura_type: String, apply_fn: Callable, remove_fn: Callable, tick_fn: Callable) -> void:
	_aura_handlers[aura_type] = {
		"apply": apply_fn,
		"remove": remove_fn,
		"tick": tick_fn,
	}

# === 内置 Aura Handlers ===

func _register_builtin_auras() -> void:
	register_aura_handler("PERIODIC_DAMAGE", _apply_periodic_damage_vfx, _remove_aura_vfx, _tick_periodic_damage)
	register_aura_handler("PERIODIC_HEAL", _apply_periodic_heal_vfx, _remove_aura_vfx, _tick_periodic_heal)
	register_aura_handler("PERIODIC_TRIGGER_SPELL", Callable(), Callable(), _tick_periodic_trigger)
	register_aura_handler("MOD_STAT", _apply_mod_stat, _remove_mod_stat, Callable())
	register_aura_handler("MOD_SPEED", _apply_mod_speed, _remove_mod_speed, Callable())
	register_aura_handler("MOD_SPEED_SLOW", _apply_slow_vfx, _remove_slow_vfx, Callable())
	register_aura_handler("SCHOOL_ABSORB", _apply_absorb, _remove_absorb, Callable())
	register_aura_handler("PROC_TRIGGER_SPELL", _apply_proc, _remove_proc, Callable())
	register_aura_handler("DAMAGE_SHIELD", _apply_damage_shield, _remove_damage_shield, Callable())
	# CC Aura Handlers（对标 TrinityCore SPELL_AURA_MOD_STUN / MOD_ROOT 等）
	register_aura_handler("CC_STUN", _apply_cc_flag, _remove_cc_flag, Callable())
	register_aura_handler("CC_ROOT", _apply_cc_flag, _remove_cc_flag, Callable())
	register_aura_handler("CC_SILENCE", _apply_cc_flag, _remove_cc_flag, Callable())
	register_aura_handler("CC_FEAR", _apply_cc_flag, _remove_cc_flag, Callable())
	# === 对标 TC 新增 aura 类型 ===
	register_aura_handler("MOD_DAMAGE_PERCENT_DONE", _apply_mod_combat_var, _remove_mod_combat_var, Callable())
	register_aura_handler("MOD_ATTACK_POWER", _apply_mod_stat, _remove_mod_stat, Callable())
	register_aura_handler("MOD_ATTACK_POWER_PCT", _apply_mod_stat, _remove_mod_stat, Callable())
	register_aura_handler("MOD_HASTE", _apply_mod_stat, _remove_mod_stat, Callable())
	register_aura_handler("MOD_CRIT_PCT", _apply_mod_combat_var, _remove_mod_combat_var, Callable())
	register_aura_handler("MOD_DAMAGE_TAKEN", _apply_mod_combat_var, _remove_mod_combat_var, Callable())
	register_aura_handler("CHEAT_DEATH", _apply_cheat_death, _remove_cheat_death, Callable())
	register_aura_handler("DUMMY", Callable(), Callable(), Callable())  # 纯容器，逻辑由 SpellScript hook 处理

# --- CC Flag Handlers ---

func _apply_cc_flag(aura: Dictionary) -> void:
	var target = aura.get("target")
	if target == null or not is_instance_valid(target) or not (target is GameEntity):
		return
	var ge: GameEntity = target as GameEntity
	# IMMUNE_CC 检查
	if ge.has_unit_flag(UnitFlags.IMMUNE_CC):
		return
	var aura_type: String = aura.get("aura_type", "")
	var flag: int = UnitFlags.CC_AURA_TO_FLAG.get(aura_type, 0)
	if flag != 0:
		ge.set_unit_flag(flag)
	# STUN/ROOT: 速度归零
	if flag & UnitFlags.MOVEMENT_PREVENTING:
		var movement: Node = EngineAPI.get_component(target, "movement")
		if movement and movement.has_method("add_speed_modifier"):
			movement.add_speed_modifier("cc_%s" % aura_type.to_lower(), 0.0)

func _remove_cc_flag(aura: Dictionary) -> void:
	var target = aura.get("target")
	if target == null or not is_instance_valid(target) or not (target is GameEntity):
		return
	var ge: GameEntity = target as GameEntity
	var aura_type: String = aura.get("aura_type", "")
	var flag: int = UnitFlags.CC_AURA_TO_FLAG.get(aura_type, 0)
	if flag != 0:
		ge.clear_unit_flag(flag)
	# 恢复速度
	if flag & UnitFlags.MOVEMENT_PREVENTING:
		var movement: Node = EngineAPI.get_component(target, "movement")
		if movement and movement.has_method("remove_speed_modifier"):
			movement.remove_speed_modifier("cc_%s" % aura_type.to_lower())

# --- 周期伤害 ---
func _tick_periodic_damage(aura: Dictionary) -> void:
	var target = aura.get("target")
	var caster = aura.get("caster")
	if target == null or not is_instance_valid(target):
		return
	var dmg: float = aura["base_points"] * aura["stacks"]
	var spell: Dictionary = aura.get("spell", {})
	var school: String = spell.get("school", "physical")
	var ability_name: String = spell.get("id", aura.get("aura_id", "DoT"))
	var health: Node = EngineAPI.get_component(target, "health")
	if health and health.has_method("take_damage"):
		var dt: int = health.parse_damage_type(school)
		health.take_damage(dmg, caster if is_instance_valid(caster) else null, dt, ability_name)

# --- 周期治疗 ---
func _tick_periodic_heal(aura: Dictionary) -> void:
	var target = aura.get("target")
	var caster = aura.get("caster")
	if target == null or not is_instance_valid(target):
		return
	var heal_amount: float = aura["base_points"] * aura["stacks"]
	var ability_name: String = aura.get("spell", {}).get("id", aura.get("aura_id", "HoT"))
	var health: Node = EngineAPI.get_component(target, "health")
	if health and health.has_method("heal"):
		health.heal(heal_amount, caster if is_instance_valid(caster) else null, ability_name)

# --- 周期触发技能 ---
func _tick_periodic_trigger(aura: Dictionary) -> void:
	var caster = aura.get("caster")
	var target = aura.get("target")
	var effect: Dictionary = aura.get("effect", {})
	var trigger_id: String = effect.get("trigger_spell", "")
	if trigger_id == "" or not is_instance_valid(caster):
		return
	# 智能触发：如果 trigger spell 是对敌伤害型，先检查附近有无敌人
	# 避免无敌人时浪费 CD/VFX/公告
	var spell_system: Node = EngineAPI.get_system("spell")
	if spell_system == null:
		return
	if effect.get("require_enemies", true) and caster is GameEntity:
		var spell_def: Dictionary = spell_system.call("get_spell", trigger_id)
		var spell_effects: Array = spell_def.get("effects", [])
		for se: Dictionary in spell_effects:
			var tgt: Dictionary = se.get("target", {})
			if tgt.get("check", "") == "ENEMY":
				var radius: float = tgt.get("radius", 5.0)
				var hostiles: Array = EngineAPI.find_hostiles_in_area(caster, caster.global_position, radius)
				if hostiles.is_empty():
					return  # 附近无敌人，跳过
				break  # 找到一个 ENEMY check 就够了
	# 概率检查（chance 0.0-1.0，0 或未设置 = 100%）
	var chance: float = effect.get("chance", 0.0)
	if chance > 0 and randf() > chance:
		return
	# 标记 _is_proc 防止 periodic 伤害再触发 on_hit proc（无限递归）
	spell_system.call("cast", trigger_id, caster, target if is_instance_valid(target) else null, {"_is_proc": true})

# --- 属性修改 ---
func _apply_mod_stat(aura: Dictionary) -> void:
	## 对标 TC AuraEffect::HandleAuraModStat → Unit::HandleStatFlatModifier → UpdateMaxHealth 等
	var target = aura.get("target")
	if target == null or not is_instance_valid(target):
		return
	var stat_name: String = aura.get("effect", {}).get("misc_value", "")
	var mod_type: String = aura.get("effect", {}).get("mod_type", "flat")
	var value: float = aura["base_points"]
	if stat_name == "":
		push_warning("[AuraManager] MOD_STAT: empty stat_name, effect=%s" % str(aura.get("effect", {})))
		return
	# MOD_STAT applied: stat_name, mod_type, value
	# 直接操作 StatSystem 的绿字属性（不用旧 modifier）
	if mod_type == "percent":
		EngineAPI.add_green_percent(target, stat_name, value)
	else:
		EngineAPI.add_green_stat(target, stat_name, value)
	# StatSystem._notify_stat_changed 会自动触发
	# _sync_health_from_stat 自动同步 HP/MP/Armor
	_sync_health_from_stat(target, stat_name, value, true)

func _remove_mod_stat(aura: Dictionary) -> void:
	var target = aura.get("target")
	if target == null or not is_instance_valid(target):
		return
	var stat_name: String = aura.get("effect", {}).get("misc_value", "")
	var mod_type: String = aura.get("effect", {}).get("mod_type", "flat")
	var value: float = aura.get("base_points", 0.0)
	if stat_name == "":
		return
	if mod_type == "percent":
		EngineAPI.remove_green_percent(target, stat_name, value)
	else:
		EngineAPI.remove_green_stat(target, stat_name, value)
	_sync_health_from_stat(target, stat_name, -value, false)

func _apply_mod_combat_var(aura: Dictionary) -> void:
	## 对标 TC MOD_DAMAGE_PERCENT_DONE / MOD_CRIT_PCT 等
	## 修改战斗变量（存储在 EngineAPI variables 中，DamagePipeline 读取）
	var effect: Dictionary = aura.get("effect", {})
	var var_name: String = effect.get("misc_value", "")
	var value: float = aura.get("base_points", 0.0)
	if var_name == "":
		return
	var current: float = float(EngineAPI.get_variable(var_name, 0.0))
	EngineAPI.set_variable(var_name, current + value)

func _remove_mod_combat_var(aura: Dictionary) -> void:
	var effect: Dictionary = aura.get("effect", {})
	var var_name: String = effect.get("misc_value", "")
	var value: float = aura.get("base_points", 0.0)
	if var_name == "":
		return
	var current: float = float(EngineAPI.get_variable(var_name, 0.0))
	EngineAPI.set_variable(var_name, current - value)

func _apply_cheat_death(aura: Dictionary) -> void:
	var target = aura.get("target")
	if target and is_instance_valid(target) and target is GameEntity:
		(target as GameEntity).set_meta_value("cheat_death_spell", aura.get("spell_id", ""))

func _remove_cheat_death(aura: Dictionary) -> void:
	var target = aura.get("target")
	if target and is_instance_valid(target) and target is GameEntity:
		(target as GameEntity).set_meta_value("cheat_death_spell", "")

func _sync_health_from_stat(target: Node3D, stat_name: String, value: float, is_apply: bool) -> void:
	## 属性变化自动同步到 HealthComponent（框架级，对标 TC UpdateMaxHealth/UpdateMaxPower）
	var health: Node = EngineAPI.get_component(target, "health")
	if health == null:
		return
	match stat_name:
		"hp":
			health.max_hp += value
			if is_apply:
				health.current_hp = minf(health.current_hp + value, health.max_hp)
			else:
				health.current_hp = minf(health.current_hp, health.max_hp)
		"mp", "mana":
			if health.get("max_mp") != null:
				health.max_mp += value
				if is_apply:
					health.current_mp = minf(health.current_mp + value, health.max_mp)
				else:
					health.current_mp = minf(health.current_mp, health.max_mp)
		"armor":
			if health.get("armor") != null:
				health.armor += value
		"regen":
			if health.get("regen_per_sec") != null:
				health.regen_per_sec += value

# --- 速度修改 ---
func _apply_mod_speed(aura: Dictionary) -> void:
	var target = aura.get("target")
	if target == null or not is_instance_valid(target):
		return
	var factor: float = 1.0 + aura["base_points"]  # base_points = 0.3 → 130% speed
	var movement: Node = EngineAPI.get_component(target, "movement")
	if movement and movement.has_method("add_speed_modifier"):
		movement.add_speed_modifier(aura["aura_id"], factor)

func _remove_mod_speed(aura: Dictionary) -> void:
	var target = aura.get("target")
	if target != null and is_instance_valid(target):
		var movement: Node = EngineAPI.get_component(target, "movement")
		if movement and movement.has_method("remove_speed_modifier"):
			movement.remove_speed_modifier(aura["aura_id"])

# --- 减速（取最强，不叠加）---
func _apply_mod_speed_slow(aura: Dictionary) -> void:
	var target = aura.get("target")
	if target == null or not is_instance_valid(target):
		return
	var slow_pct: float = aura["base_points"]  # 0.2 = 20% slow
	var factor: float = 1.0 - slow_pct
	var movement: Node = EngineAPI.get_component(target, "movement")
	if movement and movement.has_method("add_speed_modifier"):
		# 固定 ID：同类减速覆盖而非叠加
		movement.remove_speed_modifier("aura_slow")
		movement.add_speed_modifier("aura_slow", factor)

func _remove_mod_speed_slow(aura: Dictionary) -> void:
	var target = aura.get("target")
	if target != null and is_instance_valid(target):
		var movement: Node = EngineAPI.get_component(target, "movement")
		if movement and movement.has_method("remove_speed_modifier"):
			movement.remove_speed_modifier("aura_slow")

# --- 护盾吸收 ---
func _apply_absorb(aura: Dictionary) -> void:
	aura["absorb_remaining"] = aura["base_points"]

func _remove_absorb(_aura: Dictionary) -> void:
	pass  # 吸收量耗尽或持续时间到

func consume_absorb(target: Node3D, amount: float, _school: int) -> float:
	## 消耗目标身上的 SCHOOL_ABSORB aura，返回总吸收量
	if not is_instance_valid(target):
		return 0.0
	var eid: int = target.get_instance_id()
	if not _active_auras.has(eid):
		return 0.0
	var total_absorbed := 0.0
	var remaining := amount
	var auras: Array = _active_auras[eid]
	var to_remove: Array = []
	for i in range(auras.size()):
		if remaining <= 0:
			break
		var aura: Dictionary = auras[i]
		if aura.get("aura_type", "") != "SCHOOL_ABSORB":
			continue
		var absorb_left: float = aura.get("absorb_remaining", 0.0)
		if absorb_left <= 0:
			continue
		var absorbed: float = minf(remaining, absorb_left)
		aura["absorb_remaining"] -= absorbed
		remaining -= absorbed
		total_absorbed += absorbed
		if aura["absorb_remaining"] <= 0:
			to_remove.append(i)
	# 移除耗尽的吸收盾（倒序移除）
	for idx in range(to_remove.size() - 1, -1, -1):
		_remove_aura_instance(auras[to_remove[idx]])
		auras.remove_at(to_remove[idx])
	return total_absorbed

# --- Proc 触发 ---
func _apply_proc(aura: Dictionary) -> void:
	var proc_manager: Node = EngineAPI.get_system("proc")
	if proc_manager:
		var proc_data: Dictionary = aura.get("effect", {}).get("proc", {})
		var _trigger_spell: String = aura.get("effect", {}).get("trigger_spell", "")
		# proc registered
		var proc_id: String = proc_manager.call("register_proc", aura, proc_data)
		aura["proc_id"] = proc_id

func _remove_proc(aura: Dictionary) -> void:
	var proc_manager: Node = EngineAPI.get_system("proc")
	if proc_manager and aura["proc_id"] != "":
		proc_manager.call("unregister_proc", aura["proc_id"])

# --- 伤害反弹 ---
func _apply_damage_shield(aura: Dictionary) -> void:
	# 通过 proc 系统实现：受到伤害时反弹
	var proc_manager: Node = EngineAPI.get_system("proc")
	if proc_manager:
		var proc_id: String = proc_manager.call("register_proc", aura, {
			"flags": ["TAKE_DAMAGE"],
			"chance": 100,
			"action": "reflect",
			"reflect_pct": aura["base_points"],
		})
		aura["proc_id"] = proc_id

func _remove_damage_shield(aura: Dictionary) -> void:
	_remove_proc(aura)

# === 查询 ===

func _reset() -> void:
	_active_auras.clear()

func get_auras_on(target: Node3D) -> Array:
	if not is_instance_valid(target):
		return []
	var eid: int = target.get_instance_id()
	return _active_auras.get(eid, [])

func clear_auras_on(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	var eid: int = target.get_instance_id()
	if _active_auras.has(eid):
		for aura in _active_auras[eid]:
			_remove_aura_instance(aura)
		_active_auras.erase(eid)

# === Aura 持续视觉特效 ===

func _create_aura_particles(target: Node3D, config: Dictionary) -> GPUParticles3D:
	## 创建附着在目标身上的持续粒子
	if not is_instance_valid(target):
		return null
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = false
	particles.amount = config.get("amount", 4)
	particles.lifetime = config.get("lifetime", 0.8)
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = config.get("direction", Vector3(0, 1, 0))
	pmat.spread = config.get("spread", 45.0)
	pmat.initial_velocity_min = config.get("speed_min", 0.5)
	pmat.initial_velocity_max = config.get("speed_max", 1.5)
	pmat.gravity = config.get("gravity", Vector3.ZERO)
	pmat.scale_min = config.get("size_min", 0.05)
	pmat.scale_max = config.get("size_max", 0.1)
	var color_start: Color = config.get("color", Color.WHITE)
	var color_end: Color = config.get("color_end", Color(1, 1, 1, 0))
	var gradient := Gradient.new()
	gradient.set_color(0, color_start)
	gradient.set_color(1, color_end)
	var tex := GradientTexture1D.new()
	tex.gradient = gradient
	pmat.color_ramp = tex
	particles.process_material = pmat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	particles.draw_pass_1 = quad
	var draw_mat := StandardMaterial3D.new()
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.material_override = draw_mat
	particles.position = Vector3(0, 0.5, 0)  # 实体上方
	particles.name = config.get("node_name", "AuraVFX")
	target.add_child(particles)
	return particles

func _apply_periodic_damage_vfx(aura: Dictionary) -> void:
	var target = aura.get("target")
	if target == null or not is_instance_valid(target):
		return
	var school: String = aura.get("spell", {}).get("school", "physical")
	var config: Dictionary = {}
	match school:
		"fire":
			config = {
				"amount": 5, "lifetime": 0.6,
				"direction": Vector3(0, 1, 0), "spread": 30.0,
				"speed_min": 15, "speed_max": 30,
				"gravity": Vector3(0, 1.2, 0),
				"size_min": 1.5, "size_max": 2.5,
				"color": Color(1, 0.5, 0.1, 0.8),
				"color_end": Color(1, 0.2, 0, 0),
				"node_name": "BurnVFX",
			}
		"nature", "poison":
			config = {
				"amount": 3, "lifetime": 0.8,
				"direction": Vector3(0, 1, 0), "spread": 60.0,
				"speed_min": 8, "speed_max": 15,
				"gravity": Vector3(0, 0.6, 0),
				"size_min": 1.5, "size_max": 2.0,
				"color": Color(0.3, 0.9, 0.2, 0.7),
				"color_end": Color(0.1, 0.6, 0.1, 0),
				"node_name": "PoisonVFX",
			}
		"frost", "ice":
			config = {
				"amount": 4, "lifetime": 1.0,
				"direction": Vector3(0, 0, 0), "spread": 180.0,
				"speed_min": 5, "speed_max": 12,
				"gravity": Vector3(0, -0.3, 0),
				"size_min": 1.0, "size_max": 2.0,
				"color": Color(0.5, 0.8, 1, 0.7),
				"color_end": Color(0.7, 0.9, 1, 0),
				"node_name": "FrostVFX",
			}
		"shadow":
			config = {
				"amount": 4, "lifetime": 0.7,
				"direction": Vector3(0, 0, 0), "spread": 180.0,
				"speed_min": 10, "speed_max": 20,
				"gravity": Vector3.ZERO,
				"size_min": 1.5, "size_max": 2.5,
				"color": Color(0.5, 0.2, 0.8, 0.7),
				"color_end": Color(0.3, 0.1, 0.5, 0),
				"node_name": "ShadowVFX",
			}
		_:
			return  # 物理伤害不加持续特效
	var p := _create_aura_particles(target, config)
	if p:
		aura["_vfx_node"] = p

func _apply_periodic_heal_vfx(aura: Dictionary) -> void:
	var target = aura.get("target")
	if target == null or not is_instance_valid(target):
		return
	var p := _create_aura_particles(target, {
		"amount": 3, "lifetime": 1.0,
		"direction": Vector3(0, 1, 0), "spread": 20.0,
		"speed_min": 10, "speed_max": 20,
		"gravity": Vector3(0, 1.0, 0),
		"size_min": 1.5, "size_max": 2.0,
		"color": Color(0.3, 1, 0.4, 0.6),
		"color_end": Color(0.5, 1, 0.6, 0),
		"node_name": "HealVFX",
	})
	if p:
		aura["_vfx_node"] = p

func _apply_slow_vfx(aura: Dictionary) -> void:
	## 减速 = 速度修改 + 冰霜粒子
	_apply_mod_speed_slow(aura)
	var target = aura.get("target")
	if target == null or not is_instance_valid(target):
		return
	var p := _create_aura_particles(target, {
		"amount": 3, "lifetime": 1.2,
		"direction": Vector3(0, 0, 0), "spread": 180.0,
		"speed_min": 3, "speed_max": 8,
		"gravity": Vector3(0, -0.5, 0),
		"size_min": 1.0, "size_max": 1.8,
		"color": Color(0.6, 0.85, 1, 0.6),
		"color_end": Color(0.8, 0.95, 1, 0),
		"node_name": "SlowVFX",
	})
	if p:
		aura["_vfx_node"] = p

func _remove_slow_vfx(aura: Dictionary) -> void:
	_remove_mod_speed_slow(aura)
	_remove_aura_vfx(aura)

func _remove_aura_vfx(aura: Dictionary) -> void:
	var vfx = aura.get("_vfx_node")
	if vfx != null and vfx is Node and is_instance_valid(vfx):
		(vfx as Node).queue_free()
	aura.erase("_vfx_node")
