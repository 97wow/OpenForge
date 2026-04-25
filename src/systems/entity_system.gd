## EntitySystem - 通用实体生命周期管理
## 负责创建/销毁/查询实体，不包含任何游戏类型特定逻辑
class_name EntitySystem
extends Node3D

const ENTITY_SCENE := preload("res://src/entity/game_entity.tscn")

var _entities: Dictionary = {}  # runtime_id -> GameEntity
var _next_id: int = 1
var _entity_container: Node3D = null

# === 空间哈希网格（O(1) 区域查询）===
const CELL_SIZE := 1.28  # 网格单元大小（米）
var _spatial_grid: Dictionary = {}  # Vector2i -> Array[GameEntity]
var _entity_cells: Dictionary = {}  # runtime_id -> Vector2i（实体当前所在格子）
var _grid_frame: int = -1  # 上次更新帧号

# 按 faction 索引的缓存
var _faction_cache: Dictionary = {}  # faction -> Array[GameEntity]
var _faction_cache_frame: int = -1

# MultiMesh 批量渲染
var _multi_mesh_instance: MultiMeshInstance3D = null
var _multi_mesh: MultiMesh = null
const MAX_MULTIMESH_ENTITIES := 2000

func _ready() -> void:
	_entity_container = Node3D.new()
	_entity_container.name = "Entities"
	add_child(_entity_container)
	_setup_multimesh()
	EngineAPI.register_system("entity", self)

func _setup_multimesh() -> void:
	## 创建 MultiMesh 用于批量渲染实体占位符
	_multi_mesh = MultiMesh.new()
	_multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_multi_mesh.use_colors = true
	_multi_mesh.instance_count = MAX_MULTIMESH_ENTITIES
	_multi_mesh.visible_instance_count = 0
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)  # 3D 世界单位
	_multi_mesh.mesh = quad
	_multi_mesh_instance = MultiMeshInstance3D.new()
	_multi_mesh_instance.multimesh = _multi_mesh
	# 使用 billboard 材质让 quad 始终面向相机
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_multi_mesh_instance.material_override = mat
	add_child(_multi_mesh_instance)

# === 中心化更新（替代每个组件的 _process）===

func _process(delta: float) -> void:
	if EngineAPI.get_game_state() != "playing":
		return
	# 清理无效实体引用（防止泄漏）
	var stale_ids: Array[int] = []
	for rid: int in _entities:
		var e: GameEntity = _entities[rid]
		if e == null or not is_instance_valid(e):
			stale_ids.append(rid)
	for rid in stale_ids:
		_entities.erase(rid)
	# 一次循环更新所有实体的核心组件
	for entity: GameEntity in _entities.values():
		if not is_instance_valid(entity):
			continue
		_tick_entity(entity, delta)

