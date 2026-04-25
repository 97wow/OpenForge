## AreaAuraSystem — 地面持续效果系统（对标 TrinityCore DynamicObject + AreaAura）
## 管理地面 AoE 持续效果：火圈、毒池、治疗场、减速区等
## 每个 AreaAura 是一个独立的"动态对象"，在固定位置周期性对区域内实体生效
## GamePack 可注册自定义 AreaAura 类型 Handler
class_name AreaAuraSystem
extends Node

# === 活跃的地面效果 ===
# area_id(int) -> AreaAuraInstance(Dictionary)
var _active_areas: Dictionary = {}
var _next_id: int = 1

# === AreaAura Handler 注册表 ===
# type(String) -> { "tick": Callable, "enter": Callable, "exit": Callable }
var _area_handlers: Dictionary = {}

# === 常量 ===
const MAX_AREA_AURAS := 50  # 硬上限，防止无限生成
const MAX_TARGETS_PER_TICK := 20  # 每次 tick 最多影响的目标数

func _ready() -> void:
	EngineAPI.register_system("area_aura", self)
	_register_builtin_handlers()

func _process(delta: float) -> void:
	if EngineAPI.get_game_state() != "playing":
		return
	var to_remove: Array[int] = []
	for area_id in _active_areas:
		var area: Dictionary = _active_areas[area_id]
		# 持续时间递减（0 = 永久）
		var duration: float = area.get("duration", 0.0)
		if duration > 0:
			area["remaining"] -= delta
			if area["remaining"] <= 0:
				to_remove.append(area_id)
				continue
		# 周期 tick
		area["tick_timer"] += delta
		var period: float = area.get("period", 1.0)
		if area["tick_timer"] >= period:
			area["tick_timer"] -= period
			_tick_area(area_id, area)
	# 移除过期的
	for area_id in to_remove:
		_destroy_area(area_id)

# === 公共 API ===

func create_area_aura(params: Dictionary) -> int:
	## 创建地面持续效果
	## params: {
	##   caster: Node3D,          # 施法者（用于伤害归属）
	##   position: Vector3,       # 地面位置
	##   radius: float,           # 影响半径
	##   duration: float,         # 持续时间（0=永久）
	##   period: float,           # tick 间隔（秒）
	##   type: String,            # 效果类型（AREA_DAMAGE/AREA_HEAL/AREA_SLOW 等）
	##   school: String,          # 伤害学校（physical/fire/frost/...）
	##   base_points: float,      # 每次 tick 的数值
	##   target_filter: String,   # "ENEMY"/"ALLY"/"ALL"
	##   spell_id: String,        # 来源技能（用于战斗日志）
	##   follow_caster: bool,     # 是否跟随施法者移动
	##   vfx: Dictionary,         # 可选：自定义视觉效果参数
	## }
	if _active_areas.size() >= MAX_AREA_AURAS:
		push_warning("[AreaAuraSystem] Max area auras reached (%d)" % MAX_AREA_AURAS)
		return -1

	var area_id: int = _next_id
	_next_id += 1

	var caster = params.get("caster")
	var pos: Vector3 = params.get("position", Vector3.ZERO)
	var duration: float = params.get("duration", 5.0)

	var area := {
		"area_id": area_id,
		"caster": caster,
		"position": pos,
		"radius": params.get("radius", 100.0),
		"duration": duration,
		"remaining": duration,
		"period": params.get("period", 1.0),
		"tick_timer": 0.0,
		"type": params.get("type", "AREA_DAMAGE"),
		"school": params.get("school", "physical"),
		"base_points": params.get("base_points", 10.0),
		"target_filter": params.get("target_filter", "ENEMY"),
		"spell_id": params.get("spell_id", ""),
		"follow_caster": params.get("follow_caster", false),
		"stacks": params.get("stacks", 1),
		"extra": params.get("extra", {}),  # GamePack 自定义数据
		"_affected_last_tick": [],  # 上次 tick 影响的实体（用于 enter/exit 回调）
		"_vfx_node": null,
	}

	_active_areas[area_id] = area

	# 创建视觉效果
	_spawn_area_vfx(area)

	EventBus.emit_event("area_aura_created", {
		"area_id": area_id,
		"position": pos,
		"radius": area["radius"],
		"type": area["type"],
		"caster": caster,
	})

	return area_id

