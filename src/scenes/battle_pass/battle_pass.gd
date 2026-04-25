## 战令UI场景 - 等级进度、任务列表、奖励预览
extends Control

# 节点引用
@onready var title_label: Label = $VBox/Header/TitleLabel
@onready var season_label: Label = $VBox/Header/SeasonLabel
@onready var back_btn: Button = $VBox/Header/BackButton

@onready var level_label: Label = $VBox/ProgressSection/LevelLabel
@onready var xp_bar: ProgressBar = $VBox/ProgressSection/XPBar
@onready var xp_label: Label = $VBox/ProgressSection/XPLabel
@onready var days_label: Label = $VBox/ProgressSection/DaysLabel

@onready var tab_bar: HBoxContainer = $VBox/TabBar
@onready var quest_tab_btn: Button = $VBox/TabBar/QuestTabButton
@onready var reward_tab_btn: Button = $VBox/TabBar/RewardTabButton

@onready var content_panel: PanelContainer = $VBox/ContentPanel
@onready var quest_scroll: ScrollContainer = $VBox/ContentPanel/QuestScroll
@onready var quest_list: VBoxContainer = $VBox/ContentPanel/QuestScroll/QuestList
@onready var reward_scroll: ScrollContainer = $VBox/ContentPanel/RewardScroll
@onready var reward_list: VBoxContainer = $VBox/ContentPanel/RewardScroll/RewardList

@onready var premium_btn: Button = $VBox/PremiumSection/PremiumButton
@onready var premium_label: Label = $VBox/PremiumSection/PremiumLabel

var _season: Node = null

func _ready() -> void:
	_season = get_node_or_null("/root/SeasonSystem")

	# 设置多语言文本
	title_label.text = I18n.t("SEASON_BATTLE_PASS")
	back_btn.text = I18n.t("BACK")
	quest_tab_btn.text = I18n.t("SEASON_TAB_QUESTS")
	reward_tab_btn.text = I18n.t("SEASON_TAB_REWARDS")

	back_btn.pressed.connect(_on_back)
	quest_tab_btn.pressed.connect(_show_quests)
	reward_tab_btn.pressed.connect(_show_rewards)
	premium_btn.pressed.connect(_on_premium)

	_update_header()
	_update_premium_section()
	_show_quests()
	back_btn.grab_focus()

# === 头部信息 ===

func _update_header() -> void:
	if _season == null:
		return
	var display_lv: int = _season.get_display_level()
	level_label.text = I18n.t("SEASON_LEVEL", [display_lv])

	var max_lv: int = _season.max_level
	var current_xp: int = _season.xp
	var xp_needed: int = _season.xp_per_level
	if _season.level >= max_lv:
		xp_bar.value = 100.0
		xp_label.text = I18n.t("SEASON_MAX_LEVEL")
	else:
		xp_bar.value = _season.get_xp_progress() * 100.0
		xp_label.text = "%d / %d XP" % [current_xp, xp_needed]

	var days_left: int = _season.get_remaining_days()
	days_label.text = I18n.t("SEASON_DAYS_LEFT", [days_left])

	# 赛季名称
	var season_name_key: String = _season.season_name
	if season_name_key != "":
		season_label.text = I18n.t(season_name_key)
	else:
		season_label.text = ""

# === Tab 切换 ===

func _show_quests() -> void:
	quest_scroll.visible = true
	reward_scroll.visible = false
	quest_tab_btn.disabled = true
	reward_tab_btn.disabled = false
	_build_quest_list()

func _show_rewards() -> void:
	quest_scroll.visible = false
	reward_scroll.visible = true
	quest_tab_btn.disabled = false
	reward_tab_btn.disabled = true
	_build_reward_list()

# === 任务列表 ===

func _build_quest_list() -> void:
	# 清空旧内容
	for child in quest_list.get_children():
		child.queue_free()

	if _season == null:
		return

	# 每日任务标题
	_add_section_label(quest_list, I18n.t("SEASON_DAILY_QUESTS"))
	for q in _season.daily_quests:
		_add_quest_item(quest_list, q)

	# 分隔
	_add_separator(quest_list)

	# 每周任务标题
	_add_section_label(quest_list, I18n.t("SEASON_WEEKLY_QUESTS"))
	for q in _season.weekly_quests:
		_add_quest_item(quest_list, q)

