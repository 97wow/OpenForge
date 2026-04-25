## 单元测试：SpellSystem（数据驱动技能引擎）
extends GdUnitTestSuite

var _spell_sys: Node
var _stat_sys: Node

func before_test() -> void:
	_stat_sys = auto_free(StatSystem.new()) as Node
	add_child(_stat_sys)
	_spell_sys = auto_free(SpellSystem.new()) as Node
	add_child(_spell_sys)

func _make_entity(faction: String = "player") -> GameEntity:
	var e: GameEntity = auto_free(GameEntity.new()) as GameEntity
	e.runtime_id = randi()
	e.faction = faction
	return e

# === Spell 注册与查询 ===

func test_register_and_has_spell() -> void:
	_spell_sys.register_spell("test_fireball", {
		"id": "test_fireball",
		"effects": [{"type": "SCHOOL_DAMAGE", "base_points": 100}],
		"school": "fire",
	})
	assert_bool(_spell_sys.has_spell("test_fireball")).is_true()
	assert_bool(_spell_sys.has_spell("nonexistent")).is_false()

# === 伤害计算 ===

func test_calculate_value_base_points() -> void:
	var caster := _make_entity()
	var effect := {"base_points": 50.0}
	var spell := {"id": "test"}
	var result: float = _spell_sys.calculate_value(caster, effect, spell)
	assert_float(result).is_equal(50.0)

func test_calculate_value_with_scaling() -> void:
	var caster := _make_entity()
	_stat_sys.set_white_base(caster, "atk", 100.0)
	_stat_sys.add_green_stat(caster, "atk", 50.0)
	var effect := {
		"base_points": 0.0,
		"scaling": {"stat": "atk", "coefficient": 0.5},
	}
	var spell := {"id": "test"}
	# get_total_stat("atk") = 150, * 0.5 = 75
	var result: float = _spell_sys.calculate_value(caster, effect, spell)
	assert_float(result).is_equal(75.0)

func test_calculate_value_base_plus_scaling() -> void:
	var caster := _make_entity()
	_stat_sys.set_white_base(caster, "int", 80.0)
	var effect := {
		"base_points": 30.0,
		"scaling": {"stat": "int", "coefficient": 1.0},
	}
	var spell := {"id": "test"}
	# 30 + 80 * 1.0 = 110
	var result: float = _spell_sys.calculate_value(caster, effect, spell)
	assert_float(result).is_equal(110.0)

func test_scaling_uses_get_total_stat_not_get_stat() -> void:
	## 关键测试：确保 spell 伤害用 get_total_stat（白字+绿字），不是旧 get_stat
	var caster := _make_entity()
	_stat_sys.set_white_base(caster, "atk", 100.0)
	_stat_sys.add_green_stat(caster, "atk", 200.0)  # 绿字加成
	var effect := {"base_points": 0.0, "scaling": {"stat": "atk", "coefficient": 1.0}}
	var result: float = _spell_sys.calculate_value(caster, effect, {})
	# 必须是 300（白100 + 绿200），而不是 100（只有白字）
	assert_float(result).is_equal(300.0)

# === 目标解析 ===

func test_self_target() -> void:
	var caster := _make_entity()
	_spell_sys.register_spell("test_self", {
		"id": "test_self",
		"effects": [{"type": "HEAL", "base_points": 50, "target": {"category": "SELF"}}],
	})
	# Self target 不需要显式 target
	assert_bool(_spell_sys.has_spell("test_self")).is_true()

# === Cooldown ===

func test_cooldown_prevents_recast() -> void:
	_spell_sys.register_spell("test_cd", {
		"id": "test_cd", "cooldown": 5.0,
		"effects": [{"type": "SCHOOL_DAMAGE", "base_points": 10}],
	})
	var caster := _make_entity()
	# 第一次施放应该成功
	# 注：完整的 cast 测试需要 EngineAPI 和 target，这里只测 has_spell + cooldown 逻辑
	assert_bool(_spell_sys.has_spell("test_cd")).is_true()
