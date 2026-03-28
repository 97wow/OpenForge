## CardManager - 卡片抽取/套装/效果管理
## 升级时3选1，最多6张，套装集齐转化永久能力释放卡位
class_name RogueCardManager
extends RefCounted

const MAX_CARDS := 6

var _all_cards: Dictionary = {}    # card_id -> card_data
var _all_sets: Array = []          # set definitions
var _held_cards: Array[String] = [] # 当前持有的 card_id
var _completed_sets: Array[String] = [] # 已完成的套装 id
var _hero_class: String = "warrior"
var _rng := RandomNumberGenerator.new()

func init(cards_dir: String, sets_path: String, hero_class: String) -> void:
	_hero_class = hero_class
	_rng.randomize()

	# 加载卡片
	var dir := DirAccess.open(cards_dir)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var file := FileAccess.open(cards_dir.path_join(file_name), FileAccess.READ)
				if file:
					var json := JSON.new()
					if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
						var card: Dictionary = json.data
						_all_cards[card.get("id", "")] = card
			file_name = dir.get_next()

	# 加载套装
	if FileAccess.file_exists(sets_path):
		var file := FileAccess.open(sets_path, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Array:
				_all_sets = json.data

	print("[CardManager] Loaded %d cards, %d sets" % [_all_cards.size(), _all_sets.size()])

# === 抽卡（3选1）===

func draw_three() -> Array[Dictionary]:
	## 返回3张候选卡片，职业亲和的权重x2
	var pool: Array[Dictionary] = []
	for card_id in _all_cards:
		var card: Dictionary = _all_cards[card_id]
		if card_id in _held_cards:
			continue  # 已持有不重复抽
		if not _is_card_unlocked(card_id):
			continue  # 前置卡未持有，不进入池
		var weight := 1
		var affinity: Array = card.get("class_affinity", ["all"])
		if _hero_class in affinity or "all" in affinity:
			weight = 2
		for i in range(weight):
			pool.append(card)

	if pool.is_empty():
		return []

	# 随机选3张不重复
	var result: Array[Dictionary] = []
	var picked_ids: Array[String] = []
	for i in range(mini(3, pool.size())):
		var attempts := 0
		while attempts < 50:
			var idx := _rng.randi() % pool.size()
			var card: Dictionary = pool[idx]
			var cid: String = card.get("id", "")
			if cid not in picked_ids:
				picked_ids.append(cid)
				result.append(card)
				break
			attempts += 1
	return result

# === 选择卡片 ===

func select_card(card_id: String) -> Dictionary:
	## 选择一张卡片，返回 { "added": true/false, "set_completed": "set_id"/""  }
	if card_id in _held_cards:
		return {"added": false, "set_completed": ""}
	if _held_cards.size() >= MAX_CARDS:
		return {"added": false, "set_completed": ""}

	_held_cards.append(card_id)

	# 检查套装完成
	var completed_set := _check_set_completion(card_id)
	if completed_set != "":
		# 移除套装卡片，释放卡位
		var set_def := _get_set_def(completed_set)
		if set_def:
			for cid in set_def.get("cards", []):
				_held_cards.erase(cid)
			_completed_sets.append(completed_set)
		return {"added": true, "set_completed": completed_set}

	return {"added": true, "set_completed": ""}

func _is_card_unlocked(card_id: String) -> bool:
	## 检查前置条件：同套装中排在前面的卡必须已持有或套装已完成
	var card: Dictionary = _all_cards.get(card_id, {})
	var set_id: String = card.get("set_id", "")
	if set_id == "":
		return true  # 无套装归属，直接可抽
	if set_id in _completed_sets:
		return false  # 套装已完成，不再出现
	# 找到该套装的卡片顺序
	var set_def := _get_set_def(set_id)
	if set_def.is_empty():
		return true
	var set_cards: Array = set_def.get("cards", [])
	var card_index := set_cards.find(card_id)
	if card_index <= 0:
		return true  # 第一张卡或找不到，直接可抽
	# 前一张卡必须已持有
	var prev_card_id: String = set_cards[card_index - 1]
	return prev_card_id in _held_cards

func _check_set_completion(card_id: String) -> String:
	for set_def in _all_sets:
		var set_cards: Array = set_def.get("cards", [])
		if card_id not in set_cards:
			continue
		var all_held := true
		for cid in set_cards:
			if cid not in _held_cards:
				all_held = false
				break
		if all_held:
			return set_def.get("id", "")
	return ""

func _get_set_def(set_id: String) -> Dictionary:
	for s in _all_sets:
		if s.get("id", "") == set_id:
			return s
	return {}

# === 查询 ===

func get_held_cards() -> Array[String]:
	return _held_cards

func get_held_card_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cid in _held_cards:
		if _all_cards.has(cid):
			result.append(_all_cards[cid])
	return result

func get_completed_sets() -> Array[String]:
	return _completed_sets

func get_card_count() -> int:
	return _held_cards.size()

func get_card_data(card_id: String) -> Dictionary:
	return _all_cards.get(card_id, {})

func get_set_data(set_id: String) -> Dictionary:
	return _get_set_def(set_id)

func is_full() -> bool:
	return _held_cards.size() >= MAX_CARDS
