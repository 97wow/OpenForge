## StatSystem - 通用属性系统
## 管理实体属性值，借鉴 War3 属性模型:
##   白字 = white_base + white_growth * (level - 1)  (英雄固有属性，随等级成长)
##   绿字 = green_flat, green_percent              (装备/卡片/buff 加成)
##   最终值 = (white + green_flat) * (1 + green_percent)
class_name StatSystem
extends Node

# entity_runtime_id -> { stat_name -> base_value }
var _base_stats: Dictionary = {}

# === 白字/绿字属性存储 ===
# entity_runtime_id -> { stat_name -> value }
var _white_base: Dictionary = {}    # 白字基础值（初始/永久增加）
var _white_growth: Dictionary = {}  # 白字每级成长值
var _green_flat: Dictionary = {}    # 绿字固定加成
var _green_percent: Dictionary = {} # 绿字百分比加成

func _reset() -> void:
	_base_stats.clear()
	_white_base.clear()
	_white_growth.clear()
	_green_flat.clear()
	_green_percent.clear()

func _ready() -> void:
	EngineAPI.register_system("stat", self)

# === 实体注册 ===

func register_entity(entity: Node3D, base_stats: Dictionary) -> void:
	if not entity is GameEntity:
		return
	var eid: int = (entity as GameEntity).runtime_id
	_base_stats[eid] = base_stats.duplicate()
	# 初始化白字/绿字存储（如果不存在）
	if not _white_base.has(eid):
		_white_base[eid] = {}
	if not _white_growth.has(eid):
		_white_growth[eid] = {}
	if not _green_flat.has(eid):
		_green_flat[eid] = {}
	if not _green_percent.has(eid):
		_green_percent[eid] = {}

func unregister_entity(entity: Node3D) -> void:
	if not entity is GameEntity:
		return
	var eid: int = (entity as GameEntity).runtime_id
	_base_stats.erase(eid)
	_white_base.erase(eid)
	_white_growth.erase(eid)
	_green_flat.erase(eid)
	_green_percent.erase(eid)

# === 查询 ===

func get_stat(entity: Node3D, stat_name: String) -> float:
	## 返回属性最终值（委托 get_total_stat，默认 level=1）
	return get_total_stat(entity, stat_name)

func get_base_stat(entity: Node3D, stat_name: String) -> float:
	if not entity is GameEntity:
		return 0.0
	var eid: int = (entity as GameEntity).runtime_id
	if not _base_stats.has(eid):
		return 0.0
	return _base_stats[eid].get(stat_name, 0.0)

func set_base_stat(entity: Node3D, stat_name: String, value: float) -> void:
	if not entity is GameEntity:
		return
	var eid: int = (entity as GameEntity).runtime_id
	if not _base_stats.has(eid):
		_base_stats[eid] = {}
	_base_stats[eid][stat_name] = value

# === 白字/绿字属性 API（War3 风格）===

func _ensure_eid(entity: Node3D) -> int:
	## 返回 entity runtime_id，无效返回 -1
	if not entity is GameEntity:
		return -1
	var eid: int = (entity as GameEntity).runtime_id
	# 确保存储已初始化
	if not _white_base.has(eid):
		_white_base[eid] = {}
	if not _white_growth.has(eid):
		_white_growth[eid] = {}
	if not _green_flat.has(eid):
		_green_flat[eid] = {}
	if not _green_percent.has(eid):
		_green_percent[eid] = {}
	return eid

func set_white_base(entity: Node3D, stat_name: String, value: float) -> void:
	## 设置白字基础值（初始属性）
	var eid := _ensure_eid(entity)
	if eid < 0:
		return
	_white_base[eid][stat_name] = value

func set_white_growth(entity: Node3D, stat_name: String, per_level: float) -> void:
	## 设置白字每级成长值
	var eid := _ensure_eid(entity)
	if eid < 0:
		return
	_white_growth[eid][stat_name] = per_level

