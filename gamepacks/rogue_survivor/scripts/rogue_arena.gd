## RogueArena -- 地图生成（地面/树木/岩石/废墟/粒子/灯光/刷怪点标记）
extends RefCounted

var _gm  # 主控制器引用 (rogue_game_mode)

## KayKit Dungeon 素材路径
const DUNGEON_PATH := "res://assets/models/dungeon/addons/kaykit_dungeon_remastered/Assets/gltf/"
## 程序化世界噪声
var _world_noise: FastNoiseLite = null
var _detail_noise: FastNoiseLite = null

func init(game_mode) -> void:
	_gm = game_mode

func draw_arena() -> void:
	var main_node: Node3D = _gm.get_tree().current_scene as Node3D
	var arena := Node3D.new()
	arena.name = "Arena"
	main_node.add_child(arena)
	main_node.move_child(arena, 0)

	# 初始化噪声生成器
	_world_noise = FastNoiseLite.new()
	_world_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_world_noise.frequency = 0.015
	_world_noise.seed = randi()
	_detail_noise = FastNoiseLite.new()
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail_noise.frequency = 0.08
	_detail_noise.seed = randi()

	_build_ground(arena)
	_build_edge_trees(arena)

	# 刷新点标记
	for sp in _gm.SPAWN_POINTS:
		arena.add_child(_create_spawn_marker(sp))

	# 氛围粒子
	_spawn_ambient_particles()

func _build_edge_trees(arena: Node3D) -> void:
	## 地图边缘的树木（带碰撞，不允许穿过）
	var trees := Node3D.new()
	trees.name = "EdgeTrees"
	arena.add_child(trees)

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.45, 0.3, 0.15)
	trunk_mat.roughness = 0.9

	# 四条边各放一排树，间距 3 米
	var spacing := 3.0
	var margin := -1.5  # 边缘外侧

	# 北边 (z = margin)
	var x := 0.0
	while x <= _gm.ARENA_SIZE.x:
		_place_tree_with_collision(trees, Vector3(x, 0, margin), trunk_mat)
		x += spacing + randf_range(-0.5, 0.5)

	# 南边 (z = ARENA_SIZE.y - margin)
	x = 0.0
	while x <= _gm.ARENA_SIZE.x:
		_place_tree_with_collision(trees, Vector3(x, 0, _gm.ARENA_SIZE.y - margin), trunk_mat)
		x += spacing + randf_range(-0.5, 0.5)

	# 西边 (x = margin)
	var z := 0.0
	while z <= _gm.ARENA_SIZE.y:
		_place_tree_with_collision(trees, Vector3(margin, 0, z), trunk_mat)
		z += spacing + randf_range(-0.5, 0.5)

	# 东边 (x = ARENA_SIZE.x - margin)
	z = 0.0
	while z <= _gm.ARENA_SIZE.y:
		_place_tree_with_collision(trees, Vector3(_gm.ARENA_SIZE.x - margin, 0, z), trunk_mat)
		z += spacing + randf_range(-0.5, 0.5)

func _place_tree_with_collision(parent: Node3D, pos: Vector3, trunk_mat: StandardMaterial3D) -> void:
	var tree := Node3D.new()
	tree.position = pos

	var h: float = randf_range(2.5, 4.0)
	var r: float = randf_range(0.8, 1.3)

	# 树干
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.08
	trunk_mesh.bottom_radius = 0.15
	trunk_mesh.height = h * 0.45
	trunk.mesh = trunk_mesh
	trunk.set_surface_override_material(0, trunk_mat)
	trunk.position = Vector3(0, h * 0.22, 0)
	tree.add_child(trunk)

	# 树冠
	var crown := MeshInstance3D.new()
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.0
	crown_mesh.bottom_radius = r * 0.5
	crown_mesh.height = h * 0.6
	crown.mesh = crown_mesh
	var crown_mat := StandardMaterial3D.new()
	var g_var: float = randf_range(-0.05, 0.05)
	crown_mat.albedo_color = Color(0.12 + g_var, 0.45 + g_var, 0.10 + g_var)
	crown_mat.roughness = 0.85
	crown.set_surface_override_material(0, crown_mat)
	crown.position = Vector3(0, h * 0.5, 0)
	tree.add_child(crown)

	# 碰撞体（StaticBody3D + CollisionShape3D）
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = h * 0.6
	shape.shape = capsule
	shape.position = Vector3(0, h * 0.3, 0)
	body.add_child(shape)
	tree.add_child(body)

	tree.rotation_degrees.y = randf_range(0, 360)
	parent.add_child(tree)

