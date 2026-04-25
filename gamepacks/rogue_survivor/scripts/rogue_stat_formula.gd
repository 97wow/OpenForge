## RogueStatFormula -- 属性公式计算（三维属性 + 装备 + 伤害/暴击/移速）
extends RefCounted

var _gm  # 主控制器引用 (rogue_game_mode)

## 属性公式常量（参考不思议作战）
## 每点力量: +10 HP, +1.5 每秒回血
## 每点敏捷: +0.1% 物理伤害, +0.3 固定伤害
## 每点智力: +0.1% 法术伤害, +0.3 固定伤害
const STR_HP_PER_POINT := 10.0
const STR_REGEN_PER_POINT := 1.5
const AGI_PHYS_DMG_PER_POINT := 0.001  # 0.1% per point
const AGI_FLAT_DMG_PER_POINT := 0.3
const INT_SPELL_DMG_PER_POINT := 0.001  # 0.1% per point
const INT_FLAT_DMG_PER_POINT := 0.3

func init(game_mode) -> void:
	_gm = game_mode

func get_primary_stat_key() -> String:
	var cls: String = str(EngineAPI.get_variable("hero_class", "warrior"))
	match cls:
		"warrior", "berserker", "paladin": return "str"
		"ranger", "shadow_dancer", "windrunner": return "agi"
		"mage", "archmage", "necromancer": return "int"
		_: return "str"

func apply() -> void:
	## 属性公式（不思议作战式三维属性）
	if _gm.hero == null or not is_instance_valid(_gm.hero) or not (_gm.hero is GameEntity):
		return
	var entity := _gm.hero as GameEntity
	var m: Dictionary = entity.meta
	var lvl: int = _gm._hero_level - 1

	# 三维属性计算（基础 + 等级成长）
	var str_val: float = m.get("base_str", 5) + lvl * m.get("level_str", 1)
	var agi_val: float = m.get("base_agi", 5) + lvl * m.get("level_agi", 1)
	var int_val: float = m.get("base_int", 5) + lvl * m.get("level_int", 1)

	# 属性加成百分比（来自卡片/装备/存档）
	var str_pct: float = float(EngineAPI.get_variable("hero_str_pct", 0.0))
	var agi_pct: float = float(EngineAPI.get_variable("hero_agi_pct", 0.0))
	var int_pct: float = float(EngineAPI.get_variable("hero_int_pct", 0.0))
	str_val *= (1.0 + str_pct)
	agi_val *= (1.0 + agi_pct)
	int_val *= (1.0 + int_pct)

	# 装备属性
	var equip_atk: float = float(EngineAPI.get_variable("equip_atk", 0.0))
	var _equip_aspd: float = float(EngineAPI.get_variable("equip_aspd", 0.0))
	var _equip_hp: float = float(EngineAPI.get_variable("equip_hp", 0.0))
	var equip_regen: float = float(EngineAPI.get_variable("equip_regen", 0.0))
	var _equip_armor: float = float(EngineAPI.get_variable("equip_armor", 0.0))
	var equip_all: float = float(EngineAPI.get_variable("equip_all_stat", 0.0))
	# 全属性加成（炮塔提供）
	str_val += equip_all
	agi_val += equip_all
	int_val += equip_all

	# 存储计算后的属性供 HUD 显示
	EngineAPI.set_variable("_hero_str", str_val)
	EngineAPI.set_variable("_hero_agi", agi_val)
	EngineAPI.set_variable("_hero_int", int_val)

	# === HP/Armor 由 StatSystem + AuraManager 驱动，GamePack 不手动覆盖 ===
	# 此处只需 health_comp 用于回血公式（max_hp * regen_pct）
	var health_comp: Node = EngineAPI.get_component(_gm.hero, "health")
	# 回血
	var base_regen: float = str_val * STR_REGEN_PER_POINT + equip_regen
	var regen_flat_bonus: float = float(EngineAPI.get_variable("hero_regen_flat_bonus", 0.0))
	var regen_pct: float = float(EngineAPI.get_variable("hero_regen_pct", 0.02))
	var total_regen: float = base_regen + regen_flat_bonus
	if health_comp:
		total_regen += health_comp.max_hp * regen_pct
	EngineAPI.set_variable("hero_hp_regen", total_regen)

	# === 敏捷 -> 物理伤害% + 固定伤害 ===
	var phys_dmg_pct: float = agi_val * AGI_PHYS_DMG_PER_POINT
	var agi_flat: float = agi_val * AGI_FLAT_DMG_PER_POINT
	EngineAPI.set_variable("_hero_phys_dmg_pct", phys_dmg_pct)

	# === 智力 -> 法术伤害% + 固定伤害 ===
	var spell_dmg_pct: float = int_val * INT_SPELL_DMG_PER_POINT
	var int_flat: float = int_val * INT_FLAT_DMG_PER_POINT
	EngineAPI.set_variable("_hero_spell_dmg_pct", spell_dmg_pct)

	# === 最终伤害计算 ===
	var atk_pct: float = float(EngineAPI.get_variable("hero_atk_pct", 0.0))
	var atk_flat_bonus: float = float(EngineAPI.get_variable("hero_atk_flat_bonus", 0.0))
	var final_dmg_pct: float = float(EngineAPI.get_variable("hero_final_dmg_pct", 0.0))
	var base_atk: float = (_gm._base_damage + equip_atk + atk_flat_bonus + agi_flat + int_flat) * (1.0 + atk_pct)
	var _final_atk: float = base_atk * (1.0 + phys_dmg_pct + spell_dmg_pct) * (1.0 + final_dmg_pct)
	# projectile_damage / shoot_cooldown 已迁移到 StatSystem，
	# player_input_component 的 getter 直接从 StatSystem 读取，不再需要手动赋值。

	# 暴击 -- 统一写入 hero_crit_chance（damage_pipeline 读取此变量）
	var phys_crit: float = float(EngineAPI.get_variable("hero_phys_crit", 0.005))
	var spell_crit: float = float(EngineAPI.get_variable("hero_spell_crit", 0.005))
	EngineAPI.set_variable("hero_crit_chance", minf(phys_crit, 1.0))
	EngineAPI.set_variable("_hero_phys_crit", phys_crit)
	EngineAPI.set_variable("_hero_spell_crit", spell_crit)

	# 移速 -- TODO: migrate to StatSystem (movement not yet on StatSystem)
	var move_comp: Node = EngineAPI.get_component(_gm.hero, "movement")
	if move_comp:
		var move_bonus: float = float(EngineAPI.get_variable("hero_move_speed_bonus", 0.0))
		move_comp.base_speed = _gm._base_speed + move_bonus
