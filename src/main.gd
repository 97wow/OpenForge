## Main - OpenForge 战斗场景启动器
## 从 SceneManager 接收 pack_id 和 map_id，加载对应 GamePack
extends Node2D

var _scene_data: Dictionary = {}
var _loaded: bool = false
var _systems_ready: bool = false

func _ready() -> void:
	await get_tree().process_frame
	_systems_ready = true
	EventBus.emit_event("engine_ready")
	# 延迟兜底：如果 _on_scene_enter 没被调用（直接运行 main.tscn）
	get_tree().create_timer(0.5).timeout.connect(_fallback_load)

func _on_scene_enter(data: Dictionary) -> void:
	_scene_data = data
	# 等系统就绪后再加载
	if _systems_ready:
		_do_load()
	else:
		# 系统还没 ready，等一下
		await get_tree().process_frame
		await get_tree().process_frame
		_do_load()

func _fallback_load() -> void:
	# 兜底：如果0.5秒后还没加载（直接F5运行main.tscn的情况）
	if not _loaded:
		_do_load()

func _do_load() -> void:
	if _loaded:
		return
	_loaded = true

	var pack_id: String = str(_scene_data.get("pack_id", _get_pack_id()))
	var loader := EngineAPI.get_system("pack_loader") as GamePackLoader
	if loader:
		var pack := loader.load_pack(pack_id)
		if pack:
			_setup_battle_ui(pack)
		else:
			push_error("[Main] Failed to load GamePack: %s" % pack_id)
			_show_error("GamePack '%s' not found" % pack_id)
	else:
		push_error("[Main] GamePackLoader not found")

func _get_pack_id() -> String:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--pack="):
			return arg.substr(7)
	return "tower_defense"

func _setup_battle_ui(_pack: GamePack) -> void:
	# rogue_survivor 自带 HUD，不需要这里额外创建
	# 只加一个返回按钮作为兜底
	pass

func _show_error(msg: String) -> void:
	var ui_layer: CanvasLayer = $UI
	var label := Label.new()
	label.text = "Error: %s" % msg
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchors_preset = Control.PRESET_CENTER
	label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	label.add_theme_font_size_override("font_size", 20)
	ui_layer.add_child(label)

	var back_btn := Button.new()
	back_btn.text = "Back to Menu"
	back_btn.anchors_preset = Control.PRESET_CENTER
	back_btn.offset_top = 40
	back_btn.offset_bottom = 75
	back_btn.offset_left = -80
	back_btn.offset_right = 80
	back_btn.pressed.connect(func() -> void: SceneManager.goto_scene("lobby"))
	ui_layer.add_child(back_btn)
