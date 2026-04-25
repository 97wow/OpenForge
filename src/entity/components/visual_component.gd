## VisualComponent - 视觉渲染 + 血条 + 动画
## 加载 GamePack 提供的 3D 模型（.glb），或创建占位符
## 自动为有 health 组件的实体显示血条
## 自动查找 AnimationPlayer 并根据移动/攻击状态切换动画
extends Node

var _entity: Node3D = null
var _visual_node: Node3D = null
var _hp_bar_bg: MeshInstance3D = null
var _hp_bar_fill: MeshInstance3D = null
var _hp_bar_width: float = 1.0  # 血条宽度（缓存用于左对齐）
var _entity_size: float = 1.0  # 3D 世界单位
var _show_hp_bar: bool = true

# 动画系统
var _anim_player: AnimationPlayer = null
var _current_anim: String = ""
var _has_model: bool = false  # 是否加载了 3D 模型（非占位符）
var _attack_anim: String = "1H_Melee_Attack_Chop"
var _run_anim: String = "Running_A"
var _idle_anim: String = "Idle"
var _death_anim: String = "Death_A"
var _spell_anim: String = "Spellcast_Shoot"
var _hit_anim: String = "Hit_A"
var _is_dead: bool = false
## 动画速度参考值：当实体速度等于此值时，动画以 1x 速度播放
## KayKit 角色 Running_A 动画设计基于约 4.0 m/s 的跑步速度
## 运行时从 movement.base_speed 自动获取，或在 JSON 中手动指定
var _anim_ref_speed: float = 0.0  # 0 = 自动（取 base_speed）

func setup(data: Dictionary) -> void:
	var scene_path: String = data.get("scene", "")
	var color_hex: String = data.get("color", "")
	_entity_size = data.get("size", 16.0) * 0.0625  # 像素→3D 单位（/16）
	_show_hp_bar = data.get("show_hp_bar", true)
	var shape_hint: String = data.get("shape_hint", "sphere")

	# 自定义动画名映射
	_attack_anim = data.get("anim_attack", "1H_Melee_Attack_Chop")
	_run_anim = data.get("anim_run", "Running_A")
	_idle_anim = data.get("anim_idle", "Idle")
	_death_anim = data.get("anim_death", "Death_A")
	_spell_anim = data.get("anim_spell", "Spellcast_Shoot")
	_anim_ref_speed = data.get("anim_ref_speed", 0.0)  # 0 = 自动匹配 base_speed

	if scene_path != "":
		var scene := load(scene_path) as PackedScene
		if scene:
			_visual_node = scene.instantiate() as Node3D
			var model_scale: float = data.get("model_scale", _entity_size * 0.8)
			_visual_node.scale = Vector3(model_scale, model_scale, model_scale)
			_has_model = true
			# HD-3D 描边：给模型网格添加反面法 outline
			_apply_outline_to_model(_visual_node)

	if _visual_node == null:
		_visual_node = _create_placeholder(color_hex, _entity_size, shape_hint)

func _on_attached(entity: Node3D) -> void:
	_entity = entity
	if _visual_node:
		entity.add_child(_visual_node)
	# 查找 AnimationPlayer
	if _has_model and _visual_node:
		_anim_player = _find_anim_player(_visual_node)
		if _anim_player:
			# 调试：列出可用动画（帮助确认动画名映射）
			var anim_list: PackedStringArray = _anim_player.get_animation_list()
			if anim_list.size() > 0:
				pass  # 动画列表调试已完成
			# 强制 idle/run 动画循环（GLB 导入可能未设置循环）
			_ensure_loop(_idle_anim)
			_ensure_loop(_run_anim)
			_play_anim(_idle_anim)
			set_process(true)  # 启用每帧动画状态检查
	# 自动获取动画参考速度（如果未手动指定）
	if _anim_ref_speed <= 0.0:
		# 延迟获取（movement 组件可能还没 attach）
		entity.ready.connect(_auto_detect_ref_speed, CONNECT_ONE_SHOT)
	if _show_hp_bar:
		entity.ready.connect(_try_create_hp_bar, CONNECT_ONE_SHOT)
	if not _anim_player:
		set_process(false)

func _on_detached() -> void:
	if _visual_node and is_instance_valid(_visual_node):
		_visual_node.queue_free()

