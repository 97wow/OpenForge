## GamePack - 运行时表示
## 一个 GamePack 就是一个完整的游戏模式（TD/MOBA/RPG/生存）
class_name GamePack
extends RefCounted

var pack_id: String = ""
var pack_path: String = ""
var metadata: Dictionary = {}
var script_instance: Node = null  # GamePackScript

func get_name() -> String:
	return metadata.get("name", pack_id)

func get_version() -> String:
	return metadata.get("version", "0.0.0")

func get_description() -> String:
	return metadata.get("description", "")
