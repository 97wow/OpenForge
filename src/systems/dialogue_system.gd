## DialogueSystem — NPC 对话系统（对标 TrinityCore GossipMenu / NpcText）
## JSON 数据驱动的对话树：节点 + 选项 + 条件分支 + Quest 集成
## 框架层系统，零游戏知识。GamePack 提供对话内容和 UI 表现
class_name DialogueSystem
extends Node

# === 对话状态 ===
enum State { IDLE = 0, ACTIVE = 1 }

var state: int = State.IDLE
var _current_dialogue_id: String = ""
var _current_node_id: String = ""
var _current_speaker = null  # GameEntity or null

# === 数据存储 ===
# 对话定义: dialogue_id -> DialogueDef
var _dialogues: Dictionary = {}

func _ready() -> void:
	EngineAPI.register_system("dialogue", self)

func _reset() -> void:
	state = State.IDLE
	_current_dialogue_id = ""
	_current_node_id = ""
	_current_speaker = null

# === 对话定义 API ===

func register_dialogue(dialogue_def: Dictionary) -> void:
	## dialogue_def: {
	##   "id": "blacksmith_greeting",
	##   "nodes": {
	##     "start": {
	##       "speaker_key": "NPC_BLACKSMITH",  # I18n key
	##       "text_key": "DIALOG_BLACKSMITH_GREETING",
	##       "options": [
	##         { "text_key": "DIALOG_OPT_SHOP", "next": "shop", "condition": {} },
	##         { "text_key": "DIALOG_OPT_QUEST", "next": "quest_offer",
	##           "condition": { "type": "quest_available", "quest_id": "forge_sword" } },
	##         { "text_key": "DIALOG_OPT_BYE", "action": "close" },
	##       ],
	##       "on_enter": [],  # 进入此节点时执行的动作
	##     },
	##     "shop": { "text_key": "...", "action": "open_shop", "action_data": {"shop_id": "blacksmith"} },
	##     "quest_offer": { "text_key": "...", "options": [...] },
	##   }
	## }
	var did: String = dialogue_def.get("id", "")
	if did != "":
		_dialogues[did] = dialogue_def

func load_dialogues_from_directory(dir_path: String) -> int:
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
					register_dialogue(json.data)
					count += 1
		file_name = dir.get_next()
	if count > 0:
		print("[DialogueSystem] Loaded %d dialogues" % count)
	return count

# === 对话控制 API ===

func start_dialogue(dialogue_id: String, speaker: Node3D = null, start_node: String = "start") -> bool:
	## 开始对话
	var def: Dictionary = _dialogues.get(dialogue_id, {})
	if def.is_empty():
		return false
	var nodes: Dictionary = def.get("nodes", {})
	if not nodes.has(start_node):
		return false
	state = State.ACTIVE
	_current_dialogue_id = dialogue_id
	_current_speaker = speaker
	_navigate_to(start_node)
	EventBus.emit_event("dialogue_started", {
		"dialogue_id": dialogue_id, "speaker": speaker,
	})
	return true

func select_option(option_index: int) -> void:
	## 玩家选择一个选项
	if state != State.ACTIVE:
		return
	var node: Dictionary = _get_current_node()
	if node.is_empty():
		return
	var options: Array = _get_available_options(node)
	if option_index < 0 or option_index >= options.size():
		return
	var option: Dictionary = options[option_index]
	EventBus.emit_event("dialogue_option_selected", {
		"dialogue_id": _current_dialogue_id,
		"node_id": _current_node_id,
		"option_index": option_index,
		"option": option,
	})
	# 执行选项动作
	var action: String = option.get("action", "")
	if action == "close":
		end_dialogue()
		return
	if action != "":
		_execute_action(action, option.get("action_data", {}))
	# 导航到下一个节点
	var next_node: String = option.get("next", "")
	if next_node != "":
		_navigate_to(next_node)
	else:
		end_dialogue()

