## AchievementSystem — 成就系统（对标 TrinityCore AchievementMgr / CriteriaTree）
## 支持：AND/OR/COUNT 组合逻辑 + 成就前置链 + 奖励实际发放 + 统计
## 数据驱动 JSON，GamePack 定义成就和标准
## 框架层系统，零游戏知识
class_name AchievementSystem
extends Node

# === 成就状态 ===
enum AchievementState {
	LOCKED = 0,      # 未完成
	COMPLETED = 1,   # 已完成
	CLAIMED = 2,     # 已领取奖励
}

# === 标准类型（对标 TC AchievementCriteriaType）===
const CRITERIA_KILL_CREATURE   := "kill_creature"    # 击杀指定实体
const CRITERIA_KILL_COUNT      := "kill_count"        # 总击杀数
const CRITERIA_DEAL_DAMAGE     := "deal_damage"       # 累计伤害
const CRITERIA_TAKE_DAMAGE     := "take_damage"       # 累计承伤
const CRITERIA_CAST_SPELL      := "cast_spell"        # 施放技能次数
const CRITERIA_REACH_LEVEL     := "reach_level"       # 达到等级
const CRITERIA_COMPLETE_QUEST  := "complete_quest"    # 完成任务
const CRITERIA_WIN_ENCOUNTER   := "win_encounter"     # 击杀 Boss
const CRITERIA_CUSTOM          := "custom"            # 自定义

# === 数据存储 ===
# 成就定义: achievement_id -> AchievementDef
var _achievement_defs: Dictionary = {}
# 玩家进度: player_id -> { achievement_id -> { "state": int, "criteria_progress": [int, ...] } }
var _player_progress: Dictionary = {}
# 全局统计计数器: player_id -> { stat_key -> value }
var _stats: Dictionary = {}

func _ready() -> void:
	EngineAPI.register_system("achievement", self)
	EventBus.connect_event("entity_killed", _on_entity_killed)
	EventBus.connect_event("entity_damaged", _on_entity_damaged)
	EventBus.connect_event("spell_cast", _on_spell_cast)
	EventBus.connect_event("quest_turned_in", _on_quest_turned_in)
	EventBus.connect_event("encounter_completed", _on_encounter_completed)

func _reset() -> void:
	_player_progress.clear()
	_stats.clear()

# === 成就定义 API ===

func register_achievement(achievement_def: Dictionary) -> void:
	## achievement_def: {
	##   "id": String,
	##   "name_key": String,
	##   "description_key": String,
	##   "criteria": [{ "type": "kill_creature", "target": "goblin", "count": 10 }, ...],
	##   "criteria_logic": "AND" / "OR" / "COUNT",  # 默认 AND
	##   "criteria_count": 2,                        # COUNT 模式：需满足几个
	##   "prerequisites": ["achievement_id_1"],      # 前置成就
	##   "rewards": { "gold": 100, "items": ["item_id"], "title_key": "TITLE_X" },
	##   "points": 10,
	##   "hidden": false,
	##   "category": "combat",
	## }
	var aid: String = achievement_def.get("id", "")
	if aid != "":
		_achievement_defs[aid] = achievement_def

func load_achievements_from_directory(dir_path: String) -> int:
	var count := 0
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file := FileAccess.open(dir_path.path_join(file_name), FileAccess.READ)
			if file:
				var json := JSON.new()
				if json.parse(file.get_as_text()) == OK:
					if json.data is Dictionary:
						register_achievement(json.data)
						count += 1
					elif json.data is Array:
						for entry in json.data:
							if entry is Dictionary:
								register_achievement(entry)
								count += 1
		file_name = dir.get_next()
	if count > 0:
		print("[AchievementSystem] Loaded %d achievements" % count)
	return count

# === 进度 API ===

