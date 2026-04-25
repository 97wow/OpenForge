## SeasonSystem - 赛季战令系统（框架层 Autoload）
## 管理赛季周期、战令等级、任务进度、奖励领取
## 通过 SaveSystem 持久化所有赛季数据
extends Node

const SAVE_NS := "season"
const CONFIG_PATH := "res://gamepacks/rogue_survivor/season_config.json"

# === 赛季配置（从 JSON 加载） ===
var _config: Dictionary = {}

# === 运行时状态 ===
var season_id: String = ""
var season_name: String = ""
var season_start: int = 0       # Unix 时间戳
var season_end: int = 0
var xp: int = 0                 # 当前经验
var level: int = 0              # 当前等级（0-based，显示 +1）
var is_premium: bool = false    # 是否已购买付费轨道

# 任务相关
var daily_quests: Array = []    # 当日随机的每日任务
var weekly_quests: Array = []   # 本周随机的每周任务
var quest_progress: Dictionary = {}  # quest_id -> 当前进度值
var claimed_quest_ids: Array = []    # 已领取奖励的任务ID

# 奖励相关
var claimed_free_rewards: Array = []     # 已领取的免费轨道等级
var claimed_premium_rewards: Array = []  # 已领取的付费轨道等级

# 配置缓存
var max_level: int = 30
var xp_per_level: int = 100
var daily_quest_pool: Array = []
var weekly_quest_pool: Array = []
var free_rewards: Array = []
var premium_rewards: Array = []

# === 生命周期 ===

func _ready() -> void:
	_load_config()
	_load_save()
	_check_season_cycle()

# === 配置加载 ===

func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("[SeasonSystem] 赛季配置文件不存在: %s" % CONFIG_PATH)
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("[SeasonSystem] 赛季配置 JSON 解析失败")
		return
	_config = json.data
	_apply_config()

func _apply_config() -> void:
	season_id = _config.get("season_id", "")
	season_name = _config.get("season_name", "")
	season_start = _config.get("season_start", 0)
	season_end = _config.get("season_end", 0)
	max_level = _config.get("max_level", 30)
	xp_per_level = _config.get("xp_per_level", 100)
	daily_quest_pool = _config.get("daily_quest_pool", [])
	weekly_quest_pool = _config.get("weekly_quest_pool", [])
	free_rewards = _config.get("free_rewards", [])
	premium_rewards = _config.get("premium_rewards", [])

# === 存档读写 ===

func _load_save() -> void:
	var save: Node = get_node_or_null("/root/SaveSystem")
	if save == null:
		return
	var saved_season: String = save.load_data(SAVE_NS, "season_id", "")
	# 赛季ID不匹配 → 重置进度（新赛季开始）
	if saved_season != season_id:
		_reset_progress()
		return
	xp = save.load_data(SAVE_NS, "xp", 0)
	level = save.load_data(SAVE_NS, "level", 0)
	is_premium = save.load_data(SAVE_NS, "is_premium", false)
	daily_quests = save.load_data(SAVE_NS, "daily_quests", [])
	weekly_quests = save.load_data(SAVE_NS, "weekly_quests", [])
	quest_progress = save.load_data(SAVE_NS, "quest_progress", {})
	claimed_quest_ids = save.load_data(SAVE_NS, "claimed_quest_ids", [])
	claimed_free_rewards = save.load_data(SAVE_NS, "claimed_free_rewards", [])
	claimed_premium_rewards = save.load_data(SAVE_NS, "claimed_premium_rewards", [])

	# 检查每日任务是否需要刷新（跨天）
	var last_daily_ts: int = save.load_data(SAVE_NS, "last_daily_refresh", 0)
	if _is_new_day(last_daily_ts):
		_refresh_daily_quests()

	var last_weekly_ts: int = save.load_data(SAVE_NS, "last_weekly_refresh", 0)
	if _is_new_week(last_weekly_ts):
		_refresh_weekly_quests()

func _save_all() -> void:
	var save: Node = get_node_or_null("/root/SaveSystem")
	if save == null:
		return
	save.save_data(SAVE_NS, "season_id", season_id)
	save.save_data(SAVE_NS, "xp", xp)
	save.save_data(SAVE_NS, "level", level)
	save.save_data(SAVE_NS, "is_premium", is_premium)
	save.save_data(SAVE_NS, "daily_quests", daily_quests)
	save.save_data(SAVE_NS, "weekly_quests", weekly_quests)
	save.save_data(SAVE_NS, "quest_progress", quest_progress)
	save.save_data(SAVE_NS, "claimed_quest_ids", claimed_quest_ids)
	save.save_data(SAVE_NS, "claimed_free_rewards", claimed_free_rewards)
	save.save_data(SAVE_NS, "claimed_premium_rewards", claimed_premium_rewards)

# === 赛季周期 ===

func _check_season_cycle() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	if season_end > 0 and now >= season_end:
		_settle_season()

func _settle_season() -> void:
	# 赛季结算：发放未领取的自动奖励等
	EventBus.emit_event("season_ended", {
		"season_id": season_id,
		"final_level": level,
		"final_xp": xp,
	})
	_reset_progress()

func _reset_progress() -> void:
	xp = 0
	level = 0
	is_premium = false
	daily_quests = []
	weekly_quests = []
	quest_progress = {}
	claimed_quest_ids = []
	claimed_free_rewards = []
	claimed_premium_rewards = []
	_refresh_daily_quests()
	_refresh_weekly_quests()
	_save_all()

# === 经验与等级 ===

## 增加经验，自动升级
func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	var old_level: int = level
	while xp >= xp_per_level and level < max_level:
		xp -= xp_per_level
		level += 1
	# 满级后多余经验归零
	if level >= max_level:
		level = max_level
		xp = 0
	if level != old_level:
		EventBus.emit_event("season_level_up", {
			"old_level": old_level,
			"new_level": level,
		})
	_save_all()

