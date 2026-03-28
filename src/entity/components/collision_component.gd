## CollisionComponent - 碰撞体管理
## 为实体添加 Area2D 用于范围检测、点击等
extends Node

var _entity: Node2D = null
var _area: Area2D = null

func setup(data: Dictionary) -> void:
	var shape_type: String = data.get("shape", "circle")
	var radius: float = data.get("radius", 16.0)
	var width: float = data.get("width", 32.0)
	var height: float = data.get("height", 32.0)

	_area = Area2D.new()
	_area.name = "CollisionArea"
	var collision := CollisionShape2D.new()

	match shape_type:
		"circle":
			var shape := CircleShape2D.new()
			shape.radius = radius
			collision.shape = shape
		"rect":
			var shape := RectangleShape2D.new()
			shape.size = Vector2(width, height)
			collision.shape = shape

	_area.add_child(collision)

func _on_attached(entity: Node2D) -> void:
	_entity = entity
	if _area:
		entity.add_child(_area)

func _on_detached() -> void:
	if _area and is_instance_valid(_area):
		_area.queue_free()

func get_area() -> Area2D:
	return _area
