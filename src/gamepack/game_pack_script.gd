## GamePackScript - GamePack 脚本基类
## 所有 GamePack 的主脚本继承此类
## 提供生命周期钩子和便捷访问
class_name GamePackScript
extends Node

var pack: GamePack = null

# === 生命周期钩子（子类重写）===

func _pack_ready() -> void:
	## GamePack 加载完成后调用
	pass

func _pack_cleanup() -> void:
	## GamePack 卸载前调用
	pass

func _pack_process(_delta: float) -> void:
	## 每帧调用（仅在 playing 状态）
	pass

# === 便捷方法 ===

func spawn(def_id: String, pos: Vector2 = Vector2.ZERO, overrides: Dictionary = {}) -> Node2D:
	return EngineAPI.spawn_entity(def_id, pos, overrides)

func destroy(entity: Node2D) -> void:
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

# === 内部 ===

func _process(delta: float) -> void:
	if EngineAPI.get_game_state() == "playing":
		_pack_process(delta)
