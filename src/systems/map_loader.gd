## MapLoader — 从 .tscn 场景文件加载地图
## 读取 Marker3D 节点作为刷怪点、地标、路径点等
## 框架层系统，零游戏知识
class_name MapLoader
extends Node

var _map_root: Node3D = null
var _spawn_points: Array[Vector3] = []
var _landmarks: Dictionary = {}  # name -> Vector3

func _ready() -> void:
	EngineAPI.register_system("map_loader", self)

## 加载地图场景并解析标记点
func load_map(map_path: String) -> Node3D:
	if not ResourceLoader.exists(map_path):
		push_error("[MapLoader] Map not found: %s" % map_path)
		return null
	var scene := load(map_path) as PackedScene
	if scene == null:
		push_error("[MapLoader] Failed to load map: %s" % map_path)
		return null

	_map_root = scene.instantiate() as Node3D
	var main_node: Node3D = get_tree().current_scene as Node3D
	if main_node:
		main_node.add_child(_map_root)
		main_node.move_child(_map_root, 0)

	# 解析刷怪点
	_spawn_points.clear()
	var spawn_container := _map_root.get_node_or_null("SpawnPoints")
	if spawn_container:
		for child in spawn_container.get_children():
			if child is Marker3D:
				_spawn_points.append(child.global_position)

	# 解析地标
	_landmarks.clear()
	var landmark_container := _map_root.get_node_or_null("Landmarks")
	if landmark_container:
		for child in landmark_container.get_children():
			if child is Marker3D:
				_landmarks[child.name] = child.global_position

	print("[MapLoader] Loaded map: %s | %d spawns | %d landmarks" % [
		map_path, _spawn_points.size(), _landmarks.size()
	])
	return _map_root

## 获取所有刷怪点位置
func get_spawn_points() -> Array[Vector3]:
	return _spawn_points

## 获取地标位置（如 "PlayerBase", "HeroStart"）
func get_landmark(landmark_name: String, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	return _landmarks.get(landmark_name, fallback)

## 获取地图根节点（用于动态添加道具等）
func get_map_root() -> Node3D:
	return _map_root

## 获取 Props 容器（用于放置装饰物）
func get_props_container() -> Node3D:
	if _map_root:
		var props := _map_root.get_node_or_null("Props")
		if props:
			return props
	return _map_root

func _reset() -> void:
	_spawn_points.clear()
	_landmarks.clear()
	if _map_root and is_instance_valid(_map_root):
		_map_root.queue_free()
	_map_root = null
