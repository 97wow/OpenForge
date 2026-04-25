## CooldownOverlay — WoW 风格技能冷却旋转遮罩
## 用法：add_child(CooldownOverlay.new()) 到任意 Control 节点
## 调用 start_cooldown(duration) 开始冷却动画
## 半透明黑色扇形遮罩从 12 点方向顺时针旋转
extends Control

var _total_duration: float = 0.0
var _remaining: float = 0.0
var _is_cooling: bool = false
var _cd_label: Label = null

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	# 冷却时间文字
	_cd_label = Label.new()
	_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cd_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_cd_label.add_theme_font_size_override("font_size", 14)
	_cd_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_cd_label.mouse_filter = MOUSE_FILTER_IGNORE
	_cd_label.visible = false
	add_child(_cd_label)
	set_process(false)

func start_cooldown(duration: float) -> void:
	_total_duration = duration
	_remaining = duration
	_is_cooling = true
	if _cd_label:
		_cd_label.visible = duration > 1.0  # 短 CD 不显示数字
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if not _is_cooling:
		return
	_remaining -= delta
	if _remaining <= 0:
		_remaining = 0
		_is_cooling = false
		if _cd_label:
			_cd_label.visible = false
		set_process(false)
	elif _cd_label and _cd_label.visible:
		_cd_label.text = "%.0f" % ceilf(_remaining)
	queue_redraw()

func is_cooling() -> bool:
	return _is_cooling

func get_remaining() -> float:
	return _remaining

func _draw() -> void:
	if not _is_cooling or _total_duration <= 0:
		return
	var ratio: float = _remaining / _total_duration  # 1.0 → 0.0
	if ratio <= 0:
		return
	# 扇形遮罩：从 12 点方向顺时针画 ratio 比例的扇形
	var center := size / 2.0
	# 用对角线长度确保完全覆盖（clip_contents 由父容器裁剪）
	var radius: float = center.length() + 2.0
	var start_angle: float = -PI / 2.0  # 12 点方向
	var sweep_angle: float = ratio * TAU  # 剩余比例 × 360°
	var color := Color(0, 0, 0, 0.55)
	# 用多边形近似扇形
	var points := PackedVector2Array()
	points.append(center)
	var segments: int = maxi(int(sweep_angle / 0.1), 8)
	for i in range(segments + 1):
		var angle: float = start_angle + sweep_angle * (float(i) / segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)
