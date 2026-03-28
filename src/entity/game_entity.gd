## GameEntity - 通用游戏实体
## 所有游戏对象的基类，通过 tags + components 定义行为
## "塔"、"敌人"、"英雄" 只是不同的 tag 组合
class_name GameEntity
extends Node2D

var runtime_id: int = -1
var def_id: String = ""
var tags: PackedStringArray = []
var meta: Dictionary = {}  # 存储非组件的自定义数据（cost, tier 等）

var _components: Dictionary = {}  # component_name -> Node

# === 初始化 ===

func setup(id: String, def: Dictionary, overrides: Dictionary = {}) -> void:
	def_id = id
	name = "%s_%d" % [id, runtime_id]

	# 应用 tags
	var tag_array: Array = def.get("tags", [])
	for tag in tag_array:
		tags.append(str(tag))

	# 覆盖 tags
	for tag in overrides.get("tags", []):
		if str(tag) not in tags:
			tags.append(str(tag))

	# 存储 meta 数据
	meta = def.get("meta", {}).duplicate()
	meta.merge(overrides.get("meta", {}), true)

# === Tag 操作 ===

func has_tag(tag: String) -> bool:
	return tag in tags

func add_tag(tag: String) -> void:
	if tag not in tags:
		tags.append(tag)

func remove_tag(tag: String) -> void:
	var idx := tags.find(tag)
	if idx >= 0:
		tags.remove_at(idx)

func get_tags() -> PackedStringArray:
	return tags

# === 组件操作 ===

func get_component(component_name: String) -> Node:
	return _components.get(component_name)

func has_component(component_name: String) -> bool:
	return _components.has(component_name)

func add_component(component_name: String, component: Node) -> void:
	if _components.has(component_name):
		remove_component(component_name)
	_components[component_name] = component
	component.name = component_name.to_pascal_case() + "Component"
	add_child(component)
	# 让组件知道自己的宿主
	if component.has_method("_on_attached"):
		component.call("_on_attached", self)

func remove_component(component_name: String) -> void:
	if not _components.has(component_name):
		return
	var component: Node = _components[component_name]
	if component.has_method("_on_detached"):
		component.call("_on_detached")
	_components.erase(component_name)
	component.queue_free()

func get_all_components() -> Dictionary:
	return _components.duplicate()

# === 便捷访问 ===

func get_meta_value(key: String, default: Variant = null) -> Variant:
	return meta.get(key, default)

func set_meta_value(key: String, value: Variant) -> void:
	meta[key] = value
