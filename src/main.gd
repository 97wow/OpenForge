## Main - OpenForge 战斗场景启动器
## 从 SceneManager.pending_data 读取 pack_id，加载对应 GamePack
extends Node2D

func _ready() -> void:
	# 等所有子系统 _ready 完成
	await get_tree().process_frame
	EventBus.emit_event("engine_ready")

	# 重置所有框架状态（确保新局干净）
	EngineAPI.reset_all_state()

	# 从 SceneManager 读取数据
	var pack_id: String = _get_pack_id()
	print("[Main] Loading pack: %s" % pack_id)

	var loader := EngineAPI.get_system("pack_loader") as GamePackLoader
	if loader:
		var pack := loader.load_pack(pack_id)
		if pack == null:
			push_error("[Main] Failed to load GamePack: %s" % pack_id)
			_show_error("GamePack '%s' not found" % pack_id)
	else:
		push_error("[Main] GamePackLoader not found")

func _get_pack_id() -> String:
	# 优先从 SceneManager 传递的数据读取
	if SceneManager.pending_data.has("pack_id"):
		return str(SceneManager.pending_data["pack_id"])
	# 命令行参数
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--pack="):
			return arg.substr(7)
	return "tower_defense"

func _show_error(msg: String) -> void:
	var ui_layer: CanvasLayer = $UI
	var label := Label.new()
	label.text = "Error: %s" % msg
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	label.add_theme_font_size_override("font_size", 20)
	ui_layer.add_child(label)

	var back_btn := Button.new()
	back_btn.text = "Back to Menu"
	back_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	back_btn.offset_top = 40
	back_btn.offset_bottom = 75
	back_btn.offset_left = -80
	back_btn.offset_right = 80
	back_btn.pressed.connect(func() -> void: SceneManager.goto_scene("lobby"))
	ui_layer.add_child(back_btn)
