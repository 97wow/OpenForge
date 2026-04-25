## RogueElite - 精英怪词条系统
## 每5波替换一个普通怪为精英，带金色视觉 + 1-2个随机词条
## 三重安全边界：(a) 词条效果标记 is_elite_proc 防止级联
## (b) 分裂小怪不继承词条 (c) 所有伤害/目标有硬上限
class_name RogueElite

var _gm  # 主控制器引用 (rogue_game_mode)
var _affix_config: Dictionary = {}  # elite_affixes.json 数据
var _elite_entities: Dictionary = {}  # runtime_id -> { entity, affixes, timers }
var _split_spawning: bool = false  # 防止分裂产物再次成为精英

# 词条 tick 计时器
var _lightning_timers: Dictionary = {}  # runtime_id -> float
var _shield_timers: Dictionary = {}  # runtime_id -> float
var _frost_aura_timers: Dictionary = {}  # runtime_id -> float

const AFFIX_POOL: Array[String] = [
	"reflect", "lightning_shield", "splitting",
	"vampiric", "frost_aura", "enrage", "shielded", "thorns"
]

func init(game_mode) -> void:
	_gm = game_mode
	# 加载词条配置
	var path: String = _gm.pack.pack_path.path_join("elite_affixes.json")
	_affix_config = DataRegistry.load_file("elite_affixes", path)
	# 监听伤害事件（用于反射 / 荆棘）
	EventBus.connect_event("entity_damaged", _on_entity_damaged)

# === 精英生成 ===

func is_elite_wave(wave: int) -> bool:
	## 判断当前波次是否应该出精英
	var config: Dictionary = _affix_config.get("elite_config", {})
	var elite_waves: Array = config.get("elite_waves", [5, 13, 17, 21, 25, 29])
	var boss_waves: Array = config.get("boss_waves", [10, 20, 30])
	# BOSS 波不出精英
	if wave in boss_waves:
		return false
	# 精确匹配指定波次
	if wave in elite_waves:
		return true
	# 30 波之后每 5 波出精英（排除 BOSS 波）
	if wave > 30 and wave % 5 == 0 and wave % 10 != 0:
		return true
	return false

func promote_to_elite(entity: Node3D) -> void:
	## 将普通怪提升为精英怪
	if entity == null or not is_instance_valid(entity):
		return
	if not (entity is GameEntity):
		return
	if _split_spawning:
		return  # 分裂产物不能成为精英

	var ge := entity as GameEntity
	var config: Dictionary = _affix_config.get("elite_config", {})
	var hp_mult: float = config.get("hp_multiplier", 3.0)
	var dmg_mult: float = config.get("damage_multiplier", 1.5)
	var size_mult: float = config.get("size_multiplier", 1.6)
	var xp_mult: int = config.get("xp_multiplier", 5)
	var gold_mult: int = config.get("gold_multiplier", 3)

	# 标记为精英
	ge.add_tag("elite")
	ge.set_meta_value("is_elite", true)

	# 属性强化
	var health: Node = EngineAPI.get_component(entity, "health")
	if health:
		health.max_hp *= hp_mult
		health.current_hp = health.max_hp
	var combat: Node = EngineAPI.get_component(entity, "combat")
	if combat:
		combat.damage *= dmg_mult

	# 增加奖励
	var old_xp: int = int(ge.get_meta_value("xp_reward", 3))
	ge.set_meta_value("xp_reward", old_xp * xp_mult)
	var old_gold: int = int(ge.get_meta_value("gold_reward", 2))
	ge.set_meta_value("gold_reward", old_gold * gold_mult)

	# 随机词条 1-2 个
	var min_affixes: int = config.get("min_affixes", 1)
	var max_affixes: int = config.get("max_affixes", 2)
	var affix_count: int = randi_range(min_affixes, max_affixes)
	var pool := AFFIX_POOL.duplicate()
	pool.shuffle()
	var chosen_affixes: Array[String] = []
	for i in range(mini(affix_count, pool.size())):
		chosen_affixes.append(pool[i])

	ge.set_meta_value("elite_affixes", chosen_affixes)

	# 记录精英数据
	var rid: int = ge.runtime_id
	_elite_entities[rid] = {
		"entity": entity,
		"affixes": chosen_affixes,
		"enraged": false,
		"original_attack_speed": combat.attack_speed if combat else 1.0,
	}
	_lightning_timers[rid] = 0.0
	_shield_timers[rid] = 0.0
	_frost_aura_timers[rid] = 0.0

	# 视觉区分：金色 + 更大体型
	_apply_elite_visual(entity, size_mult)

	# 词条名称日志
	var I18n: Node = _gm.I18n
	var affix_names: Array[String] = []
	for aff in chosen_affixes:
		var aff_data: Dictionary = _affix_config.get("affixes", {}).get(aff, {})
		var name_key: String = aff_data.get("name_key", "AFFIX_" + aff.to_upper())
		affix_names.append(I18n.t(name_key))
	var elite_msg: String = I18n.t("ELITE_SPAWN", [ge.def_id, ", ".join(affix_names)])
	_gm._combat_log_module._add_log(elite_msg, Color(1.0, 0.84, 0.0))

