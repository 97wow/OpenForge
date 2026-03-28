## Rogue Survivor - 肉鸽生存射击主脚本
## 对抗式布局：玩家泉(右下) vs 敌人泉(左上)
## 胜利：摧毁敌方泉 或 存活10分钟
extends GamePackScript

const ARENA_SIZE := Vector2(1920, 1080)
# 对抗布局坐标
const PLAYER_FOUNTAIN_POS := Vector2(1550, 850)  # 右下
const ENEMY_FOUNTAIN_POS := Vector2(370, 230)     # 左上
const HERO_START_POS := Vector2(1400, 750)
# 怪物固定刷新点（敌方泉附近3个位置）
const SPAWN_POINTS: Array[Vector2] = [
	Vector2(200, 100),
	Vector2(500, 100),
	Vector2(200, 350),
]

const GAME_DURATION := 600.0
const WAVE_INTERVAL := 20.0
const TOTAL_WAVES := 30
const XP_PER_LEVEL_BASE := 30
const XP_PER_LEVEL_GROWTH := 15

var hero: Node2D = null
var player_fountain: Node2D = null
var enemy_fountain: Node2D = null
var _game_timer: float = 0.0
var _wave_timer: float = 0.0
var _current_wave: int = 0
var _hero_level: int = 1
var _xp_to_next: int = XP_PER_LEVEL_BASE

var _card_manager: RogueCardManager = null
var _card_select_ui: Control = null  # 3选1 弹窗

var _wave_table: Array = [
	[["goblin", 5]],
	[["goblin", 7]],
	[["goblin", 8], ["skeleton", 2]],
	[["goblin", 6], ["skeleton", 3]],
	[["goblin", 10], ["skeleton", 4]],
	[["skeleton", 6], ["shadow", 2]],
	[["goblin", 12], ["skeleton", 5], ["shadow", 2]],
	[["skeleton", 8], ["shadow", 4]],
	[["goblin", 15], ["shadow", 5]],
	[["skeleton", 10], ["shadow", 5]],
]

var _burn_timer: Dictionary = {}  # entity_id -> timer
var _poison_timer: Dictionary = {}  # entity_id -> timer

func _pack_ready() -> void:
	listen("player_shoot", _on_player_shoot)
	listen("projectile_hit", _on_projectile_hit)
	listen("entity_destroyed", _on_entity_destroyed)
	listen("resource_changed", _on_resource_changed)

	_draw_arena()
	_create_hud()
	_spawn_fountains()
	_spawn_hero()

	# 初始化卡片系统
	var hero_class: String = str(SceneManager.pending_data.get("hero_class", "warrior"))
	_card_manager = RogueCardManager.new()
	_card_manager.init(
		pack.pack_path.path_join("cards"),
		pack.pack_path.path_join("card_sets.json"),
		hero_class
	)

	EngineAPI.set_game_state("playing")
	_wave_timer = WAVE_INTERVAL - 3.0

func _pack_process(delta: float) -> void:
	_game_timer += delta
	_wave_timer += delta
	_process_dot_effects(delta)

	if _wave_timer >= WAVE_INTERVAL and _current_wave < TOTAL_WAVES:
		_spawn_wave()
		_wave_timer = 0.0

	# 时间到 = 胜利
	if _game_timer >= GAME_DURATION and EngineAPI.get_game_state() == "playing":
		_victory("Survived 10 minutes!")

	_update_hud()

	if hero and is_instance_valid(hero):
		var camera := get_viewport().get_camera_2d()
		if camera:
			camera.global_position = hero.global_position

# === 初始化 ===

func _draw_arena() -> void:
	var main_node: Node2D = get_tree().current_scene as Node2D
	var arena := Node2D.new()
	arena.name = "Arena"
	arena.z_index = -10
	main_node.add_child(arena)
	main_node.move_child(arena, 0)

	# 地板
	var floor_rect := ColorRect.new()
	floor_rect.color = Color(0.08, 0.08, 0.12)
	floor_rect.size = ARENA_SIZE
	arena.add_child(floor_rect)

	# 网格线
	for x_idx in range(0, int(ARENA_SIZE.x), 64):
		var line := Line2D.new()
		line.points = [Vector2(x_idx, 0), Vector2(x_idx, ARENA_SIZE.y)]
		line.default_color = Color(1, 1, 1, 0.03)
		line.width = 1
		arena.add_child(line)
	for y_idx in range(0, int(ARENA_SIZE.y), 64):
		var line := Line2D.new()
		line.points = [Vector2(0, y_idx), Vector2(ARENA_SIZE.x, y_idx)]
		line.default_color = Color(1, 1, 1, 0.03)
		line.width = 1
		arena.add_child(line)

	# 边界
	var border := Line2D.new()
	border.points = PackedVector2Array([
		Vector2.ZERO, Vector2(ARENA_SIZE.x, 0),
		ARENA_SIZE, Vector2(0, ARENA_SIZE.y), Vector2.ZERO
	])
	border.default_color = Color(0.4, 0.5, 0.7)
	border.width = 3
	arena.add_child(border)

	# 中线（分隔两方阵营）
	var midline := Line2D.new()
	midline.points = [Vector2(0, 0), ARENA_SIZE]
	midline.default_color = Color(0.3, 0.3, 0.4, 0.3)
	midline.width = 2
	arena.add_child(midline)

	# 刷新点标记
	for sp in SPAWN_POINTS:
		var marker := _create_spawn_marker(sp)
		arena.add_child(marker)

func _create_spawn_marker(pos: Vector2) -> Node2D:
	var node := Node2D.new()
	node.position = pos
	var circle := Node2D.new()
	circle.draw.connect(func() -> void:
		circle.draw_arc(Vector2.ZERO, 20, 0, TAU, 16, Color(1, 0.3, 0.3, 0.25), 1.5)
	)
	circle.queue_redraw()
	node.add_child(circle)
	return node

func _spawn_fountains() -> void:
	# 玩家泉（右下）
	player_fountain = spawn("life_fountain", PLAYER_FOUNTAIN_POS)
	# 敌人泉（左上）- 高攻击力
	enemy_fountain = spawn("enemy_fountain", ENEMY_FOUNTAIN_POS)

func _spawn_hero() -> void:
	# 读取角色选择（warrior/ranger/mage），默认 warrior
	var hero_class: String = str(SceneManager.pending_data.get("hero_class", "warrior"))
	hero = spawn(hero_class, HERO_START_POS)
	if hero:
		set_var("hero_class", hero_class)

