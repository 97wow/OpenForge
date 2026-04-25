## RogueCombat - 射击、命中效果、Shaman 治疗、BOSS 技能
class_name RogueCombat

var _gm  # 主控制器引用 (rogue_game_mode)

func init(game_mode) -> void:
	_gm = game_mode

# === 射击 ===

func on_player_shoot(data: Dictionary) -> void:
	var pos: Vector3 = data.get("position", Vector3.ZERO)
	var dir: Vector3 = data.get("direction", Vector3.RIGHT)
	var spd: float = data.get("speed", 6.5)
	var dmg: float = data.get("damage", 12.0)
	var proj_id: String = data.get("projectile_id", "arrow")
	var shooter: Node3D = data.get("shooter", null)

	# 击杀永久叠加伤害（reaper/soul_harvest 效果）
	var perm_dmg: float = float(EngineAPI.get_variable("_hero_perm_damage_stacks", 0.0))
	if perm_dmg > 0:
		dmg += perm_dmg

	_gm.spawn(proj_id, pos, {
		"components": {
			"projectile": {
				"direction": dir,
				"speed": spd,
				"damage": dmg,
				"source": shooter,
				"target_tag": "enemy",
				"pierce_count": 0,
				"ability_name": proj_id,
			}
		}
	})

# === 命中效果处理 ===

func on_projectile_hit(data: Dictionary) -> void:
	var target = data.get("target")  # Variant: 避免强类型赋值已释放实例
	var source = data.get("source")
	var base_damage: float = data.get("damage", 0)
	# 从投射物读取技能名
	var proj = data.get("projectile")
	var hit_ability: String = ""
	if proj and is_instance_valid(proj):
		var proj_comp: Node = EngineAPI.get_component(proj, "projectile")
		if proj_comp:
			hit_ability = proj_comp.ability_name
	if target == null or source == null:
		return
	if not is_instance_valid(target) or not is_instance_valid(source):
		return
	if not (source is Node3D and source.has_method("has_tag") and source.has_tag("player")):
		return

	# 非暴击：手动显示伤害数字（暴击已由 damage_pipeline.gd 处理）
	if is_instance_valid(target) and target is Node3D:
		var health: Node = EngineAPI.get_component(target, "health")
		if health:
			health._spawn_damage_number(base_damage, 0, hit_ability)

	# --- 吸血 ---
	var life_steal: float = float(EngineAPI.get_variable("hero_life_steal", 0.0))
	if life_steal > 0:
		var hero_health: Node = EngineAPI.get_component(_gm.hero, "health")
		if hero_health and hero_health.has_method("heal"):
			# 低血量双倍（Blood Frenzy 效果）
			var low_hp_mult: float = float(EngineAPI.get_variable("hero_low_hp_lifesteal_mult", 1.0))
			if hero_health.get_hp_ratio() < 0.5 and low_hp_mult > 1.0:
				life_steal *= low_hp_mult
			var heal_amount := base_damage * life_steal
			hero_health.heal(heal_amount, _gm.hero, "life_steal")

# === 暴击标签（供 damage_pipeline 调用）===

func _translate_ability(ability: String) -> String:
	var I18n: Node = _gm.I18n
	if I18n:
		var key: String = "ABILITY_" + ability.to_upper()
		var result: String = I18n.t(key)
		if result != key:
			return result
	return ability.replace("_", " ").capitalize()

func _spawn_crit_label(target_node: Node3D, crit_total: float, ability: String = "") -> void:
	if not HealthComponent.can_spawn_label():
		return
	var crit_label := Label3D.new()
	var I18n: Node = _gm.I18n
	var ab_name: String = _translate_ability(ability) if ability != "" else (I18n.t("ABILITY_ATTACK") if I18n else "Attack")
	var crit_tag: String = I18n.t("LOG_CRIT") if I18n else "Crit!"
	crit_label.text = "%s %d（%s）" % [ab_name, int(crit_total), crit_tag]
	crit_label.font_size = 48
	crit_label.modulate = Color(1, 0.9, 0.2)
	crit_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	crit_label.no_depth_test = true
	crit_label.render_priority = 20
	crit_label.position = target_node.global_position + Vector3(randf_range(-0.5, 0.5), 2.0, 0)
	var scene_root: Node = _gm.get_tree().current_scene
	if scene_root:
		scene_root.add_child(crit_label)
	else:
		target_node.add_child(crit_label)
	var tw := crit_label.create_tween()
	tw.tween_property(crit_label, "position:y", crit_label.position.y + 2.0, 0.6).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(crit_label, "modulate:a", 0.0, 0.5).set_delay(0.1)
	HealthComponent.inc_label_count()
	tw.tween_callback(func() -> void:
		HealthComponent.dec_label_count()
		crit_label.queue_free()
	)

