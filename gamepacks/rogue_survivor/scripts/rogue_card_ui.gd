## RogueCardUI - 卡片选择UI、卡片效果、套装奖励、转职系统
class_name RogueCardUI

var _gm  # 主控制器引用
var _pending_card_id: String = ""  # 卡满时暂存要添加的卡
var _pending_picks: int = 0  # 待选卡片次数（多次升级累积）

func init(game_mode) -> void:
	_gm = game_mode

# === 转职系统 ===

func show_promotion_selection() -> void:
	var I18n: Node = _gm.I18n
	var hero_class: String = str(EngineAPI.get_variable("hero_class", "warrior"))
	var classes: Dictionary = _gm._promotion_data.get("classes", {})
	var options: Array = classes.get(hero_class, [])
	if options.is_empty():
		show_card_selection()
		return

	# 选卡不暂停游戏
	var ui_layer: CanvasLayer = _gm.get_tree().current_scene.get_node_or_null("UI")
	if ui_layer == null:
		# 选卡不暂停游戏
		show_card_selection()
		return

	var panel := Control.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.name = "PromotionUI"
	ui_layer.add_child(panel)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(overlay)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = I18n.t("PROMOTION_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = I18n.t("PROMOTION_SUBTITLE")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(subtitle)

	# 2 个选择
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 40)
	vbox.add_child(hbox)

	for opt in options:
		if not opt is Dictionary:
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(280, 320)
		btn.pressed.connect(_on_promotion_selected.bind(opt, panel))
		btn.mouse_entered.connect(func() -> void: btn.modulate = Color(1.2, 1.2, 1.3))
		btn.mouse_exited.connect(func() -> void: btn.modulate = Color.WHITE)
		hbox.add_child(btn)

		var bvbox := VBoxContainer.new()
		bvbox.add_theme_constant_override("separation", 8)
		bvbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bvbox)

		# 职业名
		var name_lbl := Label.new()
		name_lbl.text = I18n.t(opt.get("name_key", ""))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 24)
		var opt_color: Color = Color.from_string(opt.get("color", "#ffffff"), Color.WHITE)
		name_lbl.add_theme_color_override("font_color", opt_color)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bvbox.add_child(name_lbl)

		# 描述
		var desc_lbl := Label.new()
		desc_lbl.text = I18n.t(opt.get("desc_key", ""))
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_lbl.custom_minimum_size = Vector2(250, 0)
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bvbox.add_child(desc_lbl)

		# 属性加成
		var stat_bonus: Dictionary = opt.get("stat_bonus", {})
		if not stat_bonus.is_empty():
			var stat_text := ""
			for skey in stat_bonus:
				var sval: int = stat_bonus[skey]
				var display_key: String = skey.replace("base_", "").replace("level_", "Lv.").to_upper()
				stat_text += "+%d %s  " % [sval, display_key]
			var stat_lbl := Label.new()
			stat_lbl.text = stat_text.strip_edges()
			stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stat_lbl.add_theme_font_size_override("font_size", 11)
			stat_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
			stat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			stat_lbl.custom_minimum_size = Vector2(250, 0)
			stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bvbox.add_child(stat_lbl)

