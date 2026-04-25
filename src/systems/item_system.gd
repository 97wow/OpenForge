## ItemSystem - 物品/装备/掉落系统（框架层，对标 TrinityCore LootMgr）
## 支持：概率组（权重池）、条件掉落、多Roll模式（保底+奖励骰）
## 物品定义、掉落表、词条随机、装备管理
## GamePack 可注册自定义词条池和掉落规则
class_name ItemSystem
extends Node

# === 数据存储 ===
var _item_defs: Dictionary = {}      # item_id -> item定义
var _loot_tables: Dictionary = {}    # loot_table_id -> 掉落表
var _affix_pools: Dictionary = {}    # pool_id -> [affix定义]
var _inventories: Dictionary = {}    # entity_id -> [ItemInstance]
var _equipped: Dictionary = {}       # entity_id -> {slot -> ItemInstance}
var _inventory_caps: Dictionary = {} # entity_id -> int (capacity)
var _rng := RandomNumberGenerator.new()

const DEFAULT_INVENTORY_CAPACITY := 20

# 装备槽位
const EQUIP_SLOTS := ["weapon", "armor", "accessory_1", "accessory_2", "accessory_3", "accessory_4"]
const MAX_AFFIXES := 3

# 稀有度颜色
const RARITY_COLORS := {
	"common": Color(0.7, 0.7, 0.7),
	"uncommon": Color(0.3, 0.85, 0.3),
	"rare": Color(0.3, 0.5, 1.0),
	"epic": Color(0.65, 0.3, 0.9),
	"legendary": Color(1.0, 0.6, 0.15),
}

func _ready() -> void:
	EngineAPI.register_system("item", self)
	_rng.randomize()

func _reset() -> void:
	_item_defs.clear()
	_loot_tables.clear()
	_affix_pools.clear()
	_inventories.clear()
	_equipped.clear()
	_inventory_caps.clear()

# === 数据加载 ===

func load_items_from_directory(dir_path: String) -> int:
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
					var item: Dictionary = json.data
					var item_id: String = item.get("id", "")
					if item_id != "":
						_item_defs[item_id] = item
						count += 1
		file_name = dir.get_next()
	if count > 0:
		print("[ItemSystem] Loaded %d item definitions" % count)
	return count

func load_loot_tables(dir_path: String) -> int:
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
					var table: Dictionary = json.data
					var table_id: String = table.get("id", "")
					if table_id != "":
						_loot_tables[table_id] = table
						count += 1
		file_name = dir.get_next()
	if count > 0:
		print("[ItemSystem] Loaded %d loot tables" % count)
	return count

func load_affix_pool(pool_id: String, affixes: Array) -> void:
	_affix_pools[pool_id] = affixes

func register_item(item_id: String, item_def: Dictionary) -> void:
	_item_defs[item_id] = item_def

# === 掉落生成（对标 TC LootMgr）===
#
# 掉落表 JSON 格式（新版，向后兼容旧 entries）:
# {
#   "id": "boss_loot",
#   "rolls": [                          # 多 Roll 模式
#     {
#       "guaranteed": true,             # 保底 roll（必出1件）
#       "count": 1,                     # 本次 roll 出几件
#       "entries": [                    # 概率组（权重池，从中抽 count 件）
#         { "item_id": "sword_epic", "weight": 10 },
#         { "item_id": "staff_epic", "weight": 10 },
#         { "item_id": "random_rare", "weight": 30 },
#         { "item_id": "gold_coin", "weight": 50, "min": 10, "max": 30 }
#       ]
#     },
#     {
#       "guaranteed": false,
#       "chance": 0.3,                  # 奖励 roll（30% 触发）
#       "count": 1,
#       "entries": [
#         { "item_id": "random_epic", "weight": 20 },
#         { "item_id": "random_legendary", "weight": 5 }
#       ],
#       "condition": { "min_difficulty": 5 }  # 条件掉落
#     }
#   ],
#   "entries": [...]                    # 向后兼容：旧格式（独立概率 entry）
# }

## 自定义条件检查回调：GamePack 注册 condition_type -> Callable(condition, context) -> bool
var _condition_checkers: Dictionary = {}

