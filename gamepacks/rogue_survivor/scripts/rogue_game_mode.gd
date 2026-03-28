## Rogue Survivor - 肉鸽生存射击主脚本
## 10分钟守护生命之泉，击杀怪物升级抽卡
extends GamePackScript

const ARENA_SIZE := Vector2(1600, 900)
const ARENA_CENTER := Vector2(800, 450)
const FOUNTAIN_POS := ARENA_CENTER
const SPAWN_MARGIN := 100.0
const GAME_DURATION := 600.0
const WAVE_INTERVAL := 20.0
const TOTAL_WAVES := 30
const XP_PER_LEVEL_BASE := 30
const XP_PER_LEVEL_GROWTH := 15

var hero: Node2D = null
var fountain: Node2D = null
var _game_timer: float = 0.0
var _wave_timer: float = 0.0
var _current_wave: int = 0
var _hero_level: int = 1
var _xp_to_next: int = XP_PER_LEVEL_BASE

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

func _pack_ready() -> void:
	listen("player_shoot", _on_player_shoot)
	listen("entity_destroyed", _on_entity_destroyed)
	listen("resource_changed", _on_resource_changed)
	listen("game_defeat", _on_game_defeat)

	_draw_arena()
	_create_hud()
	_spawn_fountain()
	_spawn_hero()

	EngineAPI.set_game_state("playing")
	_wave_timer = WAVE_INTERVAL - 3.0  # 3秒后第一波

func _pack_process(delta: float) -> void:
	_game_timer += delta
	_wave_timer += delta

	if _wave_timer >= WAVE_INTERVAL and _current_wave < TOTAL_WAVES:
		_spawn_wave()
		_wave_timer = 0.0

	if _game_timer >= GAME_DURATION:
		EngineAPI.set_game_state("victory")
		emit("game_victory", {})
		EngineAPI.show_message("Victory! You survived 10 minutes!")

	_update_hud()

	# 摄像机跟随英雄
	if hero and is_instance_valid(hero):
		var camera := get_viewport().get_camera_2d()
		if camera:
			camera.global_position = hero.global_position

# === 初始化 ===

func _draw_arena() -> void:
	# 关键：arena 必须在 EntitySystem 之前渲染
	# 找到 Main 节点（场景根），在最前面插入 arena
	var main_node: Node2D = get_parent().get_parent() as Node2D
	if main_node == null:
		main_node = get_parent() as Node2D

	var arena := Node2D.new()
	arena.name = "Arena"
	arena.z_index = -10  # 确保在所有实体下面
	main_node.add_child(arena)
	main_node.move_child(arena, 0)  # 移到最前面

	# 地板 - 深色
	var floor_rect := ColorRect.new()
	floor_rect.color = Color(0.08, 0.08, 0.12)
	floor_rect.position = Vector2.ZERO
	floor_rect.size = ARENA_SIZE
	arena.add_child(floor_rect)

	# 网格线（微弱，增加空间感）
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

	# 边界线 - 亮色
	var border := Line2D.new()
	border.points = PackedVector2Array([
		Vector2.ZERO, Vector2(ARENA_SIZE.x, 0),
		ARENA_SIZE, Vector2(0, ARENA_SIZE.y),
		Vector2.ZERO
	])
	border.default_color = Color(0.4, 0.5, 0.7)
	border.width = 3
	arena.add_child(border)

func _spawn_fountain() -> void:
	fountain = spawn("life_fountain", FOUNTAIN_POS)

func _spawn_hero() -> void:
	hero = spawn("hero", FOUNTAIN_POS + Vector2(0, 100))

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
				var pos := _random_spawn_position()
				spawn(enemy_id, pos)
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

func _random_spawn_position() -> Vector2:
	var side := randi() % 4
	match side:
		0: return Vector2(randf_range(0, ARENA_SIZE.x), -SPAWN_MARGIN)
		1: return Vector2(randf_range(0, ARENA_SIZE.x), ARENA_SIZE.y + SPAWN_MARGIN)
		2: return Vector2(-SPAWN_MARGIN, randf_range(0, ARENA_SIZE.y))
		_: return Vector2(ARENA_SIZE.x + SPAWN_MARGIN, randf_range(0, ARENA_SIZE.y))

# === 射击 ===