func _on_promotion_selected(promo: Dictionary, ui: Control) -> void:
	var I18n: Node = _gm.I18n
	_gm._promoted = true
	_gm._promoted_class = promo.get("id", "")
	_gm.set_var("promoted_class", _gm._promoted_class)

	# 应用属性加成
	if _gm.hero and is_instance_valid(_gm.hero) and _gm.hero is GameEntity:
		var entity := _gm.hero as GameEntity
		var stat_bonus: Dictionary = promo.get("stat_bonus", {})
		for skey in stat_bonus:
			entity.meta[skey] = entity.meta.get(skey, 0) + int(stat_bonus[skey])

		# 应用战斗修改
		var combat_mod: Dictionary = promo.get("combat_mod", {})
		var input_comp: Node = EngineAPI.get_component(_gm.hero, "player_input")
		if input_comp:
			if combat_mod.has("projectile_damage_mult"):
				input_comp.projectile_damage *= float(combat_mod["projectile_damage_mult"])
			if combat_mod.has("shoot_cooldown_mult"):
				input_comp.shoot_cooldown *= float(combat_mod["shoot_cooldown_mult"])
			if combat_mod.has("attack_range_add"):
				input_comp.attack_range += float(combat_mod["attack_range_add"])
			if combat_mod.has("projectile_speed_mult"):
				input_comp.projectile_speed *= float(combat_mod["projectile_speed_mult"])

		# HP 和护甲修改
		var health_comp: Node = EngineAPI.get_component(_gm.hero, "health")
		if health_comp:
			if combat_mod.has("max_hp_mult"):
				health_comp.max_hp *= float(combat_mod["max_hp_mult"])
				health_comp.current_hp = health_comp.max_hp
			if combat_mod.has("armor_add"):
				health_comp.armor += float(combat_mod["armor_add"])

		# 移速修改
		var move_comp: Node = EngineAPI.get_component(_gm.hero, "movement")
		if move_comp and combat_mod.has("movement_speed_add"):
			move_comp.base_speed += float(combat_mod["movement_speed_add"])

		# 吸血修改
		if combat_mod.has("life_steal_add"):
			var current_ls: float = float(EngineAPI.get_variable("hero_life_steal", 0.0))
			EngineAPI.set_variable("hero_life_steal", current_ls + float(combat_mod["life_steal_add"]))

		# 改变颜色和大小：移除旧 visual，重建新的
		if _gm.hero.has_method("remove_component") and _gm.hero.has_method("add_component"):
			_gm.hero.remove_component("visual")
			var new_visual: Node = load("res://src/entity/components/visual_component.gd").new()
			new_visual.setup({
				"color": promo.get("color", "#ffffff"),
				"size": promo.get("visual_size", 28),
			})
			_gm.hero.add_component("visual", new_visual)

		# 施放被动 spell
		var passive_spell: String = promo.get("passive_spell", "")
		if passive_spell != "":
			EngineAPI.cast_spell(passive_spell, _gm.hero, _gm.hero)

	# 更新职业名
	EngineAPI.set_variable("hero_class", _gm._promoted_class)

	# 关闭UI
	if ui and is_instance_valid(ui):
		ui.queue_free()
	# 选卡不暂停游戏

	EngineAPI.show_message(I18n.t("PROMOTION_COMPLETE", [I18n.t(promo.get("name_key", ""))]))

	# 转职升级也给卡片选择
	show_card_selection()

# === 卡片3选1 ===

func queue_card_selection() -> void:
	## 排队一次选卡（多次升级时累积）
	_pending_picks += 1
	# 只有当没有活跃的选卡UI时才立即显示
	var ui_active: bool = _gm._card_select_ui != null and is_instance_valid(_gm._card_select_ui) and _gm._card_select_ui.visible
	if not ui_active:
		_show_next_card_selection()

func _show_next_card_selection() -> void:
	## 内部：显示下一次选卡（消耗一次 _pending_picks）
	if _pending_picks <= 0:
		return
	_pending_picks -= 1
	show_card_selection()

func get_total_pending() -> int:
	## 返回总待选次数（包含当前显示的）
	var showing: int = 1 if (_gm._card_select_ui and is_instance_valid(_gm._card_select_ui)) else 0
	return _pending_picks + showing

