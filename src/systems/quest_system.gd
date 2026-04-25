## QuestSystem — 任务系统（对标 TrinityCore Quest / QuestObjective）
## 数据驱动的多目标任务：击杀/收集/到达/交互/自定义
## 支持链式任务、条件前置、奖励实际发放、选择奖励、Daily/Weekly 重置
## 框架层系统，零游戏知识
class_name QuestSystem
extends Node

# === 任务状态 ===
enum QuestState {
	UNAVAILABLE = 0,  # 条件不满足
	AVAILABLE = 1,    # 可接取
	IN_PROGRESS = 2,  # 进行中
	COMPLETE = 3,     # 目标全完成，待交付
	TURNED_IN = 4,    # 已交付
	FAILED = 5,       # 失败
}

# === 任务标志（对标 TC QuestFlags）===
const FLAG_DAILY     := "daily"      # 每日重置
const FLAG_WEEKLY    := "weekly"     # 每周重置
const FLAG_SHARABLE  := "sharable"   # 可队伍共享

# === 目标类型 ===
const OBJ_KILL       := "kill"       # 击杀指定实体
const OBJ_COLLECT    := "collect"    # 收集物品
const OBJ_REACH      := "reach"      # 到达区域
const OBJ_INTERACT   := "interact"   # 与实体交互
const OBJ_CUSTOM     := "custom"     # 自定义（GamePack 通过事件推进）

# === 数据存储 ===
# 任务定义: quest_id -> QuestDef (Dictionary, JSON 驱动)
var _quest_defs: Dictionary = {}
# 玩家任务状态: player_id -> { quest_id -> QuestProgress }
var _quest_progress: Dictionary = {}

func _ready() -> void:
	EngineAPI.register_system("quest", self)
	EventBus.connect_event("entity_killed", _on_entity_killed)

func _reset() -> void:
	_quest_progress.clear()

# === 任务定义 API ===

func register_quest(quest_def: Dictionary) -> void:
	## 注册任务定义（通常在 GamePack 加载时）
	## quest_def: {
	##   "id": String,
	##   "name_key": String,
	##   "description_key": String,
	##   "objectives": [{ "type": "kill", "target": "goblin", "count": 5, "description_key": "..." }, ...],
	##   "rewards": { "gold": 100, "xp": 50, "items": ["item_id"], "reputation": {"faction": "undead", "amount": 500} },
	##   "prerequisites": ["quest_id_1"],    # 前置任务
	##   "required_level": 0,
	##   "next_quest": "quest_id_2",         # 后续链式任务
	##   "time_limit": 0.0,                  # 限时（0=无限）
	##   "repeatable": false,
	## }
	var qid: String = quest_def.get("id", "")
	if qid != "":
		_quest_defs[qid] = quest_def

func load_quests_from_directory(dir_path: String) -> int:
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
				if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
					register_quest(json.data)
					count += 1
		file_name = dir.get_next()
	if count > 0:
		print("[QuestSystem] Loaded %d quests" % count)
	return count

func get_quest_def(quest_id: String) -> Dictionary:
	return _quest_defs.get(quest_id, {})

# === 任务接取/完成 API ===

func accept_quest(player_id: String, quest_id: String) -> bool:
	## 接取任务
	var def: Dictionary = _quest_defs.get(quest_id, {})
	if def.is_empty():
		return false
	if not can_accept(player_id, quest_id):
		return false
	_ensure_player(player_id)
	var objectives: Array = def.get("objectives", [])
	var obj_progress: Array = []
	for obj in objectives:
		obj_progress.append({
			"type": obj.get("type", OBJ_CUSTOM),
			"target": obj.get("target", ""),
			"required": obj.get("count", 1),
			"current": 0,
			"completed": false,
		})
	_quest_progress[player_id][quest_id] = {
		"state": QuestState.IN_PROGRESS,
		"objectives": obj_progress,
		"accepted_at": Time.get_ticks_msec() / 1000.0,
		"elapsed": 0.0,
	}
	EventBus.emit_event("quest_accepted", {
		"player_id": player_id, "quest_id": quest_id,
	})
	return true

func turn_in_quest(player_id: String, quest_id: String, reward_choice: int = -1) -> bool:
	## 交付任务（reward_choice: 选择奖励索引，-1=不选/无选择奖励）
	var progress: Dictionary = _get_progress(player_id, quest_id)
	if progress.is_empty() or progress["state"] != QuestState.COMPLETE:
		return false
	progress["state"] = QuestState.TURNED_IN
	progress["turned_in_at"] = Time.get_ticks_msec() / 1000.0
	var def: Dictionary = _quest_defs.get(quest_id, {})
	var rewards: Dictionary = def.get("rewards", {})
	# === 实际发放固定奖励 ===
	_grant_rewards(player_id, rewards)
	# === 发放选择奖励 ===
	var choice_rewards: Array = def.get("choice_rewards", [])
	if reward_choice >= 0 and reward_choice < choice_rewards.size():
		_grant_rewards(player_id, choice_rewards[reward_choice])
	EventBus.emit_event("quest_turned_in", {
		"player_id": player_id, "quest_id": quest_id,
		"rewards": rewards, "reward_choice": reward_choice,
	})
	# 链式：自动解锁下一个任务
	var next: String = def.get("next_quest", "")
	if next != "":
		EventBus.emit_event("quest_available", {
			"player_id": player_id, "quest_id": next,
		})
	return true

