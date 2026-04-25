## SpellScript — Spell/Aura 生命周期钩子系统
## 对标 TrinityCore SpellScript + AuraScript
## GamePack 通过注册 hook 在 spell 执行的各阶段注入自定义逻辑
##
## 用法：
##   var ss = SpellScript.new()
##   ss.register_spell_hook(spell_id, "on_cast", my_callable)
##   ss.register_aura_hook(spell_id, "on_apply", my_callable)
##   SpellSystem 在执行时自动调用已注册的 hooks
class_name SpellScript
extends Node

## === Spell Hook 类型（对标 TC SpellScriptHookType）===
## 施法生命周期
const HOOK_CHECK_CAST := "check_cast"       # bool(caster, spell) — 能否施法
const HOOK_BEFORE_CAST := "before_cast"     # void(caster, spell) — 施法前（可修改参数）
const HOOK_ON_CAST := "on_cast"             # void(caster, spell) — 施法时
const HOOK_AFTER_CAST := "after_cast"       # void(caster, spell) — 施法完成后
## 命中生命周期
const HOOK_BEFORE_HIT := "before_hit"       # void(caster, target, spell) — 命中前
const HOOK_ON_HIT := "on_hit"               # void(caster, target, spell) — 命中时
const HOOK_AFTER_HIT := "after_hit"         # void(caster, target, spell) — 命中后
## 效果处理
const HOOK_ON_EFFECT := "on_effect"         # void(caster, target, effect, spell) — 效果执行时
const HOOK_AFTER_EFFECT := "after_effect"   # void(caster, target, effect, spell) — 效果执行后
## 数值计算
const HOOK_CALC_DAMAGE := "calc_damage"     # float(caster, target, base_damage, spell) — 修改伤害
const HOOK_CALC_HEALING := "calc_healing"   # float(caster, target, base_heal, spell) — 修改治疗
const HOOK_CALC_CRIT := "calc_crit"         # float(caster, target, base_chance, spell) — 修改暴击率

## === Aura Hook 类型（对标 TC AuraScript hooks）===
const HOOK_AURA_APPLY := "aura_apply"       # void(aura) — aura 挂上时
const HOOK_AURA_REMOVE := "aura_remove"     # void(aura) — aura 移除时
const HOOK_AURA_TICK := "aura_tick"         # void(aura) — 周期 tick 时
const HOOK_AURA_PROC := "aura_proc"         # void(aura, event_data) — proc 触发时
const HOOK_AURA_CHECK_PROC := "aura_check_proc"  # bool(aura, event_data) — 是否应该触发 proc
const HOOK_AURA_ABSORB := "aura_absorb"     # float(aura, damage) — 吸收伤害时

## === 存储 ===
## spell_id -> { hook_type -> Array[Callable] }
var _spell_hooks: Dictionary = {}
## spell_id -> { hook_type -> Array[Callable] }（aura hooks 也按 spell_id 组织）
var _aura_hooks: Dictionary = {}

func _ready() -> void:
	EngineAPI.register_system("spell_script", self)

## === 注册 API ===

func register_spell_hook(spell_id: String, hook_type: String, handler: Callable) -> void:
	## 注册 spell 生命周期 hook
	if not _spell_hooks.has(spell_id):
		_spell_hooks[spell_id] = {}
	if not _spell_hooks[spell_id].has(hook_type):
		_spell_hooks[spell_id][hook_type] = []
	_spell_hooks[spell_id][hook_type].append(handler)

func register_aura_hook(spell_id: String, hook_type: String, handler: Callable) -> void:
	## 注册 aura 生命周期 hook
	if not _aura_hooks.has(spell_id):
		_aura_hooks[spell_id] = {}
	if not _aura_hooks[spell_id].has(hook_type):
		_aura_hooks[spell_id][hook_type] = []
	_aura_hooks[spell_id][hook_type].append(handler)

## === 触发 API（由 SpellSystem / AuraManager 调用）===

func fire_spell_hook(spell_id: String, hook_type: String, args: Array = []) -> Variant:
	## 触发 spell hook，返回最后一个 handler 的返回值（用于 check/calc 类）
	if not _spell_hooks.has(spell_id):
		return null
	var hooks: Dictionary = _spell_hooks[spell_id]
	if not hooks.has(hook_type):
		return null
	var result: Variant = null
	for handler: Callable in hooks[hook_type]:
		if handler.is_valid():
			result = handler.callv(args)
	return result

func fire_aura_hook(spell_id: String, hook_type: String, args: Array = []) -> Variant:
	## 触发 aura hook
	if not _aura_hooks.has(spell_id):
		return null
	var hooks: Dictionary = _aura_hooks[spell_id]
	if not hooks.has(hook_type):
		return null
	var result: Variant = null
	for handler: Callable in hooks[hook_type]:
		if handler.is_valid():
			result = handler.callv(args)
	return result

func has_spell_hook(spell_id: String, hook_type: String) -> bool:
	return _spell_hooks.has(spell_id) and _spell_hooks[spell_id].has(hook_type)

func has_aura_hook(spell_id: String, hook_type: String) -> bool:
	return _aura_hooks.has(spell_id) and _aura_hooks[spell_id].has(hook_type)

func _reset() -> void:
	_spell_hooks.clear()
	_aura_hooks.clear()