func _spawn_ambient_particles() -> void:
	var main_node: Node3D = _gm.get_tree().current_scene as Node3D
	if main_node == null:
		return

	# --- Dust motes / golden light particles ---
	var particles := GPUParticles3D.new()
	particles.name = "AmbientDust"
	particles.amount = 200
	particles.lifetime = 8.0
	particles.visibility_aabb = AABB(Vector3(-50, -2, -30), Vector3(100, 15, 60))
	particles.emitting = true

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(48, 5, 27)
	pmat.direction = Vector3(0.3, 0.5, 0.1)
	pmat.spread = 30.0
	pmat.initial_velocity_min = 0.1
	pmat.initial_velocity_max = 0.3
	pmat.gravity = Vector3(0, 0.05, 0)
	pmat.scale_min = 0.03
	pmat.scale_max = 0.08

	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.95, 0.7, 0.0))
	gradient.add_point(0.2, Color(1.0, 0.95, 0.7, 0.4))
	gradient.add_point(0.8, Color(1.0, 0.9, 0.6, 0.3))
	gradient.set_color(1, Color(1.0, 0.85, 0.5, 0.0))
	var color_tex := GradientTexture1D.new()
	color_tex.gradient = gradient
	pmat.color_ramp = color_tex

	particles.process_material = pmat
	particles.position = Vector3(_gm.ARENA_SIZE.x * 0.5, 3.0, _gm.ARENA_SIZE.y * 0.5)

	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	particles.draw_pass_1 = quad
	var draw_mat := StandardMaterial3D.new()
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(1.0, 0.9, 0.7)
	draw_mat.emission_energy_multiplier = 0.5
	particles.material_override = draw_mat

	main_node.add_child(particles)

	# --- Leaf / petal particles (subtle green, drifting down) ---
	var leaves := GPUParticles3D.new()
	leaves.name = "AmbientLeaves"
	leaves.amount = 50
	leaves.lifetime = 12.0
	leaves.visibility_aabb = AABB(Vector3(-50, -2, -30), Vector3(100, 15, 60))
	leaves.emitting = true

	var leaf_mat := ParticleProcessMaterial.new()
	leaf_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	leaf_mat.emission_box_extents = Vector3(48, 1, 27)
	leaf_mat.direction = Vector3(0.2, -0.3, 0.1)
	leaf_mat.spread = 25.0
	leaf_mat.initial_velocity_min = 0.05
	leaf_mat.initial_velocity_max = 0.15
	leaf_mat.gravity = Vector3(0, -0.08, 0)
	leaf_mat.scale_min = 0.05
	leaf_mat.scale_max = 0.12

	var leaf_gradient := Gradient.new()
	leaf_gradient.set_color(0, Color(0.4, 0.7, 0.3, 0.0))
	leaf_gradient.add_point(0.15, Color(0.4, 0.7, 0.3, 0.3))
	leaf_gradient.add_point(0.85, Color(0.35, 0.6, 0.25, 0.25))
	leaf_gradient.set_color(1, Color(0.3, 0.5, 0.2, 0.0))
	var leaf_color_tex := GradientTexture1D.new()
	leaf_color_tex.gradient = leaf_gradient
	leaf_mat.color_ramp = leaf_color_tex

	leaves.process_material = leaf_mat
	leaves.position = Vector3(_gm.ARENA_SIZE.x * 0.5, 8.0, _gm.ARENA_SIZE.y * 0.5)

	var leaf_quad := QuadMesh.new()
	leaf_quad.size = Vector2(0.15, 0.15)
	leaves.draw_pass_1 = leaf_quad
	var leaf_draw_mat := StandardMaterial3D.new()
	leaf_draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	leaf_draw_mat.vertex_color_use_as_albedo = true
	leaf_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	leaf_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	leaves.material_override = leaf_draw_mat

	main_node.add_child(leaves)

