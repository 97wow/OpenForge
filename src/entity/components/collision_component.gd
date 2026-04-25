## CollisionComponent - 碰撞体管理
## 为实体添加 Area3D 用于范围检测、点击等
extends Node

var _entity: Node3D = null
var _area: Area3D = null

func setup(data: Dictionary) -> void:
	var shape_type: String = data.get("shape", "circle")
	var radius: float = data.get("radius", 16.0)
	var width: float = data.get("width", 32.0)
	var height: float = data.get("height", 32.0)

	_area = Area3D.new()
	_area.name = "CollisionArea"
	var collision := CollisionShape3D.new()

	match shape_type:
		"circle":
			var shape := SphereShape3D.new()
			shape.radius = radius
			collision.shape = shape
		"rect":
			var shape := BoxShape3D.new()
			shape.size = Vector3(width, 1.0, height)
			collision.shape = shape

	_area.add_child(collision)

func _on_attached(entity: Node3D) -> void:
	_entity = entity
	if _area:
		entity.add_child(_area)

func _on_detached() -> void:
	if _area and is_instance_valid(_area):
		_area.queue_free()

func get_area() -> Area3D:
	return _area
