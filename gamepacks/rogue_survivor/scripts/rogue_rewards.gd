## RogueRewards -- 击杀奖励、资源飘字、伤害统计、战绩保存、游戏结束面板
extends RefCounted

var _gm  # 主控制器引用 (rogue_game_mode)

func init(game_mode) -> void:
	_gm = game_mode

# === 击杀奖励 ===

func on_entity_killed(data: Dictionary) -> void:
	## 怪物被击杀时立即给奖励+飘字（此时实体还在场，还没开始死亡动画）
	var entity = data.get("entity")
	if entity == null or not is_instance_valid(entity):
		return
	if not (entity is GameEntity and (entity as GameEntity).has_tag("enemy")):
		return
	_gm._kills += 1
	EngineAPI.add_resource("kills", 1)
	var I18n: Node = _gm.I18n
	var gold_name: String = I18n.t("GOLD") if I18n else "Gold"
	var wood_name: String = I18n.t("WOOD") if I18n else "Wood"
	var is_elite: bool = _gm._elite_module != null and _gm._elite_module.is_entity_elite(entity)
	var is_elite_minion: bool = (entity as GameEntity).get_meta_value("elite_minion", false)
	if is_elite:
		EngineAPI.add_resource("wood", 15)
		spawn_resource_text(entity, "+15 %s" % wood_name, Color(0.4, 0.75, 0.25))
		if _gm._hud_module:
			_gm._hud_module.add_announcement("+15 %s (Elite)" % wood_name, Color(0.6, 0.45, 0.25))
		if is_instance_valid(entity):
			var epos: Vector3 = (entity as Node3D).global_position
			for _si in range(6):
				var soff := Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
				var minion: Node3D = _gm.spawn("goblin", epos + soff)
				if minion and minion is GameEntity:
					(minion as GameEntity).set_meta_value("elite_minion", true)
	elif is_elite_minion:
		EngineAPI.add_resource("wood", 2)
		spawn_resource_text(entity, "+2 %s" % wood_name, Color(0.4, 0.75, 0.25))
	else:
		EngineAPI.add_resource("gold", 4)
		spawn_resource_text(entity, "+4 %s" % gold_name, Color(1, 0.85, 0.2))

func on_resource_gained_by_spell(data: Dictionary) -> void:
	## spell 效果产生的资源获取 -> 在英雄/目标头上显示飘字
	var res_name: String = data.get("resource", "")
	var amount: float = data.get("amount", 0)
	if amount <= 0 or res_name == "":
		return
	var caster = data.get("caster")
	if caster == null or not is_instance_valid(caster):
		return
	var I18n: Node = _gm.I18n
	var display_name: String = res_name
	if I18n:
		match res_name:
			"gold": display_name = I18n.t("GOLD")
			"wood": display_name = I18n.t("WOOD")
			_: display_name = res_name
	var color := Color(1, 0.85, 0.2) if res_name == "gold" else Color(0.4, 0.75, 0.25)
	spawn_resource_text(caster, "+%d %s" % [int(amount), display_name], color)

func on_loot_picked_up(data: Dictionary) -> void:
	var item: Dictionary = data.get("item", {})
	var item_sys: Node = EngineAPI.get_system("item")
	if item_sys == null:
		return
	var item_name: String = item_sys.call("get_item_display_name", item)
	var rarity: String = item.get("def", {}).get("rarity", "common")
	var color: Color = item_sys.call("get_rarity_color", rarity)
	_gm._combat_log_module._add_log("[LOOT] %s" % item_name, color)

func on_inventory_full(_data: Dictionary) -> void:
	var I18n: Node = _gm.I18n
	_gm._combat_log_module._add_log(I18n.t("INVENTORY_FULL"), Color(1, 0.3, 0.3))

# === 伤害/治疗统计 ===

func on_stat_damaged(data: Dictionary) -> void:
	var entity = data.get("entity")
	var source = data.get("source")
	var amount: float = data.get("amount", 0.0)
	if is_instance_valid(source) and source == _gm.hero and entity != _gm.hero:
		_gm._total_damage_dealt += amount
		if amount > _gm._max_hit:
			_gm._max_hit = amount
	if is_instance_valid(entity) and (entity == _gm.hero or entity == _gm.player_fountain):
		_gm._total_damage_taken += amount
	# 精英吸血词条：精英造成伤害时回血
	if _gm._elite_module:
		_gm._elite_module.on_elite_deals_damage(data)

func on_stat_healed(data: Dictionary) -> void:
	var entity = data.get("entity")
	if is_instance_valid(entity) and entity == _gm.hero:
		_gm._total_healing += data.get("amount", 0.0)

