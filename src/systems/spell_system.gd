## SpellSystem - 数据驱动技能引擎（框架层）
## 借鉴 TrinityCore Spell 框架：Spell = N × Effect，每个 Effect 通过 Handler 分发
## 用户只需写 JSON 定义 Spell，框架自动执行效果
## GamePack 可注册自定义 Effect Handler 扩展能力
class_name SpellSystem
extends Node

# === Effect Handler 注册表 ===
# effect_type(String) -> Callable(caster, target, effect_data, spell_data)
var _effect_handlers: Dictionary = {}

# === Spell 数据缓存 ===
# spell_id -> spell_data(Dictionary)
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
		print("[SpellSystem] Loaded %d spells from %s" % [count, dir_path])
	return count

func register_spell(spell_id: String, spell_data: Dictionary) -> void:
	_spells[spell_id] = spell_data

func get_spell(spell_id: String) -> Dictionary:
	return _spells.get(spell_id, {})

func has_spell(spell_id: String) -> bool:
	return _spells.has(spell_id)

# === 施放 Spell ===

func cast(spell_id: String, caster: Node2D, explicit_target: Node2D = null, overrides: Dictionary = {}) -> bool:
	## 施放技能：解析 Spell 定义，逐个执行 Effect
	var spell: Dictionary = _spells.get(spell_id, {})
	if spell.is_empty():
		DebugOverlay.log_error("SpellSystem", "Spell '%s' not found" % spell_id)
		return false

	# 合并运行时覆盖
	var merged: Dictionary = spell.duplicate(true)
	merged.merge(overrides, true)

	# 冷却检查
	var cd_key := "spell_cd_%s_%d" % [spell_id, caster.get_instance_id()]
	var cd_remaining: float = float(EngineAPI.get_variable(cd_key, 0.0))
	if cd_remaining > 0:
		return false

	# 设置冷却
	var cooldown: float = merged.get("cooldown", 0.0)
	if cooldown > 0:
		EngineAPI.set_variable(cd_key, cooldown)

	# 执行每个 Effect
	var effects: Array = merged.get("effects", [])
	for effect in effects:
		if not effect is Dictionary:
			continue
		_execute_effect(caster, explicit_target, effect, merged)

	EventBus.emit_event("spell_cast", {
		"spell_id": spell_id,
		"caster": caster,
		"target": explicit_target,
	})
	return true

# === 冷却计时 ===

func _process(delta: float) -> void:
	# 递减所有冷却
	var keys_to_check: Array = []
	for key in EngineAPI._variables:
		if str(key).begins_with("spell_cd_"):
			keys_to_check.append(key)
	for key in keys_to_check:
		var val: float = float(EngineAPI._variables[key])
		if val > 0:
			val -= delta
			if val <= 0:
				EngineAPI._variables.erase(key)
			else:
				EngineAPI._variables[key] = val

# === Effect 执行 ===

func _execute_effect(caster: Node2D, explicit_target: Node2D, effect: Dictionary, spell: Dictionary) -> void:
	var effect_type: String = effect.get("type", "")
	if effect_type == "":
		return

	# 目标解析
	var targets: Array[Node2D] = _resolve_targets(caster, explicit_target, effect)

	# Handler 分发
	if _effect_handlers.has(effect_type):
		var handler: Callable = _effect_handlers[effect_type]
		for target in targets:
			if is_instance_valid(target):
				handler.call(caster, target, effect, spell)
	else:
		DebugOverlay.log_warning("SpellSystem", "Unknown effect type: %s" % effect_type)

# === 目标解析（借鉴 WoW Targeting 组合式设计）===

