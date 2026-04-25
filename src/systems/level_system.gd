## LevelSystem — 等级/经验/属性成长系统（对标 TrinityCore Unit::GiveXP / LevelUp）
## 管理实体的等级、经验值、升级曲线、per-level 属性成长
## 支持技能点分配、等级上限、经验倍率、升级事件
## 框架层系统，零游戏知识。升级曲线和属性成长由 JSON 数据驱动
class_name LevelSystem
extends Node

# === 数据存储 ===
# entity_instance_id -> LevelData
var _level_data: Dictionary = {}

# 升级曲线模板: curve_id -> { "xp_per_level": [0, 100, 250, 500, ...], "max_level": int }
var _level_curves: Dictionary = {}

# 属性成长模板: growth_id -> { "stat_name": { "base": float, "per_level": float, "formula": String } }
var _stat_growths: Dictionary = {}

# 全局经验倍率
var xp_multiplier: float = 1.0

func _ready() -> void:
	EngineAPI.register_system("level", self)
	EventBus.connect_event("entity_killed", _on_entity_killed)
	# 注册默认线性曲线
	register_curve("linear", _generate_linear_curve(50, 100, 1.15))

func _reset() -> void:
	_level_data.clear()

# === 曲线注册 API ===

func register_curve(curve_id: String, curve_data: Dictionary) -> void:
	## curve_data: { "xp_per_level": [0, 100, 230, 400, ...], "max_level": int }
	## xp_per_level[n] = 从 level n 升到 level n+1 需要的经验
	_level_curves[curve_id] = curve_data

func register_stat_growth(growth_id: String, growth_data: Dictionary) -> void:
	## growth_data: { "max_hp": { "base": 100, "per_level": 20 },
	##                "damage": { "base": 10, "per_level": 3 }, ... }
	_stat_growths[growth_id] = growth_data

func load_curves_from_directory(dir_path: String) -> int:
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
					var data: Dictionary = json.data
					var cid: String = data.get("id", file_name.get_basename())
					if data.has("xp_per_level"):
						register_curve(cid, data)
						count += 1
					elif data.has("stats"):
						register_stat_growth(cid, data["stats"])
						count += 1
		file_name = dir.get_next()
	return count

# === 实体等级 API ===

func init_level(entity: GameEntity, params: Dictionary = {}) -> void:
	## 初始化实体等级数据
	## params: { "level": 1, "xp": 0, "curve": "linear", "growth": "warrior",
	##           "skill_points": 0, "skill_points_per_level": 1 }
	if not is_instance_valid(entity):
		return
	var eid: int = entity.get_instance_id()
	_level_data[eid] = {
		"entity": entity,
		"level": params.get("level", 1),
		"xp": params.get("xp", 0),
		"curve_id": params.get("curve", "linear"),
		"growth_id": params.get("growth", ""),
		"skill_points": params.get("skill_points", 0),
		"sp_per_level": params.get("skill_points_per_level", 1),
	}
	# 应用当前等级的属性
	_apply_level_stats(eid)

func add_xp(entity: GameEntity, amount: int) -> void:
	## 给予经验值（自动检查升级）
	if not is_instance_valid(entity):
		return
	var eid: int = entity.get_instance_id()
	if not _level_data.has(eid):
		return
	var data: Dictionary = _level_data[eid]
	var actual: int = int(amount * xp_multiplier)
	data["xp"] += actual
	EventBus.emit_event("xp_gained", {
		"entity": entity, "amount": actual, "total_xp": data["xp"],
	})
	# 检查连续升级
	while _can_level_up(eid):
		_do_level_up(eid)

func set_level(entity: GameEntity, new_level: int) -> void:
	## 直接设置等级（跳过经验）
	if not is_instance_valid(entity):
		return
	var eid: int = entity.get_instance_id()
	if not _level_data.has(eid):
		return
	var data: Dictionary = _level_data[eid]
	var old_level: int = data["level"]
	var max_level: int = _get_max_level(eid)
	data["level"] = clampi(new_level, 1, max_level)
	data["xp"] = 0
	# 给予跳过的技能点
	var levels_gained: int = data["level"] - old_level
	if levels_gained > 0:
		data["skill_points"] += levels_gained * data["sp_per_level"]
	_apply_level_stats(eid)
	EventBus.emit_event("level_changed", {
		"entity": entity, "old_level": old_level, "new_level": data["level"],
	})

