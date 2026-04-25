## VFXSystem - 视觉特效系统（框架层，3D）
## 通过代码生成粒子特效、闪电链、冲击波等
## GamePack 可调用 spawn_vfx() 或注册自定义特效
class_name VFXSystem
extends Node3D

var _vfx_handlers: Dictionary = {}
var _audio_cache: Dictionary = {}  # path -> AudioStream
var _audio_enabled: bool = true
var _hit_stop_active: bool = false
## VFX 限流：防止 GPU fence timeout
var _active_vfx_count: int = 0
const MAX_ACTIVE_VFX := 30  # 同时存在的最大 VFX 数量

func _ready() -> void:
	EngineAPI.register_system("vfx", self)
	_register_builtin_vfx()
	_preload_audio()
	EventBus.connect_event("entity_damaged", _on_entity_damaged)
	EventBus.connect_event("entity_destroyed", _on_entity_destroyed)
	EventBus.connect_event("entity_healed", _on_entity_healed)
	EventBus.connect_event("entity_killed", _on_entity_killed)
	EventBus.connect_event("spell_cast", _on_spell_cast)
	EventBus.connect_event("aura_applied", _on_aura_applied)

# === 公共 API ===

func spawn_vfx(vfx_type: String, pos: Vector3, data: Dictionary = {}) -> void:
	if _active_vfx_count >= MAX_ACTIVE_VFX:
		return  # GPU 保护：限制同时 VFX 数量
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
	if entity is GameEntity and (entity as GameEntity).has_tag("projectile"):
		return
	var amount: float = data.get("amount", 0)
	if amount < 1:
		return
	var damage_type: int = data.get("damage_type", 0)
	var _source = data.get("source")
	var pos: Vector3 = (entity as Node3D).global_position

	# --- 命中粒子 ---
	var vfx_name := "hit_physical"
	match damage_type:
		1: vfx_name = "hit_frost"
		2: vfx_name = "hit_fire"
		3: vfx_name = "hit_nature"
		4: vfx_name = "hit_shadow"
		5: vfx_name = "hit_holy"

	var size_mult := clampf(amount / 20.0, 0.5, 2.5)
	spawn_vfx(vfx_name, pos, {"size": size_mult})

	# --- 音效（优先新音效，回退旧音效）---
	var sfx_name := "hit_metal" if _audio_cache.has("hit_metal") else "hit_physical"
	match damage_type:
		1: sfx_name = "hit_frost" if _audio_cache.has("hit_frost") else "hit_generic"
		2: sfx_name = "hit_fire" if _audio_cache.has("hit_fire") else "hit_generic"
		3: sfx_name = "hit_nature" if _audio_cache.has("hit_nature") else "hit_generic"
		4: sfx_name = "hit_shadow" if _audio_cache.has("hit_shadow") else "hit_generic"
	_play_sfx(sfx_name)

	# 击退已移除默认行为 — 仅在 GamePack 显式调用时生效

	# 镜头震动和顿帧已移除

func _on_entity_killed(data: Dictionary) -> void:
	## 击杀瞬间反馈（死亡动画/销毁延迟在 DamagePipeline 处理）
	var entity = data.get("entity")
	if entity == null or not is_instance_valid(entity):
		return
	if entity is GameEntity and (entity as GameEntity).has_tag("projectile"):
		return
	var pos: Vector3 = (entity as Node3D).global_position
	# 击杀镜头震动（比普通命中更强）
	# 大量死亡粒子
	spawn_vfx("death", pos)
	_play_sfx("death")

func _on_entity_destroyed(data: Dictionary) -> void:
	var entity = data.get("entity")
	if entity == null or not is_instance_valid(entity):
		return
	if entity is GameEntity and (entity as GameEntity).has_tag("projectile"):
		return
	# 注：主要死亡特效已由 _on_entity_killed 处理
	# 这里只处理非战斗销毁（如过期、手动移除等）

func _on_entity_healed(data: Dictionary) -> void:
	var entity = data.get("entity")
	if entity == null or not is_instance_valid(entity):
		return
	spawn_vfx("heal", (entity as Node3D).global_position)

