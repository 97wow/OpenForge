## PathfindingSystem — 寻路/避障/视线系统（对标 TrinityCore PathGenerator / MMAP / VMAP）
## 基于 Godot NavigationServer3D + RayCast3D
## 支持：路径缓存、路径平滑、LoS 视线检查、动态障碍物、地形层过滤
## 框架层系统，与 MovementGenerator 集成
class_name PathfindingSystem
extends Node

# === 常量 ===
const PATH_CACHE_TIME := 0.5
const PATH_RECALC_DIST := 50.0
const MAX_PATH_LENGTH := 30
const WAYPOINT_REACH_DIST := 12.0
const SMOOTH_STEP_SIZE := 16.0  # 路径平滑步长（对标 TC SMOOTH_PATH_STEP_SIZE）
const LOS_COLLISION_MASK := 1   # LoS 检测的碰撞层（GamePack 可配置）

# === 地形层（对标 TC NavTerrainFlag，通过 navigation_layers bitmask）===
const TERRAIN_GROUND := 1       # 地面
const TERRAIN_WATER  := 2       # 水面
const TERRAIN_CLIFF  := 4       # 悬崖/不可通行

# === Navigation ===
var _nav_map_rid: RID = RID()
var _nav_ready: bool = false
var los_collision_mask: int = LOS_COLLISION_MASK

# === 路径缓存 ===
var _path_cache: Dictionary = {}

func _ready() -> void:
	EngineAPI.register_system("pathfinding", self)
	# 延迟获取导航地图（场景可能还没完全加载）
	call_deferred("_init_nav_map")
	EventBus.connect_event("entity_destroyed", _on_entity_destroyed)

func _init_nav_map() -> void:
	var maps: Array[RID] = NavigationServer3D.get_maps()
	if maps.size() > 0:
		_nav_map_rid = maps[0]
		_nav_ready = true

func _process(delta: float) -> void:
	for eid in _path_cache:
		_path_cache[eid]["age"] = _path_cache[eid].get("age", 0.0) + delta

func _reset() -> void:
	_path_cache.clear()

# === 寻路 API ===

func find_path(from: Vector3, to: Vector3, _terrain_mask: int = TERRAIN_GROUND) -> PackedVector3Array:
	## 获取导航路径
	if not _nav_ready:
		return PackedVector3Array([from, to])
	var path: PackedVector3Array = NavigationServer3D.map_get_path(
		_nav_map_rid, from, to, true)
	if path.size() > MAX_PATH_LENGTH:
		path.resize(MAX_PATH_LENGTH)
	if path.size() > 2:
		path = _smooth_path(path)
	return path

func get_next_waypoint(entity: GameEntity, target_pos: Vector3) -> Vector3:
	## 获取下一个路径点（带缓存）
	if not is_instance_valid(entity):
		return target_pos
	var eid: int = entity.get_instance_id()
	var cache: Dictionary = _path_cache.get(eid, {})
	var from: Vector3 = entity.global_position
	var need_recalc := false
	if cache.is_empty():
		need_recalc = true
	elif cache.get("target_pos", Vector3.ZERO).distance_to(target_pos) > PATH_RECALC_DIST:
		need_recalc = true
	elif cache.get("age", 999.0) > PATH_CACHE_TIME:
		need_recalc = true
	if need_recalc:
		var new_path: PackedVector3Array = find_path(from, target_pos)
		cache = {
			"path": new_path,
			"current_index": 1,
			"target_pos": target_pos,
			"age": 0.0,
		}
		_path_cache[eid] = cache
	var path: PackedVector3Array = cache.get("path", PackedVector3Array())
	var idx: int = cache.get("current_index", 0)
	if path.size() == 0 or idx >= path.size():
		return target_pos
	while idx < path.size() and from.distance_to(path[idx]) < WAYPOINT_REACH_DIST:
		idx += 1
	cache["current_index"] = idx
	if idx >= path.size():
		return target_pos
	return path[idx]

