## RogueHUD — 主控：创建子模块 + 调度更新
## 子模块：topbar / portrait / skillbar / announce / bonds(在此文件)
class_name RogueHUD

const TopbarClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_hud_topbar.gd")
const PortraitClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_hud_portrait.gd")
const SkillbarClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_hud_skillbar.gd")
const AnnounceClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_hud_announce.gd")
const BuffbarClass = preload("res://gamepacks/rogue_survivor/scripts/rogue_hud_buffbar.gd")

var _gm
var _topbar = null     # RogueHudTopbar
var _portrait = null   # RogueHudPortrait
var _skillbar = null   # RogueHudSkillbar
var _announce = null   # RogueHudAnnounce
var _buffbar = null    # RogueHudBuffbar

# 隐藏的占位 label（兼容旧 update_hud 引用）
var _hp_label: Label = null
var _mp_label: Label = null
var _xp_label: Label = null
var _level_label: Label = null

# 羁绊面板
var _bond_panel: PanelContainer = null
var _bond_content: VBoxContainer = null
var _bond_hover_container: Control = null
var _bond_hover_panels: Array = []
var _bond_hover_card_w: int = 145
var _bond_hover_total_cards: int = 0
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _last_held_count: int = -1

# Boss HP bar
var _boss_hp_bar: Control = null
var _boss_hp_fill: ColorRect = null
var _boss_name_label: Label = null

# 兼容旧引用（不再使用但避免报错）
var _equip_level_label: Label = null
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _action_buttons: VBoxContainer = null
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _equip_slots_ui: Control = null

func init(game_mode) -> void:
	_gm = game_mode

func create_hud() -> void:
	var I18n: Node = _gm.I18n
	var ui_layer: CanvasLayer = _gm.get_tree().current_scene.get_node_or_null("UI")
	if ui_layer == null:
		return
	for child in ui_layer.get_children():
		child.queue_free()

	# 占位 label（update_hud 兼容）
	_hp_label = Label.new(); _hp_label.visible = false; ui_layer.add_child(_hp_label)
	_mp_label = Label.new(); _mp_label.visible = false; ui_layer.add_child(_mp_label)
	_xp_label = Label.new(); _xp_label.visible = false; ui_layer.add_child(_xp_label)
	_equip_level_label = Label.new(); _equip_level_label.visible = false; ui_layer.add_child(_equip_level_label)

	# === 子模块创建 ===
	_topbar = TopbarClass.new()
	_topbar._gm = _gm
	_topbar.create(ui_layer, I18n)

	_announce = AnnounceClass.new()
	_announce.create(ui_layer)
	# 订阅框架级 ui_toast 事件（TriggerSystem show_toast 动作派发）
	EventBus.connect_event("ui_toast", _on_ui_toast)

	# 小地图占位
	_create_minimap(ui_layer)

	_portrait = PortraitClass.new()
	_portrait._gm = _gm
	_portrait.create(ui_layer, I18n)
	_level_label = _portrait._level_label

	_buffbar = BuffbarClass.new()
	_buffbar._gm = _gm
	_buffbar.create(ui_layer)

	_skillbar = SkillbarClass.new()
	_skillbar._gm = _gm
	_skillbar.create(ui_layer, I18n)
	_skillbar._bond_button.pressed.connect(_toggle_bond_panel)

	# === 羁绊面板（中间右侧）===
	_create_bond_panel(ui_layer)

	# === Boss HP bar ===
	_create_boss_hp_bar(ui_layer)

	# === 战斗日志（隐藏，内部仍运作）===
	_gm._combat_log_module.create_log_panel(ui_layer)
	if _gm._combat_log_module.get("_log_outer") and is_instance_valid(_gm._combat_log_module._log_outer):
		_gm._combat_log_module._log_outer.visible = false

	# === Tooltip ===
	_gm._tooltip_module.create_custom_tooltip(ui_layer)

	# 战斗事件日志
	EventBus.connect_event("entity_damaged", _gm._combat_log_module._on_log_damaged)
	EventBus.connect_event("entity_destroyed", _gm._combat_log_module._on_log_destroyed)
	EventBus.connect_event("entity_healed", _gm._combat_log_module._on_log_healed)
	EventBus.connect_event("spell_cast", _gm._combat_log_module._on_log_spell)
	EventBus.connect_event("aura_applied", _gm._combat_log_module._on_log_aura)
	EventBus.connect_event("proc_triggered", _gm._combat_log_module._on_log_proc)
	EventBus.connect_event("wave_started", _gm._combat_log_module._on_log_wave)

