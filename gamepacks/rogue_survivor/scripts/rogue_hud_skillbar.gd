## RogueHudSkillbar — 右下技能栏(卡片+技能) + 物品栏(装备) + 功能按钮
extends RefCounted

const CooldownOverlay = preload("res://src/ui/cooldown_overlay.gd")

var _gm
var _card_slots: Array[PanelContainer] = []  # 技能卡槽
var _equip_cells: Array[PanelContainer] = [] # 物品栏格子（含装备）
var _bond_button: Button = null
var _blink_cd_overlay: Control = null  # 闪现冷却遮罩
var _axe_cd_overlay: Control = null    # 铁斧冷却遮罩
var _card_cd_overlays: Array = []      # 卡片槽冷却遮罩

func create(ui_layer: CanvasLayer, I18n: Node) -> void:
	# === 功能按钮（技能栏上方横排）===
	var func_bar := HBoxContainer.new()
	func_bar.anchor_left = 1.0; func_bar.anchor_right = 1.0
	func_bar.anchor_top = 1.0; func_bar.anchor_bottom = 1.0
	func_bar.offset_left = -200; func_bar.offset_right = -2
	func_bar.offset_top = -175; func_bar.offset_bottom = -160
	func_bar.add_theme_constant_override("separation", 4)
	ui_layer.add_child(func_bar)
	_bond_button = _func_btn(func_bar, I18n.t("BOND_TAB_BONDS") if I18n else "Bonds", Color(0.5, 0.3, 0.7, 0.6))
	_func_btn(func_bar, I18n.t("TOWER_CLIMB") if I18n else "Tower", Color(0.5, 0.4, 0.15, 0.6))

	# === 技能栏 2×4 = 8格 (T/F + 6卡片槽) ===
	var skill_panel := _anchored_panel(ui_layer, -200, -2, -160, -2,
		Color(0.05, 0.04, 0.06, 0.85), Color(0.5, 0.35, 0.1, 0.5))
	var skill_vbox := VBoxContainer.new()
	skill_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_vbox.add_theme_constant_override("separation", 2)
	skill_panel.add_child(skill_vbox)
	var skill_grid := GridContainer.new()
	skill_grid.columns = 4
	skill_grid.add_theme_constant_override("h_separation", 2)
	skill_grid.add_theme_constant_override("v_separation", 2)
	skill_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skill_vbox.add_child(skill_grid)

	# 3排×4列=12格: 第1排[铁斧][空][T][F] 第2排[c0-c3] 第3排[c4-c7]
	var skill_names := ["", "", "T", "F", "", "", "", "", "", "", "", ""]
	_card_slots.clear()
	for ci in range(12):
		var cell := _create_cell(skill_names[ci], 46)
		if ci == 0: # 铁斧（英雄天赋技能）
			var axe_lbl: Label = cell.get_node("SlotLabel")
			var I18n_r: Node = _gm.I18n
			axe_lbl.text = I18n_r.t("SKILL_IRON_AXE") if I18n_r else "Axe"
			axe_lbl.add_theme_font_size_override("font_size", 11)
			axe_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
			cell.add_theme_stylebox_override("panel", _cell_style(Color(0.6, 0.45, 0.15, 0.8), 1))
			cell.mouse_entered.connect(_on_axe_hover)
			cell.mouse_exited.connect(_on_tooltip_hide)
			_axe_cd_overlay = CooldownOverlay.new()
			cell.add_child(_axe_cd_overlay)
		elif ci == 2: # T 闪现
			_style_skill_cell(cell, Color(0.5, 0.7, 1), Color(0.3, 0.5, 0.8, 0.6))
			cell.mouse_entered.connect(_on_blink_hover)
			cell.mouse_exited.connect(_on_tooltip_hide)
			# 冷却旋转遮罩
			_blink_cd_overlay = CooldownOverlay.new()
			cell.add_child(_blink_cd_overlay)
		elif ci == 3: # F 抽卡
			_style_skill_cell(cell, Color(0.7, 0.5, 1), Color(0.5, 0.3, 0.7, 0.6))
			cell.gui_input.connect(_on_draw_click)
			cell.mouse_entered.connect(_on_draw_hover)
			cell.mouse_exited.connect(_on_tooltip_hide)
		if ci >= 4: # 第2-3排为卡片槽
			if _gm._tooltip_module:
				_gm._tooltip_module.setup_card_slot_tooltip(cell, ci - 4)
			var cd_ov := CooldownOverlay.new()
			cell.add_child(cd_ov)
			_card_cd_overlays.append(cd_ov)
			_card_slots.append(cell)
		skill_grid.add_child(cell)

	# === 武器/护甲按钮（物品栏上方）===
	var equip_bar := HBoxContainer.new()
	equip_bar.anchor_left = 1.0; equip_bar.anchor_right = 1.0
	equip_bar.anchor_top = 1.0; equip_bar.anchor_bottom = 1.0
	equip_bar.offset_left = -410; equip_bar.offset_right = -330
	equip_bar.offset_top = -145; equip_bar.offset_bottom = -108
	equip_bar.add_theme_constant_override("separation", 4)
	ui_layer.add_child(equip_bar)
	_equip_cells.clear()
	var equip_types := [["WPN", "weapon"], ["SLD", "shield"]]
	for et in equip_types:
		var eb := _create_cell(et[0], 36)
		eb.custom_minimum_size = Vector2(36, 36)  # 正方形
		# 不透明背景
		var ebs := _cell_style(Color(0.3, 0.25, 0.4, 0.8), 1)
		ebs.bg_color = Color(0.08, 0.07, 0.12, 1.0)
		eb.add_theme_stylebox_override("panel", ebs)
		var ebl: Label = eb.get_node("SlotLabel")
		ebl.add_theme_font_size_override("font_size", 9)
		eb.gui_input.connect(_on_equip_click.bind(et[1]))
		eb.mouse_entered.connect(_on_equip_hover.bind(et[1]))
		eb.mouse_exited.connect(_on_tooltip_hide)
		equip_bar.add_child(eb)
		_equip_cells.append(eb)

	# === 物品栏 4×2 = 8格 ===
	var inv_panel := _anchored_panel(ui_layer, -410, -205, -105, -2,
		Color(0.06, 0.05, 0.09, 1.0), Color(0.25, 0.2, 0.35, 0.6))
	var inv_grid := GridContainer.new()
	inv_grid.columns = 4
	inv_grid.add_theme_constant_override("h_separation", 2)
	inv_grid.add_theme_constant_override("v_separation", 2)
	inv_panel.add_child(inv_grid)
	# 第1格=炮塔，其余空
	for ii in range(8):
		var ic := _create_cell("TUR" if ii == 0 else "", 46)
		if ii == 0:
			ic.gui_input.connect(_on_equip_click.bind("turret"))
			ic.mouse_entered.connect(_on_equip_hover.bind("turret"))
			ic.mouse_exited.connect(_on_tooltip_hide)
		inv_grid.add_child(ic)
		_equip_cells.append(ic)

