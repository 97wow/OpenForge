## PathFollowComponent - 路径跟随
## 让实体沿 Path2D 移动。使用隐藏的 PathFollow2D 同步位置。
extends Node

var _entity: Node2D = null
var _path_follow: PathFollow2D = null
var _path: Path2D = null
var _active: bool = false

func setup(data: Dictionary) -> void:
	# path 和 path_index 在运行时由 GamePack 脚本设置
	pass

func _on_attached(entity: Node2D) -> void:
	_entity = entity

func _on_detached() -> void:
	_cleanup()

func assign_path(path: Path2D) -> void:
	_cleanup()
	if path == null:
		return
	_path = path
	_path_follow = PathFollow2D.new()
	_path_follow.rotates = false
	_path_follow.loop = false
	_path_follow.progress = 0.0
	path.add_child(_path_follow)
	_active = true

func _cleanup() -> void:
	if _path_follow and is_instance_valid(_path_follow):
		_path_follow.queue_free()
	_path_follow = null
	_path = null
	_active = false

func _process(delta: float) -> void:
	if not _active or _entity == null or _path_follow == null:
		return
	if EngineAPI.get_game_state() != "playing":
		return

	# 从 MovementComponent 获取速度
	var movement = _entity.get_component("movement") if _entity.has_method("get_component") else null
	var speed: float = 80.0
	if movement:
		speed = movement.current_speed

	_path_follow.progress += speed * delta
	_entity.global_position = _path_follow.global_position

	# 到达终点
	if _path_follow.progress_ratio >= 1.0:
		_active = false
		EventBus.emit_event("path_completed", {"entity": _entity})

func get_progress_ratio() -> float:
	if _path_follow == null:
		return 0.0
	return _path_follow.progress_ratio

func is_active() -> bool:
	return _active
