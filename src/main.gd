## Main - OpenForge 战斗场景启动器
## 从 SceneManager 接收 pack_id 和 map_id，加载对应 GamePack
extends Node2D

var _scene_data: Dictionary = {}

func _ready() -> void:
	await get_tree().process_frame
	EventBus.emit_event("engine_ready")

	# 加载 GamePack
	var pack_id: String = str(_scene_data.get("pack_id", _get_pack_id()))
	var loader := EngineAPI.get_system("pack_loader") as GamePackLoader
	if loader:
		var pack := loader.load_pack(pack_id)
		if pack == null:
			push_error("[Main] Failed to load GamePack: %s" % pack_id)
	else:
		push_error("[Main] GamePackLoader not found")

func _on_scene_enter(data: Dictionary) -> void:
	## 由 SceneManager 调用，传入 pack_id 和 map_id
	_scene_data = data

func _get_pack_id() -> String:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--pack="):
			return arg.substr(7)
	return "tower_defense"
