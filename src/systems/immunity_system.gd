## ImmunitySystem — 学校免疫 + 机制免疫（对标 TrinityCore SpellSchoolImmunity / MechanicImmunity）
## 管理每个实体的伤害学校免疫和机制免疫
## 与 DamagePipeline 集成：伤害前检查学校免疫
## 与 AuraManager 集成：应用 aura 前检查机制免疫
## GamePack 通过 Aura 或直接 API 授予/移除免疫
class_name ImmunitySystem
extends Node

# === 伤害学校（对标 TC SpellSchoolMask，与 HealthComponent.DamageType 一致）===
# 使用 bitmask 支持多学校免疫（如 "免疫所有魔法" = FROST|FIRE|NATURE|SHADOW|HOLY）
const SCHOOL_PHYSICAL: int = 1 << 0
const SCHOOL_FROST:    int = 1 << 1
const SCHOOL_FIRE:     int = 1 << 2
const SCHOOL_NATURE:   int = 1 << 3
const SCHOOL_SHADOW:   int = 1 << 4
const SCHOOL_HOLY:     int = 1 << 5

## 复合掩码
const SCHOOL_ALL_MAGIC: int = SCHOOL_FROST | SCHOOL_FIRE | SCHOOL_NATURE | SCHOOL_SHADOW | SCHOOL_HOLY
const SCHOOL_ALL:       int = SCHOOL_PHYSICAL | SCHOOL_ALL_MAGIC

# === 机制免疫类型（对标 TC Mechanics）===
# 机制类型字符串，与 AuraManager 的 aura_type 和 spell effect 的 mechanic 字段对应
const MECHANIC_STUN    := "STUN"
const MECHANIC_ROOT    := "ROOT"
const MECHANIC_SILENCE := "SILENCE"
const MECHANIC_FEAR    := "FEAR"
const MECHANIC_SLOW    := "SLOW"
const MECHANIC_BLEED   := "BLEED"
const MECHANIC_POISON  := "POISON"
const MECHANIC_KNOCKBACK := "KNOCKBACK"

# === 数据存储 ===
# entity_instance_id -> { "school_mask": int, "mechanics": { mechanic_str: ref_count } }
var _immunities: Dictionary = {}

func _ready() -> void:
	EngineAPI.register_system("immunity", self)
	# 监听伤害前事件
	EventBus.connect_event("damage_calculating", _on_damage_calculating)

func _reset() -> void:
	_immunities.clear()

# === 学校免疫 API ===

func grant_school_immunity(entity: GameEntity, school_mask: int, source_id: String = "") -> void:
	## 授予伤害学校免疫（可叠加，ref-counted by source）
	if not is_instance_valid(entity):
		return
	var eid: int = entity.get_instance_id()
	_ensure_entry(eid)
	var entry: Dictionary = _immunities[eid]
	# 记录来源（用于精确移除）
	if not entry.has("school_sources"):
		entry["school_sources"] = {}
	entry["school_sources"][source_id] = school_mask
	# 重新计算合并掩码
	_recalc_school_mask(eid)

	EventBus.emit_event("immunity_changed", {
		"entity": entity, "type": "school", "granted": true,
		"school_mask": school_mask, "source": source_id,
	})

func revoke_school_immunity(entity: GameEntity, source_id: String = "") -> void:
	## 移除指定来源的学校免疫
	if not is_instance_valid(entity):
		return
	var eid: int = entity.get_instance_id()
	if not _immunities.has(eid):
		return
	var entry: Dictionary = _immunities[eid]
	if entry.has("school_sources"):
		entry["school_sources"].erase(source_id)
	_recalc_school_mask(eid)

	EventBus.emit_event("immunity_changed", {
		"entity": entity, "type": "school", "granted": false, "source": source_id,
	})

func is_immune_to_school(entity: GameEntity, school: int) -> bool:
	## 检查实体是否免疫指定伤害学校
	if not is_instance_valid(entity):
		return false
	var eid: int = entity.get_instance_id()
	if not _immunities.has(eid):
		return false
	return (_immunities[eid].get("school_mask", 0) & school) != 0