func _tick_entity(entity: GameEntity, delta: float) -> void:
	# --- Lifespan (TempSummon timer) ---
	if entity.lifespan > 0:
		entity._lifespan_timer += delta
		if entity._lifespan_timer >= entity.lifespan:
			entity.is_alive = false
			destroy(entity)
			return

	# --- Separation (软碰撞：同阵营实体最小间距，防止重叠) ---
	if entity.has_tag("mobile"):
		var sep_radius: float = 0.6
		var cell: Vector2i = _pos_to_cell(entity.global_position)
		var push := Vector3.ZERO
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var nc := Vector2i(cell.x + dx, cell.y + dy)
				if not _spatial_grid.has(nc):
					continue
				for other in _spatial_grid[nc]:
					if other == entity or not is_instance_valid(other) or not other.is_alive:
						continue
					if other.has_tag("projectile"):
						continue
					var diff: Vector3 = entity.global_position - other.global_position
					diff.y = 0.0  # 地面分离，忽略 Y 轴
					var dist_sq: float = diff.length_squared()
					if dist_sq < sep_radius * sep_radius and dist_sq > 0.01:
						push += diff.normalized() * (sep_radius - sqrt(dist_sq))
		if push.length_squared() > 0.01:
			entity.position += push.normalized() * minf(push.length(), 0.05)

	# --- 死亡实体跳过所有逻辑（等待死亡序列销毁）---
	if not entity.is_alive:
		var mv_dead: Node = entity.get_component("movement")
		if mv_dead and mv_dead.get("velocity") != null:
			mv_dead.velocity = Vector3.ZERO
		return

	# --- Movement（ROOTED/STUNNED 阻止自主移动）---
	var movement: Node = entity.get_component("movement")
	if movement and movement.velocity != Vector3.ZERO:
		if entity.has_any_flag(UnitFlags.MOVEMENT_PREVENTING):
			movement.velocity = Vector3.ZERO
		else:
			entity.position += movement.velocity * delta
			if movement.velocity.length_squared() > 0.001:
				movement.facing_direction = movement.velocity.normalized()
				# 实体朝向移动方向（Y 轴平滑旋转）
				var look_dir := Vector3(movement.velocity.x, 0, movement.velocity.z)
				if look_dir.length_squared() > 0.001:
					var target_angle := atan2(look_dir.x, look_dir.z)
					entity.rotation.y = lerp_angle(entity.rotation.y, target_angle, 0.15)

	# --- Mana Regen ---
	if entity.is_alive:
		var health: Node = entity.get_component("health")
		if health and health.get("mp_regen") != null and health.mp_regen > 0:
			health.current_mp = minf(health.current_mp + health.mp_regen * delta, health.max_mp)

	# --- AI 状态机（对标 TrinityCore CreatureAI）---
	var ai: Node = entity.get_component("ai_move_to")
	if ai and ai.target_tag != "":
		var ai_state: int = entity.meta.get("ai_state", 0)
		match ai_state:
			0: _tick_ai_idle(entity, ai, movement, delta)    # IDLE
			1: _tick_ai_combat(entity, ai, movement, delta)  # COMBAT
			2: _tick_ai_evading(entity, ai, movement)        # EVADING
			3:                                                 # HOME（ThreatManager 处理）
				if movement: movement.velocity = Vector3.ZERO

	# --- Combat（STUNNED/FEARED/EVADING 阻止攻击）---
	var combat: Node = entity.get_component("combat")
	if combat and combat.attack_speed > 0:
		if entity.has_any_flag(UnitFlags.ATTACK_PREVENTING) or entity.has_unit_flag(UnitFlags.EVADING):
			combat._attack_timer = 0.0
		else:
			combat._attack_timer += delta
			if combat._attack_timer >= 1.0 / combat.attack_speed:
				combat._attack_timer = 0.0
				combat._try_attack()

# === 创建 ===

func spawn(def_id: String, pos: Vector3 = Vector3.ZERO, overrides: Dictionary = {}) -> GameEntity:
	var def: Dictionary = DataRegistry.get_def("entities", def_id)
	if def.is_empty():
		push_error("[EntitySystem] Entity def '%s' not found" % def_id)
		DebugOverlay.log_error("EntitySystem", "Entity def '%s' not found" % def_id)
		return null

	var entity: GameEntity = ENTITY_SCENE.instantiate()
	entity.runtime_id = _next_id
	_next_id += 1
	entity.position = pos
	entity.setup(def_id, def, overrides)

	# 附加组件
	var components: Dictionary = def.get("components", {})
	var comp_overrides: Dictionary = overrides.get("components", {})
	for comp_name in components:
		var comp_data: Dictionary = (components[comp_name] as Dictionary).duplicate()
		if comp_overrides.has(comp_name):
			comp_data.merge(comp_overrides[comp_name], true)
		_attach_component(entity, comp_name, comp_data)

	# 注册到 StatSystem
	var stat_system := EngineAPI.get_system("stat")
	if stat_system and def.get("components", {}).has("stat"):
		var stat_data: Dictionary = def["components"].get("stat", {})
		stat_system.call("register_entity", entity, stat_data.get("base_stats", {}))

	_entities[entity.runtime_id] = entity
	_entity_container.add_child(entity)

	EventBus.emit_event("entity_spawned", {"entity": entity})
	return entity

func _attach_component(entity: GameEntity, comp_name: String, comp_data: Dictionary) -> void:
	var comp_registry := EngineAPI.get_system("component_registry")
	if comp_registry == null:
		push_error("[EntitySystem] ComponentRegistry not registered")
		DebugOverlay.log_error("EntitySystem", "ComponentRegistry not registered")
		return
	var component: Node = comp_registry.call("create_component", comp_name, comp_data)
	if component:
		entity.add_component(comp_name, component)

# === 销毁 ===

func destroy(entity: GameEntity, source: Node3D = null) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	# 防止重复销毁
	if not _entities.has(entity.runtime_id):
		return
	_entities.erase(entity.runtime_id)
	EventBus.emit_event("entity_destroyed", {"entity": entity, "source": source})

	# 从 StatSystem 注销
	var stat_system := EngineAPI.get_system("stat")
	if stat_system:
		stat_system.call("unregister_entity", entity)

	entity.queue_free()

# === 查询 ===

func get_by_id(runtime_id: int) -> GameEntity:
	return _entities.get(runtime_id)