func register_loot_condition(condition_type: String, checker: Callable) -> void:
	## 注册自定义掉落条件检查器
	_condition_checkers[condition_type] = checker

func roll_loot(loot_table_id: String, luck_bonus: float = 0.0, context: Dictionary = {}) -> Array[Dictionary]:
	## 根据掉落表随机生成物品实例列表
	## context: 条件上下文 { "difficulty": 5, "killer_level": 10, "boss_phase": 2, ... }
	var table: Dictionary = _loot_tables.get(loot_table_id, {})
	if table.is_empty():
		return []
	var results: Array[Dictionary] = []

	# 新版：多 Roll 模式
	var rolls: Array = table.get("rolls", [])
	if not rolls.is_empty():
		for roll in rolls:
			if not roll is Dictionary:
				continue
			# 条件检查
			var condition: Dictionary = roll.get("condition", {})
			if not condition.is_empty() and not _check_loot_condition(condition, context):
				continue
			# 触发检查
			var guaranteed: bool = roll.get("guaranteed", false)
			if not guaranteed:
				var roll_chance: float = roll.get("chance", 1.0) + luck_bonus
				if _rng.randf() > roll_chance:
					continue
			# 从概率组中抽取
			var roll_count: int = roll.get("count", 1)
			var roll_entries: Array = roll.get("entries", [])
			var picked: Array = _pick_from_weighted_pool(roll_entries, roll_count)
			for entry in picked:
				var item: Dictionary = _resolve_entry(entry)
				if not item.is_empty():
					results.append(item)
		return results

	# 向后兼容：旧版独立概率 entries
	var entries: Array = table.get("entries", [])
	for entry in entries:
		if not entry is Dictionary:
			continue
		# 条件检查
		var condition: Dictionary = entry.get("condition", {})
		if not condition.is_empty() and not _check_loot_condition(condition, context):
			continue
		var chance: float = entry.get("chance", 0.0) + luck_bonus
		if _rng.randf() > chance:
			continue
		var item: Dictionary = _resolve_entry(entry)
		if not item.is_empty():
			results.append(item)
	return results

func _pick_from_weighted_pool(entries: Array, count: int) -> Array:
	## 从权重池中按权重抽取 count 个（不重复）
	if entries.is_empty() or count <= 0:
		return []
	# 计算总权重
	var total_weight := 0.0
	var pool: Array = []
	for entry in entries:
		if not entry is Dictionary:
			continue
		var w: float = entry.get("weight", 1.0)
		total_weight += w
		pool.append({"entry": entry, "weight": w})
	if pool.is_empty() or total_weight <= 0:
		return []
	var picked: Array = []
	var remaining_pool: Array = pool.duplicate(true)
	for _i in range(mini(count, remaining_pool.size())):
		# 权重随机选择
		var remaining_weight := 0.0
		for p in remaining_pool:
			remaining_weight += p["weight"]
		var roll: float = _rng.randf() * remaining_weight
		var cumulative := 0.0
		var pick_idx := 0
		for j in range(remaining_pool.size()):
			cumulative += remaining_pool[j]["weight"]
			if roll <= cumulative:
				pick_idx = j
				break
		picked.append(remaining_pool[pick_idx]["entry"])
		remaining_pool.remove_at(pick_idx)
		if remaining_pool.is_empty():
			break
	return picked

func _resolve_entry(entry: Dictionary) -> Dictionary:
	## 将掉落表 entry 解析为物品实例
	var item_id: String = entry.get("item_id", "")
	if item_id.begins_with("random_"):
		var rarity: String = item_id.substr(7)
		return _generate_random_item(rarity)
	elif item_id == "gold_coin":
		var min_gold: int = entry.get("min", 1)
		var max_gold: int = entry.get("max", 5)
		return {"type": "currency", "currency": "gold", "amount": _rng.randi_range(min_gold, max_gold)}
	elif item_id != "":
		return create_item_instance(item_id)
	return {}