# === 波次 ===

func _spawn_wave() -> void:
	_current_wave += 1
	set_var("current_wave", _current_wave)

	var wave_def: Array = _get_wave_def(_current_wave)
	var spawned := 0
	for group in wave_def:
		if group is Array and group.size() >= 2:
			var enemy_id: String = group[0]
			var count: int = group[1]
			for i in range(count):
				# 从固定刷新点随机选一个
				var sp: Vector2 = SPAWN_POINTS[randi() % SPAWN_POINTS.size()]
				var offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
				spawn(enemy_id, sp + offset)
				spawned += 1

	emit("wave_started", {"wave_index": _current_wave, "enemy_count": spawned})

func _get_wave_def(wave: int) -> Array:
	if wave <= _wave_table.size():
		return _wave_table[wave - 1]
	var goblin_count: int = 5 + wave * 2
	var skeleton_count: int = maxi(0, wave - 3)
	var shadow_count: int = maxi(0, wave - 8)
	var result: Array = [["goblin", mini(goblin_count, 20)]]
	if skeleton_count > 0:
		result.append(["skeleton", mini(skeleton_count, 12)])
	if shadow_count > 0:
		result.append(["shadow", mini(shadow_count, 8)])
	return result

# === 射击 ===

func _on_player_shoot(data: Dictionary) -> void:
	var pos: Vector2 = data.get("position", Vector2.ZERO)
	var dir: Vector2 = data.get("direction", Vector2.RIGHT)
	var spd: float = data.get("speed", 650.0)
	var dmg: float = data.get("damage", 12.0)
	var proj_id: String = data.get("projectile_id", "arrow")
	var shooter: Node2D = data.get("shooter", null)

	# 读取卡片能力
	var pierce_chance: float = float(EngineAPI.get_variable("hero_pierce_chance", 0.0))
	var pierce: int = 0
	if pierce_chance > 0 and randf() < pierce_chance:
		pierce = int(EngineAPI.get_variable("hero_pierce_count", 1))
		if pierce < 1:
			pierce = 1
	var extra_proj: int = int(EngineAPI.get_variable("hero_extra_projectiles", 0))
	var spread_angle: float = float(EngineAPI.get_variable("hero_spread_angle", 10))

	# 计算投射物数量和方向
	var total_projectiles: int = 1 + extra_proj
	var directions: Array[Vector2] = []
	if total_projectiles == 1:
		directions.append(dir)
	else:
		var half_spread := deg_to_rad(spread_angle * (total_projectiles - 1) * 0.5)
		var step := deg_to_rad(spread_angle)
		for i in range(total_projectiles):
			var angle_offset := -half_spread + step * i
			directions.append(dir.rotated(angle_offset))

	for shoot_dir in directions:
		spawn(proj_id, pos, {
			"components": {
				"projectile": {
					"direction": shoot_dir,
					"speed": spd,
					"damage": dmg,
					"source": shooter,
					"target_tag": "enemy",
					"pierce_count": pierce,
				}
			}
		})

# === 命中效果处理 ===

