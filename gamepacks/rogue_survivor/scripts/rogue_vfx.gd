## RogueVFX — 技能视觉特效（GamePack 层）
## 监听 proc_triggered / spell_cast，根据效果类型播放对应 VFX
extends RefCounted

var _gm
var _vfx: Node = null  # VFXSystem 引用
var _spell_effect_map: Dictionary = {}  # card_id -> effect_type（缓存）

func init(game_mode) -> void:
	_gm = game_mode
	_vfx = EngineAPI.get_system("vfx")
	if _vfx == null:
		return
	# 注册自定义 VFX 类型
	_vfx.register_vfx("proc_aoe", _vfx_proc_aoe)
	_vfx.register_vfx("proc_chain", _vfx_proc_chain)
	_vfx.register_vfx("proc_scatter", _vfx_proc_scatter)
	_vfx.register_vfx("proc_aspd_buff", _vfx_proc_aspd_buff)
	_vfx.register_vfx("proc_double_damage", _vfx_proc_double_damage)
	_vfx.register_vfx("proc_bonus_damage", _vfx_proc_bonus_damage)
	_vfx.register_vfx("proc_spell_damage", _vfx_proc_spell_damage)
	_vfx.register_vfx("proc_multi_projectile", _vfx_proc_multi_projectile)
	_vfx.register_vfx("proc_cheat_death", _vfx_proc_cheat_death)
	_vfx.register_vfx("proc_summon", _vfx_proc_summon)
	_vfx.register_vfx("proc_resource", _vfx_proc_resource)
	_vfx.register_vfx("proc_cooldown_reduce", _vfx_proc_cooldown_reduce)
	_vfx.register_vfx("proc_gold", _vfx_proc_gold)
	_vfx.register_vfx("proc_instant_kill", _vfx_proc_instant_kill)
	_vfx.register_vfx("proc_growth", _vfx_proc_growth)
	# 缓存 effect 类型映射
	_build_effect_map()
	# 监听事件
	EventBus.connect_event("proc_triggered", _on_proc_triggered)
	EventBus.connect_event("spell_cast", _on_spell_cast)

func _build_effect_map() -> void:
	if _gm._card_sys == null:
		return
	# 卡片 + 技能/道具都收集
	for source: Dictionary in [_gm._card_sys._all_cards, _gm._card_sys._all_skills]:
		for cid: String in source:
			var data: Dictionary = source[cid]
			var proc: Dictionary = data.get("proc", {})
			var eff: String = proc.get("effect", "")
			if eff != "":
				_spell_effect_map[cid] = eff

func _on_proc_triggered(data: Dictionary) -> void:
	## ProcManager 触发（on_hit/on_crit/on_kill 等事件型 proc）
	var trigger_spell: String = data.get("trigger_spell", "")
	_play_effect_vfx(trigger_spell)

func _on_spell_cast(data: Dictionary) -> void:
	## 周期型 aura 触发的 proc spell 走 spell_cast 事件
	var spell_id: String = data.get("spell_id", "")
	if not spell_id.ends_with("_proc"):
		return  # 只处理 proc spell
	_play_effect_vfx(spell_id)

func _play_effect_vfx(spell_id: String) -> void:
	if spell_id == "" or _vfx == null:
		return
	if not _gm.hero or not is_instance_valid(_gm.hero):
		return
	var card_id: String = spell_id.replace("card_", "").replace("_proc", "")
	var effect_type: String = _spell_effect_map.get(card_id, "")
	if effect_type == "":
		return
	var pos: Vector3 = (_gm.hero as Node3D).global_position
	var vfx_name: String = _effect_to_vfx(effect_type)
	if vfx_name != "":
		_vfx.spawn_vfx(vfx_name, pos)

func _effect_to_vfx(effect_type: String) -> String:
	match effect_type:
		"aoe_damage": return "proc_aoe"
		"chain_bounce": return "proc_chain"
		"scatter_shot": return "proc_scatter"
		"aspd_buff": return "proc_aspd_buff"
		"double_damage": return "proc_double_damage"
		"bonus_damage", "bonus_spell_damage": return "proc_bonus_damage"
		"spell_damage", "aoe_spell_damage": return "proc_spell_damage"
		"multi_projectile": return "proc_multi_projectile"
		"cheat_death": return "proc_cheat_death"
		"summon_puppet": return "proc_summon"
		"grant_resource": return "proc_resource"
		"reduce_spell_cooldowns": return "proc_cooldown_reduce"
		"bonus_gold": return "proc_gold"
		"instant_kill_minion": return "proc_instant_kill"
		"add_growth", "add_percent": return "proc_growth"
		"line_spell_damage": return "proc_spell_damage"
		"multi_area_spell_damage": return "proc_spell_damage"
		"orbiting_damage": return "proc_aoe"
		"spell_damage_at_origin_and_dest": return "proc_spell_damage"
		_: return ""