func _try_create_hp_bar() -> void:
	if _entity == null:
		return
	var health: Node = _entity.get_component("health") if _entity.has_method("get_component") else null
	if health != null:
		_create_hp_bar()

var _last_hp_ratio: float = 1.0

func update_hp_bar() -> void:
	## 由 health_component 在血量变化时调用
	if not _show_hp_bar or _entity == null or _hp_bar_fill == null:
		return
	var health: Node = _entity.get_component("health") if _entity.has_method("get_component") else null
	if health == null:
		if _hp_bar_bg:
			_hp_bar_bg.visible = false
		return
	var ratio: float = health.current_hp / health.max_hp if health.max_hp > 0 else 0
	if is_equal_approx(ratio, _last_hp_ratio):
		return
	_last_hp_ratio = ratio
	# 直接改 mesh 尺寸 + center_offset 左对齐（不用 scale，避免 billboard 问题）
	var fill_mesh: QuadMesh = _hp_bar_fill.mesh as QuadMesh
	if fill_mesh:
		var h: float = fill_mesh.size.y
		fill_mesh.size = Vector2(_hp_bar_width * ratio, h)
		fill_mesh.center_offset = Vector3(-_hp_bar_width * (1.0 - ratio) * 0.5, 0, 0)
	_hp_bar_bg.visible = ratio < 1.0
	_hp_bar_fill.visible = ratio > 0.0 and ratio < 1.0
	# 颜色随血量变化
	var fill_mat: StandardMaterial3D = _hp_bar_fill.get_surface_override_material(0)
	if fill_mat:
		if ratio > 0.6:
			fill_mat.albedo_color = Color(0.2, 0.85, 0.2)
		elif ratio > 0.3:
			fill_mat.albedo_color = Color(0.9, 0.8, 0.1)
		else:
			fill_mat.albedo_color = Color(0.9, 0.15, 0.15)

func _create_hp_bar() -> void:
	var bar_width: float = clampf(_entity_size * 1.5, 0.8, 3.0)
	_hp_bar_width = bar_width
	var bar_height: float = 0.1
	var bar_y: float = _entity_size + 0.3  # 头顶上方

	# 背景条
	_hp_bar_bg = MeshInstance3D.new()
	var bg_quad := QuadMesh.new()
	bg_quad.size = Vector2(bar_width, bar_height)
	_hp_bar_bg.mesh = bg_quad
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.15, 0.15, 0.15, 0.8)
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.no_depth_test = true
	bg_mat.render_priority = 10
	_hp_bar_bg.set_surface_override_material(0, bg_mat)
	_hp_bar_bg.position = Vector3(0, bar_y, 0)
	_hp_bar_bg.visible = false
	_entity.add_child(_hp_bar_bg)

	# 填充条
	_hp_bar_fill = MeshInstance3D.new()
	var fill_quad := QuadMesh.new()
	fill_quad.size = Vector2(bar_width, bar_height)
	_hp_bar_fill.mesh = fill_quad
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.2, 0.85, 0.2)
	fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.no_depth_test = true
	fill_mat.render_priority = 11
	_hp_bar_fill.set_surface_override_material(0, fill_mat)
	_hp_bar_fill.position = Vector3(0, bar_y, 0)
	_entity.add_child(_hp_bar_fill)

func _make_mat(color: Color, metallic: float = 0.0, roughness: float = 0.7) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	mat.emission_enabled = true
	mat.emission = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15)
	mat.emission_energy_multiplier = 0.2
	return mat

func _add_mesh(parent: Node3D, mesh: Mesh, mat: StandardMaterial3D, pos: Vector3) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.set_surface_override_material(0, mat)
	inst.position = pos
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(inst)
	return inst

func _create_placeholder(color_hex: String, size: float, shape_hint: String = "sphere") -> Node3D:
	var color := Color.WHITE
	if color_hex != "":
		color = Color.from_string(color_hex, Color.WHITE)
	else:
		color = Color.from_hsv(randf(), 0.7, 0.9)

	var root := Node3D.new()
	var s := size  # 简写

	match shape_hint:
		"capsule":
			_build_humanoid(root, color, s)
		"box":
			_build_blocky(root, color, s)
		"cylinder":
			_build_tower(root, color, s)
		_:
			_build_projectile(root, color, s)

	# 脚底阴影圈（仅非弹道实体）
	if shape_hint != "sphere":
		var shadow := MeshInstance3D.new()
		var shadow_mesh := QuadMesh.new()
		shadow_mesh.size = Vector2(s * 0.8, s * 0.8)
		shadow.mesh = shadow_mesh
		var shadow_mat := StandardMaterial3D.new()
		shadow_mat.albedo_color = Color(0, 0, 0, 0.3)
		shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shadow.set_surface_override_material(0, shadow_mat)
		shadow.position = Vector3(0, 0.02, 0)
		shadow.rotation_degrees.x = -90
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(shadow)

	return root

