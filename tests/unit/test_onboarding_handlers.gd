## 单元测试：Onboarding §A1 trigger handler（compare_event_value / check_save_flag /
## set_save_flag / show_toast），以及 onboarding.json 数据完整性。
extends GdUnitTestSuite

var _trig_sys: Node

func before_test() -> void:
	_trig_sys = auto_free(TriggerSystem.new()) as Node
	add_child(_trig_sys)
	# 清掉测试用 namespace，防跨 test 污染
	var save_sys: Node = get_node_or_null("/root/SaveSystem")
	if save_sys and save_sys.has_method("clear_namespace"):
		save_sys.call("clear_namespace", "test_onboarding_ns")

# === compare_event_value ===

func test_compare_event_value_numeric_eq() -> void:
	var cond := {"type": "compare_event_value", "path": "$event.wave", "op": "==", "value": 1}
	assert_bool(_trig_sys._cond_compare_event_value(cond, {"wave": 1})).is_true()
	assert_bool(_trig_sys._cond_compare_event_value(cond, {"wave": 2})).is_false()

func test_compare_event_value_missing_path_returns_false() -> void:
	## $event.foo 不存在时不应误判（null != 任何值）
	var cond := {"type": "compare_event_value", "path": "$event.foo", "op": "==", "value": 1}
	assert_bool(_trig_sys._cond_compare_event_value(cond, {"wave": 1})).is_false()

func test_compare_event_value_string_eq() -> void:
	var cond := {"type": "compare_event_value", "path": "$event.id", "op": "==", "value": "boss"}
	assert_bool(_trig_sys._cond_compare_event_value(cond, {"id": "boss"})).is_true()
	assert_bool(_trig_sys._cond_compare_event_value(cond, {"id": "minion"})).is_false()

# === check_save_flag / set_save_flag round-trip ===

func test_save_flag_roundtrip() -> void:
	## set 之前默认 null，check != true 应该成立（首次进入 onboarding 的语义）
	var check_cond := {"type": "check_save_flag", "namespace": "test_onboarding_ns",
		"key": "seen_welcome", "op": "!=", "value": true}
	assert_bool(_trig_sys._cond_check_save_flag(check_cond, {})).is_true()
	# 写 flag
	_trig_sys._act_set_save_flag({"namespace": "test_onboarding_ns", "key": "seen_welcome", "value": true}, {})
	# 现在 != true 应该 false
	assert_bool(_trig_sys._cond_check_save_flag(check_cond, {})).is_false()
	# == true 应该 true
	var eq_cond := check_cond.duplicate()
	eq_cond["op"] = "=="
	assert_bool(_trig_sys._cond_check_save_flag(eq_cond, {})).is_true()

# === show_toast：派 EventBus event ===

func test_show_toast_emits_ui_toast_event() -> void:
	var captured: Array = []
	var listener := func(data: Dictionary) -> void:
		captured.append(data)
	EventBus.connect_event("ui_toast", listener)
	_trig_sys._act_show_toast({
		"i18n_key": "TUTORIAL_WELCOME_MOVE",
		"color": "#66ccff",
		"duration": 5.0,
	}, {})
	EventBus.disconnect_event("ui_toast", listener)
	assert_int(captured.size()).is_equal(1)
	var ev: Dictionary = captured[0]
	assert_str(str(ev.get("i18n_key", ""))).is_equal("TUTORIAL_WELCOME_MOVE")
	assert_str(str(ev.get("color", ""))).is_equal("#66ccff")
	assert_float(float(ev.get("duration", 0.0))).is_equal(5.0)

# === onboarding.json 完整性 ===

