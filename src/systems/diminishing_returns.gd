## DiminishingReturns — CC 递减系统（对标 TrinityCore SpellMgr DiminishingReturns）
## 同类 CC 连续命中同一目标时效果递减：全效 → 50% → 25% → 免疫
## 支持：PvE/PvP 区分、TAUNT 独立递减曲线、死亡自动重置、强弱比较
## 框架层系统，与 AuraManager 集成
class_name DiminishingReturns
extends Node

# === 递减等级（对标 TC DiminishingLevels）===
enum DRLevel {
	LEVEL_1 = 0,  # 全效
	LEVEL_2 = 1,
	LEVEL_3 = 2,
	LEVEL_4 = 3,  # TAUNT 用第四档
	LEVEL_IMMUNE = 4,
}

# === 递减类型：谁会受到递减（对标 TC DiminishingReturnsType）===
enum DRType {
	DR_ALL = 0,       # 对所有目标生效（Stun/Root 等）
	DR_PLAYER = 1,    # 仅对玩家/玩家控制单位生效
}

# === 递减分组（对标 TC DiminishingGroup）===
const DR_GROUP_STUN         := "DR_STUN"
const DR_GROUP_ROOT         := "DR_ROOT"
const DR_GROUP_SILENCE      := "DR_SILENCE"
const DR_GROUP_FEAR         := "DR_FEAR"
const DR_GROUP_SLOW         := "DR_SLOW"
const DR_GROUP_KNOCKBACK    := "DR_KNOCKBACK"
const DR_GROUP_INCAPACITATE := "DR_INCAPACITATE"
const DR_GROUP_DISORIENT    := "DR_DISORIENT"
const DR_GROUP_TAUNT        := "DR_TAUNT"

# === 常量 ===
const DR_RESET_TIME := 18.0

# 标准递减：100% → 50% → 25% → 0%
const DR_STANDARD := [1.0, 0.5, 0.25, 0.0, 0.0]
# 嘲讽递减（对标 TC）：100% → 65% → 42% → 27% → 0%
const DR_TAUNT_CURVE := [1.0, 0.65, 0.42, 0.27, 0.0]

# === 分组配置：group -> { "type": DRType, "curve": Array } ===
var _group_config: Dictionary = {
	DR_GROUP_STUN:         {"type": DRType.DR_ALL, "curve": DR_STANDARD},
	DR_GROUP_ROOT:         {"type": DRType.DR_ALL, "curve": DR_STANDARD},
	DR_GROUP_SILENCE:      {"type": DRType.DR_ALL, "curve": DR_STANDARD},
	DR_GROUP_FEAR:         {"type": DRType.DR_ALL, "curve": DR_STANDARD},
	DR_GROUP_SLOW:         {"type": DRType.DR_PLAYER, "curve": DR_STANDARD},
	DR_GROUP_KNOCKBACK:    {"type": DRType.DR_PLAYER, "curve": DR_STANDARD},
	DR_GROUP_INCAPACITATE: {"type": DRType.DR_ALL, "curve": DR_STANDARD},
	DR_GROUP_DISORIENT:    {"type": DRType.DR_ALL, "curve": DR_STANDARD},
	DR_GROUP_TAUNT:        {"type": DRType.DR_ALL, "curve": DR_TAUNT_CURVE},
}

# === CC aura 类型 → 递减分组映射 ===
var _aura_to_group: Dictionary = {
	"CC_STUN": DR_GROUP_STUN,
	"CC_ROOT": DR_GROUP_ROOT,
	"CC_SILENCE": DR_GROUP_SILENCE,
	"CC_FEAR": DR_GROUP_FEAR,
	"CC_INCAPACITATE": DR_GROUP_INCAPACITATE,
	"CC_DISORIENT": DR_GROUP_DISORIENT,
	"TAUNT": DR_GROUP_TAUNT,
}

# === 数据存储 ===
# entity_instance_id -> { dr_group -> { "level": int, "reset_timer": float } }
var _dr_data: Dictionary = {}

func _ready() -> void:
	EngineAPI.register_system("dr", self)
	EventBus.connect_event("entity_killed", _on_entity_killed)

func _process(delta: float) -> void:
	if EngineAPI.get_game_state() != "playing":
		return
	_tick_reset_timers(delta)

func _reset() -> void:
	_dr_data.clear()

# === 公共 API ===

func get_diminished_duration(target: GameEntity, aura_type: String, base_duration: float) -> float:
	## 获取递减后的 CC 持续时间。返回 0.0 = 完全免疫。
	var group: String = get_dr_group(aura_type)
	if group == "":
		return base_duration
	# PvE/PvP 类型检查
	if not _should_apply_dr(target, group):
		return base_duration
	var eid: int = target.get_instance_id()
	var level: int = _get_current_level(eid, group)
	var curve: Array = _get_curve(group)
	var clamped_level: int = mini(level, curve.size() - 1)
	var multiplier: float = curve[clamped_level]
	if multiplier <= 0.0:
		return 0.0
	return base_duration * multiplier