func advance_criteria(player_id: String, criteria_type: String, target: String, amount: int = 1) -> void:
	## 推进匹配的成就标准
	_ensure_player(player_id)
	for aid in _achievement_defs:
		var progress: Dictionary = _get_progress(player_id, aid)
		if progress["state"] != AchievementState.LOCKED:
			continue
		var def: Dictionary = _achievement_defs[aid]
		var criteria: Array = def.get("criteria", [])
		var changed := false
		for i in range(criteria.size()):
			var c: Dictionary = criteria[i]
			if c.get("type", "") != criteria_type:
				continue
			if c.get("target", "") != "" and c["target"] != target:
				continue
			var required: int = c.get("count", 1)
			progress["criteria_progress"][i] = mini(
				progress["criteria_progress"][i] + amount, required)
			changed = true
		if changed:
			_check_achievement_complete(player_id, aid)

func increment_stat(player_id: String, stat_key: String, amount: float = 1.0) -> void:
	## 增加全局统计（用于成就条件检查和排行榜）
	_ensure_stats(player_id)
	_stats[player_id][stat_key] = _stats[player_id].get(stat_key, 0.0) + amount

func get_stat(player_id: String, stat_key: String) -> float:
	if not _stats.has(player_id):
		return 0.0
	return _stats[player_id].get(stat_key, 0.0)

func claim_achievement(player_id: String, achievement_id: String) -> bool:
	## 领取成就奖励（实际发放到游戏系统）
	var progress: Dictionary = _get_progress(player_id, achievement_id)
	if progress["state"] != AchievementState.COMPLETED:
		return false
	progress["state"] = AchievementState.CLAIMED
	var def: Dictionary = _achievement_defs.get(achievement_id, {})
	var rewards: Dictionary = def.get("rewards", {})
	# 实际发放奖励
	var gold: int = rewards.get("gold", 0)
	if gold > 0:
		EngineAPI.add_resource("gold", gold)
	var xp: int = rewards.get("xp", 0)
	if xp > 0:
		EngineAPI.add_resource("xp", xp)
	# 物品奖励
	var item_sys: Node = EngineAPI.get_system("item")
	if item_sys:
		for item_id in rewards.get("items", []):
			var item: Dictionary = item_sys.call("create_item_instance", item_id)
			if not item.is_empty():
				var heroes: Array = EngineAPI.find_entities_by_tag("hero")
				if heroes.size() > 0 and is_instance_valid(heroes[0]):
					item_sys.call("inventory_add", heroes[0], item)
	EventBus.emit_event("achievement_claimed", {
		"player_id": player_id,
		"achievement_id": achievement_id,
		"rewards": rewards,
	})
	return true

# === 查询 API ===

func get_achievement_state(player_id: String, achievement_id: String) -> int:
	return _get_progress(player_id, achievement_id)["state"]

func get_achievement_progress(player_id: String, achievement_id: String) -> Dictionary:
	var progress: Dictionary = _get_progress(player_id, achievement_id)
	var def: Dictionary = _achievement_defs.get(achievement_id, {})
	var criteria: Array = def.get("criteria", [])
	var detail: Array = []
	for i in range(criteria.size()):
		detail.append({
			"type": criteria[i].get("type", ""),
			"target": criteria[i].get("target", ""),
			"current": progress["criteria_progress"][i] if i < progress["criteria_progress"].size() else 0,
			"required": criteria[i].get("count", 1),
		})
	return {"state": progress["state"], "criteria": detail}

func get_completed_achievements(player_id: String) -> Array[String]:
	var result: Array[String] = []
	_ensure_player(player_id)
	for aid in _player_progress[player_id]:
		if _player_progress[player_id][aid]["state"] >= AchievementState.COMPLETED:
			result.append(aid)
	return result

func get_total_points(player_id: String) -> int:
	var total := 0
	_ensure_player(player_id)
	for aid in _player_progress[player_id]:
		if _player_progress[player_id][aid]["state"] >= AchievementState.COMPLETED:
			total += _achievement_defs.get(aid, {}).get("points", 0)
	return total

func get_all_achievement_ids() -> Array[String]:
	var result: Array[String] = []
	for key in _achievement_defs:
		result.append(key)
	return result

# === 内部 ===

