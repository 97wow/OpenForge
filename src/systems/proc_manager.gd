## ProcManager - 事件驱动触发系统（框架层）
## 借鉴 TrinityCore Proc 系统
## "当 X 发生时，以 Y% 概率触发 Z" — 全部数据驱动
## 战斗事件 → 检查所有注册的 proc → 满足条件则触发
class_name ProcManager
extends Node

## Proc 事件标志（可组合）
const PROC_FLAG := {
	"DEAL_DAMAGE":      "deal_damage",       # 造成伤害时
	"TAKE_DAMAGE":      "take_damage",       # 受到伤害时
	"DEAL_MELEE":       "deal_melee",        # 近战命中
	"DEAL_RANGED":      "deal_ranged",       # 远程命中
	"DEAL_SPELL":       "deal_spell",        # 法术命中
	"ON_KILL":          "on_kill",           # 击杀时
	"ON_CRIT":          "on_crit",           # 暴击时
	"ON_HIT":           "on_hit",            # 任何命中
	"TAKE_MELEE":       "take_melee",        # 被近战命中
	"TAKE_RANGED":      "take_ranged",       # 被远程命中
	"ON_HEAL":          "on_heal",           # 治疗时
	"ON_SPELL_CAST":    "on_spell_cast",     # 施法时
	"PERIODIC_TICK":    "periodic_tick",      # DoT/HoT tick 时
}

# 注册的 proc
# proc_id -> ProcEntry
var _procs: Dictionary = {}
var _next_id: int = 1

func _ready() -> void:
	EngineAPI.register_system("proc", self)
	# 监听战斗事件
	EventBus.connect_event("entity_damaged", _on_entity_damaged)
	EventBus.connect_event("entity_destroyed", _on_entity_destroyed)
	EventBus.connect_event("entity_healed", _on_entity_healed)
	EventBus.connect_event("projectile_hit", _on_projectile_hit)
	EventBus.connect_event("spell_cast", _on_spell_cast)

# === Proc 注册 ===

func register_proc(aura: Dictionary, proc_data: Dictionary) -> String:
	var proc_id := "proc_%d" % _next_id
	_next_id += 1

	var flags: Array = proc_data.get("flags", [])
	var chance: float = proc_data.get("chance", 100.0)
	var cooldown: float = proc_data.get("cooldown", 0.0)
	var trigger_spell: String = aura.get("effect", {}).get("trigger_spell", "")
	var charges: int = proc_data.get("charges", 0)  # 0 = 无限
	var action: String = proc_data.get("action", "trigger_spell")

	_procs[proc_id] = {
		"proc_id": proc_id,
		"aura": aura,
		"flags": flags,
		"chance": chance,
		"cooldown": cooldown,
		"trigger_spell": trigger_spell,
		"charges": charges,
		"charges_remaining": charges,
		"action": action,
		"reflect_pct": proc_data.get("reflect_pct", 0.0),
		"cd_remaining": 0.0,
		"owner_id": aura.get("target", null).get_instance_id() if aura.get("target") else 0,
		"caster": aura.get("caster"),
	}
	return proc_id

func unregister_proc(proc_id: String) -> void:
	_procs.erase(proc_id)

# === 冷却递减 ===

func _process(delta: float) -> void:
	for proc_id in _procs:
		var proc: Dictionary = _procs[proc_id]
		if proc["cd_remaining"] > 0:
			proc["cd_remaining"] -= delta

# === 事件处理 → Proc 检查 ===

func _on_entity_damaged(data: Dictionary) -> void:
	var target = data.get("entity")
	var source = data.get("source")
	var amount: float = data.get("amount", 0.0)

	# 受伤者的 proc（TAKE_DAMAGE）
	if target != null and is_instance_valid(target):
		_check_procs(target.get_instance_id(), ["take_damage", "take_melee", "take_ranged"], {
			"target": target, "source": source, "amount": amount
		})

	# 攻击者的 proc（DEAL_DAMAGE, ON_HIT）
	if source != null and is_instance_valid(source):
		_check_procs(source.get_instance_id(), ["deal_damage", "on_hit"], {
			"target": target, "source": source, "amount": amount
		})