func _on_player_shoot(data: Dictionary) -> void:
	var pos: Vector2 = data.get("position", Vector2.ZERO)
	var dir: Vector2 = data.get("direction", Vector2.RIGHT)
	var spd: float = data.get("speed", 650.0)
	var dmg: float = data.get("damage", 12.0)
	var proj_id: String = data.get("projectile_id", "arrow")
	var shooter: Node2D = data.get("shooter", null)

	spawn(proj_id, pos, {
		"components": {
			"projectile": {
				"direction": dir,
				"speed": spd,
				"damage": dmg,
				"source": shooter,
				"target_tag": "enemy",
			}
		}
	})

# === 事件处理 ===

func _on_entity_destroyed(data: Dictionary) -> void:
	var entity: Node2D = data.get("entity")
	if entity == null:
		return
	if entity == hero:
		EngineAPI.set_game_state("defeat")
		emit("game_defeat", {"reason": "hero_died"})

func _on_resource_changed(data: Dictionary) -> void:
	var res: String = data.get("resource", "")
	if res == "xp":
		_check_level_up()

func _on_game_defeat(_data: Dictionary) -> void:
	EngineAPI.show_message("Game Over!")

func _check_level_up() -> void:
	var current_xp: float = EngineAPI.get_resource("xp")
	while current_xp >= _xp_to_next:
		EngineAPI.subtract_resource("xp", _xp_to_next)
		_hero_level += 1
		EngineAPI.set_resource("hero_level", _hero_level)
		_xp_to_next = XP_PER_LEVEL_BASE + (_hero_level - 1) * XP_PER_LEVEL_GROWTH
		emit("hero_level_up", {"level": _hero_level})
		EngineAPI.show_message("Level Up! Lv.%d" % _hero_level)
		current_xp = EngineAPI.get_resource("xp")

# === HUD ===

var _hp_label: Label = null
var _gold_label: Label = null
var _wave_label: Label = null
var _timer_label: Label = null
var _xp_label: Label = null
var _level_label: Label = null
var _fountain_hp_label: Label = null

func _create_hud() -> void:
	var ui_layer: CanvasLayer = get_parent().get_parent().get_node_or_null("UI")
	if ui_layer == null:
		return

	for child in ui_layer.get_children():
		child.queue_free()

	var panel := PanelContainer.new()
	panel.anchors_preset = Control.PRESET_TOP_WIDE
	panel.offset_bottom = 40
	ui_layer.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 30)
	panel.add_child(hbox)

	_hp_label = _hud_label(hbox, "HP: 150/150")
	_fountain_hp_label = _hud_label(hbox, "Fountain: 500/500")
	_gold_label = _hud_label(hbox, "Gold: 0")
	_level_label = _hud_label(hbox, "Lv.1")
	_xp_label = _hud_label(hbox, "XP: 0/%d" % _xp_to_next)
	_wave_label = _hud_label(hbox, "Wave: 0/%d" % TOTAL_WAVES)
	_timer_label = _hud_label(hbox, "Time: 0:00 / 10:00")

	var back_btn := Button.new()
	back_btn.text = "Quit"
	back_btn.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	back_btn.offset_left = -80
	back_btn.offset_top = -40
	back_btn.pressed.connect(func() -> void: SceneManager.goto_scene("lobby"))
	ui_layer.add_child(back_btn)

func _hud_label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	parent.add_child(label)
	return label

func _update_hud() -> void:
	if _hp_label == null:
		return

	if hero and is_instance_valid(hero):
		var health: Node = EngineAPI.get_component(hero, "health")
		if health:
			_hp_label.text = "HP: %d/%d" % [health.current_hp, health.max_hp]

	if fountain and is_instance_valid(fountain):
		var fh: Node = EngineAPI.get_component(fountain, "health")
		if fh:
			_fountain_hp_label.text = "Fountain: %d/%d" % [fh.current_hp, fh.max_hp]
	else:
		_fountain_hp_label.text = "Fountain: DESTROYED"

	_gold_label.text = "Gold: %d" % int(EngineAPI.get_resource("gold"))
	_level_label.text = "Lv.%d" % _hero_level
	_xp_label.text = "XP: %d/%d" % [int(EngineAPI.get_resource("xp")), _xp_to_next]
	_wave_label.text = "Wave: %d/%d" % [_current_wave, TOTAL_WAVES]

	var mins := int(_game_timer) / 60
	var secs := int(_game_timer) % 60
	_timer_label.text = "Time: %d:%02d / 10:00" % [mins, secs]
