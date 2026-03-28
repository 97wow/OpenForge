## Main - OpenForge 启动器
## 最小化：初始化框架系统，加载指定 GamePack
extends Node2D

func _ready() -> void:
	# 系统自注册到 EngineAPI（通过各自的 _ready）
	# 等一帧确保所有 autoload 和子系统就绪
	await get_tree().process_frame

	EventBus.emit_event("engine_ready")

	# 加载 GamePack
	var pack_id := _get_pack_id()
	var loader := EngineAPI.get_system("pack_loader") as GamePackLoader
	if loader:
		var pack := loader.load_pack(pack_id)
		if pack == null:
			push_error("[Main] Failed to load GamePack: %s" % pack_id)
	else:
		push_error("[Main] GamePackLoader not found")

func _get_pack_id() -> String:
	# 支持命令行参数 --pack=xxx
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--pack="):
			return arg.substr(7)
	return "tower_defense"
