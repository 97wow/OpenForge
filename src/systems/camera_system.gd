## CameraSystem — 3D 镜头控制系统（RTS 俯视角 + 跟随 + 震动）
## 支持：RTS 平移/缩放/旋转、跟随目标、过渡、trauma 震动
## Pivot + Arm 模式：Camera3D 位于 pivot 位置的上方后方
class_name CameraSystem
extends Camera3D

# === 模式 ===
enum Mode { FREE = 0, FOLLOW = 1, LOCKED = 2, TRANSITION = 3 }

var mode: int = Mode.FREE
var follow_target: Node3D = null

# === RTS 相机参数 ===
var _pivot_pos: Vector3 = Vector3.ZERO  # 目标注视点（XZ 平面）
var _pitch: float = -55.0              # 下视角度（度），负值 = 向下看
var _yaw: float = 180.0                # 水平旋转（度），从南向北看
var _distance: float = 25.0           # 相机到 pivot 的距离
var _min_distance: float = 5.0
var _max_distance: float = 150.0
var zoom_speed: float = 1.5           # 滚轮缩放速度

# === FOV 控制（War3 风格 Insert/Delete）===
var _fov: float = 70.0
var _min_fov: float = 30.0
var _max_fov: float = 110.0
var _fov_step: float = 5.0

# === 跟随配置 ===
var follow_smoothing: float = 5.0
var follow_offset: Vector3 = Vector3.ZERO
var follow_dead_zone: float = 0.2

# === 平移速度 ===
var pan_speed: float = 10.0
var edge_pan_margin: float = 20.0      # 边缘滚动区域（像素）
var edge_pan_enabled: bool = false      # 默认关闭边缘滚动

# === 限制区域 ===
var _limits_enabled: bool = false
var _limits_rect: Rect2 = Rect2()

# === Trauma-based 震动 ===
var _trauma: float = 0.0
var _trauma_decay: float = 1.5
var _shake_max_offset: float = 0.3
var _noise: FastNoiseLite = null
var _noise_y: float = 0.0

# === 过渡 ===
var _transition_from: Vector3 = Vector3.ZERO
var _transition_to: Vector3 = Vector3.ZERO
var _transition_duration: float = 0.0
var _transition_elapsed: float = 0.0
var _transition_callback: Callable = Callable()

## 后处理描边 quad
var _outline_quad: MeshInstance3D = null
## 移轴模糊 CanvasLayer
var _tilt_shift_layer: CanvasLayer = null

func _ready() -> void:
	EngineAPI.register_system("camera", self)
	# 初始化 noise 用于 trauma shake
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.5
	# 初始位置
	_update_camera_transform()
	# 模型描边由 visual_component 通过 next_pass 材质实现
	# 移轴模糊已移除

func _process(delta: float) -> void:
	match mode:
		Mode.FREE:
			_tick_free_pan(delta)
		Mode.FOLLOW:
			_tick_follow(delta)
		Mode.TRANSITION:
			_tick_transition(delta)

	_update_camera_transform()
	_apply_trauma_shake(delta)