# === 机制免疫 API ===

func grant_mechanic_immunity(entity: GameEntity, mechanic: String, source_id: String = "") -> void:
	## 授予机制免疫（ref-counted：多个来源可独立授予/移除）
	if not is_instance_valid(entity):
		return
	var eid: int = entity.get_instance_id()
	_ensure_entry(eid)
	var entry: Dictionary = _immunities[eid]
	var mechanics: Dictionary = entry.get("mechanics", {})
	if not mechanics.has(mechanic):
		mechanics[mechanic] = {}
	mechanics[mechanic][source_id] = true
	entry["mechanics"] = mechanics

	# CC 机制免疫同步到 UnitFlags（如 STUN 免疫也意味着当前 STUN 应被驱散）
	_sync_cc_immunity_flags(entity, mechanic, true)

	EventBus.emit_event("immunity_changed", {
		"entity": entity, "type": "mechanic", "granted": true,
		"mechanic": mechanic, "source": source_id,
	})

func revoke_mechanic_immunity(entity: GameEntity, mechanic: String, source_id: String = "") -> void:
	## 移除指定来源的机制免疫
	if not is_instance_valid(entity):
		return
	var eid: int = entity.get_instance_id()
	if not _immunities.has(eid):
		return
	var entry: Dictionary = _immunities[eid]
	var mechanics: Dictionary = entry.get("mechanics", {})
	if mechanics.has(mechanic):
		mechanics[mechanic].erase(source_id)
		if mechanics[mechanic].is_empty():
			mechanics.erase(mechanic)
			_sync_cc_immunity_flags(entity, mechanic, false)
	entry["mechanics"] = mechanics

	EventBus.emit_event("immunity_changed", {
		"entity": entity, "type": "mechanic", "granted": false,
		"mechanic": mechanic, "source": source_id,
	})

func is_immune_to_mechanic(entity: GameEntity, mechanic: String) -> bool:
	## 检查实体是否免疫指定机制
	if not is_instance_valid(entity):
		return false
	var eid: int = entity.get_instance_id()
	if not _immunities.has(eid):
		return false
	var mechanics: Dictionary = _immunities[eid].get("mechanics", {})
	return mechanics.has(mechanic) and not mechanics[mechanic].is_empty()

# === 查询 ===

func get_immunities(entity: GameEntity) -> Dictionary:
	## 返回实体的完整免疫信息（用于 UI/调试）
	if not is_instance_valid(entity):
		return {}
	var eid: int = entity.get_instance_id()
	if not _immunities.has(eid):
		return {"school_mask": 0, "mechanics": []}
	var entry: Dictionary = _immunities[eid]
	var active_mechs: Array[String] = []
	for m in entry.get("mechanics", {}):
		if not entry["mechanics"][m].is_empty():
			active_mechs.append(m)
	return {
		"school_mask": entry.get("school_mask", 0),
		"mechanics": active_mechs,
	}

func clear_immunities(entity: GameEntity) -> void:
	## 清除实体的所有免疫（死亡/重置时调用）
	if not is_instance_valid(entity):
		return
	var eid: int = entity.get_instance_id()
	_immunities.erase(eid)

# === 工具方法 ===

static func school_from_damage_type(damage_type: int) -> int:
	## HealthComponent.DamageType(int) → ImmunitySystem school bitmask
	match damage_type:
		0: return SCHOOL_PHYSICAL  # DamageType.PHYSICAL
		1: return SCHOOL_FROST     # DamageType.FROST
		2: return SCHOOL_FIRE      # DamageType.FIRE
		3: return SCHOOL_NATURE    # DamageType.NATURE
		4: return SCHOOL_SHADOW    # DamageType.SHADOW
		5: return SCHOOL_HOLY      # DamageType.HOLY
		_: return SCHOOL_PHYSICAL