func _notify_stat_changed(entity: Node3D, stat_name: String) -> void:
	## 属性变更通知（对标 TC Unit::UpdateStatBuffMod → UpdateAttackPowerAndDamage 等）
	## 所有依赖 stat 的组件通过此事件实时重算
	EventBus.emit_event("stat_changed", {
		"entity": entity,
		"stat": stat_name,
		"total": get_total_stat(entity, stat_name),
	})

func add_white_stat(entity: Node3D, stat_name: String, value: float) -> void:
	## 永久增加白字基础值（如永久属性药水）
	var eid := _ensure_eid(entity)
	if eid < 0:
		return
	_white_base[eid][stat_name] = _white_base[eid].get(stat_name, 0.0) + value
	_notify_stat_changed(entity, stat_name)

func add_green_stat(entity: Node3D, stat_name: String, value: float) -> void:
	## 增加绿字固定加成（装备/卡片/buff）
	var eid := _ensure_eid(entity)
	if eid < 0:
		return
	var old_val: float = _green_flat[eid].get(stat_name, 0.0)
	_green_flat[eid][stat_name] = old_val + value
	_notify_stat_changed(entity, stat_name)

func add_green_percent(entity: Node3D, stat_name: String, percent: float) -> void:
	## 增加绿字百分比加成（装备/卡片/buff）
	var eid := _ensure_eid(entity)
	if eid < 0:
		return
	var old_val: float = _green_percent[eid].get(stat_name, 0.0)
	_green_percent[eid][stat_name] = old_val + percent
	_notify_stat_changed(entity, stat_name)

func get_white_stat(entity: Node3D, stat_name: String, level: int = 1) -> float:
	## 返回白字属性值: white_base + white_growth * (level - 1)
	var eid := _ensure_eid(entity)
	if eid < 0:
		return 0.0
	var base_val: float = _white_base[eid].get(stat_name, 0.0)
	var growth_val: float = _white_growth[eid].get(stat_name, 0.0)
	return base_val + growth_val * maxf(level - 1, 0.0)

func get_green_stat(entity: Node3D, stat_name: String) -> float:
	## 返回绿字加成总值（仅 flat 部分，不含 percent）
	var eid := _ensure_eid(entity)
	if eid < 0:
		return 0.0
	return _green_flat[eid].get(stat_name, 0.0)

func get_green_percent_stat(entity: Node3D, stat_name: String) -> float:
	## 返回绿字百分比加成
	var eid := _ensure_eid(entity)
	if eid < 0:
		return 0.0
	return _green_percent[eid].get(stat_name, 0.0)

func get_total_stat(entity: Node3D, stat_name: String, level: int = 1) -> float:
	## 返回最终计算值: (white + green_flat) * (1 + green_percent)
	var eid := _ensure_eid(entity)
	if eid < 0:
		return 0.0
	var white: float = get_white_stat(entity, stat_name, level)
	var gf: float = _green_flat[eid].get(stat_name, 0.0)
	var gp: float = _green_percent[eid].get(stat_name, 0.0)
	return (white + gf) * (1.0 + gp)

func remove_green_stat(entity: Node3D, stat_name: String, value: float) -> void:
	## 移除绿字固定加成
	var eid := _ensure_eid(entity)
	if eid < 0:
		return
	_green_flat[eid][stat_name] = _green_flat[eid].get(stat_name, 0.0) - value
	_notify_stat_changed(entity, stat_name)

func remove_green_percent(entity: Node3D, stat_name: String, percent: float) -> void:
	## 移除绿字百分比加成
	var eid := _ensure_eid(entity)
	if eid < 0:
		return
	_green_percent[eid][stat_name] = _green_percent[eid].get(stat_name, 0.0) - percent
	_notify_stat_changed(entity, stat_name)

func clear_green_stats(entity: Node3D) -> void:
	## 清除实体所有绿字属性（重置装备/buff 加成）
	var eid := _ensure_eid(entity)
	if eid < 0:
		return
	_green_flat[eid].clear()
	_green_percent[eid].clear()
