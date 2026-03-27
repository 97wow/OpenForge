## DataManager - 数据驱动层核心
## 负责加载/缓存 MapPack 中的 JSON 数据
## 支持从 res:// 和 user:// 加载（为 UGC 预留）
extends Node

var _towers: Dictionary = {}       # tower_id -> data
var _enemies: Dictionary = {}      # enemy_id -> data
var _heroes: Dictionary = {}       # hero_id -> data
var _waves: Array = []             # wave definitions
var _affixes: Dictionary = {}      # affix_id -> data
var _map_config: Dictionary = {}   # current map config
var _current_pack_id: String = ""

# === 加载 MapPack ===

func load_map_pack(pack_path: String) -> bool:
	var pack_id := pack_path.get_file()
	print("DataManager: Loading map pack '%s'" % pack_id)

	# 加载地图配置
	var config := _load_json(pack_path + "/map_config.json")
	if config.is_empty():
		push_error("DataManager: Failed to load map_config.json from '%s'" % pack_path)
		return false
	_map_config = config

	# 加载各数据文件
	_towers = _load_data_dir(pack_path + "/towers")
	_enemies = _load_data_dir(pack_path + "/enemies")
	_heroes = _load_data_dir(pack_path + "/heroes")
	_affixes = _load_data_dir(pack_path + "/affixes")
	_waves = _load_json_array(pack_path + "/waves.json")

	_current_pack_id = pack_id
	EventBus.map_pack_loaded.emit(pack_id)
	print("DataManager: Pack '%s' loaded - %d towers, %d enemies, %d waves" % [
		pack_id, _towers.size(), _enemies.size(), _waves.size()
	])
	return true

# === 数据查询 ===

func get_tower(tower_id: String) -> Dictionary:
	return _towers.get(tower_id, {})

func get_enemy(enemy_id: String) -> Dictionary:
	return _enemies.get(enemy_id, {})

func get_hero(hero_id: String) -> Dictionary:
	return _heroes.get(hero_id, {})

func get_wave(wave_index: int) -> Dictionary:
	if wave_index < 0 or wave_index >= _waves.size():
		return {}
	return _waves[wave_index]

func get_wave_count() -> int:
	return _waves.size()

func get_affix(affix_id: String) -> Dictionary:
	return _affixes.get(affix_id, {})

func get_map_config() -> Dictionary:
	return _map_config

func get_all_tower_ids() -> Array:
	return _towers.keys()

func get_all_enemy_ids() -> Array:
	return _enemies.keys()

# === 内部工具 ===

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataManager: Cannot open '%s'" % path)
		return {}
	var json_text := file.get_as_text()
	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_error("DataManager: JSON parse error in '%s': %s" % [path, json.get_error_message()])
		return {}
	if json.data is Dictionary:
		return json.data
	return {}

func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var json_text := file.get_as_text()
	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_error("DataManager: JSON parse error in '%s': %s" % [path, json.get_error_message()])
		return []
	if json.data is Array:
		return json.data
	return []

func _load_data_dir(dir_path: String) -> Dictionary:
	var result: Dictionary = {}
	if not DirAccess.dir_exists(dir_path):
		return result
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var data := _load_json(dir_path + "/" + file_name)
			if not data.is_empty() and data.has("id"):
				result[data["id"]] = data
		file_name = dir.get_next()
	return result
