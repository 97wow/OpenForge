## TriggerSystem - 事件-条件-动作 (ECA) 引擎
## UGC 逻辑创作的核心：通过 JSON 定义游戏逻辑
## GamePack 可注册自定义条件评估器和动作执行器
class_name TriggerSystem
extends Node

# trigger_id -> TriggerDef
var _triggers: Dictionary = {}
# event_name -> [trigger_ids] (索引，加速查找)
var _event_index: Dictionary = {}
# 自定义条件评估器: type_name -> Callable(condition_data, event_data) -> bool
var _condition_evaluators: Dictionary = {}
# 自定义动作执行器: type_name -> Callable(action_data, event_data) -> void
var _action_executors: Dictionary = {}

var _next_id: int = 1

func _ready() -> void:
	EngineAPI.register_system("trigger", self)
	_register_builtin_conditions()
	_register_builtin_actions()

# === 注册触发器 ===

func register_trigger(trigger_def: Dictionary) -> String:
	var trigger_id: String = trigger_def.get("id", "trigger_%d" % _next_id)
	_next_id += 1

	var event_name: String = trigger_def.get("event", "")
	if event_name == "":
		push_error("[TriggerSystem] Trigger '%s' has no event" % trigger_id)
		return ""

	_triggers[trigger_id] = {
		"id": trigger_id,
		"event": event_name,
		"conditions": trigger_def.get("conditions", []),
		"actions": trigger_def.get("actions", []),
		"enabled": trigger_def.get("enabled", true),
		"once": trigger_def.get("once", false),
		"fired_count": 0,
	}

	# 建立事件索引
	if not _event_index.has(event_name):
		_event_index[event_name] = []
		EventBus.connect_event(event_name, _on_event.bind(event_name))
	_event_index[event_name].append(trigger_id)

	return trigger_id

func unregister_trigger(trigger_id: String) -> void:
	if not _triggers.has(trigger_id):
		return
	var event_name: String = _triggers[trigger_id]["event"]
	_triggers.erase(trigger_id)
	if _event_index.has(event_name):
		_event_index[event_name].erase(trigger_id)

func enable_trigger(trigger_id: String) -> void:
	if _triggers.has(trigger_id):
		_triggers[trigger_id]["enabled"] = true

func disable_trigger(trigger_id: String) -> void:
	if _triggers.has(trigger_id):
		_triggers[trigger_id]["enabled"] = false

func load_triggers(trigger_array: Array) -> void:
	for trigger_def in trigger_array:
		if trigger_def is Dictionary:
			register_trigger(trigger_def)

# === 事件处理 ===

func _on_event(event_data: Dictionary, event_name: String) -> void:
	if not _event_index.has(event_name):
		return
	var trigger_ids := _event_index[event_name].duplicate() as Array
	for trigger_id in trigger_ids:
		if not _triggers.has(trigger_id):
			continue
		var trigger: Dictionary = _triggers[trigger_id]
		if not trigger["enabled"]:
			continue
		if trigger["once"] and trigger["fired_count"] > 0:
			continue
		if _evaluate_conditions(trigger["conditions"], event_data):
			_execute_actions(trigger["actions"], event_data)
			trigger["fired_count"] += 1
			EventBus.emit_event("trigger_fired", {
				"trigger_id": trigger_id,
				"event_name": event_name,
			})

# === 条件评估 ===

func _evaluate_conditions(conditions: Array, event_data: Dictionary) -> bool:
	for condition in conditions:
		if not condition is Dictionary:
			continue
		if not _evaluate_single_condition(condition, event_data):
			return false
	return true  # 所有条件都满足（AND 逻辑）

func _evaluate_single_condition(condition: Dictionary, event_data: Dictionary) -> bool:
	var type: String = condition.get("type", "")
	if _condition_evaluators.has(type):
		return _condition_evaluators[type].call(condition, event_data)
	push_warning("[TriggerSystem] Unknown condition type: %s" % type)
	return false

# === 动作执行 ===

func _execute_actions(actions: Array, event_data: Dictionary) -> void:
	for action in actions:
		if not action is Dictionary:
			continue
		_execute_single_action(action, event_data)