func spawn_light_beams() -> void:
	var main_node: Node3D = _gm.get_tree().current_scene as Node3D
	if main_node == null:
		return

	var beam_positions: Array[Vector3] = [
		Vector3(_gm.ARENA_SIZE.x * 0.3, 15, _gm.ARENA_SIZE.y * 0.4),
		Vector3(_gm.ARENA_SIZE.x * 0.7, 18, _gm.ARENA_SIZE.y * 0.6),
	]
	for bp in beam_positions:
		var spot := SpotLight3D.new()
		spot.position = bp
		spot.rotation_degrees.x = -80
		spot.light_color = Color(1.0, 0.95, 0.8, 1.0)
		spot.light_energy = 0.8
		spot.spot_range = 25.0
		spot.spot_angle = 15.0
		spot.spot_angle_attenuation = 0.5
		spot.shadow_enabled = false
		main_node.add_child(spot)

func _load_dungeon(asset_name: String) -> PackedScene:
	var path: String = DUNGEON_PATH + asset_name
	if ResourceLoader.exists(path):
		return load(path) as PackedScene
	return null

func _place_model(parent: Node3D, asset_name: String, pos: Vector3, rot_y: float = 0.0, scl: float = 1.0) -> Node3D:
	var scene := _load_dungeon(asset_name)
	if scene == null:
		return null
	var inst := scene.instantiate() as Node3D
	inst.position = pos
	if rot_y != 0.0:
		inst.rotation_degrees.y = rot_y
	if not is_equal_approx(scl, 1.0):
		inst.scale = Vector3(scl, scl, scl)
	parent.add_child(inst)
	return inst

func _build_ground(arena: Node3D) -> void:
	## 程序化地面：一整块 PlaneMesh + 噪声纹理（草地/泥土/石板混合）
	var tex_size := 2048
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)

	for px in range(tex_size):
		for py in range(tex_size):
			# 将纹理坐标映射到世界坐标
			var wx: float = (float(px) / tex_size) * _gm.ARENA_SIZE.x
			var wz: float = (float(py) / tex_size) * _gm.ARENA_SIZE.y

			# 主噪声决定地形类型
			var n: float = _world_noise.get_noise_2d(wx, wz)  # -1 ~ 1
			# 细节噪声增加变化
			var d: float = _detail_noise.get_noise_2d(wx, wz) * 0.15

			var color: Color
			if n < -0.2:
				# 深草地（森林区域）
				var g: float = 0.30 + d + randf_range(-0.02, 0.02)
				color = Color(0.12 + d * 0.3, g, 0.08, 1.0)
			elif n < 0.15:
				# 浅草地（开阔区域）
				var g: float = 0.42 + d + randf_range(-0.02, 0.02)
				color = Color(0.22 + d * 0.2, g, 0.12, 1.0)
			elif n < 0.35:
				# 泥土路径
				var b: float = 0.32 + d + randf_range(-0.02, 0.02)
				color = Color(b + 0.08, b, b - 0.06, 1.0)
			else:
				# 石板地面
				var s: float = 0.42 + d + randf_range(-0.02, 0.02)
				color = Color(s, s - 0.02, s - 0.04, 1.0)

			img.set_pixel(px, py, color)

	var tex := ImageTexture.create_from_image(img)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(_gm.ARENA_SIZE.x, _gm.ARENA_SIZE.y)
	ground.mesh = plane
	ground.position = Vector3(_gm.ARENA_SIZE.x * 0.5, 0, _gm.ARENA_SIZE.y * 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.92
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ground.set_surface_override_material(0, mat)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(ground)

func scatter_trees_procgen(arena: Node3D) -> void:
	## 程序化树木：噪声值低的区域（森林区）密集放置
	var trees := Node3D.new()
	trees.name = "Trees"
	arena.add_child(trees)

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.45, 0.3, 0.15)
	trunk_mat.roughness = 0.9

	# 网格采样：每 4 单位检查一次，噪声决定是否放树
	var step := 4.0
	var margin := 8.0  # 离关键区域的最小距离
	for wx in range(0, int(_gm.ARENA_SIZE.x), int(step)):
		for wz in range(0, int(_gm.ARENA_SIZE.y), int(step)):
			var x: float = wx + randf_range(-1.5, 1.5)
			var z: float = wz + randf_range(-1.5, 1.5)
			# 噪声值低的区域才放树（森林区）
			var n: float = _world_noise.get_noise_2d(x, z)
			if n > -0.15:
				continue
			# 避开关键区域（喷泉、英雄出生点、刷怪点）
			if _near_poi(Vector3(x, 0, z), margin):
				continue
			# 概率过滤（噪声越低越密）
			var density: float = clampf((-n - 0.15) * 3.0, 0.0, 0.8)
			if randf() > density:
				continue
			_spawn_proc_tree(trees, Vector3(x, 0, z), trunk_mat)

