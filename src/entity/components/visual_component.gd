## VisualComponent - 视觉渲染 + 血条
## 加载 GamePack 提供的视觉场景，或创建占位符
## 自动为有 health 组件的实体显示血条
extends Node

var _entity: Node2D = null
var _visual_node: Node2D = null
var _hp_bar_bg: ColorRect = null
var _hp_bar_fill: ColorRect = null
var _entity_size: float = 16.0
var _show_hp_bar: bool = true

func setup(data: Dictionary) -> void:
	var scene_path: String = data.get("scene", "")
	var color_hex: String = data.get("color", "")
	_entity_size = data.get("size", 16.0)
	_show_hp_bar = data.get("show_hp_bar", true)

	if scene_path != "":
		var scene := load(scene_path) as PackedScene
		if scene:
			_visual_node = scene.instantiate() as Node2D

	if _visual_node == null:
		_visual_node = _create_placeholder(color_hex, _entity_size)

func _on_attached(entity: Node2D) -> void:
	_entity = entity
	if _visual_node:
		entity.add_child(_visual_node)
	if _show_hp_bar:
		_create_hp_bar()

func _on_detached() -> void:
	if _visual_node and is_instance_valid(_visual_node):
		_visual_node.queue_free()

func _process(_delta: float) -> void:
	if not _show_hp_bar or _entity == null or _hp_bar_fill == null:
		return
	var health: Node = _entity.get_component("health") if _entity.has_method("get_component") else null
	if health == null:
		if _hp_bar_bg:
			_hp_bar_bg.visible = false
		return

	var ratio: float = health.current_hp / health.max_hp if health.max_hp > 0 else 0
	_hp_bar_fill.size.x = _entity_size * 1.5 * ratio
	_hp_bar_bg.visible = ratio < 1.0  # 满血不显示

	# 颜色：绿→黄→红
	if ratio > 0.5:
		_hp_bar_fill.color = Color(0.2, 0.85, 0.2)
	elif ratio > 0.25:
		_hp_bar_fill.color = Color(0.9, 0.8, 0.1)
	else:
		_hp_bar_fill.color = Color(0.9, 0.15, 0.15)

func _create_hp_bar() -> void:
	var bar_width: float = _entity_size * 1.5
	var bar_height: float = 3.0
	var bar_y: float = -_entity_size * 0.5 - 6.0

	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0.15, 0.15, 0.15, 0.8)
	_hp_bar_bg.position = Vector2(-bar_width * 0.5, bar_y)
	_hp_bar_bg.size = Vector2(bar_width, bar_height)
	_hp_bar_bg.visible = false
	_entity.add_child(_hp_bar_bg)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color = Color(0.2, 0.85, 0.2)
	_hp_bar_fill.position = Vector2(-bar_width * 0.5, bar_y)
	_hp_bar_fill.size = Vector2(bar_width, bar_height)
	_entity.add_child(_hp_bar_fill)

func _create_placeholder(color_hex: String, size: float) -> Node2D:
	var sprite := Sprite2D.new()
	var image := Image.create(int(size), int(size), false, Image.FORMAT_RGBA8)
	var color := Color.WHITE
	if color_hex != "":
		color = Color.from_string(color_hex, Color.WHITE)
	else:
		color = Color.from_hsv(randf(), 0.7, 0.9)
	image.fill(color)
	var texture := ImageTexture.create_from_image(image)
	sprite.texture = texture
	return sprite

func get_visual_node() -> Node2D:
	return _visual_node