func _on_entity_destroyed(data: Dictionary) -> void:
	var entity = data.get("entity")
	if entity == null:
		return
	# 清理该实体的所有 proc
	var to_remove: Array[String] = []
	for proc_id in _procs:
		if _procs[proc_id]["owner_id"] == entity.get_instance_id():
			to_remove.append(proc_id)
	for proc_id in to_remove:
		_procs.erase(proc_id)

	# 检查击杀者的 ON_KILL proc（通过 source 在 damage 事件中）
	# 注意：entity_destroyed 没有 source，需要通过最近的 damage 事件关联
	# 这里简化处理：遍历所有 proc 检查 ON_KILL flag
	for proc_id in _procs:
		var proc: Dictionary = _procs[proc_id]
		if "on_kill" in proc["flags"]:
			_try_fire_proc(proc, {"target": entity, "source": proc.get("caster")})

func _on_entity_healed(data: Dictionary) -> void:
	var source = data.get("source")
	if source != null and is_instance_valid(source):
		_check_procs(source.get_instance_id(), ["on_heal"], data)

func _on_projectile_hit(data: Dictionary) -> void:
	var source = data.get("source")
	if source != null and is_instance_valid(source):
		_check_procs(source.get_instance_id(), ["deal_ranged", "on_hit"], data)

func _on_spell_cast(data: Dictionary) -> void:
	var caster = data.get("caster")
	if caster != null and is_instance_valid(caster):
		_check_procs(caster.get_instance_id(), ["on_spell_cast"], data)

# === Proc 检查与触发 ===

func _check_procs(owner_id: int, event_flags: Array, event_data: Dictionary) -> void:
	for proc_id in _procs:
		var proc: Dictionary = _procs[proc_id]
		if proc["owner_id"] != owner_id:
			continue
		# 检查 flag 匹配
		var matched := false
		for flag in event_flags:
			if flag in proc["flags"]:
				matched = true
				break
		if not matched:
			continue
		_try_fire_proc(proc, event_data)

func _try_fire_proc(proc: Dictionary, event_data: Dictionary) -> void:
	# 冷却检查
	if proc["cd_remaining"] > 0:
		return
	# 概率检查
	if proc["chance"] < 100 and randf() * 100 >= proc["chance"]:
		return
	# 触发次数检查
	if proc["charges"] > 0 and proc["charges_remaining"] <= 0:
		return

	# 触发！
	_execute_proc(proc, event_data)

	# 设置冷却
	if proc["cooldown"] > 0:
		proc["cd_remaining"] = proc["cooldown"]
	# 消耗次数
	if proc["charges"] > 0:
		proc["charges_remaining"] -= 1

func _execute_proc(proc: Dictionary, event_data: Dictionary) -> void:
	var action: String = proc["action"]
	var caster = proc.get("caster")
	var target = event_data.get("target")

	match action:
		"trigger_spell":
			var spell_id: String = proc["trigger_spell"]
			if spell_id != "" and caster != null and is_instance_valid(caster):
				var spell_system: Node = EngineAPI.get_system("spell")
				if spell_system:
					spell_system.call("cast", spell_id, caster, target if is_instance_valid(target) else null)
		"reflect":
			# 伤害反弹
			var amount: float = event_data.get("amount", 0.0)
			var reflect_amount: float = amount * float(proc["reflect_pct"])
			var source = event_data.get("source")
			if source != null and is_instance_valid(source) and reflect_amount > 0:
				var health: Node = EngineAPI.get_component(source, "health")
				if health and health.has_method("take_damage"):
					health.take_damage(reflect_amount, caster, 5)  # Holy damage

	EventBus.emit_event("proc_triggered", {
		"proc_id": proc["proc_id"],
		"action": action,
		"trigger_spell": proc.get("trigger_spell", ""),
	})
