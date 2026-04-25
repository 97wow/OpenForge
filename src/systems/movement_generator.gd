## MovementGenerator — 移动行为优先级栈（对标 TrinityCore MotionMaster / MovementGenerator）
## 管理实体的移动行为优先级：多个移动行为可叠加，高优先级的覆盖低优先级
## 与 EntitySystem 的 AI 状态机和 MovementComponent 协作
## 框架层系统，零游戏知识
class_name MovementGenerator
extends Node

# === 移动行为类型（优先级从低到高）===
enum MoveType {
	IDLE = 0,        # 原地站桩
	RANDOM = 1,      # 随机移动（闲逛/巡逻）
	WAYPOINT = 2,    # 路径点巡逻
	FOLLOW = 3,      # 跟随目标（宠物/随从）
	CHASE = 4,       # 追击目标（战斗 AI）
	FLEE = 5,        # 逃离目标
	CONFUSED = 6,    # 恐惧随机移动（CC_FEAR）
	POINT = 7,       # 移动到指定点（一次性）
	HOME = 8,        # 回家（脱战后回出生点）
	EFFECT = 9,      # 强制位移（击退/冲锋，最高优先级）
}

# === 移动行为实例 ===
# {
#   "type": MoveType,
#   "target": Node3D or null,     # 追击/跟随的目标
#   "target_pos": Vector3,        # 目标位置（POINT/HOME）
#   "speed_factor": float,        # 速度倍率（1.0 = 正常）
#   "arrive_distance": float,     # 到达判定距离
#   "duration": float,            # 持续时间（0 = 永久直到完成）
#   "elapsed": float,             # 已经过时间
#   "completed": bool,            # 是否已完成
#   "data": Dictionary,           # 额外数据
# }

# === 数据存储 ===
# entity_instance_id -> Array[MoveBehavior]（按优先级排序的行为栈）
var _move_stacks: Dictionary = {}

# 恐惧移动计时器
var _fear_change_timer: Dictionary = {}  # eid -> timer
const FEAR_CHANGE_INTERVAL := 1.5  # 恐惧每 1.5 秒换方向

func _ready() -> void:
	EngineAPI.register_system("movement_gen", self)
	EventBus.connect_event("unit_flags_changed", _on_flags_changed)
	EventBus.connect_event("entity_destroyed", _on_entity_destroyed)

func _process(delta: float) -> void:
	if EngineAPI.get_game_state() != "playing":
		return
	_tick_all(delta)

func _reset() -> void:
	_move_stacks.clear()
	_fear_change_timer.clear()

# === 公共 API ===

func push_movement(entity: GameEntity, move_type: int, params: Dictionary = {}) -> void:
	## 压入移动行为（自动按优先级排序）
	if not is_instance_valid(entity):
		return
	var eid: int = entity.get_instance_id()
	if not _move_stacks.has(eid):
		_move_stacks[eid] = []
	# 同类型只保留一个（替换旧的）
	var stack: Array = _move_stacks[eid]
	for i in range(stack.size() - 1, -1, -1):
		if stack[i]["type"] == move_type:
			stack.remove_at(i)
	var behavior := {
		"type": move_type,
		"target": params.get("target"),
		"target_pos": params.get("target_pos", Vector3.ZERO),
		"speed_factor": params.get("speed_factor", 1.0),
		"arrive_distance": params.get("arrive_distance", 20.0),
		"duration": params.get("duration", 0.0),
		"elapsed": 0.0,
		"completed": false,
		"data": params.get("data", {}),
	}
	stack.append(behavior)
	# 按优先级排序（高优先级在后面 = 栈顶）
	stack.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["type"] < b["type"]
	)

func pop_movement(entity: GameEntity, move_type: int) -> void:
	## 移除指定类型的移动行为
	if not is_instance_valid(entity):
		return
	var eid: int = entity.get_instance_id()
	if not _move_stacks.has(eid):
		return
	var stack: Array = _move_stacks[eid]
	for i in range(stack.size() - 1, -1, -1):
		if stack[i]["type"] == move_type:
			stack.remove_at(i)