func show_card_selection() -> void:
	var I18n: Node = _gm.I18n
	if _gm._card_manager == null:
		return
	# 防止重复创建
	if _gm._card_select_ui and is_instance_valid(_gm._card_select_ui):
		_gm._card_select_ui.queue_free()
		_gm._card_select_ui = null

	var choices: Array[Dictionary] = _gm._card_manager.draw_three()
	if choices.is_empty():
		EngineAPI.show_message("Level Up! Lv.%d (No cards available)" % _gm._hero_level)
		return

	# 不暂停游戏——卡片选择是实时的
	var ui_layer: CanvasLayer = _gm.get_tree().current_scene.get_node_or_null("UI")
	if ui_layer == null:
		return

	_gm._card_select_ui = Control.new()
	_gm._card_select_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(_gm._card_select_ui)

	# 无背景遮罩——卡片浮在画面中央偏下（不与顶栏/底部技能栏重叠）
	var center_vbox := VBoxContainer.new()
	center_vbox.anchor_left = 0.5
	center_vbox.anchor_right = 0.5
	center_vbox.anchor_top = 0.5
	center_vbox.anchor_bottom = 0.5
	center_vbox.offset_left = -420
	center_vbox.offset_right = 420
	center_vbox.offset_top = -50
	center_vbox.offset_bottom = 280
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 15)
	_gm._card_select_ui.add_child(center_vbox)

	# 标题（显示剩余选卡次数）
	var title := Label.new()
	var pending_text: String = ""
	if _pending_picks > 0:
		pending_text = " [+%d]" % _pending_picks
	title.text = I18n.t("LEVEL_UP", [_gm._hero_level]) + " - " + I18n.t("CHOOSE_CARD") + pending_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	center_vbox.add_child(title)

	# 卡片数量提示
	var slot_hint := Label.new()
	slot_hint.text = I18n.t("CARDS_COUNT", [_gm._card_manager.get_card_count(), RogueCardManager.MAX_CARDS])
	slot_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_hint.add_theme_font_size_override("font_size", 14)
	slot_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	center_vbox.add_child(slot_hint)

	# 3张卡片
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_child(hbox)

	var is_full: bool = _gm._card_manager.is_full()
	for card in choices:
		var card_btn := _create_card_button(card, is_full)
		hbox.add_child(card_btn)

	# 卡满时：显示当前持有卡片 + 替换提示
	if is_full:
		var replace_hint := Label.new()
		replace_hint.text = I18n.t("CARDS_FULL_HINT")
		replace_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		replace_hint.add_theme_font_size_override("font_size", 13)
		replace_hint.add_theme_color_override("font_color", Color(1, 0.6, 0.3))
		center_vbox.add_child(replace_hint)

		# 显示当前持有的卡片供替换
		var held_hbox := HBoxContainer.new()
		held_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		held_hbox.add_theme_constant_override("separation", 8)
		center_vbox.add_child(held_hbox)

		var held_cards: Array[String] = _gm._card_manager.get_held_cards()
		for held_id in held_cards:
			var held_data: Dictionary = _gm._card_manager.get_card_data(held_id)
			var held_btn := Button.new()
			var held_name_key: String = held_data.get("name_key", held_id)
			held_btn.text = "X " + I18n.t(held_name_key)
			held_btn.add_theme_font_size_override("font_size", 11)
			held_btn.custom_minimum_size = Vector2(100, 30)
			held_btn.name = "HeldCard_%s" % held_id
			held_hbox.add_child(held_btn)

	# 底部操作栏
	var action_hbox := HBoxContainer.new()
	action_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_hbox.add_theme_constant_override("separation", 20)
	center_vbox.add_child(action_hbox)

	# 刷新按钮
	if _gm._card_refreshes > 0:
		var refresh_btn := Button.new()
		refresh_btn.text = I18n.t("REFRESH") + " (%d)" % _gm._card_refreshes
		refresh_btn.custom_minimum_size = Vector2(140, 35)
		refresh_btn.pressed.connect(_on_card_refresh)
		action_hbox.add_child(refresh_btn)

	# 跳过按钮（跳过获得+1刷新）
	var skip_btn := Button.new()
	skip_btn.text = I18n.t("SKIP") + " (+1 " + I18n.t("REFRESH") + ")"
	skip_btn.custom_minimum_size = Vector2(180, 35)
	skip_btn.pressed.connect(_on_card_skipped)
	action_hbox.add_child(skip_btn)

	# 暂时隐藏按钮（继续游戏，稍后再选）
	var hide_btn := Button.new()
	hide_btn.text = I18n.t("HIDE_CARDS")
	hide_btn.custom_minimum_size = Vector2(140, 35)
	hide_btn.pressed.connect(_on_hide_cards)
	action_hbox.add_child(hide_btn)

