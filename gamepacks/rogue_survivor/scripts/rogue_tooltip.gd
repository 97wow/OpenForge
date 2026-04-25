## RogueTooltip - 自定义即时 Tooltip，带发光效果
class_name RogueTooltip

var _gm  # 主控制器引用

# 自定义 Tooltip
var _custom_tooltip: PanelContainer = null
var _tooltip_title: Label = null
var _tooltip_desc: RichTextLabel = null
var _floating_cards: Array[PanelContainer] = []  # 独立浮动卡片
var _tooltip_ui_layer: CanvasLayer = null

# 伤害类型颜色（参考 HealthComponent / WoW）
var _school_colors := {
	"physical": Color(1, 1, 1),
	"frost": Color(0.31, 0.78, 1.0),
	"fire": Color(1.0, 0.49, 0.16),
	"nature": Color(0.30, 0.87, 0.30),
	"shadow": Color(0.64, 0.21, 0.93),
	"holy": Color(1.0, 0.90, 0.35),
}

func init(game_mode) -> void:
	_gm = game_mode

func create_custom_tooltip(ui_layer: CanvasLayer) -> void:
	_custom_tooltip = PanelContainer.new()
	_custom_tooltip.visible = false
	_custom_tooltip.z_index = 100
	_custom_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_custom_tooltip.custom_minimum_size = Vector2(160, 0)  # 最小宽度，卡片区域自动撑开

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.14, 0.95)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	# 发光描边
	style.border_color = Color(0.5, 0.35, 0.9, 0.8)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	# 外发光阴影
	style.shadow_color = Color(0.4, 0.2, 0.8, 0.3)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	# 内边距
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_custom_tooltip.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_custom_tooltip.add_child(vbox)

	_tooltip_title = Label.new()
	_tooltip_title.add_theme_font_size_override("font_size", 14)
	_tooltip_title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_tooltip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_tooltip_title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.4, 0.3, 0.7, 0.5))
	vbox.add_child(sep)

	_tooltip_desc = RichTextLabel.new()
	_tooltip_desc.bbcode_enabled = true
	_tooltip_desc.fit_content = true
	_tooltip_desc.scroll_active = false
	_tooltip_desc.add_theme_font_size_override("normal_font_size", 11)
	_tooltip_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_desc.custom_minimum_size = Vector2(240, 0)
	vbox.add_child(_tooltip_desc)

	ui_layer.add_child(_custom_tooltip)
	_tooltip_ui_layer = ui_layer

func show_tooltip(title: String, bbcode_desc: String, rarity_color: Color = Color(0.7, 0.7, 0.8)) -> void:
	if _custom_tooltip == null:
		return
	_tooltip_title.text = title
	_tooltip_title.add_theme_color_override("font_color", rarity_color)
	_tooltip_desc.text = bbcode_desc
	_tooltip_desc.visible = bbcode_desc != ""
	_clear_floating_cards()
	# 重置尺寸，让面板根据新内容重新计算大小
	_custom_tooltip.reset_size()
	_custom_tooltip.visible = true
	# 更新描边颜色匹配稀有度
	var style: StyleBoxFlat = _custom_tooltip.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = Color(rarity_color.r * 0.7, rarity_color.g * 0.7, rarity_color.b * 0.7, 0.8)
		style.shadow_color = Color(rarity_color.r * 0.5, rarity_color.g * 0.5, rarity_color.b * 0.5, 0.3)

func hide_tooltip() -> void:
	if _custom_tooltip:
		_custom_tooltip.visible = false
	_clear_floating_cards()

func _clear_floating_cards() -> void:
	for card in _floating_cards:
		if is_instance_valid(card):
			card.queue_free()
	_floating_cards.clear()

func update_tooltip_position() -> void:
	if _custom_tooltip == null or not _custom_tooltip.visible:
		return
	var mouse_pos: Vector2 = _gm.get_viewport().get_mouse_position()
	var vp_size: Vector2 = _gm.get_viewport().get_visible_rect().size
	var tt_size := _custom_tooltip.size
	# 显示在鼠标右上方，避免超出屏幕
	var pos := mouse_pos + Vector2(16, -tt_size.y - 8)
	if pos.x + tt_size.x > vp_size.x:
		pos.x = mouse_pos.x - tt_size.x - 16
	if pos.y < 0:
		pos.y = mouse_pos.y + 20
	_custom_tooltip.position = pos

func setup_card_slot_tooltip(slot: PanelContainer, slot_idx: int) -> void:
	## 给卡片槽绑定 tooltip 事件
	slot.mouse_entered.connect(_on_card_slot_hover.bind(slot_idx))
	slot.mouse_exited.connect(hide_tooltip)

