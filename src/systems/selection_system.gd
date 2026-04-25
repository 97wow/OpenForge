## SelectionSystem - RTS 风格实体选择与指令系统
## 左键选择实体，右键发出移动/攻击指令
## 使用距离拾取（无物理体），选择圈 TorusMesh 视觉反馈
## 支持框选（拖拽矩形选择区域内实体）
class_name SelectionSystem
extends Node

const _PICK_RADIUS: float = 1.5
const _CIRCLE_INNER: float = 0.5
const _CIRCLE_OUTER: float = 0.65
const _CIRCLE_Y_OFFSET: float = 0.05
const _PLAYER_FACTION: String = "player"

var _selected_entity: Node3D = null
var _selection_circle: MeshInstance3D = null
var _circle_material: StandardMaterial3D = null

# === 框选状态 ===
var _is_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_rect: Control = null
var _drag_threshold: float = 5.0
var _mouse_pressed: bool = false

# === 生命周期 ===

func _ready() -> void:
	EngineAPI.register_system("selection", self)
	_create_selection_circle()
	call_deferred("_setup_drag_rect")

func _process(_delta: float) -> void:
	# 验证选中实体是否仍然有效
	if _selected_entity != null:
		if not is_instance_valid(_selected_entity):
			_force_deselect()
			return
		if _selected_entity is GameEntity and not _selected_entity.is_alive:
			deselect()
			return
		# 跟随实体位置
		if _selection_circle and _selection_circle.visible:
			_selection_circle.global_position = Vector3(
				_selected_entity.global_position.x,
				_CIRCLE_Y_OFFSET,
				_selected_entity.global_position.z
			)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_start = event.position
				_mouse_pressed = true
				_is_dragging = false
			else:
				# 松开左键
				if _is_dragging:
					_box_select(event.position)
					_end_drag()
				else:
					_handle_select()
				_mouse_pressed = false
				_is_dragging = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if _is_dragging:
					# 右键取消框选
					_end_drag()
					_mouse_pressed = false
					_is_dragging = false
				else:
					_handle_command()

	# ESC 取消选中
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _selected_entity != null:
			deselect()

	elif event is InputEventMouseMotion and _mouse_pressed:
		var dist: float = event.position.distance_to(_drag_start)
		if dist > _drag_threshold:
			_is_dragging = true
			_update_drag_rect(event.position)

# === 公共 API ===

func select_entity(entity: Node3D) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	_select_entity(entity)

func deselect() -> void:
	if _selected_entity == null:
		return
	var prev := _selected_entity
	_selected_entity = null
	_hide_selection_circle()
	EventBus.emit_event("entity_deselected", {"entity": prev})

func get_selected_entity() -> Node3D:
	if _selected_entity != null and not is_instance_valid(_selected_entity):
		_force_deselect()
		return null
	return _selected_entity

func _reset() -> void:
	_force_deselect()
	_end_drag()
	_mouse_pressed = false
	_is_dragging = false

# === 选择逻辑 ===

func _handle_select() -> void:
	var camera := EngineAPI.get_system("camera") as Node
	if camera == null or not camera.has_method("get_world_mouse_position"):
		return
	var world_pos: Vector3 = camera.call("get_world_mouse_position")
	var candidates: Array = EngineAPI.find_entities_in_area(world_pos, _PICK_RADIUS, "")
	var best: Node3D = null
	var best_dist: float = INF
	for candidate in candidates:
		if not (candidate is GameEntity):
			continue
		var ge: GameEntity = candidate as GameEntity
		if not ge.is_alive:
			continue
		if ge.has_unit_flag(UnitFlags.NOT_SELECTABLE):
			continue
		if ge.has_tag("projectile"):
			continue
		var dist: float = world_pos.distance_to(ge.global_position)
		if dist < best_dist:
			best_dist = dist
			best = ge
	if best != null:
		_select_entity(best)
	else:
		deselect()