func _spawn_proc_tree(parent: Node3D, pos: Vector3, trunk_mat: StandardMaterial3D) -> void:
	var tree := Node3D.new()
	tree.position = pos
	var h: float = randf_range(2.0, 4.0)
	var r: float = randf_range(0.8, 1.5)
	# 树干
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.08
	trunk_mesh.bottom_radius = 0.15
	trunk_mesh.height = h * 0.45
	trunk.mesh = trunk_mesh
	trunk.set_surface_override_material(0, trunk_mat)
	trunk.position = Vector3(0, h * 0.22, 0)
	tree.add_child(trunk)
	# 树冠（2-3 层锥形）
	var layers: int = randi_range(1, 3)
	for i in range(layers):
		var crown := MeshInstance3D.new()
		var crown_mesh := CylinderMesh.new()
		var layer_r: float = r * (0.6 - i * 0.15)
		var layer_h: float = h * (0.4 - i * 0.08)
		crown_mesh.top_radius = 0.0
		crown_mesh.bottom_radius = layer_r
		crown_mesh.height = layer_h
		crown.mesh = crown_mesh
		var crown_mat := StandardMaterial3D.new()
		var g_var: float = randf_range(-0.06, 0.06)
		crown_mat.albedo_color = Color(0.12 + g_var, 0.45 + g_var, 0.10 + g_var)
		crown_mat.roughness = 0.85
		crown.set_surface_override_material(0, crown_mat)
		crown.position = Vector3(0, h * (0.45 + i * 0.22), 0)
		tree.add_child(crown)
	tree.rotation_degrees.y = randf_range(0, 360)
	parent.add_child(tree)

func scatter_rocks_procgen(arena: Node3D) -> void:
	## 程序化岩石：噪声值高的区域（石地）密集放置
	var rocks := Node3D.new()
	rocks.name = "Rocks"
	arena.add_child(rocks)

	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.5, 0.48, 0.44)
	rock_mat.roughness = 0.95

	var step := 6.0
	for wx in range(0, int(_gm.ARENA_SIZE.x), int(step)):
		for wz in range(0, int(_gm.ARENA_SIZE.y), int(step)):
			var x: float = wx + randf_range(-2.0, 2.0)
			var z: float = wz + randf_range(-2.0, 2.0)
			var n: float = _world_noise.get_noise_2d(x, z)
			if n < 0.2:
				continue
			if _near_poi(Vector3(x, 0, z), 6.0):
				continue
			if randf() > 0.5:
				continue
			var s: float = randf_range(0.3, 0.8)
			var rock := MeshInstance3D.new()
			var rock_mesh := BoxMesh.new()
			rock_mesh.size = Vector3(s * randf_range(0.7, 1.4), s * randf_range(0.5, 1.0), s * randf_range(0.7, 1.3))
			rock.mesh = rock_mesh
			rock.set_surface_override_material(0, rock_mat)
			rock.position = Vector3(x, s * 0.25, z)
			rock.rotation_degrees.y = randf_range(0, 360)
			rock.rotation_degrees.x = randf_range(-10, 10)
			rocks.add_child(rock)

