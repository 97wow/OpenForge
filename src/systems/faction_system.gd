## FactionSystem — 多阵营 + 声望 + Reaction Matrix（对标 TrinityCore FactionTemplate）
## 替代当前 GameEntity 中简单的 "player"/"enemy"/"neutral" 硬编码
## 支持任意数量阵营、阵营间关系矩阵、声望等级、动态关系变更
## 向后兼容：未注册阵营时回退到旧的字符串 faction 逻辑
class_name FactionSystem
extends Node

# === 阵营关系类型（对标 TC ReputationRank）===
enum Reaction {
	HOSTILE = 0,   # 敌对（可攻击）
	UNFRIENDLY = 1, # 不友好（不可交易，不攻击）
	NEUTRAL = 2,    # 中立
	FRIENDLY = 3,   # 友好（可交易）
	HONORED = 4,    # 尊敬
	EXALTED = 5,    # 崇拜
}

# === 数据存储 ===

# 阵营模板定义: faction_id -> FactionTemplate
# FactionTemplate: {
#   "faction_id": String,
#   "name_key": String,        # I18n key
#   "base_reactions": { other_faction_id: Reaction },  # 默认关系
#   "parent_faction": String,  # 父阵营（继承关系）
# }
var _faction_templates: Dictionary = {}

# 实体阵营分配: entity_instance_id -> faction_id
var _entity_factions: Dictionary = {}

# 声望系统: "player" -> { faction_id: rep_value(float) }
# 声望值范围: -42000 (HOSTILE) ~ 42000 (EXALTED)
var _reputations: Dictionary = {}

# 动态关系覆盖: "factionA_factionB" -> Reaction
var _reaction_overrides: Dictionary = {}

# 声望阈值
const REP_HOSTILE     := -6000.0
const REP_UNFRIENDLY  := -3000.0
const REP_NEUTRAL     := 0.0
const REP_FRIENDLY    := 3000.0
const REP_HONORED     := 9000.0
const REP_EXALTED     := 21000.0
const REP_MAX         := 42000.0
const REP_MIN         := -42000.0

func _ready() -> void:
	EngineAPI.register_system("faction", self)
	# 注册内置阵营（向后兼容）
	_register_default_factions()

func _reset() -> void:
	_entity_factions.clear()
	_reputations.clear()
	_reaction_overrides.clear()
	# 保留阵营模板，它们通常是 GamePack 加载时注册的

# === 阵营模板 API ===

func register_faction(faction_def: Dictionary) -> void:
	## 注册阵营模板
	var faction_id: String = faction_def.get("faction_id", "")
	if faction_id == "":
		return
	_faction_templates[faction_id] = faction_def

func get_faction_template(faction_id: String) -> Dictionary:
	return _faction_templates.get(faction_id, {})

func get_all_factions() -> Array[String]:
	var result: Array[String] = []
	for key in _faction_templates:
		result.append(key)
	return result

# === 实体阵营 API ===

func set_entity_faction(entity: GameEntity, faction_id: String) -> void:
	## 设置实体的阵营（同时更新 GameEntity.faction 保持向后兼容）
	if not is_instance_valid(entity):
		return
	var eid: int = entity.get_instance_id()
	var old_faction: String = _entity_factions.get(eid, entity.faction)
	_entity_factions[eid] = faction_id
	# 向后兼容：同步到 GameEntity.faction
	entity.faction = faction_id
	if old_faction != faction_id:
		EventBus.emit_event("faction_changed", {
			"entity": entity, "old_faction": old_faction, "new_faction": faction_id,
		})

func get_entity_faction(entity: GameEntity) -> String:
	if not is_instance_valid(entity):
		return "neutral"
	var eid: int = entity.get_instance_id()
	return _entity_factions.get(eid, entity.faction)

# === Reaction Matrix API ===

func get_reaction(faction_a: String, faction_b: String) -> int:
	## 获取两个阵营之间的关系（考虑：覆盖 > 模板 > 默认逻辑）
	if faction_a == faction_b:
		return Reaction.FRIENDLY
	# 1. 检查动态覆盖
	var override_key := _reaction_key(faction_a, faction_b)
	if _reaction_overrides.has(override_key):
		return _reaction_overrides[override_key]
	# 2. 检查模板定义
	var template_a: Dictionary = _faction_templates.get(faction_a, {})
	var base_reactions: Dictionary = template_a.get("base_reactions", {})
	if base_reactions.has(faction_b):
		return base_reactions[faction_b]
	# 3. 检查父阵营
	var parent_a: String = template_a.get("parent_faction", "")
	if parent_a != "" and parent_a != faction_a:
		return get_reaction(parent_a, faction_b)
	# 4. 回退：旧逻辑兼容
	return _legacy_reaction(faction_a, faction_b)

func set_reaction_override(faction_a: String, faction_b: String, reaction: int) -> void:
	## 动态设置两个阵营之间的关系（双向）
	_reaction_overrides[_reaction_key(faction_a, faction_b)] = reaction
	_reaction_overrides[_reaction_key(faction_b, faction_a)] = reaction
	EventBus.emit_event("faction_reaction_changed", {
		"faction_a": faction_a, "faction_b": faction_b, "reaction": reaction,
	})