func _select_entity(entity: Node3D) -> void:
	if _selected_entity == entity:
		return
	# 先取消之前的选择
	if _selected_entity != null:
		deselect()
	_selected_entity = entity
	_show_selection_circle(entity)
	EngineAPI.play_sfx("res://assets/audio/sfx/select_unit.ogg")
	EventBus.emit_event("entity_selected", {"entity": entity})

# === 框选逻辑 ===

func _box_select(end_pos: Vector2) -> void:
	var camera := EngineAPI.get_system("camera") as Camera3D
	if camera == null:
		return

	# 构建屏幕空间矩形
	var top_left := Vector2(
		minf(_drag_start.x, end_pos.x),
		minf(_drag_start.y, end_pos.y)
	)
	var bot_right := Vector2(
		maxf(_drag_start.x, end_pos.x),
		maxf(_drag_start.y, end_pos.y)
	)
	var screen_rect := Rect2(top_left, bot_right - top_left)

	# 收集所有可选实体
	var all_entities: Array = EngineAPI.find_entities_by_tag("")
	var matched: Array[GameEntity] = []

	for entity in all_entities:
		if not is_instance_valid(entity):
			continue
		if not (entity is GameEntity):
			continue
		var ge: GameEntity = entity as GameEntity
		if not ge.is_alive:
			continue
		if ge.has_unit_flag(UnitFlags.NOT_SELECTABLE):
			continue
		if ge.has_tag("projectile"):
			continue

		# 将世界坐标投影到屏幕坐标
		var screen_point: Vector2 = camera.unproject_position(ge.global_position)

		# 检查是否在相机前方（避免选中背后的实体）
		if not camera.is_position_behind(ge.global_position):
			if screen_rect.has_point(screen_point):
				matched.append(ge)

	if matched.is_empty():
		deselect()
		return

	# 优先选择玩家阵营实体
	var player_entities: Array[GameEntity] = []
	for ge in matched:
		if ge.faction == _PLAYER_FACTION:
			player_entities.append(ge)

	# 如果有玩家阵营实体，优先选择；否则选第一个
	var to_select: GameEntity
	if not player_entities.is_empty():
		to_select = player_entities[0]
	else:
		to_select = matched[0]

	_select_entity(to_select)

	# 发出框选事件，包含所有匹配实体（便于未来多选扩展）
	EventBus.emit_event("box_selected", {
		"selected": to_select,
		"all_matched": matched,
		"count": matched.size(),
	})

# === 框选视觉 ===

func _setup_drag_rect() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.current_scene
	if root == null:
		return

	# 尝试找到 UI CanvasLayer，否则用场景根节点
	var ui_layer: Node = root.get_node_or_null("UI")
	if ui_layer == null:
		ui_layer = root

	_drag_rect = _SelectionRect.new()
	_drag_rect.visible = false
	_drag_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_rect.z_index = 50
	ui_layer.add_child(_drag_rect)

func _update_drag_rect(current_pos: Vector2) -> void:
	if _drag_rect == null:
		return
	var top_left := Vector2(
		minf(_drag_start.x, current_pos.x),
		minf(_drag_start.y, current_pos.y)
	)
	var bot_right := Vector2(
		maxf(_drag_start.x, current_pos.x),
		maxf(_drag_start.y, current_pos.y)
	)
	_drag_rect.position = top_left
	_drag_rect.size = bot_right - top_left
	_drag_rect.visible = true
	_drag_rect.queue_redraw()

func _end_drag() -> void:
	if _drag_rect != null:
		_drag_rect.visible = false

# === 指令逻辑 ===