var _tag_cache: Dictionary = {}  # tag -> Array[GameEntity]
var _tag_cache_frame: int = -1

func query_by_tag(tag: String) -> Array[GameEntity]:
	## 带帧缓存的 tag 查询——同一帧内相同 tag 只遍历一次
	var frame: int = Engine.get_process_frames()
	if frame != _tag_cache_frame:
		_tag_cache_frame = frame
		_tag_cache.clear()
	if _tag_cache.has(tag):
		return _tag_cache[tag]
	var result: Array[GameEntity] = []
	for entity: GameEntity in _entities.values():
		if is_instance_valid(entity) and entity.is_alive and entity.has_tag(tag):
			result.append(entity)
	_tag_cache[tag] = result
	return result

func query_in_area(center: Vector3, radius: float, filter_tag: String = "") -> Array[GameEntity]:
	## 使用空间哈希网格的 O(K) 区域查询（K = 附近格子中的实体数）
	_rebuild_spatial_grid()
	var result: Array[GameEntity] = []
	var radius_sq := radius * radius
	var cells: Array[Vector2i] = _get_cells_in_radius(center, radius)
	for cell in cells:
		if not _spatial_grid.has(cell):
			continue
		for entry in _spatial_grid[cell]:
			if not is_instance_valid(entry) or not (entry is GameEntity):
				continue
			var entity: GameEntity = entry as GameEntity
			if not entity.is_alive:
				continue
			if filter_tag != "" and not entity.has_tag(filter_tag):
				continue
			if center.distance_squared_to(entity.global_position) <= radius_sq:
				result.append(entity)
	return result

## === 空间哈希网格 ===

func _pos_to_cell(pos: Vector3) -> Vector2i:
	## 空间哈希用 XZ 平面（Y 轴为高度，地面游戏忽略）
	@warning_ignore("narrowing_conversion")
	return Vector2i(int(floor(pos.x / CELL_SIZE)), int(floor(pos.z / CELL_SIZE)))

func _rebuild_spatial_grid() -> void:
	## 每帧重建一次空间网格（O(N)，但只做一次）
	var frame: int = Engine.get_process_frames()
	if frame == _grid_frame:
		return
	_grid_frame = frame
	_spatial_grid.clear()
	_entity_cells.clear()
	for entity: GameEntity in _entities.values():
		if not is_instance_valid(entity) or not entity.is_alive or entity.has_tag("projectile"):
			continue
		var cell: Vector2i = _pos_to_cell(entity.global_position)
		if not _spatial_grid.has(cell):
			_spatial_grid[cell] = []
		_spatial_grid[cell].append(entity)
		_entity_cells[entity.runtime_id] = cell

func _get_cells_in_radius(center: Vector3, radius: float) -> Array[Vector2i]:
	## 获取 XZ 平面圆形范围覆盖的所有网格单元
	var cells: Array[Vector2i] = []
	# 安全上限：超大半径回退到遍历所有已有格子
	var max_cells_per_axis := 100
	var min_cell: Vector2i = _pos_to_cell(center - Vector3(radius, 0, radius))
	var max_cell: Vector2i = _pos_to_cell(center + Vector3(radius, 0, radius))
	if (max_cell.x - min_cell.x) > max_cells_per_axis or (max_cell.y - min_cell.y) > max_cells_per_axis:
		var all_cells: Array[Vector2i] = []
		for k in _spatial_grid.keys():
			all_cells.append(k as Vector2i)
		return all_cells
	for cx in range(min_cell.x, max_cell.x + 1):
		for cy in range(min_cell.y, max_cell.y + 1):
			cells.append(Vector2i(cx, cy))
	return cells

func _refresh_faction_cache() -> void:
	var frame: int = Engine.get_process_frames()
	if frame == _faction_cache_frame:
		return
	_faction_cache_frame = frame
	_faction_cache.clear()
	for entity: GameEntity in _entities.values():
		if not is_instance_valid(entity):
			continue
		var f: String = entity.faction
		if not _faction_cache.has(f):
			_faction_cache[f] = []
		_faction_cache[f].append(entity)

func query_hostiles_in_area(source: GameEntity, center: Vector3, radius: float) -> Array[GameEntity]:
	## 空间哈希 + is_hostile_to 检查（支持多阵营）
	_rebuild_spatial_grid()
	var result: Array[GameEntity] = []
	var radius_sq := radius * radius
	var cells: Array[Vector2i] = _get_cells_in_radius(center, radius)
	for cell in cells:
		if not _spatial_grid.has(cell):
			continue
		for entry in _spatial_grid[cell]:
			if not is_instance_valid(entry) or not (entry is GameEntity):
				continue
			var entity: GameEntity = entry as GameEntity
			if entity == source:
				continue
			if not source.is_hostile_to(entity):
				continue
			if not TargetUtil.is_valid_attack_target(source, entity):
				continue
			if center.distance_squared_to(entity.global_position) <= radius_sq:
				result.append(entity)
	return result