func _on_card_slot_hover(slot_idx: int) -> void:
	var I18n: Node = _gm.I18n
	# 新卡片系统优先
	if _gm._card_sys and not _gm._card_manager:
		if slot_idx >= _gm._card_sys.held_cards.size():
			return
		var entry: Dictionary = _gm._card_sys.held_cards[slot_idx]
		var cdata: Dictionary = entry.get("data", {})
		var cname: String = _gm._card_sys._get_card_display_name(cdata)
		var card_bbcode: String = _gm._card_sys.build_card_bbcode(cdata)
		var tier: int = cdata.get("tier", 1)
		show_tooltip(cname, card_bbcode, _gm._card_sys._get_tier_color(tier))
		return
	if _gm._card_manager == null:
		return
	var held: Array[String] = _gm._card_manager.get_held_cards()
	if slot_idx >= held.size():
		return
	var card_data: Dictionary = _gm._card_manager.get_card_data(held[slot_idx])
	var spell_id: String = card_data.get("spell_id", "")
	var rarity: String = card_data.get("rarity", "common")

	# 如果卡片有关联技能，使用标准化 spell tooltip
	if spell_id != "":
		var spell_sys = EngineAPI.get_system("spell")
		var spell_data: Dictionary = spell_sys.call("get_spell", spell_id) if spell_sys else {}
		if not spell_data.is_empty():
			show_spell_tooltip(spell_data, card_data)
			return

	# 回退：无技能数据时使用旧逻辑
	var name_key: String = card_data.get("name_key", "")
	var set_id: String = card_data.get("set_id", "")

	var title: String = I18n.t(name_key) if name_key != "" else held[slot_idx]

	# 组装 BBCode 描述
	var desc := ""
	desc += "[color=#999999]%s[/color]\n" % I18n.t(rarity.to_upper())
	var legacy_desc: String = ""
	if _gm._card_sys:
		legacy_desc = _gm._card_sys.get_card_desc(card_data)
	if legacy_desc == "":
		var desc_key: String = card_data.get("desc_key", "")
		legacy_desc = I18n.t(desc_key) if desc_key != "" else ""
	if legacy_desc != "":
		desc += legacy_desc + "\n"
	if spell_id != "":
		var detail: String = _gm._combat_log_module.get_spell_detail_text(spell_id)
		if detail != "":
			desc += "[color=#66cc66]%s[/color]\n" % detail

	# 套装信息（效果 + 已有/缺少的卡片）
	if set_id != "":
		desc += _build_set_info_bbcode(set_id, held)

	show_tooltip(title, desc, _rarity_color(rarity))

## 标准化技能 Tooltip 显示
## spell_data: 来自 SpellSystem/DataRegistry 的技能数据
## card_data: 可选的卡片数据（提供名称、套装等信息）
func show_spell_tooltip(spell_data: Dictionary, card_data: Dictionary = {}) -> void:
	if _custom_tooltip == null:
		return
	var I18n: Node = _gm.I18n

	# === 标题 ===
	var name_key: String = card_data.get("name_key", "")
	var title: String = ""
	if name_key != "":
		title = I18n.t(name_key)
	else:
		title = card_data.get("name", spell_data.get("id", "Unknown"))

	# === 稀有度颜色 ===
	var rarity: String = card_data.get("rarity", "common")
	var title_color: Color = _rarity_color(rarity)

	# === Meta 行（CD / 射程 / 施法时间）===
	var meta_parts: Array[String] = []
	var cd: float = spell_data.get("cooldown", 0.0)
	if cd > 0:
		meta_parts.append("CD: %.1fs" % cd)
	var cast_time: float = spell_data.get("cast_time", 0.0)
	if cast_time > 0:
		meta_parts.append("Cast: %.1fs" % cast_time)
	# 从 effects 中提取射程/半径
	var spell_range: float = _extract_spell_range(spell_data)
	if spell_range > 0:
		meta_parts.append("Range: %.1fm" % spell_range)

	# === 描述（BBCode）===
	var desc: String = _build_spell_description(spell_data, card_data)

	# === 组装最终 BBCode ===
	var bbcode := ""
	if meta_parts.size() > 0:
		bbcode += "[color=#888888][font_size=10]%s[/font_size][/color]\n" % " | ".join(meta_parts)
	bbcode += desc

	# === 套装信息 ===
	var set_id: String = card_data.get("set_id", "")
	if set_id != "" and _gm._card_manager != null:
		var held: Array[String] = _gm._card_manager.get_held_cards()
		bbcode += "\n" + _build_set_info_bbcode(set_id, held)

	show_tooltip(title, bbcode, title_color)

