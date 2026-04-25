## ThreatManager — 仇恨/仇恨系统（对标 TrinityCore ThreatManager）
## 每个 AI 实体维护独立仇恨列表，驱动 AI 状态机（IDLE/COMBAT/EVADING/HOME）
## 框架层系统，通过 EventBus 监听伤害/死亡事件自动运作
class_name ThreatManager
extends Node

# === AI 状态枚举 ===
enum AIState { IDLE = 0, COMBAT = 1, EVADING = 2, HOME = 3 }

# === 常量 ===
const EVADE_CHECK_INTERVAL := 1.0
const DEFAULT_LEASH_DISTANCE := 600.0
const HOME_ARRIVE_THRESHOLD := 20.0
const HEAL_THREAT_MULT := 0.5

# === 数据 ===
# entity_instance_id → { source_instance_id → threat_value }
var _threat_lists: Dictionary = {}
# entity_instance_id → { "source": GameEntity, "expire": float }
var _taunt_overrides: Dictionary = {}
var _evade_timer: float = 0.0

func _ready() -> void:
	EngineAPI.register_system("threat", self)
	EventBus.connect_event("entity_damaged", _on_entity_damaged)
	EventBus.connect_event("entity_destroyed", _on_entity_destroyed)
	EventBus.connect_event("entity_spawned", _on_entity_spawned)
	EventBus.connect_event("entity_healed", _on_entity_healed)

func _process(delta: float) -> void:
	# 场景切换/非游戏状态时跳过
	if EngineAPI.get_game_state() != "playing":
		return
	# 嘲讽过期清理
	var expired_taunts: Array = []
	var now: float = Time.get_ticks_msec() / 1000.0
	for eid in _taunt_overrides:
		if _taunt_overrides[eid].get("expire", 0.0) <= now:
			expired_taunts.append(eid)
	for eid in expired_taunts:
		_taunt_overrides.erase(eid)

	# 拉扯/回家检查
	_evade_timer += delta
	if _evade_timer < EVADE_CHECK_INTERVAL:
		return
	_evade_timer -= EVADE_CHECK_INTERVAL
	_check_evade_and_home()

# === 公共 API ===

func add_threat(entity: GameEntity, source: GameEntity, amount: float) -> void:
	## 向 entity 的仇恨列表中添加来自 source 的仇恨值
	if not is_instance_valid(entity) or not is_instance_valid(source):
		return
	if not entity.is_alive or not source.is_alive:
		return
	# 脱战/归位中不接受任何仇恨（对标 WoW evade immunity）
	var cur_state: int = entity.meta.get("ai_state", AIState.IDLE)
	if cur_state == AIState.EVADING or cur_state == AIState.HOME:
		return
	# 只对有 AI 的实体追踪仇恨
	if not entity.has_component("ai_move_to"):
		return
	var eid: int = entity.get_instance_id()
	if not _threat_lists.has(eid):
		_threat_lists[eid] = {}
	var sid: int = source.get_instance_id()
	var list: Dictionary = _threat_lists[eid]
	var old_empty: bool = list.is_empty()
	list[sid] = list.get(sid, 0.0) + maxf(amount, 0.0)
	# 首次进入仇恨列表 → 进入战斗
	if old_empty and not list.is_empty():
		_enter_combat(entity, source)

func get_victim(entity: GameEntity) -> GameEntity:
	## 返回仇恨最高的有效目标（对标 TrinityCore ThreatManager::GetCurrentVictim）
	if not is_instance_valid(entity):
		return null
	var eid: int = entity.get_instance_id()
	# 嘲讽覆盖
	if _taunt_overrides.has(eid):
		var taunt_src = _taunt_overrides[eid].get("source")
		if is_instance_valid(taunt_src) and TargetUtil.is_valid_attack_target(entity, taunt_src):
			return taunt_src
	# 仇恨列表排序
	if not _threat_lists.has(eid):
		return null
	var list: Dictionary = _threat_lists[eid]
	var best: GameEntity = null
	var best_threat: float = -1.0
	var invalid_ids: Array = []
	for sid in list:
		var src_node: Object = instance_from_id(sid)
		if src_node == null or not is_instance_valid(src_node) or not (src_node is GameEntity):
			invalid_ids.append(sid)
			continue
		var src: GameEntity = src_node as GameEntity
		if not TargetUtil.is_valid_attack_target(entity, src):
			continue
		if list[sid] > best_threat:
			best_threat = list[sid]
			best = src
	# 清理无效条目
	for sid in invalid_ids:
		list.erase(sid)
	return best

