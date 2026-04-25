## UnitFlags — 单位状态标志位（对标 TrinityCore UnitFlags / UnitState）
## 框架层常量定义，所有系统通过 UnitFlags.CONSTANT 访问
class_name UnitFlags
extends RefCounted

# === UnitState（互斥状态枚举）===
enum UnitState {
	ALIVE = 0,
	DEAD = 1,
	EVADING = 2,
}

# === UnitFlags（bitmask，可组合）===
const STUNNED:        int = 1 << 0   # 无法移动+攻击+施法
const ROOTED:         int = 1 << 1   # 无法移动，可攻击/施法
const SILENCED:       int = 1 << 2   # 无法施法，可移动/攻击
const FEARED:         int = 1 << 3   # 随机移动，无法控制
const IMMUNE_DAMAGE:  int = 1 << 4   # 免疫所有伤害
const IMMUNE_CC:      int = 1 << 5   # 免疫控制效果
const CASTING:        int = 1 << 6   # 正在施法（可被打断）
const CHANNELING:     int = 1 << 7   # 正在引导（可被打断）
const EVADING:        int = 1 << 8   # 正在回家（免疫+不可选中）
const NOT_SELECTABLE: int = 1 << 9   # 不可被选为目标
const IN_COMBAT:      int = 1 << 10  # 战斗中

# === 复合掩码（用于快速批量检查）===

## 所有 CC 类 flag
const CC_FLAGS: int = STUNNED | ROOTED | SILENCED | FEARED

## 阻止移动的 flag（FEARED 也阻止自主移动，未来改为随机移动）
const MOVEMENT_PREVENTING: int = STUNNED | ROOTED | FEARED

## 阻止攻击的 flag
const ATTACK_PREVENTING: int = STUNNED | FEARED

## 阻止施法的 flag
const CAST_PREVENTING: int = STUNNED | SILENCED | FEARED

## 阻止被选为攻击目标的 flag
const TARGET_PREVENTING: int = NOT_SELECTABLE | EVADING

# === CC Aura 类型 → Flag 映射（用于 AuraManager）===
const CC_AURA_TO_FLAG: Dictionary = {
	"CC_STUN":    STUNNED,
	"CC_ROOT":    ROOTED,
	"CC_SILENCE": SILENCED,
	"CC_FEAR":    FEARED,
}

# === 工具方法 ===

## 从字符串名获取 flag 值（用于 JSON 数据引用）
static func flag_from_string(flag_name: String) -> int:
	match flag_name.to_upper():
		"STUNNED": return STUNNED
		"ROOTED": return ROOTED
		"SILENCED": return SILENCED
		"FEARED": return FEARED
		"IMMUNE_DAMAGE": return IMMUNE_DAMAGE
		"IMMUNE_CC": return IMMUNE_CC
		"CASTING": return CASTING
		"CHANNELING": return CHANNELING
		"EVADING": return EVADING
		"NOT_SELECTABLE": return NOT_SELECTABLE
		"IN_COMBAT": return IN_COMBAT
		_: return 0

## 获取 flag 的可读名称（用于调试显示）
static func flag_to_string(flag: int) -> String:
	var parts: PackedStringArray = []
	if flag & STUNNED: parts.append("STUNNED")
	if flag & ROOTED: parts.append("ROOTED")
	if flag & SILENCED: parts.append("SILENCED")
	if flag & FEARED: parts.append("FEARED")
	if flag & IMMUNE_DAMAGE: parts.append("IMMUNE_DMG")
	if flag & IMMUNE_CC: parts.append("IMMUNE_CC")
	if flag & CASTING: parts.append("CASTING")
	if flag & CHANNELING: parts.append("CHANNELING")
	if flag & EVADING: parts.append("EVADING")
	if flag & NOT_SELECTABLE: parts.append("NOT_SELECTABLE")
	if flag & IN_COMBAT: parts.append("IN_COMBAT")
	return "|".join(parts) if parts.size() > 0 else "NONE"