## 从技能 effects 中提取最大射程/半径
func _extract_spell_range(spell_data: Dictionary) -> float:
	var max_range: float = 0.0
	var effects: Array = spell_data.get("effects", [])
	for eff in effects:
		var target: Dictionary = eff.get("target", {})
		var radius: float = target.get("radius", 0.0)
		if radius > max_range:
			max_range = radius
	return max_range

## 根据技能 effects 构建人类可读的 BBCode 描述
func _build_spell_description(spell_data: Dictionary, card_data: Dictionary) -> String:
	var school: String = spell_data.get("school", "physical")
	var school_color: Color = _school_colors.get(school, Color.WHITE)
	var school_hex: String = school_color.to_html(false)

	var lines: Array[String] = []
	var effects: Array = spell_data.get("effects", [])

	for eff in effects:
		var eff_type: String = eff.get("type", "")
		var base_points: float = eff.get("base_points", 0.0)
		var target: Dictionary = eff.get("target", {})
		var radius: float = target.get("radius", 0.0)
		var target_check: String = target.get("check", "")
		var line := ""

		match eff_type:
			"SCHOOL_DAMAGE":
				line = "Deals [color=#%s]%.0f %s[/color] damage" % [school_hex, base_points, school]
				if radius > 0:
					var scope: String = "enemies" if target_check == "ENEMY" else "targets"
					line += " to %s within %.1fm" % [scope, radius]
			"HEAL":
				line = "Heals for [color=#44ff44]%.0f[/color]" % base_points
				if radius > 0:
					var scope: String = "allies" if target_check == "ALLY" else "targets"
					line += " %s within %.1fm" % [scope, radius]
			"SET_VARIABLE":
				var var_key: String = eff.get("key", eff.get("variable", "stat"))
				line = "Increases %s by %.0f" % [var_key, base_points]
			"APPLY_AURA":
				var aura_id: String = eff.get("aura_id", eff.get("aura", ""))
				var duration: float = eff.get("duration", 0.0)
				if aura_id != "":
					line = "Applies [color=#cc99ff]%s[/color]" % aura_id
				else:
					line = "Applies an effect"
				if duration > 0:
					line += " for %.1fs" % duration
			"TRIGGER_SPELL":
				var trigger_id: String = eff.get("spell_id", eff.get("trigger", ""))
				if trigger_id != "":
					line = "Triggers [color=#ffcc44]%s[/color]" % trigger_id
			_:
				if eff_type != "":
					line = "%s: %.0f" % [eff_type, base_points]

		if line != "":
			lines.append(line)

	# 如果没有从 effects 解析到任何内容，回退到嵌入描述或 combat_log
	if lines.is_empty():
		var embedded_desc: String = ""
		if _gm._card_sys:
			embedded_desc = _gm._card_sys.get_card_desc(card_data)
		if embedded_desc != "":
			lines.append(embedded_desc)
		else:
			var spell_id: String = spell_data.get("id", "")
			if spell_id != "" and _gm._combat_log_module != null:
				var detail: String = _gm._combat_log_module.get_spell_detail_text(spell_id)
				if detail != "":
					lines.append("[color=#66cc66]%s[/color]" % detail)

	return "\n".join(lines)

## 构建套装信息 BBCode（复用逻辑）
func _build_set_info_bbcode(set_id: String, held: Array[String]) -> String:
	var I18n: Node = _gm.I18n
	var set_data: Dictionary = _gm._card_manager.get_set_data(set_id)
	var set_tr_key: String = "SET_" + set_id.to_upper()
	var desc := ""
	desc += "\n[color=#8888aa]── [%s] ──[/color]" % I18n.t(set_tr_key)
	# 套装效果
	var bonus: Dictionary = set_data.get("set_bonus", {})
	var eff_key := "SET_EFFECT_" + str(bonus.get("type", ""))
	var eff_txt: String = I18n.t(eff_key)
	if eff_txt != eff_key:
		desc += "\n[color=#ffcc44]%s[/color]" % eff_txt
	# 每张卡片：已有=绿色勾，缺少=灰色
	var set_cards: Array = set_data.get("cards", [])
	for cid in set_cards:
		var cd: Dictionary = _gm._card_manager.get_card_data(str(cid))
		var cn: String = I18n.t(cd.get("name_key", str(cid)))
		var is_held: bool = str(cid) in held
		if is_held:
			desc += "\n  [color=#44ff44]✓ %s[/color]" % cn
		else:
			desc += "\n  [color=#666666]✗ %s[/color]" % cn
	return desc