func _near_poi(pos: Vector3, radius: float) -> bool:
	## 检查位置是否靠近关键兴趣点（避免在关键区域放障碍物）
	var pois: Array[Vector3] = [_gm.PLAYER_FOUNTAIN_POS, _gm.ENEMY_FOUNTAIN_POS, _gm.HERO_START_POS]
	pois.append_array(_gm.SPAWN_POINTS)
	for p in pois:
		if pos.distance_to(p) < radius:
			return true
	return false

func build_poi_areas(arena: Node3D) -> void:
	## 在关键兴趣点周围建造地牢风格的小型建筑群
	var pois := Node3D.new()
	pois.name = "POIs"
	arena.add_child(pois)

	# === 玩家喷泉区：石砖地面 + 柱子 + 火把 ===
	_build_camp(pois, _gm.PLAYER_FOUNTAIN_POS, "player")
	# === 敌方泉区：暗色营地 ===
	_build_camp(pois, _gm.ENEMY_FOUNTAIN_POS, "enemy")
	# === 地图中散布废墟遗迹 ===
	_scatter_ruins(pois)

func _build_camp(parent: Node3D, center: Vector3, camp_type: String) -> void:
	## 在指定位置建造一个小型营地（石砖 + 柱子 + 火把 + 道具）
	var camp := Node3D.new()
	camp.name = "Camp_" + camp_type
	parent.add_child(camp)

	# 石砖地面（3x3 区域）
	var tile_scene := _load_dungeon("floor_tile_small.gltf.glb")
	var decor_tile := _load_dungeon("floor_tile_small_decorated.gltf.glb")
	if tile_scene:
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var tile_s: PackedScene = decor_tile if (dx == 0 and dz == 0) else tile_scene
				if tile_s == null:
					tile_s = tile_scene
				var t := tile_s.instantiate() as Node3D
				t.position = center + Vector3(dx, 0.01, dz)
				t.rotation_degrees.y = [0.0, 90.0, 180.0, 270.0].pick_random()
				camp.add_child(t)

	# 四角柱子
	for dx in [-2.5, 2.5]:
		for dz in [-2.5, 2.5]:
			_place_model(camp, "pillar.gltf.glb", center + Vector3(dx, 0, dz))

	# 火把 + 光源
	var torch_offsets: Array[Vector3] = [
		Vector3(-2.5, 0, 0), Vector3(2.5, 0, 0),
		Vector3(0, 0, -2.5), Vector3(0, 0, 2.5),
	]
	for to in torch_offsets:
		var t_node := _place_model(camp, "torch_lit.gltf.glb", center + to)
		if t_node:
			_add_torch_light(t_node, Vector3(0, 1.5, 0))

	# 道具
	if camp_type == "player":
		_place_model(camp, "chest_gold.glb", center + Vector3(-1.5, 0, 1.5), -20.0)
		_place_model(camp, "barrel_large.gltf.glb", center + Vector3(1.8, 0, -1.5), 30.0)
		_place_model(camp, "banner_blue.gltf.glb", center + Vector3(0, 0, -2.8))
	else:
		_place_model(camp, "barrel_small_stack.gltf.glb", center + Vector3(-1.5, 0, -1.5))
		_place_model(camp, "crates_stacked.gltf.glb", center + Vector3(1.5, 0, 1.5), 45.0)
		_place_model(camp, "banner_red.gltf.glb", center + Vector3(0, 0, -2.8))

