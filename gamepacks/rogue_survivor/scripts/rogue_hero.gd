## RogueHero -- 英雄生成、天赋加成、升级、转职
extends RefCounted

var _gm  # 主控制器引用 (rogue_game_mode)

func init(game_mode) -> void:
	_gm = game_mode

func spawn_hero() -> void:
	var hero_class: String = str(SceneManager.pending_data.get("hero_class", "warrior"))
	_gm.hero = _gm.spawn(hero_class, _gm.HERO_START_POS)
	if _gm.hero:
		_gm.set_var("hero_class", hero_class)
		# 初始化背包 + 拾取组件
		EngineAPI.init_inventory(_gm.hero, 20)
		EngineAPI.add_component(_gm.hero, "pickup", {
			"auto_pickup_radius": 2.0,
			"interact_radius": 3.5,
			"auto_pickup_enabled": true,
		})
		var inp: Node = EngineAPI.get_component(_gm.hero, "player_input")
		if inp:
			_gm._base_damage = inp.projectile_damage
			_gm._base_cooldown = inp.shoot_cooldown
		var hpc: Node = EngineAPI.get_component(_gm.hero, "health")
		if hpc:
			_gm._base_max_hp = hpc.max_hp
			_gm._base_armor = hpc.armor
		var mvc: Node = EngineAPI.get_component(_gm.hero, "movement")
		if mvc:
			_gm._base_speed = mvc.base_speed
		apply_talent_bonuses()
		# 自动施放 skill 类型的 spell（铁斧等被动技能）
		cast_hero_skills()
		# 相机跟随英雄
		var cam: Node = EngineAPI.get_system("camera")
		if cam and cam.has_method("follow"):
			cam.follow(_gm.hero, 8.0)

func cast_hero_skills() -> void:
	## 自动施放所有 type=skill 的 spell 到英雄身上（铁斧等被动技能）
	if _gm.hero == null or not is_instance_valid(_gm.hero):
		return
	var spell_sys: Node = EngineAPI.get_system("spell")
	if spell_sys == null or _gm._card_sys == null:
		return
	for sid: String in _gm._card_sys._all_skills:
		var data: Dictionary = _gm._card_sys._all_skills[sid]
		# 只自动施放被动技能（talent），主动技能（active）由玩家操作触发
		if data.get("subclass", "") == "active":
			continue
		var spell_key: String = "card_%s" % sid
		if spell_sys.has_spell(spell_key):
			spell_sys.cast(spell_key, _gm.hero)

func apply_talent_bonuses() -> void:
	if _gm.hero == null or not is_instance_valid(_gm.hero):
		return
	var bonuses: Dictionary = get_talent_bonuses()
	if bonuses.is_empty():
		return

	var move_comp: Node = EngineAPI.get_component(_gm.hero, "movement")

	for stat in bonuses:
		var value: float = float(bonuses[stat])
		match stat:
			"max_hp":
				EngineAPI.add_green_stat(_gm.hero, "hp", value)
			"damage":
				EngineAPI.add_green_stat(_gm.hero, "atk", value)
			"armor":
				EngineAPI.add_green_stat(_gm.hero, "armor", value)
			"attack_speed_pct":
				EngineAPI.add_green_stat(_gm.hero, "aspd", value)
			"crit_chance":
				# 加到 hero_phys_crit（_apply_stat_formula 每帧从此变量计算 hero_crit_chance）
				var current: float = float(EngineAPI.get_variable("hero_phys_crit", 0.005))
				EngineAPI.set_variable("hero_phys_crit", current + value)
			"move_speed":
				# TODO: migrate to StatSystem (movement not yet on StatSystem)
				if move_comp:
					move_comp.base_speed += value
			"life_steal":
				var current: float = float(EngineAPI.get_variable("hero_life_steal", 0.0))
				EngineAPI.set_variable("hero_life_steal", current + value)

	if not bonuses.is_empty():
		_gm._combat_log_module._add_log("[TALENT] Bonuses applied", Color(0.5, 0.8, 1))

func get_talent_bonuses() -> Dictionary:
	var bonuses: Dictionary = {}
	var path: String = _gm.pack.pack_path.path_join("meta_progress.json")
	if not FileAccess.file_exists(path):
		return bonuses
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return bonuses
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return bonuses
	var meta: Dictionary = json.data
	var talents: Dictionary = meta.get("talents", {})
	var saved: Variant = SaveSystem.load_data("rogue_survivor_progress", "talents", {})
	if not saved is Dictionary:
		return bonuses
	for tid in saved:
		var level: int = int((saved as Dictionary)[tid])
		if level <= 0:
			continue
		var tdata: Dictionary = talents.get(tid, {})
		var stat: String = tdata.get("stat", "")
		var per_level: float = tdata.get("effect_per_level", 0.0)
		if stat != "":
			bonuses[stat] = bonuses.get(stat, 0.0) + per_level * level
	return bonuses

func check_level_up() -> void:
	var current_xp: float = EngineAPI.get_resource("xp")
	if current_xp >= _gm._xp_to_next:
		EngineAPI.subtract_resource("xp", _gm._xp_to_next)
		_gm._hero_level += 1
		EngineAPI.set_resource("hero_level", _gm._hero_level)
		_gm._xp_to_next = _gm.XP_PER_LEVEL_BASE + (_gm._hero_level - 1) * _gm.XP_PER_LEVEL_GROWTH
		_gm.emit("hero_level_up", {"level": _gm._hero_level})
		if _gm.hero and is_instance_valid(_gm.hero):
			var vfx: Node = EngineAPI.get_system("vfx")
			if vfx:
				vfx.call("spawn_vfx", "level_up", _gm.hero.global_position)
				vfx.call("play_sfx", "level_up", -5.0)
		# 升级公告
		if _gm._hud_module:
			var I18n: Node = _gm.I18n
			var lu_text: String = I18n.t("LEVEL_UP", [str(_gm._hero_level)]) if I18n else "Level Up Lv.%d" % _gm._hero_level
			_gm._hud_module.add_announcement("[b]%s[/b]" % lu_text, Color(1, 0.85, 0.3))