func _on_projectile_hit(data: Dictionary) -> void:
	var target = data.get("target")  # Variant: 避免强类型赋值已释放实例
	var source = data.get("source")
	var base_damage: float = data.get("damage", 0)
	if target == null or source == null:
		return
	if not is_instance_valid(target) or not is_instance_valid(source):
		return
	# 仅处理玩家的投射物命中
	if not (source is Node2D and source.has_method("has_tag") and source.has_tag("player")):
		return

	# --- 暴击 ---
	var crit_chance: float = float(EngineAPI.get_variable("hero_crit_chance", 0.0))
	if crit_chance > 0 and randf() < crit_chance:
		var crit_mult := 1.5 + float(EngineAPI.get_variable("hero_crit_damage_bonus", 0.0))
		var bonus_dmg := base_damage * (crit_mult - 1.0)
		var health: Node = EngineAPI.get_component(target, "health")
		if health and health.has_method("take_damage"):
			health.take_damage(bonus_dmg, source)
		# 暴击黄色大字提示
		if is_instance_valid(target) and target is Node2D:
			var crit_label := Label.new()
			crit_label.text = "CRIT! %d" % int(base_damage * crit_mult)
			crit_label.add_theme_font_size_override("font_size", 22)
			crit_label.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
			crit_label.position = Vector2(randf_range(-15, 15), -35)
			crit_label.z_index = 51
			(target as Node2D).add_child(crit_label)
			var tw := crit_label.create_tween()
			tw.set_parallel(true)
			tw.tween_property(crit_label, "position:y", crit_label.position.y - 50, 1.0)
			tw.tween_property(crit_label, "modulate:a", 0.0, 1.0)
			tw.chain().tween_callback(crit_label.queue_free)

	# --- 吸血 ---
	var life_steal: float = float(EngineAPI.get_variable("hero_life_steal", 0.0))
	if life_steal > 0:
		var hero_health: Node = EngineAPI.get_component(hero, "health")
		if hero_health and hero_health.has_method("heal"):
			# 低血量双倍（Blood Frenzy 效果）
			var low_hp_mult: float = float(EngineAPI.get_variable("hero_low_hp_lifesteal_mult", 1.0))
			if hero_health.get_hp_ratio() < 0.5 and low_hp_mult > 1.0:
				life_steal *= low_hp_mult
			var heal_amount := base_damage * life_steal
			hero_health.heal(heal_amount, hero)

	# --- 燃烧 ---
	var ignite_chance: float = float(EngineAPI.get_variable("hero_ignite_chance", 0.0))
	if ignite_chance > 0 and randf() < ignite_chance:
		EngineAPI.apply_buff(target, "burn", 3.0)
		var eid: int = target.runtime_id if target is GameEntity else target.get_instance_id()
		_burn_timer[eid] = {"target": target, "remaining": 3.0, "dps": 5.0}

	# --- 减速（同一目标只取最强减速，不叠加）---
	var slow_chance: float = float(EngineAPI.get_variable("hero_slow_chance", 0.0))
	if slow_chance > 0 and randf() < slow_chance:
		var slow_pct: float = float(EngineAPI.get_variable("hero_slow_pct", 0.2))
		var movement: Node = EngineAPI.get_component(target, "movement")
		if movement and movement.has_method("add_speed_modifier"):
			# 固定 ID：覆盖式刷新，不叠加
			movement.remove_speed_modifier("hero_slow")
			movement.add_speed_modifier("hero_slow", 1.0 - slow_pct)
			get_tree().create_timer(2.0).timeout.connect(func() -> void:
				if is_instance_valid(target) and movement:
					movement.remove_speed_modifier("hero_slow")
			)

	# --- 中毒 ---
	var poison_chance: float = float(EngineAPI.get_variable("hero_poison_chance", 0.0))
	if poison_chance > 0 and randf() < poison_chance:
		EngineAPI.apply_buff(target, "poison", 3.0)
		var eid: int = target.runtime_id if target is GameEntity else target.get_instance_id()
		var max_stacks: int = int(EngineAPI.get_variable("hero_poison_max_stacks", 1))
		if _poison_timer.has(eid):
			var pt: Dictionary = _poison_timer[eid]
			pt["stacks"] = mini(pt["stacks"] + 1, max_stacks)
			pt["remaining"] = 3.0
		else:
			_poison_timer[eid] = {"target": target, "remaining": 3.0, "dps": 4.0, "stacks": 1}

	# --- 分裂 ---
	var split_chance: float = float(EngineAPI.get_variable("hero_split_chance", 0.0))
	if split_chance > 0 and randf() < split_chance:
		var split_count: int = int(EngineAPI.get_variable("hero_split_count", 1))
		var split_ratio: float = float(EngineAPI.get_variable("hero_split_damage_ratio", 0.6))
		var split_dmg := base_damage * split_ratio
		# 找附近其他敌人
		var nearby: Array = EngineAPI.find_entities_in_area(target.global_position, 150, "enemy")
		var split_done := 0
		for e in nearby:
			if e == target or not is_instance_valid(e):
				continue
			var dir: Vector2 = (target as Node2D).global_position.direction_to(e.global_position)
			spawn("arrow", target.global_position, {
				"components": {
					"projectile": {
						"direction": dir,
						"speed": 800,
						"damage": split_dmg,
						"source": hero,
						"target_tag": "enemy",
						"max_range": 200,
					}
				}
			})
			split_done += 1
			if split_done >= split_count:
				break

	# --- 链式闪电 ---
	var chain_chance: float = float(EngineAPI.get_variable("hero_chain_chance", 0.0))
	if chain_chance > 0 and randf() < chain_chance:
		var chain_count: int = int(EngineAPI.get_variable("hero_chain_count", 2))
		var chain_stun: float = float(EngineAPI.get_variable("hero_chain_stun", 0.5))
		var chain_dmg := base_damage * 0.6
		var chain_targets: Array = EngineAPI.find_entities_in_area(target.global_position, 180, "enemy")
		var chained := 0
		for ct in chain_targets:
			if ct == target or not is_instance_valid(ct):
				continue
			var ct_health: Node = EngineAPI.get_component(ct, "health")
			if ct_health and ct_health.has_method("take_damage"):
				ct_health.take_damage(chain_dmg, hero, 4)  # DamageType.SHADOW
			# 眩晕 = 减速100%
			var ct_movement: Node = EngineAPI.get_component(ct, "movement")
			if ct_movement and ct_movement.has_method("add_speed_modifier"):
				ct_movement.remove_speed_modifier("chain_stun")
				ct_movement.add_speed_modifier("chain_stun", 0.0)
				get_tree().create_timer(chain_stun).timeout.connect(func() -> void:
					if is_instance_valid(ct) and ct_movement:
						ct_movement.remove_speed_modifier("chain_stun")
				)
			chained += 1
			if chained >= chain_count:
				break

	# --- 冲击波（每N次攻击）---
	var shockwave_n: int = int(EngineAPI.get_variable("hero_shockwave_every_n", 0))
	if shockwave_n > 0:
		var hit_count: int = int(EngineAPI.get_variable("_hit_counter", 0)) + 1
		EngineAPI.set_variable("_hit_counter", hit_count)
		if hit_count % shockwave_n == 0:
			var sw_radius: float = float(EngineAPI.get_variable("hero_shockwave_radius", 120))
			var sw_stun: float = float(EngineAPI.get_variable("hero_shockwave_stun", 1.0))
			var sw_targets: Array = EngineAPI.find_entities_in_area(target.global_position, sw_radius, "enemy")
			for sw_t in sw_targets:
				if not is_instance_valid(sw_t):
					continue
				var sw_health: Node = EngineAPI.get_component(sw_t, "health")
				if sw_health and sw_health.has_method("take_damage"):
					sw_health.take_damage(base_damage * 0.8, hero, 5)  # DamageType.HOLY
				var sw_mov: Node = EngineAPI.get_component(sw_t, "movement")
				if sw_mov and sw_mov.has_method("add_speed_modifier"):
					sw_mov.remove_speed_modifier("shockwave_stun")
					sw_mov.add_speed_modifier("shockwave_stun", 0.0)
					get_tree().create_timer(sw_stun).timeout.connect(func() -> void:
						if is_instance_valid(sw_t) and sw_mov:
							sw_mov.remove_speed_modifier("shockwave_stun")
					)

	# --- 处决（死神套装：低血量直接击杀）---
	var exec_threshold: float = float(EngineAPI.get_variable("hero_execute_threshold", 0.0))
	if exec_threshold > 0 and is_instance_valid(target):
		var exec_health: Node = EngineAPI.get_component(target, "health")
		if exec_health and exec_health.get_hp_ratio() <= exec_threshold:
			exec_health.take_damage(exec_health.current_hp + 1, hero)

const DOT_TICK_INTERVAL := 0.5

