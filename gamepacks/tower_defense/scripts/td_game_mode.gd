## TD Game Mode - 塔防玩法脚本
## 所有塔防特定逻辑都在这里，框架层完全不知道"塔防"的存在
extends GamePackScript

var _current_wave: int = -1
var _wave_data: Array = []
var _spawn_queue: Array = []
var _spawn_timer: float = 0.0
var _is_spawning: bool = false
var _enemies_alive: int = 0
var _paths: Array[Path2D] = []
var _current_path_index: int = 0

func _pack_ready() -> void:
	_load_map("demo_plains")
	listen("entity_destroyed", _on_entity_destroyed)
	listen("path_completed", _on_path_completed)

func _load_map(map_id: String) -> void:
	var maps_dir: String = pack.pack_path.path_join("maps").path_join(map_id)
	var map_config: Dictionary = DataRegistry.load_file("maps", maps_dir.path_join("map_config.json"))
	if map_config.is_empty():
		push_error("[TD] Failed to load map: %s" % map_id)
		return

	# 初始化网格
	var grid := EngineAPI.get_system("grid") as GridSystem
	if grid:
		var state_map_raw: Dictionary = map_config.get("tile_state_map", {})
		# 转换 key 为 int
		var state_map: Dictionary = {}
		for key in state_map_raw:
			state_map[int(key)] = state_map_raw[key]
		grid.init_from_layout(
			map_config.get("grid_width", 20),
			map_config.get("grid_height", 12),
			map_config.get("layout", []),
			state_map
		)
		var cell_data: Array = map_config.get("cell_size", [64, 64])
		grid.set_cell_size(Vector2(cell_data[0], cell_data[1]))

	# 创建路径
	_setup_paths(map_config.get("paths", []))

	# 加载波次
	_wave_data = DataRegistry.load_array_file("waves", maps_dir.path_join("waves.json"))

	# 设置变量
	set_var("total_waves", _wave_data.size())
	set_var("current_wave", -1)
	set_var("map_id", map_id)

	EngineAPI.set_game_state("preparing")
	print("[TD] Map '%s' loaded: %d waves" % [map_config.get("name", map_id), _wave_data.size()])

func _setup_paths(path_data: Array) -> void:
	_paths.clear()
	# 获取 main 场景的 Systems 节点或 entity container 作为 parent
	var parent := get_parent()
	for i in range(path_data.size()):
		var points: Array = path_data[i]
		var path := Path2D.new()
		path.name = "EnemyPath_%d" % i
		var curve := Curve2D.new()
		for point in points:
			if point is Dictionary:
				curve.add_point(Vector2(point.get("x", 0), point.get("y", 0)))
		path.curve = curve
		parent.add_child(path)
		_paths.append(path)

# === 公共 API（供 UI 调用）===

func start_next_wave() -> void:
	if _is_spawning:
		return
	_current_wave += 1
	if _current_wave >= _wave_data.size():
		emit("all_waves_completed", {})
		EngineAPI.set_game_state("victory")
		EngineAPI.show_message("胜利！所有波次已完成！")
		return

	var wave: Dictionary = _wave_data[_current_wave]
	set_var("current_wave", _current_wave)

	# 构建生成队列
	_spawn_queue.clear()
	_enemies_alive = 0
	var groups: Array = wave.get("groups", [])
	for group in groups:
		var enemy_id: String = group.get("enemy_id", "")
		var count: int = group.get("count", 1)
		var interval: float = group.get("interval", 1.0)
		var delay: float = group.get("delay", 0.0)
		for j in range(count):
			_spawn_queue.append({
				"enemy_id": enemy_id,
				"time": delay + j * interval,
			})

	_spawn_queue.sort_custom(func(a, b): return a["time"] < b["time"])
	# 转为相对时间
	var last := 0.0
	for entry in _spawn_queue:
		var abs_time: float = entry["time"]
		entry["time"] = abs_time - last
		last = abs_time

	_spawn_timer = 0.0
	_is_spawning = true
	EngineAPI.set_game_state("playing")
	emit("wave_started", {"wave_index": _current_wave, "wave_name": wave.get("name", "")})
	EngineAPI.show_message("第 %d 波: %s" % [_current_wave + 1, wave.get("name", "")])

func build_tower(tower_id: String, grid_pos: Vector2i) -> Node2D:
	var tile := EngineAPI.get_tile_state(grid_pos)
	if tile != "buildable":
		return null
	var def: Dictionary = DataRegistry.get_def("entities", tower_id)
	if def.is_empty():
		return null
	var cost: int = def.get("meta", {}).get("cost", 0)
	if not EngineAPI.can_afford("gold", cost):
		return null

	EngineAPI.subtract_resource("gold", cost)
	var world_pos := EngineAPI.grid_to_world(grid_pos)
	var tower := spawn(tower_id, world_pos)
	if tower:
		EngineAPI.set_tile_state(grid_pos, "occupied")
		tower.set_meta_value("grid_pos", grid_pos)
		emit("tower_placed", {"tower": tower, "grid_pos": grid_pos})
	return tower

func sell_tower(tower: Node2D) -> void:
	if tower == null or not tower is GameEntity:
		return
	var entity := tower as GameEntity
	if not entity.has_tag("tower"):
		return
	var cost: int = entity.get_meta_value("cost", 0)
	var sell_ratio: float = entity.get_meta_value("sell_ratio", 0.7)
	var refund := int(cost * sell_ratio)
	var grid_pos = entity.get_meta_value("grid_pos", Vector2i.ZERO)
	EngineAPI.add_resource("gold", refund)
	EngineAPI.set_tile_state(grid_pos, "buildable")
	emit("tower_sold", {"tower": tower, "refund": refund})
	destroy(tower)

# === 波次 Process ===

func _pack_process(delta: float) -> void:
	if not _is_spawning or _spawn_queue.is_empty():
		return
	_spawn_timer += delta
	while not _spawn_queue.is_empty() and _spawn_timer >= _spawn_queue[0]["time"]:
		var entry: Dictionary = _spawn_queue.pop_front()
		_spawn_timer -= entry["time"]
		_spawn_enemy(entry["enemy_id"])

	if _spawn_queue.is_empty():
		_is_spawning = false

func _spawn_enemy(enemy_id: String) -> void:
	if _paths.is_empty():
		return
	var path: Path2D = _paths[_current_path_index % _paths.size()]
	_current_path_index += 1

	var start_pos := path.curve.get_point_position(0) if path.curve.point_count > 0 else Vector2.ZERO
	var enemy := spawn(enemy_id, start_pos)
	if enemy:
		_enemies_alive += 1
		var pf = enemy.get_component("path_follow")
		if pf and pf.has_method("assign_path"):
			pf.call("assign_path", path)

# === 事件处理 ===

func _on_entity_destroyed(data: Dictionary) -> void:
	var entity = data.get("entity")
	if entity is GameEntity and entity.has_tag("enemy"):
		_enemies_alive -= 1
		_check_wave_complete()

func _on_path_completed(_data: Dictionary) -> void:
	# path_completed 触发后，combat_rules.json 会扣除生命
	# 实体会被 destroy_entity 销毁，触发 entity_destroyed
	pass

func _check_wave_complete() -> void:
	if _enemies_alive <= 0 and not _is_spawning:
		emit("wave_completed", {"wave_index": _current_wave})