func _apply_elite_visual(entity: Node3D, size_mult: float) -> void:
	## 精英怪视觉：放大体型 + 金色光圈 + "精英"标签
	entity.scale *= size_mult

	# 金色光圈（3D TorusMesh）
	var glow := MeshInstance3D.new()
	glow.name = "EliteGlow"
	var glow_radius: float = 1.0
	var torus := TorusMesh.new()
	torus.inner_radius = glow_radius * 0.85
	torus.outer_radius = glow_radius
	glow.mesh = torus
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.84, 0.0, 0.6)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.84, 0.0)
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.set_surface_override_material(0, glow_mat)
	glow.rotation_degrees.x = 90
	glow.position = Vector3(0, 0.05, 0)
	entity.add_child(glow)

	# 精英标签（头顶 Label3D）
	var label := Label3D.new()
	var I18n: Node = _gm.I18n
	label.text = I18n.t("ELITE_TAG")
	label.font_size = 32
	label.modulate = Color(1.0, 0.84, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# 反向缩放回正常大小（因为父节点已被放大）
	var inv_scale: float = 1.0 / size_mult
	label.scale = Vector3(inv_scale, inv_scale, inv_scale)
	label.position = Vector3(0, 2.0 / size_mult, 0)
	entity.add_child(label)

# === 每帧处理（由 _pack_process 调用）===

func process_elites(delta: float) -> void:
	var remove_ids: Array = []
	for rid in _elite_entities:
		var data: Dictionary = _elite_entities[rid]
		var entity = data.get("entity")
		if entity == null or not is_instance_valid(entity):
			remove_ids.append(rid)
			continue
		var affixes: Array = data.get("affixes", [])
		for aff in affixes:
			match str(aff):
				"lightning_shield":
					_process_lightning_shield(rid, entity, delta)
				"frost_aura":
					_process_frost_aura(rid, entity, delta)
				"enrage":
					_process_enrage(rid, entity, data)
				"shielded":
					_process_shielded(rid, entity, delta)
	for rid in remove_ids:
		_elite_entities.erase(rid)
		_lightning_timers.erase(rid)
		_shield_timers.erase(rid)
		_frost_aura_timers.erase(rid)

# === 词条 tick 效果 ===

func _process_lightning_shield(rid: int, entity: Node3D, delta: float) -> void:
	## 闪电盾：每3秒对最近敌人释放闪电
	var aff_data: Dictionary = _affix_config.get("affixes", {}).get("lightning_shield", {})
	var interval: float = aff_data.get("tick_interval", 3.0)
	var dmg: float = aff_data.get("damage", 12)
	var aff_range: float = aff_data.get("range", 1.0)

	_lightning_timers[rid] = _lightning_timers.get(rid, 0.0) + delta
	if _lightning_timers[rid] < interval:
		return
	_lightning_timers[rid] -= interval

	# 查找最近的玩家方目标
	var targets: Array = EngineAPI.find_hostiles_in_area(entity, entity.global_position, aff_range)
	if targets.is_empty():
		return
	# 取最近的一个
	var closest: Node3D = null
	var closest_dist: float = INF
	for t in targets:
		if not is_instance_valid(t):
			continue
		var d: float = entity.global_position.distance_squared_to(t.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = t
	if closest == null:
		return
	var h: Node = EngineAPI.get_component(closest, "health")
	if h and h.has_method("take_damage"):
		# 标记 is_proc 防止级联
		h.take_damage(dmg, entity, 4, "elite_lightning", true)
	# 闪电VFX
	_gm._combat_module._draw_lightning_arc(entity.global_position, closest.global_position)

func _process_frost_aura(rid: int, entity: Node3D, delta: float) -> void:
	## 冰冻光环：减速附近80范围内的玩家方单位15%
	var aff_data: Dictionary = _affix_config.get("affixes", {}).get("frost_aura", {})
	var interval: float = aff_data.get("tick_interval", 1.0)
	var aff_range: float = aff_data.get("range", 0.8)
	var slow_pct: float = aff_data.get("slow_pct", 0.15)

	_frost_aura_timers[rid] = _frost_aura_timers.get(rid, 0.0) + delta
	if _frost_aura_timers[rid] < interval:
		return
	_frost_aura_timers[rid] -= interval

	var targets: Array = EngineAPI.find_hostiles_in_area(entity, entity.global_position, aff_range)
	# 最多影响 6 个目标
	var count := 0
	for t in targets:
		if not is_instance_valid(t):
			continue
		var mv: Node = EngineAPI.get_component(t, "movement")
		if mv and mv.has_method("add_speed_modifier"):
			# 覆盖式减速（不叠加）
			mv.remove_speed_modifier("elite_frost_aura")
			mv.add_speed_modifier("elite_frost_aura", 1.0 - slow_pct)
			_gm._combat_module._delayed_remove_speed_mod(mv, "elite_frost_aura", 1.5)
		count += 1
		if count >= 6:
			break

func _process_enrage(_rid: int, entity: Node3D, data: Dictionary) -> void:
	## 狂暴：HP<50%时攻速×2
	var aff_data: Dictionary = _affix_config.get("affixes", {}).get("enrage", {})
	var threshold: float = aff_data.get("hp_threshold", 0.5)
	var aspd_mult: float = aff_data.get("attack_speed_mult", 2.0)

	var health: Node = EngineAPI.get_component(entity, "health")
	if health == null:
		return
	var ratio: float = health.get_hp_ratio() if health.has_method("get_hp_ratio") else 1.0
	var already_enraged: bool = data.get("enraged", false)

	if ratio < threshold and not already_enraged:
		data["enraged"] = true
		var combat: Node = EngineAPI.get_component(entity, "combat")
		if combat:
			combat.attack_speed /= aspd_mult  # attack_speed 是间隔，除以=加速
		# 视觉提示：红色闪烁
		_flash_entity(entity, Color(1, 0.2, 0.2, 0.5))

func _process_shielded(rid: int, entity: Node3D, delta: float) -> void:
	## 护盾：每10秒恢复20%最大HP的护盾（直接回血）
	var aff_data: Dictionary = _affix_config.get("affixes", {}).get("shielded", {})
	var interval: float = aff_data.get("interval", 10.0)
	var shield_pct: float = aff_data.get("shield_pct", 0.2)

	_shield_timers[rid] = _shield_timers.get(rid, 0.0) + delta
	if _shield_timers[rid] < interval:
		return
	_shield_timers[rid] -= interval

	var health: Node = EngineAPI.get_component(entity, "health")
	if health and health.has_method("heal"):
		var heal_amount: float = health.max_hp * shield_pct
		health.heal(heal_amount, entity, "elite_shield")
	# 护盾VFX
	_flash_entity(entity, Color(0.3, 0.7, 1.0, 0.4))

# === 事件驱动的词条效果 ===

func _on_entity_damaged(data: Dictionary) -> void:
	## 反射 + 荆棘：精英被玩家攻击时触发
	var entity = data.get("entity")
	var source = data.get("source")
	var amount: float = data.get("amount", 0.0)
	var ability: String = str(data.get("ability", ""))
	# 安全边界：精英词条造成的伤害不触发反射（防止无限级联）
	if ability.begins_with("elite_"):
		return
	var is_proc: bool = data.get("is_proc", false)
	if is_proc:
		return
	if entity == null or not is_instance_valid(entity):
		return
	if not (entity is GameEntity):
		return
	var ge := entity as GameEntity
	if not ge.get_meta_value("is_elite", false):
		return
	if source == null or not is_instance_valid(source):
		return
	# 只处理玩家对精英的伤害
	if not (source is Node3D and source.has_method("has_tag") and source.has_tag("player")):
		return

	var affixes: Array = ge.get_meta_value("elite_affixes", [])

	# 反射词条
	if "reflect" in affixes:
		var aff_data: Dictionary = _affix_config.get("affixes", {}).get("reflect", {})
		var reflect_pct: float = aff_data.get("reflect_pct", 0.15)
		var reflect_dmg: float = minf(amount * reflect_pct, 50.0)  # 硬上限 50
		var source_health: Node = EngineAPI.get_component(source, "health")
		if source_health and source_health.has_method("take_damage"):
			# is_proc=true 防止再次触发
			source_health.take_damage(reflect_dmg, entity, 0, "elite_reflect", true)

	# 荆棘词条
	if "thorns" in affixes:
		var aff_data: Dictionary = _affix_config.get("affixes", {}).get("thorns", {})
		var flat_dmg: float = aff_data.get("flat_damage", 10)
		var source_health: Node = EngineAPI.get_component(source, "health")
		if source_health and source_health.has_method("take_damage"):
			# is_proc=true 防止再次触发
			source_health.take_damage(flat_dmg, entity, 0, "elite_thorns", true)

	# 吸血词条（攻击回复HP）— 只在精英攻击命中时（entity_damaged 中 source 是精英）
	# 注意：这里 entity 是受伤方（精英被打），吸血应在精英打人时触发
	# 吸血在 _on_elite_deals_damage 中处理

func on_elite_deals_damage(data: Dictionary) -> void:
	## 精英造成伤害时的吸血效果（由 entity_damaged 中 source 是精英时调用）
	var source = data.get("source")
	var amount: float = data.get("amount", 0.0)
	var ability: String = str(data.get("ability", ""))
	# 安全边界：词条伤害不触发吸血
	if ability.begins_with("elite_"):
		return
	if source == null or not is_instance_valid(source):
		return
	if not (source is GameEntity):
		return
	var ge := source as GameEntity
	if not ge.get_meta_value("is_elite", false):
		return
	var affixes: Array = ge.get_meta_value("elite_affixes", [])
	if "vampiric" not in affixes:
		return
	var aff_data: Dictionary = _affix_config.get("affixes", {}).get("vampiric", {})
	var heal_pct: float = aff_data.get("heal_pct", 0.05)
	var heal_amount: float = minf(amount * heal_pct, 20.0)  # 硬上限 20
	var health: Node = EngineAPI.get_component(source, "health")
	if health and health.has_method("heal"):
		health.heal(heal_amount, source, "elite_vampiric")

# === 精英死亡处理（分裂词条）===

func on_elite_destroyed(entity: Node3D) -> void:
	## 精英死亡时处理分裂词条 + 保底卡片经验
	if entity == null or not is_instance_valid(entity):
		return
	if not (entity is GameEntity):
		return
	var ge := entity as GameEntity
	if not ge.get_meta_value("is_elite", false):
		return

	var affixes: Array = ge.get_meta_value("elite_affixes", [])
	var rid: int = ge.runtime_id

	# 分裂词条：死亡分裂为2个50%HP小怪（不继承精英属性）
	if "splitting" in affixes:
		var aff_data: Dictionary = _affix_config.get("affixes", {}).get("splitting", {})
		var split_count: int = mini(aff_data.get("split_count", 2), 3)  # 硬上限 3
		var hp_ratio: float = aff_data.get("hp_ratio", 0.5)
		var base_hp: float = 0.0
		var health: Node = EngineAPI.get_component(entity, "health")
		if health:
			# 用原始 max_hp / 精英倍率 = 普通怪 HP
			var config: Dictionary = _affix_config.get("elite_config", {})
			var elite_hp_mult: float = config.get("hp_multiplier", 3.0)
			base_hp = health.max_hp / elite_hp_mult

		_split_spawning = true  # 防止分裂产物被提升为精英
		for i in range(split_count):
			var offset := Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
			var spawn_pos: Vector3 = ge.global_position + offset
			var minion: Node3D = _gm.spawn(ge.def_id, spawn_pos)
			if minion:
				var m_health: Node = EngineAPI.get_component(minion, "health")
				if m_health and base_hp > 0:
					m_health.max_hp = base_hp * hp_ratio
					m_health.current_hp = m_health.max_hp
		_split_spawning = false

	# 保底蓝色品质卡片经验（通过 xp_reward 加成已在 promote_to_elite 中设置）
	# 额外奖励：给玩家发放一些卡片经验
	EngineAPI.add_resource("xp", 15)  # 保底卡片经验

	# 清理
	_elite_entities.erase(rid)
	_lightning_timers.erase(rid)
	_shield_timers.erase(rid)
	_frost_aura_timers.erase(rid)

# === 辅助 ===

func _flash_entity(entity: Node3D, color: Color) -> void:
	## 短暂闪烁效果（3D 球体闪光）
	if not is_instance_valid(entity):
		return
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	flash.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.set_surface_override_material(0, mat)
	flash.position = Vector3(0, 0.5, 0)
	entity.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(flash.queue_free)

func is_entity_elite(entity: Node3D) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	if not (entity is GameEntity):
		return false
	return (entity as GameEntity).get_meta_value("is_elite", false)
