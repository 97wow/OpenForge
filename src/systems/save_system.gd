## SaveSystem — 完整游戏状态存档系统（对标 TrinityCore CharacterDatabase）
## 支持：KV 持久化 + 完整游戏快照 + 多存档槽 + 版本管理 + 自动存档 + 校验
## 框架层系统，GamePack 通过 EngineAPI 或直接调用
extends Node

const SAVE_DIR := "user://save/"
const MAX_SLOTS := 5
const AUTO_SAVE_INTERVAL := 300.0  # 自动存档间隔（秒，0=关闭）
const SAVE_VERSION := 1

var _cache: Dictionary = {}  # namespace -> Dictionary
var _auto_save_timer: float = 0.0
var auto_save_enabled: bool = false
var _current_slot: int = 0  # 当前使用的存档槽

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _process(delta: float) -> void:
	# 自动 play_time 计时
	if EngineAPI.get_game_state() == "playing":
		var pt: float = EngineAPI.get_variable("play_time", 0.0)
		EngineAPI._variables["play_time"] = pt + delta  # 直接写避免触发事件
	if auto_save_enabled and AUTO_SAVE_INTERVAL > 0:
		_auto_save_timer += delta
		if _auto_save_timer >= AUTO_SAVE_INTERVAL:
			_auto_save_timer = 0.0
			save_game_snapshot(_current_slot)

# === 基础 KV 存取（保留原有接口）===

func save_data(ns: String, key: String, value: Variant) -> void:
	_ensure_loaded(ns)
	_cache[ns][key] = value
	_write_file(ns)

func load_data(ns: String, key: String, default: Variant = null) -> Variant:
	_ensure_loaded(ns)
	return _cache[ns].get(key, default)

func has_data(ns: String, key: String) -> bool:
	_ensure_loaded(ns)
	return _cache[ns].has(key)

func get_all(ns: String) -> Dictionary:
	_ensure_loaded(ns)
	return _cache.get(ns, {}).duplicate()

func erase_data(ns: String, key: String) -> void:
	_ensure_loaded(ns)
	_cache[ns].erase(key)
	_write_file(ns)

func clear_namespace(ns: String) -> void:
	_cache[ns] = {}
	_write_file(ns)

# === 完整游戏快照（存档/读档）===

func save_game_snapshot(slot: int = -1) -> bool:
	## 保存完整游戏状态到指定槽位
	if slot < 0:
		slot = _current_slot
	var snapshot := _capture_game_state()
	if snapshot.is_empty():
		return false
	# 写入文件
	var path := _slot_path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveSystem] Cannot write to %s" % path)
		return false
	file.store_string(JSON.stringify(snapshot, "\t"))
	EventBus.emit_event("game_saved", {"slot": slot})
	return true

func load_game_snapshot(slot: int = -1) -> Dictionary:
	## 加载存档槽的游戏快照（不自动应用，交给 GamePack 决定如何恢复）
	if slot < 0:
		slot = _current_slot
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		return {}
	var data: Dictionary = json.data
	# 版本校验
	if data.get("save_version", 0) != SAVE_VERSION:
		push_warning("[SaveSystem] Save version mismatch: %d vs %d" % [data.get("save_version", 0), SAVE_VERSION])
	# 完整性校验
	var stored_checksum: int = data.get("checksum", 0)
	data.erase("checksum")
	var computed: int = _compute_checksum(data)
	if stored_checksum != 0 and stored_checksum != computed:
		push_warning("[SaveSystem] Checksum mismatch in slot %d" % slot)
	EventBus.emit_event("game_loaded", {"slot": slot})
	return data

func apply_snapshot(snapshot: Dictionary) -> void:
	## 从快照恢复游戏状态（框架层恢复资源/变量/背包，实体由 GamePack 重建）
	# 资源
	var resources: Dictionary = snapshot.get("resources", {})
	for res_name in resources:
		EngineAPI.set_resource(res_name, resources[res_name])
	# 变量
	var variables: Dictionary = snapshot.get("variables", {})
	for key in variables:
		EngineAPI.set_variable(key, variables[key])
	# 背包（需要英雄实体已存在）
	var heroes: Array = EngineAPI.find_entities_by_tag("hero")
	if heroes.size() > 0 and is_instance_valid(heroes[0]):
		var hero: Node3D = heroes[0]
		var item_sys: Node = EngineAPI.get_system("item")
		if item_sys:
			var inv: Array = snapshot.get("inventory", [])
			item_sys.call("init_inventory", hero, snapshot.get("inventory_capacity", 20))
			for item in inv:
				item_sys.call("inventory_add", hero, item)
			# 装备
			var equipped: Dictionary = snapshot.get("equipped", {})
			for slot in equipped:
				item_sys.call("equip_item", hero, slot, equipped[slot])
	# 任务进度
	var quest_progress: Dictionary = snapshot.get("quest_progress", {})
	var quest_sys: Node = EngineAPI.get_system("quest")
	if quest_sys and not quest_progress.is_empty():
		quest_sys._quest_progress["player"] = quest_progress
	# 成就进度
	var ach_progress: Dictionary = snapshot.get("achievement_progress", {})
	var ach_sys: Node = EngineAPI.get_system("achievement")
	if ach_sys and not ach_progress.is_empty():
		ach_sys._player_progress["player"] = ach_progress
		var ach_stats: Dictionary = snapshot.get("achievement_stats", {})
		if not ach_stats.is_empty():
			ach_sys._stats["player"] = ach_stats
	# 声望
	var reps: Dictionary = snapshot.get("reputations", {})
	var faction_sys: Node = EngineAPI.get_system("faction")
	if faction_sys and not reps.is_empty():
		faction_sys._reputations["player"] = reps
	# 持久 Aura 恢复
	if heroes.size() > 0 and is_instance_valid(heroes[0]):
		var aura_mgr: Node = EngineAPI.get_system("aura")
		if aura_mgr:
			for aura_data in snapshot.get("persistent_auras", []):
				aura_mgr.call("apply_aura", heroes[0], heroes[0],
					{"aura": aura_data.get("aura_type", ""), "base_points": aura_data.get("base_points", 0)},
					{"id": aura_data.get("spell_id", "")},
					aura_data.get("remaining", 0))
	EventBus.emit_event("snapshot_applied", {"snapshot": snapshot})

