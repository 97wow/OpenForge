## DamagePipeline — 统一伤害流水线（对标 TrinityCore Unit::DealDamage）
## 所有伤害都通过此类处理，确保：护甲减免→吸收盾→扣血→事件→击杀 顺序一致
## 框架层静态工具类，GamePack 通过 "damage_calculating" 事件 hook 修改伤害
class_name DamagePipeline
extends RefCounted

# === 伤害标志位（bitmask）===
const IGNORE_ARMOR:  int = 1 << 0  # 无视护甲
const IGNORE_ABSORB: int = 1 << 1  # 无视吸收盾
const NO_PROC:       int = 1 << 2  # 不触发 proc
const IS_PROC:       int = 1 << 3  # 本身是 proc 触发的（防级联）
const IGNORE_RESIST:  int = 1 << 4  # 无视魔抗

## 统一伤害入口（所有伤害最终走这里）
## params: { attacker, target, base_amount, school, ability, is_proc, flags }
## returns: { effective_damage, absorbed, resisted, overkill, killed, target }
static func deal_damage(params: Dictionary) -> Dictionary:
	var result := {
		"effective_damage": 0.0,
		"absorbed": 0.0,
		"resisted": 0.0,
		"overkill": 0.0,
		"killed": false,
		"target": params.get("target"),
	}

	var target = params.get("target")
	var attacker = params.get("attacker")
	var base_amount: float = params.get("base_amount", 0.0)
	var school: int = params.get("school", 0)
	var ability: String = params.get("ability", "")
	var flags: int = params.get("flags", 0)
	if params.get("is_proc", false):
		flags |= IS_PROC

	# === Step 1: 校验目标 ===
	if target == null or not is_instance_valid(target):
		return result
	if target is GameEntity:
		var ge: GameEntity = target as GameEntity
		if not ge.is_alive:
			return result
		if ge.has_unit_flag(UnitFlags.IMMUNE_DAMAGE) and not (flags & IGNORE_ARMOR):
			return result

	var health: Node = EngineAPI.get_component(target, "health")
	if health == null or not health.has_method("apply_hp_change"):
		return result

	# === Step 2: Pre-damage 事件（GamePack hook 增伤/减伤）===
	var calc_data := {"base_amount": base_amount, "school": school, "attacker": attacker, "target": target, "ability": ability}
	EventBus.emit_event("damage_calculating", calc_data)
	base_amount = calc_data.get("base_amount", base_amount)

	# === Step 2.5: 伤害百分比修正（对标 TC MOD_DAMAGE_PERCENT_DONE）===
	var damage_pct: float = float(EngineAPI.get_variable("hero_damage_pct", 0.0))
	if damage_pct != 0 and attacker is GameEntity:
		base_amount *= (1.0 + damage_pct)
	# BOSS 增伤
	if target is GameEntity and (target as GameEntity).has_tag("boss"):
		var boss_pct: float = float(EngineAPI.get_variable("hero_boss_damage_pct", 0.0))
		if boss_pct > 0:
			base_amount *= (1.0 + boss_pct)
	# 暴击检查（对标 TC SpellInfo::CalcCritChance）
	# StatSystem crit_rate（卡牌/装备/天赋阈值）+ 变量 hero_crit_chance（基础属性/遗物/被动）
	var crit_chance: float = float(EngineAPI.get_variable("hero_crit_chance", 0.0))
	if attacker and is_instance_valid(attacker):
		crit_chance += EngineAPI.get_total_stat(attacker, "crit_rate")
	crit_chance = clampf(crit_chance, 0.0, 1.0)
	var is_crit: bool = crit_chance > 0 and randf() < crit_chance
	if is_crit:
		# 暴击伤害：StatSystem crit_dmg + 变量 hero_crit_damage_bonus
		var crit_dmg_bonus: float = float(EngineAPI.get_variable("hero_crit_damage_bonus", 0.0))
		if attacker and is_instance_valid(attacker):
			crit_dmg_bonus += EngineAPI.get_total_stat(attacker, "crit_dmg")
		var crit_mult: float = 1.5 + crit_dmg_bonus
		base_amount *= crit_mult
		result["is_crit"] = true
		# 触发 ON_CRIT proc 事件（对标 TC PROC_FLAG_DONE_SPELL_CRIT）
		EventBus.emit_event("damage_crit", {
			"attacker": attacker, "target": target,
			"amount": base_amount, "ability": ability,
		})
	# SpellScript calc_damage hook
	var script_sys: Node = EngineAPI.get_system("spell_script")
	if script_sys and ability != "" and script_sys.has_spell_hook(ability, "calc_damage"):
		var modified: Variant = script_sys.fire_spell_hook(ability, "calc_damage", [attacker, target, base_amount])
		if modified is float:
			base_amount = modified

	# === Step 2.6: Damage taken reduction (对标 TC MOD_DAMAGE_TAKEN) ===
	if target is GameEntity:
		var dmg_reduction: float = float(EngineAPI.get_variable("hero_damage_taken_reduction", 0.0))
		if dmg_reduction > 0:
			base_amount *= (1.0 - clampf(dmg_reduction, 0.0, 0.9))  # cap at 90% reduction

	# === Step 3: 护甲/魔抗减免 ===
	var amount: float = base_amount
	if not (flags & IGNORE_ARMOR):
		var armor: float = health.armor if health.get("armor") != null else 0.0
		var magic_resist: float = health.magic_resist if health.get("magic_resist") != null else 0.0
		var reduction := 0.0
		if school == 0:  # PHYSICAL
			reduction = armor
		else:
			reduction = armor * 0.33 + magic_resist
		result["resisted"] = minf(reduction, amount - 1.0)  # 至少 1 伤害
		amount = maxf(amount - reduction, 1.0)

	# === Step 4: 吸收盾消耗 ===
	if not (flags & IGNORE_ABSORB):
		var aura_mgr: Node = EngineAPI.get_system("aura")
		if aura_mgr and aura_mgr.has_method("consume_absorb"):
			var absorbed: float = aura_mgr.call("consume_absorb", target, amount, school)
			result["absorbed"] = absorbed
			amount = maxf(amount - absorbed, 0.0)

	# === Step 5: 扣血 ===
	var old_hp: float = health.current_hp
	var actual_lost: float = health.apply_hp_change(amount)
	var new_hp: float = health.current_hp
	result["effective_damage"] = actual_lost

	# === Step 6: 显示伤害数字 ===
	if health.show_damage_numbers and target is Node3D and is_instance_valid(target):
		health._spawn_damage_number(actual_lost, school, ability)

	# === Step 7: Post-damage 事件 ===
	EventBus.emit_event("entity_damaged", {
		"entity": target,
		"amount": actual_lost,
		"source": attacker,
		"damage_type": school,
		"ability": ability,
		"is_proc": (flags & IS_PROC) != 0,
		"old_hp": old_hp,
		"new_hp": new_hp,
		"absorbed": result["absorbed"],
		"resisted": result["resisted"],
	})

	# === Step 8: 击杀判定 ===
	if new_hp <= 0.0 and old_hp > 0.0:
		# CHEAT_DEATH check (对标 TC SPELL_AURA_SPIRIT_OF_REDEMPTION)
		if target is GameEntity:
			var cheat_spell: String = (target as GameEntity).get_meta_value("cheat_death_spell", "")
			if cheat_spell != "":
				# Survive with full HP, remove the cheat death aura
				health.current_hp = health.max_hp
				var aura_mgr: Node = EngineAPI.get_system("aura")
				if aura_mgr:
					aura_mgr.remove_aura(target, cheat_spell + "_CHEAT_DEATH")
				(target as GameEntity).set_meta_value("cheat_death_spell", "")
				EventBus.emit_event("cheat_death_triggered", {"entity": target, "spell": cheat_spell})
				# Don't kill - skip the rest of kill logic
				return result
		result["killed"] = true
		result["overkill"] = absf(new_hp)
		# 标记死亡（立即阻止后续伤害/攻击）
		if target is GameEntity:
			var ge: GameEntity = target as GameEntity
			ge.is_alive = false
			ge.set_unit_flag(UnitFlags.IMMUNE_DAMAGE)
		# 发射击杀事件（携带 killer 信息）
		EventBus.emit_event("entity_killed", {
			"entity": target,
			"killer": attacker,
			"ability": ability,
			"overkill": result["overkill"],
		})
		# 延迟销毁：播放死亡动画 + 粒子 + 淡出，然后再销毁
		_start_death_sequence(target)

	return result