func _process_dot_effects(delta: float) -> void:
	# 燃烧 DoT（每 0.5s tick）
	var burn_remove: Array = []
	for eid in _burn_timer:
		var bt: Dictionary = _burn_timer[eid]
		var target = bt.get("target")
		if target == null or not is_instance_valid(target):
			burn_remove.append(eid)
			continue
		bt["remaining"] -= delta
		bt["tick_timer"] = bt.get("tick_timer", 0.0) + delta
		if bt["tick_timer"] >= DOT_TICK_INTERVAL:
			bt["tick_timer"] -= DOT_TICK_INTERVAL
			var tick_dmg: float = bt["dps"] * DOT_TICK_INTERVAL
			var health: Node = EngineAPI.get_component(target, "health")
			if health and health.has_method("take_damage"):
				health.take_damage(tick_dmg, hero, 2)  # DamageType.FIRE
		if bt["remaining"] <= 0:
			burn_remove.append(eid)
	for eid in burn_remove:
		_burn_timer.erase(eid)

	# 中毒 DoT（每 0.5s tick）
	var poison_remove: Array = []
	for eid in _poison_timer:
		var pt: Dictionary = _poison_timer[eid]
		var target = pt.get("target")
		if target == null or not is_instance_valid(target):
			poison_remove.append(eid)
			continue
		pt["remaining"] -= delta
		pt["tick_timer"] = pt.get("tick_timer", 0.0) + delta
		if pt["tick_timer"] >= DOT_TICK_INTERVAL:
			pt["tick_timer"] -= DOT_TICK_INTERVAL
			var tick_dmg: float = pt["dps"] * pt["stacks"] * DOT_TICK_INTERVAL
			var health: Node = EngineAPI.get_component(target, "health")
			if health and health.has_method("take_damage"):
				health.take_damage(tick_dmg, hero, 3)  # DamageType.NATURE
		if pt["remaining"] <= 0:
			poison_remove.append(eid)
	for eid in poison_remove:
		_poison_timer.erase(eid)

# === 事件处理 ===

func _on_entity_destroyed(data: Dictionary) -> void:
	var entity: Node2D = data.get("entity")
	if entity == null:
		return

	if entity == hero:
		# 时间领主：死亡回溯
		if bool(EngineAPI.get_variable("hero_death_rewind", false)):
			EngineAPI.set_variable("hero_death_rewind", false)  # 一次性
			var hero_health: Node = EngineAPI.get_component(hero, "health")
			if hero_health:
				hero_health.current_hp = hero_health.max_hp
				EngineAPI.show_message("TIME REWIND! Death prevented!")
				return
		_defeat(tr("HERO_FALLEN"))
	elif entity == player_fountain:
		_defeat(tr("FOUNTAIN_DESTROYED"))
	elif entity == enemy_fountain:
		_victory(tr("DARK_FOUNTAIN_DESTROYED"))

	# 击杀效果（仅英雄击杀敌人时）
	if entity is GameEntity and (entity as GameEntity).has_tag("enemy"):
		# 击杀回血
		var kill_heal: float = float(EngineAPI.get_variable("hero_kill_heal_pct", 0.0))
		if kill_heal > 0 and hero and is_instance_valid(hero):
			var hh: Node = EngineAPI.get_component(hero, "health")
			if hh and hh.has_method("heal"):
				hh.heal(hh.max_hp * kill_heal, hero)
		# 永久伤害加成
		var perm_dmg: float = float(EngineAPI.get_variable("hero_permanent_damage_per_kill", 0.0))
		if perm_dmg > 0 and hero and is_instance_valid(hero):
			var input_comp: Node = EngineAPI.get_component(hero, "player_input")
			if input_comp:
				input_comp.projectile_damage += input_comp.projectile_damage * perm_dmg

func _on_resource_changed(data: Dictionary) -> void:
	var res: String = data.get("resource", "")
	if res == "xp":
		_check_level_up()

func _victory(reason: String) -> void:
	if EngineAPI.get_game_state() != "playing":
		return
	EngineAPI.set_game_state("victory")
	EngineAPI.show_message("VICTORY! %s" % reason)
	emit("game_victory", {"reason": reason})

func _defeat(reason: String) -> void:
	if EngineAPI.get_game_state() != "playing":
		return
	EngineAPI.set_game_state("defeat")
	EngineAPI.show_message("DEFEAT! %s" % reason)
	emit("game_defeat", {"reason": reason})

func _check_level_up() -> void:
	var current_xp: float = EngineAPI.get_resource("xp")
	if current_xp >= _xp_to_next:
		EngineAPI.subtract_resource("xp", _xp_to_next)
		_hero_level += 1
		EngineAPI.set_resource("hero_level", _hero_level)
		_xp_to_next = XP_PER_LEVEL_BASE + (_hero_level - 1) * XP_PER_LEVEL_GROWTH
		emit("hero_level_up", {"level": _hero_level})
		# 升级特效
		if hero and is_instance_valid(hero):
			var vfx: Node = EngineAPI.get_system("vfx")
			if vfx:
				vfx.call("spawn_vfx", "level_up", hero.global_position)
				vfx.call("play_sfx", "level_up", -5.0)
		_show_card_selection()

# === 卡片3选1 ===

func _show_card_selection() -> void:
	if _card_manager == null:
		return
	var choices: Array[Dictionary] = _card_manager.draw_three()
	if choices.is_empty():
		EngineAPI.show_message("Level Up! Lv.%d (No cards available)" % _hero_level)
		return

	# 暂停游戏
	get_tree().paused = true

	# 创建选卡UI
	var ui_layer: CanvasLayer = get_tree().current_scene.get_node_or_null("UI")
	if ui_layer == null:
		get_tree().paused = false
		return

	_card_select_ui = Control.new()
	_card_select_ui.process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时也能交互
	_card_select_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(_card_select_ui)

	# 半透明背景
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_select_ui.add_child(overlay)

	# 居中容器
	var center_vbox := VBoxContainer.new()
	center_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 15)
	_card_select_ui.add_child(center_vbox)

	# 标题
	var title := Label.new()
	title.text = tr("LEVEL_UP").format([_hero_level]) + " - " + tr("CHOOSE_CARD")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	center_vbox.add_child(title)

	# 卡片数量提示
	var slot_hint := Label.new()
	slot_hint.text = tr("CARDS_COUNT").format([_card_manager.get_card_count(), RogueCardManager.MAX_CARDS])
	slot_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_hint.add_theme_font_size_override("font_size", 14)
	slot_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	center_vbox.add_child(slot_hint)

	# 3张卡片
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_child(hbox)

	var is_full := _card_manager.is_full()
	for card in choices:
		var card_btn := _create_card_button(card, is_full)
		hbox.add_child(card_btn)

	# 卡满时：显示当前持有卡片 + 替换提示
	if is_full:
		var replace_hint := Label.new()
		replace_hint.text = tr("CARDS_FULL_HINT")
		replace_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		replace_hint.add_theme_font_size_override("font_size", 13)
		replace_hint.add_theme_color_override("font_color", Color(1, 0.6, 0.3))
		center_vbox.add_child(replace_hint)

		# 显示当前持有的卡片供替换
		var held_hbox := HBoxContainer.new()
		held_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		held_hbox.add_theme_constant_override("separation", 8)
		center_vbox.add_child(held_hbox)

		var held_cards: Array[String] = _card_manager.get_held_cards()
		for held_id in held_cards:
			var held_data: Dictionary = _card_manager.get_card_data(held_id)
			var held_btn := Button.new()
			var held_name_key: String = held_data.get("name_key", held_id)
			held_btn.text = "X " + tr(held_name_key)
			held_btn.add_theme_font_size_override("font_size", 11)
			held_btn.custom_minimum_size = Vector2(100, 30)
			held_btn.name = "HeldCard_%s" % held_id
			held_hbox.add_child(held_btn)

	# 跳过按钮
	var skip_btn := Button.new()
	skip_btn.text = tr("SKIP")
	skip_btn.custom_minimum_size = Vector2(120, 35)
	skip_btn.pressed.connect(_on_card_skipped)
	center_vbox.add_child(skip_btn)

