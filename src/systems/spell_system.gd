## SpellSystem - 数据驱动技能引擎（框架层）
## 借鉴 TrinityCore Spell 框架
##
## Spell JSON 结构:
## {
##   "id": "spell_id",
##   "name": "Display Name",
##   "school": "physical|frost|fire|nature|shadow|holy",
##   "school_mask": ["fire", "frost"],  // 多属性，可选
##   "cooldown": 0.0,
##   "flags": ["PASSIVE", "NO_GCD"],    // 技能标记
##   "effects": [
##     {
##       "type": "SCHOOL_DAMAGE|HEAL|APPLY_AURA|TRIGGER_SPELL|...",
##       "base_points": 50,
##       "per_level": 5,               // 每级加成
##       "scaling": {
##         "stat": "spell_power",      // 引用 caster 的某个属性
##         "coefficient": 1.0,         // 系数
##         "pct_of_stat": "max_hp",    // 按百分比引用（如 max_hp 的 10%）
##         "pct": 0.1
##       },
##       "condition": {                // 条件：满足才执行此 effect
##         "type": "hp_below|hp_above|has_aura|variable_check",
##         "target": "caster|target",
##         "value": 0.5
##       },
##       "aura": "PERIODIC_DAMAGE|MOD_STAT|PROC_TRIGGER_SPELL|...",
##       "period": 1.0,
##       "duration": 10.0,
##       "trigger_spell": "other_spell_id",
##       "proc": { "flags": ["on_hit"], "chance": 25, "cooldown": 1.0, "charges": 3 },
##       "target": {
##         "category": "DEFAULT|SELF|AREA|NEAREST|CHAIN|CONE",
##         "reference": "CASTER|TARGET",
##         "check": "ENEMY|ALLY|PLAYER|ALL",
##         "radius": 200,
##         "chain_targets": 3,
##         "max_targets": 5,
##         "cone_angle": 60
##       }
##     }
##   ]
## }
class_name SpellSystem
extends Node

var _effect_handlers: Dictionary = {}
var _spells: Dictionary = {}
# 施法状态机（Phase 1.6）
var _casting_entities: Dictionary = {}     # caster_id → {caster, spell, target, timer, interruptible}
var _channeling_entities: Dictionary = {}  # caster_id → {caster, spell, target, remaining, period, tick_timer}

func _reset() -> void:
	_spells.clear()
	_casting_entities.clear()
	_channeling_entities.clear()

func _ready() -> void:
	EngineAPI.register_system("spell", self)
	_register_builtin_effects()
	EventBus.connect_event("entity_damaged", _on_caster_damaged)

# === Spell 数据管理 ===

func load_spells_from_directory(dir_path: String) -> int:
	var count := 0
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file := FileAccess.open(dir_path.path_join(file_name), FileAccess.READ)
			if file:
				var json := JSON.new()
				if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
					var spell: Dictionary = json.data
					var spell_id: String = spell.get("id", "")
					if spell_id != "":
						_spells[spell_id] = spell
						count += 1
		file_name = dir.get_next()
	if count > 0:
		print("[SpellSystem] Loaded %d spells" % count)
	return count

func register_spell(spell_id: String, spell_data: Dictionary) -> void:
	_spells[spell_id] = spell_data

func get_spell(spell_id: String) -> Dictionary:
	return _spells.get(spell_id, {})

func has_spell(spell_id: String) -> bool:
	return _spells.has(spell_id)

# === 施放 Spell（统一生命周期：PREPARE → START → EXECUTE → EFFECT → FINISH）===
#
# 对标 TrinityCore Spell 生命周期:
#   Spell::prepare()  → 条件/消耗/冷却检查
#   Spell::cast()     → 状态设置 + 开始事件
#   Spell::handle_immediate() / handle_delayed() → 执行效果
#   Spell::finish()   → 清状态 + 完成事件
#
# 所有技能类型（瞬发/读条/引导）共享同一流程，顺序由框架保证。