func clear_reaction_override(faction_a: String, faction_b: String) -> void:
	_reaction_overrides.erase(_reaction_key(faction_a, faction_b))
	_reaction_overrides.erase(_reaction_key(faction_b, faction_a))

func is_hostile(faction_a: String, faction_b: String) -> bool:
	return get_reaction(faction_a, faction_b) <= Reaction.HOSTILE

func is_friendly(faction_a: String, faction_b: String) -> bool:
	return get_reaction(faction_a, faction_b) >= Reaction.FRIENDLY

func is_neutral(faction_a: String, faction_b: String) -> bool:
	var r: int = get_reaction(faction_a, faction_b)
	return r == Reaction.NEUTRAL or r == Reaction.UNFRIENDLY

# === 实体间关系查询（便捷方法）===

func are_hostile(entity_a: GameEntity, entity_b: GameEntity) -> bool:
	return is_hostile(get_entity_faction(entity_a), get_entity_faction(entity_b))

func are_friendly(entity_a: GameEntity, entity_b: GameEntity) -> bool:
	return is_friendly(get_entity_faction(entity_a), get_entity_faction(entity_b))

# === 声望 API ===

func get_reputation(player_id: String, faction_id: String) -> float:
	## 获取玩家对某阵营的声望值
	if not _reputations.has(player_id):
		return REP_NEUTRAL
	return _reputations[player_id].get(faction_id, REP_NEUTRAL)

func add_reputation(player_id: String, faction_id: String, amount: float) -> void:
	## 增加/减少声望值
	if not _reputations.has(player_id):
		_reputations[player_id] = {}
	var current: float = _reputations[player_id].get(faction_id, REP_NEUTRAL)
	var new_val: float = clampf(current + amount, REP_MIN, REP_MAX)
	_reputations[player_id][faction_id] = new_val
	var old_rank: int = rep_to_rank(current)
	var new_rank: int = rep_to_rank(new_val)
	EventBus.emit_event("reputation_changed", {
		"player_id": player_id,
		"faction_id": faction_id,
		"old_value": current,
		"new_value": new_val,
		"rank_changed": old_rank != new_rank,
		"new_rank": new_rank,
	})

func set_reputation(player_id: String, faction_id: String, value: float) -> void:
	if not _reputations.has(player_id):
		_reputations[player_id] = {}
	_reputations[player_id][faction_id] = clampf(value, REP_MIN, REP_MAX)

func get_reputation_rank(player_id: String, faction_id: String) -> int:
	return rep_to_rank(get_reputation(player_id, faction_id))

static func rep_to_rank(rep_value: float) -> int:
	## 声望值 → 声望等级
	if rep_value >= REP_EXALTED: return Reaction.EXALTED
	if rep_value >= REP_HONORED: return Reaction.HONORED
	if rep_value >= REP_FRIENDLY: return Reaction.FRIENDLY
	if rep_value >= REP_NEUTRAL: return Reaction.NEUTRAL
	if rep_value >= REP_UNFRIENDLY: return Reaction.UNFRIENDLY
	return Reaction.HOSTILE

static func rank_to_string(rank: int) -> String:
	match rank:
		Reaction.HOSTILE: return "HOSTILE"
		Reaction.UNFRIENDLY: return "UNFRIENDLY"
		Reaction.NEUTRAL: return "NEUTRAL"
		Reaction.FRIENDLY: return "FRIENDLY"
		Reaction.HONORED: return "HONORED"
		Reaction.EXALTED: return "EXALTED"
		_: return "UNKNOWN"

# === 内部方法 ===

func _register_default_factions() -> void:
	## 注册默认阵营（向后兼容现有 "player"/"enemy"/"neutral"）
	register_faction({
		"faction_id": "player",
		"name_key": "FACTION_PLAYER",
		"base_reactions": {"enemy": Reaction.HOSTILE, "neutral": Reaction.NEUTRAL},
	})
	register_faction({
		"faction_id": "enemy",
		"name_key": "FACTION_ENEMY",
		"base_reactions": {"player": Reaction.HOSTILE, "neutral": Reaction.NEUTRAL},
	})
	register_faction({
		"faction_id": "neutral",
		"name_key": "FACTION_NEUTRAL",
		"base_reactions": {"player": Reaction.NEUTRAL, "enemy": Reaction.NEUTRAL},
	})

func _legacy_reaction(faction_a: String, faction_b: String) -> int:
	## 向后兼容：旧的 player/enemy/neutral 逻辑
	if faction_a == "neutral" or faction_b == "neutral":
		return Reaction.NEUTRAL
	if faction_a == faction_b:
		return Reaction.FRIENDLY
	# player vs enemy
	if (faction_a == "player" and faction_b == "enemy") or (faction_a == "enemy" and faction_b == "player"):
		return Reaction.HOSTILE
	# 未知组合默认中立
	return Reaction.NEUTRAL

func _reaction_key(faction_a: String, faction_b: String) -> String:
	return "%s_%s" % [faction_a, faction_b]
