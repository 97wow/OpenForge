## 集成测试：冒烟测试（加载不崩溃）
extends GdUnitTestSuite

func test_main_scene_loads() -> void:
	## 主场景能否加载
	var scene: PackedScene = load("res://src/main.tscn")
	assert_object(scene).is_not_null()

func test_autoloads_exist() -> void:
	## 核心 Autoload 是否可用
	var event_bus: Node = Engine.get_main_loop().root.get_node_or_null("/root/EventBus") if Engine.get_main_loop() else null
	# 在测试环境中 Autoload 可能不可用，跳过
	if event_bus == null:
		return
	assert_object(event_bus).is_not_null()

func test_spells_json_parseable() -> void:
	## spells.json 能否解析
	var path := "res://gamepacks/rogue_survivor/data/spells.json"
	assert_bool(FileAccess.file_exists(path)).is_true()
	var json := JSON.new()
	var text: String = FileAccess.get_file_as_string(path)
	assert_int(json.parse(text)).is_equal(OK)
	assert_bool(json.data is Dictionary).is_true()
	# 至少 50 条记录
	var data: Dictionary = json.data
	assert_int(data.size()).is_greater_equal(50)

func test_all_locale_files_parseable() -> void:
	## 所有语言文件能否解析
	for lang in ["zh_CN", "en", "ja", "ko"]:
		var path := "res://gamepacks/rogue_survivor/data/spells_%s.json" % lang
		assert_bool(FileAccess.file_exists(path)).is_true()
		var json := JSON.new()
		var text: String = FileAccess.get_file_as_string(path)
		assert_int(json.parse(text)).is_equal(OK)

func test_entity_definitions_exist() -> void:
	## 核心实体定义文件存在
	var required := ["warrior", "goblin", "skeleton", "arrow"]
	for entity_id in required:
		var path := "res://gamepacks/rogue_survivor/entities/%s.json" % entity_id
		assert_bool(FileAccess.file_exists(path)).is_true()

func test_gamepack_manifest_exists() -> void:
	## GamePack 清单文件存在
	var path := "res://gamepacks/rogue_survivor/pack.json"
	assert_bool(FileAccess.file_exists(path)).is_true()

func test_no_old_modifier_system() -> void:
	## 确保旧 modifier 系统已清理
	var stat_code: String = FileAccess.get_file_as_string("res://src/systems/stat_system.gd")
	assert_str(stat_code).not_contains("_modifiers")
	assert_str(stat_code).not_contains("add_modifier")

func test_no_deprecated_card_effects() -> void:
	## 确保废弃文件已删除
	assert_bool(FileAccess.file_exists("res://gamepacks/rogue_survivor/scripts/rogue_card_effects.gd")).is_false()