func clear_movement(entity: GameEntity) -> void:
	## 清除实体的所有移动行为
	if not is_instance_valid(entity):
		return
	var eid: int = entity.get_instance_id()
	_move_stacks.erase(eid)
	_fear_change_timer.erase(eid)

func get_current_movement(entity: GameEntity) -> Dictionary:
	## 获取当前最高优先级的移动行为
	if not is_instance_valid(entity):
		return {}
	var eid: int = entity.get_instance_id()
	if not _move_stacks.has(eid):
		return {}
	var stack: Array = _move_stacks[eid]
	if stack.is_empty():
		return {}
	return stack[stack.size() - 1]

func has_movement(entity: GameEntity, move_type: int) -> bool:
	if not is_instance_valid(entity):
		return false
	var eid: int = entity.get_instance_id()
	if not _move_stacks.has(eid):
		return false
	for b in _move_stacks[eid]:
		if b["type"] == move_type:
			return true
	return false

# === 便捷方法 ===

func move_chase(entity: GameEntity, target: GameEntity, arrive_dist: float = 30.0) -> void:
	push_movement(entity, MoveType.CHASE, {
		"target": target, "arrive_distance": arrive_dist,
	})

func move_follow(entity: GameEntity, target: GameEntity, follow_dist: float = 60.0) -> void:
	push_movement(entity, MoveType.FOLLOW, {
		"target": target, "arrive_distance": follow_dist,
	})

func move_flee(entity: GameEntity, from_target: GameEntity, duration: float = 3.0) -> void:
	push_movement(entity, MoveType.FLEE, {
		"target": from_target, "duration": duration,
	})

func move_point(entity: GameEntity, target_pos: Vector3, arrive_dist: float = 10.0) -> void:
	push_movement(entity, MoveType.POINT, {
		"target_pos": target_pos, "arrive_distance": arrive_dist,
	})

func move_home(entity: GameEntity) -> void:
	var home_pos: Vector3 = entity.meta.get("home_position",
		entity.meta.get("spawn_position", entity.global_position))
	push_movement(entity, MoveType.HOME, {
		"target_pos": home_pos, "arrive_distance": 20.0, "speed_factor": 1.5,
	})

func move_confused(entity: GameEntity, duration: float = 5.0) -> void:
	push_movement(entity, MoveType.CONFUSED, {
		"duration": duration,
	})

func move_effect(entity: GameEntity, target_pos: Vector3, duration: float = 0.3, speed_factor: float = 3.0) -> void:
	## 强制位移（击退/冲锋），最高优先级
	push_movement(entity, MoveType.EFFECT, {
		"target_pos": target_pos, "duration": duration,
		"speed_factor": speed_factor, "arrive_distance": 5.0,
	})

func move_random(entity: GameEntity, radius: float = 100.0, pause_min: float = 2.0, pause_max: float = 5.0) -> void:
	push_movement(entity, MoveType.RANDOM, {
		"arrive_distance": 10.0,
		"data": {
			"radius": radius,
			"pause_min": pause_min,
			"pause_max": pause_max,
			"origin": entity.global_position,
			"next_move_at": 0.0,
		},
	})

# === 内部 Tick ===

func _tick_all(delta: float) -> void:
	var to_clean: Array = []
	for eid in _move_stacks:
		var stack: Array = _move_stacks[eid]
		if stack.is_empty():
			to_clean.append(eid)
			continue
		# 清理已完成的行为
		for i in range(stack.size() - 1, -1, -1):
			if stack[i]["completed"]:
				stack.remove_at(i)
		if stack.is_empty():
			to_clean.append(eid)
			continue
		# 执行栈顶行为
		var entity_obj: Object = instance_from_id(eid)
		if entity_obj == null or not is_instance_valid(entity_obj) or not (entity_obj is GameEntity):
			to_clean.append(eid)
			continue
		var entity: GameEntity = entity_obj as GameEntity
		if not entity.is_alive:
			to_clean.append(eid)
			continue
		var behavior: Dictionary = stack[stack.size() - 1]
		_tick_behavior(entity, behavior, delta)
	for eid in to_clean:
		_move_stacks.erase(eid)