func update_hud() -> void:
	var delta: float = _gm.get_process_delta_time() if _gm else 0.016
	var I18n: Node = _gm.I18n
	if _topbar: _topbar.update(I18n)
	if _portrait: _portrait.update()
	if _skillbar: _skillbar.update(I18n)
	if _announce: _announce.update(delta)
	if _buffbar: _buffbar.update(delta)
	_update_bond_hover_position()
	_update_boss_hp_bar(I18n)
	# 羁绊面板实时刷新（卡片数量变化时）
	if _bond_panel and _bond_panel.visible and _gm._card_sys:
		var cur: int = _gm._card_sys.held_cards.size() + _gm._card_sys.consumed_cards.size()
		if cur != _last_held_count:
			_last_held_count = cur
			_refresh_bond_panel()

func add_announcement(msg: String, color: Color = Color(0.85, 0.85, 0.9)) -> void:
	if _announce: _announce.add(msg, color)

func _on_ui_toast(data: Dictionary) -> void:
	## TriggerSystem show_toast 动作的渲染入口（onboarding 等数据驱动 UX 的统一通道）
	if _announce == null:
		return
	var text: String = str(data.get("text", ""))
	if text.is_empty():
		return
	var color := Color(0.85, 0.85, 0.9)
	var hex: String = str(data.get("color", ""))
	if hex.begins_with("#") and hex.length() >= 7:
		color = Color.html(hex)
	_announce.add(text, color)

# === 小地图 ===

func _create_minimap(ui_layer: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0; panel.anchor_right = 0.0
	panel.anchor_top = 1.0; panel.anchor_bottom = 1.0
	panel.offset_left = 2; panel.offset_right = 132
	panel.offset_top = -135; panel.offset_bottom = -2
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.06, 0.03, 0.85)
	s.border_color = Color(0.25, 0.5, 0.15, 0.6)
	s.border_width_top = 1; s.border_width_bottom = 1; s.border_width_left = 1; s.border_width_right = 1
	s.corner_radius_top_left = 4; s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4; s.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", s)
	ui_layer.add_child(panel)
	var lbl := Label.new()
	lbl.text = "MAP"; lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.3, 0.5, 0.2, 0.5))
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(lbl)

# === Boss HP bar ===

func _create_boss_hp_bar(ui_layer: CanvasLayer) -> void:
	_boss_hp_bar = Control.new()
	_boss_hp_bar.anchor_left = 0.5; _boss_hp_bar.anchor_right = 0.5
	_boss_hp_bar.offset_left = -200; _boss_hp_bar.offset_top = 42
	_boss_hp_bar.offset_right = 200; _boss_hp_bar.offset_bottom = 75
	_boss_hp_bar.visible = false
	ui_layer.add_child(_boss_hp_bar)
	var bg := ColorRect.new(); bg.color = Color(0.1, 0.1, 0.15, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _boss_hp_bar.add_child(bg)
	_boss_hp_fill = ColorRect.new(); _boss_hp_fill.color = Color(0.8, 0.15, 0.1)
	_boss_hp_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boss_hp_fill.offset_left = 2; _boss_hp_fill.offset_top = 2
	_boss_hp_fill.offset_right = -2; _boss_hp_fill.offset_bottom = -2
	_boss_hp_bar.add_child(_boss_hp_fill)
	_boss_name_label = Label.new()
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boss_name_label.add_theme_font_size_override("font_size", 14)
	_boss_name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.8))
	_boss_hp_bar.add_child(_boss_name_label)

func _update_boss_hp_bar(I18n: Node) -> void:
	if _boss_hp_bar == null: return
	var live_boss: Node3D = null
	for b in _gm._spawner.active_bosses:
		if b != null and is_instance_valid(b): live_boss = b; break
	if live_boss:
		_boss_hp_bar.visible = true
		var bh: Node = EngineAPI.get_component(live_boss, "health")
		if bh:
			_boss_hp_fill.anchor_right = bh.current_hp / bh.max_hp if bh.max_hp > 0 else 0.0
			_boss_name_label.text = "%s  %d / %d" % [I18n.t(_gm._spawner.get_boss_name_key(live_boss)), int(bh.current_hp), int(bh.max_hp)]
	else:
		_boss_hp_bar.visible = false