func update(I18n: Node) -> void:
	# 闪现冷却遮罩同步
	if _blink_cd_overlay and _gm.hero and is_instance_valid(_gm.hero):
		var inp: Node = EngineAPI.get_component(_gm.hero, "player_input")
		if inp and inp.get("_blink_cd_timer") != null:
			var cd_timer: float = float(inp._blink_cd_timer)
			if cd_timer > 0 and not _blink_cd_overlay.is_cooling():
				_blink_cd_overlay.start_cooldown(inp.blink_cooldown)
	# 铁斧 CD：只在 spell 实际施放时显示（通过 buff bar 的 spell_cast 事件驱动）
	# 不再每帧轮询 aura，避免无敌人时也显示 CD

	# 卡片槽冷却遮罩：从 ProcManager 读取 proc CD
	_update_card_cooldowns()

	# 装备等级（前2=WPN/SLD按钮，第3=TUR格子）
	if _gm._equipment and _equip_cells.size() >= 3:
		var eq = _gm._equipment
		var wpn_lbl: Label = _equip_cells[0].get_node_or_null("SlotLabel")
		if wpn_lbl: wpn_lbl.text = "WPN Lv.%d" % eq.weapon_level if eq.weapon_level >= 0 else "WPN"
		var sld_lbl: Label = _equip_cells[1].get_node_or_null("SlotLabel")
		if sld_lbl: sld_lbl.text = "SLD Lv.%d" % eq.shield_level if eq.shield_level >= 0 else "SLD"
		var tur_lbl: Label = _equip_cells[2].get_node_or_null("SlotLabel")
		if tur_lbl: tur_lbl.text = "TUR Lv.%d" % eq.turret_level
	# 卡片槽
	if _gm._card_sys:
		var cs = _gm._card_sys
		for si in range(mini(8, _card_slots.size())):
			var sl: Label = _card_slots[si].get_node_or_null("SlotLabel")
			if sl == null: continue
			var sp: PanelContainer = _card_slots[si]
			if si < cs.held_cards.size():
				var cdata: Dictionary = cs.held_cards[si].get("data", {})
				var cname: String = cs._get_card_display_name(cdata)
				sl.text = cname.substr(0, 3) if cname.length() >= 3 else cname
				sl.add_theme_font_size_override("font_size", 11)
				var tc: Color = cs._get_tier_color(cdata.get("tier", 1))
				sl.add_theme_color_override("font_color", tc)
				sp.add_theme_stylebox_override("panel", _cell_style(Color(tc.r, tc.g, tc.b, 0.7), 2))
			else:
				sl.text = ""; sl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
				sp.add_theme_stylebox_override("panel", _cell_style(Color(0.2, 0.2, 0.3, 0.5), 1))
		if _bond_button:
			_bond_button.text = "%s (%d)" % [I18n.t("BOND_TAB_BONDS") if I18n else "Bonds", cs.get_activated_bonds().size()]

