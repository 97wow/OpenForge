## RogueHudTopbar — 顶栏：左侧留空，中央波次，右侧资源
extends RefCounted

var _gm
var _gold_label: Label = null
var _wood_label: Label = null
var _kills_label: Label = null
var _wave_countdown_label: Label = null
var _mobs_label: Label = null
var _timer_label: Label = null
var _mob_count_timer: float = 0.0
var _cached_mob_count: int = 0

func create(ui_layer: CanvasLayer, I18n: Node) -> void:
	var top_panel := PanelContainer.new()
	top_panel.anchor_left = 0.0; top_panel.anchor_right = 1.0
	top_panel.anchor_top = 0.0; top_panel.anchor_bottom = 0.0
	top_panel.offset_bottom = 30
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	style.content_margin_left = 10; style.content_margin_right = 10
	style.content_margin_top = 3; style.content_margin_bottom = 3
	top_panel.add_theme_stylebox_override("panel", style)
	ui_layer.add_child(top_panel)

	# 中央：波次倒计时（绝对居中，不受左右元素影响）
	_wave_countdown_label = Label.new()
	_wave_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_countdown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wave_countdown_label.add_theme_font_size_override("font_size", 14)
	_wave_countdown_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	_wave_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel.add_child(_wave_countdown_label)

	# 右侧：资源（HBox 右对齐）
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_END
	top_panel.add_child(hbox)

	_gold_label = _lbl(hbox, I18n.t("GOLD") + ": 0", 12, Color(1, 0.85, 0.2))
	_wood_label = _lbl(hbox, I18n.t("WOOD") + ": 0", 12, Color(0.6, 0.45, 0.25))
	_kills_label = _lbl(hbox, I18n.t("KILLS") + ": 0", 12, Color(1, 0.4, 0.3))
	_mobs_label = _lbl(hbox, I18n.t("HUD_MOBS", ["0"]), 12, Color(0.8, 0.6, 0.4))
	_timer_label = _lbl(hbox, "0:00", 12)

func update(I18n: Node) -> void:
	var gold_ps: float = float(EngineAPI.get_variable("base_gold_per_sec", 0.0)) + float(EngineAPI.get_variable("hero_gold_per_sec", 0.0))
	_gold_label.text = I18n.t("GOLD") + ": %d (+%.0f/s)" % [int(EngineAPI.get_resource("gold")), gold_ps]
	if _wood_label:
		var wood_ps: float = float(EngineAPI.get_variable("base_wood_per_sec", 0.0))
		_wood_label.text = I18n.t("WOOD") + ": %d (+%.0f/s)" % [int(EngineAPI.get_resource("wood")), wood_ps]

	var kill_ps: float = float(EngineAPI.get_variable("hero_kill_per_sec", 0.0))
	_kills_label.text = I18n.t("KILLS") + ": %d" % _gm._kills + (" (+%.1f/s)" % kill_ps if kill_ps > 0 else "")

	_mob_count_timer += 0.016
	if _mob_count_timer >= 1.0:
		_mob_count_timer = 0.0
		_cached_mob_count = EngineAPI.find_entities_by_tag("enemy").size()
	_mobs_label.text = I18n.t("HUD_MOBS", [str(_cached_mob_count)])

	@warning_ignore("integer_division")
	_timer_label.text = "%d:%02d" % [int(_gm._game_timer) / 60, int(_gm._game_timer) % 60]

	if _gm._wave_system:
		var ws = _gm._wave_system
		if ws.game_completed:
			var ct: float = ws.get_remaining_time()
			@warning_ignore("INTEGER_DIVISION")
			_wave_countdown_label.text = I18n.t("GAME_TIME_UP") + " %d:%02d" % [int(ct) / 60, int(ct) % 60] if ct > 0 else I18n.t("GAME_TIME_UP")
		elif ws.wave_active:
			_wave_countdown_label.text = I18n.t("WAVE") + " %d/%d  %.0fs" % [ws.get_display_wave(), ws.get_total_waves(), ws.get_remaining_time()]
		else:
			_wave_countdown_label.text = I18n.t("WAVE") + " %d/%d" % [ws.get_display_wave(), ws.get_total_waves()]

func _lbl(parent: Node, text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text; l.add_theme_font_size_override("font_size", size)
	if color != Color.WHITE: l.add_theme_color_override("font_color", color)
	parent.add_child(l); return l