# === 羁绊面板 ===

func _create_bond_panel(ui_layer: CanvasLayer) -> void:
	_bond_panel = PanelContainer.new()
	_bond_panel.anchor_left = 1.0; _bond_panel.anchor_right = 1.0
	_bond_panel.anchor_top = 0.5; _bond_panel.anchor_bottom = 0.5
	_bond_panel.offset_left = -330; _bond_panel.offset_top = -200
	_bond_panel.offset_right = -5; _bond_panel.offset_bottom = 200
	_bond_panel.visible = false
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.05, 0.12, 0.95)
	s.corner_radius_top_left = 8; s.corner_radius_top_right = 8
	s.border_color = Color(0.4, 0.25, 0.7, 0.6)
	s.border_width_top = 2; s.border_width_left = 1; s.border_width_right = 1
	s.content_margin_left = 10; s.content_margin_right = 10
	s.content_margin_top = 8; s.content_margin_bottom = 8
	s.shadow_color = Color(0.3, 0.15, 0.6, 0.3); s.shadow_size = 6
	_bond_panel.add_theme_stylebox_override("panel", s)
	ui_layer.add_child(_bond_panel)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bond_panel.add_child(scroll)
	_bond_content = VBoxContainer.new()
	_bond_content.add_theme_constant_override("separation", 4)
	_bond_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_bond_content)

func _toggle_bond_panel() -> void:
	if _bond_panel:
		_bond_panel.visible = not _bond_panel.visible
		if _bond_panel.visible: _refresh_bond_panel()
		else: _hide_bond_tooltip()

func _refresh_bond_panel() -> void:
	if _bond_content == null: return
	for child in _bond_content.get_children(): child.queue_free()
	_hide_bond_tooltip()
	if not _gm._card_sys: return
	var cs = _gm._card_sys; var I18n: Node = _gm.I18n

	var cell_size := 44

	# === 上方：已凑齐的套装效果 ===
	var bond_title := Label.new()
	bond_title.text = I18n.t("BOND_REWARD") if I18n else "Set Bonuses"
	bond_title.add_theme_font_size_override("font_size", 11)
	bond_title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_bond_content.add_child(bond_title)

	var bond_grid := GridContainer.new(); bond_grid.columns = 6
	bond_grid.add_theme_constant_override("h_separation", 4)
	bond_grid.add_theme_constant_override("v_separation", 4)
	_bond_content.add_child(bond_grid)

	var activated_bonds: Array = cs.get_activated_bonds()
	if activated_bonds.is_empty():
		# 占位保持间距
		var placeholder := Label.new()
		placeholder.text = "—"
		placeholder.add_theme_font_size_override("font_size", 10)
		placeholder.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		placeholder.custom_minimum_size = Vector2(cell_size, cell_size)
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bond_grid.add_child(placeholder)
	else:
		for bond_id in activated_bonds:
			var bname: String = cs._get_bond_display_name(bond_id)
			var bcell := PanelContainer.new()
			bcell.custom_minimum_size = Vector2(cell_size, cell_size)
			bcell.clip_contents = true
			var bs := StyleBoxFlat.new()
			bs.bg_color = Color(0.08, 0.06, 0.04, 0.95)
			bs.corner_radius_top_left = 3; bs.corner_radius_top_right = 3
			bs.corner_radius_bottom_left = 3; bs.corner_radius_bottom_right = 3
			bs.border_color = Color(0.85, 0.7, 0.2, 0.8)
			bs.border_width_top = 2; bs.border_width_bottom = 2
			bs.border_width_left = 2; bs.border_width_right = 2
			bs.content_margin_left = 2; bs.content_margin_right = 2
			bs.content_margin_top = 2; bs.content_margin_bottom = 2
			bcell.add_theme_stylebox_override("panel", bs)
			bcell.mouse_filter = Control.MOUSE_FILTER_STOP
			var blbl := Label.new()
			blbl.text = bname.substr(0, 2) if bname.length() >= 2 else bname
			blbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			blbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			blbl.add_theme_font_size_override("font_size", 12)
			blbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
			blbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bcell.add_child(blbl)
			var bid_ref: String = bond_id
			bcell.mouse_entered.connect(func() -> void: _on_bond_icon_hover(bid_ref))
			bcell.mouse_exited.connect(func() -> void: _hide_bond_tooltip())
			bond_grid.add_child(bcell)

	# === 下方：已吞噬的卡片（按吞噬先后顺序，老的在前）===
	if cs.consumed_cards.size() > 0:
		_bond_content.add_child(HSeparator.new())
		var consumed_title := Label.new()
		consumed_title.text = I18n.t("CARD_STATUS_CONSUMED") if I18n else "Consumed"
		consumed_title.add_theme_font_size_override("font_size", 11)
		consumed_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		_bond_content.add_child(consumed_title)

		var card_grid := GridContainer.new(); card_grid.columns = 6
		card_grid.add_theme_constant_override("h_separation", 4)
		card_grid.add_theme_constant_override("v_separation", 4)
		_bond_content.add_child(card_grid)

		# consumed_cards 数组本身就是按吞噬顺序排列的（append 顺序）
		for c in cs.consumed_cards:
			card_grid.add_child(_bond_card_cell(cs, c.get("id", ""), c.get("data", {}), cell_size))