func _tick_behavior(entity: GameEntity, behavior: Dictionary, delta: float) -> void:
	var movement: Node = EngineAPI.get_component(entity, "movement")
	if movement == null:
		return
	# 持续时间检查
	if behavior["duration"] > 0:
		behavior["elapsed"] += delta
		if behavior["elapsed"] >= behavior["duration"]:
			behavior["completed"] = true
			movement.velocity = Vector3.ZERO
			return
	# 根据类型执行
	match behavior["type"]:
		MoveType.IDLE:
			movement.velocity = Vector3.ZERO
		MoveType.CHASE:
			_tick_chase(entity, behavior, movement)
		MoveType.FOLLOW:
			_tick_follow(entity, behavior, movement)
		MoveType.FLEE:
			_tick_flee(entity, behavior, movement)
		MoveType.CONFUSED:
			_tick_confused(entity, behavior, movement, delta)
		MoveType.POINT, MoveType.HOME:
			_tick_move_to_point(entity, behavior, movement)
		MoveType.EFFECT:
			_tick_effect(entity, behavior, movement)
		MoveType.RANDOM:
			_tick_random(entity, behavior, movement, delta)

func _tick_chase(entity: GameEntity, behavior: Dictionary, movement: Node) -> void:
	var target = behavior.get("target")
	if target == null or not is_instance_valid(target):
		behavior["completed"] = true
		movement.velocity = Vector3.ZERO
		return
	var dist: float = entity.global_position.distance_to(target.global_position)
	if dist <= behavior["arrive_distance"]:
		movement.velocity = Vector3.ZERO
	else:
		var dir: Vector3 = _get_pathfind_direction(entity, target.global_position)
		movement.velocity = dir * movement.current_speed * behavior["speed_factor"]

func _tick_follow(entity: GameEntity, behavior: Dictionary, movement: Node) -> void:
	var target = behavior.get("target")
	if target == null or not is_instance_valid(target):
		behavior["completed"] = true
		movement.velocity = Vector3.ZERO
		return
	var dist: float = entity.global_position.distance_to(target.global_position)
	if dist <= behavior["arrive_distance"]:
		movement.velocity = Vector3.ZERO
	else:
		var dir: Vector3 = _get_pathfind_direction(entity, target.global_position)
		movement.velocity = dir * movement.current_speed * behavior["speed_factor"]

func _tick_flee(entity: GameEntity, behavior: Dictionary, movement: Node) -> void:
	var target = behavior.get("target")
	if target == null or not is_instance_valid(target):
		behavior["completed"] = true
		movement.velocity = Vector3.ZERO
		return
	var dir: Vector3 = target.global_position.direction_to(entity.global_position)
	movement.velocity = dir * movement.current_speed * behavior["speed_factor"]

func _tick_confused(entity: GameEntity, behavior: Dictionary, movement: Node, delta: float) -> void:
	## 恐惧/混乱：随机方向移动，定期换方向
	var eid: int = entity.get_instance_id()
	if not _fear_change_timer.has(eid):
		_fear_change_timer[eid] = 0.0
		behavior["data"]["random_dir"] = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	_fear_change_timer[eid] += delta
	if _fear_change_timer[eid] >= FEAR_CHANGE_INTERVAL:
		_fear_change_timer[eid] -= FEAR_CHANGE_INTERVAL
		behavior["data"]["random_dir"] = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var dir: Vector3 = behavior["data"].get("random_dir", Vector3.RIGHT)
	movement.velocity = dir * movement.current_speed * 0.6  # 恐惧移动速度降低

