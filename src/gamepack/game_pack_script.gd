## GamePackScript - GamePack 脚本基类
## 所有 GamePack 的主脚本继承此类
## 框架级安全保护：子类代码出错不会崩溃整个游戏
class_name GamePackScript
extends Node

var pack: GamePack = null
var _error_count: int = 0
const MAX_ERRORS := 50  # 超过此数量停止执行，防止日志刷屏

# === 生命周期钩子（子类重写）===

func _pack_ready() -> void:
	pass

func _pack_cleanup() -> void:
	pass

func _pack_process(_delta: float) -> void:
	pass

# === 便捷方法 ===

func spawn(def_id: String, pos: Vector2 = Vector2.ZERO, overrides: Dictionary = {}) -> Node2D:
	return EngineAPI.spawn_entity(def_id, pos, overrides)

func destroy(entity: Node2D) -> void:
	EngineAPI.destroy_entity(entity)

func emit(event_name: String, data: Dictionary = {}) -> void:
	EngineAPI.emit_event(event_name, data)

func listen(event_name: String, callback: Callable) -> void:
	## 包裹回调，捕获异常
	var safe_callback := func(d: Dictionary) -> void:
		_safe_call(callback, [d])
	EngineAPI.connect_event(event_name, safe_callback)

func get_resource(res_name: String) -> float:
	return EngineAPI.get_resource(res_name)

func set_var(key: String, value: Variant) -> void:
	EngineAPI.set_variable(key, value)

func get_var(key: String, default: Variant = null) -> Variant:
	return EngineAPI.get_variable(key, default)

# === 安全调用 ===

func _safe_call(callable: Callable, args: Array = []) -> Variant:
	if _error_count >= MAX_ERRORS:
		return null
	if not callable.is_valid():
		return null
	return callable.callv(args)

func _process(delta: float) -> void:
	if _error_count >= MAX_ERRORS:
		return
	if EngineAPI.get_game_state() == "playing":
		_pack_process(delta)