func _on_card_cell_hover(_card_id: String, cdata: Dictionary) -> void:
	## hover 单张卡片：左边卡片详情，右边套装效果（如果有的话）
	_hide_bond_tooltip()
	if not _gm._card_sys: return
	var cs = _gm._card_sys
	var ui_layer: CanvasLayer = _gm.get_tree().current_scene.get_node_or_null("UI")
	if ui_layer == null: return

	# 容器
	if _bond_hover_container and is_instance_valid(_bond_hover_container): _bond_hover_container.queue_free()
	_bond_hover_container = Control.new()
	_bond_hover_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bond_hover_container.z_index = 100
	ui_layer.add_child(_bond_hover_container)

	var cw := 155
	_bond_hover_card_w = cw
	_bond_hover_total_cards = 1  # 只显示卡片自身

	# === 卡片详情（统一 BBCode）===
	var tc: Color = cs._get_tier_color(cdata.get("tier", 1))
	var p1 := _hover_card_panel(cw, Color(tc.r, tc.g, tc.b, 0.8))
	p1.position = Vector2(0, 0)
	_bond_hover_container.add_child(p1)
	var vb1: VBoxContainer = p1.get_child(0)
	# 卡名
	_add_lbl(vb1, cs._get_card_display_name(cdata), 13, tc, HORIZONTAL_ALIGNMENT_CENTER)
	# 统一描述
	var bbcode: String = cs.build_card_bbcode(cdata)
	if bbcode != "":
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true; rtl.scroll_active = false; rtl.fit_content = true
		rtl.add_theme_font_size_override("normal_font_size", 10)
		rtl.text = bbcode; rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb1.add_child(rtl)
	_bond_hover_panels.append(p1)
	_update_bond_hover_position()

func _bond_card_cell(cs, card_id: String, cdata: Dictionary, size: int, _is_held: bool = true) -> PanelContainer:
	var tier: int = cdata.get("tier", 1)
	var tc: Color = cs._get_tier_color(tier)
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(size, size)
	cell.clip_contents = true
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.06, 0.05, 0.1, 0.95)
	sty.corner_radius_top_left = 3; sty.corner_radius_top_right = 3
	sty.corner_radius_bottom_left = 3; sty.corner_radius_bottom_right = 3
	sty.border_color = Color(tc.r, tc.g, tc.b, 0.7)
	sty.border_width_top = 2; sty.border_width_bottom = 2
	sty.border_width_left = 2; sty.border_width_right = 2
	sty.content_margin_left = 2; sty.content_margin_right = 2
	sty.content_margin_top = 2; sty.content_margin_bottom = 2
	cell.add_theme_stylebox_override("panel", sty)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var lbl := Label.new()
	var cname: String = cs._get_card_display_name(cdata)
	lbl.text = cname.substr(0, 2) if cname.length() >= 2 else cname
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", tc)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(lbl)
	var cid_ref: String = card_id; var cdata_ref: Dictionary = cdata
	cell.mouse_entered.connect(_on_card_cell_hover.bind(cid_ref, cdata_ref))
	cell.mouse_exited.connect(func() -> void: _hide_bond_tooltip())
	return cell

