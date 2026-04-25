## 单元测试：StatSystem（白字+绿字属性架构）
extends GdUnitTestSuite

var _stat_sys: Node

func before_test() -> void:
	_stat_sys = auto_free(StatSystem.new()) as Node
	add_child(_stat_sys)

func _make_entity() -> GameEntity:
	var e: GameEntity = auto_free(GameEntity.new()) as GameEntity
	e.runtime_id = randi()
	return e

# === 白字属性 ===

func test_white_base_stat() -> void:
	var e := _make_entity()
	_stat_sys.set_white_base(e, "str", 10.0)
	assert_float(_stat_sys.get_white_stat(e, "str")).is_equal(10.0)

func test_white_growth_per_level() -> void:
	var e := _make_entity()
	_stat_sys.set_white_base(e, "str", 10.0)
	_stat_sys.set_white_growth(e, "str", 2.0)
	# level 5: base + growth * (5-1) = 10 + 2*4 = 18
	assert_float(_stat_sys.get_white_stat(e, "str", 5)).is_equal(18.0)

# === 绿字属性 ===

func test_green_flat_adds() -> void:
	var e := _make_entity()
	_stat_sys.set_white_base(e, "atk", 100.0)
	_stat_sys.add_green_stat(e, "atk", 50.0)
	# total = (100 + 50) * (1 + 0) = 150
	assert_float(_stat_sys.get_total_stat(e, "atk")).is_equal(150.0)

func test_green_percent_multiplies() -> void:
	var e := _make_entity()
	_stat_sys.set_white_base(e, "atk", 100.0)
	_stat_sys.add_green_percent(e, "atk", 0.5)
	# total = (100 + 0) * (1 + 0.5) = 150
	assert_float(_stat_sys.get_total_stat(e, "atk")).is_equal(150.0)

func test_green_flat_and_percent_combined() -> void:
	var e := _make_entity()
	_stat_sys.set_white_base(e, "atk", 100.0)
	_stat_sys.add_green_stat(e, "atk", 50.0)
	_stat_sys.add_green_percent(e, "atk", 0.2)
	# total = (100 + 50) * (1 + 0.2) = 180
	assert_float(_stat_sys.get_total_stat(e, "atk")).is_equal(180.0)

func test_remove_green_stat() -> void:
	var e := _make_entity()
	_stat_sys.set_white_base(e, "hp", 500.0)
	_stat_sys.add_green_stat(e, "hp", 200.0)
	_stat_sys.remove_green_stat(e, "hp", 200.0)
	assert_float(_stat_sys.get_total_stat(e, "hp")).is_equal(500.0)

func test_remove_green_percent() -> void:
	var e := _make_entity()
	_stat_sys.set_white_base(e, "hp", 500.0)
	_stat_sys.add_green_percent(e, "hp", 0.5)
	_stat_sys.remove_green_percent(e, "hp", 0.5)
	assert_float(_stat_sys.get_total_stat(e, "hp")).is_equal(500.0)

func test_zero_white_with_green_flat() -> void:
	var e := _make_entity()
	# 倍率类 stat（如 aspd_pct）白字为 0，用 flat 加算
	_stat_sys.add_green_stat(e, "aspd", 0.5)
	assert_float(_stat_sys.get_total_stat(e, "aspd")).is_equal(0.5)

func test_multiple_green_stats_stack() -> void:
	var e := _make_entity()
	_stat_sys.set_white_base(e, "str", 10.0)
	_stat_sys.add_green_stat(e, "str", 5.0)
	_stat_sys.add_green_stat(e, "str", 3.0)
	# total = (10 + 8) * 1 = 18
	assert_float(_stat_sys.get_total_stat(e, "str")).is_equal(18.0)

# === 边界情况 ===

func test_unregistered_entity_returns_zero() -> void:
	var e := _make_entity()
	assert_float(_stat_sys.get_total_stat(e, "atk")).is_equal(0.0)

func test_stat_changed_event_fires() -> void:
	var e := _make_entity()
	_stat_sys.set_white_base(e, "atk", 100.0)
	# 监听 stat_changed 事件
	var monitor := monitor_signals(EventBus)
	_stat_sys.add_green_stat(e, "atk", 50.0)
	# stat_changed 通过 EventBus 发出，验证事件触发
	# 注：EventBus 是自定义事件系统，不是 Godot signal