func clear_threat(entity: GameEntity) -> void:
	if entity == null:
		return
	var eid: int = entity.get_instance_id()
	_threat_lists.erase(eid)
	_taunt_overrides.erase(eid)

func has_threat(entity: GameEntity) -> bool:
	if entity == null:
		return false
	var eid: int = entity.get_instance_id()
	return _threat_lists.has(eid) and not _threat_lists[eid].is_empty()

func get_threat_list_debug(entity: GameEntity) -> Array:
	## 返回可读的仇恨列表（用于调试）
	var result: Array = []
	if entity == null:
		return result
	var eid: int = entity.get_instance_id()
	if not _threat_lists.has(eid):
		return result
	for sid in _threat_lists[eid]:
		var src_node: Object = instance_from_id(sid)
		var name_str: String = (src_node as GameEntity).def_id if src_node is GameEntity else "?"
		result.append({"name": name_str, "threat": _threat_lists[eid][sid]})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["threat"] > b["threat"])
	return result

func apply_taunt(entity: GameEntity, taunter: GameEntity, duration: float) -> void:
	if not is_instance_valid(entity) or not is_instance_valid(taunter):
		return
	# 脱战归位优先级高于一切（对标 WoW：EVADING 期间免疫所有操作包括嘲讽）
	var cur_state: int = entity.meta.get("ai_state", AIState.IDLE)
	if cur_state == AIState.EVADING or cur_state == AIState.HOME:
		return
	var eid: int = entity.get_instance_id()
	_taunt_overrides[eid] = {
		"source": taunter,
		"expire": Time.get_ticks_msec() / 1000.0 + duration,
	}
	# 确保 taunter 在仇恨列表里，并进入 COMBAT
	add_threat(entity, taunter, 1.0)

func _reset() -> void:
	_threat_lists.clear()
	_taunt_overrides.clear()
	_evade_timer = 0.0

# === AI 状态转换 ===

func _enter_combat(entity: GameEntity, first_aggro: GameEntity) -> void:
	## 对标 TrinityCore Creature::AtEngage()
	var old_state: int = entity.meta.get("ai_state", AIState.IDLE)
	if old_state == AIState.COMBAT:
		return
	# 保存进入战斗时的位置作为"回家点"（对标 SetHomePosition(*this)）
	entity.meta["home_position"] = entity.global_position
	entity.meta["ai_state"] = AIState.COMBAT
	entity.set_unit_flag(UnitFlags.IN_COMBAT)
	EventBus.emit_event("ai_entered_combat", {"entity": entity, "aggro": first_aggro})

func _enter_evade(entity: GameEntity) -> void:
	entity.meta["ai_state"] = AIState.EVADING
	entity.set_unit_state(UnitFlags.UnitState.EVADING)
	clear_threat(entity)
	# 重置所有战斗状态：清目标、停攻击
	var ai: Node = entity.get_component("ai_move_to")
	if ai:
		ai.target_entity = null
		ai._reached = false
	var combat: Node = entity.get_component("combat")
	if combat:
		combat._attack_timer = 0.0
	# 清除所有 debuff（框架层通过 AuraManager）
	var aura_mgr: Node = EngineAPI.get_system("aura")
	if aura_mgr and aura_mgr.has_method("remove_all_debuffs"):
		aura_mgr.call("remove_all_debuffs", entity)
	EventBus.emit_event("ai_enter_evade", {"entity": entity})

func _enter_home(entity: GameEntity) -> void:
	entity.meta["ai_state"] = AIState.HOME
	# 恢复状态
	entity.set_unit_state(UnitFlags.UnitState.ALIVE)
	entity.clear_unit_flag(UnitFlags.EVADING | UnitFlags.IMMUNE_DAMAGE | UnitFlags.NOT_SELECTABLE | UnitFlags.IN_COMBAT)
	# 满血
	var health: Node = EngineAPI.get_component(entity, "health")
	if health:
		health.current_hp = health.max_hp
	# 下一帧转 IDLE
	entity.meta["ai_state"] = AIState.IDLE
	EventBus.emit_event("ai_returned_home", {"entity": entity})

