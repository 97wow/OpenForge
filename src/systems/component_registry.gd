## ComponentRegistry - 组件类型注册与工厂
## 将组件类型名映射到脚本，支持内置组件和 GamePack 自定义组件
class_name ComponentRegistry
extends Node

# type_name -> { script_path, scene_path }
var _registry: Dictionary = {}
# 缓存已加载的脚本
var _script_cache: Dictionary = {}

func _ready() -> void:
	EngineAPI.register_system("component_registry", self)
	_register_builtin_components()

func _register_builtin_components() -> void:
	var base := "res://src/entity/components/"
	register_component("health", base + "health_component.gd")
	register_component("movement", base + "movement_component.gd")
	register_component("combat", base + "combat_component.gd")
	register_component("path_follow", base + "path_follow_component.gd")
	register_component("visual", base + "visual_component.gd")
	register_component("collision", base + "collision_component.gd")
	register_component("player_input", base + "player_input_component.gd")
	register_component("projectile", base + "projectile_component.gd")
	register_component("ai_move_to", base + "ai_move_to_component.gd")
	register_component("alert", base + "alert_component.gd")

# === 注册 ===

func register_component(type_name: String, script_path: String, scene_path: String = "") -> void:
	_registry[type_name] = {
		"script_path": script_path,
		"scene_path": scene_path,
	}

func unregister_component(type_name: String) -> void:
	_registry.erase(type_name)
	_script_cache.erase(type_name)

func has_component_type(type_name: String) -> bool:
	return _registry.has(type_name)

# === 创建 ===

func create_component(type_name: String, data: Dictionary = {}) -> Node:
	if not _registry.has(type_name):
		push_warning("[ComponentRegistry] Unknown component type: %s" % type_name)
		return null

	var info: Dictionary = _registry[type_name]
	var component: Node = null

	# 如果有场景模板，优先用场景
	if info["scene_path"] != "":
		var scene := load(info["scene_path"]) as PackedScene
		if scene:
			component = scene.instantiate()
	else:
		# 用脚本创建
		var script: GDScript = _get_script(type_name)
		if script:
			component = Node.new()
			component.set_script(script)

	if component == null:
		push_error("[ComponentRegistry] Failed to create component: %s" % type_name)
		return null

	# 调用 setup
	if component.has_method("setup"):
		component.call("setup", data)

	return component

func _get_script(type_name: String) -> GDScript:
	if _script_cache.has(type_name):
		return _script_cache[type_name]
	var info: Dictionary = _registry[type_name]
	var script := load(info["script_path"]) as GDScript
	if script:
		_script_cache[type_name] = script
	return script

# === 查询 ===

func get_registered_types() -> Array[String]:
	var result: Array[String] = []
	for key in _registry:
		result.append(key)
	return result
