## RogueWaveSystem — 5 波制波次管理器（公式化）
## 精英/小怪/Boss 全部由公式生成，支持速度倍率调节
## 第5波结束后进入 900 秒倒计时（完成模式）
extends RefCounted

var _gm = null

## 当前波次（0-based 内部，1-based 显示）
var current_wave: int = 0
var _wave_elapsed: float = 0.0
var _minion_timer: float = 0.0
var _elite_index: int = 0
var _boss_spawned: bool = false
var wave_active: bool = false
var _intermission: bool = false
var _intermission_timer: float = 0.0
const INTERMISSION_DURATION := 5.0

## 游戏完成模式（第5波后）
var game_completed: bool = false
var _completion_timer: float = 0.0
const COMPLETION_DURATION := 900.0  # 900秒倒计时

## 速度倍率（用于加速/减速刷怪）
var speed_multiplier: float = 1.0  # >1 加快刷怪, <1 减慢

## 当前波次的精英时间表（由公式生成）
var _elite_schedule: Array[Dictionary] = []

# === 波次基础配置（不硬编码精英时间点）===
const WAVE_CONFIGS := [
	{"duration": 360.0, "minions_per_sec": 2, "minion_id": "goblin", "boss_id": "bone_dragon"},
	{"duration": 360.0, "minions_per_sec": 4, "minion_id": "skeleton", "boss_id": "shadow_lord"},
	{"duration": 370.0, "minions_per_sec": 4, "minion_id": "skeleton", "boss_id": "bone_dragon"},
	{"duration": 380.0, "minions_per_sec": 4, "minion_id": "shadow", "boss_id": "shadow_lord"},
	{"duration": 250.0, "minions_per_sec": 4, "minion_id": "shadow", "boss_id": "void_titan", "is_final": true},
]

# === 精英公式参数 ===
## 精英总数 = ELITE_BASE + wave_index * ELITE_PER_WAVE
const ELITE_BASE := 3
const ELITE_PER_WAVE := 2
## 波1精英首次出现在波次50%处，波2-5在10%处
## 批次规模：波1-2 全×1，波3 随机×1-2，波4-5 随机×1-3

func init(game_mode) -> void:
	_gm = game_mode

func _t(key: String, args: Array = []) -> String:
	if _gm and _gm.I18n:
		if args.is_empty():
			return _gm.I18n.t(key)
		return _gm.I18n.t(key, args)
	return key

# === 公式化精英时间表生成 ===

func _generate_elite_schedule(wave_index: int) -> Array[Dictionary]:
	## 根据公式生成精英出现时间表
	var config: Dictionary = WAVE_CONFIGS[wave_index]
	var duration: float = config.get("duration", 360.0)

	# 精英总数
	var total_elites: int = ELITE_BASE + wave_index * ELITE_PER_WAVE  # 5,7,9,11,13

	# 首次出现时间（剩余秒数）
	var first_remaining: float
	if wave_index == 0:
		first_remaining = duration * 0.50  # 波1: 50%处
	else:
		first_remaining = duration * 0.90  # 波2-5: 10%已过 = 90%剩余

	# 最后一批在剩余 5% 处
	var last_remaining: float = duration * 0.05

	# 生成批次
	var schedule: Array[Dictionary] = []
	var remaining_elites: int = total_elites
	var batch_count: int = 0

	# 计算批次数量（根据波次决定批次规模）
	var max_batch_size: int = 1
	if wave_index >= 4:
		max_batch_size = 3
	elif wave_index >= 3:
		max_batch_size = 3
	elif wave_index >= 2:
		max_batch_size = 2

	# 先决定每个批次的大小
	var batches: Array[int] = []
	while remaining_elites > 0:
		var batch_size: int = mini(randi_range(1, max_batch_size), remaining_elites)
		batches.append(batch_size)
		remaining_elites -= batch_size

	batch_count = batches.size()
	if batch_count == 0:
		return schedule

	# 均匀分布时间点
	var time_span: float = first_remaining - last_remaining
	var interval: float = time_span / maxf(batch_count, 1)

	for i in range(batch_count):
		var remaining_time: float = first_remaining - i * interval
		# 加一点随机偏移（±10%间隔）
		remaining_time += randf_range(-interval * 0.1, interval * 0.1)
		remaining_time = clampf(remaining_time, last_remaining, first_remaining)
		schedule.append({
			"remaining": remaining_time,
			"count": batches[i],
		})

	# 按剩余时间降序排列（先出现的在前面）
	schedule.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["remaining"]) > float(b["remaining"])
	)

	return schedule

# === 波次控制 ===