func _update_card_cooldowns() -> void:
	if not _gm._card_sys or not _gm.hero or not is_instance_valid(_gm.hero):
		return
	var cs = _gm._card_sys
	# 收集 proc CD（事件触发型：on_hit/on_crit 等）
	var proc_mgr: Node = EngineAPI.get_system("proc")
	var procs: Array = proc_mgr.get_procs_for_owner(_gm.hero) if proc_mgr else []
	# 收集 aura 周期信息（periodic 型）
	var aura_mgr: Node = EngineAPI.get_system("aura")
	var auras: Array = aura_mgr.get_auras_on(_gm.hero) if aura_mgr else []

	for si in range(mini(8, _card_slots.size())):
		if si >= _card_cd_overlays.size():
			break
		var cd_ov: Control = _card_cd_overlays[si]
		if si >= cs.held_cards.size():
			continue
		var card_id: String = cs.held_cards[si].get("id", "")
		if card_id == "":
			continue
		var spell_key: String = "card_%s" % card_id
		var found := false
		# 1. 检查 ProcManager CD（on_hit 等概率触发型）
		for proc: Dictionary in procs:
			var aura: Dictionary = proc.get("aura", {})
			if aura.get("spell_id", "") != spell_key:
				continue
			var cd_remaining: float = proc.get("cd_remaining", 0.0)
			var cd_total: float = proc.get("cooldown", 0.0)
			if cd_remaining > 0 and cd_total > 0 and not cd_ov.is_cooling():
				cd_ov.start_cooldown(cd_total)
			found = true
			break
		if found:
			continue
		# periodic 型 CD 由 buff bar proc 图标系统管理（spell_cast 事件驱动）
		# 不在此处轮询，避免无敌人时也显示 CD
			break

