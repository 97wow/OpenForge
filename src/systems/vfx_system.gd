## VFXSystem - 视觉特效系统（框架层）
## 通过代码生成粒子特效、闪电链、冲击波等
## GamePack 可调用 spawn_vfx() 或注册自定义特效
class_name VFXSystem
extends Node2D

var _vfx_handlers: Dictionary = {}
var _audio_cache: Dictionary = {}  # path -> AudioStream
var _audio_enabled: bool = true

func _ready() -> void:
	EngineAPI.register_system("vfx", self)
	_register_builtin_vfx()
	_preload_audio()
	# 监听战斗事件自动播放特效
	EventBus.connect_event("entity_damaged", _on_entity_damaged)
	EventBus.connect_event("entity_destroyed", _on_entity_destroyed)
	EventBus.connect_event("entity_healed", _on_entity_healed)
	EventBus.connect_event("spell_cast", _on_spell_cast)
	EventBus.connect_event("aura_applied", _on_aura_applied)

# === 公共 API ===

func spawn_vfx(vfx_type: String, pos: Vector2, data: Dictionary = {}) -> void:
	if _vfx_handlers.has(vfx_type):
		_vfx_handlers[vfx_type].call(pos, data)

func register_vfx(vfx_type: String, handler: Callable) -> void:
	_vfx_handlers[vfx_type] = handler

# === 内置特效注册 ===

func _register_builtin_vfx() -> void:
	register_vfx("hit_physical", _vfx_hit_physical)
	register_vfx("hit_fire", _vfx_hit_fire)
	register_vfx("hit_frost", _vfx_hit_frost)
	register_vfx("hit_nature", _vfx_hit_nature)
	register_vfx("hit_shadow", _vfx_hit_shadow)
	register_vfx("hit_holy", _vfx_hit_holy)
	register_vfx("death", _vfx_death)
	register_vfx("heal", _vfx_heal)
	register_vfx("level_up", _vfx_level_up)
	register_vfx("shockwave", _vfx_shockwave)
	register_vfx("lightning", _vfx_lightning)

# === 事件响应 ===

func _on_entity_damaged(data: Dictionary) -> void:
	var entity = data.get("entity")
	if entity == null or not is_instance_valid(entity):
		return
	var amount: float = data.get("amount", 0)
	var damage_type: int = data.get("damage_type", 0)
	var pos: Vector2 = (entity as Node2D).global_position

	# 根据伤害类型播放命中特效
	var vfx_name := "hit_physical"
	match damage_type:
		1: vfx_name = "hit_frost"
		2: vfx_name = "hit_fire"
		3: vfx_name = "hit_nature"
		4: vfx_name = "hit_shadow"
		5: vfx_name = "hit_holy"

	var size_mult := clampf(amount / 20.0, 0.5, 2.5)
	spawn_vfx(vfx_name, pos, {"size": size_mult})
	# 音效
	var sfx_name := "hit_physical"
	match damage_type:
		1: sfx_name = "hit_frost"
		2: sfx_name = "hit_fire"
		3: sfx_name = "hit_nature"
		4: sfx_name = "hit_shadow"
	_play_sfx(sfx_name)

func _on_entity_destroyed(data: Dictionary) -> void:
	var entity = data.get("entity")
	if entity == null or not is_instance_valid(entity):
		return
	spawn_vfx("death", (entity as Node2D).global_position)
	_play_sfx("death")

func _on_entity_healed(data: Dictionary) -> void:
	var entity = data.get("entity")
	if entity == null or not is_instance_valid(entity):
		return
	spawn_vfx("heal", (entity as Node2D).global_position)

func _on_spell_cast(data: Dictionary) -> void:
	var caster = data.get("caster")
	if caster == null or not is_instance_valid(caster):
		return
	# 施法闪光
	var pos: Vector2 = (caster as Node2D).global_position
	_spawn_flash(pos, Color(1, 1, 1, 0.3), 15.0)
	_play_sfx("shoot")

func _on_aura_applied(data: Dictionary) -> void:
	var target = data.get("target")
	var aura_type: String = data.get("aura_type", "")
	if target == null or not is_instance_valid(target):
		return
	var pos: Vector2 = (target as Node2D).global_position
	match aura_type:
		"PERIODIC_DAMAGE":
			_spawn_flash(pos, Color(1, 0.3, 0.1, 0.4), 20.0)
		"MOD_SPEED_SLOW":
			_spawn_flash(pos, Color(0.3, 0.7, 1, 0.4), 20.0)

# === 粒子特效工厂 ===