func abandon_quest(player_id: String, quest_id: String) -> void:
	var progress: Dictionary = _get_progress(player_id, quest_id)
	if progress.is_empty():
		return
	progress["state"] = QuestState.FAILED
	EventBus.emit_event("quest_abandoned", {
		"player_id": player_id, "quest_id": quest_id,
	})

func fail_quest(player_id: String, quest_id: String) -> void:
	var progress: Dictionary = _get_progress(player_id, quest_id)
	if progress.is_empty() or progress["state"] != QuestState.IN_PROGRESS:
		return
	progress["state"] = QuestState.FAILED
	EventBus.emit_event("quest_failed", {
		"player_id": player_id, "quest_id": quest_id,
	})

# === 目标推进 API ===

func advance_objective(player_id: String, quest_id: String, obj_index: int, amount: int = 1) -> void:
	## 手动推进指定目标（用于 CUSTOM / INTERACT / REACH 类型）
	var progress: Dictionary = _get_progress(player_id, quest_id)
	if progress.is_empty() or progress["state"] != QuestState.IN_PROGRESS:
		return
	var objectives: Array = progress["objectives"]
	if obj_index < 0 or obj_index >= objectives.size():
		return
	var obj: Dictionary = objectives[obj_index]
	if obj["completed"]:
		return
	obj["current"] = mini(obj["current"] + amount, obj["required"])
	if obj["current"] >= obj["required"]:
		obj["completed"] = true
	EventBus.emit_event("quest_objective_updated", {
		"player_id": player_id, "quest_id": quest_id,
		"objective_index": obj_index,
		"current": obj["current"], "required": obj["required"],
	})
	_check_quest_complete(player_id, quest_id)

func advance_by_event(player_id: String, obj_type: String, target_id: String, amount: int = 1) -> void:
	## 按类型+目标推进所有匹配的活跃任务目标
	_ensure_player(player_id)
	for qid in _quest_progress[player_id]:
		var progress: Dictionary = _quest_progress[player_id][qid]
		if progress["state"] != QuestState.IN_PROGRESS:
			continue
		var objectives: Array = progress["objectives"]
		for i in range(objectives.size()):
			var obj: Dictionary = objectives[i]
			if obj["completed"]:
				continue
			if obj["type"] == obj_type and obj["target"] == target_id:
				obj["current"] = mini(obj["current"] + amount, obj["required"])
				if obj["current"] >= obj["required"]:
					obj["completed"] = true
				EventBus.emit_event("quest_objective_updated", {
					"player_id": player_id, "quest_id": qid,
					"objective_index": i,
					"current": obj["current"], "required": obj["required"],
				})
		_check_quest_complete(player_id, qid)

# === 查询 API ===

func can_accept(player_id: String, quest_id: String) -> bool:
	var def: Dictionary = _quest_defs.get(quest_id, {})
	if def.is_empty():
		return false
	# 已接/已完成检查
	var progress: Dictionary = _get_progress(player_id, quest_id)
	if not progress.is_empty():
		if progress["state"] == QuestState.TURNED_IN and not def.get("repeatable", false):
			return false
		if progress["state"] == QuestState.IN_PROGRESS:
			return false
	# 前置任务检查
	var prereqs: Array = def.get("prerequisites", [])
	for prereq_id in prereqs:
		var prereq: Dictionary = _get_progress(player_id, prereq_id)
		if prereq.is_empty() or prereq["state"] != QuestState.TURNED_IN:
			return false
	return true

func get_quest_state(player_id: String, quest_id: String) -> int:
	var progress: Dictionary = _get_progress(player_id, quest_id)
	if progress.is_empty():
		return QuestState.UNAVAILABLE
	return progress["state"]

func get_quest_progress(player_id: String, quest_id: String) -> Dictionary:
	return _get_progress(player_id, quest_id)

func get_active_quests(player_id: String) -> Array[String]:
	var result: Array[String] = []
	_ensure_player(player_id)
	for qid in _quest_progress[player_id]:
		if _quest_progress[player_id][qid]["state"] == QuestState.IN_PROGRESS:
			result.append(qid)
	return result

func get_completed_quests(player_id: String) -> Array[String]:
	var result: Array[String] = []
	_ensure_player(player_id)
	for qid in _quest_progress[player_id]:
		var state: int = _quest_progress[player_id][qid]["state"]
		if state == QuestState.COMPLETE or state == QuestState.TURNED_IN:
			result.append(qid)
	return result