func destroy_area_aura(area_id: int) -> void:
	## 手动销毁地面效果
	_destroy_area(area_id)

func get_area_aura(area_id: int) -> Dictionary:
	return _active_areas.get(area_id, {})

func get_all_area_auras() -> Dictionary:
	return _active_areas.duplicate()

func register_area_handler(area_type: String, tick_fn: Callable, enter_fn: Callable = Callable(), exit_fn: Callable = Callable()) -> void:
	## 注册自定义 AreaAura 类型处理器
	_area_handlers[area_type] = {
		"tick": tick_fn,
		"enter": enter_fn,
		"exit": exit_fn,
	}

func _reset() -> void:
	# 清理所有 VFX
	for area_id in _active_areas:
		var area: Dictionary = _active_areas[area_id]
		_cleanup_vfx(area)
	_active_areas.clear()
	_next_id = 1

# === 内部逻辑 ===

func _tick_area(area_id: int, area: Dictionary) -> void:
	## 每个 period 执行一次：查找区域内目标，调用 handler
	var caster = area.get("caster")

	# 跟随施法者模式：更新位置
	if area.get("follow_caster", false) and is_instance_valid(caster) and caster is Node3D:
		area["position"] = (caster as Node3D).global_position
		_update_vfx_position(area)

	# 查找区域内目标
	var targets: Array = _find_targets(area)

	# Enter/Exit 回调
	var prev_affected: Array = area.get("_affected_last_tick", [])
	var curr_ids: Array = []
	for t in targets:
		if is_instance_valid(t):
			curr_ids.append(t.get_instance_id())
	# 新进入的
	var handler: Dictionary = _area_handlers.get(area["type"], {})
	for t in targets:
		if is_instance_valid(t) and t.get_instance_id() not in prev_affected:
			if handler.has("enter") and handler["enter"].is_valid():
				handler["enter"].call(area, t)
	# 离开的
	for eid in prev_affected:
		if eid not in curr_ids:
			var obj: Object = instance_from_id(eid)
			if obj is GameEntity and is_instance_valid(obj):
				if handler.has("exit") and handler["exit"].is_valid():
					handler["exit"].call(area, obj)
	area["_affected_last_tick"] = curr_ids

	# 调用 tick handler 对所有区域内目标生效
	if handler.has("tick") and handler["tick"].is_valid():
		for t in targets:
			handler["tick"].call(area, t)

	EventBus.emit_event("area_aura_ticked", {
		"area_id": area_id,
		"target_count": targets.size(),
	})

func _find_targets(area: Dictionary) -> Array:
	## 查找区域内符合条件的目标（对标 TC SearchAreaTargets）
	var pos: Vector3 = area.get("position", Vector3.ZERO)
	var radius: float = area.get("radius", 100.0)
	var filter: String = area.get("target_filter", "ENEMY")
	var caster = area.get("caster")

	var candidates: Array = []
	match filter:
		"ENEMY":
			if is_instance_valid(caster) and caster is Node3D:
				candidates = EngineAPI.find_hostiles_in_area(caster, pos, radius)
			else:
				candidates = EngineAPI.find_entities_in_area(pos, radius)
		"ALLY":
			if is_instance_valid(caster) and caster is Node3D:
				candidates = EngineAPI.find_allies_in_area(caster, pos, radius)
			else:
				candidates = EngineAPI.find_entities_in_area(pos, radius)
		"ALL":
			candidates = EngineAPI.find_entities_in_area(pos, radius)
		_:
			candidates = EngineAPI.find_entities_in_area(pos, radius)

	# 过滤无效目标 + 硬上限
	var valid: Array = []
	for e in candidates:
		if not is_instance_valid(e) or not (e is GameEntity):
			continue
		var ge: GameEntity = e as GameEntity
		if not ge.is_alive:
			continue
		if ge.has_unit_flag(UnitFlags.EVADING | UnitFlags.NOT_SELECTABLE):
			continue
		valid.append(ge)
		if valid.size() >= MAX_TARGETS_PER_TICK:
			break
	return valid

