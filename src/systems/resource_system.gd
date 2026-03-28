## ResourceSystem - 通用命名资源管理
## "金币"、"生命"、"法力"、"积分" 都只是不同名字的资源
## GamePack 通过 define_resource() 定义自己需要的资源
class_name ResourceSystem
extends Node

# res_name -> { value, min, max }
var _resources: Dictionary = {}

func _ready() -> void:
	EngineAPI.register_system("resource", self)

# === 定义 ===

func define_resource(res_name: String, initial: float = 0.0, max_val: float = INF) -> void:
	_resources[res_name] = {
		"value": initial,
		"min": 0.0,
		"max": max_val,
	}

func undefine_resource(res_name: String) -> void:
	_resources.erase(res_name)

func has_resource(res_name: String) -> bool:
	return _resources.has(res_name)

# === 操作 ===

func get_value(res_name: String) -> float:
	if not _resources.has(res_name):
		return 0.0
	return _resources[res_name]["value"]

func set_value(res_name: String, value: float) -> void:
	if not _resources.has(res_name):
		return
	var res: Dictionary = _resources[res_name]
	var old_value: float = res["value"]
	res["value"] = clampf(value, res["min"], res["max"])
	_emit_change(res_name, old_value, res["value"])

func add(res_name: String, amount: float) -> void:
	if not _resources.has(res_name) or amount <= 0:
		return
	var res: Dictionary = _resources[res_name]
	var old_value: float = res["value"]
	res["value"] = minf(res["value"] + amount, res["max"])
	_emit_change(res_name, old_value, res["value"])

func subtract(res_name: String, amount: float) -> bool:
	if not _resources.has(res_name) or amount <= 0:
		return false
	var res: Dictionary = _resources[res_name]
	if res["value"] < amount:
		return false
	var old_value: float = res["value"]
	res["value"] = maxf(res["value"] - amount, res["min"])
	_emit_change(res_name, old_value, res["value"])
	return true

func can_afford(res_name: String, amount: float) -> bool:
	if not _resources.has(res_name):
		return false
	return _resources[res_name]["value"] >= amount

# === 查询 ===

func get_all_resources() -> Dictionary:
	var result: Dictionary = {}
	for key in _resources:
		result[key] = _resources[key]["value"]
	return result

func get_resource_info(res_name: String) -> Dictionary:
	return _resources.get(res_name, {}).duplicate()

# === 批量 ===

func clear_all() -> void:
	_resources.clear()

func _emit_change(res_name: String, old_val: float, new_val: float) -> void:
	if old_val != new_val:
		EventBus.emit_event("resource_changed", {
			"resource": res_name,
			"old_value": old_val,
			"new_value": new_val,
			"delta": new_val - old_val,
		})