func end_dialogue() -> void:
	if state == State.IDLE:
		return
	state = State.IDLE
	EventBus.emit_event("dialogue_ended", {
		"dialogue_id": _current_dialogue_id,
		"speaker": _current_speaker,
	})
	_current_dialogue_id = ""
	_current_node_id = ""
	_current_speaker = null

func is_in_dialogue() -> bool:
	return state == State.ACTIVE

# === NPC 头顶指示图标（对标 TC QuestGiverStatus）===

func get_npc_indicator(npc: GameEntity) -> String:
	## 获取 NPC 头顶应显示的图标类型
	## 返回: "quest_available" / "quest_turn_in" / "quest_in_progress" / "gossip" / "none"
	if not is_instance_valid(npc):
		return "none"
	var npc_id: String = npc.def_id
	var quest_sys: Node = EngineAPI.get_system("quest")
	if quest_sys:
		# 检查该 NPC 是否有可交付的任务
		for qid in quest_sys._quest_defs:
			var qdef: Dictionary = quest_sys._quest_defs[qid]
			if qdef.get("turn_in_npc", "") == npc_id:
				var state_val: int = quest_sys.call("get_quest_state", "player", qid)
				if state_val == 3:  # COMPLETE
					return "quest_turn_in"
				elif state_val == 2:  # IN_PROGRESS
					return "quest_in_progress"
		# 检查该 NPC 是否有可接取的任务
		for qid in quest_sys._quest_defs:
			var qdef: Dictionary = quest_sys._quest_defs[qid]
			if qdef.get("quest_giver", "") == npc_id:
				if quest_sys.call("can_accept", "player", qid):
					return "quest_available"
	# 有对话内容
	var dialogue_id: String = npc.get_meta_value("dialogue_id", "")
	if dialogue_id != "" and _dialogues.has(dialogue_id):
		return "gossip"
	return "none"

# === 多页文本支持 ===

var _current_page: int = 0
var _current_pages: Array = []  # [text_key, ...]

func get_current_page() -> int:
	return _current_page

func get_total_pages() -> int:
	return _current_pages.size()

func next_page() -> bool:
	## 翻到下一页，返回是否还有下一页
	if _current_page < _current_pages.size() - 1:
		_current_page += 1
		EventBus.emit_event("dialogue_page_changed", {
			"page": _current_page,
			"text_key": _current_pages[_current_page],
		})
		return true
	return false  # 已是最后一页

# === 查询 API ===

func get_current_node() -> Dictionary:
	## 获取当前对话节点（UI 读取用）
	var node: Dictionary = _get_current_node()
	if node.is_empty():
		return {}
	return {
		"dialogue_id": _current_dialogue_id,
		"node_id": _current_node_id,
		"speaker_key": node.get("speaker_key", ""),
		"text_key": node.get("text_key", ""),
		"options": _get_available_options(node),
		"speaker": _current_speaker,
	}

func get_dialogue_def(dialogue_id: String) -> Dictionary:
	return _dialogues.get(dialogue_id, {})

func has_dialogue(dialogue_id: String) -> bool:
	return _dialogues.has(dialogue_id)

# === 内部 ===

func _navigate_to(node_id: String) -> void:
	_current_node_id = node_id
	var node: Dictionary = _get_current_node()
	if node.is_empty():
		end_dialogue()
		return
	# 多页文本支持：优先使用 text_keys 数组，回退到单个 text_key
	var text_keys: Array = node.get("text_keys", [])
	if text_keys.is_empty() and node.has("text_key"):
		text_keys = [node.get("text_key", "")]
	_current_pages = text_keys
	_current_page = 0
	# 执行 on_enter 动作
	for action_def in node.get("on_enter", []):
		if action_def is Dictionary:
			_execute_action(action_def.get("action", ""), action_def.get("data", {}))
	# 节点级别动作（无选项的自动执行节点）
	var node_action: String = node.get("action", "")
	if node_action != "" and node.get("options", []).is_empty():
		_execute_action(node_action, node.get("action_data", {}))
	EventBus.emit_event("dialogue_node_entered", {
		"dialogue_id": _current_dialogue_id,
		"node_id": node_id,
		"text_key": text_keys[0] if text_keys.size() > 0 else "",
		"text_keys": text_keys,
		"total_pages": text_keys.size(),
		"options": _get_available_options(node),
		"speaker": _current_speaker,
	})

