## GridSystem - 通用网格系统
## Tile 状态用字符串表示，GamePack 自定义语义
## TD 用 "buildable"/"path"/"occupied"，RPG 用 "walkable"/"wall" 等
class_name GridSystem
extends Node2D

var cell_size: Vector2 = Vector2(64, 64)
var _grid: Dictionary = {}  # Vector2i -> String (state)
var _grid_size: Vector2i = Vector2i.ZERO

func _ready() -> void:
	EngineAPI.register_system("grid", self)

# === 初始化 ===

func init_grid(width: int, height: int, default_state: String = "empty") -> void:
	_grid_size = Vector2i(width, height)
	_grid.clear()
	for y in range(height):
		for x in range(width):
			_grid[Vector2i(x, y)] = default_state

func init_from_layout(width: int, height: int, layout: Array, state_map: Dictionary) -> void:
	_grid_size = Vector2i(width, height)
	_grid.clear()
	for y in range(height):
		for x in range(width):
			var value := 0
			if y < layout.size() and layout[y] is Array:
				var row: Array = layout[y]
				if x < row.size():
					value = int(row[x])
			var state: String = state_map.get(value, "empty")
			_grid[Vector2i(x, y)] = state

# === Tile 操作 ===

func set_tile(pos: Vector2i, state: String) -> void:
	_grid[pos] = state

func get_tile(pos: Vector2i) -> String:
	return _grid.get(pos, "")

func find_tiles(state: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for pos in _grid:
		if _grid[pos] == state:
			result.append(pos)
	return result

func is_tile(pos: Vector2i, state: String) -> bool:
	return _grid.get(pos, "") == state

func is_valid_pos(pos: Vector2i) -> bool:
	return _grid.has(pos)

# === 坐标转换 ===

func set_cell_size(size: Vector2) -> void:
	cell_size = size

func grid_to_world(pos: Vector2i) -> Vector2:
	return Vector2(pos) * cell_size + cell_size * 0.5

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i((world_pos / cell_size).floor())

# === 查询 ===

func get_grid_size() -> Vector2i:
	return _grid_size

func get_neighbors(pos: Vector2i, include_diagonal: bool = false) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var offsets := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	if include_diagonal:
		offsets.append_array([
			Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
		])
	for offset in offsets:
		var neighbor := pos + offset
		if _grid.has(neighbor):
			result.append(neighbor)
	return result