func _destroy_area(area_id: int) -> void:
	if not _active_areas.has(area_id):
		return
	var area: Dictionary = _active_areas[area_id]

	# Exit 回调给所有当前在区域内的实体
	var handler: Dictionary = _area_handlers.get(area["type"], {})
	if handler.has("exit") and handler["exit"].is_valid():
		for eid in area.get("_affected_last_tick", []):
			var obj: Object = instance_from_id(eid)
			if obj is GameEntity and is_instance_valid(obj):
				handler["exit"].call(area, obj)

	_cleanup_vfx(area)
	_active_areas.erase(area_id)

	EventBus.emit_event("area_aura_destroyed", {"area_id": area_id})

# === 内置 Handler ===

func _register_builtin_handlers() -> void:
	register_area_handler("AREA_DAMAGE", _tick_damage)
	register_area_handler("AREA_HEAL", _tick_heal)
	register_area_handler("AREA_SLOW", _tick_slow, _enter_slow, _exit_slow)
	register_area_handler("AREA_TRIGGER_SPELL", _tick_trigger_spell)

func _tick_damage(area: Dictionary, target: GameEntity) -> void:
	## 区域周期伤害（火圈、毒池等）
	var caster = area.get("caster")
	var dmg: float = area.get("base_points", 0.0) * area.get("stacks", 1)
	var school: String = area.get("school", "physical")
	var spell_id: String = area.get("spell_id", "area_damage")
	var health: Node = EngineAPI.get_component(target, "health")
	if health and health.has_method("take_damage"):
		var dt: int = health.parse_damage_type(school)
		health.take_damage(dmg, caster if is_instance_valid(caster) else null, dt, spell_id)

func _tick_heal(area: Dictionary, target: GameEntity) -> void:
	## 区域周期治疗（治疗泉、神圣光环等）
	var caster = area.get("caster")
	var heal_amount: float = area.get("base_points", 0.0) * area.get("stacks", 1)
	var spell_id: String = area.get("spell_id", "area_heal")
	var health: Node = EngineAPI.get_component(target, "health")
	if health and health.has_method("heal"):
		health.heal(heal_amount, caster if is_instance_valid(caster) else null, spell_id)

func _tick_slow(_area: Dictionary, _target: GameEntity) -> void:
	## 减速区：进入/离开时处理，tick 不做额外操作
	pass

func _enter_slow(area: Dictionary, target: GameEntity) -> void:
	var slow_pct: float = area.get("base_points", 0.3)
	var factor: float = 1.0 - slow_pct
	var movement: Node = EngineAPI.get_component(target, "movement")
	if movement and movement.has_method("add_speed_modifier"):
		var mod_id := "area_slow_%d" % area.get("area_id", 0)
		movement.add_speed_modifier(mod_id, factor)

func _exit_slow(area: Dictionary, target: GameEntity) -> void:
	var movement: Node = EngineAPI.get_component(target, "movement")
	if movement and movement.has_method("remove_speed_modifier"):
		var mod_id := "area_slow_%d" % area.get("area_id", 0)
		movement.remove_speed_modifier(mod_id)

func _tick_trigger_spell(area: Dictionary, target: GameEntity) -> void:
	## 区域内周期触发技能
	var caster = area.get("caster")
	var trigger_id: String = area.get("extra", {}).get("trigger_spell", "")
	if trigger_id != "" and is_instance_valid(caster):
		EngineAPI.cast_spell(trigger_id, caster, target)

# === 视觉效果 ===