func apply_dr(target: GameEntity, aura_type: String) -> void:
	## 记录一次 CC 命中，递增递减等级
	var group: String = get_dr_group(aura_type)
	if group == "":
		return
	if not _should_apply_dr(target, group):
		return
	var eid: int = target.get_instance_id()
	_ensure_entry(eid)
	var groups: Dictionary = _dr_data[eid]
	var curve: Array = _get_curve(group)
	var max_level: int = curve.size() - 1
	if not groups.has(group):
		groups[group] = {"level": DRLevel.LEVEL_1, "reset_timer": DR_RESET_TIME}
	else:
		groups[group]["level"] = mini(groups[group]["level"] + 1, max_level)
		groups[group]["reset_timer"] = DR_RESET_TIME
	EventBus.emit_event("dr_applied", {
		"entity": target, "group": group,
		"level": groups[group]["level"],
		"multiplier": curve[mini(groups[group]["level"], max_level)],
	})

func has_stronger_aura_with_dr(target: GameEntity, aura_type: String, new_duration: float) -> bool:
	## 检查目标身上是否已有同组更强的 CC（递减后的实际持续时间更长）
	## 对标 TC HasStrongerAuraWithDR：如果新 CC 递减后比现有的短，拒绝覆盖
	var group: String = get_dr_group(aura_type)
	if group == "":
		return false
	var aura_mgr: Node = EngineAPI.get_system("aura")
	if aura_mgr == null:
		return false
	# 查找目标身上同组的现有 CC 剩余时间
	var auras: Array = aura_mgr.call("get_auras_on", target)
	for aura in auras:
		var existing_type: String = aura.get("aura_type", "")
		if get_dr_group(existing_type) == group:
			var remaining: float = aura.get("remaining", 0.0)
			if remaining > new_duration:
				return true  # 现有的更强
	return false

func get_dr_level(target: GameEntity, aura_type: String) -> int:
	var group: String = get_dr_group(aura_type)
	if group == "":
		return DRLevel.LEVEL_1
	return _get_current_level(target.get_instance_id(), group)

func reset_dr(target: GameEntity, group: String = "") -> void:
	## 手动重置递减
	var eid: int = target.get_instance_id()
	if group == "":
		_dr_data.erase(eid)
	elif _dr_data.has(eid):
		_dr_data[eid].erase(group)

func get_dr_group(aura_type: String) -> String:
	return _aura_to_group.get(aura_type, "")

func register_dr_group(aura_type: String, dr_group: String) -> void:
	_aura_to_group[aura_type] = dr_group

func register_group_config(group: String, dr_type: int, curve: Array) -> void:
	## GamePack 注册/覆盖递减分组配置
	_group_config[group] = {"type": dr_type, "curve": curve}

func get_dr_info(target: GameEntity) -> Dictionary:
	if not is_instance_valid(target):
		return {}
	var eid: int = target.get_instance_id()
	if not _dr_data.has(eid):
		return {}
	var result: Dictionary = {}
	for group in _dr_data[eid]:
		var entry: Dictionary = _dr_data[eid][group]
		var curve: Array = _get_curve(group)
		var lvl: int = mini(entry["level"], curve.size() - 1)
		result[group] = {
			"level": entry["level"],
			"multiplier": curve[lvl],
			"reset_in": entry["reset_timer"],
		}
	return result

static func level_to_string(level: int) -> String:
	match level:
		DRLevel.LEVEL_1: return "100%"
		DRLevel.LEVEL_2: return "50%"
		DRLevel.LEVEL_3: return "25%"
		DRLevel.LEVEL_4: return "27%(taunt)"
		DRLevel.LEVEL_IMMUNE: return "IMMUNE"
		_: return "?"

# === 内部 ===

func _should_apply_dr(target: GameEntity, group: String) -> bool:
	## PvE/PvP 区分：DR_PLAYER 类型仅对 player 阵营生效
	var config: Dictionary = _group_config.get(group, {})
	var dr_type: int = config.get("type", DRType.DR_ALL)
	if dr_type == DRType.DR_PLAYER:
		return target.faction == "player"
	return true

func _get_curve(group: String) -> Array:
	var config: Dictionary = _group_config.get(group, {})
	return config.get("curve", DR_STANDARD)

func _ensure_entry(eid: int) -> void:
	if not _dr_data.has(eid):
		_dr_data[eid] = {}

func _get_current_level(eid: int, group: String) -> int:
	if not _dr_data.has(eid) or not _dr_data[eid].has(group):
		return DRLevel.LEVEL_1
	return _dr_data[eid][group]["level"]

func _tick_reset_timers(delta: float) -> void:
	var to_clean: Array = []
	for eid in _dr_data:
		var groups: Dictionary = _dr_data[eid]
		var to_remove: Array = []
		for group in groups:
			groups[group]["reset_timer"] -= delta
			if groups[group]["reset_timer"] <= 0:
				to_remove.append(group)
		for group in to_remove:
			groups.erase(group)
		if groups.is_empty():
			to_clean.append(eid)
	for eid in to_clean:
		_dr_data.erase(eid)

func _on_entity_killed(data: Dictionary) -> void:
	## 死亡自动清除所有递减（对标 TC ClearDiminishings on death）
	var entity = data.get("entity")
	if entity == null or not (entity is GameEntity):
		return
	_dr_data.erase((entity as GameEntity).get_instance_id())