func _vfx_hit_physical(pos: Vector2, data: Dictionary) -> void:
	var size: float = data.get("size", 1.0)
	_spawn_particles(pos, {
		"amount": int(6 * size),
		"color": Color(1, 1, 1, 0.9),
		"color_end": Color(0.8, 0.8, 0.8, 0),
		"speed": 80 * size,
		"lifetime": 0.3,
		"size": 2.5,
		"gravity": Vector2(0, 50),
	})

func _vfx_hit_fire(pos: Vector2, data: Dictionary) -> void:
	var size: float = data.get("size", 1.0)
	_spawn_particles(pos, {
		"amount": int(10 * size),
		"color": Color(1, 0.6, 0.1, 0.95),
		"color_end": Color(1, 0.2, 0, 0),
		"speed": 60 * size,
		"lifetime": 0.5,
		"size": 3.5,
		"gravity": Vector2(0, -30),
	})

func _vfx_hit_frost(pos: Vector2, data: Dictionary) -> void:
	var size: float = data.get("size", 1.0)
	_spawn_particles(pos, {
		"amount": int(8 * size),
		"color": Color(0.4, 0.8, 1, 0.9),
		"color_end": Color(0.7, 0.9, 1, 0),
		"speed": 50 * size,
		"lifetime": 0.6,
		"size": 3.0,
		"gravity": Vector2(0, 10),
	})

func _vfx_hit_nature(pos: Vector2, data: Dictionary) -> void:
	var size: float = data.get("size", 1.0)
	_spawn_particles(pos, {
		"amount": int(8 * size),
		"color": Color(0.3, 0.9, 0.3, 0.9),
		"color_end": Color(0.1, 0.6, 0.1, 0),
		"speed": 40 * size,
		"lifetime": 0.7,
		"size": 2.5,
		"gravity": Vector2(0, -20),
	})

func _vfx_hit_shadow(pos: Vector2, data: Dictionary) -> void:
	var size: float = data.get("size", 1.0)
	_spawn_particles(pos, {
		"amount": int(10 * size),
		"color": Color(0.6, 0.2, 0.9, 0.9),
		"color_end": Color(0.3, 0.1, 0.5, 0),
		"speed": 70 * size,
		"lifetime": 0.4,
		"size": 3.0,
		"gravity": Vector2.ZERO,
	})

func _vfx_hit_holy(pos: Vector2, data: Dictionary) -> void:
	var size: float = data.get("size", 1.0)
	_spawn_particles(pos, {
		"amount": int(12 * size),
		"color": Color(1, 0.9, 0.4, 0.95),
		"color_end": Color(1, 1, 0.7, 0),
		"speed": 55 * size,
		"lifetime": 0.5,
		"size": 3.0,
		"gravity": Vector2(0, -40),
	})

func _vfx_death(pos: Vector2, _data: Dictionary) -> void:
	_spawn_particles(pos, {
		"amount": 20,
		"color": Color(1, 0.3, 0.2, 0.9),
		"color_end": Color(0.5, 0.1, 0.1, 0),
		"speed": 100,
		"lifetime": 0.6,
		"size": 3.0,
		"gravity": Vector2(0, 80),
		"spread": 180,
	})

func _vfx_heal(pos: Vector2, _data: Dictionary) -> void:
	_spawn_particles(pos, {
		"amount": 8,
		"color": Color(0.3, 1, 0.4, 0.8),
		"color_end": Color(0.5, 1, 0.6, 0),
		"speed": 30,
		"lifetime": 0.8,
		"size": 3.0,
		"gravity": Vector2(0, -50),
		"spread": 30,
	})

func _vfx_level_up(pos: Vector2, _data: Dictionary) -> void:
	_spawn_particles(pos, {
		"amount": 30,
		"color": Color(1, 0.85, 0.2, 1),
		"color_end": Color(1, 0.7, 0, 0),
		"speed": 80,
		"lifetime": 1.0,
		"size": 4.0,
		"gravity": Vector2(0, -60),
		"spread": 180,
	})
	_spawn_ring(pos, Color(1, 0.85, 0.3, 0.6), 50, 0.8)

func _vfx_shockwave(pos: Vector2, data: Dictionary) -> void:
	var radius: float = data.get("radius", 150)
	_spawn_ring(pos, Color(1, 0.9, 0.5, 0.7), radius, 0.5)
	_spawn_particles(pos, {
		"amount": 15,
		"color": Color(1, 0.9, 0.4, 0.8),
		"color_end": Color(1, 0.8, 0.3, 0),
		"speed": 120,
		"lifetime": 0.4,
		"size": 3.0,
		"gravity": Vector2.ZERO,
		"spread": 180,
	})

