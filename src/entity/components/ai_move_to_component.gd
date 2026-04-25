## AIMoveToComponent - AI 移动到目标
## 让实体自动向指定目标或位置移动
## 到达攻击范围后停下并攻击
extends Node

var _entity: Node3D = null
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _movement: Node = null
var target_tag: String = ""
var target_entity: Node3D = null
var attack_range: float = 2.0
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _reached: bool = false
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _search_timer: float = 0.0
const SEARCH_INTERVAL := 0.5  # 每 0.5 秒重新搜索目标（而非每帧）

func setup(data: Dictionary) -> void:
	target_tag = data.get("target_tag", "")
	attack_range = data.get("attack_range", 30.0)

func _on_attached(entity: Node3D) -> void:
	_entity = entity
	set_process(false)  # 由 EntitySystem 中心化更新

func _process(_delta: float) -> void:
	pass  # 由 EntitySystem 中心化更新

func _find_target() -> Node3D:
	# 优先使用 faction 系统查找敌对目标
	var candidates: Array = []
	if _entity is GameEntity:
		candidates = EngineAPI.find_hostiles_in_area(_entity, _entity.global_position, 99.0)
	elif target_tag != "":
		candidates = EngineAPI.find_entities_by_tag(target_tag)
	if candidates.is_empty():
		return null
	# 找最近的
	var closest: Node3D = null
	var closest_dist := INF
	for c in candidates:
		if not is_instance_valid(c):
			continue
		var d := _entity.global_position.distance_squared_to(c.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = c
	return closest