func _handle_command() -> void:
	if _selected_entity == null or not is_instance_valid(_selected_entity):
		return
	if not (_selected_entity is GameEntity):
		return
	var ge: GameEntity = _selected_entity as GameEntity
	# 只有玩家阵营实体可接受指令
	if ge.faction != _PLAYER_FACTION:
		return
	var camera := EngineAPI.get_system("camera") as Node
	if camera == null or not camera.has_method("get_world_mouse_position"):
		return
	var world_pos: Vector3 = camera.call("get_world_mouse_position")
	# 检查点击位置是否有敌对实体
	var hostile: Node3D = _find_hostile_at(ge, world_pos)
	if hostile != null:
		EventBus.emit_event("attack_command", {
			"entity": _selected_entity,
			"target": hostile,
		})
	else:
		EventBus.emit_event("move_command", {
			"entity": _selected_entity,
			"position": world_pos,
		})
		EngineAPI.play_sfx("res://assets/audio/sfx/move_command.ogg")
		# 通过 MovementGenerator 执行移动
		var mg := EngineAPI.get_system("movement_gen") as Node
		if mg:
			mg.call("move_point", _selected_entity, world_pos, 0.5)

func _find_hostile_at(source: GameEntity, pos: Vector3) -> Node3D:
	var candidates: Array = EngineAPI.find_entities_in_area(pos, _PICK_RADIUS, "")
	var best: Node3D = null
	var best_dist: float = INF
	for candidate in candidates:
		if not (candidate is GameEntity):
			continue
		var ge: GameEntity = candidate as GameEntity
		if not ge.is_alive:
			continue
		if not source.is_hostile_to(ge):
			continue
		var dist: float = pos.distance_to(ge.global_position)
		if dist < best_dist:
			best_dist = dist
			best = ge
	return best

# === 选择圈视觉 ===

func _create_selection_circle() -> void:
	_selection_circle = MeshInstance3D.new()
	# 用 QuadMesh 做扁平地面贴花（替代 TorusMesh 避免穿模）
	var quad := QuadMesh.new()
	var ring_size: float = (_CIRCLE_INNER + _CIRCLE_OUTER)
	quad.size = Vector2(ring_size, ring_size)
	_selection_circle.mesh = quad
	_circle_material = StandardMaterial3D.new()
	_circle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_circle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_circle_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_circle_material.albedo_color = Color(0.0, 1.0, 0.0, 0.4)
	_selection_circle.material_override = _circle_material
	_selection_circle.rotation_degrees.x = -90.0  # 水平朝上
	_selection_circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_selection_circle.visible = false
	add_child(_selection_circle)

func _show_selection_circle(entity: Node3D) -> void:
	if _selection_circle == null:
		return
	# 颜色：友方绿色，敌方红色
	if entity is GameEntity:
		var ge: GameEntity = entity as GameEntity
		if ge.faction == _PLAYER_FACTION:
			_circle_material.albedo_color = Color(0.0, 1.0, 0.0, 0.6)
		else:
			_circle_material.albedo_color = Color(1.0, 0.0, 0.0, 0.6)
	# 缩放：根据实体可视大小（如有）
	var scale_factor: float = _get_entity_visual_scale(entity)
	_selection_circle.scale = Vector3(scale_factor, scale_factor, scale_factor)
	# 位置
	_selection_circle.global_position = Vector3(
		entity.global_position.x,
		0.05,  # 紧贴地面
		entity.global_position.z
	)
	_selection_circle.visible = true

func _hide_selection_circle() -> void:
	if _selection_circle != null:
		_selection_circle.visible = false

func _get_entity_visual_scale(entity: Node3D) -> float:
	## 尝试从实体 meta 或组件获取视觉大小，默认 1.0
	if entity is GameEntity:
		var ge: GameEntity = entity as GameEntity
		var visual_scale = ge.meta.get("selection_scale", 0.0)
		if visual_scale > 0.0:
			return float(visual_scale)
		var visual_size = ge.meta.get("visual_size", 0.0)
		if visual_size > 0.0:
			return float(visual_size)
	return 1.0

func _force_deselect() -> void:
	## 实体已被释放时的安全清理（不发事件中的 entity 引用）
	_selected_entity = null
	_hide_selection_circle()

# === 框选矩形内部类 ===

class _SelectionRect extends Control:
	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		# 半透明绿色填充
		draw_rect(rect, Color(0.2, 0.8, 0.2, 0.08))
		# 绿色边框
		draw_rect(rect, Color(0.3, 1.0, 0.3, 0.8), false, 1.0)