func cast(spell_id: String, caster: Node3D, explicit_target: Node3D = null, overrides: Dictionary = {}) -> bool:
	var spell: Dictionary = _spells.get(spell_id, {})
	if spell.is_empty():
		DebugOverlay.log_error("SpellSystem", "Spell '%s' not found" % spell_id)
		return false

	var merged: Dictionary = spell.duplicate(true)
	merged.merge(overrides, true)

	# === PREPARE 阶段 ===
	# Hook: CHECK_CAST（对标 TC SpellScript::CheckCast）
	var script_sys: Node = EngineAPI.get_system("spell_script")
	if script_sys and script_sys.has_spell_hook(spell_id, "check_cast"):
		var can_cast: Variant = script_sys.fire_spell_hook(spell_id, "check_cast", [caster, merged])
		if can_cast == false:
			return false
	if caster is GameEntity and not TargetUtil.can_cast(caster as GameEntity):
		return false
	var cd_key := "spell_cd_%s_%d" % [spell_id, caster.get_instance_id()]
	if float(EngineAPI.get_variable(cd_key, 0.0)) > 0:
		return false
	var cooldown: float = merged.get("cooldown", 0.0)
	if cooldown > 0:
		EngineAPI.set_variable(cd_key, cooldown)

	var cast_time: float = merged.get("cast_time", 0.0)
	var channel_time: float = merged.get("channel_time", 0.0)

	# === START 阶段（根据类型分流）===
	if cast_time > 0 and caster is GameEntity:
		# 读条：通知 → 设 flag → 进入等待
		var cid: int = caster.get_instance_id()
		_casting_entities[cid] = {
			"caster": caster, "spell": merged, "target": explicit_target,
			"timer": cast_time, "interruptible": merged.get("interruptible", true),
		}
		_trigger_cast_animation(caster)
		EventBus.emit_event("spell_cast_start", {
			"caster": caster, "target": explicit_target,
			"spell_id": spell_id, "cast_time": cast_time,
		})
		(caster as GameEntity).set_unit_flag(UnitFlags.CASTING)
		return true

	if channel_time > 0 and caster is GameEntity:
		# 引导：通知 → 设 flag → 进入周期 tick
		var cid: int = caster.get_instance_id()
		_channeling_entities[cid] = {
			"caster": caster, "spell": merged, "target": explicit_target,
			"remaining": channel_time, "period": merged.get("channel_period", 1.0),
			"tick_timer": 0.0,
		}
		EventBus.emit_event("spell_channel_start", {
			"caster": caster, "target": explicit_target,
			"spell_id": spell_id, "channel_time": channel_time,
		})
		(caster as GameEntity).set_unit_flag(UnitFlags.CHANNELING)
		return true

	# 瞬发：直接走完整 FINISH 流程
	_spell_finish(caster, explicit_target, merged)
	return true

func _trigger_cast_animation(caster: Node3D) -> void:
	## 触发施法者的施法动画
	if caster and is_instance_valid(caster) and caster.has_method("get_component"):
		var vis: Node = caster.get_component("visual")
		if vis and vis.has_method("play_spell"):
			vis.play_spell()

func _spell_finish(caster: Node3D, target: Node3D, spell: Dictionary) -> void:
	## 统一的 FINISH 阶段（对标 TC Spell::SendSpellGo → handle_immediate）
	if target != null and not is_instance_valid(target):
		return
	var spell_id: String = spell.get("id", "")
	# Hook: ON_CAST
	var script_sys: Node = EngineAPI.get_system("spell_script")
	if script_sys:
		script_sys.fire_spell_hook(spell_id, "on_cast", [caster, target, spell])
	_trigger_cast_animation(caster)
	EventBus.emit_event("spell_cast", {
		"spell_id": spell_id, "caster": caster, "target": target,
	})
	_execute_spell_effects(caster, target, spell)
	# Hook: AFTER_CAST
	if script_sys:
		script_sys.fire_spell_hook(spell_id, "after_cast", [caster, target, spell])

# === 冷却计时 ===

func _execute_spell_effects(caster: Node3D, target: Node3D, spell: Dictionary) -> void:
	## 执行 spell 的所有 effects（瞬发/读条完成/引导 tick 共用）
	if target != null and not is_instance_valid(target):
		return
	var effects: Array = spell.get("effects", [])
	for effect in effects:
		if not effect is Dictionary:
			continue
		# 目标可能在前一个 effect 中被杀
		if target != null and not is_instance_valid(target):
			break
		if not _check_condition(caster, target, effect):
			continue
		_execute_effect(caster, target, effect, spell)