func _unhandled_input(event: InputEvent) -> void:
	# 滚轮缩放（距离远近）
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(_distance - zoom_speed, _min_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(_distance + zoom_speed, _max_distance)
	# Insert/Delete 调节 FOV（War3 风格视角大小）
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_INSERT:
			_fov = clampf(_fov - _fov_step, _min_fov, _max_fov)
			fov = _fov
		elif event.keycode == KEY_DELETE:
			_fov = clampf(_fov + _fov_step, _min_fov, _max_fov)
			fov = _fov
		elif event.keycode == KEY_HOME:
			# Home 键重置默认视角
			_fov = 70.0
			fov = _fov
			_distance = 25.0

# === 公共 API ===

func follow(target: Node3D, smoothing: float = 5.0, cam_offset: Vector3 = Vector3.ZERO) -> void:
	follow_target = target
	follow_smoothing = smoothing
	follow_offset = cam_offset
	mode = Mode.FOLLOW

func stop_follow() -> void:
	follow_target = null
	mode = Mode.FREE

func lock_at(pos: Vector3) -> void:
	_pivot_pos = pos
	mode = Mode.LOCKED

func move_to(pos: Vector3, duration: float = 0.5, callback: Callable = Callable()) -> void:
	_transition_from = _pivot_pos
	_transition_to = pos
	_transition_duration = maxf(duration, 0.01)
	_transition_elapsed = 0.0
	_transition_callback = callback
	mode = Mode.TRANSITION

func set_zoom_level(zoom_level: float) -> void:
	## zoom_level: 1.0 = 默认距离，<1 = 更近，>1 = 更远
	_distance = clampf(25.0 / zoom_level, _min_distance, _max_distance)

func shake(intensity: float = 0.5, decay: float = 1.5) -> void:
	_trauma = clampf(_trauma + intensity, 0.0, 1.0)
	_trauma_decay = decay

func set_limits_rect(rect: Rect2) -> void:
	## 限制 pivot 在 XZ 平面的矩形区域内
	_limits_rect = rect
	_limits_enabled = true

func clear_limits() -> void:
	_limits_enabled = false

func set_pitch(degrees: float) -> void:
	_pitch = clampf(degrees, -89.0, -10.0)

func set_yaw(degrees: float) -> void:
	_yaw = fmod(degrees, 360.0)

func orbit(yaw_delta: float) -> void:
	_yaw = fmod(_yaw + yaw_delta, 360.0)

func get_world_mouse_position() -> Vector3:
	## Raycast 鼠标位置到 XZ 平面（Y=0）
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = project_ray_origin(mouse_pos)
	var dir: Vector3 = project_ray_normal(mouse_pos)
	# 与 Y=0 平面相交
	if abs(dir.y) < 0.001:
		return _pivot_pos
	var t: float = -from.y / dir.y
	if t < 0:
		return _pivot_pos
	return from + dir * t

func _update_dof() -> void:
	## 动态景深：相机越远，景深远端越远（移轴微缩感）
	var we_node: Node = get_tree().current_scene.get_node_or_null("WorldEnvironment")
	if we_node == null or not (we_node is WorldEnvironment):
		return
	var e: Environment = (we_node as WorldEnvironment).environment
	if e == null:
		return
	# 安全访问 DOF 属性（Godot 4.x 属性名可能变化）
	if not e.get("dof_blur_far_enabled"):
		return
	e.set("dof_blur_far_distance", _distance * 1.5)
	e.set("dof_blur_far_transition", _distance * 0.6)
	e.set("dof_blur_amount", clampf(0.03 + (1.0 - _distance / _max_distance) * 0.04, 0.02, 0.08))

# === 内部 ===

func _update_camera_transform() -> void:
	## 根据 pivot/pitch/yaw/distance 计算相机位置和朝向
	var pitch_rad: float = deg_to_rad(_pitch)
	var yaw_rad: float = deg_to_rad(_yaw)

	# 从 pivot 向后上方偏移
	var offset := Vector3.ZERO
	offset.y = -sin(pitch_rad) * _distance  # 向上
	var horizontal_dist: float = cos(pitch_rad) * _distance
	offset.x = -sin(yaw_rad) * horizontal_dist
	offset.z = -cos(yaw_rad) * horizontal_dist

	global_position = _pivot_pos + offset
	look_at(_pivot_pos, Vector3.UP)

func _tick_free_pan(delta: float) -> void:
	var pan_dir := Vector3.ZERO
	# WASD 平移
	if Input.is_action_pressed("move_up"):
		pan_dir.z -= 1
	if Input.is_action_pressed("move_down"):
		pan_dir.z += 1
	if Input.is_action_pressed("move_left"):
		pan_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		pan_dir.x += 1

	# 边缘滚动
	if edge_pan_enabled:
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		if mouse_pos.x < edge_pan_margin:
			pan_dir.x -= 1
		elif mouse_pos.x > vp_size.x - edge_pan_margin:
			pan_dir.x += 1
		if mouse_pos.y < edge_pan_margin:
			pan_dir.z -= 1
		elif mouse_pos.y > vp_size.y - edge_pan_margin:
			pan_dir.z += 1

	if pan_dir != Vector3.ZERO:
		# 旋转平移方向以匹配相机朝向
		var yaw_rad: float = deg_to_rad(_yaw)
		var rotated_dir := Vector3(
			pan_dir.x * cos(yaw_rad) - pan_dir.z * sin(yaw_rad),
			0,
			pan_dir.x * sin(yaw_rad) + pan_dir.z * cos(yaw_rad)
		).normalized()
		_pivot_pos += rotated_dir * pan_speed * delta
		_clamp_pivot()

func _tick_follow(delta: float) -> void:
	if follow_target == null or not is_instance_valid(follow_target):
		mode = Mode.FREE
		return
	var target_pos: Vector3 = follow_target.global_position + follow_offset
	var dist: float = _pivot_pos.distance_to(target_pos)
	if dist > follow_dead_zone:
		_pivot_pos = _pivot_pos.lerp(target_pos, follow_smoothing * delta)
	_clamp_pivot()

func _tick_transition(delta: float) -> void:
	_transition_elapsed += delta
	var t: float = clampf(_transition_elapsed / _transition_duration, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 3.0)  # ease out cubic
	_pivot_pos = _transition_from.lerp(_transition_to, eased)
	if t >= 1.0:
		mode = Mode.FREE
		if _transition_callback.is_valid():
			_transition_callback.call()

func _clamp_pivot() -> void:
	if _limits_enabled:
		_pivot_pos.x = clampf(_pivot_pos.x, _limits_rect.position.x, _limits_rect.end.x)
		_pivot_pos.z = clampf(_pivot_pos.z, _limits_rect.position.y, _limits_rect.end.y)

func _apply_trauma_shake(_delta: float) -> void:
	if _trauma <= 0:
		return
	_trauma = maxf(_trauma - _trauma_decay * _delta, 0.0)
	var shake_power: float = _trauma * _trauma
	_noise_y += _delta * 50.0
	var offset_x: float = _noise.get_noise_2d(1.0, _noise_y) * _shake_max_offset * shake_power
	var offset_z: float = _noise.get_noise_2d(100.0, _noise_y) * _shake_max_offset * shake_power
	# 应用偏移到位置（在 transform 更新后）
	global_position += Vector3(offset_x, 0, offset_z)

# === 后处理描边 ===

func _setup_post_process() -> void:
	var shader_path := "res://assets/shaders/outline.gdshader"
	if not ResourceLoader.exists(shader_path):
		return
	var shader := load(shader_path) as Shader
	if shader == null:
		return

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("outline_threshold", 0.008)
	mat.set_shader_parameter("outline_strength", 0.8)

	var quad := MeshInstance3D.new()
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(2, 2)
	quad.mesh = quad_mesh
	quad.material_override = mat
	quad.position = Vector3(0, 0, -near)
	quad.extra_cull_margin = 10000.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)
	_outline_quad = quad