func _on_hide_cards() -> void:
	## 暂时隐藏选卡界面，恢复游戏
	if _gm._card_select_ui and is_instance_valid(_gm._card_select_ui):
		_gm._card_select_ui.visible = false
		# 选卡不暂停游戏

func show_pending_cards() -> void:
	## 恢复显示隐藏的选卡界面，重新暂停
	if _gm._card_select_ui and is_instance_valid(_gm._card_select_ui):
		_gm._card_select_ui.visible = true
		# 选卡不暂停游戏

func has_pending_cards() -> bool:
	return _gm._card_select_ui != null and is_instance_valid(_gm._card_select_ui) and not _gm._card_select_ui.visible

func _on_card_skipped() -> void:
	_pending_card_id = ""
	_gm._card_refreshes += 1
	if _gm._card_select_ui:
		_gm._card_select_ui.queue_free()
		_gm._card_select_ui = null
	# 处理下一次待选
	_show_next_card_selection()

func _on_card_refresh() -> void:
	## 消耗1次刷新，重新抽3张
	if _gm._card_refreshes <= 0:
		return
	_gm._card_refreshes -= 1
	if _gm._card_select_ui:
		_gm._card_select_ui.queue_free()
		_gm._card_select_ui = null
	show_card_selection()

func _connect_replace_buttons(node: Node) -> void:
	if node.name.begins_with("HeldCard_"):
		var held_id: String = node.name.substr(9)  # "HeldCard_xxx" -> "xxx"
		if not node.is_connected("pressed", _on_replace_card):
			node.pressed.connect(_on_replace_card.bind(held_id))
	for child in node.get_children():
		_connect_replace_buttons(child)

func _on_replace_card(replace_id: String) -> void:
	if _pending_card_id == "" or _gm._card_manager == null:
		return
	var I18n: Node = _gm.I18n
	# 移除旧卡
	_gm._card_manager.remove_card(replace_id)
	# 添加新卡
	var result: Dictionary = _gm._card_manager.select_card(_pending_card_id)
	var card_data: Dictionary = _gm._card_manager.get_card_data(_pending_card_id)
	_apply_card_effects(card_data)

	if result.get("set_completed", "") != "":
		var set_id: String = result["set_completed"]
		var set_data: Dictionary = _gm._card_manager.get_set_data(set_id)
		_apply_set_bonus(set_data)
		EngineAPI.show_message(I18n.t("SET_COMPLETE", [I18n.t("SET_" + set_id.to_upper())]))
	else:
		var name_key: String = card_data.get("name_key", _pending_card_id)
		EngineAPI.show_message(I18n.t("LEVEL_UP", [_gm._hero_level]) + ": " + I18n.t(name_key))

	# 检查主题羁绊
	if _gm._theme_bond_module:
		_gm._theme_bond_module.check_bonds()

	var selected_id: String = _pending_card_id
	_pending_card_id = ""
	if _gm._card_select_ui:
		_gm._card_select_ui.queue_free()
		_gm._card_select_ui = null

	_gm.emit("card_selected", {"card_id": selected_id, "level": _gm._hero_level})
	# 处理下一次待选
	_show_next_card_selection()

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon": return Color(0.0, 0.44, 0.87)
		"rare": return Color(0.64, 0.21, 0.93)
		"legendary": return Color(1.0, 0.5, 0.0)
		_: return Color(0.85, 0.85, 0.85)