# === Callbacks ===

func _on_axe_hover() -> void:
	if _gm._tooltip_module:
		var I18n: Node = _gm.I18n
		var name_t: String = I18n.t("SKILL_IRON_AXE") if I18n else "Iron Axe"
		var desc: String = I18n.t("SKILL_IRON_AXE_DESC") if I18n else "Knockback on hit, 15% AOE knockback for 50% ATK, CD 2s"
		_gm._tooltip_module.show_tooltip(name_t, desc, Color(0.9, 0.7, 0.3))

func _on_blink_hover() -> void:
	if _gm._tooltip_module:
		var I18n: Node = _gm.I18n
		var inp: Node = EngineAPI.get_component(_gm.hero, "player_input") if _gm.hero else null
		var cd: float = inp.blink_cooldown if inp else 0.5
		var mp: float = inp.blink_mp_cost if inp else 10.0
		var dist: float = inp.blink_distance if inp else 5.0
		var name_t: String = I18n.t("BLINK") if I18n else "Blink"
		var desc: String = "[T] %s\nCD: %.1fs  MP: %.0f\n%s: %.0f" % [name_t, cd, mp, I18n.t("STAT_SPEED") if I18n else "Range", dist]
		_gm._tooltip_module.show_tooltip(name_t, desc)

func _on_draw_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _gm._card_sys: _gm._card_sys.draw_card()

func _on_draw_hover() -> void:
	if _gm._tooltip_module and _gm._card_sys:
		var I18n: Node = _gm.I18n
		var title: String = I18n.t("DRAW_CARD") if I18n else "Draw Card"
		var desc: String = "[F] %s\n%s: %d\n%s: %d" % [
			title,
			I18n.t("WOOD") if I18n else "Wood", _gm._card_sys.draw_cost,
			I18n.t("POOL_REMAINING") if I18n else "Pool", _gm._card_sys._card_pool.size()]
		_gm._tooltip_module.show_tooltip(title, desc)

func _on_equip_click(event: InputEvent, etype: String) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT): return
	if _gm._equipment == null: return
	match etype:
		"turret": _gm._equipment.upgrade_turret()
		"weapon":
			if _gm._equipment.weapon_level >= 0:
				var r: Dictionary = _gm._equipment.upgrade_weapon()
				if r.get("forge_options"): _gm._equipment.show_forge_selection(r["forge_options"])
		"shield":
			if _gm._equipment.shield_level >= 0:
				var r: Dictionary = _gm._equipment.upgrade_shield()
				if r.get("forge_options"): _gm._equipment.show_forge_selection(r["forge_options"])

func _on_equip_hover(etype: String) -> void:
	if _gm._equipment == null or _gm._tooltip_module == null: return
	var eq = _gm._equipment
	var I18n: Node = _gm.I18n
	var t := func(key: String) -> String: return I18n.t(key) if I18n else key
	var title := ""; var desc := ""; var color := Color(0.7, 0.7, 0.8)
	match etype:
		"turret":
			title = eq.get_turret_display_name()
			desc = "%s: %.0f\n%s: %.0f" % [t.call("EQUIP_ATK"), eq.get_turret_atk(), t.call("EQUIP_ALL_STAT"), eq.get_turret_all_stat()]
			if eq.turret_level < 5:
				desc += "\n%s: %d" % [t.call("GOLD"), 100 + eq.turret_level * 50]
			color = Color(1, 0.85, 0.3)
		"weapon":
			if eq.weapon_level < 0:
				title = t.call("WEAPON"); desc = t.call("LOCKED")
			else:
				title = eq.get_weapon_display_name()
				desc = "%s: %.0f\n%s: %.2f\n%s: %d\n%s: %d%%" % [
					t.call("EQUIP_ATK"), eq.get_weapon_atk(),
					t.call("EQUIP_ASPD"), eq.get_weapon_aspd(),
					t.call("GOLD"), eq.get_weapon_upgrade_cost(),
					t.call("SUCCESS_RATE"), int(eq.get_upgrade_success_rate() * 100)]
				color = Color(0.5, 0.8, 1)
		"shield":
			if eq.shield_level < 0:
				title = t.call("SHIELD"); desc = t.call("LOCKED")
			else:
				title = eq.get_shield_display_name()
				desc = "%s: %.0f\n%s: %.0f\n%s: %.0f\n%s: %d" % [
					t.call("EQUIP_HP"), eq.get_shield_hp(),
					t.call("EQUIP_REGEN"), eq.get_shield_regen(),
					t.call("EQUIP_ARMOR"), eq.get_shield_armor(),
					t.call("GOLD"), eq.get_shield_upgrade_cost()]
				color = Color(0.4, 1, 0.5)
	_gm._tooltip_module.show_tooltip(title, desc, color)