func _ensure_player(player_id: String) -> void:
	if not _player_progress.has(player_id):
		_player_progress[player_id] = {}
	# 初始化所有成就的进度
	for aid in _achievement_defs:
		if not _player_progress[player_id].has(aid):
			var criteria_count: int = _achievement_defs[aid].get("criteria", []).size()
			var zeros: Array = []
			zeros.resize(criteria_count)
			zeros.fill(0)
			_player_progress[player_id][aid] = {
				"state": AchievementState.LOCKED,
				"criteria_progress": zeros,
			}

func _ensure_stats(player_id: String) -> void:
	if not _stats.has(player_id):
		_stats[player_id] = {}

func _get_progress(player_id: String, achievement_id: String) -> Dictionary:
	_ensure_player(player_id)
	return _player_progress[player_id].get(achievement_id, {"state": AchievementState.LOCKED, "criteria_progress": []})

func _check_achievement_complete(player_id: String, achievement_id: String) -> void:
	var progress: Dictionary = _get_progress(player_id, achievement_id)
	if progress["state"] != AchievementState.LOCKED:
		return
	var def: Dictionary = _achievement_defs.get(achievement_id, {})
	# 前置成就检查（对标 TC RequiredAchievementSatisfied）
	var prereqs: Array = def.get("prerequisites", [])
	for prereq_id in prereqs:
		var prereq: Dictionary = _get_progress(player_id, prereq_id)
		if prereq["state"] < AchievementState.COMPLETED:
			return  # 前置未完成
	# 标准组合逻辑（对标 TC CriteriaTree AND/OR/COUNT）
	var criteria: Array = def.get("criteria", [])
	var logic: String = def.get("criteria_logic", "AND")
	var met_count := 0
	for i in range(criteria.size()):
		var required: int = criteria[i].get("count", 1)
		var current: int = progress["criteria_progress"][i] if i < progress["criteria_progress"].size() else 0
		if current >= required:
			met_count += 1
	var is_complete := false
	match logic:
		"AND":
			is_complete = met_count == criteria.size()
		"OR":
			is_complete = met_count > 0
		"COUNT":
			var need: int = def.get("criteria_count", 1)
			is_complete = met_count >= need
		_:
			is_complete = met_count == criteria.size()
	if is_complete:
		progress["state"] = AchievementState.COMPLETED
		EventBus.emit_event("achievement_completed", {
			"player_id": player_id,
			"achievement_id": achievement_id,
			"points": def.get("points", 0),
		})

# === 事件监听 ===

func _on_entity_killed(data: Dictionary) -> void:
	var entity = data.get("entity")
	var killer = data.get("killer")
	if entity == null or not (entity is GameEntity):
		return
	var def_id: String = (entity as GameEntity).def_id
	# kill_creature
	for pid in _player_progress:
		advance_criteria(pid, CRITERIA_KILL_CREATURE, def_id, 1)
	# kill_count
	if killer is GameEntity:
		for pid in _player_progress:
			increment_stat(pid, "total_kills", 1.0)
			advance_criteria(pid, CRITERIA_KILL_COUNT, "", 1)

func _on_entity_damaged(data: Dictionary) -> void:
	var amount: float = data.get("amount", 0)
	if amount <= 0:
		return
	for pid in _player_progress:
		increment_stat(pid, "total_damage_dealt", amount)

func _on_spell_cast(data: Dictionary) -> void:
	var spell_id: String = str(data.get("spell_id", ""))
	if spell_id == "":
		return
	for pid in _player_progress:
		advance_criteria(pid, CRITERIA_CAST_SPELL, spell_id, 1)

func _on_quest_turned_in(data: Dictionary) -> void:
	var player_id: String = data.get("player_id", "")
	var quest_id: String = data.get("quest_id", "")
	if player_id != "" and quest_id != "":
		advance_criteria(player_id, CRITERIA_COMPLETE_QUEST, quest_id, 1)

func _on_encounter_completed(data: Dictionary) -> void:
	var encounter_id: int = data.get("encounter_id", 0)
	for pid in _player_progress:
		advance_criteria(pid, CRITERIA_WIN_ENCOUNTER, str(encounter_id), 1)
