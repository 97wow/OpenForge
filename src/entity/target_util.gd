## TargetUtil — 统一目标有效性检查（对标 TrinityCore Unit::IsValidAttackTarget / IsValidAssistTarget）
## 所有系统的目标选择必须通过此类，不再散落检查
class_name TargetUtil
extends RefCounted

# === 攻击目标检查 ===

static func is_valid_attack_target(attacker: Variant, target: Variant, ignore_immunity: bool = false) -> bool:
	## 对标 TrinityCore Unit::IsValidAttackTarget()
	## attacker 能否攻击 target？检查：存活/阵营/flags/免疫
	if not _is_valid_base(target):
		return false
	var t: GameEntity = target as GameEntity
	# 不能攻击不可选中/正在逃离的目标
	if t.has_any_flag(UnitFlags.TARGET_PREVENTING):
		return false
	# 免疫伤害检查（除非 ignore_immunity）
	if not ignore_immunity and t.has_unit_flag(UnitFlags.IMMUNE_DAMAGE):
		return false
	# 攻击者检查
	if attacker == null or not is_instance_valid(attacker):
		return true  # 无来源（如 DOT 的 source 已死）→ 允许
	if attacker == target:
		return false
	# 阵营检查
	if attacker is GameEntity:
		if (attacker as GameEntity).is_friendly_to(t):
			return false
	return true

# === 辅助目标检查（治疗/Buff）===

static func is_valid_assist_target(helper: Variant, target: Variant) -> bool:
	## 对标 TrinityCore Unit::IsValidAssistTarget()
	## helper 能否治疗/buff target？
	if not _is_valid_base(target):
		return false
	if helper == null or not is_instance_valid(helper):
		return true
	if helper == target:
		return true  # 可以辅助自己
	# 阵营检查：只能辅助友方
	if helper is GameEntity and target is GameEntity:
		if (helper as GameEntity).is_hostile_to(target as GameEntity):
			return false
	return true

# === 状态便捷查询 ===

static func can_attack(entity: GameEntity) -> bool:
	## 实体当前能否执行攻击？
	if not entity.is_alive:
		return false
	return not entity.has_any_flag(UnitFlags.ATTACK_PREVENTING)

static func can_cast(entity: GameEntity) -> bool:
	## 实体当前能否施法？
	if not entity.is_alive:
		return false
	return not entity.has_any_flag(UnitFlags.CAST_PREVENTING)

static func can_move(entity: GameEntity) -> bool:
	## 实体当前能否自主移动？
	if not entity.is_alive:
		return false
	return not entity.has_any_flag(UnitFlags.MOVEMENT_PREVENTING)

# === 内部 ===

static func _is_valid_base(target: Variant) -> bool:
	## 基础有效性：非空 + 节点有效 + 是 GameEntity + 存活
	if target == null or not is_instance_valid(target):
		return false
	if not (target is GameEntity):
		return false
	return (target as GameEntity).is_alive