func _build_humanoid(root: Node3D, color: Color, s: float) -> void:
	## War3 风格人形：身体+头+双臂+武器+肩甲
	var body_color := color
	var skin_color := Color(0.85, 0.72, 0.55)
	var armor_color := Color(color.r * 0.7, color.g * 0.7, color.b * 0.7)
	var body_mat := _make_mat(body_color, 0.1, 0.6)
	var skin_mat := _make_mat(skin_color, 0.0, 0.8)
	var armor_mat := _make_mat(armor_color, 0.4, 0.4)

	# 躯干（上窄下宽的梯形 = CylinderMesh）
	var torso := CylinderMesh.new()
	torso.top_radius = s * 0.18
	torso.bottom_radius = s * 0.22
	torso.height = s * 0.35
	_add_mesh(root, torso, body_mat, Vector3(0, s * 0.42, 0))

	# 腿部（两个小圆柱）
	var leg := CylinderMesh.new()
	leg.top_radius = s * 0.08
	leg.bottom_radius = s * 0.07
	leg.height = s * 0.3
	_add_mesh(root, leg, _darker_mat(body_color), Vector3(-s * 0.1, s * 0.15, 0))
	_add_mesh(root, leg, _darker_mat(body_color), Vector3(s * 0.1, s * 0.15, 0))

	# 头（球体，肤色）
	var head := SphereMesh.new()
	head.radius = s * 0.13
	head.height = s * 0.26
	_add_mesh(root, head, skin_mat, Vector3(0, s * 0.72, 0))

	# 肩甲（两个小球）
	var shoulder := SphereMesh.new()
	shoulder.radius = s * 0.1
	shoulder.height = s * 0.2
	_add_mesh(root, shoulder, armor_mat, Vector3(-s * 0.28, s * 0.55, 0))
	_add_mesh(root, shoulder, armor_mat, Vector3(s * 0.28, s * 0.55, 0))

	# 右手武器（锥形 = 剑/矛）
	var weapon := CylinderMesh.new()
	weapon.top_radius = 0.0
	weapon.bottom_radius = s * 0.04
	weapon.height = s * 0.45
	var weapon_mat := _make_mat(Color(0.75, 0.75, 0.8), 0.8, 0.2)
	var wpn := _add_mesh(root, weapon, weapon_mat, Vector3(s * 0.3, s * 0.55, -s * 0.15))
	wpn.rotation_degrees.x = -30

	# 左手盾牌（扁方块）
	var shield := BoxMesh.new()
	shield.size = Vector3(s * 0.04, s * 0.2, s * 0.15)
	_add_mesh(root, shield, armor_mat, Vector3(-s * 0.3, s * 0.4, -s * 0.05))

func _darker_mat(color: Color) -> StandardMaterial3D:
	return _make_mat(Color(color.r * 0.6, color.g * 0.6, color.b * 0.6), 0.0, 0.8)

func _build_blocky(root: Node3D, color: Color, s: float) -> void:
	## 方块型怪物（骷髅/石像鬼）：方体+头骨+手臂
	var body_mat := _make_mat(color, 0.0, 0.7)
	var dark_mat := _make_mat(Color(color.r * 0.5, color.g * 0.5, color.b * 0.5), 0.1, 0.6)

	# 方体躯干
	var body := BoxMesh.new()
	body.size = Vector3(s * 0.5, s * 0.45, s * 0.35)
	_add_mesh(root, body, body_mat, Vector3(0, s * 0.4, 0))

	# 头（方形，稍小）
	var head := BoxMesh.new()
	head.size = Vector3(s * 0.3, s * 0.25, s * 0.3)
	_add_mesh(root, head, body_mat, Vector3(0, s * 0.72, 0))

	# 双眼（两个红色小球）
	var eye := SphereMesh.new()
	eye.radius = s * 0.04
	eye.height = s * 0.08
	var eye_mat := _make_mat(Color(1, 0.2, 0.1), 0.0, 0.3)
	eye_mat.emission = Color(1, 0.2, 0.1)
	eye_mat.emission_energy_multiplier = 2.0
	_add_mesh(root, eye, eye_mat, Vector3(-s * 0.08, s * 0.75, -s * 0.14))
	_add_mesh(root, eye, eye_mat, Vector3(s * 0.08, s * 0.75, -s * 0.14))

	# 腿
	var leg := BoxMesh.new()
	leg.size = Vector3(s * 0.15, s * 0.25, s * 0.15)
	_add_mesh(root, leg, dark_mat, Vector3(-s * 0.15, s * 0.12, 0))
	_add_mesh(root, leg, dark_mat, Vector3(s * 0.15, s * 0.12, 0))

