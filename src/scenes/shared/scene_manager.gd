## SceneManager - 场景切换管理
## 通过 pending_data 传递场景间数据（避免时序问题）
extends Node

var _transition_rect: ColorRect = null
var _is_transitioning: bool = false

## 待传递数据：新场景在 _ready 中读取此字段
var pending_data: Dictionary = {}

# 场景注册表
var _scenes: Dictionary = {
	"welcome": "res://src/scenes/welcome/welcome_screen.tscn",
	"lobby": "res://src/scenes/lobby/main_menu.tscn",
	"map_select": "res://src/scenes/map_select/map_select.tscn",
	"battle": "res://src/main.tscn",
	"talents": "res://src/scenes/talents/talents.tscn",
	"leaderboard": "res://src/scenes/leaderboard/leaderboard.tscn",
	"battle_pass": "res://src/scenes/battle_pass/battle_pass.tscn",
	# character_select / difficulty_select 由 GamePack 注册（不同游戏不同角色/难度）
}

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	canvas.name = "TransitionLayer"
	add_child(canvas)

	_transition_rect = ColorRect.new()
	_transition_rect.color = Color(0, 0, 0, 0)
	_transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	# 先存数据，新场景 _ready 时直接读
	pending_data = data
	# 淡出
	var tween := create_tween()
	tween.tween_property(_transition_rect, "color:a", 1.0, 0.3)
	await tween.finished
	# 切换场景
	get_tree().change_scene_to_file(_scenes[scene_id])
	# 等场景加载完
	await get_tree().process_frame
	await get_tree().process_frame
	# 淡入
	var tween2 := create_tween()
	tween2.tween_property(_transition_rect, "color:a", 0.0, 0.3)
	await tween2.finished
	_is_transitioning = false

func goto_scene_instant(scene_id: String, data: Dictionary = {}) -> void:
	if not _scenes.has(scene_id):
		push_error("[SceneManager] Scene '%s' not registered" % scene_id)
		return
	pending_data = data
	get_tree().change_scene_to_file(_scenes[scene_id])
