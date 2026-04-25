## RogueSpawner — 波次生成 + Boss 生成 + 波次表 + Boss 警告
## 从 rogue_game_mode.gd 提取，负责实际的怪物/Boss 实例化逻辑
extends RefCounted

var _gm = null  # rogue_game_mode 引用

# 波次定义表（旧系统 fallback）
var _wave_table: Array = [
	[["goblin", 5]],                                        # W1
	[["goblin", 7]],                                        # W2
	[["goblin", 8], ["skeleton", 2]],                       # W3
	[["goblin", 6], ["skeleton", 3], ["archer", 1]],        # W4
	[["goblin", 10], ["skeleton", 4], ["archer", 2]],       # W5
	[["skeleton", 6], ["shadow", 2], ["archer", 2]],        # W6
	[["goblin", 12], ["skeleton", 5], ["shaman", 1]],       # W7
	[["skeleton", 8], ["shadow", 4], ["archer", 3]],        # W8
	[["goblin", 10], ["shadow", 5], ["shaman", 2]],         # W9
	# W10 = BOSS (bone_dragon)
	[["skeleton", 8], ["shadow", 4], ["archer", 3], ["shaman", 1]],   # W11
	[["goblin", 10], ["golem", 1], ["archer", 4]],                     # W12
	[["skeleton", 10], ["shadow", 6], ["shaman", 2]],                  # W13
	[["golem", 2], ["archer", 5], ["shadow", 4]],                      # W14
	[["goblin", 15], ["skeleton", 8], ["shaman", 2], ["golem", 1]],   # W15
	[["shadow", 8], ["archer", 5], ["golem", 2]],                      # W16
	[["skeleton", 12], ["shaman", 3], ["golem", 2], ["archer", 4]],   # W17
	[["shadow", 10], ["golem", 3], ["archer", 6]],                     # W18
	[["goblin", 20], ["skeleton", 10], ["shadow", 6], ["shaman", 3]], # W19
	# W20 = BOSS (shadow_lord)
	[["golem", 3], ["shadow", 8], ["archer", 6], ["shaman", 2]],      # W21
	[["skeleton", 15], ["shadow", 8], ["golem", 3], ["archer", 5]],   # W22
	[["shadow", 10], ["golem", 4], ["shaman", 3], ["archer", 6]],     # W23
	[["goblin", 20], ["skeleton", 12], ["golem", 3], ["shaman", 3], ["archer", 6]], # W24
	[["shadow", 12], ["golem", 4], ["archer", 8], ["shaman", 4]],     # W25
	[["skeleton", 15], ["shadow", 10], ["golem", 5], ["shaman", 3]],  # W26
	[["shadow", 15], ["golem", 5], ["archer", 8], ["shaman", 4]],     # W27
	[["goblin", 25], ["skeleton", 15], ["shadow", 10], ["golem", 4], ["shaman", 3], ["archer", 6]], # W28
	[["shadow", 15], ["golem", 6], ["archer", 10], ["shaman", 5]],    # W29
	# W30 = BOSS (void_titan)
]

# BOSS 系统
const BOSS_WAVES: Dictionary = {
	10: "bone_dragon",
	20: "shadow_lord",
	30: "void_titan",
}
var active_bosses: Array[Node3D] = []
var boss_skill_timers: Dictionary = {}  # entity_id -> {spells, cooldowns}
var _boss_warning_label: Label = null
var final_boss_spawned: bool = false
var final_boss: Node3D = null

func init(game_mode) -> void:
	_gm = game_mode

# === 旧波次系统（fallback / 测试模式）===