func _build_tower(root: Node3D, color: Color, s: float) -> void:
	## 建筑/Boss（多层柱体+顶部装饰）
	var body_mat := _make_mat(color, 0.2, 0.5)
	var accent := Color(color.r * 1.3, color.g * 1.3, color.b * 1.3).clamp()
	var accent_mat := _make_mat(accent, 0.5, 0.3)

	# 底座（宽矮圆柱）
	var base := CylinderMesh.new()
	base.top_radius = s * 0.4
	base.bottom_radius = s * 0.45
	base.height = s * 0.15
	_add_mesh(root, base, body_mat, Vector3(0, s * 0.075, 0))

	# 主体（高圆柱）
	var body := CylinderMesh.new()
	body.top_radius = s * 0.3
	body.bottom_radius = s * 0.38
	body.height = s * 0.6
	_add_mesh(root, body, body_mat, Vector3(0, s * 0.45, 0))

	# 顶冠（球体或锥体）
	var crown := SphereMesh.new()
	crown.radius = s * 0.2
	crown.height = s * 0.35
	_add_mesh(root, crown, accent_mat, Vector3(0, s * 0.82, 0))

	# 发光环（TorusMesh）
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = s * 0.25
	torus.outer_radius = s * 0.32
	ring.mesh = torus
	var ring_mat := _make_mat(accent, 0.0, 0.3)
	ring_mat.emission = accent
	ring_mat.emission_energy_multiplier = 1.0
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(accent.r, accent.g, accent.b, 0.6)
	ring.set_surface_override_material(0, ring_mat)
	ring.position = Vector3(0, s * 0.55, 0)
	ring.rotation_degrees.x = 90
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)

## 弹道 Mesh/Material 缓存（避免每发弹道都新建，减轻 GPU 压力）
static var _projectile_mesh_cache: Dictionary = {}  # color_hex -> SphereMesh
static var _projectile_mat_cache: Dictionary = {}   # color_hex -> StandardMaterial3D

func _build_projectile(root: Node3D, color: Color, s: float) -> void:
	## 弹道：单个发光球体（轻量级，缓存复用）
	var key := color.to_html()
	var body_mesh: SphereMesh
	var body_mat: StandardMaterial3D
	if _projectile_mesh_cache.has(key):
		body_mesh = _projectile_mesh_cache[key]
		body_mat = _projectile_mat_cache[key]
	else:
		body_mesh = SphereMesh.new()
		body_mesh.radius = 0.15
		body_mesh.height = 0.3
		body_mat = StandardMaterial3D.new()
		body_mat.albedo_color = color
		body_mat.emission_enabled = true
		body_mat.emission = color
		body_mat.emission_energy_multiplier = 3.0
		body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_projectile_mesh_cache[key] = body_mesh
		_projectile_mat_cache[key] = body_mat
	var inst := MeshInstance3D.new()
	inst.mesh = body_mesh
	inst.set_surface_override_material(0, body_mat)
	inst.position = Vector3(0, s * 0.35, 0)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inst)

static var _outline_shader: Shader = null

func _apply_outline_to_model(root: Node3D) -> void:
	## 给模型的所有 MeshInstance3D 添加反面法描边（next_pass 材质）
	if _outline_shader == null:
		var path := "res://assets/shaders/outline.gdshader"
		if ResourceLoader.exists(path):
			_outline_shader = load(path) as Shader
	if _outline_shader == null:
		return
	var outline_mat := ShaderMaterial.new()
	outline_mat.shader = _outline_shader
	outline_mat.set_shader_parameter("outline_color", Color(0.08, 0.05, 0.03, 1.0))
	outline_mat.set_shader_parameter("outline_width", 0.025)
	_apply_outline_recursive(root, outline_mat)