func get_direction(entity: GameEntity, target_pos: Vector3) -> Vector3:
	## 获取移动方向（已寻路）
	var waypoint: Vector3 = get_next_waypoint(entity, target_pos)
	return entity.global_position.direction_to(waypoint)

func clear_path_cache(entity: GameEntity) -> void:
	if is_instance_valid(entity):
		_path_cache.erase(entity.get_instance_id())

func is_path_reachable(_from: Vector3, to: Vector3) -> bool:
	if not _nav_ready:
		return true
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(
		_nav_map_rid, to)
	return closest.distance_to(to) < 20.0

func has_navigation() -> bool:
	return _nav_ready

# === 路径平滑（对标 TC FindSmoothPath）===

func _smooth_path(raw_path: PackedVector3Array) -> PackedVector3Array:
	## 将锯齿路径点平滑为更自然的曲线
	if raw_path.size() <= 2:
		return raw_path
	var smooth := PackedVector3Array()
	smooth.append(raw_path[0])
	var i := 0
	while i < raw_path.size() - 1:
		var start: Vector3 = raw_path[i]
		# 尝试跳过中间点：如果可以直达更远的点，就跳过
		var farthest: int = i + 1
		for j in range(i + 2, mini(i + 6, raw_path.size())):
			if not _is_blocked(start, raw_path[j]):
				farthest = j
		smooth.append(raw_path[farthest])
		i = farthest
	return smooth

func _is_blocked(from: Vector3, to: Vector3) -> bool:
	## 用 NavigationServer 检查两点之间是否有障碍
	if not _nav_ready:
		return false
	# 简单检查：中间点是否在导航网格上
	var mid: Vector3 = (from + to) * 0.5
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(_nav_map_rid, mid)
	return closest.distance_to(mid) > 15.0

# === LoS 视线检查（对标 TC VMAP IsInLineOfSight）===

func has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	## 检查两点之间是否有视线（无物理障碍物阻挡）
	var space_state: PhysicsDirectSpaceState3D = _get_space_state()
	if space_state == null:
		return true  # 无物理空间 = 不检查
	var query := PhysicsRayQueryParameters3D.create(from, to, los_collision_mask)
	var result: Dictionary = space_state.intersect_ray(query)
	return result.is_empty()

func has_line_of_sight_entity(source: GameEntity, target: GameEntity) -> bool:
	## 两个实体之间的视线检查
	if not is_instance_valid(source) or not is_instance_valid(target):
		return false
	return has_line_of_sight(source.global_position, target.global_position)

func _get_space_state() -> PhysicsDirectSpaceState3D:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	var world: World3D = viewport.world_3d
	if world == null:
		return null
	return world.direct_space_state

# === 动态障碍物 ===

func add_obstacle(position: Vector3, radius: float) -> RID:
	if not _nav_ready:
		return RID()
	var obstacle_rid: RID = NavigationServer3D.obstacle_create()
	NavigationServer3D.obstacle_set_map(obstacle_rid, _nav_map_rid)
	NavigationServer3D.obstacle_set_radius(obstacle_rid, radius)
	NavigationServer3D.obstacle_set_position(obstacle_rid, position)
	NavigationServer3D.obstacle_set_avoidance_enabled(obstacle_rid, true)
	return obstacle_rid

func remove_obstacle(obstacle_rid: RID) -> void:
	if obstacle_rid.is_valid():
		NavigationServer3D.free_rid(obstacle_rid)

func update_obstacle_position(obstacle_rid: RID, position: Vector3) -> void:
	if obstacle_rid.is_valid():
		NavigationServer3D.obstacle_set_position(obstacle_rid, position)

func _on_entity_destroyed(data: Dictionary) -> void:
	var entity = data.get("entity")
	if entity != null and entity is GameEntity:
		_path_cache.erase((entity as GameEntity).get_instance_id())
