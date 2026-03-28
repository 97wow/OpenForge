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

func _ready() -> void:
	EngineAPI.register_system("spell", self)
	_register_builtin_effects()

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

# === 施放 Spell ===

func cast(spell_id: String, caster: Node2D, explicit_target: Node2D = null, overrides: Dictionary = {}) -> bool:
	var spell: Dictionary = _spells.get(spell_id, {})
	if spell.is_empty():
		DebugOverlay.log_error("SpellSystem", "Spell '%s' not found" % spell_id)
		return false

	var merged: Dictionary = spell.duplicate(true)
	merged.merge(overrides, true)

	# 冷却检查
	var cd_key := "spell_cd_%s_%d" % [spell_id, caster.get_instance_id()]
	if float(EngineAPI.get_variable(cd_key, 0.0)) > 0:
		return false

	# 设置冷却
	var cooldown: float = merged.get("cooldown", 0.0)
	if cooldown > 0:
		EngineAPI.set_variable(cd_key, cooldown)

	# 逐个执行 Effect
	var effects: Array = merged.get("effects", [])
	for effect in effects:
		if not effect is Dictionary:
			continue
		# 条件检查
		if not _check_condition(caster, explicit_target, effect):
			continue
		_execute_effect(caster, explicit_target, effect, merged)

	EventBus.emit_event("spell_cast", {
		"spell_id": spell_id, "caster": caster, "target": explicit_target,
	})
	return true

# === 冷却计时 ===

func _process(delta: float) -> void:
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

func _check_condition(caster: Node2D, target: Node2D, effect: Dictionary) -> bool:
	var condition: Dictionary = effect.get("condition", {})
	if condition.is_empty():
		return true

	var cond_type: String = condition.get("type", "")
	var cond_target_str: String = condition.get("target", "caster")
	var cond_node: Node2D = caster if cond_target_str == "caster" else target
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

func calculate_value(caster: Node2D, effect: Dictionary, spell: Dictionary) -> float:
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
			base += EngineAPI.get_stat(caster, stat_name) * coefficient

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

func _execute_effect(caster: Node2D, explicit_target: Node2D, effect: Dictionary, spell: Dictionary) -> void:
	var effect_type: String = effect.get("type", "")
	if effect_type == "":
		return

	var targets: Array[Node2D] = _resolve_targets(caster, explicit_target, effect)

	if _effect_handlers.has(effect_type):
		var handler: Callable = _effect_handlers[effect_type]
		for target in targets:
			if is_instance_valid(target):
				handler.call(caster, target, effect, spell)
	else:
		DebugOverlay.log_warning("SpellSystem", "Unknown effect type: %s" % effect_type)

# === 目标解析 ===

func _resolve_targets(caster: Node2D, explicit_target: Node2D, effect: Dictionary) -> Array[Node2D]:
	var target_data: Dictionary = effect.get("target", {})
	var category: String = target_data.get("category", "DEFAULT")
	var check: String = target_data.get("check", "ENEMY")
	var reference: String = target_data.get("reference", "CASTER")
	var radius: float = target_data.get("radius", 0.0)
	var max_targets: int = target_data.get("max_targets", 0)
	var chain_targets: int = target_data.get("chain_targets", 0)
	var cone_angle: float = target_data.get("cone_angle", 0.0)

	var ref_node: Node2D = caster if reference == "CASTER" else explicit_target
	if ref_node == null or not is_instance_valid(ref_node):
		ref_node = caster
	var ref_pos: Vector2 = ref_node.global_position if ref_node else Vector2.ZERO

	var filter_tag := _check_to_tag(check)
	var result: Array[Node2D] = []

	match category:
		"DEFAULT":
			if explicit_target and is_instance_valid(explicit_target):
				result.append(explicit_target)
		"SELF":
			if caster and is_instance_valid(caster):
				result.append(caster)
		"AREA":
			if radius > 0:
				var found: Array = EngineAPI.find_entities_in_area(ref_pos, radius, filter_tag)
				for e in found:
					result.append(e as Node2D)
		"NEAREST":
			if radius > 0:
				var found: Array = EngineAPI.find_entities_in_area(ref_pos, radius, filter_tag)
				if not found.is_empty():
					var closest: Node2D = null
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
				var decay: float = target_data.get("chain_amplitude", 1.0)
				var current: Node2D = explicit_target
				var hit: Array[Node2D] = [explicit_target]
				for _i in range(chain_targets):
					var found: Array = EngineAPI.find_entities_in_area(current.global_position, chain_range, filter_tag)
					var next: Node2D = null
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
				var found: Array = EngineAPI.find_entities_in_area(ref_pos, radius, filter_tag)
				var facing: Vector2 = Vector2.RIGHT
				if explicit_target and is_instance_valid(explicit_target):
					facing = ref_pos.direction_to(explicit_target.global_position)
				var half_angle := deg_to_rad(cone_angle * 0.5)
				for e in found:
					var dir: Vector2 = ref_pos.direction_to(e.global_position)
					if abs(facing.angle_to(dir)) <= half_angle:
						result.append(e as Node2D)

	if max_targets > 0 and result.size() > max_targets:
		result.resize(max_targets)
	return result

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

