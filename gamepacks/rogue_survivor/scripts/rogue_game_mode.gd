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
	var target: Node2D = data.get("target")
	var source: Node2D = data.get("source")
	var base_damage: float = data.get("damage", 0)
	if target == null or source != hero:
		return
	if not is_instance_valid(target):
		return

	# --- 暴击 ---
	var crit_chance: float = float(EngineAPI.get_variable("hero_crit_chance", 0.0))
	if crit_chance > 0 and randf() < crit_chance:
		var crit_mult := 1.5 + float(EngineAPI.get_variable("hero_crit_damage_bonus", 0.0))
		var bonus_dmg := base_damage * (crit_mult - 1.0)
		var health: Node = EngineAPI.get_component(target, "health")
		if health and health.has_method("take_damage"):
			health.take_damage(bonus_dmg, source)

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

	# --- 减速 ---
	var slow_chance: float = float(EngineAPI.get_variable("hero_slow_chance", 0.0))
	if slow_chance > 0 and randf() < slow_chance:
		var slow_pct: float = float(EngineAPI.get_variable("hero_slow_pct", 0.2))
		# 直接减速 movement 组件
		var movement: Node = EngineAPI.get_component(target, "movement")
		if movement and movement.has_method("add_speed_modifier"):
			var mod_id := "slow_%d" % (randi() % 99999)
			movement.add_speed_modifier(mod_id, 1.0 - slow_pct)
			# 2秒后移除
			get_tree().create_timer(2.0).timeout.connect(func() -> void:
				if is_instance_valid(target) and movement:
					movement.remove_speed_modifier(mod_id)
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
			var dir := target.global_position.direction_to(e.global_position)
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

func _process_dot_effects(delta: float) -> void:
	# 燃烧 DoT
	var burn_remove: Array = []
	for eid in _burn_timer:
		var bt: Dictionary = _burn_timer[eid]
		var target = bt.get("target")  # Variant: 避免强类型赋值已释放实例
		if target == null or not is_instance_valid(target):
			burn_remove.append(eid)
			continue
		bt["remaining"] -= delta
		var health: Node = EngineAPI.get_component(target, "health")
		if health and health.has_method("take_damage"):
			health.take_damage(bt["dps"] * delta, hero)
		if bt["remaining"] <= 0:
			burn_remove.append(eid)
	for eid in burn_remove:
		_burn_timer.erase(eid)

	# 中毒 DoT
	var poison_remove: Array = []
	for eid in _poison_timer:
		var pt: Dictionary = _poison_timer[eid]
		var target = pt.get("target")  # Variant
		if target == null or not is_instance_valid(target):
			poison_remove.append(eid)
			continue
		pt["remaining"] -= delta
		var health: Node = EngineAPI.get_component(target, "health")
		if health and health.has_method("take_damage"):
			var total_dps: float = pt["dps"] * pt["stacks"]
			health.take_damage(total_dps * delta, hero)
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
		_defeat("Hero has fallen!")
	elif entity == player_fountain:
		_defeat("Life Fountain destroyed!")
	elif entity == enemy_fountain:
		_victory("Dark Fountain destroyed!")

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

	for card in choices:
		var card_btn := _create_card_button(card)
		hbox.add_child(card_btn)

func _create_card_button(card: Dictionary) -> PanelContainer:
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

	# 套装归属（翻译）
	var set_id: String = card.get("set_id", "")
	var set_tr_key := "SET_%s" % set_id.to_upper()
	var set_label := Label.new()
	set_label.text = "[%s]" % tr(set_tr_key)
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
	## 统一处理：所有效果都写入 hero_xxx 变量 + 直接修改组件
	if hero == null or not is_instance_valid(hero):
		return
	var effects: Array = card.get("effects", [])
	for effect in effects:
		if not effect is Dictionary:
			continue
		var stat: String = effect.get("stat", "")
		var value: float = effect.get("value", 0.0)

		# 所有效果统一存入 hero_ 前缀变量（累加）
		var var_key := "hero_" + stat
		var current: float = float(EngineAPI.get_variable(var_key, 0.0))
		EngineAPI.set_variable(var_key, current + value)

		# 特殊效果：直接修改组件属性
		match stat:
			"attack_speed_pct":
				# 减少射击冷却时间
				var input_comp: Node = EngineAPI.get_component(hero, "player_input")
				if input_comp:
					input_comp.shoot_cooldown *= (1.0 / (1.0 + value))
			"extra_projectiles":
				pass  # 射击时读取变量
			"spread_angle":
				pass  # 射击时读取变量

	var card_name: String = card.get("name_key", card.get("id", ""))
	print("[Cards] Applied: %s | Variables: pierce=%s split=%s ignite=%s slow=%s lifesteal=%s crit=%s proj=%s" % [
		card_name,
		EngineAPI.get_variable("hero_pierce_chance", 0),
		EngineAPI.get_variable("hero_split_chance", 0),
		EngineAPI.get_variable("hero_ignite_chance", 0),
		EngineAPI.get_variable("hero_slow_chance", 0),
		EngineAPI.get_variable("hero_life_steal", 0),
		EngineAPI.get_variable("hero_crit_chance", 0),
		EngineAPI.get_variable("hero_extra_projectiles", 0),
	])

func _apply_set_bonus(set_data: Dictionary) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	var bonus: Dictionary = set_data.get("set_bonus", {})
	var btype: String = bonus.get("type", "")
	match btype:
		"pierce":
			EngineAPI.set_variable("hero_pierce_count", bonus.get("pierce_count", 3))
			EngineAPI.set_variable("hero_pierce_chance", bonus.get("pierce_chance", 1.0))
		"split":
			EngineAPI.set_variable("hero_split_chance", bonus.get("split_chance", 0.4))
			EngineAPI.set_variable("hero_split_count", bonus.get("split_count", 2))
			EngineAPI.set_variable("hero_split_damage_ratio", bonus.get("split_damage_ratio", 0.8))
		"stat_mod":
			var stats: Dictionary = bonus.get("stats", {})
			for stat_name in stats:
				EngineAPI.add_stat_modifier(hero, stat_name, {
					"type": "percent", "value": stats[stat_name], "source": set_data.get("id", "")
				})
		"multi_shot":
			EngineAPI.set_variable("hero_extra_projectiles", bonus.get("extra_projectiles", 2))
			EngineAPI.set_variable("hero_spread_angle", bonus.get("spread_angle", 15))
		"burn_spread":
			EngineAPI.set_variable("hero_ignite_chance", bonus.get("ignite_chance", 0.5))
			EngineAPI.set_variable("hero_burn_spread", true)
		"freeze_shatter":
			EngineAPI.set_variable("hero_slow_pct", bonus.get("slow_pct", 0.4))
			EngineAPI.set_variable("hero_freeze_shatter", true)
	print("[Cards] Set bonus applied: %s" % set_data.get("name", ""))

# === HUD ===

var _hp_label: Label = null
var _gold_label: Label = null
var _wave_label: Label = null
var _timer_label: Label = null
var _xp_label: Label = null
var _level_label: Label = null
var _pfountain_label: Label = null
var _efountain_label: Label = null

func _create_hud() -> void:
	var ui_layer: CanvasLayer = get_tree().current_scene.get_node_or_null("UI")
	if ui_layer == null:
		return
	for child in ui_layer.get_children():
		child.queue_free()

	# 顶栏
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 40
	ui_layer.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)

	_hp_label = _hud_label(hbox, "HP: 150/150")
	_pfountain_label = _hud_label(hbox, "Our Fountain: 500")
	_efountain_label = _hud_label(hbox, "Enemy Fountain: 800")
	_gold_label = _hud_label(hbox, "Gold: 0")
	_level_label = _hud_label(hbox, "Lv.1")
	_xp_label = _hud_label(hbox, "XP: 0/%d" % _xp_to_next)
	_wave_label = _hud_label(hbox, "Wave: 0/%d" % TOTAL_WAVES)
	_timer_label = _hud_label(hbox, "0:00/10:00")

	# 退出按钮
	var back_btn := Button.new()
	back_btn.text = tr("QUIT")
	back_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	back_btn.offset_left = -80
	back_btn.offset_top = -40
	back_btn.pressed.connect(func() -> void: SceneManager.goto_scene("lobby"))
	ui_layer.add_child(back_btn)