func spawn_wave() -> void:
	_gm._current_wave += 1
	_gm.set_var("current_wave", _gm._current_wave)

	var hp_mult: float = _gm._difficulty.get("hp_mult", 1.0)
	var dmg_mult: float = _gm._difficulty.get("dmg_mult", 1.0)
	var count_mult: float = _gm._difficulty.get("count_mult", 1.0)
	var spawned: int = 0
	var spawned_enemies: Array[Node3D] = []

	var wave_def: Array = get_wave_def(_gm._current_wave)
	for group in wave_def:
		if group is Array and group.size() >= 2:
			var enemy_id: String = group[0]
			var base_count: int = group[1]
			var count: int = int(ceil(base_count * count_mult))
			for i in range(count):
				var sp: Vector3 = _gm.SPAWN_POINTS[randi() % _gm.SPAWN_POINTS.size()]
				var offset := Vector3(randf_range(-3.0, 3.0), 0, randf_range(-3.0, 3.0))
				var enemy: Node3D = _gm.spawn(enemy_id, sp + offset)
				if enemy and hp_mult > 1.0:
					var health: Node = EngineAPI.get_component(enemy, "health")
					if health:
						health.max_hp *= hp_mult
						health.current_hp = health.max_hp
				if enemy and dmg_mult > 1.0:
					var combat: Node = EngineAPI.get_component(enemy, "combat")
					if combat:
						combat.damage *= dmg_mult
				if enemy:
					spawned_enemies.append(enemy)
				spawned += 1

	if _gm._elite_module.is_elite_wave(_gm._current_wave) and spawned_enemies.size() > 0:
		var elite_idx: int = randi() % spawned_enemies.size()
		_gm._elite_module.promote_to_elite(spawned_enemies[elite_idx])

	_gm.emit("wave_started", {"wave_index": _gm._current_wave, "enemy_count": spawned})

func get_wave_def(wave: int) -> Array:
	if wave <= _wave_table.size():
		return _wave_table[wave - 1]
	var goblin_count: int = mini(5 + wave * 2, 25)
	var skeleton_count: int = mini(maxi(0, wave - 3), 15)
	var shadow_count: int = mini(maxi(0, wave - 8), 15)
	var archer_count: int = mini(maxi(0, wave - 4), 10)
	@warning_ignore("integer_division")
	var shaman_count: int = mini(maxi(0, (wave - 7) / 2), 5)
	@warning_ignore("integer_division")
	var golem_count: int = mini(maxi(0, (wave - 12) / 3), 6)
	var result: Array = [["goblin", goblin_count]]
	if skeleton_count > 0:
		result.append(["skeleton", skeleton_count])
	if shadow_count > 0:
		result.append(["shadow", shadow_count])
	if archer_count > 0:
		result.append(["archer", archer_count])
	if shaman_count > 0:
		result.append(["shaman", shaman_count])
	if golem_count > 0:
		result.append(["golem", golem_count])
	return result

# === Boss 生成 ===

func spawn_boss_wave(boss_id: String, hp_mult: float, dmg_mult: float) -> int:
	show_boss_warning(boss_id)
	EventBus.emit_event("boss_spawned", {"boss_id": boss_id, "is_final": false})
	var sp: Vector3 = _gm.SPAWN_POINTS[0]
	var boss: Node3D = _gm.spawn(boss_id, sp)
	if boss == null:
		return 0

	if hp_mult > 1.0:
		var health: Node = EngineAPI.get_component(boss, "health")
		if health:
			health.max_hp *= hp_mult
			health.current_hp = health.max_hp
	if dmg_mult > 1.0:
		var combat: Node = EngineAPI.get_component(boss, "combat")
		if combat:
			combat.damage *= dmg_mult

	active_bosses.append(boss)

	if boss is GameEntity:
		var spells: Array = (boss as GameEntity).get_meta_value("boss_spells", [])
		if spells.size() > 0:
			var cooldowns: Dictionary = {}
			for spell_id in spells:
				cooldowns[str(spell_id)] = randf_range(2.0, 4.0)
			boss_skill_timers[boss.get_instance_id()] = {
				"entity": boss,
				"spells": spells,
				"cooldowns": cooldowns,
			}

	@warning_ignore("integer_division")
	var escort_count: int = 3 + _gm._current_wave / 10
	for i in range(escort_count):
		var esc_sp: Vector3 = _gm.SPAWN_POINTS[randi() % _gm.SPAWN_POINTS.size()]
		var offset := Vector3(randf_range(-3.0, 3.0), 0, randf_range(-3.0, 3.0))
		_gm.spawn("shadow", esc_sp + offset)

	_gm._combat_log_module._add_log("=== BOSS: %s ===" % _gm.I18n.t(get_boss_name_key(boss)), Color(1, 0.3, 0.1))
	return 1 + escort_count

