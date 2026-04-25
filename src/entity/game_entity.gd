## GameEntity - 通用游戏实体
## 所有游戏对象的基类，通过 tags + components 定义行为
## "塔"、"敌人"、"英雄" 只是不同的 tag 组合
class_name GameEntity
extends Node3D

var runtime_id: int = -1
var def_id: String = ""
var tags: PackedStringArray = []
var meta: Dictionary = {}  # 存储非组件的自定义数据（cost, tier 等）
var faction: String = "neutral"  # "player" / "enemy" / "neutral"
## 生物等级（对标 TC creature_template.rank）：0=Normal, 1=Elite, 2=Rare, 3=Boss
var creature_rank: int = 0
var is_alive: bool = true  # 向后兼容：由 unit_state 同步
var unit_state: int = UnitFlags.UnitState.ALIVE  # 对标 TrinityCore Unit::DeathState
var unit_flags: int = 0  # Bitmask，对标 TrinityCore Unit::m_unitFlags
var lifespan: float = -1.0  # 存活时间（秒），<= 0 表示永久
var _lifespan_timer: float = 0.0

var _components: Dictionary = {}  # component_name -> Node

# === 初始化 ===

func setup(id: String, def: Dictionary, overrides: Dictionary = {}) -> void:
	def_id = id
	name = "%s_%d" % [id, runtime_id]

	# 应用 tags（overrides 完全替换 def 的 tags，避免 tag 污染）
	var tag_source: Array = overrides.get("tags", []) if overrides.has("tags") else def.get("tags", [])
	for tag in tag_source:
		tags.append(str(tag))

	# 存储 meta 数据
	meta = def.get("meta", {}).duplicate()
	meta.merge(overrides.get("meta", {}), true)

	# 存活时间（TempSummon 模式）
	lifespan = float(overrides.get("lifespan", def.get("lifespan", -1.0)))
	_lifespan_timer = 0.0

	# 阵营：优先 overrides > def > 根据 tags 推断
	faction = overrides.get("faction", def.get("faction", ""))
	if faction == "":
		if has_tag("player") or has_tag("friendly") or has_tag("hero"):
			faction = "player"
		elif has_tag("enemy"):
			faction = "enemy"
		else:
			faction = "neutral"

# === Tag 操作 ===

func has_tag(tag: String) -> bool:
	return tag in tags

func add_tag(tag: String) -> void:
	if tag not in tags:
		tags.append(tag)

func remove_tag(tag: String) -> void:
	var idx := tags.find(tag)
	if idx >= 0:
		tags.remove_at(idx)

func get_tags() -> PackedStringArray:
	return tags

# === 组件操作 ===

func get_component(component_name: String) -> Node:
	return _components.get(component_name)

func has_component(component_name: String) -> bool:
	return _components.has(component_name)

func add_component(component_name: String, component: Node) -> void:
	if _components.has(component_name):
		remove_component(component_name)
	_components[component_name] = component
	component.name = component_name.to_pascal_case() + "Component"
	add_child(component)
	# 让组件知道自己的宿主
	if component.has_method("_on_attached"):
		component.call("_on_attached", self)

func remove_component(component_name: String) -> void:
	if not _components.has(component_name):
		return
	var component: Node = _components[component_name]
	if component.has_method("_on_detached"):
		component.call("_on_detached")
	_components.erase(component_name)
	component.queue_free()

func get_all_components() -> Dictionary:
	return _components.duplicate()

# === 便捷访问 ===

# === 阵营 ===

func is_hostile_to(other: GameEntity) -> bool:
	## 优先使用 FactionSystem（支持多阵营），回退到旧逻辑
	var faction_sys: Node = EngineAPI.get_system("faction")
	if faction_sys:
		return faction_sys.call("is_hostile", faction, other.faction)
	# 旧逻辑回退
	if faction == "neutral" or other.faction == "neutral":
		return false
	return faction != other.faction

func is_friendly_to(other: GameEntity) -> bool:
	var faction_sys: Node = EngineAPI.get_system("faction")
	if faction_sys:
		return faction_sys.call("is_friendly", faction, other.faction)
	if faction == "neutral" or other.faction == "neutral":
		return true
	return faction == other.faction

func get_hostile_faction() -> String:
	## 旧接口保留向后兼容，但仅适用于二元阵营
	## 多阵营场景请直接用 is_hostile_to() 判断
	match faction:
		"player": return "enemy"
		"enemy": return "player"
		_: return ""

# === Unit Flags（对标 TrinityCore Unit::HasFlag / SetFlag / RemoveFlag）===

func has_unit_flag(flag: int) -> bool:
	return (unit_flags & flag) != 0

func has_any_flag(flags: int) -> bool:
	## 检查是否有 flags 中的任意一个
	return (unit_flags & flags) != 0

func has_all_flags(flags: int) -> bool:
	## 检查是否同时有 flags 中的全部
	return (unit_flags & flags) == flags

func set_unit_flag(flag: int) -> void:
	var old: int = unit_flags
	unit_flags |= flag
	if old != unit_flags:
		EventBus.emit_event("unit_flags_changed", {
			"entity": self, "old_flags": old, "new_flags": unit_flags
		})

func clear_unit_flag(flag: int) -> void:
	var old: int = unit_flags
	unit_flags &= ~flag
	if old != unit_flags:
		EventBus.emit_event("unit_flags_changed", {
			"entity": self, "old_flags": old, "new_flags": unit_flags
		})

func set_unit_state(new_state: int) -> void:
	unit_state = new_state
	match new_state:
		UnitFlags.UnitState.DEAD:
			is_alive = false
		UnitFlags.UnitState.ALIVE:
			is_alive = true
		UnitFlags.UnitState.EVADING:
			is_alive = true
			set_unit_flag(UnitFlags.EVADING | UnitFlags.IMMUNE_DAMAGE | UnitFlags.NOT_SELECTABLE)

# === 便捷访问 ===

func get_meta_value(key: String, default: Variant = null) -> Variant:
	return meta.get(key, default)

func set_meta_value(key: String, value: Variant) -> void:
	meta[key] = value
