## 排行榜 - 本地历史战绩
extends Control

const SAVE_NS := "rogue_survivor_progress"
const MAX_ENTRIES := 20

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# 标题 + 统计摘要
	var top_hbox := HBoxContainer.new()
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_theme_constant_override("separation", 40)
	vbox.add_child(top_hbox)

	var title := Label.new()
	title.text = I18n.t("LEADERBOARD")
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	top_hbox.add_child(title)

	# 总体统计
	var total_games: int = int(SaveSystem.load_data(SAVE_NS, "total_games", 0))
	var total_wins: int = int(SaveSystem.load_data(SAVE_NS, "total_wins", 0))
	var best_wave: int = int(SaveSystem.load_data(SAVE_NS, "best_wave", 0))
	var win_rate: float = (float(total_wins) / float(total_games) * 100.0) if total_games > 0 else 0.0

	var stats_label := Label.new()
	stats_label.text = "%s: %d  |  %s: %d  |  %s: %.0f%%  |  %s: %d" % [
		I18n.t("TOTAL_GAMES"), total_games,
		I18n.t("TOTAL_WINS"), total_wins,
		I18n.t("WIN_RATE"), win_rate,
		I18n.t("BEST_WAVE"), best_wave,
	]
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_hbox.add_child(stats_label)

	vbox.add_child(HSeparator.new())

	# 表头
	var header := _create_row("", I18n.t("DIFFICULTY"), "Class", I18n.t("KILLS"), "Score", "Grade", "Time", true)
	vbox.add_child(header)

	# 历史记录
	var history: Array = _load_history()
	if history.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = I18n.t("NO_RECORDS")
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 16)
		empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		vbox.add_child(empty_lbl)
	else:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		vbox.add_child(scroll)

		var list_vbox := VBoxContainer.new()
		list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list_vbox.add_theme_constant_override("separation", 2)
		scroll.add_child(list_vbox)

		for i in range(history.size()):
			var entry: Dictionary = history[i]
			var rank := str(i + 1)
			var diff_name: String = entry.get("difficulty", "N1")
			var cls_id: String = entry.get("class", "warrior")
			var kills: String = str(entry.get("kills", 0))
			var score: String = str(entry.get("score", 0))
			var grade: String = entry.get("grade", "D")
			@warning_ignore("integer_division")
			var time_mins: int = int(entry.get("time", 0)) / 60
			@warning_ignore("integer_division")
			var time_secs: int = int(entry.get("time", 0)) % 60
			var time_str := "%d:%02d" % [time_mins, time_secs]
			var is_victory: bool = entry.get("victory", false)

			var row := _create_row(rank, diff_name, _class_display(cls_id), kills, score, grade, time_str, false)
			if is_victory:
				row.modulate = Color(1, 1, 1)
			else:
				row.modulate = Color(0.6, 0.6, 0.7)
			list_vbox.add_child(row)

	# 返回按钮
	var back_btn := Button.new()
	back_btn.text = I18n.t("BACK")
	back_btn.custom_minimum_size = Vector2(140, 40)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.pressed.connect(func() -> void: SceneManager.goto_scene("lobby"))
	vbox.add_child(back_btn)

func _create_row(rank: String, diff: String, cls: String, kills: String, score: String, grade: String, time: String, is_header: bool) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var font_size := 12 if is_header else 13
	var color := Color(0.5, 0.5, 0.6) if is_header else Color(0.85, 0.85, 0.9)

	var cols: Array = [
		[rank if rank != "" else "#", 40],
		[diff, 60],
		[cls, 120],
		[kills, 60],
		[score, 60],
		[grade, 50],
		[time, 60],
	]

	for col in cols:
		var lbl := Label.new()
		lbl.text = str(col[0])
		lbl.custom_minimum_size = Vector2(col[1], 0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", font_size)
		lbl.add_theme_color_override("font_color", color)
		if is_header:
			lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		# 评分颜色
		if not is_header and col == cols[5]:  # grade column
			match grade:
				"S": lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.1))
				"A": lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
				"B": lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 1))
				"C": lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
				"D": lbl.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
		hbox.add_child(lbl)

	return hbox

func _class_display(cls: String) -> String:
	var key := cls.to_upper()
	if key.begins_with("CLASS_"):
		key = key  # already a translation key
	elif ["BERSERKER", "PALADIN", "SHADOW_DANCER", "WINDRUNNER", "ARCHMAGE", "NECROMANCER"].has(key):
		key = "CLASS_" + key
	var translated: String = I18n.t(key)
	return translated if translated != key else cls.capitalize()

func _load_history() -> Array:
	var raw: Variant = SaveSystem.load_data(SAVE_NS, "battle_history", [])
	if raw is Array:
		return raw
	return []

## 静态方法：战斗结束后记录一条
static func record_battle(data: Dictionary) -> void:
	var history: Variant = SaveSystem.load_data("rogue_survivor_progress", "battle_history", [])
	var list: Array = []
	if history is Array:
		list = history
	list.push_front(data)
	# 保留最近 MAX_ENTRIES 条
	while list.size() > MAX_ENTRIES:
		list.pop_back()
	# 按 score 降序排列
	list.sort_custom(func(a: Variant, b: Variant) -> bool:
		return (a as Dictionary).get("score", 0) > (b as Dictionary).get("score", 0)
	)
	SaveSystem.save_data("rogue_survivor_progress", "battle_history", list)