var _pending_card_id: String = ""  # 卡满时暂存要添加的卡

func _on_card_skipped() -> void:
	_pending_card_id = ""
	if _card_select_ui:
		_card_select_ui.queue_free()
		_card_select_ui = null
	get_tree().paused = false

func _connect_replace_buttons(node: Node) -> void:
	if node.name.begins_with("HeldCard_"):
		var held_id: String = node.name.substr(9)  # "HeldCard_xxx" → "xxx"
		if not node.is_connected("pressed", _on_replace_card):
			node.pressed.connect(_on_replace_card.bind(held_id))
	for child in node.get_children():
		_connect_replace_buttons(child)

func _on_replace_card(replace_id: String) -> void:
	if _pending_card_id == "" or _card_manager == null:
		return
	# 移除旧卡
	_card_manager.remove_card(replace_id)
	# 添加新卡
	var result: Dictionary = _card_manager.select_card(_pending_card_id)
	var card_data: Dictionary = _card_manager.get_card_data(_pending_card_id)
	_apply_card_effects(card_data)

	if result.get("set_completed", "") != "":
		var set_id: String = result["set_completed"]
		var set_data: Dictionary = _card_manager.get_set_data(set_id)
		_apply_set_bonus(set_data)
		EngineAPI.show_message(tr("SET_COMPLETE").format([set_data.get("name", set_id)]))
	else:
		var name_key: String = card_data.get("name_key", _pending_card_id)
		EngineAPI.show_message(tr("LEVEL_UP").format([_hero_level]) + ": " + tr(name_key))

	_pending_card_id = ""
	if _card_select_ui:
		_card_select_ui.queue_free()
		_card_select_ui = null
	get_tree().paused = false
	emit("card_selected", {"card_id": _pending_card_id, "level": _hero_level})

func _create_card_button(card: Dictionary, _is_full: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 280)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# 卡名（翻译）
	var name_label := Label.new()
	var name_key: String = card.get("name_key", card.get("name", "???"))
	name_label.text = tr(name_key) if name_key.begins_with("CARD_") else name_key
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_label)

	# 套装归属 + 收集进度 + 套装效果
	var set_id: String = card.get("set_id", "")
	var set_tr_key := "SET_%s" % set_id.to_upper()
	var set_label := Label.new()
	if set_id != "" and _card_manager:
		var set_data: Dictionary = _card_manager.get_set_data(set_id)
		var set_cards: Array = set_data.get("cards", [])
		var held: Array[String] = _card_manager.get_held_cards()
		var owned := 0
		for sc in set_cards:
			if str(sc) in held:
				owned += 1
		var total: int = set_cards.size()
		set_label.text = "[%s] (%d/%d)" % [tr(set_tr_key), owned, total]

		# 套装效果描述
		if set_data.has("set_bonus"):
			var bonus: Dictionary = set_data["set_bonus"]
			var bonus_type: String = bonus.get("type", "")
			if bonus_type != "":
				var bonus_desc := Label.new()
				bonus_desc.text = tr("SET_BONUS") + ": " + bonus_type
				bonus_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				bonus_desc.add_theme_font_size_override("font_size", 10)
				# 集齐则金色，未集齐灰色
				if owned + 1 >= total:  # +1 因为当前卡还没加入
					bonus_desc.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
				else:
					bonus_desc.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
				vbox.add_child(bonus_desc)
	else:
		set_label.text = ""
	set_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_label.add_theme_font_size_override("font_size", 12)
	set_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1))
	vbox.add_child(set_label)

	# 稀有度（翻译）
	var rarity: String = card.get("rarity", "common")
	var rarity_color := Color.WHITE
	match rarity:
		"common": rarity_color = Color(0.7, 0.7, 0.7)
		"uncommon": rarity_color = Color(0.3, 0.7, 1)
		"rare": rarity_color = Color(0.7, 0.3, 1)
		"legendary": rarity_color = Color(1, 0.8, 0.2)
	var rarity_label := Label.new()
	rarity_label.text = tr(rarity.to_upper())
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 11)
	rarity_label.add_theme_color_override("font_color", rarity_color)
	vbox.add_child(rarity_label)

	# 描述（翻译）
	var desc_label := Label.new()
	var desc_key: String = card.get("desc_key", card.get("description", ""))
	desc_label.text = tr(desc_key) if desc_key.begins_with("CARD_") else desc_key
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(220, 0)
	vbox.add_child(desc_label)

	# 间距
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# 选择按钮
	var btn := Button.new()
	btn.text = tr("PICK")
	btn.custom_minimum_size = Vector2(0, 40)
	var card_id: String = card.get("id", "")
	btn.pressed.connect(_on_card_picked.bind(card_id))
	vbox.add_child(btn)

	return panel

func _on_card_picked(card_id: String) -> void:
	if _card_manager == null:
		return
	# 卡满时：先选中新卡，然后需要点击已持有的卡来替换
	if _card_manager.is_full():
		_pending_card_id = card_id
		# 连接持有卡的替换按钮
		if _card_select_ui:
			for node in _card_select_ui.get_children():
				_connect_replace_buttons(node)
		return

	var result: Dictionary = _card_manager.select_card(card_id)
	var card_data: Dictionary = _card_manager.get_card_data(card_id)

	# 应用卡片效果
	_apply_card_effects(card_data)

	if result.get("set_completed", "") != "":
		var set_id: String = result["set_completed"]
		var set_data: Dictionary = _card_manager.get_set_data(set_id)
		_apply_set_bonus(set_data)
		EngineAPI.show_message(tr("SET_COMPLETE").format([set_data.get("name", set_id)]))
	else:
		EngineAPI.show_message(tr("LEVEL_UP").format([_hero_level]) + ": " + card_data.get("name", card_id))

	# 关闭选卡UI，恢复游戏
	if _card_select_ui:
		_card_select_ui.queue_free()
		_card_select_ui = null
	get_tree().paused = false

	emit("card_selected", {"card_id": card_id, "level": _hero_level})