func _complete_cast(caster_id: int) -> void:
	## 读条完成：清 flag → 走统一 FINISH
	var data: Dictionary = _casting_entities.get(caster_id, {})
	var caster = data.get("caster")
	if caster is GameEntity:
		(caster as GameEntity).clear_unit_flag(UnitFlags.CASTING)
	var target = data.get("target")
	_spell_finish(caster, target if is_instance_valid(target) else null, data.get("spell", {}))
	_casting_entities.erase(caster_id)

func _interrupt_cast(caster_id: int) -> void:
	## 读条被打断
	var data: Dictionary = _casting_entities.get(caster_id, {})
	var caster = data.get("caster")
	if caster is GameEntity:
		(caster as GameEntity).clear_unit_flag(UnitFlags.CASTING)
	EventBus.emit_event("spell_interrupted", {"caster": caster, "spell_id": data.get("spell", {}).get("id", "")})
	_casting_entities.erase(caster_id)

func _finish_channel(caster_id: int) -> void:
	## 引导结束：最终 tick（flag 还在）→ 清 flag → 通知完成
	var data: Dictionary = _channeling_entities.get(caster_id, {})
	var caster = data.get("caster")
	var target = data.get("target")
	var spell: Dictionary = data.get("spell", {})
	# 1. 最终 tick（CHANNELING flag 还在，确保引导状态下执行）
	if target != null and is_instance_valid(target):
		_execute_spell_effects(caster, target, spell)
	# 2. 清 flag
	if caster is GameEntity:
		(caster as GameEntity).clear_unit_flag(UnitFlags.CHANNELING)
	# 3. 通知完成
	EventBus.emit_event("spell_cast", {"spell_id": spell.get("id", ""), "caster": caster, "target": target})
	_channeling_entities.erase(caster_id)

func _on_caster_damaged(data: Dictionary) -> void:
	## 施法者受伤 → 检查是否打断读条
	var entity = data.get("entity")
	if entity == null or not is_instance_valid(entity):
		return
	var eid: int = entity.get_instance_id()
	if _casting_entities.has(eid):
		if _casting_entities[eid].get("interruptible", true):
			_interrupt_cast(eid)

func _process(delta: float) -> void:
	# === 读条计时 ===
	var cast_remove: Array = []
	for cid in _casting_entities:
		var cd: Dictionary = _casting_entities[cid]
		var caster = cd.get("caster")
		if not is_instance_valid(caster):
			cast_remove.append(cid)
			continue
		cd["timer"] -= delta
		if cd["timer"] <= 0:
			_complete_cast(cid)
			cast_remove.append(cid)  # 已在 _complete_cast 中 erase，但安全起见
		elif caster is GameEntity and (caster as GameEntity).has_any_flag(UnitFlags.CAST_PREVENTING):
			_interrupt_cast(cid)
			cast_remove.append(cid)

	# === 引导计时 ===
	var ch_remove: Array = []
	for cid in _channeling_entities:
		var ch: Dictionary = _channeling_entities[cid]
		var caster = ch.get("caster")
		if not is_instance_valid(caster):
			ch_remove.append(cid)
			continue
		# CC 打断引导
		if caster is GameEntity and (caster as GameEntity).has_any_flag(UnitFlags.CAST_PREVENTING):
			if caster is GameEntity:
				(caster as GameEntity).clear_unit_flag(UnitFlags.CHANNELING)
			EventBus.emit_event("spell_interrupted", {"caster": caster, "spell_id": ch.get("spell", {}).get("id", "")})
			ch_remove.append(cid)
			continue
		var ch_target = ch.get("target")
		# 目标已死/已freed → 中断引导
		if ch_target != null and not is_instance_valid(ch_target):
			if caster is GameEntity:
				(caster as GameEntity).clear_unit_flag(UnitFlags.CHANNELING)
			ch_remove.append(cid)
			continue
		ch["remaining"] -= delta
		if ch["remaining"] <= 0:
			_finish_channel(cid)
			ch_remove.append(cid)
			continue
		ch["tick_timer"] += delta
		if ch["tick_timer"] >= ch["period"]:
			ch["tick_timer"] -= ch["period"]
			# 再次检查 target（可能在同帧被释放）
			if ch_target != null and not is_instance_valid(ch_target):
				if caster is GameEntity:
					(caster as GameEntity).clear_unit_flag(UnitFlags.CHANNELING)
				ch_remove.append(cid)
				continue
			_execute_spell_effects(caster, ch_target if is_instance_valid(ch_target) else null, ch.get("spell", {}))
			EventBus.emit_event("spell_channel_tick", {
				"caster": caster, "target": ch_target,
				"spell_id": ch.get("spell", {}).get("id", ""),
			})

	# 清理（防止迭代中删除）
	for cid in cast_remove:
		_casting_entities.erase(cid)
	for cid in ch_remove:
		_channeling_entities.erase(cid)

	# === 冷却计时 ===
	var keys_to_remove: Array = []
	for key in EngineAPI._variables:
		if str(key).begins_with("spell_cd_"):
			var val: float = float(EngineAPI._variables[key])
			if val > 0:
				EngineAPI._variables[key] = val - delta
				if val - delta <= 0:
					keys_to_remove.append(key)
	for key in keys_to_remove:
		EngineAPI._variables.erase(key)

