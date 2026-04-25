## PickupComponent — 自动/手动拾取掉落物
## 周期性扫描 "loot_entities" group 内的 LootEntity
## 自动拾取在 auto_pickup_radius 内，手动拾取在 interact_radius 内
extends Node

var _entity: Node3D = null
var auto_pickup_radius: float = 0.6
var interact_radius: float = 1.2
var auto_pickup_enabled: bool = true
var _scan_timer: float = 0.0
const SCAN_INTERVAL := 0.2

func setup(data: Dictionary) -> void:
	auto_pickup_radius = data.get("auto_pickup_radius", 0.6)
	interact_radius = data.get("interact_radius", 1.2)
	auto_pickup_enabled = data.get("auto_pickup_enabled", true)

func _on_attached(entity: Node3D) -> void:
	_entity = entity

func _process(delta: float) -> void:
	if not auto_pickup_enabled:
		return
	if _entity == null or not is_instance_valid(_entity):
		return
	_scan_timer += delta
	if _scan_timer < SCAN_INTERVAL:
		return
	_scan_timer -= SCAN_INTERVAL
	_scan_and_pickup(auto_pickup_radius)

func interact_pickup() -> void:
	## 手动拾取：拾取 interact_radius 内最近的掉落物
	if _entity == null or not is_instance_valid(_entity):
		return
	var closest: LootEntity = _find_closest_loot(interact_radius)
	if closest:
		_try_pickup(closest)

func _scan_and_pickup(radius: float) -> void:
	var my_pos: Vector3 = _entity.global_position
	var radius_sq: float = radius * radius
	for node in _entity.get_tree().get_nodes_in_group("loot_entities"):
		if not is_instance_valid(node) or not (node is LootEntity):
			continue
		var loot: LootEntity = node as LootEntity
		if loot._picked_up:
			continue
		if my_pos.distance_squared_to(loot.global_position) <= radius_sq:
			_try_pickup(loot)

func _find_closest_loot(radius: float) -> LootEntity:
	var my_pos: Vector3 = _entity.global_position
	var radius_sq: float = radius * radius
	var closest: LootEntity = null
	var closest_dist := INF
	for node in _entity.get_tree().get_nodes_in_group("loot_entities"):
		if not is_instance_valid(node) or not (node is LootEntity):
			continue
		var loot: LootEntity = node as LootEntity
		if loot._picked_up:
			continue
		var d: float = my_pos.distance_squared_to(loot.global_position)
		if d <= radius_sq and d < closest_dist:
			closest_dist = d
			closest = loot
	return closest

func _try_pickup(loot: LootEntity) -> void:
	var item_sys: Node = EngineAPI.get_system("item")
	if item_sys == null:
		return
	# 背包满检查
	if item_sys.call("inventory_is_full", _entity):
		return  # inventory_full 事件由 inventory_add 发出
	var item: Dictionary = loot.pickup()
	if item.is_empty():
		return
	item_sys.call("inventory_add", _entity, item)