func _on_spell_cast(data: Dictionary) -> void:
	var caster = data.get("caster")
	if caster == null or not is_instance_valid(caster):
		return
	var pos: Vector3 = (caster as Node3D).global_position
	_spawn_flash(pos, Color(1, 1, 1, 0.3), 1.0)
	_play_sfx("shoot")

func _on_aura_applied(data: Dictionary) -> void:
	var target = data.get("target")
	var aura_type: String = data.get("aura_type", "")
	if target == null or not is_instance_valid(target):
		return
	var pos: Vector3 = (target as Node3D).global_position
	match aura_type:
		"PERIODIC_DAMAGE":
			_spawn_flash(pos, Color(1, 0.3, 0.1, 0.4), 1.2)
		"MOD_SPEED_SLOW":
			_spawn_flash(pos, Color(0.3, 0.7, 1, 0.4), 1.2)

# === 粒子特效工厂 ===

func _vfx_hit_physical(pos: Vector3, data: Dictionary) -> void:
	var size: float = data.get("size", 1.0)
	_spawn_particles(pos, {
		"amount": int(6 * size), "color": Color(1, 1, 1, 0.9),
		"color_end": Color(0.8, 0.8, 0.8, 0), "speed": 5 * size,
		"lifetime": 0.3, "size": 0.08, "gravity": Vector3(0, -3, 0),
	})

func _vfx_hit_fire(pos: Vector3, data: Dictionary) -> void:
	var size: float = data.get("size", 1.0)
	_spawn_particles(pos, {
		"amount": int(10 * size), "color": Color(1, 0.6, 0.1, 0.95),
		"color_end": Color(1, 0.2, 0, 0), "speed": 4 * size,
		"lifetime": 0.5, "size": 0.1, "gravity": Vector3(0, 2, 0),
	})

func _vfx_hit_frost(pos: Vector3, data: Dictionary) -> void:
	var size: float = data.get("size", 1.0)
	_spawn_particles(pos, {
		"amount": int(8 * size), "color": Color(0.4, 0.8, 1, 0.9),
		"color_end": Color(0.7, 0.9, 1, 0), "speed": 3 * size,
		"lifetime": 0.6, "size": 0.09, "gravity": Vector3(0, -0.5, 0),
	})

func _vfx_hit_nature(pos: Vector3, data: Dictionary) -> void:
	var size: float = data.get("size", 1.0)
	_spawn_particles(pos, {
		"amount": int(8 * size), "color": Color(0.3, 0.9, 0.3, 0.9),
		"color_end": Color(0.1, 0.6, 0.1, 0), "speed": 2.5 * size,
		"lifetime": 0.7, "size": 0.08, "gravity": Vector3(0, 1.5, 0),
	})

func _vfx_hit_shadow(pos: Vector3, data: Dictionary) -> void:
	var size: float = data.get("size", 1.0)
	_spawn_particles(pos, {
		"amount": int(10 * size), "color": Color(0.6, 0.2, 0.9, 0.9),
		"color_end": Color(0.3, 0.1, 0.5, 0), "speed": 4.5 * size,
		"lifetime": 0.4, "size": 0.09, "gravity": Vector3.ZERO,
	})

func _vfx_hit_holy(pos: Vector3, data: Dictionary) -> void:
	var size: float = data.get("size", 1.0)
	_spawn_particles(pos, {
		"amount": int(12 * size), "color": Color(1, 0.9, 0.4, 0.95),
		"color_end": Color(1, 1, 0.7, 0), "speed": 3.5 * size,
		"lifetime": 0.5, "size": 0.09, "gravity": Vector3(0, 2.5, 0),
	})

func _vfx_death(pos: Vector3, _data: Dictionary) -> void:
	# 主爆散（红色碎片向四周飞射）
	_spawn_particles(pos, {
		"amount": 30, "color": Color(1, 0.4, 0.2, 0.95),
		"color_end": Color(0.5, 0.1, 0.1, 0), "speed": 8,
		"lifetime": 0.7, "size": 0.12, "gravity": Vector3(0, -6, 0), "spread": 180,
	})
	# 灵魂烟雾（白色上升）
	_spawn_particles(pos, {
		"amount": 12, "color": Color(1, 1, 1, 0.5),
		"color_end": Color(0.8, 0.8, 1, 0), "speed": 2,
		"lifetime": 1.0, "size": 0.15, "gravity": Vector3(0, 3, 0), "spread": 40,
	})
	# 冲击环
	_spawn_ring(pos, Color(1, 0.5, 0.2, 0.5), 1.5, 0.4)