# === 内部 ===

func _ensure_player(player_id: String) -> void:
	if not _quest_progress.has(player_id):
		_quest_progress[player_id] = {}

func _get_progress(player_id: String, quest_id: String) -> Dictionary:
	if not _quest_progress.has(player_id):
		return {}
	return _quest_progress[player_id].get(quest_id, {})

func _check_quest_complete(player_id: String, quest_id: String) -> void:
	var progress: Dictionary = _get_progress(player_id, quest_id)
	if progress.is_empty() or progress["state"] != QuestState.IN_PROGRESS:
		return
	var all_done := true
	for obj in progress["objectives"]:
		if not obj["completed"]:
			all_done = false
			break
	if all_done:
		progress["state"] = QuestState.COMPLETE
		EventBus.emit_event("quest_complete", {
			"player_id": player_id, "quest_id": quest_id,
		})

func _on_entity_killed(data: Dictionary) -> void:
	## 自动推进 kill 类型目标
	var entity = data.get("entity")
	if entity == null or not (entity is GameEntity):
		return
	var def_id: String = (entity as GameEntity).def_id
	for player_id in _quest_progress:
		advance_by_event(player_id, OBJ_KILL, def_id, 1)

# === 奖励发放（实际执行）===

func _grant_rewards(player_id: String, rewards: Dictionary) -> void:
	## 真正发放奖励到游戏系统
	# 金币/货币
	var gold: int = rewards.get("gold", 0)
	if gold > 0:
		EngineAPI.add_resource("gold", gold)
	for currency_key in rewards.get("currencies", {}):
		EngineAPI.add_resource(currency_key, rewards["currencies"][currency_key])
	# 经验
	var xp: int = rewards.get("xp", 0)
	if xp > 0:
		EngineAPI.add_resource("xp", xp)
	# 物品
	var item_sys: Node = EngineAPI.get_system("item")
	if item_sys:
		for item_id in rewards.get("items", []):
			var item: Dictionary = item_sys.call("create_item_instance", item_id)
			if not item.is_empty():
				# 尝试加入英雄背包
				var heroes: Array = EngineAPI.find_entities_by_tag("hero")
				if heroes.size() > 0 and is_instance_valid(heroes[0]):
					item_sys.call("inventory_add", heroes[0], item)
	# 声望
	var rep: Dictionary = rewards.get("reputation", {})
	if not rep.is_empty():
		var faction_sys: Node = EngineAPI.get_system("faction")
		if faction_sys:
			faction_sys.call("add_reputation", player_id,
				rep.get("faction", ""), rep.get("amount", 0))

# === Daily/Weekly 重置 ===

func reset_daily_quests() -> void:
	## 重置所有 daily 任务（框架每日调用或 GamePack 手动调用）
	_reset_quests_by_flag(FLAG_DAILY)

func reset_weekly_quests() -> void:
	## 重置所有 weekly 任务
	_reset_quests_by_flag(FLAG_WEEKLY)

func _reset_quests_by_flag(flag: String) -> void:
	for player_id in _quest_progress:
		var to_reset: Array = []
		for qid in _quest_progress[player_id]:
			var progress: Dictionary = _quest_progress[player_id][qid]
			if progress["state"] != QuestState.TURNED_IN:
				continue
			var def: Dictionary = _quest_defs.get(qid, {})
			var flags: Array = def.get("flags", [])
			if flag in flags:
				to_reset.append(qid)
		for qid in to_reset:
			_quest_progress[player_id].erase(qid)
			EventBus.emit_event("quest_reset", {
				"player_id": player_id, "quest_id": qid, "flag": flag,
			})

# === 组队共享（对标 TC QUEST_FLAGS_SHARABLE）===

func share_quest_progress(source_player: String, target_player: String, quest_id: String) -> bool:
	## 队友共享任务进度（kill 类型）
	var def: Dictionary = _quest_defs.get(quest_id, {})
	if not FLAG_SHARABLE in def.get("flags", []):
		return false
	# 目标玩家也在做同一任务
	var target_progress: Dictionary = _get_progress(target_player, quest_id)
	if target_progress.is_empty() or target_progress["state"] != QuestState.IN_PROGRESS:
		return false
	# 对 kill 类目标，同步源玩家的击杀
	var source_progress: Dictionary = _get_progress(source_player, quest_id)
	if source_progress.is_empty():
		return false
	var objectives: Array = target_progress["objectives"]
	var src_objectives: Array = source_progress["objectives"]
	for i in range(mini(objectives.size(), src_objectives.size())):
		if objectives[i]["type"] == OBJ_KILL and not objectives[i]["completed"]:
			if src_objectives[i]["current"] > objectives[i]["current"]:
				objectives[i]["current"] = src_objectives[i]["current"]
				if objectives[i]["current"] >= objectives[i]["required"]:
					objectives[i]["completed"] = true
	_check_quest_complete(target_player, quest_id)
	return true
