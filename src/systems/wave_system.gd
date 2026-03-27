## WaveSystem - 波次管理
## 根据 waves.json 数据生成敌人波次
class_name WaveSystem
extends Node

signal wave_enemies_all_spawned(wave_index: int)

var _current_wave_index: int = -1
var _spawn_queue: Array = []
var _spawn_timer: float = 0.0
var _is_spawning: bool = false
var _enemies_alive: int = 0

func start_wave(wave_index: int) -> void:
	var wave_data := DataManager.get_wave(wave_index)
	if wave_data.is_empty():
		EventBus.all_waves_completed.emit()
		return

	_current_wave_index = wave_index
	_spawn_queue.clear()
	_enemies_alive = 0

	# 构建生成队列
	var groups: Array = wave_data.get("groups", [])
	for group in groups:
		var enemy_id: String = group.get("enemy_id", "")
		var count: int = group.get("count", 1)
		var interval: float = group.get("interval", 1.0)
		var delay: float = group.get("delay", 0.0)
		var path_index: int = group.get("path_index", -1)

		for i in range(count):
			_spawn_queue.append({
				"enemy_id": enemy_id,
				"delay": delay + i * interval,
				"path_index": path_index,
			})

	# 按延迟排序
	_spawn_queue.sort_custom(func(a, b): return a["delay"] < b["delay"])

	# 转换为相对间隔
	var last_time := 0.0
	for entry in _spawn_queue:
		var abs_time: float = entry["delay"]
		entry["delay"] = abs_time - last_time
		last_time = abs_time

	_spawn_timer = 0.0
	_is_spawning = true
	EventBus.wave_started.emit(wave_index)

func _process(delta: float) -> void:
	if not _is_spawning or _spawn_queue.is_empty():
		return

	_spawn_timer += delta
	while not _spawn_queue.is_empty() and _spawn_timer >= _spawn_queue[0]["delay"]:
		var entry: Dictionary = _spawn_queue.pop_front()
		_spawn_timer -= entry["delay"]
		_spawn_enemy(entry["enemy_id"], entry["path_index"])

	if _spawn_queue.is_empty():
		_is_spawning = false
		wave_enemies_all_spawned.emit(_current_wave_index)

func _spawn_enemy(enemy_id: String, path_index: int) -> void:
	var enemy := GameEngine.unit_system.spawn_enemy(enemy_id, path_index)
	if enemy:
		_enemies_alive += 1
		enemy.tree_exiting.connect(_on_enemy_removed)

func _on_enemy_removed() -> void:
	_enemies_alive -= 1
	if _enemies_alive <= 0 and not _is_spawning:
		EventBus.wave_completed.emit(_current_wave_index)
		# 检查是否还有下一波
		if _current_wave_index + 1 >= DataManager.get_wave_count():
			EventBus.all_waves_completed.emit()

func get_current_wave() -> int:
	return _current_wave_index

func get_enemies_alive() -> int:
	return _enemies_alive

func is_spawning() -> bool:
	return _is_spawning