func start_wave(wave_index: int) -> void:
	if wave_index >= WAVE_CONFIGS.size():
		return
	current_wave = wave_index
	_wave_elapsed = 0.0
	_minion_timer = 0.0
	_elite_index = 0
	_boss_spawned = false
	wave_active = true
	_intermission = false

	# 生成本波精英时间表
	_elite_schedule = _generate_elite_schedule(wave_index)

	var config: Dictionary = WAVE_CONFIGS[current_wave]
	var duration: float = config.get("duration", 360.0)
	var elite_total: int = 0
	for e in _elite_schedule:
		elite_total += int(e.get("count", 1))

	EventBus.emit_event("wave_started", {
		"wave": current_wave + 1,
		"duration": duration,
		"elite_count": elite_total,
	})
	if _gm._combat_log_module:
		_gm._combat_log_module._add_log(
			_t("WAVE_START", [str(current_wave + 1), str(int(duration))]),
			Color(1, 0.85, 0.3)
		)

func process(delta: float) -> void:
	if not wave_active:
		# 完成模式倒计时
		if game_completed:
			_completion_timer -= delta
			if _completion_timer <= 0:
				_completion_timer = 0
				# 游戏结束
				EventBus.emit_event("game_time_up", {})
		return

	# 波间休息
	if _intermission:
		_intermission_timer -= delta
		if _intermission_timer <= 0:
			_intermission = false
			if current_wave + 1 < WAVE_CONFIGS.size():
				start_wave(current_wave + 1)
			else:
				wave_active = false
				_on_all_waves_complete()
		return

	var config: Dictionary = WAVE_CONFIGS[current_wave]
	var duration: float = config.get("duration", 360.0)
	_wave_elapsed += delta * speed_multiplier
	var remaining: float = duration - _wave_elapsed

	# === 小怪持续刷新 ===
	var minions_per_sec: float = config.get("minions_per_sec", 2) * speed_multiplier
	var minion_id: String = config.get("minion_id", "goblin")
	_minion_timer += delta
	var spawn_interval: float = 1.0 / maxf(minions_per_sec, 0.5)
	while _minion_timer >= spawn_interval:
		_minion_timer -= spawn_interval
		_spawn_minion(minion_id)

	# === 精英定时刷新 ===
	while _elite_index < _elite_schedule.size():
		var elite_cfg: Dictionary = _elite_schedule[_elite_index]
		var elite_remaining: float = float(elite_cfg.get("remaining", 0))
		if remaining <= elite_remaining:
			var count: int = int(elite_cfg.get("count", 1))
			_spawn_elites(count)
			_elite_index += 1
		else:
			break

	# === Boss 在 0 秒出现 ===
	if remaining <= 0 and not _boss_spawned:
		_boss_spawned = true
		var boss_id: String = config.get("boss_id", "bone_dragon")
		_spawn_boss(boss_id, config.get("is_final", false))

# === 查询 ===

func get_remaining_time() -> float:
	if game_completed:
		return _completion_timer
	if not wave_active:
		return 0.0
	if _intermission:
		return _intermission_timer
	var duration: float = WAVE_CONFIGS[current_wave].get("duration", 360.0)
	return maxf(duration - _wave_elapsed, 0.0)

func get_display_wave() -> int:
	return current_wave + 1

func get_total_waves() -> int:
	return WAVE_CONFIGS.size()

func is_final_wave() -> bool:
	return current_wave >= WAVE_CONFIGS.size() - 1

func set_speed(multiplier: float) -> void:
	## 设置刷怪速度倍率（1.0=正常, 2.0=两倍速）
	speed_multiplier = clampf(multiplier, 0.25, 4.0)

# === 内部生成 ===

func _spawn_minion(minion_id: String) -> void:
	var sp: Vector3 = _gm.SPAWN_POINTS[randi() % _gm.SPAWN_POINTS.size()]
	var offset := Vector3(randf_range(-3.0, 3.0), 0, randf_range(-3.0, 3.0))
	var hp_mult: float = _gm._difficulty.get("hp_mult", 1.0)
	var dmg_mult: float = _gm._difficulty.get("dmg_mult", 1.0)
	var enemy: Node3D = _gm.spawn(minion_id, sp + offset)
	if enemy:
		if hp_mult > 1.0:
			var health: Node = EngineAPI.get_component(enemy, "health")
			if health:
				health.max_hp *= hp_mult
				health.current_hp = health.max_hp
		if dmg_mult > 1.0:
			var combat: Node = EngineAPI.get_component(enemy, "combat")
			if combat:
				combat.damage *= dmg_mult

func _spawn_elites(count: int) -> void:
	for _i in range(count):
		var elite_pool := ["skeleton", "shadow", "golem", "archer"]
		var elite_id: String = elite_pool[randi() % elite_pool.size()]
		var sp: Vector3 = _gm.SPAWN_POINTS[randi() % _gm.SPAWN_POINTS.size()]
		var offset := Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0))
		var enemy: Node3D = _gm.spawn(elite_id, sp + offset)
		if enemy and _gm._elite_module:
			_gm._elite_module.promote_to_elite(enemy)
	if _gm._combat_log_module:
		_gm._combat_log_module._add_log(
			_t("ELITE_SPAWN", [str(count)]), Color(1, 0.5, 0.2)
		)