# === 条件系统 ===

func _check_condition(caster: Node3D, target: Node3D, effect: Dictionary) -> bool:
	var condition: Dictionary = effect.get("condition", {})
	if condition.is_empty():
		return true

	var cond_type: String = condition.get("type", "")
	var cond_target_str: String = condition.get("target", "caster")
	var cond_node: Node3D = caster if cond_target_str == "caster" else target
	if cond_node == null or not is_instance_valid(cond_node):
		return false

	var value: float = condition.get("value", 0.0)

	match cond_type:
		"hp_below":
			var health: Node = EngineAPI.get_component(cond_node, "health")
			if health:
				return health.get_hp_ratio() < value
			return false
		"hp_above":
			var health: Node = EngineAPI.get_component(cond_node, "health")
			if health:
				return health.get_hp_ratio() > value
			return false
		"has_aura":
			var aura_id: String = condition.get("aura_id", "")
			var aura_mgr: Node = EngineAPI.get_system("aura")
			if aura_mgr:
				return aura_mgr.call("has_aura", cond_node, aura_id)
			return false
		"not_has_aura":
			var aura_id: String = condition.get("aura_id", "")
			var aura_mgr: Node = EngineAPI.get_system("aura")
			if aura_mgr:
				return not aura_mgr.call("has_aura", cond_node, aura_id)
			return true
		"has_tag":
			if cond_node.has_method("has_tag"):
				return cond_node.has_tag(condition.get("tag", ""))
			return false
		"variable_check":
			var var_key: String = condition.get("key", "")
			var op: String = condition.get("op", ">=")
			var current: float = float(EngineAPI.get_variable(var_key, 0.0))
			return _compare(current, op, value)
		"resource_check":
			var res_name: String = condition.get("resource", "")
			var op: String = condition.get("op", ">=")
			var current: float = EngineAPI.get_resource(res_name)
			return _compare(current, op, value)
		_:
			return true

func _compare(a: float, op: String, b: float) -> bool:
	match op:
		"==": return is_equal_approx(a, b)
		"!=": return not is_equal_approx(a, b)
		">": return a > b
		">=": return a >= b
		"<": return a < b
		"<=": return a <= b
	return false

# === 数值计算引擎 ===

