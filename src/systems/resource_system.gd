## ResourceSystem - 通用命名资源管理
## "金币"、"生命"、"法力"、"积分" 都只是不同名字的资源
## GamePack 通过 define_resource() 定义自己需要的资源
class_name ResourceSystem
extends Node

# name -> { value, min, max }
var _resources: Dictionary = {}

func _ready() -> void:
	EngineAPI.register_system("resource", self)

# === 定义 ===

func define_resource(name: String, initial: float = 0.0, max_val: float = INF) -> void:
	_resources[name] = {
		"value": initial,
		"min": 0.0,
		"max": max_val,
	}

func undefine_resource(name: String) -> void:
	_resources.erase(name)

func has_resource(name: String) -> bool:
	return _resources.has(name)

# === 操作 ===

func get_value(name: String) -> float:
	if not _resources.has(name):
		return 0.0
	return _resources[name]["value"]

func set_value(name: String, value: float) -> void:
	if not _resources.has(name):
		return
	var res: Dictionary = _resources[name]
	var old_value: float = res["value"]
	res["value"] = clampf(value, res["min"], res["max"])
	_emit_change(name, old_value, res["value"])

func add(name: String, amount: float) -> void:
	if not _resources.has(name) or amount <= 0:
		return
	var res: Dictionary = _resources[name]
	var old_value: float = res["value"]
	res["value"] = minf(res["value"] + amount, res["max"])
	_emit_change(name, old_value, res["value"])

func subtract(name: String, amount: float) -> bool:
	if not _resources.has(name) or amount <= 0:
		return false
	var res: Dictionary = _resources[name]
	if res["value"] < amount:
		return false
	var old_value: float = res["value"]
	res["value"] = maxf(res["value"] - amount, res["min"])
	_emit_change(name, old_value, res["value"])
	return true

func can_afford(name: String, amount: float) -> bool:
	if not _resources.has(name):
		return false
	return _resources[name]["value"] >= amount

# === 查询 ===

func get_all_resources() -> Dictionary:
	var result: Dictionary = {}
	for name in _resources:
		result[name] = _resources[name]["value"]
	return result

func get_resource_info(name: String) -> Dictionary:
	return _resources.get(name, {}).duplicate()

# === 批量 ===

func clear_all() -> void:
	_resources.clear()

func _emit_change(name: String, old_val: float, new_val: float) -> void:
	if old_val != new_val:
		EventBus.emit_event("resource_changed", {
			"resource": name,
			"old_value": old_val,
			"new_value": new_val,
			"delta": new_val - old_val,
		})