func _execute_single_action(action: Dictionary, event_data: Dictionary) -> void:
	var type: String = action.get("type", "")
	if _action_executors.has(type):
		_action_executors[type].call(action, event_data)
	else:
		push_warning("[TriggerSystem] Unknown action type: %s" % type)

# === 扩展点 ===

func register_condition_evaluator(type: String, evaluator: Callable) -> void:
	_condition_evaluators[type] = evaluator

func register_action_executor(type: String, executor: Callable) -> void:
	_action_executors[type] = executor

# === 值解析（支持 $event.xxx 引用）===

func resolve_value(value: Variant, event_data: Dictionary) -> Variant:
	if value is String and value.begins_with("$event."):
		return _resolve_path(value.substr(7), event_data)
	return value

func _resolve_path(path: String, data: Variant) -> Variant:
	var parts := path.split(".")
	var current: Variant = data
	for part in parts:
		if current is Dictionary and current.has(part):
			current = current[part]
		elif current is Object and current.has_method("get_" + part):
			current = current.call("get_" + part)
		elif current is Object and part == "meta" and current.has_method("get_meta_value"):
			continue  # 下一层会处理
		elif current is Node2D and current.has_method("get_component"):
			var comp = current.call("get_component", part)
			if comp != null:
				current = comp
			else:
				return null
		else:
			return null
	return current

# === 内置条件 ===

func _register_builtin_conditions() -> void:
	register_condition_evaluator("has_tag", _cond_has_tag)
	register_condition_evaluator("compare_resource", _cond_compare_resource)
	register_condition_evaluator("check_variable", _cond_check_variable)
	register_condition_evaluator("is_game_state", _cond_is_game_state)
	register_condition_evaluator("has_component", _cond_has_component)
	register_condition_evaluator("and", _cond_and)
	register_condition_evaluator("or", _cond_or)
	register_condition_evaluator("not", _cond_not)

func _cond_has_tag(cond: Dictionary, event_data: Dictionary) -> bool:
	var entity = resolve_value(cond.get("entity", ""), event_data)
	var tag: String = cond.get("tag", "")
	if entity is Node2D and entity.has_method("has_tag"):
		return entity.call("has_tag", tag)
	return false

func _cond_compare_resource(cond: Dictionary, event_data: Dictionary) -> bool:
	var res_name: String = cond.get("resource", "")
	var op: String = cond.get("op", "==")
	var value = resolve_value(cond.get("value", 0), event_data)
	var current := EngineAPI.get_resource(res_name)
	return _compare(current, op, float(value))

func _cond_check_variable(cond: Dictionary, event_data: Dictionary) -> bool:
	var key: String = cond.get("key", "")
	var op: String = cond.get("op", "==")
	var value = resolve_value(cond.get("value", null), event_data)
	var current = EngineAPI.get_variable(key)
	if current is float or current is int:
		return _compare(float(current), op, float(value))
	return str(current) == str(value)

func _cond_is_game_state(cond: Dictionary, _event_data: Dictionary) -> bool:
	return EngineAPI.get_game_state() == cond.get("state", "")

func _cond_has_component(cond: Dictionary, event_data: Dictionary) -> bool:
	var entity = resolve_value(cond.get("entity", ""), event_data)
	var comp_name: String = cond.get("component", "")
	if entity is Node2D and entity.has_method("has_component"):
		return entity.call("has_component", comp_name)
	return false

func _cond_and(cond: Dictionary, event_data: Dictionary) -> bool:
	var sub_conditions: Array = cond.get("conditions", [])
	return _evaluate_conditions(sub_conditions, event_data)

func _cond_or(cond: Dictionary, event_data: Dictionary) -> bool:
	var sub_conditions: Array = cond.get("conditions", [])
	for sub in sub_conditions:
		if sub is Dictionary and _evaluate_single_condition(sub, event_data):
			return true
	return false

func _cond_not(cond: Dictionary, event_data: Dictionary) -> bool:
	var sub: Dictionary = cond.get("condition", {})
	return not _evaluate_single_condition(sub, event_data)

