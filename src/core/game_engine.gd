## GameEngine - 框架层核心入口
## 类似 War3 native 函数，提供统一的 Engine API 给上层调用
## 上层（模板层/创作者层）只通过 GameEngine.xxx() 与框架交互
extends Node

enum GameState { IDLE, PREPARING, PLAYING, PAUSED, VICTORY, DEFEAT }

var state: GameState = GameState.IDLE
var current_map_id: String = ""
var current_wave: int = -1
var speed_multiplier: float = 1.0

# 子系统引用（由 main.gd 注册）
var grid_system: Node = null
var path_system: Node = null
var wave_system: Node = null
var unit_system: Node = null
var economy_system: Node = null
var buff_system: Node = null

# === 游戏流程 API ===

func start_game() -> void:
	if state != GameState.PREPARING:
		push_warning("GameEngine: Cannot start, state is %s" % GameState.keys()[state])
		return
	state = GameState.PLAYING
	current_wave = -1
	EventBus.game_started.emit()
	next_wave()

func pause_game() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.PAUSED
	get_tree().paused = true
	EventBus.game_paused.emit()

func resume_game() -> void:
	if state != GameState.PAUSED:
		return
	state = GameState.PLAYING
	get_tree().paused = false
	EventBus.game_resumed.emit()

func toggle_pause() -> void:
	if state == GameState.PLAYING:
		pause_game()
	elif state == GameState.PAUSED:
		resume_game()

func set_speed(multiplier: float) -> void:
	speed_multiplier = clampf(multiplier, 0.5, 3.0)
	Engine.time_scale = speed_multiplier

func end_game(victory: bool) -> void:
	state = GameState.VICTORY if victory else GameState.DEFEAT
	Engine.time_scale = 1.0
	EventBus.game_over.emit(victory)

# === 波次 API ===

func next_wave() -> void:
	if wave_system == null:
		push_error("GameEngine: wave_system not registered")
		return
	current_wave += 1
	wave_system.start_wave(current_wave)

# === 建造 API ===

func can_build_at(grid_pos: Vector2i) -> bool:
	if grid_system == null:
		return false
	return grid_system.is_buildable(grid_pos)

func build_tower(tower_id: String, grid_pos: Vector2i) -> Node2D:
	if not can_build_at(grid_pos):
		return null
	var tower_data := DataManager.get_tower(tower_id)
	if tower_data.is_empty():
		push_error("GameEngine: tower_id '%s' not found" % tower_id)
		return null
	var cost: int = tower_data.get("cost", 0)
	if not economy_system.can_afford(cost):
		return null
	economy_system.spend(cost)
	var tower := unit_system.spawn_tower(tower_id, grid_pos)
	grid_system.occupy(grid_pos)
	EventBus.tower_placed.emit(tower, grid_pos)
	return tower

func sell_tower(tower: Node2D) -> void:
	if tower == null:
		return
	var refund: int = tower.get_sell_value()
	var grid_pos: Vector2i = tower.grid_pos
	economy_system.earn(refund)
	grid_system.free_tile(grid_pos)
	EventBus.tower_sold.emit(tower, refund)
	tower.queue_free()

# === 查询 API ===

func get_enemies_in_range(center: Vector2, radius: float) -> Array[Node2D]:
	if unit_system == null:
		return []
	return unit_system.get_enemies_in_range(center, radius)

func get_path_points() -> PackedVector2Array:
	if path_system == null:
		return PackedVector2Array()
	return path_system.get_path_points()

# === 生命周期 ===

func _ready() -> void:
	EventBus.all_waves_completed.connect(_on_all_waves_completed)
	EventBus.lives_changed.connect(_on_lives_changed)

func _on_all_waves_completed() -> void:
	end_game(true)

func _on_lives_changed(current: int, _delta: int) -> void:
	if current <= 0:
		end_game(false)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
	elif event.is_action_pressed("speed_up") and state == GameState.PLAYING:
		var new_speed := 1.0 if speed_multiplier > 1.0 else 2.0
		set_speed(new_speed)