func _apply_card_effects(card: Dictionary) -> void:
	## 通过 SpellSystem 施放卡片对应的 spell
	if hero == null or not is_instance_valid(hero):
		return
	var spell_id: String = card.get("spell_id", "")
	if spell_id != "":
		EngineAPI.cast_spell(spell_id, hero, hero)
		print("[Cards] Cast spell: %s (from card %s)" % [spell_id, card.get("id", "")])
	else:
		# 兼容旧格式：直接读 effects 数组存入变量
		var effects: Array = card.get("effects", [])
		for effect in effects:
			if not effect is Dictionary:
				continue
			var stat: String = effect.get("stat", "")
			var value: float = effect.get("value", 0.0)
			var var_key := "hero_" + stat
			var current: float = float(EngineAPI.get_variable(var_key, 0.0))
			EngineAPI.set_variable(var_key, current + value)
			# 攻速特殊处理
			if stat == "attack_speed_pct":
				var input_comp: Node = EngineAPI.get_component(hero, "player_input")
				if input_comp:
					input_comp.shoot_cooldown *= (1.0 / (1.0 + value))
		print("[Cards] Applied legacy effects from: %s" % card.get("id", ""))

func _apply_set_bonus(set_data: Dictionary) -> void:
	## 通过 SpellSystem 施放套装 bonus spell
	if hero == null or not is_instance_valid(hero):
		return
	var bonus_spell: String = set_data.get("bonus_spell", "")
	if bonus_spell != "":
		EngineAPI.cast_spell(bonus_spell, hero, hero)
		print("[Cards] Set bonus spell: %s (set %s)" % [bonus_spell, set_data.get("id", "")])
	else:
		# 兼容旧格式：直接读 set_bonus 存入变量
		var bonus: Dictionary = set_data.get("set_bonus", {})
		var btype: String = bonus.get("type", "")
		if btype == "stat_mod":
			var stats: Dictionary = bonus.get("stats", {})
			for stat_name in stats:
				EngineAPI.add_stat_modifier(hero, stat_name, {
					"type": "percent", "value": stats[stat_name], "source": set_data.get("id", "")
				})
		else:
			# 通用：把 bonus 的所有数值键存入 hero_ 变量
			for key in bonus:
				if key == "type":
					continue
				EngineAPI.set_variable("hero_" + key, bonus[key])
		print("[Cards] Set bonus (legacy): %s (%s)" % [set_data.get("id", ""), btype])

# === HUD ===

var _hp_label: Label = null
var _gold_label: Label = null
var _wave_label: Label = null
var _timer_label: Label = null
var _xp_label: Label = null
var _level_label: Label = null
var _pfountain_label: Label = null
var _efountain_label: Label = null
# 属性面板
var _str_label: Label = null
var _agi_label: Label = null
var _int_label: Label = null
var _sta_label: Label = null
var _def_label: Label = null
var _atk_label: Label = null
var _aspd_label: Label = null
var _range_label: Label = null
# 卡片栏
var _card_slots: Array[PanelContainer] = []
var _set_buff_container: HBoxContainer = null
# 战斗日志
var _combat_log: VBoxContainer = null
const MAX_LOG_LINES := 12