func _spawn_area_vfx(area: Dictionary) -> void:
	## 在地面位置创建环形粒子效果
	var game_root: Node = get_tree().current_scene
	if game_root == null:
		return
	var pos: Vector3 = area.get("position", Vector3.ZERO)
	var radius: float = area.get("radius", 100.0)
	var area_type: String = area.get("type", "")
	var school: String = area.get("school", "physical")

	# 根据类型/学校选择颜色
	var color: Color = _get_school_color(school, area_type)

	# 创建 VFX 容器节点
	var vfx_root := Node3D.new()
	vfx_root.global_position = pos
	vfx_root.name = "AreaAuraVFX_%d" % area.get("area_id", 0)
	game_root.add_child(vfx_root)

	# 圆环粒子（沿边缘发射）
	var ring := GPUParticles3D.new()
	ring.emitting = true
	ring.one_shot = false
	ring.amount = clampi(int(radius * 0.15), 6, 30)
	ring.lifetime = 1.2
	var ring_mat := ParticleProcessMaterial.new()
	ring_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	ring_mat.emission_ring_radius = radius
	ring_mat.emission_ring_inner_radius = radius * 0.85
	ring_mat.emission_ring_height = 0.1
	ring_mat.emission_ring_axis = Vector3(0, 1, 0)
	ring_mat.direction = Vector3(0, 1, 0)
	ring_mat.spread = 180.0
	ring_mat.initial_velocity_min = 0.2
	ring_mat.initial_velocity_max = 0.5
	ring_mat.gravity = Vector3.ZERO
	ring_mat.scale_min = 0.08
	ring_mat.scale_max = 0.15
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color.r, color.g, color.b, 0.6))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var ring_tex := GradientTexture1D.new()
	ring_tex.gradient = gradient
	ring_mat.color_ramp = ring_tex
	ring.process_material = ring_mat
	var ring_quad := QuadMesh.new()
	ring_quad.size = Vector2(0.1, 0.1)
	ring.draw_pass_1 = ring_quad
	var ring_draw_mat := StandardMaterial3D.new()
	ring_draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	ring_draw_mat.vertex_color_use_as_albedo = true
	ring_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = ring_draw_mat
	ring.name = "RingParticles"
	vfx_root.add_child(ring)

	# 内部填充粒子（较稀疏）
	var fill := GPUParticles3D.new()
	fill.emitting = true
	fill.one_shot = false
	fill.amount = clampi(int(radius * 0.08), 3, 15)
	fill.lifetime = 0.8
	var fill_mat := ParticleProcessMaterial.new()
	fill_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fill_mat.emission_sphere_radius = radius * 0.7
	fill_mat.direction = Vector3(0, 1, 0)
	fill_mat.spread = 30.0
	fill_mat.initial_velocity_min = 0.5
	fill_mat.initial_velocity_max = 1.2
	fill_mat.gravity = Vector3(0, 0.5, 0)
	fill_mat.scale_min = 0.05
	fill_mat.scale_max = 0.1
	var fill_gradient := Gradient.new()
	fill_gradient.set_color(0, Color(color.r, color.g, color.b, 0.4))
	fill_gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var fill_tex := GradientTexture1D.new()
	fill_tex.gradient = fill_gradient
	fill_mat.color_ramp = fill_tex
	fill.process_material = fill_mat
	var fill_quad := QuadMesh.new()
	fill_quad.size = Vector2(0.1, 0.1)
	fill.draw_pass_1 = fill_quad
	fill.material_override = ring_draw_mat  # 复用 billboard 材质
	fill.name = "FillParticles"
	vfx_root.add_child(fill)

	area["_vfx_node"] = vfx_root

func _update_vfx_position(area: Dictionary) -> void:
	var vfx = area.get("_vfx_node")
	if vfx != null and is_instance_valid(vfx) and vfx is Node3D:
		(vfx as Node3D).global_position = area.get("position", Vector3.ZERO)

func _cleanup_vfx(area: Dictionary) -> void:
	var vfx = area.get("_vfx_node")
	if vfx != null and is_instance_valid(vfx) and vfx is Node:
		(vfx as Node).queue_free()
	area["_vfx_node"] = null

func _get_school_color(school: String, area_type: String) -> Color:
	if area_type == "AREA_HEAL":
		return Color(0.3, 1.0, 0.4, 0.8)
	match school:
		"fire": return Color(1.0, 0.4, 0.1, 0.8)
		"frost", "ice": return Color(0.4, 0.75, 1.0, 0.8)
		"nature", "poison": return Color(0.3, 0.85, 0.2, 0.8)
		"shadow", "dark": return Color(0.55, 0.2, 0.85, 0.8)
		"holy", "light": return Color(1.0, 0.9, 0.3, 0.8)
		_: return Color(0.8, 0.8, 0.8, 0.6)  # physical
