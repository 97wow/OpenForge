## UnitSystem - 单位管理
## 负责创建/销毁塔防单位（防御塔、敌人）
class_name UnitSystem
extends Node2D

@onready var tower_container := Node2D.new()
@onready var enemy_container := Node2D.new()
@onready var projectile_container := Node2D.new()

var _tower_scene: PackedScene = preload("res://src/entities/towers/base_tower.tscn")
var _enemy_scene: PackedScene = preload("res://src/entities/enemies/base_enemy.tscn")

func _ready() -> void:
	tower_container.name = "Towers"
	enemy_container.name = "Enemies"
	projectile_container.name = "Projectiles"
	add_child(tower_container)
	add_child(enemy_container)
	add_child(projectile_container)

func spawn_tower(tower_id: String, grid_pos: Vector2i) -> Node2D:
	var data := DataManager.get_tower(tower_id)
	if data.is_empty():
		return null
	var tower := _tower_scene.instantiate() as Node2D
	tower.position = GameEngine.grid_system.grid_to_world(grid_pos)
	tower.setup(tower_id, data, grid_pos)
	tower_container.add_child(tower)
	return tower

func spawn_enemy(enemy_id: String, path_index: int = -1) -> Node2D:
	var data := DataManager.get_enemy(enemy_id)
	if data.is_empty():
		return null
	var path := GameEngine.path_system.get_path(path_index)
	if path == null:
		push_error("UnitSystem: No path available for enemy spawn")
		return null
	var enemy := _enemy_scene.instantiate() as Node2D
	enemy.setup(enemy_id, data, path)
	enemy_container.add_child(enemy)
	EventBus.enemy_spawned.emit(enemy)
	return enemy

func get_enemies_in_range(center: Vector2, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var radius_sq := radius * radius
	for enemy in enemy_container.get_children():
		if enemy is Node2D and is_instance_valid(enemy):
			if center.distance_squared_to(enemy.global_position) <= radius_sq:
				result.append(enemy)
	return result

func get_all_enemies() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for enemy in enemy_container.get_children():
		if is_instance_valid(enemy):
			result.append(enemy as Node2D)
	return result

func get_all_towers() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for tower in tower_container.get_children():
		if is_instance_valid(tower):
			result.append(tower as Node2D)
	return result