func calculate_value(caster: Node3D, effect: Dictionary, spell: Dictionary) -> float:
	## 计算 Effect 的最终数值
	## base_points + per_level * level + scaling.stat * scaling.coefficient
	var base: float = effect.get("base_points", 0.0)
	var per_level: float = effect.get("per_level", 0.0)

	# 等级加成
	if per_level != 0 and caster is GameEntity:
		var level: float = float(EngineAPI.get_variable("hero_level", 1))
		base += per_level * (level - 1)

	# 属性 scaling
	var scaling: Dictionary = effect.get("scaling", {})
	if not scaling.is_empty():
		var stat_name: String = scaling.get("stat", "")
		var coefficient: float = scaling.get("coefficient", 0.0)
		if stat_name != "" and coefficient != 0 and caster is GameEntity:
			base += EngineAPI.get_total_stat(caster, stat_name) * coefficient

		# 百分比引用（如 max_hp 的 10%）
		var pct_stat: String = scaling.get("pct_of_stat", "")
		var pct: float = scaling.get("pct", 0.0)
		if pct_stat != "" and pct != 0:
			if pct_stat == "max_hp":
				var health: Node = EngineAPI.get_component(caster, "health")
				if health:
					base += health.max_hp * pct
			elif pct_stat == "current_hp":
				var health: Node = EngineAPI.get_component(caster, "health")
				if health:
					base += health.current_hp * pct
			else:
				base += EngineAPI.get_stat(caster, pct_stat) * pct

	# school 掩码加成
	var _school_mask: Array = spell.get("school_mask", [spell.get("school", "physical")])

	return base

# === Effect 执行 ===

func _execute_effect(caster: Node3D, explicit_target: Node3D, effect: Dictionary, spell: Dictionary) -> void:
	var effect_type: String = effect.get("type", "")
	if effect_type == "":
		return

	var targets: Array[Node3D] = _resolve_targets(caster, explicit_target, effect)

	if _effect_handlers.has(effect_type):
		var handler: Callable = _effect_handlers[effect_type]
		var spell_id: String = spell.get("id", "")
		var script_sys: Node = EngineAPI.get_system("spell_script")
		# CHAIN 类型：画链式 VFX（prev → current → next...）
		var is_chain: bool = effect.get("target", {}).get("category", "") == "CHAIN"
		var prev_pos: Vector3 = caster.global_position if is_instance_valid(caster) else Vector3.ZERO
		for target in targets:
			if is_instance_valid(target):
				# Hook: ON_EFFECT（对标 TC EffectHandler）
				if script_sys:
					script_sys.fire_spell_hook(spell_id, "on_effect", [caster, target, effect, spell])
				handler.call(caster, target, effect, spell)
				if is_chain:
					var vfx: Node = EngineAPI.get_system("vfx")
					if vfx:
						vfx.call("spawn_vfx", "lightning", prev_pos, {
							"target_pos": target.global_position
						})
					prev_pos = target.global_position
	else:
		DebugOverlay.log_warning("SpellSystem", "Unknown effect type: %s" % effect_type)

# === 目标解析 ===

