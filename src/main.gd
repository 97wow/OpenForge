## Main - OpenForge 战斗场景启动器
## 从 SceneManager 接收 pack_id 和 map_id，加载对应 GamePack
extends Node2D

var _scene_data: Dictionary = {}
var _loaded: bool = false

func _ready() -> void:
	# 等系统注册完成
	await get_tree().process_frame
	EventBus.emit_event("engine_ready")
	# 再等一帧让 _on_scene_enter 有机会被调用
	await get_tree().process_frame
	_load_pack()

func _on_scene_enter(data: Dictionary) -> void:
	_scene_data = data

func _load_pack() -> void:
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

func _setup_battle_ui(pack: GamePack) -> void:
	var ui_layer: CanvasLayer = $UI

	# 顶部状态栏
	var top_bar := HBoxContainer.new()
	top_bar.anchors_preset = Control.PRESET_TOP_WIDE
	top_bar.offset_top = 10
	top_bar.offset_bottom = 45
	top_bar.offset_left = 20
	top_bar.offset_right = -20
	ui_layer.add_child(top_bar)

	var pack_label := Label.new()
	pack_label.text = "Pack: %s" % pack.get_name()
	pack_label.add_theme_font_size_override("font_size", 18)
	top_bar.add_child(pack_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	var state_label := Label.new()
	state_label.text = "State: %s" % EngineAPI.get_game_state()
	state_label.add_theme_font_size_override("font_size", 18)
	state_label.name = "StateLabel"
	top_bar.add_child(state_label)

	# 返回按钮
	var back_btn := Button.new()
	back_btn.text = "< Back to Menu"
	back_btn.anchors_preset = Control.PRESET_BOTTOM_LEFT
	back_btn.offset_left = 20
	back_btn.offset_top = -50
	back_btn.offset_right = 170
	back_btn.offset_bottom = -15
	back_btn.pressed.connect(func() -> void: SceneManager.goto_scene("lobby"))
	ui_layer.add_child(back_btn)

	# 中央提示
	var center_label := Label.new()
	center_label.text = "Battle Scene Loaded\n\nGamePack: %s\nMap: %s\n\n(Core gameplay coming in Phase 2)" % [
		pack.get_name(),
		str(_scene_data.get("map_id", "default"))
	]
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.anchors_preset = Control.PRESET_CENTER
	center_label.offset_left = -200
	center_label.offset_top = -60
	center_label.offset_right = 200
	center_label.offset_bottom = 60
	center_label.add_theme_font_size_override("font_size", 16)
	center_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	ui_layer.add_child(center_label)

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