func _create_card_button(card: Dictionary, _is_full: bool = false) -> Button:
	var I18n: Node = _gm.I18n
	var card_id: String = card.get("id", "")
	var rarity: String = card.get("rarity", "common")
	var rc: Color = _rarity_color(rarity)
	# 中等亮度边框（比已激活套装稍暗）
	var border_col: Color = Color(rc.r * 0.7, rc.g * 0.7, rc.b * 0.7, 0.9)

	var panel := Button.new()
	panel.custom_minimum_size = Vector2(240, 260)
	panel.focus_mode = Control.FOCUS_ALL
	# 统一卡片风格
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.05, 0.14, 0.95)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_color = border_col
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.shadow_color = Color(border_col.r, border_col.g, border_col.b, 0.2)
	style.shadow_size = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("normal", style)
	# Hover: 亮边框
	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.border_color = rc
	hover_style.shadow_color = Color(rc.r, rc.g, rc.b, 0.4)
	hover_style.shadow_size = 6
	panel.add_theme_stylebox_override("hover", hover_style)

	panel.pressed.connect(_on_card_picked.bind(card_id))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	# 卡名
	var name_label := Label.new()
	var name_key: String = card.get("name_key", card.get("name", "???"))
	name_label.text = I18n.t(name_key) if name_key.begins_with("CARD_") else name_key
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", rc)
	vbox.add_child(name_label)

	# 稀有度
	var rarity_label := Label.new()
	rarity_label.text = I18n.t(rarity.to_upper())
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 10)
	rarity_label.add_theme_color_override("font_color", Color(rc.r * 0.6, rc.g * 0.6, rc.b * 0.6))
	vbox.add_child(rarity_label)

	# 分隔线
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(border_col.r, border_col.g, border_col.b, 0.3)
	vbox.add_child(sep)

	# 描述
	var desc_label := Label.new()
	var card_desc_text: String = ""
	if _gm and _gm.get("_card_sys") and _gm._card_sys:
		card_desc_text = _gm._card_sys.get_card_desc(card)
	if card_desc_text == "":
		var desc_key: String = card.get("desc_key", card.get("description", ""))
		card_desc_text = I18n.t(desc_key) if desc_key.begins_with("CARD_") else desc_key
	desc_label.text = card_desc_text
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(200, 0)
	vbox.add_child(desc_label)

	# 具体数值（从 spell 提取）
	var card_spell_id: String = card.get("spell_id", "")
	if card_spell_id != "":
		var detail_text: String = _gm._combat_log_module.get_spell_detail_text(card_spell_id)
		if detail_text != "":
			var detail_lbl := Label.new()
			detail_lbl.text = detail_text
			detail_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			detail_lbl.add_theme_font_size_override("font_size", 10)
			detail_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
			detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			detail_lbl.custom_minimum_size = Vector2(220, 0)
			vbox.add_child(detail_lbl)

	# 套装归属
	var set_id: String = card.get("set_id", "")
	if set_id != "" and _gm._card_manager:
		var set_data: Dictionary = _gm._card_manager.get_set_data(set_id)
		var set_tr_key := "SET_%s" % set_id.to_upper()
		var held: Array[String] = _gm._card_manager.get_held_cards()
		var set_cards: Array = set_data.get("cards", [])
		var owned := 0
		for sc in set_cards:
			if str(sc) in held:
				owned += 1
		var sep2 := ColorRect.new()
		sep2.custom_minimum_size = Vector2(0, 1)
		sep2.color = Color(0.3, 0.3, 0.4, 0.3)
		vbox.add_child(sep2)
		var set_lbl := Label.new()
		set_lbl.text = "[%s] %d/%d" % [I18n.t(set_tr_key), owned, set_cards.size()]
		set_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		set_lbl.add_theme_font_size_override("font_size", 10)
		set_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7))
		vbox.add_child(set_lbl)

	return panel