func _check_loot_condition(condition: Dictionary, context: Dictionary) -> bool:
	## 检查掉落条件是否满足
	for key in condition:
		match key:
			"min_difficulty":
				if context.get("difficulty", 0) < condition[key]:
					return false
			"max_difficulty":
				if context.get("difficulty", 999) > condition[key]:
					return false
			"min_level":
				if context.get("killer_level", 0) < condition[key]:
					return false
			"boss_phase":
				if context.get("boss_phase", 0) != condition[key]:
					return false
			"variable":
				# 检查 EngineAPI 变量
				var var_cond: Dictionary = condition[key]
				var var_key: String = var_cond.get("key", "")
				var expected = var_cond.get("value")
				if EngineAPI.get_variable(var_key) != expected:
					return false
			_:
				# 自定义条件检查器
				if _condition_checkers.has(key):
					if not _condition_checkers[key].call(condition[key], context):
						return false
	return true

func _generate_random_item(rarity: String) -> Dictionary:
	## 从该稀有度的所有物品中随机选一个
	var candidates: Array = []
	for item_id in _item_defs:
		var item: Dictionary = _item_defs[item_id]
		if item.get("rarity", "common") == rarity and item.get("type", "") != "consumable":
			candidates.append(item_id)
	if candidates.is_empty():
		return {}
	var picked: String = candidates[_rng.randi() % candidates.size()]
	return create_item_instance(picked)

# === 物品实例创建 ===

func create_item_instance(item_id: String, extra_affixes: int = 0) -> Dictionary:
	## 创建物品实例（带随机词条）
	var def: Dictionary = _item_defs.get(item_id, {})
	if def.is_empty():
		return {}
	var instance: Dictionary = {
		"type": "item",
		"item_id": item_id,
		"def": def,
		"affixes": [],
		"instance_id": _rng.randi(),
	}
	# 基础词条
	var base_affixes: Array = def.get("affixes", [])
	for affix in base_affixes:
		instance["affixes"].append(affix)
	# 额外随机词条
	var bonus_count: int = extra_affixes
	var rarity: String = def.get("rarity", "common")
	match rarity:
		"uncommon": bonus_count += 1
		"rare": bonus_count += 1
		"epic": bonus_count += 2
		"legendary": bonus_count += 2
	if bonus_count > 0:
		_roll_random_affixes(instance, bonus_count)
	return instance

func _roll_random_affixes(instance: Dictionary, count: int) -> void:
	var item_type: String = instance["def"].get("type", "weapon")
	var pool_id := "affix_" + item_type
	var pool: Array = _affix_pools.get(pool_id, _affix_pools.get("affix_default", []))
	if pool.is_empty():
		return
	var existing_stats: Array = []
	for a in instance["affixes"]:
		existing_stats.append(a.get("stat", ""))
	for _i in range(mini(count, MAX_AFFIXES - instance["affixes"].size())):
		var attempts := 0
		while attempts < 20:
			var affix: Dictionary = pool[_rng.randi() % pool.size()]
			var stat: String = affix.get("stat", "")
			if stat not in existing_stats:
				# 在范围内随机数值
				var min_val: float = affix.get("min", 0)
				var max_val: float = affix.get("max", 0)
				var value: float = _rng.randf_range(min_val, max_val)
				if affix.get("integer", false):
					value = float(int(value))
				instance["affixes"].append({"stat": stat, "value": value})
				existing_stats.append(stat)
				break
			attempts += 1

# === 装备管理 ===

func equip_item(entity: Node3D, slot: String, item_instance: Dictionary) -> Dictionary:
	## 装备物品，返回被替换的旧物品（如果有）
	if not is_instance_valid(entity):
		return {}
	var eid: int = entity.get_instance_id()
	if not _equipped.has(eid):
		_equipped[eid] = {}

	var old_item: Dictionary = {}
	if _equipped[eid].has(slot):
		old_item = _equipped[eid][slot]
		_unequip_effects(entity, old_item)

	_equipped[eid][slot] = item_instance
	_apply_equip_effects(entity, item_instance)

	EventBus.emit_event("item_equipped", {
		"entity": entity, "slot": slot, "item": item_instance
	})
	return old_item

