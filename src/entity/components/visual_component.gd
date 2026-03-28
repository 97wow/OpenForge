## VisualComponent - 视觉渲染
## 加载 GamePack 提供的视觉场景，或创建占位符
extends Node

var _entity: Node2D = null
var _visual_node: Node2D = null

func setup(data: Dictionary) -> void:
	var scene_path: String = data.get("scene", "")
	var color_hex: String = data.get("color", "")
	var size: float = data.get("size", 16.0)

	if scene_path != "":
		# 加载 GamePack 提供的视觉场景
		var scene := load(scene_path) as PackedScene
		if scene:
			_visual_node = scene.instantiate() as Node2D

	if _visual_node == null:
		# 创建占位符（彩色方块）
		_visual_node = _create_placeholder(color_hex, size)

func _on_attached(entity: Node2D) -> void:
	_entity = entity
	if _visual_node:
		entity.add_child(_visual_node)

func _on_detached() -> void:
	if _visual_node and is_instance_valid(_visual_node):
		_visual_node.queue_free()

func _create_placeholder(color_hex: String, size: float) -> Node2D:
	var sprite := Sprite2D.new()
	# 创建一个简单的彩色纹理
	var image := Image.create(int(size), int(size), false, Image.FORMAT_RGBA8)
	var color := Color.WHITE
	if color_hex != "":
		color = Color.from_string(color_hex, Color.WHITE)
	else:
		# 根据 hash 生成伪随机颜色
		color = Color.from_hsv(randf(), 0.7, 0.9)
	image.fill(color)
	var texture := ImageTexture.create_from_image(image)
	sprite.texture = texture
	return sprite

func get_visual_node() -> Node2D:
	return _visual_node
