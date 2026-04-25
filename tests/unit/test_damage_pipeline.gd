## 单元测试：DamagePipeline（暴击/减伤/免死）
extends GdUnitTestSuite

# === 暴击统一性 ===

func test_crit_reads_from_stat_system_crit_rate() -> void:
	## 确保 damage_pipeline 从 StatSystem crit_rate 读取暴击率
	## 卡片通过 MOD_STAT aura 设置 crit_rate，必须能被 damage_pipeline 识别
	# 验证 damage_pipeline.gd 源码包含 get_total_stat(*, "crit_rate")
	var dp_path := "res://src/systems/damage_pipeline.gd"
	if not FileAccess.file_exists(dp_path):
		fail("damage_pipeline.gd not found")
		return
	var code: String = FileAccess.get_file_as_string(dp_path)
	assert_str(code).contains("get_total_stat")
	assert_str(code).contains("crit_rate")

func test_no_final_crit_chance_reference() -> void:
	## 确保旧的 _final_crit_chance 变量已彻底清除
	var files := [
		"res://src/systems/damage_pipeline.gd",
		"res://gamepacks/rogue_survivor/scripts/rogue_combat.gd",
	]
	for path in files:
		if FileAccess.file_exists(path):
			var code: String = FileAccess.get_file_as_string(path)
			assert_str(code).not_contains("_final_crit_chance")
