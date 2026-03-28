## DebugOverlay - 框架级调试信息覆盖层
## GamePack 出错时直接在游戏画面上显示，不需要看控制台
## 生产环境可通过 enabled = false 关闭
extends Node

var enabled: bool = true
var max_messages: int = 8  # 屏幕上最多显示条数
var message_duration: float = 6.0  # 每条消息显示时长

var _canvas: CanvasLayer = null
var _container: VBoxContainer = null
var _error_count: int = 0
var _warning_count: int = 0

func _ready() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 99  # 在 UI 之上，过渡层之下
	_canvas.name = "DebugOverlay"
	add_child(_canvas)

	# 右上角容器
	_container = VBoxContainer.new()
	_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_container.offset_left = -450
	_container.offset_top = 50
	_container.offset_right = -10
	_container.offset_bottom = 500
	_container.add_theme_constant_override("separation", 4)
	_canvas.add_child(_container)

## 显示错误（红色，GamePack 级别的运行时错误）
func log_error(source: String, message: String) -> void:
	_error_count += 1
	_add_message("[ERROR] [%s] %s" % [source, message], Color(1, 0.25, 0.2, 0.95))
	push_error("[GamePack:%s] %s" % [source, message])

## 显示警告（黄色）
func log_warning(source: String, message: String) -> void:
	_warning_count += 1
	_add_message("[WARN] [%s] %s" % [source, message], Color(1, 0.8, 0.2, 0.9))
	push_warning("[GamePack:%s] %s" % [source, message])

## 显示信息（灰色，调试用）
func log_info(source: String, message: String) -> void:
	_add_message("[INFO] [%s] %s" % [source, message], Color(0.7, 0.7, 0.8, 0.8))

func _add_message(text: String, color: Color) -> void:
	if not enabled:
		return

	# 超出最大数量，移除最旧的
	while _container.get_child_count() >= max_messages:
		var oldest := _container.get_child(0)
		oldest.queue_free()

	var panel := PanelContainer.new()
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 0.75)
	stylebox.corner_radius_top_left = 4
	stylebox.corner_radius_top_right = 4
	stylebox.corner_radius_bottom_left = 4
	stylebox.corner_radius_bottom_right = 4
	stylebox.content_margin_left = 8
	stylebox.content_margin_right = 8
	stylebox.content_margin_top = 4
	stylebox.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", stylebox)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.add_child(label)

	_container.add_child(panel)

	# 自动消失
	var tween := panel.create_tween()
	tween.tween_interval(message_duration)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(panel.queue_free)

func get_error_count() -> int:
	return _error_count

func get_warning_count() -> int:
	return _warning_count

func clear() -> void:
	for child in _container.get_children():
		child.queue_free()
	_error_count = 0
	_warning_count = 0