func on_resource_changed(data: Dictionary) -> void:
	var res: String = data.get("resource", "")
	if res == "xp":
		_gm._hero_module.check_level_up()

# === 飘字 ===

func spawn_resource_text(entity, text: String, color: Color) -> void:
	## 在实体位置生成资源获取飘字（金币/木头）
	if entity == null or not is_instance_valid(entity) or not (entity is Node3D):
		return
	var pos: Vector3 = (entity as Node3D).global_position
	var label := Label3D.new()
	label.text = text
	label.font_size = 28
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 20
	label.outline_size = 6
	label.outline_modulate = Color(0, 0, 0, 0.7)
	label.position = pos + Vector3(randf_range(-0.3, 0.3), 1.5, randf_range(-0.2, 0.2))
	var scene_root: Node = _gm.get_tree().current_scene
	if scene_root:
		scene_root.add_child(label)
		var tween := label.create_tween()
		tween.tween_property(label, "position:y", label.position.y + 1.5, 0.8).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
		tween.tween_callback(label.queue_free)

# === 战绩保存 ===

func save_battle_rewards(is_victory: bool) -> void:
	var _I18n: Node = _gm.I18n
	var reward_mult: float = _gm._difficulty.get("reward_mult", 1.0)
	var save_ns := "rogue_survivor_progress"

	if is_victory:
		var dust: int = int(10 * reward_mult)
		var old_dust: int = int(SaveSystem.load_data(save_ns, "star_dust", 0))
		SaveSystem.save_data(save_ns, "star_dust", old_dust + dust)

	var gold_earned: int = int(EngineAPI.get_resource("gold"))
	var old_gold: int = int(SaveSystem.load_data(save_ns, "gold", 0))
	SaveSystem.save_data(save_ns, "gold", old_gold + gold_earned)

	var total_games: int = int(SaveSystem.load_data(save_ns, "total_games", 0))
	var total_wins: int = int(SaveSystem.load_data(save_ns, "total_wins", 0))
	SaveSystem.save_data(save_ns, "total_games", total_games + 1)
	if is_victory:
		SaveSystem.save_data(save_ns, "total_wins", total_wins + 1)
	var best_wave: int = int(SaveSystem.load_data(save_ns, "best_wave", 0))
	if _gm._current_wave > best_wave:
		SaveSystem.save_data(save_ns, "best_wave", _gm._current_wave)

	var rating: Array = calculate_rating(is_victory)
	var hero_class_key: String = str(EngineAPI.get_variable("hero_class", "warrior"))
	var record := {
		"victory": is_victory,
		"difficulty": str(_gm._difficulty.get("name", "N1")),
		"class": _gm._promoted_class if _gm._promoted else hero_class_key,
		"kills": _gm._kills,
		"bosses": _gm._bosses_killed,
		"score": int(rating[2]),
		"grade": str(rating[0]),
		"level": _gm._hero_level,
		"time": int(_gm._game_timer),
		"wave": _gm._current_wave,
	}
	_record_battle(record)

static func _record_battle(data: Dictionary) -> void:
	var ns := "rogue_survivor_progress"
	var history: Variant = SaveSystem.load_data(ns, "battle_history", [])
	var list: Array = []
	if history is Array:
		list = history
	list.push_front(data)
	while list.size() > 20:
		list.pop_back()
	list.sort_custom(func(a: Variant, b: Variant) -> bool:
		return (a as Dictionary).get("score", 0) > (b as Dictionary).get("score", 0)
	)
	SaveSystem.save_data(ns, "battle_history", list)

func calculate_rating(is_victory: bool) -> Array:
	var score: int = 0
	if is_victory:
		score += 50
	score += mini(_gm._kills, 100)
	score += _gm._bosses_killed * 30
	score += mini(_gm._hero_level * 5, 50)
	var diff_level: int = _gm._difficulty.get("level", 1)
	score += diff_level * 10
	if is_victory and _gm._game_timer < 480:
		score += int((480 - _gm._game_timer) / 10)

	var grade: String
	var color: Color
	if score >= 250:
		grade = "S"
		color = Color(1, 0.85, 0.1)
	elif score >= 180:
		grade = "A"
		color = Color(0.3, 0.9, 0.3)
	elif score >= 120:
		grade = "B"
		color = Color(0.4, 0.7, 1)
	elif score >= 60:
		grade = "C"
		color = Color(0.8, 0.8, 0.8)
	else:
		grade = "D"
		color = Color(0.6, 0.4, 0.4)
	return [grade, color, score]

# === 游戏结束面板 ===