func _compare(a: float, op: String, b: float) -> bool:
	match op:
		"==": return is_equal_approx(a, b)
		"!=": return not is_equal_approx(a, b)
		">": return a > b
		">=": return a >= b
		"<": return a < b
		"<=": return a <= b
	return false

# === 内置动作 ===

func _register_builtin_actions() -> void:
	register_action_executor("spawn_entity", _act_spawn_entity)
	register_action_executor("destroy_entity", _act_destroy_entity)
	register_action_executor("add_resource", _act_add_resource)
	register_action_executor("subtract_resource", _act_subtract_resource)
	register_action_executor("set_resource", _act_set_resource)
	register_action_executor("set_variable", _act_set_variable)
	register_action_executor("emit_event", _act_emit_event)
	register_action_executor("set_game_state", _act_set_game_state)
	register_action_executor("apply_buff", _act_apply_buff)
	register_action_executor("remove_buff", _act_remove_buff)
	register_action_executor("show_message", _act_show_message)
	register_action_executor("log", _act_log)

func _act_spawn_entity(action: Dictionary, event_data: Dictionary) -> void:
	var def_id = resolve_value(action.get("entity_id", ""), event_data)
	var pos_data = action.get("position", {})
	var pos := Vector2(
		float(resolve_value(pos_data.get("x", 0), event_data)),
		float(resolve_value(pos_data.get("y", 0), event_data))
	)
	EngineAPI.spawn_entity(str(def_id), pos)

func _act_destroy_entity(action: Dictionary, event_data: Dictionary) -> void:
	var entity = resolve_value(action.get("entity", ""), event_data)
	if entity is Node2D:
		EngineAPI.destroy_entity(entity)

func _act_add_resource(action: Dictionary, event_data: Dictionary) -> void:
	var name: String = action.get("resource", "")
	var amount = resolve_value(action.get("amount", 0), event_data)
	EngineAPI.add_resource(name, float(amount))

func _act_subtract_resource(action: Dictionary, event_data: Dictionary) -> void:
	var name: String = action.get("resource", "")
	var amount = resolve_value(action.get("amount", 0), event_data)
	EngineAPI.subtract_resource(name, float(amount))

func _act_set_resource(action: Dictionary, event_data: Dictionary) -> void:
	var name: String = action.get("resource", "")
	var value = resolve_value(action.get("value", 0), event_data)
	EngineAPI.set_resource(name, float(value))

func _act_set_variable(action: Dictionary, event_data: Dictionary) -> void:
	var key: String = action.get("key", "")
	var value = resolve_value(action.get("value", null), event_data)
	EngineAPI.set_variable(key, value)

func _act_emit_event(action: Dictionary, event_data: Dictionary) -> void:
	var event_name: String = action.get("event", "")
	var data: Dictionary = action.get("data", {})
	# 解析 data 中的引用
	var resolved_data: Dictionary = {}
	for key in data:
		resolved_data[key] = resolve_value(data[key], event_data)
	EngineAPI.emit_event(event_name, resolved_data)

func _act_set_game_state(action: Dictionary, _event_data: Dictionary) -> void:
	var state: String = action.get("state", "")
	EngineAPI.set_game_state(state)

func _act_apply_buff(action: Dictionary, event_data: Dictionary) -> void:
	var entity = resolve_value(action.get("entity", ""), event_data)
	if entity is Node2D:
		EngineAPI.apply_buff(
			entity,
			action.get("buff_id", ""),
			float(action.get("duration", 5.0)),
			action.get("data", {})
		)

func _act_remove_buff(action: Dictionary, event_data: Dictionary) -> void:
	var entity = resolve_value(action.get("entity", ""), event_data)
	if entity is Node2D:
		EngineAPI.remove_buff(entity, action.get("buff_id", ""))

func _act_show_message(action: Dictionary, event_data: Dictionary) -> void:
	var text = resolve_value(action.get("text", ""), event_data)
	var duration: float = action.get("duration", 3.0)
	EngineAPI.show_message(str(text), duration)

func _act_log(action: Dictionary, event_data: Dictionary) -> void:
	var message = resolve_value(action.get("message", ""), event_data)
	print("[Trigger] %s" % str(message))
