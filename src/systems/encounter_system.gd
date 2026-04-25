## EncounterSystem — 副本/Boss 战斗框架（对标 TrinityCore InstanceScript + BossAI）
## 双层架构：
##   InstanceScript — 副本级管理（多 Boss 顺序/门控/状态持久化）
##   BossEncounter — 单 Boss 战斗（阶段/定时器/召唤物/边界/回调）
## 框架层系统，零游戏知识
class_name EncounterSystem
extends Node

# === 战斗状态（对标 TC EncounterState）===
enum State {
	NOT_STARTED = 0,
	IN_PROGRESS = 1,
	FAILED = 2,
	DONE = 3,
}

# === 门控行为 ===
enum DoorBehavior {
	OPEN_WHEN_NOT_IN_PROGRESS = 0,  # Boss 未开打时开启（常见入口门）
	OPEN_WHEN_DONE = 1,             # Boss 击杀后开启（通往下一区域）
	OPEN_WHEN_IN_PROGRESS = 2,      # 战斗中开启（刷怪口）
	CLOSE_WHEN_IN_PROGRESS = 3,     # 战斗中关闭（锁门）
}

# === 数据存储 ===
var _instances: Dictionary = {}  # instance_id -> InstanceData
var _next_instance_id: int = 1

func _ready() -> void:
	EngineAPI.register_system("encounter", self)
	EventBus.connect_event("entity_killed", _on_entity_killed)

func _process(delta: float) -> void:
	if EngineAPI.get_game_state() != "playing":
		return
	for iid in _instances:
		var inst: Dictionary = _instances[iid]
		for boss_id in inst.get("bosses", {}):
			var boss: Dictionary = inst["bosses"][boss_id]
			if boss["state"] == State.IN_PROGRESS:
				_tick_boss(inst, boss, delta)

func _reset() -> void:
	_instances.clear()
	_next_instance_id = 1

# =========================================================================
# InstanceScript 层（副本级管理）
# =========================================================================

func create_instance(params: Dictionary) -> int:
	## 创建副本实例
	## params: {
	##   "boss_order": [boss_id_1, boss_id_2, ...],  # Boss 击杀顺序
	##   "doors": [{ "node": Node3D, "boss_id": String, "behavior": DoorBehavior }],
	## }
	var iid: int = _next_instance_id
	_next_instance_id += 1
	_instances[iid] = {
		"instance_id": iid,
		"bosses": {},        # boss_id -> BossEncounter data
		"boss_order": params.get("boss_order", []),
		"doors": params.get("doors", []),
		"data": {},          # 自由数据
	}
	return iid

func register_boss(instance_id: int, boss_id: String, params: Dictionary) -> void:
	## 注册一个 Boss 到副本
	## params: {
	##   "entities": [GameEntity, ...],  # Boss 实体（支持多个 = 议会战）
	##   "phases": int,
	##   "enrage_time": float,
	##   "boundary_center": Vector3,     # 战斗边界中心
	##   "boundary_radius": float,       # 战斗边界半径（0=无限制）
	##   "script": Dictionary,           # 回调脚本
	##   "required_bosses": [boss_id],   # 前置 Boss（必须先击杀）
	## }
	## script callbacks: {
	##   "on_start": Callable(enc),
	##   "on_phase_change": Callable(enc, old_phase, new_phase),
	##   "on_update": Callable(enc, delta),
	##   "on_boss_killed": Callable(enc),
	##   "on_fail": Callable(enc),
	##   "on_reset": Callable(enc),
	##   "on_enrage": Callable(enc),
	## }
	var inst: Dictionary = _instances.get(instance_id, {})
	if inst.is_empty():
		return
	var entities: Array = params.get("entities", [])
	if entities.is_empty():
		var single = params.get("boss_entity")
		if single:
			entities = [single]
	inst["bosses"][boss_id] = {
		"boss_id": boss_id,
		"entities": entities,
		"state": State.NOT_STARTED,
		"phase": 0,
		"max_phases": params.get("phases", 1),
		"enrage_time": params.get("enrage_time", 0.0),
		"elapsed": 0.0,
		"enraged": false,
		"timers": {},
		"summons": [],       # SummonList: [GameEntity, ...]
		"script": params.get("script", {}),
		"data": {},
		"boundary_center": params.get("boundary_center", Vector3.ZERO),
		"boundary_radius": params.get("boundary_radius", 0.0),
		"required_bosses": params.get("required_bosses", []),
		"instance_id": instance_id,
	}

func get_instance(instance_id: int) -> Dictionary:
	return _instances.get(instance_id, {})

func get_boss_state(instance_id: int, boss_id: String) -> int:
	var inst: Dictionary = _instances.get(instance_id, {})
	return inst.get("bosses", {}).get(boss_id, {}).get("state", State.NOT_STARTED)

func get_all_boss_states(instance_id: int) -> Dictionary:
	## 返回 { boss_id: state, ... }
	var result: Dictionary = {}
	var inst: Dictionary = _instances.get(instance_id, {})
	for bid in inst.get("bosses", {}):
		result[bid] = inst["bosses"][bid]["state"]
	return result

