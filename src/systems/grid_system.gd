## GridSystem - 网格管理
## 管理地图格子状态（可建造/已占用/不可用）
class_name GridSystem
extends Node2D

const CELL_SIZE := Vector2(64, 64)

enum TileState { EMPTY, BUILDABLE, OCCUPIED, PATH, BLOCKED }

var _grid: Dictionary = {}  # Vector2i -> TileState
var _grid_size: Vector2i = Vector2i.ZERO

func init_grid(width: int, height: int, layout: Array) -> void:
	_grid_size = Vector2i(width, height)
	_grid.clear()
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if layout.size() > y and layout[y] is Array:
				var row: Array = layout[y]
				if row.size() > x:
					_grid[pos] = row[x] as TileState
				else:
					_grid[pos] = TileState.EMPTY
			else:
				_grid[pos] = TileState.EMPTY

func is_buildable(grid_pos: Vector2i) -> bool:
	return _grid.get(grid_pos, TileState.EMPTY) == TileState.BUILDABLE

func occupy(grid_pos: Vector2i) -> void:
	if _grid.has(grid_pos):
		_grid[grid_pos] = TileState.OCCUPIED

func free_tile(grid_pos: Vector2i) -> void:
	if _grid.has(grid_pos):
		_grid[grid_pos] = TileState.BUILDABLE

func get_tile_state(grid_pos: Vector2i) -> TileState:
	return _grid.get(grid_pos, TileState.EMPTY)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos) * CELL_SIZE + CELL_SIZE * 0.5

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i((world_pos / CELL_SIZE).floor())

func get_buildable_tiles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for pos in _grid:
		if _grid[pos] == TileState.BUILDABLE:
			result.append(pos)
	return result

func get_grid_size() -> Vector2i:
	return _grid_size