func _on_bond_icon_hover(bond_id: String) -> void:
	## hover 套装 icon：显示套装效果 tooltip
	_hide_bond_tooltip()
	if not _gm._card_sys: return
	var cs = _gm._card_sys; var I18n: Node = _gm.I18n
	var bd: Dictionary = cs._all_bonds.get(bond_id, {}); if bd.is_empty(): return
	var ui_layer: CanvasLayer = _gm.get_tree().current_scene.get_node_or_null("UI")
	if ui_layer == null: return
	if _bond_hover_container and is_instance_valid(_bond_hover_container): _bond_hover_container.queue_free()
	_bond_hover_container = Control.new()
	_bond_hover_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bond_hover_container.z_index = 100
	ui_layer.add_child(_bond_hover_container)
	_bond_hover_card_w = 155; _bond_hover_total_cards = 1
	var p := _hover_card_panel(155, Color(0.8, 0.65, 0.2, 0.8))
	_bond_hover_container.add_child(p)
	var vb: VBoxContainer = p.get_child(0)
	_add_lbl(vb, I18n.t("BOND_REWARD") if I18n else "Set Bonus", 12, Color(1, 0.85, 0.3), HORIZONTAL_ALIGNMENT_CENTER)
	_add_lbl(vb, cs._get_bond_display_name(bond_id), 10, Color(0.7, 0.4, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	var prog: int = cs.get_bond_progress(bond_id)
	var req: int = bd.get("required", 3)
	_add_lbl(vb, "%d/%d ✓" % [prog, req], 9, Color(0.4, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	var bs: Dictionary = bd.get("stats", {})
	if not bs.is_empty():
		vb.add_child(HSeparator.new())
		for s: String in bs: _add_lbl(vb, cs._format_stat(s, float(bs[s])), 10, Color(0.9, 0.8, 0.4))
	var desc: String = cs.get_bond_desc(bond_id)
	if desc != "":
		vb.add_child(HSeparator.new())
		_add_lbl(vb, desc, 9, Color(0.6, 0.6, 0.7))
	_bond_hover_panels.append(p)
	_update_bond_hover_position()

func _hover_card_panel(w: int, border_color: Color) -> PanelContainer:
	var p := PanelContainer.new(); p.custom_minimum_size = Vector2(w, 0)
	var s := StyleBoxFlat.new(); s.bg_color = Color(0.06, 0.05, 0.12, 0.96)
	s.corner_radius_top_left = 6; s.corner_radius_top_right = 6; s.corner_radius_bottom_left = 6; s.corner_radius_bottom_right = 6
	s.border_color = border_color; s.border_width_top = 2; s.border_width_bottom = 2; s.border_width_left = 2; s.border_width_right = 2
	s.content_margin_left = 8; s.content_margin_right = 8; s.content_margin_top = 6; s.content_margin_bottom = 6
	s.shadow_color = Color(0, 0, 0, 0.5); s.shadow_size = 5
	p.add_theme_stylebox_override("panel", s); p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 2); vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(vb); return p

func _add_lbl(parent: Node, text: String, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color); l.horizontal_alignment = align as HorizontalAlignment
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE; l.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(l); return l

func _hide_bond_tooltip() -> void:
	if _bond_hover_container and is_instance_valid(_bond_hover_container):
		_bond_hover_container.queue_free(); _bond_hover_container = null
	_bond_hover_panels.clear(); _bond_hover_total_cards = 0

func _update_bond_hover_position() -> void:
	if _bond_hover_container == null or not is_instance_valid(_bond_hover_container): return
	var vp: Viewport = _bond_hover_container.get_viewport(); if vp == null: return
	var vs: Vector2 = vp.get_visible_rect().size; var mp: Vector2 = vp.get_mouse_position()
	var tw: float = _bond_hover_total_cards * _bond_hover_card_w + (_bond_hover_total_cards - 1) * 6
	var sx: float = clampf(mp.x - tw * 0.5, 5, vs.x - tw - 5)
	var sy: float = clampf(mp.y - 250, 5, vs.y - 300)
	_bond_hover_container.position = Vector2(sx, sy)