func _leave_combat(entity: GameEntity) -> void:
	## 对标 TrinityCore：仇恨清空后判断是否需要脱战回家
	entity.clear_unit_flag(UnitFlags.IN_COMBAT)
	# 回家目标 = 进入战斗时的位置（home_position），不是原始出生点
	var home_pos: Vector3 = entity.meta.get("home_position", entity.meta.get("spawn_position", entity.global_position))
	var dist: float = entity.global_position.distance_to(home_pos)
	if dist > HOME_ARRIVE_THRESHOLD * 3:
		_enter_evade(entity)
	else:
		entity.meta["ai_state"] = AIState.IDLE

# === 定时检查 ===

func _check_evade_and_home() -> void:
	if EngineAPI.get_game_state() != "playing":
		return
	var entities: Array = EngineAPI.find_entities_by_tag("mobile")
	for e in entities:
		if not is_instance_valid(e) or not (e is GameEntity):
			continue
		var ge: GameEntity = e as GameEntity
		var state: int = ge.meta.get("ai_state", AIState.IDLE)
		match state:
			AIState.COMBAT:
				# 仇恨列表空 → 脱战
				if not has_threat(ge):
					_leave_combat(ge)
					continue
				# 拉扯检查（对标 TrinityCore CanCreatureAttack）
				# 用 home_position（战斗入口），不是 spawn_position
				var home_pos: Vector3 = ge.meta.get("home_position", ge.meta.get("spawn_position", ge.global_position))
				var leash: float = float(ge.meta.get("leash_distance", DEFAULT_LEASH_DISTANCE))
				# 检查当前目标是否离 home 太远（被风筝）
				var victim: GameEntity = get_victim(ge)
				if victim and victim.global_position.distance_to(home_pos) > leash:
					_enter_evade(ge)
			AIState.EVADING:
				# 到达 home_position → 回家完成
				var evade_home: Vector3 = ge.meta.get("home_position", ge.meta.get("spawn_position", ge.global_position))
				if ge.global_position.distance_to(evade_home) < HOME_ARRIVE_THRESHOLD:
					_enter_home(ge)

# === 事件处理 ===

func _on_entity_spawned(data: Dictionary) -> void:
	var entity = data.get("entity")
	if entity == null or not (entity is GameEntity):
		return
	var ge: GameEntity = entity as GameEntity
	# 只对 AI 实体初始化
	if ge.has_component("ai_move_to"):
		ge.meta["spawn_position"] = ge.global_position
		if not ge.meta.has("ai_state"):
			ge.meta["ai_state"] = AIState.IDLE

func _on_entity_damaged(data: Dictionary) -> void:
	var entity = data.get("entity")  # 受伤方
	var source = data.get("source")  # 攻击方
	var amount: float = data.get("amount", 0.0)
	if entity == null or source == null:
		return
	if not is_instance_valid(entity) or not is_instance_valid(source):
		return
	if not (entity is GameEntity) or not (source is GameEntity):
		return
	# 受伤方是 AI → 攻击方产生仇恨
	if (entity as GameEntity).has_component("ai_move_to"):
		add_threat(entity as GameEntity, source as GameEntity, amount)

func _on_entity_healed(data: Dictionary) -> void:
	var entity = data.get("entity")  # 被治疗方
	var source = data.get("source")  # 治疗者
	var amount: float = data.get("amount", 0.0)
	if entity == null or source == null:
		return
	if not is_instance_valid(entity) or not is_instance_valid(source):
		return
	if not (source is GameEntity):
		return
	# 治疗者对所有正在攻击被治疗方的敌人产生仇恨
	var threat_amount: float = amount * HEAL_THREAT_MULT
	for eid in _threat_lists:
		var list: Dictionary = _threat_lists[eid]
		var target_id: int = entity.get_instance_id() if is_instance_valid(entity) else -1
		if target_id >= 0 and list.has(target_id):
			var npc: Object = instance_from_id(eid)
			if npc is GameEntity and is_instance_valid(npc):
				var src_id: int = (source as GameEntity).get_instance_id()
				list[src_id] = list.get(src_id, 0.0) + threat_amount

func _on_entity_destroyed(data: Dictionary) -> void:
	var entity = data.get("entity")
	if entity == null or not (entity is GameEntity):
		return
	var ge: GameEntity = entity as GameEntity
	var eid: int = ge.get_instance_id()
	# 清除自身仇恨列表
	_threat_lists.erase(eid)
	_taunt_overrides.erase(eid)
	# 从所有其他实体的仇恨列表中移除
	for other_eid in _threat_lists:
		var list: Dictionary = _threat_lists[other_eid]
		list.erase(eid)
		# 如果某个实体的仇恨列表因此清空，下次 _check_evade_and_home 会处理