func _create_hud() -> void:
	var ui_layer: CanvasLayer = get_tree().current_scene.get_node_or_null("UI")
	if ui_layer == null:
		return
	for child in ui_layer.get_children():
		child.queue_free()

	# === 顶栏 ===
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_bottom = 36
	ui_layer.add_child(top_panel)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 18)
	top_panel.add_child(top_hbox)

	_hp_label = _hud_label(top_hbox, "HP: --", 13)
	_pfountain_label = _hud_label(top_hbox, tr("OUR_FOUNTAIN") + ": --", 13)
	_efountain_label = _hud_label(top_hbox, tr("ENEMY_FOUNTAIN") + ": --", 13)
	_gold_label = _hud_label(top_hbox, tr("GOLD") + ": 0", 13)
	_level_label = _hud_label(top_hbox, "Lv.1", 13)
	_xp_label = _hud_label(top_hbox, "XP: 0/%d" % _xp_to_next, 13)
	_wave_label = _hud_label(top_hbox, tr("WAVE") + ": 0/%d" % TOTAL_WAVES, 13)
	_timer_label = _hud_label(top_hbox, "0:00/10:00", 13)

	# === 右侧属性面板 ===
	var stat_panel := PanelContainer.new()
	stat_panel.anchor_left = 1.0
	stat_panel.anchor_right = 1.0
	stat_panel.anchor_top = 0.0
	stat_panel.anchor_bottom = 0.0
	stat_panel.offset_left = -155
	stat_panel.offset_top = 45
	stat_panel.offset_right = -5
	stat_panel.offset_bottom = 260
	ui_layer.add_child(stat_panel)

	var stat_vbox := VBoxContainer.new()
	stat_vbox.add_theme_constant_override("separation", 3)
	stat_panel.add_child(stat_vbox)

	var stat_title := Label.new()
	stat_title.text = tr("WARRIOR")  # 会被 _update_hud 覆盖为实际职业
	stat_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_title.add_theme_font_size_override("font_size", 14)
	stat_title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	stat_title.name = "ClassTitle"
	stat_vbox.add_child(stat_title)

	_str_label = _hud_label(stat_vbox, tr("STR") + ": 0", 12, Color(1, 0.4, 0.35))
	_agi_label = _hud_label(stat_vbox, tr("AGI") + ": 0", 12, Color(0.4, 1, 0.4))
	_int_label = _hud_label(stat_vbox, tr("INT") + ": 0", 12, Color(0.5, 0.6, 1))
	_sta_label = _hud_label(stat_vbox, tr("STA") + ": 0", 12, Color(1, 0.8, 0.3))
	_def_label = _hud_label(stat_vbox, tr("DEF") + ": 0", 12, Color(0.6, 0.6, 0.7))

	var sep := HSeparator.new()
	stat_vbox.add_child(sep)

	_atk_label = _hud_label(stat_vbox, "DMG: --", 12)
	_aspd_label = _hud_label(stat_vbox, "SPD: --", 12)
	_range_label = _hud_label(stat_vbox, "RNG: --", 12)

	# === 底部卡片栏 ===
	var card_bar := HBoxContainer.new()
	card_bar.anchor_left = 0.5
	card_bar.anchor_right = 0.5
	card_bar.anchor_top = 1.0
	card_bar.anchor_bottom = 1.0
	card_bar.offset_left = -240
	card_bar.offset_top = -65
	card_bar.offset_right = 240
	card_bar.offset_bottom = -5
	card_bar.add_theme_constant_override("separation", 6)
	card_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	ui_layer.add_child(card_bar)

	_card_slots.clear()
	for i in range(6):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(72, 55)
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.15, 0.15, 0.2, 0.7)
		slot_style.corner_radius_top_left = 4
		slot_style.corner_radius_top_right = 4
		slot_style.corner_radius_bottom_left = 4
		slot_style.corner_radius_bottom_right = 4
		slot_style.border_color = Color(0.3, 0.3, 0.4, 0.5)
		slot_style.border_width_top = 1
		slot_style.border_width_bottom = 1
		slot_style.border_width_left = 1
		slot_style.border_width_right = 1
		slot.add_theme_stylebox_override("panel", slot_style)

		var slot_label := Label.new()
		slot_label.text = ""
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_label.add_theme_font_size_override("font_size", 10)
		slot_label.name = "SlotLabel"
		slot.add_child(slot_label)

		# Tooltip
		slot.tooltip_text = ""
		slot.mouse_filter = Control.MOUSE_FILTER_PASS

		card_bar.add_child(slot)
		_card_slots.append(slot)

	# === 套装 Buff 显示区域（左下角）===
	_set_buff_container = HBoxContainer.new()
	_set_buff_container.anchor_left = 0.0
	_set_buff_container.anchor_top = 1.0
	_set_buff_container.anchor_bottom = 1.0
	_set_buff_container.offset_left = 10
	_set_buff_container.offset_top = -60
	_set_buff_container.offset_right = 400
	_set_buff_container.offset_bottom = -5
	_set_buff_container.add_theme_constant_override("separation", 6)
	ui_layer.add_child(_set_buff_container)

	# === 战斗日志（左侧）===
	var log_panel := PanelContainer.new()
	log_panel.anchor_left = 0.0
	log_panel.anchor_top = 0.0
	log_panel.offset_left = 5
	log_panel.offset_top = 45
	log_panel.offset_right = 280
	log_panel.offset_bottom = 280
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0, 0, 0, 0.4)
	log_style.corner_radius_top_left = 4
	log_style.corner_radius_top_right = 4
	log_style.corner_radius_bottom_left = 4
	log_style.corner_radius_bottom_right = 4
	log_panel.add_theme_stylebox_override("panel", log_style)
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(log_panel)

	var log_scroll := ScrollContainer.new()
	log_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_panel.add_child(log_scroll)

	_combat_log = VBoxContainer.new()
	_combat_log.add_theme_constant_override("separation", 2)
	_combat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_scroll.add_child(_combat_log)

	# 监听战斗事件写日志
	EventBus.connect_event("entity_damaged", _on_log_damaged)
	EventBus.connect_event("entity_destroyed", _on_log_destroyed)
	EventBus.connect_event("spell_cast", _on_log_spell)
	EventBus.connect_event("aura_applied", _on_log_aura)
	EventBus.connect_event("proc_triggered", _on_log_proc)
	EventBus.connect_event("wave_started", _on_log_wave)

	# === 退出按钮 ===
	var back_btn := Button.new()
	back_btn.text = tr("QUIT")
	back_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	back_btn.offset_left = -80
	back_btn.offset_top = -40
	back_btn.pressed.connect(func() -> void: SceneManager.goto_scene("lobby"))
	ui_layer.add_child(back_btn)

