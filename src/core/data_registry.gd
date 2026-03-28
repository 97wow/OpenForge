## DataRegistry - 通用数据注册表
## 以 (namespace, id) 为键缓存 JSON 数据
## 支持 res:// 和 user:// 加载（为 UGC 预留）
## 不包含任何游戏特定概念（无 tower/enemy/wave）
extends Node

# namespace -> { id -> Dictionary }
var _data: Dictionary = {}

# === 加载 ===

func load_directory(ns: String, dir_path: String) -> int:
	## 加载目录下所有 JSON 文件到指定命名空间，返回加载数量
	_ensure_namespace(ns)
	var count := 0
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path := dir_path.path_join(file_name)
			var data: Dictionary = _parse_json_file(full_path)
			if not data.is_empty():
				var id: String = data.get("id", file_name.get_basename())
				_data[ns][id] = data
				count += 1
		file_name = dir.get_next()
	return count

func load_file(ns: String, file_path: String) -> Dictionary:
	## 加载单个 JSON 文件到指定命名空间
	_ensure_namespace(ns)
	var data: Dictionary = _parse_json_file(file_path)
	if not data.is_empty():
		var id: String = data.get("id", file_path.get_file().get_basename())
		_data[ns][id] = data
	return data

func load_array_file(ns: String, file_path: String) -> Array:
	## 加载 JSON 数组文件（如 waves.json），返回数组
	## 不存入 namespace（数组无 id），调用者自行处理
	if not FileAccess.file_exists(file_path):
		return []
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return []
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("[DataRegistry] Parse error in '%s': %s" % [file_path, json.get_error_message()])
		return []
	if json.data is Array:
		return json.data
	return []

func register(ns: String, id: String, data: Dictionary) -> void:
	## 直接注册数据（非文件加载）
	_ensure_namespace(ns)
	_data[ns][id] = data

# === 查询 ===

func get_def(ns: String, id: String) -> Dictionary:
	if not _data.has(ns):
		return {}
	return _data[ns].get(id, {})

func has_def(ns: String, id: String) -> bool:
	return _data.has(ns) and _data[ns].has(id)

func get_all_ids(ns: String) -> Array[String]:
	if not _data.has(ns):
		return []
	var result: Array[String] = []
	for key in _data[ns]:
		result.append(key)
	return result

func get_all_defs(ns: String) -> Array[Dictionary]:
	if not _data.has(ns):
		return []
	var result: Array[Dictionary] = []
	for value in _data[ns].values():
		result.append(value)
	return result

func get_namespace_count(ns: String) -> int:
	if not _data.has(ns):
		return 0
	return _data[ns].size()

# === 清理 ===

func clear_namespace(ns: String) -> void:
	_data.erase(ns)

func clear_all() -> void:
	_data.clear()

func get_all_namespaces() -> Array[String]:
	var result: Array[String] = []
	for key in _data:
		result.append(key)
	return result

# === 内部 ===

func _ensure_namespace(ns: String) -> void:
	if not _data.has(ns):
		_data[ns] = {}

func _parse_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[DataRegistry] Cannot open: %s" % path)
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("[DataRegistry] Parse error in '%s': %s" % [path, json.get_error_message()])
		return {}
	if json.data is Dictionary:
		return json.data
	return {}