func unequip_item(entity: Node3D, slot: String) -> Dictionary:
	if not is_instance_valid(entity):
		return {}
	var eid: int = entity.get_instance_id()
	if not _equipped.has(eid) or not _equipped[eid].has(slot):
		return {}
	var item: Dictionary = _equipped[eid][slot]
	_unequip_effects(entity, item)
	_equipped[eid].erase(slot)
	EventBus.emit_event("item_unequipped", {
		"entity": entity, "slot": slot, "item": item
	})
	return item

func get_equipped(entity: Node3D) -> Dictionary:
	if not is_instance_valid(entity):
		return {}
	return _equipped.get(entity.get_instance_id(), {})

func get_equipped_in_slot(entity: Node3D, slot: String) -> Dictionary:
	var equipped: Dictionary = get_equipped(entity)
	return equipped.get(slot, {})

# === 装备效果 ===

func _apply_equip_effects(entity: Node3D, item: Dictionary) -> void:
	var def: Dictionary = item.get("def", {})
	# 基础属性
	var base_stats: Dictionary = def.get("base_stats", {})
	for stat in base_stats:
		EngineAPI.set_variable("hero_" + stat,
			float(EngineAPI.get_variable("hero_" + stat, 0.0)) + float(base_stats[stat]))
	# 词条属性
	for affix in item.get("affixes", []):
		var stat: String = affix.get("stat", "")
		var value: float = affix.get("value", 0.0)
		EngineAPI.set_variable("hero_" + stat,
			float(EngineAPI.get_variable("hero_" + stat, 0.0)) + value)
	# 装备 spell
	var spell_on_equip: String = def.get("spell_on_equip", "")
	if spell_on_equip != "":
		EngineAPI.cast_spell(spell_on_equip, entity, entity)
	# 命中 spell (通过 proc)
	var spell_on_hit: String = def.get("spell_on_hit", "")
	if spell_on_hit != "":
		EngineAPI.cast_spell(spell_on_hit, entity, entity)

func _unequip_effects(_entity: Node3D, item: Dictionary) -> void:
	var def: Dictionary = item.get("def", {})
	var base_stats: Dictionary = def.get("base_stats", {})
	for stat in base_stats:
		EngineAPI.set_variable("hero_" + stat,
			float(EngineAPI.get_variable("hero_" + stat, 0.0)) - float(base_stats[stat]))
	for affix in item.get("affixes", []):
		var stat: String = affix.get("stat", "")
		var value: float = affix.get("value", 0.0)
		EngineAPI.set_variable("hero_" + stat,
			float(EngineAPI.get_variable("hero_" + stat, 0.0)) - value)

# === 背包 API ===

func init_inventory(entity: Node3D, capacity: int = DEFAULT_INVENTORY_CAPACITY) -> void:
	if not is_instance_valid(entity):
		return
	var eid: int = entity.get_instance_id()
	if not _inventories.has(eid):
		_inventories[eid] = []
	_inventory_caps[eid] = capacity

func inventory_add(entity: Node3D, item: Dictionary) -> bool:
	if not is_instance_valid(entity) or item.is_empty():
		return false
	var eid: int = entity.get_instance_id()
	if not _inventories.has(eid):
		_inventories[eid] = []
	var cap: int = _inventory_caps.get(eid, DEFAULT_INVENTORY_CAPACITY)
	if _inventories[eid].size() >= cap:
		EventBus.emit_event("inventory_full", {"entity": entity, "item": item})
		return false
	_inventories[eid].append(item)
	EventBus.emit_event("inventory_changed", {"entity": entity})
	return true

func inventory_remove(entity: Node3D, index: int) -> Dictionary:
	if not is_instance_valid(entity):
		return {}
	var eid: int = entity.get_instance_id()
	if not _inventories.has(eid) or index < 0 or index >= _inventories[eid].size():
		return {}
	var item: Dictionary = _inventories[eid][index]
	_inventories[eid].remove_at(index)
	EventBus.emit_event("inventory_changed", {"entity": entity})
	return item

func inventory_get(entity: Node3D) -> Array:
	if not is_instance_valid(entity):
		return []
	return _inventories.get(entity.get_instance_id(), []).duplicate()