func is_instance_cleared(instance_id: int) -> bool:
	var inst: Dictionary = _instances.get(instance_id, {})
	for bid in inst.get("bosses", {}):
		if inst["bosses"][bid]["state"] != State.DONE:
			return false
	return not inst.get("bosses", {}).is_empty()

# =========================================================================
# BossEncounter 层（单 Boss 战斗）
# =========================================================================

func start_encounter(instance_id: int, boss_id: String) -> bool:
	var inst: Dictionary = _instances.get(instance_id, {})
	if inst.is_empty():
		return false
	var boss: Dictionary = inst["bosses"].get(boss_id, {})
	if boss.is_empty() or boss["state"] != State.NOT_STARTED:
		return false
	# 前置 Boss 检查
	for req_id in boss.get("required_bosses", []):
		if get_boss_state(instance_id, req_id) != State.DONE:
			return false
	boss["state"] = State.IN_PROGRESS
	boss["phase"] = 1
	boss["elapsed"] = 0.0
	boss["enraged"] = false
	_call_script(boss, "on_start", [boss])
	_update_doors(inst)
	EventBus.emit_event("encounter_started", {
		"instance_id": instance_id, "boss_id": boss_id,
		"entities": boss["entities"],
	})
	return true

func set_phase(instance_id: int, boss_id: String, new_phase: int) -> void:
	var boss: Dictionary = _get_boss(instance_id, boss_id)
	if boss.is_empty() or boss["state"] != State.IN_PROGRESS:
		return
	var old_phase: int = boss["phase"]
	if old_phase == new_phase:
		return
	boss["phase"] = new_phase
	_call_script(boss, "on_phase_change", [boss, old_phase, new_phase])
	EventBus.emit_event("encounter_phase_changed", {
		"instance_id": instance_id, "boss_id": boss_id,
		"old_phase": old_phase, "new_phase": new_phase,
	})

func fail_encounter(instance_id: int, boss_id: String) -> void:
	var inst: Dictionary = _instances.get(instance_id, {})
	var boss: Dictionary = inst.get("bosses", {}).get(boss_id, {})
	if boss.is_empty() or boss["state"] != State.IN_PROGRESS:
		return
	boss["state"] = State.FAILED
	_clear_timers(boss)
	_despawn_summons(boss)
	_call_script(boss, "on_fail", [boss])
	_update_doors(inst)
	EventBus.emit_event("encounter_failed", {
		"instance_id": instance_id, "boss_id": boss_id,
	})

func reset_encounter(instance_id: int, boss_id: String) -> void:
	## 重置 Boss（重试，对标 TC BossAI::_Reset）
	var inst: Dictionary = _instances.get(instance_id, {})
	var boss: Dictionary = inst.get("bosses", {}).get(boss_id, {})
	if boss.is_empty():
		return
	boss["state"] = State.NOT_STARTED
	boss["phase"] = 0
	boss["elapsed"] = 0.0
	boss["enraged"] = false
	_clear_timers(boss)
	_despawn_summons(boss)
	_call_script(boss, "on_reset", [boss])
	_update_doors(inst)
	EventBus.emit_event("encounter_reset", {
		"instance_id": instance_id, "boss_id": boss_id,
	})

# === 定时器 API ===

func schedule_timer(instance_id: int, boss_id: String, timer_name: String, delay: float, callback: Callable, repeat: bool = false) -> void:
	var boss: Dictionary = _get_boss(instance_id, boss_id)
	if boss.is_empty():
		return
	boss["timers"][timer_name] = {
		"remaining": delay, "callback": callback,
		"repeat": repeat, "interval": delay,
	}

func cancel_timer(instance_id: int, boss_id: String, timer_name: String) -> void:
	var boss: Dictionary = _get_boss(instance_id, boss_id)
	if not boss.is_empty():
		boss["timers"].erase(timer_name)

# === SummonList（小怪管理，对标 TC SummonList）===

func register_summon(instance_id: int, boss_id: String, summon: GameEntity) -> void:
	## Boss 召唤的小怪注册到列表，Boss 结束时自动清理
	var boss: Dictionary = _get_boss(instance_id, boss_id)
	if boss.is_empty():
		return
	boss["summons"].append(summon)

func _despawn_summons(boss: Dictionary) -> void:
	for summon in boss.get("summons", []):
		if is_instance_valid(summon):
			EngineAPI.destroy_entity(summon)
	boss["summons"].clear()

# === 战斗边界（对标 TC AreaBoundary）===

func is_in_boundary(instance_id: int, boss_id: String, position: Vector3) -> bool:
	var boss: Dictionary = _get_boss(instance_id, boss_id)
	if boss.is_empty():
		return true
	var radius: float = boss.get("boundary_radius", 0.0)
	if radius <= 0:
		return true  # 无边界
	var center: Vector3 = boss.get("boundary_center", Vector3.ZERO)
	return center.distance_to(position) <= radius

# === 查询 ===

func get_elapsed(instance_id: int, boss_id: String) -> float:
	return _get_boss(instance_id, boss_id).get("elapsed", 0.0)