func _apply_outline_recursive(node: Node, outline_mat: ShaderMaterial) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		# 给第一个 surface 的材质添加 next_pass
		var existing_mat: Material = mi.get_active_material(0)
		if existing_mat:
			existing_mat.next_pass = outline_mat
		elif mi.mesh and mi.mesh.get_surface_count() > 0:
			var base_mat := mi.mesh.surface_get_material(0)
			if base_mat:
				# 需要复制一份避免影响其他实例
				var mat_copy: Material = base_mat.duplicate()
				mat_copy.next_pass = outline_mat
				mi.set_surface_override_material(0, mat_copy)
	for child in node.get_children():
		_apply_outline_recursive(child, outline_mat)

func get_visual_node() -> Node3D:
	return _visual_node

# === 动画系统 ===

func _auto_detect_ref_speed() -> void:
	## 从 movement 组件获取 base_speed 作为动画参考速度
	if _entity and is_instance_valid(_entity) and _entity.has_method("get_component"):
		var mv: Node = _entity.get_component("movement")
		if mv and mv.get("base_speed") != null:
			_anim_ref_speed = mv.base_speed
	# 兜底：如果仍然为 0，使用保守默认值
	if _anim_ref_speed <= 0.0:
		_anim_ref_speed = 1.0

func _ensure_loop(anim_name: String) -> void:
	## 强制指定动画为循环模式（GLB 导入的动画可能未设 loop）
	if _anim_player == null:
		return
	var resolved := _resolve_anim_name(anim_name)
	if resolved == "":
		return
	var anim: Animation = _anim_player.get_animation(resolved)
	if anim and anim.loop_mode == Animation.LOOP_NONE:
		anim.loop_mode = Animation.LOOP_LINEAR

func _find_anim_player(node: Node) -> AnimationPlayer:
	## 递归查找 AnimationPlayer 节点
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found:
			return found
	return null

func _resolve_anim_name(anim_name: String) -> String:
	## 查找实际可用的动画名（支持回退）
	if _anim_player.has_animation(anim_name):
		return anim_name
	# 常见回退映射（KayKit / Mixamo / 通用命名）
	var fallbacks: Dictionary = {
		"Running_A": ["Running_B", "Run", "Walking_A", "Walk"],
		"Idle": ["Idle_A", "idle", "Standing"],
		"1H_Melee_Attack_Chop": ["1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Stab", "Attack", "attack"],
		"1H_Ranged_Aiming": ["1H_Ranged_Shoot", "1H_Melee_Attack_Chop", "Attack", "Shoot"],
		"Death_A": ["Death_B", "Death", "death", "Die"],
		"Spellcast_Shoot": ["Spellcasting", "Cast", "Spell", "1H_Melee_Attack_Chop"],
		"Hit_A": ["Hit_B", "Hit", "Hurt", "TakeHit"],
	}
	if fallbacks.has(anim_name):
		for alt: String in fallbacks[anim_name]:
			if _anim_player.has_animation(alt):
				return alt
	# 尝试模糊匹配（包含关键词）
	var keyword := anim_name.split("_")[0].to_lower()
	for a_name: StringName in _anim_player.get_animation_list():
		if (a_name as String).to_lower().contains(keyword):
			return a_name
	return ""

func _play_anim(anim_name: String, force: bool = false) -> void:
	if _anim_player == null or _is_dead:
		return
	if anim_name == _current_anim and not force:
		return
	var resolved := _resolve_anim_name(anim_name)
	if resolved != "":
		# Cross-fade 过渡（0.15 秒混合，消除硬切换感）
		if _anim_player.is_playing() and _current_anim != "":
			_anim_player.play(resolved, 0.15)
		else:
			_anim_player.play(resolved)
		_current_anim = anim_name  # 保持逻辑名用于状态判断

