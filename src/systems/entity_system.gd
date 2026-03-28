## EntitySystem - 通用实体生命周期管理
## 负责创建/销毁/查询实体，不包含任何游戏类型特定逻辑
class_name EntitySystem
extends Node2D

const ENTITY_SCENE := preload("res://src/entity/game_entity.tscn")

var _entities: Dictionary = {}  # runtime_id -> GameEntity
var _next_id: int = 1
var _entity_container: Node2D = null

func _ready() -> void:
	_entity_container = Node2D.new()
	_entity_container.name = "Entities"
	add_child(_entity_container)
	EngineAPI.register_system("entity", self)

# === 创建 ===

func spawn(def_id: String, pos: Vector2 = Vector2.ZERO, overrides: Dictionary = {}) -> GameEntity:
	var def := DataRegistry.get_def("entities", def_id)
	if def.is_empty():
		push_error("[EntitySystem] Entity def '%s' not found" % def_id)
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
		return
	var component: Node = comp_registry.call("create_component", comp_name, comp_data)
	if component:
		entity.add_component(comp_name, component)

# === 销毁 ===

func destroy(entity: GameEntity) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	EventBus.emit_event("entity_destroyed", {"entity": entity})

	# 从 StatSystem 注销
	var stat_system := EngineAPI.get_system("stat")
	if stat_system:
		stat_system.call("unregister_entity", entity)

	_entities.erase(entity.runtime_id)
	entity.queue_free()

# === 查询 ===

func get_by_id(runtime_id: int) -> GameEntity:
	return _entities.get(runtime_id)

func query_by_tag(tag: String) -> Array[GameEntity]:
	var result: Array[GameEntity] = []
	for entity: GameEntity in _entities.values():
		if is_instance_valid(entity) and entity.has_tag(tag):
			result.append(entity)
	return result

func query_in_area(center: Vector2, radius: float, filter_tag: String = "") -> Array[GameEntity]:
	var result: Array[GameEntity] = []
	var radius_sq := radius * radius
	for entity: GameEntity in _entities.values():
		if not is_instance_valid(entity):
			continue
		if filter_tag != "" and not entity.has_tag(filter_tag):
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