func show_game_over(is_victory: bool, reason: String) -> void:
	_gm.get_tree().paused = true
	var ui_layer: CanvasLayer = _gm.get_tree().current_scene.get_node_or_null("UI")
	if ui_layer == null:
		return
	var I18n: Node = _gm.I18n

	var panel := Control.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(panel)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(overlay)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	var rating: Array = calculate_rating(is_victory)
	var grade: String = rating[0]
	var grade_color: Color = rating[1]
	var score: int = rating[2]

	var title_hbox := HBoxContainer.new()
	title_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(title_hbox)

	var title := Label.new()
	title.text = I18n.t("VICTORY") if is_victory else I18n.t("DEFEAT")
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2) if is_victory else Color(1, 0.3, 0.2))
	title_hbox.add_child(title)

	var grade_label := Label.new()
	grade_label.text = grade
	grade_label.add_theme_font_size_override("font_size", 52)
	grade_label.add_theme_color_override("font_color", grade_color)
	title_hbox.add_child(grade_label)

	var reason_label := Label.new()
	reason_label.text = reason
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.add_theme_font_size_override("font_size", 14)
	reason_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(reason_label)

	vbox.add_child(HSeparator.new())

	_build_stats_grid(vbox, is_victory, score, grade_color, I18n)
	_build_detail_grid(vbox, I18n)
	_build_cards_summary(vbox, I18n)

	if is_victory:
		var reward_mult: float = _gm._difficulty.get("reward_mult", 1.0)
		vbox.add_child(HSeparator.new())
		var star_dust: int = int(10 * reward_mult)
		var reward_label := Label.new()
		reward_label.text = "+" + str(star_dust) + " Star Dust"
		reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_label.add_theme_font_size_override("font_size", 18)
		reward_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		vbox.add_child(reward_label)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_hbox)

	var menu_btn := Button.new()
	menu_btn.text = I18n.t("BACK")
	menu_btn.custom_minimum_size = Vector2(140, 40)
	menu_btn.pressed.connect(func() -> void:
		_gm.get_tree().paused = false
		SceneManager.goto_scene("lobby")
	)
	btn_hbox.add_child(menu_btn)

	var retry_btn := Button.new()
	retry_btn.text = I18n.t("RETRY")
	retry_btn.custom_minimum_size = Vector2(140, 40)
	retry_btn.pressed.connect(func() -> void:
		_gm.get_tree().paused = false
		SceneManager.goto_scene("battle", {
			"pack_id": SceneManager.pending_data.get("pack_id", "rogue_survivor"),
			"map_id": SceneManager.pending_data.get("map_id", "")
		})
	)
	btn_hbox.add_child(retry_btn)

func _build_stats_grid(vbox: VBoxContainer, _is_victory: bool, score: int, grade_color: Color, I18n: Node) -> void:
	@warning_ignore("integer_division")
	var mins: int = int(_gm._game_timer) / 60
	@warning_ignore("integer_division")
	var secs: int = int(_gm._game_timer) % 60
	var diff_name: String = str(_gm._difficulty.get("name", "N1"))
	var hero_class_key: String = str(EngineAPI.get_variable("hero_class", "warrior")).to_upper()
	var class_display: String = I18n.t("CLASS_" + _gm._promoted_class.to_upper()) if _gm._promoted else I18n.t(hero_class_key)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)

	var stat_rows: Array = [
		[I18n.t("STAT_CLASS"), class_display, Color(0.9, 0.8, 0.6)],
		[I18n.t("DIFFICULTY"), diff_name, Color(0.8, 0.8, 0.9)],
		[I18n.t("STAT_LEVEL"), "Lv.%d" % _gm._hero_level, Color(0.9, 0.85, 0.3)],
		[I18n.t("STAT_TIME"), "%d:%02d" % [mins, secs], Color(0.8, 0.8, 0.9)],
		[I18n.t("KILLS"), str(_gm._kills), Color(1, 0.4, 0.3)],
	]
	if _gm._bosses_killed > 0:
		stat_rows.append([I18n.t("STAT_BOSS_KILLS"), str(_gm._bosses_killed), Color(1, 0.5, 0.1)])
	stat_rows.append_array([
		[I18n.t("GOLD"), str(int(EngineAPI.get_resource("gold"))), Color(1, 0.9, 0.3)],
		[I18n.t("STAT_SCORE"), str(score), grade_color],
	])

	for row in stat_rows:
		var key_lbl := Label.new()
		key_lbl.text = str(row[0])
		key_lbl.add_theme_font_size_override("font_size", 13)
		key_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key_lbl.custom_minimum_size = Vector2(120, 0)
		grid.add_child(key_lbl)

		var val_lbl := Label.new()
		val_lbl.text = str(row[1])
		val_lbl.add_theme_font_size_override("font_size", 13)
		val_lbl.add_theme_color_override("font_color", row[2])
		val_lbl.custom_minimum_size = Vector2(120, 0)
		grid.add_child(val_lbl)

