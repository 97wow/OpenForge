## LootEntity — 地面掉落物实体（对标 TrinityCore GameObject LOOT）
## 轻量 Node3D（非 GameEntity），不进入空间网格和战斗系统
## 视觉：稀有度颜色球体 + 粒子光芒 + 弹跳 + 浮动
## 通过 "loot_entities" group 被 PickupComponent 扫描
class_name LootEntity
extends Node3D

var item_data: Dictionary = {}
var rarity: String = "common"
var despawn_time: float = 30.0
var _age: float = 0.0
var _bob_offset: float = 0.0
var _base_y: float = 0.0
var _picked_up: bool = false

# 稀有度颜色（与 ItemSystem.RARITY_COLORS 一致）
const RARITY_COLORS := {
	"common": Color(0.7, 0.7, 0.7),
	"uncommon": Color(0.3, 0.85, 0.3),
	"rare": Color(0.3, 0.5, 1.0),
	"epic": Color(0.65, 0.3, 0.9),
	"legendary": Color(1.0, 0.6, 0.15),
}
const RARITY_PARTICLE := ["rare", "epic", "legendary"]

func setup(item: Dictionary, lifetime: float = 30.0) -> void:
	item_data = item
	despawn_time = lifetime
	rarity = item.get("def", {}).get("rarity", "common")
	_bob_offset = randf() * TAU  # 随机浮动相位

func _ready() -> void:
	add_to_group("loot_entities")
	_base_y = position.y
	_create_visuals()
	_play_spawn_animation()

func _process(delta: float) -> void:
	_age += delta
	if _age >= despawn_time:
		queue_free()
		return
	# 最后 5 秒闪烁提示
	if _age >= despawn_time - 5.0:
		var mesh_node: MeshInstance3D = get_node_or_null("Dot")
		if mesh_node and mesh_node.get_surface_override_material(0):
			var mat: StandardMaterial3D = mesh_node.get_surface_override_material(0)
			mat.albedo_color.a = 0.5 + 0.5 * sin(_age * 6.0)
	# 浮动动画
	position.y = _base_y + sin(_age * 2.0 + _bob_offset) * 0.15

func get_item() -> Dictionary:
	return item_data

func pickup() -> Dictionary:
	## 拾取：返回物品数据并销毁自身
	if _picked_up:
		return {}
	_picked_up = true
	var item: Dictionary = item_data
	EventBus.emit_event("loot_picked_up", {
		"item": item, "loot_entity": self, "position": global_position,
	})
	# 拾取动画：快速缩小并消失
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.15)
	tw.tween_callback(queue_free)
	return item

func _create_visuals() -> void:
	var col: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	# 掉落物球体
	var dot := MeshInstance3D.new()
	dot.name = "Dot"
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	dot.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col * 0.5
	mat.emission_energy_multiplier = 0.5
	dot.set_surface_override_material(0, mat)
	add_child(dot)

	# 稀有度以上加粒子光芒
	if rarity in RARITY_PARTICLE:
		var particles := GPUParticles3D.new()
		particles.emitting = true
		particles.one_shot = false
		particles.amount = 4 if rarity == "rare" else (6 if rarity == "epic" else 8)
		particles.lifetime = 0.8
		var pmat := ParticleProcessMaterial.new()
		pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pmat.emission_sphere_radius = 0.3
		pmat.direction = Vector3(0, 1, 0)
		pmat.spread = 180.0
		pmat.initial_velocity_min = 0.3
		pmat.initial_velocity_max = 0.8
		pmat.gravity = Vector3(0, -0.5, 0)
		pmat.scale_min = 0.05
		pmat.scale_max = 0.1
		var color_ramp := Gradient.new()
		color_ramp.set_color(0, Color(col.r, col.g, col.b, 0.7))
		color_ramp.set_color(1, Color(col.r, col.g, col.b, 0.0))
		var tex := GradientTexture1D.new()
		tex.gradient = color_ramp
		pmat.color_ramp = tex
		particles.process_material = pmat
		# 小 quad mesh 作为粒子形状
		var quad := QuadMesh.new()
		quad.size = Vector2(0.1, 0.1)
		particles.draw_pass_1 = quad
		particles.name = "GlowParticles"
		add_child(particles)

	# 传奇：额外脉冲光晕（通过 emission 强度变化）
	if rarity == "legendary":
		var tw := create_tween().set_loops()
		var dot_mat: StandardMaterial3D = dot.get_surface_override_material(0)
		if dot_mat:
			tw.tween_property(dot_mat, "emission_energy_multiplier", 1.5, 0.6)
			tw.tween_property(dot_mat, "emission_energy_multiplier", 0.5, 0.6)

	# 物品名标签（uncommon 以上显示）
	if rarity != "common":
		var label := Label3D.new()
		var item_sys: Node = EngineAPI.get_system("item")
		if item_sys:
			label.text = item_sys.call("get_item_display_name", item_data)
		else:
			label.text = item_data.get("item_id", "?")
		label.font_size = 32
		label.modulate = col
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0, 0.6, 0)
		label.name = "NameLabel"
		add_child(label)

func _play_spawn_animation() -> void:
	## 弹跳出现动画
	var start_y: float = position.y
	position.y = start_y + 1.0  # 向上弹起
	scale = Vector3(0.3, 0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(self, "position:y", start_y, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	tw.parallel().tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _base_y = start_y)