func _resolve_targets(caster: Node3D, explicit_target: Node3D, effect: Dictionary) -> Array[Node3D]:
	var target_data: Dictionary = effect.get("target", {})
	var category: String = target_data.get("category", "DEFAULT")
	var check: String = target_data.get("check", "ENEMY")
	var reference: String = target_data.get("reference", "CASTER")
	var radius: float = target_data.get("radius", 0.0)
	var max_targets: int = mini(target_data.get("max_targets", 0), 10)  # 框架硬上限 10
	var chain_targets: int = mini(target_data.get("chain_targets", 0), 5)  # 链式硬上限 5
	var cone_angle: float = target_data.get("cone_angle", 0.0)

	var ref_node: Node3D = caster if reference == "CASTER" else explicit_target
	if ref_node == null or not is_instance_valid(ref_node):
		ref_node = caster
	var ref_pos: Vector3 = ref_node.global_position if ref_node else Vector3.ZERO

	var result: Array[Node3D] = []
	# 优先使用 faction 感知的查询
	var use_faction := check in ["ENEMY", "ALLY", "FRIENDLY"] and caster is GameEntity

	match category:
		"DEFAULT":
			if explicit_target and is_instance_valid(explicit_target):
				# 校验目标阵营：ENEMY check 不能打到友方
				if use_faction and caster is GameEntity and explicit_target is GameEntity:
					var caster_ge := caster as GameEntity
					var target_ge := explicit_target as GameEntity
					if check == "ENEMY" and not caster_ge.is_hostile_to(target_ge):
						pass  # 不加入：目标与施法者同阵营
					elif check in ["ALLY", "FRIENDLY"] and not caster_ge.is_friendly_to(target_ge):
						pass  # 不加入：目标与施法者不同阵营
					else:
						result.append(explicit_target)
				else:
					result.append(explicit_target)
		"SELF":
			if caster and is_instance_valid(caster):
				result.append(caster)
		"AREA":
			if radius > 0:
				var found: Array = _find_targets_by_check(caster, ref_pos, radius, check, use_faction)
				for e in found:
					result.append(e as Node3D)
		"NEAREST":
			if radius > 0:
				var found: Array = _find_targets_by_check(caster, ref_pos, radius, check, use_faction)
				if not found.is_empty():
					var closest: Node3D = null
					var closest_dist := INF
					for e in found:
						var d: float = ref_pos.distance_squared_to(e.global_position)
						if d < closest_dist:
							closest_dist = d
							closest = e
					if closest:
						result.append(closest)
		"CHAIN":
			if explicit_target and is_instance_valid(explicit_target):
				result.append(explicit_target)
				var chain_range: float = target_data.get("chain_range", 150.0)
				var _decay: float = target_data.get("chain_amplitude", 1.0)
				var current: Node3D = explicit_target
				var hit: Array[Node3D] = [explicit_target]
				for _i in range(chain_targets):
					var found: Array = _find_targets_by_check(caster, current.global_position, chain_range, check, use_faction)
					var next: Node3D = null
					var next_dist := INF
					for e in found:
						if e in hit:
							continue
						var d: float = current.global_position.distance_squared_to(e.global_position)
						if d < next_dist:
							next_dist = d
							next = e
					if next:
						result.append(next)
						hit.append(next)
						current = next
					else:
						break
		"CONE":
			if cone_angle > 0 and radius > 0:
				var found: Array = _find_targets_by_check(caster, ref_pos, radius, check, use_faction)
				var facing: Vector3 = Vector3.RIGHT
				if explicit_target and is_instance_valid(explicit_target):
					facing = ref_pos.direction_to(explicit_target.global_position)
				var half_angle := deg_to_rad(cone_angle * 0.5)
				for e in found:
					var dir: Vector3 = ref_pos.direction_to(e.global_position)
					if abs(facing.angle_to(dir)) <= half_angle:
						result.append(e as Node3D)

	if max_targets > 0 and result.size() > max_targets:
		result.resize(max_targets)
	return result

func _find_targets_by_check(caster: Node3D, center: Vector3, radius: float, check: String, use_faction: bool) -> Array:
	if use_faction and caster is GameEntity:
		match check:
			"ENEMY":
				return EngineAPI.find_hostiles_in_area(caster, center, radius)
			"ALLY", "FRIENDLY":
				return EngineAPI.find_allies_in_area(caster, center, radius)
	# 回退到 tag 过滤
	return EngineAPI.find_entities_in_area(center, radius, _check_to_tag(check))

func _check_to_tag(check: String) -> String:
	match check:
		"ENEMY": return "enemy"
		"ALLY", "FRIENDLY": return "friendly"
		"PLAYER": return "player"
		_: return ""

# === 内置 Effect Handlers ===

func _register_builtin_effects() -> void:
	register_effect_handler("SCHOOL_DAMAGE", _effect_school_damage)
	register_effect_handler("HEAL", _effect_heal)
	register_effect_handler("APPLY_AURA", _effect_apply_aura)
	register_effect_handler("TRIGGER_SPELL", _effect_trigger_spell)
	register_effect_handler("SUMMON", _effect_summon)
	register_effect_handler("KNOCK_BACK", _effect_knock_back)
	register_effect_handler("ADD_RESOURCE", _effect_add_resource)
	register_effect_handler("MODIFY_SPEED", _effect_modify_speed)
	register_effect_handler("DISPEL", _effect_dispel)
	register_effect_handler("SET_VARIABLE", _effect_set_variable)
	register_effect_handler("TELEPORT", _effect_teleport)
	register_effect_handler("CREATE_ITEM", _effect_create_item)
	register_effect_handler("RESET_COOLDOWN", _effect_reset_cooldown)

func register_effect_handler(effect_type: String, handler: Callable) -> void:
	_effect_handlers[effect_type] = handler