func set_outline_enabled(enabled: bool) -> void:
	if _outline_quad != null:
		_outline_quad.visible = enabled

func set_outline_strength(strength: float) -> void:
	if _outline_quad == null:
		return
	var mat := _outline_quad.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("outline_strength", clampf(strength, 0.0, 1.0))

# === 移轴模糊（Tilt-Shift） ===

func _setup_tilt_shift() -> void:
	var shader_path := "res://assets/shaders/tilt_shift.gdshader"
	if not ResourceLoader.exists(shader_path):
		return
	var shader := load(shader_path) as Shader
	if shader == null:
		return

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("blur_amount", 2.0)
	mat.set_shader_parameter("focus_center", 0.45)
	mat.set_shader_parameter("focus_width", 0.15)

	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "TiltShiftLayer"
	canvas_layer.layer = 100

	var rect := ColorRect.new()
	rect.name = "TiltShiftRect"
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = mat

	canvas_layer.add_child(rect)
	add_child(canvas_layer)
	_tilt_shift_layer = canvas_layer

func set_tilt_shift_enabled(enabled: bool) -> void:
	if _tilt_shift_layer != null:
		_tilt_shift_layer.visible = enabled

func set_tilt_shift_blur(amount: float) -> void:
	if _tilt_shift_layer == null:
		return
	var rect := _tilt_shift_layer.get_node_or_null("TiltShiftRect") as ColorRect
	if rect == null:
		return
	var mat := rect.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("blur_amount", clampf(amount, 0.0, 3.0))
