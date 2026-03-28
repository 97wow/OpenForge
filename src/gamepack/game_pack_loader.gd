## GamePackLoader - GamePack 发现、加载、卸载
## 从 res://gamepacks/ 和 user://gamepacks/ 扫描可用包
class_name GamePackLoader
extends Node

var _current_pack: GamePack = null
var _pack_runtime: Node = null  # GamePackScript 实例挂载点

func _ready() -> void:
	EngineAPI.register_system("pack_loader", self)
	_pack_runtime = Node.new()
	_pack_runtime.name = "GamePackRuntime"
	add_child(_pack_runtime)

# === 扫描 ===

func scan_packs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append_array(_scan_directory("res://gamepacks"))
	result.append_array(_scan_directory("user://gamepacks"))
	return result

func _scan_directory(base_path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir := DirAccess.open(base_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and entry != "." and entry != "..":
			var pack_json_path := base_path.path_join(entry).path_join("pack.json")
			if FileAccess.file_exists(pack_json_path):
				var meta := _load_pack_json(pack_json_path)
				if not meta.is_empty():
					meta["_path"] = base_path.path_join(entry)
					result.append(meta)
		entry = dir.get_next()
	return result

func _load_pack_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}

# === 加载 ===

func load_pack(pack_id: String) -> GamePack:
	# 先卸载当前包
	unload_current_pack()

	# 查找包路径
	var pack_path := _find_pack_path(pack_id)
	if pack_path == "":
		push_error("[GamePackLoader] Pack '%s' not found" % pack_id)
		DebugOverlay.log_error("GamePackLoader", "Pack '%s' not found" % pack_id)
		return null

	var pack_json := _load_pack_json(pack_path.path_join("pack.json"))
	if pack_json.is_empty():
		push_error("[GamePackLoader] Invalid pack.json for '%s'" % pack_id)
		DebugOverlay.log_error("GamePackLoader", "Invalid pack.json for '%s'" % pack_id)
		return null

	print("[GamePackLoader] Loading pack: %s (%s)" % [
		pack_json.get("name", pack_id), pack_json.get("version", "?")
	])

	var pack := GamePack.new()
	pack.pack_id = pack_id
	pack.pack_path = pack_path
	pack.metadata = pack_json

	# 1. 加载实体定义
	var entity_dir: String = pack_json.get("entity_dir", "entities")
	var entity_count: int = DataRegistry.load_directory("entities", pack_path.path_join(entity_dir))
	print("[GamePackLoader] Loaded %d entity definitions" % entity_count)

	# 2. 加载 Buff 定义
	var buff_dir: String = pack_json.get("buff_dir", "buffs")
	var buff_count: int = DataRegistry.load_directory("buffs", pack_path.path_join(buff_dir))
	if buff_count > 0:
		print("[GamePackLoader] Loaded %d buff definitions" % buff_count)

	# 2.5 加载 Spell 定义
	var spell_dir: String = pack_json.get("spell_dir", "spells")
	var spell_system: Node = EngineAPI.get_system("spell")
	if spell_system:
		var spell_count: int = spell_system.call("load_spells_from_directory", pack_path.path_join(spell_dir))
		if spell_count > 0:
			print("[GamePackLoader] Loaded %d spell definitions" % spell_count)

	# 3. 定义资源
	var resources: Dictionary = pack_json.get("resources", {})
	for res_name in resources:
		var res_data: Dictionary = resources[res_name]
		EngineAPI.define_resource(
			res_name,
			res_data.get("initial", 0.0),
			res_data.get("max", INF)
		)
	if not resources.is_empty():
		print("[GamePackLoader] Defined %d resources" % resources.size())

	# 4. 注册自定义事件
	var events: Array = pack_json.get("events", [])
	for event_name in events:
		EventBus.register_event(str(event_name))

	# 5. 加载触发规则
	var rules_dir: String = pack_json.get("rules_dir", "rules")
	_load_rules(pack_path.path_join(rules_dir))

	# 6. 加载并实例化主脚本
	var main_script_path: String = pack_json.get("main_script", "")
	if main_script_path != "":
		var full_script_path := pack_path.path_join(main_script_path)
		var script := load(full_script_path) as GDScript
		if script:
			var instance: Node = Node.new()
			instance.set_script(script)
			instance.name = "PackScript_%s" % pack_id
			if instance is GamePackScript:
				(instance as GamePackScript).pack = pack
			_pack_runtime.add_child(instance)
			pack.script_instance = instance
			# 调用 _pack_ready
			if instance.has_method("_pack_ready"):
				instance.call("_pack_ready")
			print("[GamePackLoader] Pack script loaded: %s" % main_script_path)

	_current_pack = pack
	EventBus.emit_event("gamepack_loaded", {"pack_id": pack_id})
	return pack

func _load_rules(rules_path: String) -> void:
	var dir := DirAccess.open(rules_path)
	if dir == null:
		return
	var trigger_system := EngineAPI.get_system("trigger")
	if trigger_system == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var total := 0
	while file_name != "":
		if file_name.ends_with(".json"):
			var triggers: Array = DataRegistry.load_array_file("_rules", rules_path.path_join(file_name))
			trigger_system.call("load_triggers", triggers)
			total += triggers.size()
		file_name = dir.get_next()
	if total > 0:
		print("[GamePackLoader] Loaded %d trigger rules" % total)

# === 卸载 ===

func unload_current_pack() -> void:
	if _current_pack == null:
		return
	var pack_id := _current_pack.pack_id

	# 调用清理钩子
	if _current_pack.script_instance and _current_pack.script_instance.has_method("_pack_cleanup"):
		_current_pack.script_instance.call("_pack_cleanup")

	# 清理 runtime 节点
	for child in _pack_runtime.get_children():
		child.queue_free()

	# 清理数据
	DataRegistry.clear_all()
	EventBus.clear_all_custom_events()
	EngineAPI.clear_variables()

	var resource_system := EngineAPI.get_system("resource") as Node
	if resource_system:
		resource_system.call("clear_all")

	EventBus.emit_event("gamepack_unloaded", {"pack_id": pack_id})
	_current_pack = null

# === 查询 ===

func get_current_pack() -> GamePack:
	return _current_pack

func _find_pack_path(pack_id: String) -> String:
	for base in ["res://gamepacks", "user://gamepacks"]:
		var path: String = base.path_join(pack_id)
		if DirAccess.open(path) != null:
			var pack_json: String = path.path_join("pack.json")
			if FileAccess.file_exists(pack_json):
				return path
	return ""