func _scatter_ruins(parent: Node3D) -> void:
	## 在地图中随机生成废墟遗迹
	var ruins := Node3D.new()
	ruins.name = "Ruins"
	parent.add_child(ruins)

	# 生成 8-12 个废墟点
	var ruin_count: int = randi_range(8, 12)
	var placed: Array[Vector3] = []
	for _i in range(ruin_count):
		# 随机选位置，避开 POI 和已有废墟
		var pos := Vector3.ZERO
		var valid := false
		for _try in range(20):
			pos = Vector3(randf_range(10, _gm.ARENA_SIZE.x - 10), 0, randf_range(10, _gm.ARENA_SIZE.y - 10))
			if _near_poi(pos, 15.0):
				continue
			var too_close := false
			for p in placed:
				if pos.distance_to(p) < 20.0:
					too_close = true
					break
			if too_close:
				continue
			valid = true
			break
		if not valid:
			continue
		placed.append(pos)
		_build_ruin(ruins, pos)

func _build_ruin(parent: Node3D, pos: Vector3) -> void:
	## 单个废墟：残墙 + 碎石砖 + 可能的火把
	var ruin := Node3D.new()
	ruin.position = pos
	parent.add_child(ruin)

	# 随机选择废墟类型
	var ruin_type: int = randi() % 4
	match ruin_type:
		0:  # L 形残墙
			_place_model(ruin, "wall_half.gltf.glb", Vector3(0, 0, 0))
			_place_model(ruin, "wall_half.gltf.glb", Vector3(2, 0, 0))
			_place_model(ruin, "wall_broken.gltf.glb", Vector3(0, 0, 2), 90.0)
		1:  # 柱子遗迹
			for dx in [-1.5, 1.5]:
				for dz in [-1.5, 1.5]:
					if randf() < 0.7:
						_place_model(ruin, "pillar.gltf.glb", Vector3(dx, 0, dz))
		2:  # 拱门废墟
			_place_model(ruin, "wall_arched.gltf.glb", Vector3(0, 0, 0))
			_place_model(ruin, "wall_cracked.gltf.glb", Vector3(2, 0, 0))
		3:  # 小型石砖平台
			var tile_s := _load_dungeon("floor_tile_small_broken_A.gltf.glb")
			if tile_s:
				for dx in range(-1, 2):
					for dz in range(-1, 2):
						if randf() < 0.7:
							var t := tile_s.instantiate() as Node3D
							t.position = Vector3(dx, 0.01, dz)
							t.rotation_degrees.y = randf_range(0, 360)
							ruin.add_child(t)

	# 废墟旁的装饰
	if randf() < 0.4:
		_place_model(ruin, "barrel_small.gltf.glb", Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), randf_range(0, 360))
	if randf() < 0.3:
		var t_node := _place_model(ruin, "torch_lit.gltf.glb", Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
		if t_node:
			_add_torch_light(t_node, Vector3(0, 1.5, 0))

func _add_torch_light(parent: Node3D, offset: Vector3) -> void:
	var light := OmniLight3D.new()
	light.position = offset
	light.light_color = Color(1.0, 0.75, 0.35)
	light.light_energy = 2.0
	light.omni_range = 8.0
	light.omni_attenuation = 1.5
	light.shadow_enabled = false
	parent.add_child(light)

func _create_spawn_marker(pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	# 扁平地面圆圈（QuadMesh 水平放置，避免穿模）
	var ring := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	ring.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.3, 0.3, 0.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# 不透视，会被模型正常遮挡
	ring.set_surface_override_material(0, mat)
	ring.rotation_degrees.x = -90  # 水平朝上
	ring.position = Vector3(0, 0.03, 0)  # 紧贴地面
	node.add_child(ring)
	return node
