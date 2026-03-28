## ItemSystem - 物品/装备/掉落系统（框架层）
## 借鉴不思议作战 + 暗黑破坏神的装备系统
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
var _rng := RandomNumberGenerator.new()

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

# === 掉落生成 ===

func roll_loot(loot_table_id: String, luck_bonus: float = 0.0) -> Array[Dictionary]:
	## 根据掉落表随机生成物品实例列表
	var table: Dictionary = _loot_tables.get(loot_table_id, {})
	if table.is_empty():
		return []
	var results: Array[Dictionary] = []
	var entries: Array = table.get("entries", [])
	for entry in entries:
		if not entry is Dictionary:
			continue
		var chance: float = entry.get("chance", 0.0) + luck_bonus
		if _rng.randf() > chance:
			continue
		var item_id: String = entry.get("item_id", "")
		# 特殊标识：random_common, random_uncommon 等
		if item_id.begins_with("random_"):
			var rarity: String = item_id.substr(7)  # "random_rare" → "rare"
			var random_item: Dictionary = _generate_random_item(rarity)
			if not random_item.is_empty():
				results.append(random_item)
		elif item_id == "gold_coin":
			var min_gold: int = entry.get("min", 1)
			var max_gold: int = entry.get("max", 5)
			var gold: int = _rng.randi_range(min_gold, max_gold)
			results.append({"type": "currency", "currency": "gold", "amount": gold})
		else:
			var instance: Dictionary = create_item_instance(item_id)
			if not instance.is_empty():
				results.append(instance)
	return results

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

func equip_item(entity: Node2D, slot: String, item_instance: Dictionary) -> Dictionary:
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

func unequip_item(entity: Node2D, slot: String) -> Dictionary:
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

func get_equipped(entity: Node2D) -> Dictionary:
	if not is_instance_valid(entity):
		return {}
	return _equipped.get(entity.get_instance_id(), {})

func get_equipped_in_slot(entity: Node2D, slot: String) -> Dictionary:
	var equipped: Dictionary = get_equipped(entity)
	return equipped.get(slot, {})

# === 装备效果 ===

func _apply_equip_effects(entity: Node2D, item: Dictionary) -> void:
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

func _unequip_effects(entity: Node2D, item: Dictionary) -> void:
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

# === 套装检查 ===

func check_set_bonuses(entity: Node2D) -> Array[String]:
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
	return tr(name_key)

func get_item_tooltip(item: Dictionary) -> String:
	var def: Dictionary = item.get("def", {})
	var lines: Array[String] = []
	lines.append(get_item_display_name(item))
	lines.append(tr(def.get("rarity", "common").to_upper()))
	# 基础属性
	for stat in def.get("base_stats", {}):
		lines.append("+%s %s" % [str(def["base_stats"][stat]), stat])
	# 词条
	for affix in item.get("affixes", []):
		lines.append("+%.1f %s" % [affix.get("value", 0), affix.get("stat", "")])
	# 套装
	var set_id: String = def.get("set_id", "")
	if set_id != "":
		lines.append("[%s]" % tr("SET_" + set_id.to_upper()))
	return "\n".join(lines)