# === 闪电弧 VFX（供 elite 模块调用）===

func _draw_lightning_arc(from_pos: Vector3, to_pos: Vector3) -> void:
	## 画一条闪电弧线 VFX（ImmediateMesh 锯齿线 + 淡出）
	var scene_root: Node = _gm.get_tree().current_scene
	if scene_root == null:
		return
	var mesh_inst := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	mesh_inst.mesh = im
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.92, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.75, 0.92, 1.0)
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# 先画 ImmediateMesh（创建 surface），再设材质
	var dir: Vector3 = to_pos - from_pos
	var dist: float = dir.length()
	var segments: int = maxi(3, int(dist / 1.5))
	var step: Vector3 = dir / segments
	var perp: Vector3 = dir.cross(Vector3.UP).normalized()
	if perp.length_squared() < 0.01:
		perp = Vector3.RIGHT
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	im.surface_add_vertex(from_pos)
	for si in range(1, segments):
		var base: Vector3 = from_pos + step * si
		var jitter: float = randf_range(-0.5, 0.5)
		im.surface_add_vertex(base + perp * jitter)
	im.surface_add_vertex(to_pos)
	im.surface_end()
	mesh_inst.set_surface_override_material(0, mat)
	scene_root.add_child(mesh_inst)
	# 淡出
	var tw := mesh_inst.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(mesh_inst.queue_free)

func _delayed_remove_speed_mod(move_comp: Node, mod_id: String, delay: float) -> void:
	await _gm.get_tree().create_timer(delay).timeout
	if is_instance_valid(move_comp):
		move_comp.remove_speed_modifier(mod_id)

# === Shaman 治疗 ===

func process_shaman_heals(delta: float) -> void:
	_gm._shaman_heal_timer += delta
	if _gm._shaman_heal_timer < _gm.SHAMAN_HEAL_TICK:
		return
	_gm._shaman_heal_timer -= _gm.SHAMAN_HEAL_TICK

	# 查找所有 shaman，治疗附近友方
	var shamans: Array = EngineAPI.find_entities_by_tag("healer")
	for shaman in shamans:
		if shaman == null or not is_instance_valid(shaman):
			continue
		if not (shaman is GameEntity):
			continue
		var heal_range: float = (shaman as GameEntity).get_meta_value("heal_range", 1.2)
		var heal_amount: float = (shaman as GameEntity).get_meta_value("heal_amount", 8.0)
		var nearby: Array = EngineAPI.find_allies_in_area(shaman, shaman.global_position, heal_range)
		for ally in nearby:
			if ally == shaman or ally == null or not is_instance_valid(ally):
				continue
			var health: Node = EngineAPI.get_component(ally, "health")
			if health and health.has_method("heal") and health.get_hp_ratio() < 1.0:
				health.heal(heal_amount, shaman, "shaman_heal")

# === BOSS 技能 ===

func process_boss_skills(delta: float) -> void:
	var remove_ids: Array = []
	for eid in _gm._spawner.boss_skill_timers:
		var data: Dictionary = _gm._spawner.boss_skill_timers[eid]
		var boss: Node3D = data.get("entity")
		if boss == null or not is_instance_valid(boss):
			remove_ids.append(eid)
			continue

		var spells: Array = data.get("spells", [])
		var cooldowns: Dictionary = data.get("cooldowns", {})
		for spell_id in spells:
			var sid: String = str(spell_id)
			cooldowns[sid] = cooldowns.get(sid, 0.0) - delta
			if cooldowns[sid] <= 0.0:
				_execute_boss_spell(boss, sid)
				# 重置冷却（从 spell JSON 读取或默认 5s）
				var spell_data: Dictionary = _get_spell_data(sid)
				var cd: float = spell_data.get("cooldown", 5.0)
				cooldowns[sid] = cd
		data["cooldowns"] = cooldowns

	for eid in remove_ids:
		_gm._spawner.boss_skill_timers.erase(eid)

	# 清理死亡的 BOSS
	var alive_bosses: Array[Node3D] = []
	for b in _gm._spawner.active_bosses:
		if b != null and is_instance_valid(b):
			alive_bosses.append(b)
	_gm._spawner.active_bosses = alive_bosses