func get_level(entity: GameEntity) -> int:
	if not is_instance_valid(entity):
		return 1
	return _level_data.get(entity.get_instance_id(), {}).get("level", 1)

func get_xp(entity: GameEntity) -> int:
	if not is_instance_valid(entity):
		return 0
	return _level_data.get(entity.get_instance_id(), {}).get("xp", 0)

func get_xp_to_next(entity: GameEntity) -> int:
	## 升到下一级需要多少经验
	if not is_instance_valid(entity):
		return 0
	var eid: int = entity.get_instance_id()
	return _get_xp_required(eid, _level_data.get(eid, {}).get("level", 1))

func get_xp_progress(entity: GameEntity) -> float:
	## 当前等级内的经验进度（0.0 ~ 1.0）
	var xp: int = get_xp(entity)
	var required: int = get_xp_to_next(entity)
	if required <= 0:
		return 1.0
	return clampf(float(xp) / float(required), 0.0, 1.0)

func get_skill_points(entity: GameEntity) -> int:
	if not is_instance_valid(entity):
		return 0
	return _level_data.get(entity.get_instance_id(), {}).get("skill_points", 0)

func spend_skill_point(entity: GameEntity, stat_name: String, amount: float = 1.0) -> bool:
	## 花费技能点提升属性
	if not is_instance_valid(entity):
		return false
	var eid: int = entity.get_instance_id()
	if not _level_data.has(eid):
		return false
	var data: Dictionary = _level_data[eid]
	if data["skill_points"] <= 0:
		return false
	data["skill_points"] -= 1
	# 通过绿字属性添加永久加成（技能点加成 = 装备/卡片级别的 bonus）
	EngineAPI.add_green_stat(entity, stat_name, amount)
	EventBus.emit_event("skill_point_spent", {
		"entity": entity, "stat": stat_name, "amount": amount,
		"remaining": data["skill_points"],
	})
	return true

func get_level_data(entity: GameEntity) -> Dictionary:
	## 查询完整等级信息（UI/调试用）
	if not is_instance_valid(entity):
		return {}
	var eid: int = entity.get_instance_id()
	var data: Dictionary = _level_data.get(eid, {})
	if data.is_empty():
		return {}
	return {
		"level": data["level"],
		"xp": data["xp"],
		"xp_to_next": _get_xp_required(eid, data["level"]),
		"max_level": _get_max_level(eid),
		"skill_points": data["skill_points"],
	}

# === 内部 ===

func _can_level_up(eid: int) -> bool:
	var data: Dictionary = _level_data.get(eid, {})
	if data.is_empty():
		return false
	if data["level"] >= _get_max_level(eid):
		return false
	var required: int = _get_xp_required(eid, data["level"])
	return data["xp"] >= required

func _do_level_up(eid: int) -> void:
	var data: Dictionary = _level_data[eid]
	var required: int = _get_xp_required(eid, data["level"])
	data["xp"] -= required
	data["level"] += 1
	data["skill_points"] += data["sp_per_level"]
	_apply_level_stats(eid)
	var entity = data.get("entity")
	EventBus.emit_event("level_up", {
		"entity": entity,
		"new_level": data["level"],
		"skill_points": data["skill_points"],
	})

func _apply_level_stats(eid: int) -> void:
	## 根据等级 + 成长模板计算属性，通过 StatSystem 应用
	var data: Dictionary = _level_data.get(eid, {})
	var growth_id: String = data.get("growth_id", "")
	if growth_id == "" or not _stat_growths.has(growth_id):
		return
	var entity = data.get("entity")
	if not is_instance_valid(entity):
		return
	var _level: int = data["level"]
	var growth: Dictionary = _stat_growths[growth_id]
	var stat_sys: Node = EngineAPI.get_system("stat")
	if stat_sys == null:
		return
	# 使用白字属性系统：set_white_base + set_white_growth，由 StatSystem 按等级自动计算
	for stat_name in growth:
		var sg: Dictionary = growth[stat_name]
		var base_val: float = sg.get("base", 0.0)
		var per_level: float = sg.get("per_level", 0.0)
		stat_sys.call("set_white_base", entity, stat_name, base_val)
		stat_sys.call("set_white_growth", entity, stat_name, per_level)