func _spawn_boss(boss_id: String, is_final: bool) -> void:
	var hp_mult: float = _gm._difficulty.get("hp_mult", 1.0)
	var dmg_mult: float = _gm._difficulty.get("dmg_mult", 1.0)
	_gm._spawner.spawn_boss_wave(boss_id, hp_mult, dmg_mult)
	if _gm._combat_log_module:
		var key: String = "FINAL_BOSS_SPAWN" if is_final else "BOSS_SPAWN"
		_gm._combat_log_module._add_log(
			_t(key, [boss_id]), Color(1, 0.2, 0.1)
		)

func on_boss_killed() -> void:
	wave_active = false
	_show_draft_selection()
	if not is_final_wave():
		_intermission = true
		_intermission_timer = INTERMISSION_DURATION
		wave_active = true

func _show_draft_selection() -> void:
	if _gm._combat_log_module:
		_gm._combat_log_module._add_log(
			_t("DRAFT_AVAILABLE"), Color(0.3, 1, 0.5)
		)
	EventBus.emit_event("draft_available", {"wave": current_wave + 1})

func _on_all_waves_complete() -> void:
	## 第5波结束 → 进入900秒完成模式
	game_completed = true
	_completion_timer = COMPLETION_DURATION

	# 停止所有自动资源增长
	EngineAPI.set_variable("base_gold_per_sec", 0.0)  # 金币保持（不停）
	EngineAPI.set_variable("base_wood_per_sec", 0.0)
	EngineAPI.set_variable("hero_gold_per_sec", 0.0)

	if _gm._combat_log_module:
		_gm._combat_log_module._add_log(
			_t("ALL_WAVES_DONE"), Color(1, 0.85, 0.3)
		)
	EventBus.emit_event("all_waves_complete", {})

	# 生成挑战 NPC
	_spawn_challenge_npc()

func _spawn_challenge_npc() -> void:
	## 在英雄附近生成存档Boss挑战NPC
	if _gm.hero == null or not is_instance_valid(_gm.hero):
		return
	var npc_pos: Vector3 = _gm.hero.global_position + Vector3(3, 0, 0)
	var npc: Node3D = _gm.spawn("training_dummy", npc_pos, {
		"tags": ["npc", "structure", "friendly"],
		"faction": "player",
		"components": {
			"health": {"max_hp": 99999, "show_damage_numbers": false},
		},
	})
	if npc and npc is GameEntity:
		(npc as GameEntity).set_unit_flag(UnitFlags.IMMUNE_DAMAGE)
		(npc as GameEntity).set_meta_value("npc_type", "challenge_boss")

	# 监听选中事件来显示挑战UI
	EventBus.connect_event("entity_selected", _on_npc_selected)

	if _gm._combat_log_module:
		_gm._combat_log_module._add_log(
			_t("NPC_CHALLENGE_SPAWNED"), Color(0.5, 0.8, 1)
		)

func _on_npc_selected(data: Dictionary) -> void:
	var entity = data.get("entity")
	if entity == null or not is_instance_valid(entity):
		return
	if not (entity is GameEntity):
		return
	if (entity as GameEntity).get_meta_value("npc_type", "") != "challenge_boss":
		return
	_show_challenge_boss_ui()

func _show_challenge_boss_ui() -> void:
	## 显示存档Boss挑战选择UI
	var ui_layer: CanvasLayer = _gm.get_tree().current_scene.get_node_or_null("UI")
	if ui_layer == null:
		return
	var I18n: Node = _gm.I18n
	var difficulty_level: int = _gm._difficulty.get("level", 1)

	var panel := Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.z_index = 50
	ui_layer.add_child(panel)

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(overlay)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.offset_left = -180
	vbox.offset_right = 180
	vbox.offset_top = -120
	vbox.offset_bottom = 120
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = _t("CHALLENGE_BOSS_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vbox.add_child(title)

	# 每个难度一个按钮（只能挑战 <= 当前难度）
	var boss_ids := ["bone_dragon", "shadow_lord", "void_titan"]
	for i in range(difficulty_level):
		var boss_id: String = boss_ids[i % boss_ids.size()]
		var btn := Button.new()
		btn.text = "%s Lv.%d" % [_t("CHALLENGE_BOSS"), i + 1]
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_size_override("font_size", 14)
		var bid: String = boss_id
		var p: Control = panel
		btn.pressed.connect(func() -> void:
			p.queue_free()
			var hp_mult: float = 1.0 + i * 0.5
			var dmg_mult: float = 1.0 + i * 0.3
			_gm._spawner.spawn_boss_wave(bid, hp_mult, dmg_mult)
			if _gm._combat_log_module:
				_gm._combat_log_module._add_log(
					_t("BOSS_SPAWN", [bid]), Color(1, 0.3, 0.1)
				)
		)
		vbox.add_child(btn)

	# 关闭按钮
	var close_btn := Button.new()
	close_btn.text = I18n.t("BACK") if I18n else "Close"
	close_btn.custom_minimum_size = Vector2(0, 30)
	close_btn.pressed.connect(panel.queue_free)
	vbox.add_child(close_btn)
