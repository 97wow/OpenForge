## GamePackScript - GamePack 脚本基类
## 框架级安全保护：子类代码出错 → 游戏画面显示错误 → 不崩溃
class_name GamePackScript
extends Node

var pack: GamePack = null
var _error_count: int = 0
const MAX_ERRORS := 50

# === 生命周期钩子（子类重写）===

func _pack_ready() -> void:
	pass

func _pack_cleanup() -> void:
	pass

func _pack_process(_delta: float) -> void:
	pass

# === 便捷方法 ===

func spawn(def_id: String, pos: Vector3 = Vector3.ZERO, overrides: Dictionary = {}) -> Node3D:
	return EngineAPI.spawn_entity(def_id, pos, overrides)

func destroy(entity: Node3D) -> void:
	EngineAPI.destroy_entity(entity)

func emit(event_name: String, data: Dictionary = {}) -> void:
	EngineAPI.emit_event(event_name, data)

func listen(event_name: String, callback: Callable) -> void:
	EngineAPI.connect_event(event_name, callback)

func get_resource(res_name: String) -> float:
	return EngineAPI.get_resource(res_name)

func set_var(key: String, value: Variant) -> void:
	EngineAPI.set_variable(key, value)

func get_var(key: String, default: Variant = null) -> Variant:
	return EngineAPI.get_variable(key, default)

# === 安全辅助 ===

func _pack_error(message: String) -> void:
	## GamePack 脚本中报告错误（显示在游戏画面上）
	_error_count += 1
	var source: String = pack.pack_id if pack else "unknown"
	DebugOverlay.log_error(source, message)
	if _error_count >= MAX_ERRORS:
		DebugOverlay.log_error(source, "Too many errors (%d), pack script paused" % _error_count)

func _pack_warning(message: String) -> void:
	var source: String = pack.pack_id if pack else "unknown"
	DebugOverlay.log_warning(source, message)

func _pack_info(message: String) -> void:
	var source: String = pack.pack_id if pack else "unknown"
	DebugOverlay.log_info(source, message)

func _process(delta: float) -> void:
	if _error_count >= MAX_ERRORS:
		return
	if EngineAPI.get_game_state() == "playing":
		_pack_process(delta)