func _get_xp_required(eid: int, level: int) -> int:
	var data: Dictionary = _level_data.get(eid, {})
	var curve_id: String = data.get("curve_id", "linear")
	var curve: Dictionary = _level_curves.get(curve_id, {})
	var xp_table: Array = curve.get("xp_per_level", [])
	if level < xp_table.size():
		return int(xp_table[level])
	# 超出表范围：用最后一个值 × 1.15 递增
	if xp_table.size() > 0:
		var last: float = float(xp_table[xp_table.size() - 1])
		var extra: int = level - xp_table.size() + 1
		return int(last * pow(1.15, extra))
	return 100 * level  # 无曲线回退

func _get_max_level(eid: int) -> int:
	var data: Dictionary = _level_data.get(eid, {})
	var curve_id: String = data.get("curve_id", "linear")
	var curve: Dictionary = _level_curves.get(curve_id, {})
	return curve.get("max_level", 99)

func _generate_linear_curve(base_xp: int, increment: int, multiplier: float, max_level: int = 50) -> Dictionary:
	## 生成默认升级曲线
	var table: Array = [0]  # level 0 → 1 不需要经验
	var current: float = base_xp
	for _i in range(max_level):
		table.append(int(current))
		current = current * multiplier + increment
	return {"xp_per_level": table, "max_level": max_level}

func _on_entity_killed(data: Dictionary) -> void:
	## 击杀奖励经验（对标 TC GiveXP + 等级差异缩放）
	var entity = data.get("entity")
	var killer = data.get("killer")
	if entity == null or not (entity is GameEntity):
		return
	if killer == null or not (killer is GameEntity):
		return
	var victim: GameEntity = entity as GameEntity
	var attacker: GameEntity = killer as GameEntity
	var base_xp: int = victim.get_meta_value("xp_reward", 0)
	if base_xp <= 0:
		return
	# 精英倍率（对标 TC CreatureTypeFlags）
	var elite_mult: float = victim.get_meta_value("elite_multiplier", 1.0)
	# 等级差异缩放（对标 TC ZeroDifference / GrayLevel）
	var killer_level: int = get_level(attacker)
	var victim_level: int = victim.get_meta_value("level", killer_level)
	var scaled_xp: int = int(base_xp * elite_mult * _calc_level_diff_multiplier(killer_level, victim_level))
	if scaled_xp > 0:
		add_xp(attacker, scaled_xp)

func _calc_level_diff_multiplier(player_level: int, mob_level: int) -> float:
	## 等级差异经验缩放（对标 TC GrayLevel + ZeroDifference）
	## 高等级怪: 每高1级 +5%（最高 +20%）
	## 同级怪: 100%
	## 低等级怪: 线性衰减直到灰色线（0%）
	var diff: int = mob_level - player_level
	if diff >= 0:
		# 怪物等级 >= 玩家：加成 5%/级，封顶 +20%
		return minf(1.0 + diff * 0.05, 1.2)
	# 怪物等级 < 玩家：计算灰色线
	var gray_level: int = _get_gray_level(player_level)
	if mob_level <= gray_level:
		return 0.0  # 灰色怪 = 0 经验
	# 灰色线到同级之间线性衰减
	var window: int = player_level - gray_level
	if window <= 0:
		return 1.0
	return float(mob_level - gray_level) / float(window)

static func _get_gray_level(player_level: int) -> int:
	## 灰色等级线（对标 TC GetGrayLevel）
	if player_level <= 5: return 0
	if player_level <= 39: return player_level - 5 - int(player_level / 10.0)
	if player_level <= 59: return player_level - 1 - int(player_level / 5.0)
	return player_level - 9