func _add_quest_item(parent: VBoxContainer, quest: Dictionary) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	# 任务名称
	var name_label := Label.new()
	var name_key: String = quest.get("name_key", "???")
	name_label.text = I18n.t(name_key)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(name_label)

	# 进度
	var qid: String = quest.get("id", "")
	var target: int = quest.get("target", 1)
	var current: int = _season.quest_progress.get(qid, 0)
	var progress_label := Label.new()
	progress_label.text = "%d / %d" % [current, target]
	progress_label.add_theme_font_size_override("font_size", 14)
	progress_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	hbox.add_child(progress_label)

	# 经验奖励
	var xp_lbl := Label.new()
	xp_lbl.text = "+%d XP" % quest.get("xp_reward", 0)
	xp_lbl.add_theme_font_size_override("font_size", 14)
	xp_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hbox.add_child(xp_lbl)

	# 领取按钮
	var claim_btn := Button.new()
	if _season.claimed_quest_ids.has(qid):
		claim_btn.text = I18n.t("SEASON_CLAIMED")
		claim_btn.disabled = true
	elif current >= target:
		claim_btn.text = I18n.t("SEASON_CLAIM")
		claim_btn.pressed.connect(_on_claim_quest.bind(qid))
	else:
		claim_btn.text = I18n.t("SEASON_IN_PROGRESS")
		claim_btn.disabled = true
	claim_btn.custom_minimum_size = Vector2(80, 30)
	hbox.add_child(claim_btn)

func _on_claim_quest(quest_id: String) -> void:
	if _season == null:
		return
	_season.claim_quest_reward(quest_id)
	_update_header()
	_build_quest_list()

# === 奖励列表 ===

func _build_reward_list() -> void:
	for child in reward_list.get_children():
		child.queue_free()

	if _season == null:
		return

	# 免费轨道
	_add_section_label(reward_list, I18n.t("SEASON_FREE_TRACK"))
	for r in _season.free_rewards:
		_add_reward_item(reward_list, r, false)

	_add_separator(reward_list)

	# 付费轨道
	_add_section_label(reward_list, I18n.t("SEASON_PREMIUM_TRACK"))
	for r in _season.premium_rewards:
		_add_reward_item(reward_list, r, true)

func _add_reward_item(parent: VBoxContainer, reward: Dictionary, is_premium_track: bool) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	# 等级（0-based 转为显示 1-based）
	var rlevel: int = reward.get("level", 0)
	var lv_label := Label.new()
	lv_label.text = I18n.t("REWARD_LV", [str(rlevel + 1)])
	lv_label.custom_minimum_size = Vector2(50, 0)
	lv_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(lv_label)

	# 奖励名称
	var rname := Label.new()
	var name_key: String = reward.get("name_key", "")
	rname.text = I18n.t(name_key) if name_key != "" else "---"
	rname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rname.add_theme_font_size_override("font_size", 14)
	hbox.add_child(rname)

	# 领取按钮
	var claim_btn := Button.new()
	var claimed_list: Array = _season.claimed_premium_rewards if is_premium_track else _season.claimed_free_rewards
	if claimed_list.has(rlevel):
		claim_btn.text = I18n.t("SEASON_CLAIMED")
		claim_btn.disabled = true
	elif rlevel > _season.level:
		claim_btn.text = I18n.t("SEASON_LOCKED")
		claim_btn.disabled = true
	elif is_premium_track and not _season.is_premium:
		claim_btn.text = I18n.t("SEASON_PREMIUM_ONLY")
		claim_btn.disabled = true
	else:
		claim_btn.text = I18n.t("SEASON_CLAIM")
		if is_premium_track:
			claim_btn.pressed.connect(_on_claim_premium_reward.bind(rlevel))
		else:
			claim_btn.pressed.connect(_on_claim_free_reward.bind(rlevel))
	claim_btn.custom_minimum_size = Vector2(100, 30)
	hbox.add_child(claim_btn)

func _on_claim_free_reward(reward_level: int) -> void:
	if _season == null:
		return
	_season.claim_free_reward(reward_level)
	_update_header()
	_build_reward_list()

func _on_claim_premium_reward(reward_level: int) -> void:
	if _season == null:
		return
	_season.claim_premium_reward(reward_level)
	_update_header()
	_build_reward_list()

# === 付费区域 ===

func _update_premium_section() -> void:
	if _season == null:
		premium_btn.visible = false
		premium_label.visible = false
		return
	if _season.is_premium:
		premium_btn.visible = false
		premium_label.text = I18n.t("SEASON_PREMIUM_ACTIVE")
		premium_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		premium_btn.visible = true
		premium_btn.text = I18n.t("SEASON_BUY_PREMIUM")
		premium_label.text = I18n.t("SEASON_PREMIUM_DESC")

func _on_premium() -> void:
	if _season == null:
		return
	_season.purchase_premium()
	_update_premium_section()
	# 如果当前在奖励页签，刷新以解锁付费轨道领取
	if reward_scroll.visible:
		_build_reward_list()

# === 工具 ===

func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(label)

func _add_separator(parent: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 12)
	parent.add_child(sep)

func _on_back() -> void:
	SceneManager.goto_scene("lobby")