# === VFX 实现 ===

func _vfx_proc_aoe(pos: Vector3, _data: Dictionary) -> void:
	## AOE 范围伤害 — 橙色扩散冲击环
	_vfx.call("spawn_vfx", "shockwave", pos, {"radius": 3.5})
	_spawn_ground_circle(pos, Color(1, 0.5, 0.1, 0.4), 3.5, 0.6)

func _vfx_proc_chain(pos: Vector3, _data: Dictionary) -> void:
	## 弹射 — 青蓝色闪电向随机方向
	for i in range(3):
		var angle: float = randf() * TAU
		var offset := Vector3(cos(angle) * 3.0, 0.5, sin(angle) * 3.0)
		_vfx.call("spawn_vfx", "lightning", pos + Vector3(0, 0.8, 0), {"target_pos": pos + offset})

func _vfx_proc_scatter(pos: Vector3, _data: Dictionary) -> void:
	## 散射 — 多个黄色粒子扇面扩散
	_vfx.call("_spawn_particles", pos, {
		"amount": 15, "color": Color(1, 0.9, 0.3, 0.9),
		"color_end": Color(1, 0.7, 0.1, 0), "speed": 7,
		"lifetime": 0.4, "size": 0.07, "gravity": Vector3.ZERO, "spread": 120,
	})

func _vfx_proc_aspd_buff(pos: Vector3, _data: Dictionary) -> void:
	## 攻速提升 — 绿色向上粒子 + 光环
	_vfx.call("_spawn_particles", pos, {
		"amount": 20, "color": Color(0.3, 1, 0.5, 0.9),
		"color_end": Color(0.1, 0.8, 0.3, 0), "speed": 3,
		"lifetime": 0.8, "size": 0.06, "gravity": Vector3(0, 4, 0), "spread": 30,
	})
	_spawn_ground_circle(pos, Color(0.3, 1, 0.5, 0.3), 1.5, 0.8)

func _vfx_proc_double_damage(pos: Vector3, _data: Dictionary) -> void:
	## 双倍伤害 — 红色爆裂
	_vfx.call("_spawn_particles", pos, {
		"amount": 12, "color": Color(1, 0.2, 0.1, 1),
		"color_end": Color(1, 0.5, 0, 0), "speed": 6,
		"lifetime": 0.35, "size": 0.1, "gravity": Vector3.ZERO, "spread": 180,
	})
	_vfx.call("_spawn_flash", pos, Color(1, 0.3, 0.1, 0.5), 1.0)

func _vfx_proc_bonus_damage(pos: Vector3, _data: Dictionary) -> void:
	## 额外伤害 — 金色冲击
	_vfx.call("_spawn_particles", pos, {
		"amount": 10, "color": Color(1, 0.85, 0.2, 0.9),
		"color_end": Color(1, 0.6, 0, 0), "speed": 5,
		"lifetime": 0.4, "size": 0.09, "gravity": Vector3.ZERO, "spread": 90,
	})

func _vfx_proc_spell_damage(pos: Vector3, _data: Dictionary) -> void:
	## 法术伤害 — 紫色/蓝色魔法爆发
	_vfx.call("_spawn_particles", pos, {
		"amount": 14, "color": Color(0.6, 0.3, 1, 0.9),
		"color_end": Color(0.3, 0.1, 0.8, 0), "speed": 5,
		"lifetime": 0.5, "size": 0.1, "gravity": Vector3(0, 2, 0), "spread": 120,
	})
	_vfx.call("_spawn_ring", pos, Color(0.5, 0.3, 1, 0.5), 2.5, 0.4)