func delete_slot(slot: int) -> void:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	EventBus.emit_event("save_slot_deleted", {"slot": slot})

func set_current_slot(slot: int) -> void:
	_current_slot = clampi(slot, 0, MAX_SLOTS - 1)

# === 存档信息查询 ===

func get_slot_info(slot: int) -> Dictionary:
	## 获取存档槽信息（不加载完整数据，仅读 header）
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"exists": false, "slot": slot}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": false, "slot": slot}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		return {"exists": false, "slot": slot}
	var data: Dictionary = json.data
	return {
		"exists": true,
		"slot": slot,
		"save_time": data.get("save_time", ""),
		"play_time": data.get("play_time", 0),
		"game_mode": data.get("game_mode", ""),
		"level": data.get("level_data", {}).get("level", 1),
		"save_version": data.get("save_version", 0),
	}

func get_all_slot_info() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(MAX_SLOTS):
		result.append(get_slot_info(i))
	return result

# === 内部 ===

func _capture_game_state() -> Dictionary:
	## 捕获当前完整游戏状态
	var snapshot := {
		"save_version": SAVE_VERSION,
		"save_time": Time.get_datetime_string_from_system(),
		"play_time": EngineAPI.get_variable("play_time", 0),
		"game_mode": EngineAPI.get_variable("game_mode", ""),
		"game_state": EngineAPI.get_game_state(),
	}
	# 资源
	var res_sys: Node = EngineAPI.get_system("resource")
	if res_sys and res_sys.has_method("get_all_resources"):
		snapshot["resources"] = res_sys.call("get_all_resources")
	# 变量（排除临时变量）
	snapshot["variables"] = {}
	for key in EngineAPI._variables:
		if not str(key).begins_with("_tmp_"):
			snapshot["variables"][key] = EngineAPI._variables[key]
	# 英雄状态
	var heroes: Array = EngineAPI.find_entities_by_tag("hero")
	if heroes.size() > 0 and is_instance_valid(heroes[0]):
		var hero: Node3D = heroes[0]
		var item_sys: Node = EngineAPI.get_system("item")
		if item_sys:
			snapshot["inventory"] = item_sys.call("inventory_get", hero)
			snapshot["inventory_capacity"] = item_sys.call("inventory_capacity", hero)
			snapshot["equipped"] = item_sys.call("get_equipped", hero)
		# 等级
		var level_sys: Node = EngineAPI.get_system("level")
		if level_sys:
			snapshot["level_data"] = level_sys.call("get_level_data", hero)
		# 位置
		snapshot["hero_position"] = {"x": hero.global_position.x, "y": hero.global_position.y}
	# 任务进度
	var quest_sys: Node = EngineAPI.get_system("quest")
	if quest_sys:
		snapshot["quest_progress"] = quest_sys._quest_progress.get("player", {})
	# 成就进度
	var ach_sys: Node = EngineAPI.get_system("achievement")
	if ach_sys:
		snapshot["achievement_progress"] = ach_sys._player_progress.get("player", {})
		snapshot["achievement_stats"] = ach_sys._stats.get("player", {})
	# 声望（对标 TC character_reputation）
	var faction_sys: Node = EngineAPI.get_system("faction")
	if faction_sys:
		snapshot["reputations"] = faction_sys._reputations.get("player", {})
	# 活跃持久 Aura（对标 TC character_aura，排除临时战斗 buff）
	if heroes.size() > 0 and is_instance_valid(heroes[0]):
		var aura_mgr: Node = EngineAPI.get_system("aura")
		if aura_mgr:
			var auras: Array = aura_mgr.call("get_auras_on", heroes[0])
			var persistent_auras: Array = []
			for aura in auras:
				# 只保存持久性 aura（duration > 60秒或永久的非 CC 效果）
				var dur: float = aura.get("duration", 0)
				var aura_type: String = aura.get("aura_type", "")
				if (dur == 0 or dur > 60.0) and not aura_type.begins_with("CC_"):
					persistent_auras.append({
						"aura_id": aura.get("aura_id", ""),
						"aura_type": aura_type,
						"spell_id": aura.get("spell_id", ""),
						"remaining": aura.get("remaining", 0),
						"stacks": aura.get("stacks", 1),
						"base_points": aura.get("base_points", 0),
					})
			snapshot["persistent_auras"] = persistent_auras
	# 校验和
	snapshot["checksum"] = _compute_checksum(snapshot)
	return snapshot

func _slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.json" % slot

func _compute_checksum(data: Dictionary) -> int:
	## 基于 save_version + save_time + play_time 的确定性校验
	var key_str: String = "%s_%s_%s" % [
		str(data.get("save_version", 0)),
		str(data.get("save_time", "")),
		str(data.get("play_time", 0))]
	return key_str.hash()

func _ensure_loaded(ns: String) -> void:
	if _cache.has(ns):
		return
	var path := SAVE_DIR + ns + ".json"
	if not FileAccess.file_exists(path):
		_cache[ns] = {}
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_cache[ns] = {}
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_cache[ns] = json.data
	else:
		_cache[ns] = {}

func _write_file(ns: String) -> void:
	var path := SAVE_DIR + ns + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_cache.get(ns, {}), "\t"))