func _build_detail_grid(vbox: VBoxContainer, I18n: Node) -> void:
	vbox.add_child(HSeparator.new())

	var detail_grid := GridContainer.new()
	detail_grid.columns = 2
	detail_grid.add_theme_constant_override("h_separation", 30)
	detail_grid.add_theme_constant_override("v_separation", 4)
	detail_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(detail_grid)

	var detail_rows: Array = [
		[I18n.t("STAT_DMG_DEALT"), _format_number(_gm._total_damage_dealt), Color(1, 0.5, 0.3)],
		[I18n.t("STAT_DMG_TAKEN"), _format_number(_gm._total_damage_taken), Color(0.9, 0.4, 0.4)],
		[I18n.t("STAT_HEALING"), _format_number(_gm._total_healing), Color(0.3, 0.9, 0.3)],
		[I18n.t("STAT_MAX_HIT"), str(int(_gm._max_hit)), Color(1, 0.8, 0.2)],
		[I18n.t("STAT_DPS"), _format_number(_gm._total_damage_dealt / maxf(_gm._game_timer, 1.0)), Color(0.8, 0.6, 1)],
		[I18n.t("STAT_WAVES"), "%d" % _gm._current_wave, Color(0.7, 0.7, 0.9)],
	]

	for row in detail_rows:
		var key_lbl := Label.new()
		key_lbl.text = str(row[0])
		key_lbl.add_theme_font_size_override("font_size", 12)
		key_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key_lbl.custom_minimum_size = Vector2(120, 0)
		detail_grid.add_child(key_lbl)

		var val_lbl := Label.new()
		val_lbl.text = str(row[1])
		val_lbl.add_theme_font_size_override("font_size", 12)
		val_lbl.add_theme_color_override("font_color", row[2])
		val_lbl.custom_minimum_size = Vector2(120, 0)
		detail_grid.add_child(val_lbl)

func _build_cards_summary(vbox: VBoxContainer, I18n: Node) -> void:
	if _gm._card_manager == null:
		return
	var held: Array[String] = _gm._card_manager.get_held_cards()
	if held.size() == 0:
		return
	vbox.add_child(HSeparator.new())
	var cards_title := Label.new()
	cards_title.text = I18n.t("CARDS_SUMMARY", [str(held.size())])
	cards_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cards_title.add_theme_font_size_override("font_size", 12)
	cards_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(cards_title)

	var cards_hbox := HBoxContainer.new()
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(cards_hbox)
	for cid in held:
		var cdata: Dictionary = _gm._card_manager.get_card_data(cid)
		var clbl := Label.new()
		clbl.text = I18n.t(cdata.get("name_key", cid))
		clbl.add_theme_font_size_override("font_size", 10)
		var rarity: String = cdata.get("rarity", "common")
		match rarity:
			"legendary": clbl.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
			"rare": clbl.add_theme_color_override("font_color", Color(0.7, 0.3, 1))
			"uncommon": clbl.add_theme_color_override("font_color", Color(0.3, 0.7, 1))
			_: clbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		cards_hbox.add_child(clbl)

func _format_number(value: float) -> String:
	if value >= 1000000:
		return "%.1fM" % (value / 1000000.0)
	elif value >= 1000:
		return "%.1fK" % (value / 1000.0)
	return str(int(value))

# === 实体销毁处理 ===