func _on_tooltip_hide() -> void:
	if _gm._tooltip_module: _gm._tooltip_module.hide_tooltip()

# === Helpers ===

func _create_cell(text: String, size: int = 46) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(size, size)
	cell.clip_contents = true  # 防止子节点（如冷却遮罩）超出边框
	cell.add_theme_stylebox_override("panel", _cell_style(Color(0.25, 0.25, 0.35, 1.0), 1))
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var lbl := Label.new(); lbl.text = text; lbl.name = "SlotLabel"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	cell.add_child(lbl); return cell

func _style_skill_cell(cell: PanelContainer, font_color: Color, border_color: Color) -> void:
	var sl: Label = cell.get_node("SlotLabel")
	sl.add_theme_font_size_override("font_size", 14)
	sl.add_theme_color_override("font_color", font_color)
	cell.add_theme_stylebox_override("panel", _cell_style(border_color, 1))

func _cell_style(border_color: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.04, 0.08, 1.0)
	s.corner_radius_top_left = 3; s.corner_radius_top_right = 3
	s.corner_radius_bottom_left = 3; s.corner_radius_bottom_right = 3
	s.border_color = border_color
	s.border_width_top = border_w; s.border_width_bottom = border_w
	s.border_width_left = border_w; s.border_width_right = border_w
	s.content_margin_left = 2; s.content_margin_right = 2
	s.content_margin_top = 2; s.content_margin_bottom = 2
	return s

func _func_btn(parent: Node, text: String, border_color: Color) -> Button:
	var btn := Button.new(); btn.text = text; btn.custom_minimum_size = Vector2(60, 14)
	btn.add_theme_font_size_override("font_size", 9)
	var s := StyleBoxFlat.new(); s.bg_color = Color(0.1, 0.08, 0.18, 0.9)
	s.corner_radius_top_left = 3; s.corner_radius_top_right = 3
	s.corner_radius_bottom_left = 3; s.corner_radius_bottom_right = 3
	s.border_color = border_color
	s.border_width_top = 1; s.border_width_bottom = 1; s.border_width_left = 1; s.border_width_right = 1
	btn.add_theme_stylebox_override("normal", s); parent.add_child(btn); return btn

func _anchored_panel(ui_layer: CanvasLayer, ol: int, or_: int, ot: int, ob: int, bg: Color, bc: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.anchor_left = 1.0; p.anchor_right = 1.0; p.anchor_top = 1.0; p.anchor_bottom = 1.0
	p.offset_left = ol; p.offset_right = or_; p.offset_top = ot; p.offset_bottom = ob
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.border_color = bc
	s.border_width_top = 1; s.border_width_bottom = 1; s.border_width_left = 1; s.border_width_right = 1
	s.corner_radius_top_left = 4; s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4; s.corner_radius_bottom_right = 4
	s.content_margin_left = 4; s.content_margin_right = 4
	s.content_margin_top = 4; s.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", s); ui_layer.add_child(p); return p