func spawn_final_boss() -> void:
	final_boss_spawned = true
	show_boss_warning("void_titan")
	EventBus.emit_event("boss_spawned", {"boss_id": "void_titan", "is_final": true})
	_gm._combat_log_module._add_log("=== FINAL BOSS! DEFEAT TO WIN! ===", Color(1, 0.2, 0.1))
	var hp_mult: float = _gm._difficulty.get("hp_mult", 1.0)
	var dmg_mult: float = _gm._difficulty.get("dmg_mult", 1.0)
	var boss: Node3D = _gm.spawn("void_titan", _gm.SPAWN_POINTS[0])
	if boss:
		var health: Node = EngineAPI.get_component(boss, "health")
		if health:
			health.max_hp *= hp_mult * 1.5
			health.current_hp = health.max_hp
		var combat: Node = EngineAPI.get_component(boss, "combat")
		if combat:
			combat.damage *= dmg_mult * 1.3
		final_boss = boss
		active_bosses.append(boss)
		if boss is GameEntity:
			var spells: Array = (boss as GameEntity).get_meta_value("boss_spells", [])
			if spells.size() > 0:
				var cooldowns: Dictionary = {}
				for spell_id in spells:
					cooldowns[str(spell_id)] = randf_range(2.0, 4.0)
				boss_skill_timers[boss.get_instance_id()] = {
					"entity": boss, "spells": spells, "cooldowns": cooldowns,
				}

# === Boss 辅助 ===

func get_boss_name_key(boss: Node3D) -> String:
	if boss is GameEntity:
		return (boss as GameEntity).get_meta_value("boss_name_key", "BOSS")
	return "BOSS"

func show_boss_warning(_boss_id: String) -> void:
	var ui_layer: CanvasLayer = _gm.get_tree().current_scene.get_node_or_null("UI")
	if ui_layer == null:
		return
	if _boss_warning_label and is_instance_valid(_boss_warning_label):
		_boss_warning_label.queue_free()

	_boss_warning_label = Label.new()
	_boss_warning_label.text = "!! BOSS INCOMING !!"
	_boss_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_warning_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_boss_warning_label.add_theme_font_size_override("font_size", 36)
	_boss_warning_label.add_theme_color_override("font_color", Color(1, 0.2, 0.1))
	ui_layer.add_child(_boss_warning_label)

	var tw := _boss_warning_label.create_tween()
	tw.tween_property(_boss_warning_label, "modulate:a", 0.3, 0.3)
	tw.tween_property(_boss_warning_label, "modulate:a", 1.0, 0.3)
	tw.tween_property(_boss_warning_label, "modulate:a", 0.3, 0.3)
	tw.tween_property(_boss_warning_label, "modulate:a", 1.0, 0.3)
	tw.tween_property(_boss_warning_label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_boss_warning_label.queue_free)

# === 挑战模式 ===

func on_challenge_wave() -> void:
	if EngineAPI.get_game_state() != "playing":
		return
	spawn_wave()
	_gm._combat_log_module._add_log("[CHALLENGE] Extra wave!", Color(1, 0.6, 0.2))

func on_challenge_boss() -> void:
	if EngineAPI.get_game_state() != "playing":
		return
	var boss_ids := ["bone_dragon", "shadow_lord", "void_titan"]
	var boss_id: String = boss_ids[randi() % boss_ids.size()]
	var hp_mult: float = _gm._difficulty.get("hp_mult", 1.0)
	var dmg_mult: float = _gm._difficulty.get("dmg_mult", 1.0)
	spawn_boss_wave(boss_id, hp_mult, dmg_mult)
	_gm._combat_log_module._add_log("[CHALLENGE] Boss %s!" % boss_id, Color(1, 0.3, 0.1))