func _vfx_heal(pos: Vector3, _data: Dictionary) -> void:
	_spawn_particles(pos, {
		"amount": 8, "color": Color(0.3, 1, 0.4, 0.8),
		"color_end": Color(0.5, 1, 0.6, 0), "speed": 2,
		"lifetime": 0.8, "size": 0.09, "gravity": Vector3(0, 3, 0), "spread": 30,
	})

func _vfx_level_up(pos: Vector3, _data: Dictionary) -> void:
	_spawn_particles(pos, {
		"amount": 30, "color": Color(1, 0.85, 0.2, 1),
		"color_end": Color(1, 0.7, 0, 0), "speed": 5,
		"lifetime": 1.0, "size": 0.12, "gravity": Vector3(0, 4, 0), "spread": 180,
	})
	_spawn_ring(pos, Color(1, 0.85, 0.3, 0.6), 3.0, 0.8)

func _vfx_shockwave(pos: Vector3, data: Dictionary) -> void:
	var radius: float = data.get("radius", 10)
	_spawn_ring(pos, Color(1, 0.9, 0.5, 0.7), radius, 0.5)
	_spawn_particles(pos, {
		"amount": 15, "color": Color(1, 0.9, 0.4, 0.8),
		"color_end": Color(1, 0.8, 0.3, 0), "speed": 8,
		"lifetime": 0.4, "size": 0.09, "gravity": Vector3.ZERO, "spread": 180,
	})

func _vfx_lightning(pos: Vector3, data: Dictionary) -> void:
	var target_pos: Vector3 = data.get("target_pos", pos + Vector3(5, 0, 0))
	_spawn_lightning_bolt(pos, target_pos, Color(0.5, 0.7, 1, 0.9))

# === 底层生成器 ===

func _spawn_particles(pos: Vector3, config: Dictionary) -> void:
	# 限制同时存在的粒子节点数量（防止 GPU fence timeout）
	if get_child_count() > 40:
		return
	var particles := GPUParticles3D.new()
	particles.position = pos + Vector3(0, 0.5, 0)  # 稍微抬高
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = config.get("amount", 8)
	particles.lifetime = config.get("lifetime", 0.5)

	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = config.get("spread", 90.0)
	pmat.initial_velocity_min = config.get("speed", 3) * 0.5
	pmat.initial_velocity_max = config.get("speed", 3)
	pmat.gravity = config.get("gravity", Vector3.ZERO)
	pmat.scale_min = config.get("size", 0.08) * 0.5
	pmat.scale_max = config.get("size", 0.08)

	var color_start: Color = config.get("color", Color.WHITE)
	var color_end: Color = config.get("color_end", Color(1, 1, 1, 0))
	var gradient := Gradient.new()
	gradient.set_color(0, color_start)
	gradient.set_color(1, color_end)
	var tex := GradientTexture1D.new()
	tex.gradient = gradient
	pmat.color_ramp = tex

	particles.process_material = pmat

	# 粒子 mesh（小 quad）
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	particles.draw_pass_1 = quad
	# Billboard 材质
	var draw_mat := StandardMaterial3D.new()
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.material_override = draw_mat

	add_child(particles)
	_active_vfx_count += 1
	get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(func() -> void:
		_active_vfx_count -= 1
		if is_instance_valid(particles):
			particles.queue_free()
	)

func _spawn_flash(pos: Vector3, color: Color, radius: float) -> void:
	if get_child_count() > 40:
		return
	var flash := MeshInstance3D.new()
	flash.position = pos + Vector3(0, 0.5, 0)
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2
	flash.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 1.0
	flash.set_surface_override_material(0, mat)
	add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tween.tween_callback(flash.queue_free)