func inventory_size(entity: Node3D) -> int:
	if not is_instance_valid(entity):
		return 0
	return _inventories.get(entity.get_instance_id(), []).size()

func inventory_capacity(entity: Node3D) -> int:
	if not is_instance_valid(entity):
		return 0
	return _inventory_caps.get(entity.get_instance_id(), DEFAULT_INVENTORY_CAPACITY)

func inventory_is_full(entity: Node3D) -> bool:
	return inventory_size(entity) >= inventory_capacity(entity)

func inventory_equip_from(entity: Node3D, inventory_idx: int, slot: String) -> bool:
	## 从背包装备：背包物品→装备栏，旧装备→背包
	if not is_instance_valid(entity):
		return false
	var eid: int = entity.get_instance_id()
	if not _inventories.has(eid) or inventory_idx < 0 or inventory_idx >= _inventories[eid].size():
		return false
	var item: Dictionary = _inventories[eid][inventory_idx]
	var old_equipped: Dictionary = equip_item(entity, slot, item)
	_inventories[eid].remove_at(inventory_idx)
	if not old_equipped.is_empty():
		_inventories[eid].append(old_equipped)
	EventBus.emit_event("inventory_changed", {"entity": entity})
	return true

func inventory_unequip_to(entity: Node3D, slot: String) -> bool:
	## 卸下装备到背包
	if not is_instance_valid(entity) or inventory_is_full(entity):
		return false
	var item: Dictionary = unequip_item(entity, slot)
	if item.is_empty():
		return false
	return inventory_add(entity, item)

# === 掉落物生成 ===

func spawn_loot_entity(item: Dictionary, pos: Vector3, lifetime: float = 30.0) -> Node3D:
	## 在地面位置生成掉落物实体
	var loot := LootEntity.new()
	loot.setup(item, lifetime)
	# 先加入场景树，再设置 global_position（避免 not_in_tree 错误）
	var entity_sys: Node = EngineAPI.get_system("entity")
	if entity_sys and is_instance_valid(entity_sys):
		entity_sys.add_child(loot)
	elif get_tree().current_scene:
		get_tree().current_scene.add_child(loot)
	loot.global_position = pos
	EventBus.emit_event("loot_entity_spawned", {"item": item, "position": pos, "loot_entity": loot})
	return loot

# === 套装检查 ===

func check_set_bonuses(entity: Node3D) -> Array[String]:
	## 检查当前装备的套装激活状态，返回激活的套装 ID
	var equipped: Dictionary = get_equipped(entity)
	var set_counts: Dictionary = {}  # set_id -> count
	for slot in equipped:
		var item: Dictionary = equipped[slot]
		var set_id: String = item.get("def", {}).get("set_id", "")
		if set_id != "":
			set_counts[set_id] = set_counts.get(set_id, 0) + 1
	var activated: Array[String] = []
	for set_id in set_counts:
		activated.append(set_id)
	return activated

# === 查询 ===

func get_item_def(item_id: String) -> Dictionary:
	return _item_defs.get(item_id, {})

func get_all_item_ids() -> Array[String]:
	var result: Array[String] = []
	for key in _item_defs:
		result.append(key)
	return result

func get_rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)

func get_item_display_name(item: Dictionary) -> String:
	var def: Dictionary = item.get("def", {})
	var name_key: String = def.get("name_key", def.get("id", "???"))
	return I18n.t(name_key)

func get_item_tooltip(item: Dictionary) -> String:
	var def: Dictionary = item.get("def", {})
	var lines: Array[String] = []
	lines.append(get_item_display_name(item))
	lines.append(I18n.t(def.get("rarity", "common").to_upper()))
	# 基础属性
	for stat in def.get("base_stats", {}):
		lines.append("+%s %s" % [str(def["base_stats"][stat]), stat])
	# 词条
	for affix in item.get("affixes", []):
		lines.append("+%.1f %s" % [affix.get("value", 0), affix.get("stat", "")])
	# 套装
	var set_id: String = def.get("set_id", "")
	if set_id != "":
		lines.append("[%s]" % I18n.t("SET_" + set_id.to_upper()))
	return "\n".join(lines)