func play_attack() -> void:
	## 播放攻击动画（由 combat/projectile 触发）
	if _anim_player == null or _is_dead:
		return
	# 攻击动画加速：基础 2.0x，如果有攻速数据则匹配攻速
	var atk_speed_scale: float = 2.0
	if _entity and is_instance_valid(_entity) and _entity.has_method("get_component"):
		var combat: Node = _entity.get_component("combat")
		if combat and combat.get("attack_speed") != null:
			# 攻速越快动画越快，基准：1次/秒 = 2.0x 播放速度
			atk_speed_scale = clampf(float(combat.attack_speed) * 2.0, 1.5, 5.0)
		var inp: Node = _entity.get_component("player_input")
		if inp and inp.get("shoot_cooldown") != null:
			# 玩家：冷却越短动画越快
			atk_speed_scale = clampf(2.0 / maxf(float(inp.shoot_cooldown), 0.2), 1.5, 5.0)
	_anim_player.speed_scale = atk_speed_scale
	_play_anim(_attack_anim, true)
	# 攻击动画结束后自动回到 idle/run（双保险：信号 + 定时器）
	if not _anim_player.animation_finished.is_connected(_on_action_finished):
		_anim_player.animation_finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	# 定时器兜底：最多 0.5 秒后强制恢复（防止某些动画不触发 finished）
	if _entity and is_instance_valid(_entity) and _entity.get_tree():
		_entity.get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if _anim_player and not _is_dead and _current_anim == _attack_anim:
				_on_action_finished(_attack_anim)
		)

func play_spell() -> void:
	## 播放施法动画
	if _anim_player == null or _is_dead:
		return
	_anim_player.speed_scale = 2.0  # 施法动画加速
	_play_anim(_spell_anim, true)
	if not _anim_player.animation_finished.is_connected(_on_action_finished):
		_anim_player.animation_finished.connect(_on_action_finished, CONNECT_ONE_SHOT)

func play_hit() -> void:
	## 播放受击动画（仅在非动作状态时触发，避免打断攻击/施法）
	if _anim_player == null or _is_dead:
		return
	# 如果正在播放攻击/施法动画，不打断
	if _current_anim == _attack_anim or _current_anim == _spell_anim:
		if _anim_player.is_playing():
			return
	_play_anim(_hit_anim, true)
	if not _anim_player.animation_finished.is_connected(_on_action_finished):
		_anim_player.animation_finished.connect(_on_action_finished, CONNECT_ONE_SHOT)

func play_death() -> void:
	## 播放死亡（倒地）动画
	_is_dead = true
	if _anim_player:
		# 直接播放，绕过 _play_anim 的 _is_dead 检查
		var resolved := _resolve_anim_name(_death_anim)
		if resolved != "":
			_anim_player.speed_scale = 1.0
			_anim_player.play(resolved, 0.15)
			_current_anim = _death_anim
			return
	# 无动画播放器或无死亡动画 → 模拟倒地（向前倒下）
	if _entity and is_instance_valid(_entity):
		var tween := _entity.create_tween()
		tween.tween_property(_entity, "rotation_degrees:x", -90.0, 0.4).set_ease(Tween.EASE_IN)

func _on_action_finished(_anim_name: StringName) -> void:
	## 动作动画结束后恢复移动/待机动画
	if _is_dead:
		return
	# 检查是否在移动
	if _entity and is_instance_valid(_entity):
		var mv: Node = _entity.get_component("movement") if _entity.has_method("get_component") else null
		if mv and mv.get("velocity") and (mv.velocity as Vector3).length_squared() > 0.01:
			_play_anim(_run_anim)
		else:
			_play_anim(_idle_anim)

func _process(_delta: float) -> void:
	## 每帧检查移动状态，切换 idle ↔ run 动画 + 速度适配
	if _anim_player == null or _is_dead or _entity == null or not is_instance_valid(_entity):
		return
	# 如果正在播放动作动画（攻击/施法/受击），不打断
	if _current_anim == _attack_anim or _current_anim == _spell_anim or _current_anim == _hit_anim:
		if _anim_player.is_playing():
			return
	var mv: Node = _entity.get_component("movement") if _entity.has_method("get_component") else null
	if mv == null:
		return
	var vel: Vector3 = mv.velocity if mv.get("velocity") else Vector3.ZERO
	var speed: float = vel.length()
	if speed > 0.05:
		_play_anim(_run_anim)
		# 动画速度适配：按实际移动速度 / 参考速度 缩放播放速率
		# 这样步伐频率和移动距离完全匹配，不会出现"滑步"
		var speed_scale := clampf(speed / _anim_ref_speed, 0.3, 3.0)
		_anim_player.speed_scale = speed_scale
	else:
		_play_anim(_idle_anim)
		_anim_player.speed_scale = 1.0