func _hud_label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)
	return label

func _update_hud() -> void:
	if _hp_label == null:
		return

	if hero and is_instance_valid(hero):
		var health: Node = EngineAPI.get_component(hero, "health")
		if health:
			_hp_label.text = "HP: %d/%d" % [health.current_hp, health.max_hp]

	if player_fountain and is_instance_valid(player_fountain):
		var fh: Node = EngineAPI.get_component(player_fountain, "health")
		if fh:
			_pfountain_label.text = "Our Fountain: %d" % int(fh.current_hp)
	else:
		_pfountain_label.text = "Our Fountain: DEAD"

	if enemy_fountain and is_instance_valid(enemy_fountain):
		var eh: Node = EngineAPI.get_component(enemy_fountain, "health")
		if eh:
			_efountain_label.text = "Enemy Fountain: %d" % int(eh.current_hp)
	else:
		_efountain_label.text = "Enemy Fountain: DEAD"

	_gold_label.text = "Gold: %d" % int(EngineAPI.get_resource("gold"))
	_level_label.text = "Lv.%d" % _hero_level
	_xp_label.text = "XP: %d/%d" % [int(EngineAPI.get_resource("xp")), _xp_to_next]
	_wave_label.text = "Wave: %d/%d" % [_current_wave, TOTAL_WAVES]

	@warning_ignore("integer_division")
	var mins: int = int(_game_timer) / 60
	@warning_ignore("integer_division")
	var secs: int = int(_game_timer) % 60
	_timer_label.text = "%d:%02d/10:00" % [mins, secs]
