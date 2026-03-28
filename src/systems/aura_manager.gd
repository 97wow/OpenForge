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

func apply_aura(caster: Node2D, target: Node2D, effect: Dictionary, spell: Dictionary, duration: float) -> void:
	if not is_instance_valid(target):
		return
	var eid: int = target.get_instance_id()
	var aura_type: String = effect.get("aura", "")
	var spell_id: String = spell.get("id", "")
	var aura_id := "%s_%s" % [spell_id, aura_type]
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

	EventBus.emit_event("aura_applied", {
		"aura_id": aura_id,
		"target": target,
		"caster": caster,
		"aura_type": aura_type,
	})

func remove_aura(target: Node2D, aura_id: String) -> void:
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

func has_aura(target: Node2D, aura_id: String) -> bool:
	var eid: int = target.get_instance_id()
	return not _find_aura(eid, aura_id).is_empty()

func get_aura_stacks(target: Node2D, aura_id: String) -> int:
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

func _remove_aura_instance(aura: Dictionary) -> void:
	var aura_type: String = aura["aura_type"]
	if _aura_handlers.has(aura_type):
		var handlers: Dictionary = _aura_handlers[aura_type]
		if handlers.has("remove") and handlers["remove"] != null and handlers["remove"].is_valid():
			handlers["remove"].call(aura)

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

# --- 周期伤害 ---
func _tick_periodic_damage(aura: Dictionary) -> void:
	var target = aura.get("target")
	var caster = aura.get("caster")
	if target == null or not is_instance_valid(target):
		return
	var dmg: float = aura["base_points"] * aura["stacks"]
	var school: String = aura.get("spell", {}).get("school", "physical")
	var health: Node = EngineAPI.get_component(target, "health")
	if health and health.has_method("take_damage"):
		var dt: int = health.parse_damage_type(school)
		health.take_damage(dmg, caster if is_instance_valid(caster) else null, dt)

# --- 周期治疗 ---
func _tick_periodic_heal(aura: Dictionary) -> void:
	var target = aura.get("target")
	var caster = aura.get("caster")
	if target == null or not is_instance_valid(target):
		return
	var heal_amount: float = aura["base_points"] * aura["stacks"]
	var health: Node = EngineAPI.get_component(target, "health")
	if health and health.has_method("heal"):
		health.heal(heal_amount, caster if is_instance_valid(caster) else null)

# --- 周期触发技能 ---
func _tick_periodic_trigger(aura: Dictionary) -> void:
	var caster = aura.get("caster")
	var target = aura.get("target")
	var trigger_id: String = aura.get("effect", {}).get("trigger_spell", "")
	if trigger_id != "" and is_instance_valid(caster):
		var spell_system: Node = EngineAPI.get_system("spell")
		if spell_system:
			spell_system.call("cast", trigger_id, caster, target if is_instance_valid(target) else null)

# --- 属性修改 ---
func _apply_mod_stat(aura: Dictionary) -> void:
	var target = aura.get("target")
	if target == null or not is_instance_valid(target):
		return
	var stat_name: String = aura.get("effect", {}).get("misc_value", "")
	var mod_type: String = aura.get("effect", {}).get("mod_type", "flat")
	var value: float = aura["base_points"]
	var mod_id: String = EngineAPI.add_stat_modifier(target, stat_name, {
		"type": mod_type, "value": value, "source": aura["aura_id"]
	})
	aura["modifier_ids"].append(mod_id)

func _remove_mod_stat(aura: Dictionary) -> void:
	for mod_id in aura.get("modifier_ids", []):
		EngineAPI.remove_stat_modifier(mod_id)

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

# --- Proc 触发 ---
func _apply_proc(aura: Dictionary) -> void:
	var proc_manager: Node = EngineAPI.get_system("proc")
	if proc_manager:
		var proc_data: Dictionary = aura.get("effect", {}).get("proc", {})
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

func get_auras_on(target: Node2D) -> Array:
	if not is_instance_valid(target):
		return []
	var eid: int = target.get_instance_id()
	return _active_auras.get(eid, [])

func clear_auras_on(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	var eid: int = target.get_instance_id()
	if _active_auras.has(eid):
		for aura in _active_auras[eid]:
			_remove_aura_instance(aura)
		_active_auras.erase(eid)

# === Aura 持续视觉特效 ===

func _create_aura_particles(target: Node2D, config: Dictionary) -> CPUParticles2D:
	## 创建附着在目标身上的持续粒子
	if not is_instance_valid(target):
		return null
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = false
	particles.amount = config.get("amount", 4)
	particles.lifetime = config.get("lifetime", 0.8)
	particles.speed_scale = 1.0
	particles.direction = config.get("direction", Vector2(0, -1))
	particles.spread = config.get("spread", 45.0)
	particles.initial_velocity_min = config.get("speed_min", 10)
	particles.initial_velocity_max = config.get("speed_max", 25)
	particles.gravity = config.get("gravity", Vector2.ZERO)
	particles.scale_amount_min = config.get("size_min", 1.5)
	particles.scale_amount_max = config.get("size_max", 2.5)
	var color_start: Color = config.get("color", Color.WHITE)
	var color_end: Color = config.get("color_end", Color(1, 1, 1, 0))
	var gradient := Gradient.new()
	gradient.set_color(0, color_start)
	gradient.set_color(1, color_end)
	particles.color_ramp = gradient
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
				"direction": Vector2(0, -1), "spread": 30.0,
				"speed_min": 15, "speed_max": 30,
				"gravity": Vector2(0, -20),
				"size_min": 1.5, "size_max": 2.5,
				"color": Color(1, 0.5, 0.1, 0.8),
				"color_end": Color(1, 0.2, 0, 0),
				"node_name": "BurnVFX",
			}
		"nature", "poison":
			config = {
				"amount": 3, "lifetime": 0.8,
				"direction": Vector2(0, -1), "spread": 60.0,
				"speed_min": 8, "speed_max": 15,
				"gravity": Vector2(0, -10),
				"size_min": 1.5, "size_max": 2.0,
				"color": Color(0.3, 0.9, 0.2, 0.7),
				"color_end": Color(0.1, 0.6, 0.1, 0),
				"node_name": "PoisonVFX",
			}
		"frost", "ice":
			config = {
				"amount": 4, "lifetime": 1.0,
				"direction": Vector2(0, 0), "spread": 180.0,
				"speed_min": 5, "speed_max": 12,
				"gravity": Vector2(0, 5),
				"size_min": 1.0, "size_max": 2.0,
				"color": Color(0.5, 0.8, 1, 0.7),
				"color_end": Color(0.7, 0.9, 1, 0),
				"node_name": "FrostVFX",
			}
		"shadow":
			config = {
				"amount": 4, "lifetime": 0.7,
				"direction": Vector2(0, 0), "spread": 180.0,
				"speed_min": 10, "speed_max": 20,
				"gravity": Vector2.ZERO,
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
		"direction": Vector2(0, -1), "spread": 20.0,
		"speed_min": 10, "speed_max": 20,
		"gravity": Vector2(0, -15),
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
		"direction": Vector2(0, 0), "spread": 180.0,
		"speed_min": 3, "speed_max": 8,
		"gravity": Vector2(0, 8),
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