## 获取显示等级（1-based）
func get_display_level() -> int:
	return level + 1

## 获取当前等级经验进度百分比 (0.0 ~ 1.0)
func get_xp_progress() -> float:
	if level >= max_level:
		return 1.0
	if xp_per_level <= 0:
		return 0.0
	return float(xp) / float(xp_per_level)

# === 任务系统 ===

func _refresh_daily_quests() -> void:
	daily_quests = _pick_random_quests(daily_quest_pool, 3)
	# 重置对应的进度
	for q in daily_quests:
		var qid: String = q.get("id", "")
		quest_progress[qid] = 0
	var save: Node = get_node_or_null("/root/SaveSystem")
	if save:
		save.save_data(SAVE_NS, "last_daily_refresh", int(Time.get_unix_time_from_system()))
	_save_all()

func _refresh_weekly_quests() -> void:
	weekly_quests = _pick_random_quests(weekly_quest_pool, 3)
	for q in weekly_quests:
		var qid: String = q.get("id", "")
		quest_progress[qid] = 0
	var save: Node = get_node_or_null("/root/SaveSystem")
	if save:
		save.save_data(SAVE_NS, "last_weekly_refresh", int(Time.get_unix_time_from_system()))
	_save_all()

func _pick_random_quests(pool: Array, count: int) -> Array:
	if pool.size() <= count:
		return pool.duplicate()
	var shuffled: Array = pool.duplicate()
	shuffled.shuffle()
	return shuffled.slice(0, count)

## 推进任务进度（由游戏逻辑调用）
## event_type: 对应任务的 trigger 字段（如 "enemy_killed", "game_completed" 等）
## amount: 推进数值
func advance_quest(event_type: String, amount: int = 1) -> void:
	var changed := false
	for q in daily_quests + weekly_quests:
		var qid: String = q.get("id", "")
		var trigger: String = q.get("trigger", "")
		if trigger != event_type:
			continue
		if claimed_quest_ids.has(qid):
			continue
		var target: int = q.get("target", 1)
		var current: int = quest_progress.get(qid, 0)
		if current >= target:
			continue
		quest_progress[qid] = mini(current + amount, target)
		changed = true
	if changed:
		_save_all()

## 检查任务是否已完成
func is_quest_complete(quest_id: String) -> bool:
	for q in daily_quests + weekly_quests:
		if q.get("id", "") == quest_id:
			var target: int = q.get("target", 1)
			var current: int = quest_progress.get(quest_id, 0)
			return current >= target
	return false

## 领取任务奖励
func claim_quest_reward(quest_id: String) -> bool:
	if claimed_quest_ids.has(quest_id):
		return false
	if not is_quest_complete(quest_id):
		return false
	# 找到任务获取经验
	for q in daily_quests + weekly_quests:
		if q.get("id", "") == quest_id:
			var xp_reward: int = q.get("xp_reward", 0)
			claimed_quest_ids.append(quest_id)
			add_xp(xp_reward)
			EventBus.emit_event("quest_reward_claimed", {
				"quest_id": quest_id,
				"xp": xp_reward,
			})
			return true
	return false

# === 奖励轨道 ===

## 领取免费轨道奖励
func claim_free_reward(reward_level: int) -> bool:
	if reward_level > level:
		return false
	if claimed_free_rewards.has(reward_level):
		return false
	# 检查该等级是否有免费奖励
	var reward: Dictionary = _find_reward(free_rewards, reward_level)
	if reward.is_empty():
		return false
	claimed_free_rewards.append(reward_level)
	_grant_reward(reward)
	_save_all()
	return true

## 领取付费轨道奖励
func claim_premium_reward(reward_level: int) -> bool:
	if not is_premium:
		return false
	if reward_level > level:
		return false
	if claimed_premium_rewards.has(reward_level):
		return false
	var reward: Dictionary = _find_reward(premium_rewards, reward_level)
	if reward.is_empty():
		return false
	claimed_premium_rewards.append(reward_level)
	_grant_reward(reward)
	_save_all()
	return true

## 购买付费战令
func purchase_premium() -> void:
	is_premium = true
	_save_all()
	EventBus.emit_event("season_premium_purchased", {"season_id": season_id})

func _find_reward(rewards: Array, target_level: int) -> Dictionary:
	for r in rewards:
		if r.get("level", -1) == target_level:
			return r
	return {}

func _grant_reward(reward: Dictionary) -> void:
	# 通过事件通知，由 GamePack 层处理具体的奖励发放
	EventBus.emit_event("season_reward_granted", reward)

# === 时间工具 ===

func _is_new_day(last_ts: int) -> bool:
	if last_ts <= 0:
		return true
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var last: Dictionary = Time.get_datetime_dict_from_unix_time(last_ts)
	return now.get("day", 0) != last.get("day", -1) or \
		now.get("month", 0) != last.get("month", -1) or \
		now.get("year", 0) != last.get("year", -1)

func _is_new_week(last_ts: int) -> bool:
	if last_ts <= 0:
		return true
	var now_unix: int = int(Time.get_unix_time_from_system())
	# 简单计算：超过7天则视为新周
	return (now_unix - last_ts) >= 604800

# === 查询接口 ===

## 赛季剩余秒数
func get_remaining_seconds() -> int:
	var now: int = int(Time.get_unix_time_from_system())
	return maxi(season_end - now, 0)

## 赛季剩余天数
func get_remaining_days() -> int:
	@warning_ignore("integer_division")
	return get_remaining_seconds() / 86400

## 赛季是否激活
func is_season_active() -> bool:
	var now: int = int(Time.get_unix_time_from_system())
	return now >= season_start and now < season_end
