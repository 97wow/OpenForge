## RogueHudBuffbar — Proc 冷却图标栏（WoW 风格）
## 仅在 proc 触发时显示临时图标 + CD 倒计时，CD 结束后自动消失
extends RefCounted

const CooldownOverlay = preload("res://src/ui/cooldown_overlay.gd")

const ICON_SIZE := 26
const ICON_GAP := 2
const MAX_ICONS := 20

var _gm
var _container: HBoxContainer = null
var _active_procs: Dictionary = {}  # card_id -> {panel, label, cd_label, cd_overlay, remaining, total}

func create(ui_layer: CanvasLayer) -> void:
	_container = HBoxContainer.new()
	_container.anchor_left = 0.5; _container.anchor_right = 0.5
	_container.anchor_top = 1.0; _container.anchor_bottom = 1.0
	_container.offset_left = -230; _container.offset_right = 230
	_container.offset_top = -185; _container.offset_bottom = -172
	_container.add_theme_constant_override("separation", ICON_GAP)
	_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_container)
	# 监听 proc 事件
	EventBus.connect_event("proc_triggered", _on_proc_triggered)
	EventBus.connect_event("spell_cast", _on_spell_cast)

func update(delta: float) -> void:
	var expired: Array[String] = []
	for card_id: String in _active_procs:
		var entry: Dictionary = _active_procs[card_id]
		entry["remaining"] -= delta
		if entry["remaining"] <= 0:
			expired.append(card_id)
		else:
			_update_cd_text(entry)
	for card_id: String in expired:
		_remove_icon(card_id)

func _on_proc_triggered(data: Dictionary) -> void:
	## 事件型 proc（on_hit, on_crit, on_kill 等）
	var trigger_spell: String = data.get("trigger_spell", "")
	if trigger_spell == "":
		return
	var card_id: String = trigger_spell.replace("card_", "").replace("_proc", "")
	var proc_id: String = data.get("proc_id", "")
	# 从 ProcManager 读取 cooldown
	var cooldown: float = _get_proc_cooldown(proc_id)
	if cooldown <= 0:
		return  # 无 CD 的 proc 不显示
	_add_proc_icon(card_id, cooldown)

func _on_spell_cast(data: Dictionary) -> void:
	## 周期型 aura 触发的 proc spell（spell_id 以 _proc 结尾）
	var spell_id: String = data.get("spell_id", "")
	if not spell_id.ends_with("_proc"):
		return
	var card_id: String = spell_id.replace("card_", "").replace("_proc", "")
	# 从 AuraManager 读取 period 作为 CD
	var cooldown: float = _get_periodic_cooldown(card_id)
	if cooldown <= 0:
		cooldown = 2.0  # fallback
	_add_proc_icon(card_id, cooldown)

func _add_proc_icon(card_id: String, cooldown: float) -> void:
	if _container == null or not is_instance_valid(_container):
		return
	# 已存在则刷新 CD
	if _active_procs.has(card_id):
		var entry: Dictionary = _active_procs[card_id]
		entry["remaining"] = cooldown
		entry["total"] = cooldown
		var cd_ov: Control = entry["cd_overlay"]
		if is_instance_valid(cd_ov) and cd_ov.has_method("start_cooldown"):
			cd_ov.start_cooldown(cooldown)
		return
	if _active_procs.size() >= MAX_ICONS:
		return
	var effect_color: Color = _get_effect_color(card_id)
	var panel := _create_icon_panel(effect_color)
	var display_name: String = _get_spell_display_name(card_id)
	var lbl := _make_label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, 9, effect_color)
	lbl.text = display_name.substr(0, 2) if display_name.length() >= 2 else display_name
	panel.add_child(lbl)
	var cd_lbl := _make_label(HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM, 7, Color(1, 1, 0.6))
	panel.add_child(cd_lbl)
	var overlay := CooldownOverlay.new()
	panel.add_child(overlay)
	overlay.start_cooldown(cooldown)
	_container.add_child(panel)
	panel.mouse_entered.connect(_on_icon_hover.bind(card_id))
	panel.mouse_exited.connect(_on_icon_unhover)
	_active_procs[card_id] = {"panel": panel, "label": lbl, "cd_label": cd_lbl,
		"cd_overlay": overlay, "remaining": cooldown, "total": cooldown}
	_update_cd_text(_active_procs[card_id])