func test_onboarding_json_parses_and_uses_registered_types() -> void:
	var path := "res://gamepacks/rogue_survivor/rules/onboarding.json"
	assert_bool(FileAccess.file_exists(path)).is_true()
	var json := JSON.new()
	var text: String = FileAccess.get_file_as_string(path)
	assert_int(json.parse(text)).is_equal(OK)
	var arr: Array = json.data
	assert_int(arr.size()).is_greater_equal(1)
	var registered_conds := ["has_tag", "compare_resource", "check_variable",
		"compare_event_value", "check_save_flag", "is_game_state",
		"has_component", "and", "or", "not"]
	var registered_acts := ["spawn_entity", "destroy_entity", "add_resource",
		"subtract_resource", "set_resource", "set_variable", "set_save_flag",
		"show_toast", "emit_event", "set_game_state", "apply_buff", "remove_buff",
		"show_message", "log"]
	for trig: Dictionary in arr:
		for cond: Dictionary in trig.get("conditions", []):
			assert_bool(cond.get("type", "") in registered_conds).is_true()
		for act: Dictionary in trig.get("actions", []):
			assert_bool(act.get("type", "") in registered_acts).is_true()

# === i18n key 完整性：4 国都得有 TUTORIAL_WELCOME_MOVE ===

func test_tutorial_keys_present_in_all_langs() -> void:
	var required_keys := [
		"TUTORIAL_WELCOME_MOVE",       # §A1
		"TUTORIAL_DRAFT_TITLE",        # §A2
		"TUTORIAL_DRAFT_RARITY",       # §A2
		"TUTORIAL_DRAFT_SETS",         # §A2
		"TUTORIAL_BOND_FIRST",         # §A3
		"TUTORIAL_BOSS_FIRST",         # §A4
		"TUTORIAL_SKIP_TOGGLE",        # §A5
	]
	for lang in ["en", "zh_CN", "ja", "ko"]:
		var path := "res://lang/%s.json" % lang
		assert_bool(FileAccess.file_exists(path)).is_true()
		var lj := JSON.new()
		var lt: String = FileAccess.get_file_as_string(path)
		assert_int(lj.parse(lt)).is_equal(OK)
		var d: Dictionary = lj.data
		var strings: Dictionary = d.get("strings", {})
		for key in required_keys:
			assert_bool(strings.has(key)).is_true()
			assert_str(str(strings[key])).is_not_empty()

func test_onboarding_json_has_all_four_beats() -> void:
	## A1 (welcome) + A2 (first_draft) + A3 (first_bond) + A4 (first_boss) 都到位
	var path := "res://gamepacks/rogue_survivor/rules/onboarding.json"
	var json := JSON.new()
	var text: String = FileAccess.get_file_as_string(path)
	assert_int(json.parse(text)).is_equal(OK)
	var arr: Array = json.data
	var ids: Array[String] = []
	for trig: Dictionary in arr:
		ids.append(str(trig.get("id", "")))
	assert_bool("onboarding_welcome_movement" in ids).is_true()
	assert_bool("onboarding_first_draft" in ids).is_true()
	assert_bool("onboarding_first_bond" in ids).is_true()
	assert_bool("onboarding_first_boss" in ids).is_true()

func test_boss_spawned_event_emitted_in_spawner() -> void:
	## §A4 依赖 boss_spawned 事件——验证 rogue_spawner.gd 真发了它
	var src: String = FileAccess.get_file_as_string("res://gamepacks/rogue_survivor/scripts/rogue_spawner.gd")
	assert_str(src).contains('EventBus.emit_event("boss_spawned"')

func test_tutorial_skip_toggle_wired_in_character_select() -> void:
	## §A5 escape hatch：character_select 必须有 SaveSystem-backed toggle
	## 写入 namespace=rogue_survivor_onboarding key=tutorials_disabled
	var src: String = FileAccess.get_file_as_string("res://gamepacks/rogue_survivor/scenes/character_select/character_select.gd")
	assert_str(src).contains("TUTORIAL_SKIP_TOGGLE")
	assert_str(src).contains("rogue_survivor_onboarding")
	assert_str(src).contains("tutorials_disabled")
	assert_str(src).contains("SaveSystem.save_data")