static func school_from_string(school_str: String) -> int:
	## 字符串 → school bitmask（JSON 数据驱动用）
	match school_str.to_lower():
		"physical": return SCHOOL_PHYSICAL
		"frost", "ice": return SCHOOL_FROST
		"fire": return SCHOOL_FIRE
		"nature", "poison": return SCHOOL_NATURE
		"shadow", "dark": return SCHOOL_SHADOW
		"holy", "light": return SCHOOL_HOLY
		"all_magic": return SCHOOL_ALL_MAGIC
		"all": return SCHOOL_ALL
		_: return 0

static func school_to_string(school_mask: int) -> String:
	var parts: PackedStringArray = []
	if school_mask & SCHOOL_PHYSICAL: parts.append("Physical")
	if school_mask & SCHOOL_FROST: parts.append("Frost")
	if school_mask & SCHOOL_FIRE: parts.append("Fire")
	if school_mask & SCHOOL_NATURE: parts.append("Nature")
	if school_mask & SCHOOL_SHADOW: parts.append("Shadow")
	if school_mask & SCHOOL_HOLY: parts.append("Holy")
	return "|".join(parts) if parts.size() > 0 else "None"

static func mechanic_from_cc_aura(aura_type: String) -> String:
	## CC aura 类型 → 机制名（用于免疫检查）
	match aura_type:
		"CC_STUN": return MECHANIC_STUN
		"CC_ROOT": return MECHANIC_ROOT
		"CC_SILENCE": return MECHANIC_SILENCE
		"CC_FEAR": return MECHANIC_FEAR
		_: return ""

# === 内部方法 ===

func _ensure_entry(eid: int) -> void:
	if not _immunities.has(eid):
		_immunities[eid] = {
			"school_mask": 0,
			"school_sources": {},
			"mechanics": {},
		}

func _recalc_school_mask(eid: int) -> void:
	## 从所有来源合并计算最终 school mask
	var entry: Dictionary = _immunities[eid]
	var combined: int = 0
	for source_id in entry.get("school_sources", {}):
		combined |= entry["school_sources"][source_id]
	entry["school_mask"] = combined

func _sync_cc_immunity_flags(entity: GameEntity, mechanic: String, granted: bool) -> void:
	## CC 机制免疫与 UnitFlags.IMMUNE_CC 的同步
	## 如果获得任何 CC 机制免疫，检查是否应该移除当前对应的 CC 效果
	if not granted:
		return
	# 获得 CC 免疫时，移除当前身上对应的 CC aura
	var aura_mgr: Node = EngineAPI.get_system("aura")
	if aura_mgr == null:
		return
	var cc_aura_type := ""
	match mechanic:
		MECHANIC_STUN: cc_aura_type = "CC_STUN"
		MECHANIC_ROOT: cc_aura_type = "CC_ROOT"
		MECHANIC_SILENCE: cc_aura_type = "CC_SILENCE"
		MECHANIC_FEAR: cc_aura_type = "CC_FEAR"
	if cc_aura_type == "":
		return
	# 移除所有匹配类型的 CC aura
	var auras: Array = aura_mgr.call("get_auras_on", entity)
	for aura in auras:
		if aura.get("aura_type", "") == cc_aura_type:
			aura_mgr.call("remove_aura", entity, aura.get("aura_id", ""))

# === 事件 Hook ===

func _on_damage_calculating(data: Dictionary) -> void:
	## Hook 进 DamagePipeline 的 damage_calculating 事件
	## 如果目标免疫该伤害学校，将伤害置为 0
	var target = data.get("target")
	if target == null or not is_instance_valid(target) or not (target is GameEntity):
		return
	var ge: GameEntity = target as GameEntity
	var school_str: String = data.get("school", "physical") if data.get("school") is String else ""
	# DamagePipeline 传过来的 school 是 int（DamageType enum）
	# damage_calculating 事件中 school 可能是 string 或 int
	var school_mask: int = 0
	if school_str != "":
		school_mask = school_from_string(school_str)
	else:
		var school_int: int = data.get("school", 0)
		school_mask = school_from_damage_type(school_int)

	if school_mask != 0 and is_immune_to_school(ge, school_mask):
		data["base_amount"] = 0.0