func on_entity_destroyed(data: Dictionary) -> void:
	var entity = data.get("entity")
	if entity == null or not is_instance_valid(entity):
		return
	var I18n: Node = _gm.I18n
	var spawner = _gm._spawner

	# 英雄死亡
	if entity == _gm.hero:
		if bool(EngineAPI.get_variable("hero_death_rewind", false)):
			EngineAPI.set_variable("hero_death_rewind", false)
			var hero_health: Node = EngineAPI.get_component(_gm.hero, "health")
			if hero_health:
				hero_health.current_hp = hero_health.max_hp
				EngineAPI.show_message("TIME REWIND! Death prevented!")
				return
		_gm._hero_dead = true
		_gm._respawn_timer = 10.0
		var gold: float = float(EngineAPI.get_resource("gold"))
		var gold_penalty: int = int(gold * 0.2)
		if gold_penalty > 0:
			EngineAPI.add_resource("gold", -gold_penalty)
		_gm._combat_log_module._add_log(I18n.t("HERO_DEATH", ["10", str(gold_penalty)]), Color(1, 0.2, 0.2))
	elif entity == _gm.player_fountain:
		_gm._defeat(I18n.t("FOUNTAIN_DESTROYED"))
	elif spawner.final_boss != null and entity == spawner.final_boss:
		spawner.final_boss = null
		_gm._victory(I18n.t("FINAL_BOSS_DEFEATED"))

	# BOSS 击杀
	if entity is GameEntity and (entity as GameEntity).has_tag("boss"):
		_gm._bosses_killed += 1
		spawner.boss_skill_timers.erase(entity.get_instance_id())
		_gm._combat_log_module._add_log("[BOSS KILLED] %s" % _gm._get_entity_name(entity), Color(1, 0.85, 0.2))
		var vfx: Node = EngineAPI.get_system("vfx")
		if vfx and is_instance_valid(entity):
			vfx.call("spawn_vfx", "boss_death", (entity as Node3D).global_position)
			vfx.call("play_sfx", "boss_death", -3.0)
		if _gm._wave_system:
			_gm._wave_system.on_boss_killed()

	# 精英怪死亡处理
	if _gm._elite_module and _gm._elite_module.is_entity_elite(entity):
		_gm._elite_module.on_elite_destroyed(entity)

		if _gm._relic_module:
			_gm._relic_module.check_relic_trigger()
		var kill_heal: float = float(EngineAPI.get_variable("hero_kill_heal_pct", 0.0))
		if kill_heal > 0 and _gm.hero and is_instance_valid(_gm.hero):
			var hh: Node = EngineAPI.get_component(_gm.hero, "health")
			if hh and hh.has_method("heal"):
				hh.heal(hh.max_hp * kill_heal, _gm.hero, "kill_heal")
		var necro_chance: float = float(EngineAPI.get_variable("hero_necro_raise_chance", 0.0))
		if necro_chance > 0 and randf() < necro_chance and is_instance_valid(entity):
			var summons: Array = EngineAPI.find_entities_by_tag("summon")
			if summons.size() < _gm.MAX_SUMMONS:
				var raise_pos: Vector3 = (entity as Node3D).global_position
				_gm.spawn("shadow", raise_pos + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)), {
					"faction": "player",
					"tags": ["friendly", "mobile", "ground", "summon"],
					"lifespan": _gm.SUMMON_LIFESPAN,
					"components": {
						"ai_move_to": {"target_tag": "enemy", "attack_range": 0.6},
						"combat": {"damage": 15, "attack_speed": 1.5, "range": 0.6,
							"attack_type": "single", "target_filter_tag": "enemy",
							"targeting": "closest"},
					},
				})
				_gm._combat_log_module._add_log("[NECRO] Raised a minion!", Color(0.6, 0.2, 0.8))

		var perm_dmg: float = float(EngineAPI.get_variable("hero_permanent_damage_per_kill", 0.0))
		if perm_dmg > 0:
			var stacks: float = float(EngineAPI.get_variable("_hero_perm_damage_stacks", 0.0))
			EngineAPI.set_variable("_hero_perm_damage_stacks", stacks + perm_dmg)

		var kill_crit: float = float(EngineAPI.get_variable("hero_kill_crit_bonus", 0.0))
		if kill_crit > 0 and _gm._kills % 100 == 0:
			var cur_crit: float = float(EngineAPI.get_variable("hero_phys_crit", 0.005))
			EngineAPI.set_variable("hero_phys_crit", minf(cur_crit + kill_crit, 1.0))

		var summon_chance: float = float(EngineAPI.get_variable("hero_summon_on_kill_chance", 0.0))
		if summon_chance > 0 and randf() < summon_chance and is_instance_valid(entity):
			var cur_summons: Array = EngineAPI.find_entities_by_tag("summon")
			if cur_summons.size() < _gm.MAX_SUMMONS:
				var summon_pos: Vector3 = (entity as Node3D).global_position
				var summon_dmg: float = 10.0 + float(EngineAPI.get_variable("hero_summon_damage_bonus", 0.0))
				_gm.spawn("shadow", summon_pos + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)), {
					"faction": "player",
					"tags": ["friendly", "mobile", "ground", "summon"],
					"lifespan": _gm.SUMMON_LIFESPAN,
					"components": {
						"ai_move_to": {"target_tag": "enemy", "attack_range": 0.6},
						"combat": {"damage": summon_dmg, "attack_speed": 1.5, "range": 0.6,
							"attack_type": "single", "target_filter_tag": "enemy",
							"targeting": "closest"},
					},
				})