func get_phase(instance_id: int, boss_id: String) -> int:
	return _get_boss(instance_id, boss_id).get("phase", 0)

func set_data(instance_id: int, boss_id: String, key: String, value: Variant) -> void:
	var boss: Dictionary = _get_boss(instance_id, boss_id)
	if not boss.is_empty():
		boss["data"][key] = value

func get_data(instance_id: int, boss_id: String, key: String, default: Variant = null) -> Variant:
	return _get_boss(instance_id, boss_id).get("data", {}).get(key, default)

# === 内部 ===

func _get_boss(instance_id: int, boss_id: String) -> Dictionary:
	var inst: Dictionary = _instances.get(instance_id, {})
	return inst.get("bosses", {}).get(boss_id, {})

func _tick_boss(inst: Dictionary, boss: Dictionary, delta: float) -> void:
	boss["elapsed"] += delta
	# 实体有效性检查（议会战：全部死亡才算完成）
	var all_dead := true
	for entity in boss.get("entities", []):
		if is_instance_valid(entity) and entity is GameEntity and (entity as GameEntity).is_alive:
			all_dead = false
			break
	if all_dead and not boss.get("entities", []).is_empty():
		_complete_boss(inst, boss)
		return
	# 狂暴
	if not boss["enraged"] and boss["enrage_time"] > 0 and boss["elapsed"] >= boss["enrage_time"]:
		boss["enraged"] = true
		_call_script(boss, "on_enrage", [boss])
		EventBus.emit_event("encounter_enrage", {
			"instance_id": inst["instance_id"], "boss_id": boss["boss_id"],
		})
	# 战斗边界检查：越界实体传送回来
	var radius: float = boss.get("boundary_radius", 0.0)
	if radius > 0:
		var center: Vector3 = boss["boundary_center"]
		var players: Array = EngineAPI.find_entities_by_tag("hero")
		for p in players:
			if is_instance_valid(p) and p is Node3D:
				if center.distance_to(p.global_position) > radius:
					p.global_position = center
	# 定时器
	var to_fire: Array = []
	var to_remove: Array = []
	for tname in boss["timers"]:
		var t: Dictionary = boss["timers"][tname]
		t["remaining"] -= delta
		if t["remaining"] <= 0:
			to_fire.append(tname)
			if t["repeat"]:
				t["remaining"] += t["interval"]
			else:
				to_remove.append(tname)
	for tname in to_fire:
		if boss["timers"].has(tname) and boss["timers"][tname]["callback"].is_valid():
			boss["timers"][tname]["callback"].call()
	for tname in to_remove:
		boss["timers"].erase(tname)
	# on_update
	_call_script(boss, "on_update", [boss, delta])

func _complete_boss(inst: Dictionary, boss: Dictionary) -> void:
	boss["state"] = State.DONE
	_clear_timers(boss)
	_despawn_summons(boss)
	_call_script(boss, "on_boss_killed", [boss])
	_update_doors(inst)
	EventBus.emit_event("encounter_completed", {
		"instance_id": inst["instance_id"], "boss_id": boss["boss_id"],
		"elapsed": boss["elapsed"],
	})
	# 检查副本全清
	if is_instance_cleared(inst["instance_id"]):
		EventBus.emit_event("instance_cleared", {"instance_id": inst["instance_id"]})

func _on_entity_killed(_data: Dictionary) -> void:
	## 不再直接在这里处理——_tick_boss 通过 all_dead 检测处理
	## 保留此方法以便未来扩展（如统计击杀数）
	pass

func _update_doors(inst: Dictionary) -> void:
	## 根据 Boss 状态更新门控（对标 TC DoorData）
	for door_data in inst.get("doors", []):
		var door_node = door_data.get("node")
		if not is_instance_valid(door_node):
			continue
		var boss_id: String = door_data.get("boss_id", "")
		var behavior: int = door_data.get("behavior", DoorBehavior.OPEN_WHEN_NOT_IN_PROGRESS)
		var boss_state: int = get_boss_state(inst["instance_id"], boss_id)
		var should_open := false
		match behavior:
			DoorBehavior.OPEN_WHEN_NOT_IN_PROGRESS:
				should_open = boss_state != State.IN_PROGRESS
			DoorBehavior.OPEN_WHEN_DONE:
				should_open = boss_state == State.DONE
			DoorBehavior.OPEN_WHEN_IN_PROGRESS:
				should_open = boss_state == State.IN_PROGRESS
			DoorBehavior.CLOSE_WHEN_IN_PROGRESS:
				should_open = boss_state != State.IN_PROGRESS
		# 通知门状态变化（GamePack 处理具体表现：可见性/碰撞）
		EventBus.emit_event("door_state_changed", {
			"node": door_node, "open": should_open,
			"boss_id": boss_id, "behavior": behavior,
		})

func _call_script(boss: Dictionary, method: String, args: Array) -> void:
	var script: Dictionary = boss.get("script", {})
	if script.has(method):
		var cb: Callable = script[method]
		if cb.is_valid():
			cb.callv(args)

func _clear_timers(boss: Dictionary) -> void:
	boss["timers"].clear()