# --- SCHOOL_DAMAGE ---
func _effect_school_damage(caster: Node3D, target: Node3D, effect: Dictionary, spell: Dictionary) -> void:
	var total: float = calculate_value(caster, effect, spell)
	var school: String = spell.get("school", "physical")
	var health: Node = EngineAPI.get_component(target, "health")
	if health and health.has_method("take_damage"):
		var spell_name: String = spell.get("id", "")
		var is_proc: bool = spell.get("_is_proc", false)
		health.take_damage(total, caster, health.parse_damage_type(school), spell_name, is_proc)
	# CHAIN VFX 由 _execute_effect 统一处理（见下方）

# --- HEAL ---
func _effect_heal(caster: Node3D, target: Node3D, effect: Dictionary, spell: Dictionary) -> void:
	var total: float = calculate_value(caster, effect, spell)
	var health: Node = EngineAPI.get_component(target, "health")
	if health and health.has_method("heal"):
		health.heal(total, caster)

# --- APPLY_AURA ---
func _effect_apply_aura(caster: Node3D, target: Node3D, effect: Dictionary, spell: Dictionary) -> void:
	var aura_manager: Node = EngineAPI.get_system("aura")
	if aura_manager == null:
		DebugOverlay.log_error("SpellSystem", "AuraManager not registered")
		return
	# 用计算引擎得到 base_points
	var calc_effect: Dictionary = effect.duplicate()
	calc_effect["base_points"] = calculate_value(caster, effect, spell)
	var duration: float = calc_effect.get("duration", spell.get("duration", 0.0))
	aura_manager.call("apply_aura", caster, target, calc_effect, spell, duration)

# --- TRIGGER_SPELL ---
func _effect_trigger_spell(caster: Node3D, target: Node3D, effect: Dictionary, _spell: Dictionary) -> void:
	var trigger_id: String = effect.get("trigger_spell", "")
	if trigger_id != "":
		cast(trigger_id, caster, target)

# --- SUMMON ---
func _effect_summon(caster: Node3D, _target: Node3D, effect: Dictionary, _spell: Dictionary) -> void:
	var entity_id: String = effect.get("entity_id", "")
	var offset: Dictionary = effect.get("offset", {})
	var pos := caster.global_position + Vector3(float(offset.get("x", 0)), 0, float(offset.get("y", 0)))
	if entity_id != "":
		EngineAPI.spawn_entity(entity_id, pos)

# --- KNOCK_BACK ---
func _effect_knock_back(caster: Node3D, target: Node3D, effect: Dictionary, spell: Dictionary) -> void:
	var force: float = calculate_value(caster, effect, spell)
	var movement: Node = EngineAPI.get_component(target, "movement")
	if movement:
		var dir: Vector3 = caster.global_position.direction_to(target.global_position)
		movement.velocity = dir * force

# --- ADD_RESOURCE ---
func _effect_add_resource(caster: Node3D, _target: Node3D, effect: Dictionary, spell: Dictionary) -> void:
	var res_name: String = effect.get("resource", "")
	var amount: float = calculate_value(caster, effect, spell)
	if res_name != "":
		EngineAPI.add_resource(res_name, amount)
		# 通知 GamePack 显示飘字（对标 TC 战利品通知）
		EventBus.emit_event("resource_gained_by_spell", {
			"resource": res_name, "amount": amount,
			"caster": caster, "spell_id": spell.get("id", ""),
		})

# --- MODIFY_SPEED ---
func _effect_modify_speed(_caster: Node3D, target: Node3D, effect: Dictionary, _spell: Dictionary) -> void:
	var factor: float = effect.get("base_points", 1.0)
	var duration: float = effect.get("duration", 2.0)
	var movement: Node = EngineAPI.get_component(target, "movement")
	if movement and movement.has_method("add_speed_modifier"):
		var mod_id := "spell_speed_%d" % target.get_instance_id()
		movement.remove_speed_modifier(mod_id)
		movement.add_speed_modifier(mod_id, factor)
		if duration > 0:
			get_tree().create_timer(duration).timeout.connect(func() -> void:
				if is_instance_valid(target) and movement:
					movement.remove_speed_modifier(mod_id)
			)