static func _start_death_sequence(entity: Node3D) -> void:
	## 死亡序列：倒地动画 → 停留 → 淡出 → 销毁
	# 1. 播放死亡动画（倒地）
	if entity.has_method("get_component"):
		var vis: Node = entity.get_component("visual")
		if vis and vis.has_method("play_death"):
			vis.play_death()
		# 隐藏血条
		if vis and vis.get("_hp_bar_bg") != null and vis._hp_bar_bg is Node3D:
			(vis._hp_bar_bg as Node3D).visible = false
		if vis and vis.get("_hp_bar_fill") != null and vis._hp_bar_fill is Node3D:
			(vis._hp_bar_fill as Node3D).visible = false
	# 2. 停止移动
	if entity.has_method("get_component"):
		var mv: Node = entity.get_component("movement")
		if mv and mv.get("velocity") != null:
			mv.velocity = Vector3.ZERO
	# 3. 倒地后停留 2 秒，然后淡出销毁
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		EngineAPI.destroy_entity(entity)
		return
	tree.create_timer(0.8).timeout.connect(func() -> void:
		if not is_instance_valid(entity):
			return
		# 淡出：逐渐透明（遍历所有 MeshInstance3D）
		var tween := entity.create_tween()
		tween.tween_interval(0.3)  # 短暂停顿
		tween.tween_callback(func() -> void:
			if is_instance_valid(entity):
				EngineAPI.destroy_entity(entity)
		)
	)