func setup_buff_tooltip(buff_panel: PanelContainer, set_id: String) -> void:
	buff_panel.mouse_entered.connect(_on_buff_hover.bind(set_id))
	buff_panel.mouse_exited.connect(hide_tooltip)

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon": return Color(0.0, 0.44, 0.87)  # WoW 蓝
		"rare": return Color(0.64, 0.21, 0.93)      # WoW 紫
		"legendary": return Color(1.0, 0.5, 0.0)    # WoW 橙
		_: return Color(1.0, 1.0, 1.0)              # WoW 白

func _on_buff_hover(set_id: String) -> void:
	var I18n: Node = _gm.I18n
	if _gm._card_manager == null or _tooltip_ui_layer == null:
		return
	_clear_floating_cards()

	var set_data: Dictionary = _gm._card_manager.get_set_data(set_id)
	var set_tr_key := "SET_" + set_id.to_upper()
	var rarity: String = set_data.get("rarity", "common")
	var title: String = I18n.t(set_tr_key)
	var title_color: Color = _rarity_color(rarity)

	# 隐藏默认 tooltip（用独立卡片替代）
	if _custom_tooltip:
		_custom_tooltip.visible = false

	# 鼠标位置作为起点
	var mouse_pos: Vector2 = _gm.get_viewport().get_mouse_position()
	var card_x: float = mouse_pos.x + 16
	var card_y: float = mouse_pos.y - 100

	# 第1张：套装主卡（大卡，粗边框+发光）
	var bonus: Dictionary = set_data.get("set_bonus", {})
	var eff_key := "SET_EFFECT_" + str(bonus.get("type", ""))
	var eff_txt: String = I18n.t(eff_key)
	if eff_txt == eff_key:
		eff_txt = ""
	var set_desc: String = I18n.t(rarity.to_upper())
	if eff_txt != "":
		set_desc += "\n" + eff_txt
	var bonus_spell_id: String = set_data.get("bonus_spell", "")
	if bonus_spell_id != "":
		var detail: String = _gm._combat_log_module.get_spell_detail_text(bonus_spell_id)
		if detail != "":
			set_desc += "\n" + detail

	var set_card: PanelContainer = _build_floating_card(title, set_desc, title_color, true)
	set_card.position = Vector2(card_x, card_y)
	_tooltip_ui_layer.add_child(set_card)
	_floating_cards.append(set_card)
	card_x += 145

	# 后续：每张子卡片（小卡，细边框）
	var cards: Array = set_data.get("cards", [])
	for cid in cards:
		var cdata: Dictionary = _gm._card_manager.get_card_data(str(cid))
		var cname: String = I18n.t(cdata.get("name_key", str(cid)))
		var crarity: String = cdata.get("rarity", "common")
		var cdesc: String = ""
		if _gm._card_sys:
			cdesc = _gm._card_sys.get_card_desc(cdata)
		if cdesc == "":
			var cdesc_key: String = cdata.get("desc_key", "")
			cdesc = I18n.t(cdesc_key) if cdesc_key != "" else ""
		var child_card: PanelContainer = _build_floating_card(cname, cdesc, _rarity_color(crarity), false)
		child_card.position = Vector2(card_x, card_y + 5)  # 子卡略微下移
		_tooltip_ui_layer.add_child(child_card)
		_floating_cards.append(child_card)
		card_x += 125

func _build_floating_card(title_text: String, desc_text: String, border_col: Color, is_set: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(135, 90) if is_set else Vector2(115, 80)
	card.z_index = 101
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.05, 0.14, 0.97)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.border_color = border_col
	style.border_width_top = 2 if is_set else 1
	style.border_width_bottom = 2 if is_set else 1
	style.border_width_left = 2 if is_set else 1
	style.border_width_right = 2 if is_set else 1
	if is_set:
		style.shadow_color = Color(border_col.r, border_col.g, border_col.b, 0.35)
		style.shadow_size = 5
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vb)

	var tl := Label.new()
	tl.text = title_text
	tl.add_theme_font_size_override("font_size", 12 if is_set else 10)
	tl.add_theme_color_override("font_color", border_col if is_set else Color(1.0, 1.0, 1.0))
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tl)

	# 分隔线
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(border_col.r, border_col.g, border_col.b, 0.3)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(sep)

	if desc_text != "":
		var dl := Label.new()
		dl.text = desc_text
		dl.add_theme_font_size_override("font_size", 9)
		dl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD
		dl.custom_minimum_size = Vector2(105, 0)
		dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(dl)

	return card
