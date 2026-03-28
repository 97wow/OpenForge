## SceneManager - 场景切换管理
## 负责欢迎页→大厅→地图选择→战斗的场景流转
## 支持过渡动画
extends Node

var _transition_rect: ColorRect = null
var _is_transitioning: bool = false

# 场景注册表
var _scenes: Dictionary = {
	"welcome": "res://src/scenes/welcome/welcome_screen.tscn",
	"lobby": "res://src/scenes/lobby/main_menu.tscn",
	"map_select": "res://src/scenes/map_select/map_select.tscn",
	"battle": "res://src/main.tscn",
}

func _ready() -> void:
	# 创建过渡遮罩
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	canvas.name = "TransitionLayer"
	add_child(canvas)

	_transition_rect = ColorRect.new()
	_transition_rect.color = Color(0, 0, 0, 0)
	_transition_rect.anchors_preset = Control.PRESET_FULL_RECT
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_transition_rect)

func register_scene(scene_id: String, scene_path: String) -> void:
	_scenes[scene_id] = scene_path

func goto_scene(scene_id: String, data: Dictionary = {}) -> void:
	if _is_transitioning:
		return
	if not _scenes.has(scene_id):
		push_error("[SceneManager] Scene '%s' not registered" % scene_id)
		return
	_is_transitioning = true
	# 淡出
	var tween := create_tween()
	tween.tween_property(_transition_rect, "color:a", 1.0, 0.3)
	await tween.finished
	# 切换场景
	get_tree().change_scene_to_file(_scenes[scene_id])
	# 等一帧让场景加载
	await get_tree().process_frame
	# 传递数据给新场景
	var root := get_tree().current_scene
	if root and root.has_method("_on_scene_enter"):
		root.call("_on_scene_enter", data)
	# 淡入
	var tween2 := create_tween()
	tween2.tween_property(_transition_rect, "color:a", 0.0, 0.3)
	await tween2.finished
	_is_transitioning = false

func goto_scene_instant(scene_id: String, data: Dictionary = {}) -> void:
	if not _scenes.has(scene_id):
		push_error("[SceneManager] Scene '%s' not registered" % scene_id)
		return
	get_tree().change_scene_to_file(_scenes[scene_id])
	await get_tree().process_frame
	var root := get_tree().current_scene
	if root and root.has_method("_on_scene_enter"):
		root.call("_on_scene_enter", data)