func _on_card_picked(card_id: String) -> void:
	var I18n: Node = _gm.I18n
	if _gm._card_manager == null:
		return
	# 卡满时：先选中新卡，然后需要点击已持有的卡来替换
	if _gm._card_manager.is_full():
		_pending_card_id = card_id
		# 连接持有卡的替换按钮
		if _gm._card_select_ui:
			for node in _gm._card_select_ui.get_children():
				_connect_replace_buttons(node)
		return

	var result: Dictionary = _gm._card_manager.select_card(card_id)
	var card_data: Dictionary = _gm._card_manager.get_card_data(card_id)

	# 应用卡片效果
	_apply_card_effects(card_data)

	if result.get("set_completed", "") != "":
		var set_id: String = result["set_completed"]
		var set_data: Dictionary = _gm._card_manager.get_set_data(set_id)
		_apply_set_bonus(set_data)
		EngineAPI.show_message(I18n.t("SET_COMPLETE", [I18n.t("SET_" + set_id.to_upper())]))
	else:
		var msg_name_key: String = card_data.get("name_key", card_id)
		EngineAPI.show_message(I18n.t("LEVEL_UP", [_gm._hero_level]) + ": " + I18n.t(msg_name_key))

	# 检查主题羁绊
	if _gm._theme_bond_module:
		_gm._theme_bond_module.check_bonds()

	# 关闭选卡UI，恢复游戏
	if _gm._card_select_ui:
		_gm._card_select_ui.queue_free()
		_gm._card_select_ui = null

	_gm.emit("card_selected", {"card_id": card_id, "level": _gm._hero_level})
	# 处理下一次待选
	_show_next_card_selection()

func _apply_card_effects(card: Dictionary) -> void:
	## 通过 SpellSystem 施放卡片对应的 spell
	if _gm.hero == null or not is_instance_valid(_gm.hero):
		return
	var spell_id: String = card.get("spell_id", "")
	if spell_id != "":
		EngineAPI.cast_spell(spell_id, _gm.hero, _gm.hero)
		print("[Cards] Cast spell: %s (from card %s)" % [spell_id, card.get("id", "")])
	else:
		# 兼容旧格式：直接读 effects 数组存入变量
		var effects: Array = card.get("effects", [])
		for effect in effects:
			if not effect is Dictionary:
				continue
			var stat: String = effect.get("stat", "")
			var value: float = effect.get("value", 0.0)
			var var_key := "hero_" + stat
			var current: float = float(EngineAPI.get_variable(var_key, 0.0))
			EngineAPI.set_variable(var_key, current + value)
			# 攻速特殊处理
			if stat == "attack_speed_pct":
				var input_comp: Node = EngineAPI.get_component(_gm.hero, "player_input")
				if input_comp:
					input_comp.shoot_cooldown *= (1.0 / (1.0 + value))
		print("[Cards] Applied legacy effects from: %s" % card.get("id", ""))

func _apply_set_bonus(set_data: Dictionary) -> void:
	## 通过 SpellSystem 施放套装 bonus spell
	if _gm.hero == null or not is_instance_valid(_gm.hero):
		return
	var bonus_spell: String = set_data.get("bonus_spell", "")
	if bonus_spell != "":
		EngineAPI.cast_spell(bonus_spell, _gm.hero, _gm.hero)
		print("[Cards] Set bonus spell: %s (set %s)" % [bonus_spell, set_data.get("id", "")])
	else:
		# 兼容旧格式：直接读 set_bonus 存入变量
		var bonus: Dictionary = set_data.get("set_bonus", {})
		var btype: String = bonus.get("type", "")
		if btype == "stat_mod":
			var stats: Dictionary = bonus.get("stats", {})
			for stat_name in stats:
				EngineAPI.add_green_percent(_gm.hero, stat_name, float(stats[stat_name]))
		else:
			# 通用：把 bonus 的所有数值键存入 hero_ 变量
			for key in bonus:
				if key == "type":
					continue
				EngineAPI.set_variable("hero_" + key, bonus[key])
		print("[Cards] Set bonus (legacy): %s (%s)" % [set_data.get("id", ""), btype])