# --- DISPEL (驱散 aura) ---
func _effect_dispel(_caster: Node3D, target: Node3D, effect: Dictionary, _spell: Dictionary) -> void:
	var aura_id: String = effect.get("aura_id", "")
	var aura_mgr: Node = EngineAPI.get_system("aura")
	if aura_mgr and aura_id != "":
		aura_mgr.call("remove_aura", target, aura_id)

# --- SET_VARIABLE ---
func _effect_create_item(caster: Node3D, _target: Node3D, effect: Dictionary, _spell: Dictionary) -> void:
	## 对标 TC SPELL_EFFECT_CREATE_ITEM — 在背包创建物品
	var item_id: int = int(effect.get("item_id", effect.get("base_points", 0)))
	var count: int = int(effect.get("count", 1))
	if item_id > 0:
		EventBus.emit_event("item_created", {
			"item_id": item_id, "count": count, "target": caster
		})

func _effect_teleport(caster: Node3D, _target: Node3D, effect: Dictionary, _spell: Dictionary) -> void:
	## 对标 TC SPELL_EFFECT_TELEPORT_UNITS
	if caster == null or not is_instance_valid(caster):
		return
	var distance: float = effect.get("base_points", 5.0)
	# 传送到鼠标位置或前方指定距离
	var camera: Node = EngineAPI.get_system("camera")
	if camera and camera.has_method("get_world_mouse_position"):
		var target_pos: Vector3 = camera.get_world_mouse_position()
		var dir: Vector3 = target_pos - caster.global_position
		dir.y = 0
		if dir.length() > distance:
			dir = dir.normalized() * distance
		caster.global_position += dir
	else:
		# 无相机时向前传送
		var forward: Vector3 = -caster.global_transform.basis.z.normalized()
		caster.global_position += forward * distance

func _effect_set_variable(caster: Node3D, _target: Node3D, effect: Dictionary, spell: Dictionary) -> void:
	var var_key: String = effect.get("key", "")
	var value: float = calculate_value(caster, effect, spell)
	var mode: String = effect.get("mode", "set")  # set, add, max
	if var_key == "":
		return
	match mode:
		"set":
			EngineAPI.set_variable(var_key, value)
		"add":
			var current: float = float(EngineAPI.get_variable(var_key, 0.0))
			EngineAPI.set_variable(var_key, current + value)
		"max":
			var current: float = float(EngineAPI.get_variable(var_key, 0.0))
			EngineAPI.set_variable(var_key, maxf(current, value))

# --- RESET_COOLDOWN ---
func _effect_reset_cooldown(caster: Node3D, _target: Node3D, effect: Dictionary, _spell: Dictionary) -> void:
	## 对标 TC SPELL_EFFECT_CLEAR_QUEST - repurposed for cooldown reset
	var target_spell: String = effect.get("target_spell", "")
	if target_spell != "" and caster:
		var cd_key := "spell_cd_%s_%d" % [target_spell, caster.get_instance_id()]
		EngineAPI.set_variable(cd_key, 0.0)

# === Toggle Spell（对标 TC toggle abilities, e.g., Aspect of the Hawk）===

func toggle(spell_id: String, caster: Node3D) -> bool:
	## Toggle spell on/off. If aura exists, remove it. If not, cast.
	var aura_mgr: Node = EngineAPI.get_system("aura")
	if aura_mgr == null:
		return false
	# Check if caster already has an aura from this spell
	var auras: Array = aura_mgr.get_auras_on(caster)
	for aura in auras:
		if str(aura.get("spell_id", "")).begins_with(spell_id):
			# Already active - remove it
			aura_mgr.remove_aura(caster, aura.get("aura_id", ""))
			EventBus.emit_event("spell_toggled", {"spell_id": spell_id, "caster": caster, "active": false})
			return true
	# Not active - cast it
	cast(spell_id, caster)
	EventBus.emit_event("spell_toggled", {"spell_id": spell_id, "caster": caster, "active": true})
	return true

func is_spell_active(spell_id: String, entity: Node3D) -> bool:
	var aura_mgr: Node = EngineAPI.get_system("aura")
	if aura_mgr == null:
		return false
	var auras: Array = aura_mgr.get_auras_on(entity)
	for aura in auras:
		if str(aura.get("spell_id", "")).begins_with(spell_id):
			return true
	return false