func register_effect_handler(effect_type: String, handler: Callable) -> void:
	_effect_handlers[effect_type] = handler

# --- SCHOOL_DAMAGE ---
func _effect_school_damage(caster: Node2D, target: Node2D, effect: Dictionary, spell: Dictionary) -> void:
	var total: float = calculate_value(caster, effect, spell)
	var school: String = spell.get("school", "physical")
	var health: Node = EngineAPI.get_component(target, "health")
	if health and health.has_method("take_damage"):
		health.take_damage(total, caster, health.parse_damage_type(school))

# --- HEAL ---
func _effect_heal(caster: Node2D, target: Node2D, effect: Dictionary, spell: Dictionary) -> void:
	var total: float = calculate_value(caster, effect, spell)
	var health: Node = EngineAPI.get_component(target, "health")
	if health and health.has_method("heal"):
		health.heal(total, caster)

# --- APPLY_AURA ---
func _effect_apply_aura(caster: Node2D, target: Node2D, effect: Dictionary, spell: Dictionary) -> void:
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
func _effect_trigger_spell(caster: Node2D, target: Node2D, effect: Dictionary, _spell: Dictionary) -> void:
	var trigger_id: String = effect.get("trigger_spell", "")
	if trigger_id != "":
		cast(trigger_id, caster, target)

# --- SUMMON ---
func _effect_summon(caster: Node2D, _target: Node2D, effect: Dictionary, _spell: Dictionary) -> void:
	var entity_id: String = effect.get("entity_id", "")
	var offset: Dictionary = effect.get("offset", {})
	var pos := caster.global_position + Vector2(offset.get("x", 0), offset.get("y", 0))
	if entity_id != "":
		EngineAPI.spawn_entity(entity_id, pos)

# --- KNOCK_BACK ---
func _effect_knock_back(caster: Node2D, target: Node2D, effect: Dictionary, spell: Dictionary) -> void:
	var force: float = calculate_value(caster, effect, spell)
	var movement: Node = EngineAPI.get_component(target, "movement")
	if movement:
		var dir: Vector2 = caster.global_position.direction_to(target.global_position)
		movement.velocity = dir * force

# --- ADD_RESOURCE ---
func _effect_add_resource(caster: Node2D, _target: Node2D, effect: Dictionary, spell: Dictionary) -> void:
	var res_name: String = effect.get("resource", "")
	var amount: float = calculate_value(caster, effect, spell)
	if res_name != "":
		EngineAPI.add_resource(res_name, amount)

# --- MODIFY_SPEED ---
func _effect_modify_speed(_caster: Node2D, target: Node2D, effect: Dictionary, _spell: Dictionary) -> void:
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
func _effect_dispel(_caster: Node2D, target: Node2D, effect: Dictionary, _spell: Dictionary) -> void:
	var aura_id: String = effect.get("aura_id", "")
	var aura_mgr: Node = EngineAPI.get_system("aura")
	if aura_mgr and aura_id != "":
		aura_mgr.call("remove_aura", target, aura_id)

# --- SET_VARIABLE ---
func _effect_set_variable(caster: Node2D, _target: Node2D, effect: Dictionary, spell: Dictionary) -> void:
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