func _get_current_node() -> Dictionary:
	var def: Dictionary = _dialogues.get(_current_dialogue_id, {})
	return def.get("nodes", {}).get(_current_node_id, {})

func _get_available_options(node: Dictionary) -> Array:
	## 过滤条件不满足的选项
	var all_options: Array = node.get("options", [])
	var available: Array = []
	for opt in all_options:
		if not opt is Dictionary:
			continue
		var condition: Dictionary = opt.get("condition", {})
		if condition.is_empty() or _check_condition(condition):
			available.append(opt)
	return available

func _check_condition(condition: Dictionary) -> bool:
	## 检查对话选项条件
	var cond_type: String = condition.get("type", "")
	match cond_type:
		"quest_available":
			var quest_sys: Node = EngineAPI.get_system("quest")
			if quest_sys:
				return quest_sys.call("can_accept", "player", condition.get("quest_id", ""))
			return false
		"quest_state":
			var quest_sys: Node = EngineAPI.get_system("quest")
			if quest_sys:
				var state_val: int = quest_sys.call("get_quest_state", "player", condition.get("quest_id", ""))
				return state_val == condition.get("state", 0)
			return false
		"has_item":
			var items: Array = EngineAPI.inventory_get(
				EngineAPI.find_entities_by_tag("hero")[0] if EngineAPI.find_entities_by_tag("hero").size() > 0 else null)
			for item in items:
				if item.get("item_id", "") == condition.get("item_id", ""):
					return true
			return false
		"variable":
			return EngineAPI.get_variable(condition.get("key", "")) == condition.get("value")
		"level_min":
			var level_sys: Node = EngineAPI.get_system("level")
			if level_sys:
				var heroes: Array = EngineAPI.find_entities_by_tag("hero")
				if heroes.size() > 0 and is_instance_valid(heroes[0]):
					return level_sys.call("get_level", heroes[0]) >= condition.get("level", 1)
			return false
		"reputation_min":
			var faction_sys: Node = EngineAPI.get_system("faction")
			if faction_sys:
				return faction_sys.call("get_reputation", "player", condition.get("faction", "")) >= condition.get("amount", 0)
			return false
		_:
			return true

func _execute_action(action: String, data: Dictionary) -> void:
	## 执行对话动作（框架提供基础动作，GamePack 通过事件扩展）
	match action:
		"accept_quest":
			var quest_sys: Node = EngineAPI.get_system("quest")
			if quest_sys:
				quest_sys.call("accept_quest", "player", data.get("quest_id", ""))
		"turn_in_quest":
			var quest_sys: Node = EngineAPI.get_system("quest")
			if quest_sys:
				quest_sys.call("turn_in_quest", "player", data.get("quest_id", ""), data.get("reward_choice", -1))
		"give_item":
			var item_sys: Node = EngineAPI.get_system("item")
			if item_sys:
				var item: Dictionary = item_sys.call("create_item_instance", data.get("item_id", ""))
				if not item.is_empty():
					var heroes: Array = EngineAPI.find_entities_by_tag("hero")
					if heroes.size() > 0:
						item_sys.call("inventory_add", heroes[0], item)
		"add_resource":
			EngineAPI.add_resource(data.get("resource", "gold"), data.get("amount", 0))
		"set_variable":
			EngineAPI.set_variable(data.get("key", ""), data.get("value"))
		"emit_event":
			EventBus.emit_event(data.get("event", ""), data.get("event_data", {}))
		"close":
			end_dialogue()
		_:
			# 未知动作 → emit 事件让 GamePack 处理
			EventBus.emit_event("dialogue_action", {
				"action": action, "data": data,
				"dialogue_id": _current_dialogue_id,
				"speaker": _current_speaker,
			})