func query_allies_in_area(source: GameEntity, center: Vector3, radius: float) -> Array[GameEntity]:
	## 空间哈希 + is_friendly_to 检查（支持多阵营）
	_rebuild_spatial_grid()
	var result: Array[GameEntity] = []
	var radius_sq := radius * radius
	var cells: Array[Vector2i] = _get_cells_in_radius(center, radius)
	for cell in cells:
		if not _spatial_grid.has(cell):
			continue
		for entry in _spatial_grid[cell]:
			if not is_instance_valid(entry) or not (entry is GameEntity):
				continue
			var entity: GameEntity = entry as GameEntity
			if not source.is_friendly_to(entity):
				continue
			if not TargetUtil.is_valid_assist_target(source, entity):
				continue
			if center.distance_squared_to(entity.global_position) <= radius_sq:
				result.append(entity)
	return result

func query_all() -> Array[GameEntity]:
	var result: Array[GameEntity] = []
	for entity: GameEntity in _entities.values():
		if is_instance_valid(entity):
			result.append(entity)
	return result

func get_entity_count() -> int:
	return _entities.size()

func get_entity_count_by_tag(tag: String) -> int:
	var count := 0
	for entity: GameEntity in _entities.values():
		if is_instance_valid(entity) and entity.has_tag(tag):
			count += 1
	return count

# === AI 状态机辅助方法（对标 TrinityCore CreatureAI）===

func _tick_ai_idle(entity: GameEntity, ai: Node, movement: Node, delta: float) -> void:
	## IDLE 状态：按距离找最近敌对目标（向后兼容原有行为）
	ai._search_timer += delta
	if ai.target_entity == null or not TargetUtil.is_valid_attack_target(entity, ai.target_entity) or ai._search_timer >= ai.SEARCH_INTERVAL:
		if ai._search_timer >= ai.SEARCH_INTERVAL:
			ai._search_timer = 0.0
		ai._reached = false
		ai.target_entity = ai._find_target()
		if ai.target_entity == null:
			if movement:
				movement.velocity = Vector3.ZERO
			return
	_chase_target(entity, ai, movement)

func _tick_ai_combat(entity: GameEntity, ai: Node, movement: Node, delta: float) -> void:
	## COMBAT 状态：仇恨驱动目标选择
	ai._search_timer += delta
	if ai._search_timer >= ai.SEARCH_INTERVAL:
		ai._search_timer = 0.0
		# 从 ThreatManager 获取仇恨最高目标
		var victim: Node3D = EngineAPI.get_threat_victim(entity)
		if victim:
			ai.target_entity = victim
		else:
			# 仇恨列表空，ThreatManager 的 _check_evade_and_home 会处理状态转换
			# 临时 fallback 到距离寻敌
			ai.target_entity = ai._find_target()
	if ai.target_entity == null or not TargetUtil.is_valid_attack_target(entity, ai.target_entity):
		if movement:
			movement.velocity = Vector3.ZERO
		return
	_chase_target(entity, ai, movement)

func _tick_ai_evading(entity: GameEntity, ai: Node, movement: Node) -> void:
	## EVADING 状态：跑回 home_position（进入战斗时的位置，对标 TrinityCore MoveTargetedHome）
	ai.target_entity = null
	ai._reached = false
	var home_pos: Vector3 = entity.meta.get("home_position", entity.meta.get("spawn_position", entity.global_position))
	if movement:
		var dir: Vector3 = entity.global_position.direction_to(home_pos)
		movement.velocity = dir * movement.current_speed

func _chase_target(entity: GameEntity, ai: Node, movement: Node) -> void:
	## 通用追击逻辑：在攻击范围内停下，否则靠近
	var dist: float = entity.global_position.distance_to(ai.target_entity.global_position)
	if dist <= ai.attack_range:
		if movement:
			movement.velocity = Vector3.ZERO
		if not ai._reached:
			ai._reached = true
			EventBus.emit_event("ai_reached_target", {"entity": entity, "target": ai.target_entity})
	else:
		ai._reached = false
		var dir: Vector3 = entity.global_position.direction_to(ai.target_entity.global_position)
		if movement:
			movement.velocity = dir * movement.current_speed