func _resolve_targets(caster: Node2D, explicit_target: Node2D, effect: Dictionary) -> Array[Node2D]:
	var target_data: Dictionary = effect.get("target", {})
	var category: String = target_data.get("category", "DEFAULT")
	var check: String = target_data.get("check", "ENEMY")
	var reference: String = target_data.get("reference", "CASTER")
	var radius: float = target_data.get("radius", 0.0)
	var max_targets: int = target_data.get("max_targets", 0)
	var chain_targets: int = target_data.get("chain_targets", 0)

	# 确定参考点
	var ref_pos := Vector2.ZERO
	var ref_node: Node2D = caster
	match reference:
		"CASTER":
			ref_node = caster
		"TARGET":
			ref_node = explicit_target
	if ref_node and is_instance_valid(ref_node):
		ref_pos = ref_node.global_position

	# 确定 tag 过滤
	var filter_tag := ""
	match check:
		"ENEMY":
			filter_tag = "enemy"
		"ALLY", "FRIENDLY":
			filter_tag = "friendly"
		"PLAYER":
			filter_tag = "player"
		"ALL":
			filter_tag = ""

	var result: Array[Node2D] = []

	match category:
		"DEFAULT":
			# 显式目标
			if explicit_target and is_instance_valid(explicit_target):
				result.append(explicit_target)
		"SELF":
			result.append(caster)
		"AREA":
			# 半径内所有目标
			if radius > 0:
				var found: Array = EngineAPI.find_entities_in_area(ref_pos, radius, filter_tag)
				for e in found:
					result.append(e as Node2D)
		"NEAREST":
			# 最近的目标
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
			# 链式目标
			if explicit_target and is_instance_valid(explicit_target):
				result.append(explicit_target)
				var chain_range: float = target_data.get("chain_range", 150.0)
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

	# 限制最大目标数
	if max_targets > 0 and result.size() > max_targets:
		result.resize(max_targets)

	return result

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

func register_effect_handler(effect_type: String, handler: Callable) -> void:
	_effect_handlers[effect_type] = handler

# --- 具体 Handler ---

func _effect_school_damage(caster: Node2D, target: Node2D, effect: Dictionary, spell: Dictionary) -> void:
	var base_points: float = effect.get("base_points", 0.0)
	var school: String = spell.get("school", "physical")
	var scaling: Dictionary = effect.get("scaling", {})
	var coefficient: float = scaling.get("coefficient", 0.0)

	# 属性加成（如果 caster 有 StatSystem 数据）
	var bonus: float = 0.0
	if coefficient > 0 and caster is GameEntity:
		bonus = EngineAPI.get_stat(caster, "spell_power") * coefficient

	var total_damage := base_points + bonus
	var health: Node = EngineAPI.get_component(target, "health")
	if health and health.has_method("take_damage"):
		var dt: int = health.parse_damage_type(school)
		health.take_damage(total_damage, caster, dt)

func _effect_heal(caster: Node2D, target: Node2D, effect: Dictionary, _spell: Dictionary) -> void:
	var base_points: float = effect.get("base_points", 0.0)
	var health: Node = EngineAPI.get_component(target, "health")
	if health and health.has_method("heal"):
		health.heal(base_points, caster)

func _effect_apply_aura(caster: Node2D, target: Node2D, effect: Dictionary, spell: Dictionary) -> void:
	var aura_manager: Node = EngineAPI.get_system("aura")
	if aura_manager == null:
		DebugOverlay.log_error("SpellSystem", "AuraManager not registered")
		return
	var duration: float = effect.get("duration", spell.get("duration", 0.0))
	aura_manager.call("apply_aura", caster, target, effect, spell, duration)

func _effect_trigger_spell(caster: Node2D, target: Node2D, effect: Dictionary, _spell: Dictionary) -> void:
	var trigger_id: String = effect.get("trigger_spell", "")
	if trigger_id != "":
		cast(trigger_id, caster, target)

func _effect_summon(caster: Node2D, _target: Node2D, effect: Dictionary, _spell: Dictionary) -> void:
	var entity_id: String = effect.get("entity_id", "")
	var offset: Dictionary = effect.get("offset", {})
	var pos := caster.global_position + Vector2(offset.get("x", 0), offset.get("y", 0))
	if entity_id != "":
		EngineAPI.spawn_entity(entity_id, pos)

func _effect_knock_back(caster: Node2D, target: Node2D, effect: Dictionary, _spell: Dictionary) -> void:
	var force: float = effect.get("base_points", 200.0)
	var movement: Node = EngineAPI.get_component(target, "movement")
	if movement:
		var dir: Vector2 = caster.global_position.direction_to(target.global_position)
		movement.velocity = dir * force

func _effect_add_resource(_caster: Node2D, _target: Node2D, effect: Dictionary, _spell: Dictionary) -> void:
	var res_name: String = effect.get("resource", "")
	var amount: float = effect.get("base_points", 0.0)
	if res_name != "":
		EngineAPI.add_resource(res_name, amount)

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