func _tick_move_to_point(entity: GameEntity, behavior: Dictionary, movement: Node) -> void:
	var target_pos: Vector3 = behavior["target_pos"]
	var dist: float = entity.global_position.distance_to(target_pos)
	if dist <= behavior["arrive_distance"]:
		behavior["completed"] = true
		movement.velocity = Vector3.ZERO
		EventBus.emit_event("movement_arrived", {
			"entity": entity, "move_type": behavior["type"],
		})
	else:
		var dir: Vector3 = _get_pathfind_direction(entity, target_pos)
		movement.velocity = dir * movement.current_speed * behavior["speed_factor"]

func _tick_effect(entity: GameEntity, behavior: Dictionary, movement: Node) -> void:
	## 强制位移（忽略 ROOTED 等，由调用方保证合理性）
	var target_pos: Vector3 = behavior["target_pos"]
	var dist: float = entity.global_position.distance_to(target_pos)
	if dist <= behavior["arrive_distance"]:
		behavior["completed"] = true
		movement.velocity = Vector3.ZERO
	else:
		var dir: Vector3 = entity.global_position.direction_to(target_pos)
		movement.velocity = dir * movement.base_speed * behavior["speed_factor"]

func _tick_random(entity: GameEntity, behavior: Dictionary, movement: Node, delta: float) -> void:
	## 随机闲逛：到达目标点后等待，再随机下一个点
	var data: Dictionary = behavior["data"]
	var origin: Vector3 = data.get("origin", entity.global_position)
	var radius: float = data.get("radius", 100.0)

	if not data.has("current_target"):
		data["next_move_at"] = data.get("next_move_at", 0.0)

	data["next_move_at"] -= delta

	if data.has("current_target"):
		# 移动中
		var target_pos: Vector3 = data["current_target"]
		var dist: float = entity.global_position.distance_to(target_pos)
		if dist <= 15.0:
			# 到达，进入等待
			movement.velocity = Vector3.ZERO
			data.erase("current_target")
			data["next_move_at"] = randf_range(data.get("pause_min", 2.0), data.get("pause_max", 5.0))
		else:
			var dir: Vector3 = entity.global_position.direction_to(target_pos)
			movement.velocity = dir * movement.current_speed * 0.5
	else:
		# 等待中
		if data["next_move_at"] <= 0:
			# 选择新的随机目标点（XZ 平面）
			var angle: float = randf() * TAU
			var dist: float = randf() * radius
			data["current_target"] = origin + Vector3(cos(angle), 0, sin(angle)) * dist
		else:
			movement.velocity = Vector3.ZERO

# === 事件处理 ===

func _on_flags_changed(event_data: Dictionary) -> void:
	## 当 FEARED flag 设置/清除时，自动推入/弹出 CONFUSED 移动
	var entity = event_data.get("entity")
	if entity == null or not (entity is GameEntity):
		return
	var ge: GameEntity = entity as GameEntity
	var old_flags: int = event_data.get("old_flags", 0)
	var new_flags: int = event_data.get("new_flags", 0)
	# FEARED 变化
	var was_feared: bool = (old_flags & UnitFlags.FEARED) != 0
	var is_feared: bool = (new_flags & UnitFlags.FEARED) != 0
	if is_feared and not was_feared:
		move_confused(ge, 999.0)  # duration 由 aura 控制，这里设大值
	elif was_feared and not is_feared:
		pop_movement(ge, MoveType.CONFUSED)
		_fear_change_timer.erase(ge.get_instance_id())

func _on_entity_destroyed(data: Dictionary) -> void:
	var entity = data.get("entity")
	if entity == null or not (entity is GameEntity):
		return
	var eid: int = (entity as GameEntity).get_instance_id()
	_move_stacks.erase(eid)
	_fear_change_timer.erase(eid)

# === PathfindingSystem 集成 ===

func _get_pathfind_direction(entity: GameEntity, target_pos: Vector3) -> Vector3:
	## 尝试使用 PathfindingSystem 寻路，回退到直线方向
	var path_sys: Node = EngineAPI.get_system("pathfinding")
	if path_sys and path_sys.call("has_navigation"):
		return path_sys.call("get_direction", entity, target_pos)
	return entity.global_position.direction_to(target_pos)