func _get_spell_data(spell_id: String) -> Dictionary:
	var spell_sys: Node = EngineAPI.get_system("spell")
	if spell_sys:
		return spell_sys.call("get_spell", spell_id)
	return {}

func _execute_boss_spell(boss: Node3D, spell_id: String) -> void:
	## BOSS 技能执行：AOE 伤害 / 召唤小怪
	var spell_data: Dictionary = _get_spell_data(spell_id)
	if spell_data.is_empty():
		return

	var effects: Array = spell_data.get("effects", [])
	for effect in effects:
		if not effect is Dictionary:
			continue
		var etype: String = effect.get("type", "")
		match etype:
			"AREA_DAMAGE":
				_boss_area_damage(boss, effect)
			"TRIGGER_SPELL":
				# 召唤类：在 BOSS 附近刷小怪
				_boss_summon(boss)

	_gm._combat_log_module._add_log("[BOSS] %s -> %s" % [_get_entity_name(boss), spell_id], Color(1, 0.4, 0.1))

	# VFX
	var vfx: Node = EngineAPI.get_system("vfx")
	if vfx and is_instance_valid(boss):
		vfx.call("spawn_vfx", "boss_cast", (boss as Node3D).global_position)

func parse_damage_type(type_str: String) -> int:
	## 与 HealthComponent.DamageType 枚举对齐:
	## PHYSICAL=0, FROST=1, FIRE=2, NATURE=3, SHADOW=4, HOLY=5
	match type_str.to_lower():
		"physical": return 0
		"frost", "ice": return 1
		"fire": return 2
		"nature", "poison": return 3
		"shadow": return 4
		"holy": return 5
		_: return 0

func get_damage_color(damage_type: int) -> Color:
	## 与 HealthComponent.DAMAGE_COLORS 对齐
	match damage_type:
		0: return Color(1.0, 1.0, 1.0)         # physical
		1: return Color(0.31, 0.78, 1.0)        # frost
		2: return Color(1.0, 0.49, 0.16)        # fire
		3: return Color(0.30, 0.87, 0.30)       # nature
		4: return Color(0.64, 0.21, 0.93)       # shadow
		5: return Color(1.0, 0.90, 0.35)        # holy
		_: return Color.WHITE

func _boss_area_damage(boss: Node3D, effect: Dictionary) -> void:
	var radius: float = effect.get("radius", 1.5)
	var base_dmg: float = effect.get("base_value", 30.0)
	var dmg_type_str: String = effect.get("damage_type", "physical")
	var dmg_type: int = parse_damage_type(dmg_type_str)

	# 对玩家和友方泉造成伤害
	var targets: Array = []
	if _gm.hero and is_instance_valid(_gm.hero):
		if _gm.hero.global_position.distance_to(boss.global_position) <= radius:
			targets.append(_gm.hero)
	if _gm.player_fountain and is_instance_valid(_gm.player_fountain):
		if _gm.player_fountain.global_position.distance_to(boss.global_position) <= radius:
			targets.append(_gm.player_fountain)

	for t in targets:
		var health: Node = EngineAPI.get_component(t, "health")
		if health and health.has_method("take_damage"):
			health.take_damage(base_dmg, boss, dmg_type, "boss_aoe")

	# AOE 视觉指示
	if is_instance_valid(boss):
		var c: Color = get_damage_color(dmg_type)
		var ring := MeshInstance3D.new()
		ring.position = boss.global_position + Vector3(0, 0.1, 0)
		var torus := TorusMesh.new()
		torus.inner_radius = radius * 0.9
		torus.outer_radius = radius
		ring.mesh = torus
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(c.r, c.g, c.b, 0.4)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = c
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.set_surface_override_material(0, mat)
		ring.rotation_degrees.x = 90
		_gm.get_tree().current_scene.add_child(ring)
		var tw := ring.create_tween()
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.6)
		tw.tween_callback(ring.queue_free)

func _boss_summon(boss: Node3D) -> void:
	## Shadow Lord 召唤小怪
	var summon_count := 3
	for i in range(summon_count):
		var offset := Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
		_gm.spawn("shadow", boss.global_position + offset)
	_gm._combat_log_module._add_log("[BOSS] Summoned %d minions!" % summon_count, Color(0.7, 0.3, 1))

# === 实体辅助 ===

func _get_entity_name(entity: Variant) -> String:
	if entity == null or not is_instance_valid(entity):
		return "?"
	if entity is GameEntity:
		return (entity as GameEntity).def_id
	return "?"