func _vfx_proc_multi_projectile(pos: Vector3, _data: Dictionary) -> void:
	## 多投射物 — 橙色火焰弹扇面
	_vfx.call("_spawn_particles", pos, {
		"amount": 18, "color": Color(1, 0.6, 0.2, 0.95),
		"color_end": Color(1, 0.3, 0, 0), "speed": 8,
		"lifetime": 0.4, "size": 0.08, "gravity": Vector3.ZERO, "spread": 60,
	})

func _vfx_proc_cheat_death(pos: Vector3, _data: Dictionary) -> void:
	## 免死 — 金色大爆发 + 治疗光环
	_vfx.call("_spawn_particles", pos, {
		"amount": 30, "color": Color(1, 0.95, 0.5, 1),
		"color_end": Color(1, 0.8, 0.2, 0), "speed": 6,
		"lifetime": 1.0, "size": 0.15, "gravity": Vector3(0, 3, 0), "spread": 180,
	})
	_vfx.call("_spawn_ring", pos, Color(1, 0.9, 0.3, 0.7), 4.0, 1.0)
	_vfx.call("_spawn_flash", pos, Color(1, 1, 0.8, 0.6), 2.0)

func _vfx_proc_summon(pos: Vector3, _data: Dictionary) -> void:
	## 召唤 — 暗紫色漩涡
	_vfx.call("_spawn_particles", pos, {
		"amount": 16, "color": Color(0.5, 0.2, 0.8, 0.9),
		"color_end": Color(0.3, 0.1, 0.6, 0), "speed": 2,
		"lifetime": 0.8, "size": 0.1, "gravity": Vector3(0, -2, 0), "spread": 180,
	})
	_spawn_ground_circle(pos, Color(0.5, 0.2, 0.8, 0.4), 2.0, 0.8)

func _vfx_proc_resource(pos: Vector3, _data: Dictionary) -> void:
	## 资源获取 — 棕色木头粒子
	_vfx.call("_spawn_particles", pos, {
		"amount": 8, "color": Color(0.7, 0.5, 0.2, 0.8),
		"color_end": Color(0.5, 0.35, 0.15, 0), "speed": 3,
		"lifetime": 0.6, "size": 0.08, "gravity": Vector3(0, 2, 0), "spread": 60,
	})

func _vfx_proc_cooldown_reduce(pos: Vector3, _data: Dictionary) -> void:
	## CD 缩减 — 浅蓝色时钟感觉的旋转粒子
	_vfx.call("_spawn_particles", pos, {
		"amount": 12, "color": Color(0.4, 0.8, 1, 0.9),
		"color_end": Color(0.2, 0.6, 1, 0), "speed": 2,
		"lifetime": 0.6, "size": 0.07, "gravity": Vector3(0, 3, 0), "spread": 40,
	})

func _vfx_proc_gold(pos: Vector3, _data: Dictionary) -> void:
	## 金币获取 — 金色上升粒子
	_vfx.call("_spawn_particles", pos, {
		"amount": 6, "color": Color(1, 0.85, 0.2, 0.9),
		"color_end": Color(1, 0.7, 0, 0), "speed": 2,
		"lifetime": 0.5, "size": 0.06, "gravity": Vector3(0, 3, 0), "spread": 30,
	})

func _vfx_proc_instant_kill(pos: Vector3, _data: Dictionary) -> void:
	## 即杀 — 白金色闪光爆发
	_vfx.call("_spawn_flash", pos, Color(1, 0.95, 0.7, 0.7), 2.0)
	_vfx.call("_spawn_particles", pos, {
		"amount": 20, "color": Color(1, 0.95, 0.5, 1),
		"color_end": Color(1, 0.8, 0, 0), "speed": 8,
		"lifetime": 0.5, "size": 0.12, "gravity": Vector3.ZERO, "spread": 180,
	})

func _vfx_proc_growth(pos: Vector3, _data: Dictionary) -> void:
	## 成长 — 柔和绿色上升
	_vfx.call("_spawn_particles", pos, {
		"amount": 8, "color": Color(0.4, 0.9, 0.4, 0.7),
		"color_end": Color(0.2, 0.7, 0.2, 0), "speed": 2,
		"lifetime": 0.7, "size": 0.06, "gravity": Vector3(0, 3, 0), "spread": 25,
	})

# === 辅助 ===

func _spawn_ground_circle(pos: Vector3, color: Color, radius: float, duration: float) -> void:
	## 地面圆形指示器（半透明扩散环）
	if _vfx == null:
		return
	_vfx.call("_spawn_ring", pos, color, radius, duration)