func _spawn_ring(pos: Vector3, color: Color, max_radius: float, duration: float) -> void:
	var ring := MeshInstance3D.new()
	ring.position = pos + Vector3(0, 0.1, 0)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.5
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	ring.set_surface_override_material(0, mat)
	# 旋转使 torus 水平
	ring.rotation_degrees.x = 90
	ring.scale = Vector3(0.3, 0.3, 0.3)
	add_child(ring)

	var final_scale: float = max_radius / 0.5
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(final_scale, final_scale, final_scale), duration)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.set_parallel(false)
	tween.tween_callback(ring.queue_free)

func _spawn_lightning_bolt(from_pos: Vector3, to_pos: Vector3, color: Color) -> void:
	## 使用 ImmediateMesh 绘制闪电链
	var mesh_inst := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	mesh_inst.mesh = im

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.material_override = mat  # 用 override 而非 surface_override（ImmediateMesh 绘制前无 surface）

	# 生成锯齿形闪电路径
	var segments := 8
	var dir: Vector3 = to_pos - from_pos
	var step: Vector3 = dir / segments
	# 垂直于方向的偏移向量
	var perp: Vector3 = dir.cross(Vector3.UP).normalized()
	if perp.length_squared() < 0.01:
		perp = Vector3.RIGHT

	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	im.surface_add_vertex(from_pos)
	for i in range(1, segments):
		var base: Vector3 = from_pos + step * i
		var offset: float = randf_range(-0.8, 0.8)
		im.surface_add_vertex(base + perp * offset)
	im.surface_add_vertex(to_pos)
	im.surface_end()

	add_child(mesh_inst)
	var tween := mesh_inst.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tween.tween_callback(mesh_inst.queue_free)

# === 音频系统 ===

func _preload_audio() -> void:
	var audio_dir := "res://assets/audio/"
	var sfx_dir := "res://assets/audio/sfx/"
	# 原有音效（wav）
	var files := ["hit_physical", "hit_fire", "hit_frost", "hit_nature", "hit_shadow", "shoot", "death", "level_up"]
	for fname in files:
		for ext in [".wav", ".ogg"]:
			var path: String = audio_dir + fname + ext
			if ResourceLoader.exists(path):
				_audio_cache[fname] = load(path)
				break
	# 新增音效（ogg）
	var sfx_files := {
		"melee_swing": "melee_swing.ogg",
		"spell_cast": "spell_cast.ogg",
		"hit_metal": "hit_metal.ogg",
		"hit_generic": "hit_generic.ogg",
		"gold_pickup": "gold_pickup.ogg",
		"select_unit": "select_unit.ogg",
		"move_command": "move_command.ogg",
		"ui_click": "ui_click.ogg",
	}
	for key: String in sfx_files:
		var path: String = sfx_dir + sfx_files[key]
		if ResourceLoader.exists(path):
			_audio_cache[key] = load(path)

var _sfx_cooldowns: Dictionary = {}  # sfx_name -> next_allowed_time

func _play_sfx(sfx_name: String, volume_db: float = -10.0) -> void:
	if not _audio_enabled:
		return
	if not _audio_cache.has(sfx_name):
		return
	# 同名音效最少间隔 50ms（防止同一帧叠加几十个）
	var now: float = Time.get_ticks_msec() / 1000.0
	var next_allowed: float = _sfx_cooldowns.get(sfx_name, 0.0)
	if now < next_allowed:
		return
	_sfx_cooldowns[sfx_name] = now + 0.05
	# 限制同时播放的音效总数
	var sfx_count := 0
	for c in get_children():
		if c is AudioStreamPlayer:
			sfx_count += 1
	if sfx_count > 12:
		return
	var player := AudioStreamPlayer.new()
	player.stream = _audio_cache[sfx_name]
	player.volume_db = volume_db
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func play_sfx(sfx_name: String, volume_db: float = -10.0) -> void:
	_play_sfx(sfx_name, volume_db)

# === 手感系统（Game Feel）===

func _do_hit_stop(duration: float) -> void:
	## 顿帧：短暂冻结画面，给予攻击"重量感"
	if _hit_stop_active:
		return
	_hit_stop_active = true
	var prev_scale: float = Engine.time_scale
	Engine.time_scale = 0.05
	# 使用不受时间缩放影响的计时器
	get_tree().create_timer(duration, true, false, true).timeout.connect(func() -> void:
		Engine.time_scale = prev_scale
		_hit_stop_active = false
	)