func _create_icon_panel(border_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.1, 0.9)
	for prop in ["corner_radius_top_left","corner_radius_top_right","corner_radius_bottom_left","corner_radius_bottom_right"]:
		style.set(prop, 2)
	for prop in ["border_width_top","border_width_bottom","border_width_left","border_width_right"]:
		style.set(prop, 1)
	style.border_color = border_color
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_label(h_align: int, v_align: int, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.horizontal_alignment = h_align as HorizontalAlignment
	lbl.vertical_alignment = v_align as VerticalAlignment
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

func _remove_icon(card_id: String) -> void:
	if not _active_procs.has(card_id):
		return
	var entry: Dictionary = _active_procs[card_id]
	var panel: PanelContainer = entry["panel"]
	if is_instance_valid(panel):
		panel.queue_free()
	_active_procs.erase(card_id)

func _update_cd_text(entry: Dictionary) -> void:
	var r: float = entry["remaining"]
	entry["cd_label"].text = "%dm" % int(r / 60) if r >= 60 else ("%ds" % ceili(r) if r > 0 else "")

func _get_proc_cooldown(proc_id: String) -> float:
	var proc_mgr: Node = EngineAPI.get_system("proc")
	if proc_mgr == null: return 0.0
	if proc_mgr._procs.has(proc_id):
		return proc_mgr._procs[proc_id].get("cooldown", 0.0)
	return 0.0

func _get_periodic_cooldown(card_id: String) -> float:
	if not _gm.hero or not is_instance_valid(_gm.hero): return 0.0
	var aura_mgr: Node = EngineAPI.get_system("aura")
	if aura_mgr == null: return 0.0
	for aura: Dictionary in aura_mgr.get_auras_on(_gm.hero):
		var sid: String = aura.get("spell_id", "")
		if sid == "card_%s" % card_id or sid == "card_%s_proc" % card_id:
			var p: float = aura.get("period", 0.0)
			if p > 0: return p
	return 0.0

func _get_spell_display_name(card_id: String) -> String:
	if _gm._card_sys:
		var r: String = _gm._card_sys.get_spell_name(card_id)
		if r != card_id: return r
	return card_id

const _EFFECT_COLORS := {
	"aoe_damage": Color(0.9,0.3,0.3,0.9), "chain_bounce": Color(0.5,0.7,1,0.9),
	"scatter_shot": Color(1,0.5,0.2,0.9), "aspd_buff": Color(0.3,0.9,0.3,0.9),
	"double_damage": Color(1,0.8,0.3,0.9), "bonus_damage": Color(1,0.5,0.2,0.9),
	"multi_projectile": Color(0.9,0.7,0.2,0.9), "cheat_death": Color(1,0.3,0.6,0.9),
	"instant_kill": Color(0.8,0.2,0.2,0.9), "growth": Color(0.3,0.9,0.5,0.9),
}
const _DEFAULT_COLOR := Color(0.5, 0.6, 0.8, 0.9)

func _get_effect_color(card_id: String) -> Color:
	if _gm._card_sys == null:
		return _DEFAULT_COLOR
	for source: Dictionary in [_gm._card_sys._all_cards, _gm._card_sys._all_skills]:
		if source.has(card_id):
			var eff: String = source[card_id].get("proc", {}).get("effect", "")
			return _EFFECT_COLORS.get(eff, _DEFAULT_COLOR)
	return _DEFAULT_COLOR

func _on_icon_hover(card_id: String) -> void:
	if not _active_procs.has(card_id) or _gm._tooltip_module == null:
		return
	var entry: Dictionary = _active_procs[card_id]
	var title: String = _get_spell_display_name(card_id)
	var color: Color = _get_effect_color(card_id)
	var lines: Array[String] = []
	lines.append("CD: %.1fs / %.1fs" % [entry["remaining"], entry["total"]])
	if _gm._card_sys:
		var desc: String = _gm._card_sys.get_spell_desc(card_id)
		if desc != "":
			lines.append(desc)
	_gm._tooltip_module.show_tooltip(title, "\n".join(lines), color)

func _on_icon_unhover() -> void:
	if _gm._tooltip_module:
		_gm._tooltip_module.hide_tooltip()