func _vfx_lightning(pos: Vector2, data: Dictionary) -> void:
	var target_pos: Vector2 = data.get("target_pos", pos + Vector2(100, 0))
	_spawn_lightning_bolt(pos, target_pos, Color(0.5, 0.7, 1, 0.9))

# === 底层生成器 ===

func _spawn_particles(pos: Vector2, config: Dictionary) -> void:
	var particles := CPUParticles2D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = config.get("amount", 8)
	particles.lifetime = config.get("lifetime", 0.5)
	particles.speed_scale = 1.5

	# 方向和扩散
	particles.direction = Vector2(0, -1)
	particles.spread = config.get("spread", 90.0)
	particles.initial_velocity_min = config.get("speed", 50) * 0.5
	particles.initial_velocity_max = config.get("speed", 50)
	particles.gravity = config.get("gravity", Vector2.ZERO)

	# 大小
	var base_size: float = config.get("size", 3.0)
	particles.scale_amount_min = base_size * 0.5
	particles.scale_amount_max = base_size

	# 颜色
	var color_start: Color = config.get("color", Color.WHITE)
	var color_end: Color = config.get("color_end", Color(1, 1, 1, 0))
	var gradient := Gradient.new()
	gradient.set_color(0, color_start)
	gradient.set_color(1, color_end)
	particles.color_ramp = gradient

	add_child(particles)
	# 自动清理
	get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)

func _spawn_flash(pos: Vector2, color: Color, radius: float) -> void:
	var flash := Node2D.new()
	flash.position = pos
	flash.z_index = 40
	var flash_color := color
	var flash_radius := radius
	flash.draw.connect(func() -> void:
		flash.draw_circle(Vector2.ZERO, flash_radius, flash_color)
	)
	flash.queue_redraw()
	add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.tween_callback(flash.queue_free)

func _spawn_ring(pos: Vector2, color: Color, max_radius: float, duration: float) -> void:
	var ring := Node2D.new()
	ring.position = pos
	ring.z_index = 35
	var current_radius := 5.0
	var ring_color := color
	ring.set_meta("radius", current_radius)
	ring.draw.connect(func() -> void:
		var r: float = ring.get_meta("radius")
		ring.draw_arc(Vector2.ZERO, r, 0, TAU, 32, ring_color, 2.5)
	)
	ring.queue_redraw()
	add_child(ring)

	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(val: float) -> void:
		if is_instance_valid(ring):
			ring.set_meta("radius", val)
			ring.queue_redraw()
	, 5.0, max_radius, duration)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(ring):
			ring.queue_free()
	)

func _spawn_lightning_bolt(from_pos: Vector2, to_pos: Vector2, color: Color) -> void:
	var bolt := Line2D.new()
	bolt.z_index = 45
	bolt.width = 2.5
	bolt.default_color = color

	# 生成锯齿形闪电路径
	var points: PackedVector2Array = []
	var segments := 8
	var dir: Vector2 = (to_pos - from_pos)
	var step: Vector2 = dir / segments
	var perp: Vector2 = Vector2(-dir.y, dir.x).normalized()

	points.append(from_pos)
	for i in range(1, segments):
		var base: Vector2 = from_pos + step * i
		var offset: float = randf_range(-15, 15)
		points.append(base + perp * offset)
	points.append(to_pos)

	bolt.points = points
	add_child(bolt)

	var tween := bolt.create_tween()
	tween.tween_property(bolt, "modulate:a", 0.0, 0.25)
	tween.tween_callback(bolt.queue_free)

# === 音频系统 ===

func _preload_audio() -> void:
	var audio_dir := "res://assets/audio/"
	var files := ["hit_physical", "hit_fire", "hit_frost", "hit_nature", "hit_shadow", "shoot", "death", "level_up"]
	for fname in files:
		var path: String = audio_dir + fname + ".wav"
		if ResourceLoader.exists(path):
			_audio_cache[fname] = load(path)

func _play_sfx(sfx_name: String, volume_db: float = -10.0) -> void:
	if not _audio_enabled:
		return
	if not _audio_cache.has(sfx_name):
		return
	var player := AudioStreamPlayer.new()
	player.stream = _audio_cache[sfx_name]
	player.volume_db = volume_db
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func play_sfx(sfx_name: String, volume_db: float = -10.0) -> void:
	## 公共 API，GamePack 可调用
	_play_sfx(sfx_name, volume_db)