func _hud_label(parent: Node, text: String, size: int = 13, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	if color != Color.WHITE:
		label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _update_hud() -> void:
	if _hp_label == null:
		return

	# --- 顶栏 ---
	if hero and is_instance_valid(hero):
		var health: Node = EngineAPI.get_component(hero, "health")
		if health:
			_hp_label.text = "HP: %d/%d" % [health.current_hp, health.max_hp]

	if player_fountain and is_instance_valid(player_fountain):
		var fh: Node = EngineAPI.get_component(player_fountain, "health")
		if fh:
			_pfountain_label.text = tr("OUR_FOUNTAIN") + ": %d" % int(fh.current_hp)
	else:
		_pfountain_label.text = tr("OUR_FOUNTAIN") + ": DEAD"

	if enemy_fountain and is_instance_valid(enemy_fountain):
		var eh: Node = EngineAPI.get_component(enemy_fountain, "health")
		if eh:
			_efountain_label.text = tr("ENEMY_FOUNTAIN") + ": %d" % int(eh.current_hp)
	else:
		_efountain_label.text = tr("ENEMY_FOUNTAIN") + ": DEAD"

	_gold_label.text = tr("GOLD") + ": %d" % int(EngineAPI.get_resource("gold"))
	_level_label.text = "Lv.%d" % _hero_level
	_xp_label.text = "XP: %d/%d" % [int(EngineAPI.get_resource("xp")), _xp_to_next]
	_wave_label.text = tr("WAVE") + ": %d/%d" % [_current_wave, TOTAL_WAVES]

	@warning_ignore("integer_division")
	var mins: int = int(_game_timer) / 60
	@warning_ignore("integer_division")
	var secs: int = int(_game_timer) % 60
	_timer_label.text = "%d:%02d/10:00" % [mins, secs]

	# --- 属性面板 ---
	if hero and is_instance_valid(hero) and hero is GameEntity:
		var entity := hero as GameEntity
		var m: Dictionary = entity.meta
		var lvl := _hero_level - 1
		var s: int = m.get("base_str", 5) + lvl * m.get("level_str", 1)
		var a: int = m.get("base_agi", 5) + lvl * m.get("level_agi", 1)
		var i: int = m.get("base_int", 5) + lvl * m.get("level_int", 1)
		var st: int = m.get("base_sta", 5) + lvl * m.get("level_sta", 1)
		var d: int = m.get("base_def", 3) + lvl * m.get("level_def", 1)
		_str_label.text = tr("STR") + ": %d" % s
		_agi_label.text = tr("AGI") + ": %d" % a
		_int_label.text = tr("INT") + ": %d" % i
		_sta_label.text = tr("STA") + ": %d" % st
		_def_label.text = tr("DEF") + ": %d" % d

		var input_comp: Node = EngineAPI.get_component(hero, "player_input")
		if input_comp:
			_atk_label.text = "DMG: %d" % int(input_comp.projectile_damage)
			_aspd_label.text = "SPD: %.2fs" % input_comp.shoot_cooldown
			_range_label.text = "RNG: %d" % int(input_comp.attack_range)

		# 职业标题
		var class_title := _str_label.get_parent().get_node_or_null("ClassTitle")
		if class_title:
			var cls_key: String = str(EngineAPI.get_variable("hero_class", "warrior")).to_upper()
			class_title.text = tr(cls_key)

	# --- 卡片栏 + Tooltip ---
	if _card_manager:
		var held: Array[String] = _card_manager.get_held_cards()
		for slot_idx in range(6):
			var slot_label: Label = _card_slots[slot_idx].get_node("SlotLabel")
			if slot_idx < held.size():
				var card_data: Dictionary = _card_manager.get_card_data(held[slot_idx])
				var name_key: String = card_data.get("name_key", held[slot_idx])
				var desc_key: String = card_data.get("desc_key", "")
				var set_id: String = card_data.get("set_id", "")
				slot_label.text = tr(name_key)
				slot_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
				# Tooltip: 名称 + 描述 + 套装归属
				var tip := tr(name_key)
				if desc_key != "":
					tip += "\n" + tr(desc_key)
				if set_id != "":
					tip += "\n[" + tr("SET_" + set_id.to_upper()) + "]"
				_card_slots[slot_idx].tooltip_text = tip
			else:
				slot_label.text = ""
				_card_slots[slot_idx].tooltip_text = ""

		# --- 套装 Buff 显示 ---
		if _set_buff_container:
			var completed: Array[String] = _card_manager.get_completed_sets()
			# 只在数量变化时重建
			if _set_buff_container.get_child_count() != completed.size():
				for child in _set_buff_container.get_children():
					child.queue_free()
				for set_id in completed:
					var set_data: Dictionary = _card_manager.get_set_data(set_id)
					var buff_panel := PanelContainer.new()
					buff_panel.custom_minimum_size = Vector2(50, 50)
					var buff_style := StyleBoxFlat.new()
					buff_style.bg_color = Color(0.2, 0.15, 0.3, 0.8)
					buff_style.corner_radius_top_left = 4
					buff_style.corner_radius_top_right = 4
					buff_style.corner_radius_bottom_left = 4
					buff_style.corner_radius_bottom_right = 4
					buff_style.border_color = Color(0.6, 0.4, 0.8, 0.6)
					buff_style.border_width_top = 2
					buff_style.border_width_bottom = 2
					buff_style.border_width_left = 2
					buff_style.border_width_right = 2
					buff_panel.add_theme_stylebox_override("panel", buff_style)
					buff_panel.mouse_filter = Control.MOUSE_FILTER_PASS

					var buff_label := Label.new()
					var set_tr_key := "SET_" + set_id.to_upper()
					buff_label.text = tr(set_tr_key)
					buff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					buff_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					buff_label.add_theme_font_size_override("font_size", 9)
					buff_label.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
					buff_panel.add_child(buff_label)

					# Buff tooltip: 套装名 + 效果类型
					var bonus: Dictionary = set_data.get("set_bonus", {})
					var tip := tr(set_tr_key) + " (" + tr("SET_COMPLETE").format([""]).strip_edges() + ")"
					tip += "\n" + str(bonus.get("type", ""))
					buff_panel.tooltip_text = tip

					_set_buff_container.add_child(buff_panel)

# === 战斗日志 ===

func _add_log(text: String, color: Color = Color(0.7, 0.7, 0.8)) -> void:
	if _combat_log == null:
		return
	while _combat_log.get_child_count() >= MAX_LOG_LINES:
		_combat_log.get_child(0).queue_free()
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_log.add_child(label)

func _get_entity_name(entity: Variant) -> String:
	if entity == null or not is_instance_valid(entity):
		return "?"
	if entity is GameEntity:
		return (entity as GameEntity).def_id
	return "?"

func _on_log_damaged(data: Dictionary) -> void:
	var target_name: String = _get_entity_name(data.get("entity"))
	var source_name: String = _get_entity_name(data.get("source"))
	var amount: float = data.get("amount", 0)
	var dt: int = data.get("damage_type", 0)
	var school_names := ["Physical", "Frost", "Fire", "Nature", "Shadow", "Holy"]
	var school_colors := [Color.WHITE, Color(0.4, 0.8, 1), Color(1, 0.5, 0.2), Color(0.3, 0.9, 0.3), Color(0.6, 0.3, 0.9), Color(1, 0.9, 0.4)]
	var sn: String = school_names[dt] if dt < school_names.size() else "?"
	var sc: Color = school_colors[dt] if dt < school_colors.size() else Color.WHITE
	_add_log("%s -> %s: %d %s" % [source_name, target_name, int(amount), sn], sc)

func _on_log_destroyed(data: Dictionary) -> void:
	var name_str: String = _get_entity_name(data.get("entity"))
	_add_log("[KILLED] %s" % name_str, Color(1, 0.3, 0.2))

func _on_log_spell(data: Dictionary) -> void:
	var caster_name: String = _get_entity_name(data.get("caster"))
	var spell_id: String = data.get("spell_id", "")
	_add_log("[SPELL] %s cast %s" % [caster_name, spell_id], Color(0.5, 0.7, 1))

func _on_log_aura(data: Dictionary) -> void:
	var target_name: String = _get_entity_name(data.get("target"))
	var aura_type: String = data.get("aura_type", "")
	_add_log("[AURA] %s <- %s" % [target_name, aura_type], Color(0.7, 0.5, 1))

func _on_log_proc(data: Dictionary) -> void:
	var action: String = data.get("action", "")
	var spell: String = data.get("trigger_spell", "")
	_add_log("[PROC] %s -> %s" % [action, spell], Color(1, 0.8, 0.3))

func _on_log_wave(data: Dictionary) -> void:
	var wave_idx: int = data.get("wave_index", 0)
	var count: int = data.get("enemy_count", 0)
	_add_log("=== WAVE %d (%d enemies) ===" % [wave_idx, count], Color(1, 1, 0.5))
