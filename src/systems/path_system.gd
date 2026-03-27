## PathSystem - 路径管理
## 管理敌人行进路径，支持多路径和分支
class_name PathSystem
extends Node2D

var _paths: Array[Path2D] = []
var _current_path_index: int = 0

func setup_paths(path_data: Array) -> void:
	# 清理旧路径
	for child in get_children():
		child.queue_free()
	_paths.clear()

	for i in range(path_data.size()):
		var points: Array = path_data[i]
		var path := Path2D.new()
		path.name = "Path_%d" % i
		var curve := Curve2D.new()
		for point in points:
			if point is Array and point.size() >= 2:
				curve.add_point(Vector2(point[0], point[1]))
			elif point is Dictionary:
				curve.add_point(Vector2(point.get("x", 0), point.get("y", 0)))
		path.curve = curve
		add_child(path)
		_paths.append(path)

func get_path(index: int = -1) -> Path2D:
	if _paths.is_empty():
		return null
	if index < 0:
		# 轮换路径（多路径支持）
		var path := _paths[_current_path_index % _paths.size()]
		_current_path_index += 1
		return path
	if index < _paths.size():
		return _paths[index]
	return _paths[0]

func get_path_count() -> int:
	return _paths.size()

func get_path_points(index: int = 0) -> PackedVector2Array:
	if index < 0 or index >= _paths.size():
		return PackedVector2Array()
	return _paths[index].curve.get_baked_points()

func get_path_length(index: int = 0) -> float:
	if index < 0 or index >= _paths.size():
		return 0.0
	return _paths[index].curve.get_baked_length()
