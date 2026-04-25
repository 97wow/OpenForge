## 主菜单 - 游戏大厅
extends Control

const LANGUAGES := [
	{"code": "en", "label": "English"},
	{"code": "zh_CN", "label": "中文"},
	{"code": "ja", "label": "日本語"},
	{"code": "ko", "label": "한국어"},
]

@onready var play_btn: Button = $CenterPanel/VBox/PlayButton
@onready var collection_btn: Button = $CenterPanel/VBox/CollectionButton
@onready var battle_pass_btn: Button = $CenterPanel/VBox/BattlePassButton
@onready var leaderboard_btn: Button = $CenterPanel/VBox/LeaderboardButton
@onready var settings_btn: Button = $CenterPanel/VBox/SettingsButton
@onready var quit_btn: Button = $CenterPanel/VBox/QuitButton

var _settings_panel: Control = null

func _ready() -> void:
	# 多语言文本
	$TitleLabel.text = I18n.t("GAME_TITLE")
	$VersionLabel.text = I18n.t("VERSION", [ProjectSettings.get_setting("application/config/version", "0.1.0")])
	play_btn.text = I18n.t("START_GAME")
	collection_btn.text = I18n.t("COLLECTION")
	battle_pass_btn.text = I18n.t("SEASON_BATTLE_PASS")
	leaderboard_btn.text = I18n.t("LEADERBOARD")
	settings_btn.text = I18n.t("SETTINGS")
	quit_btn.text = I18n.t("QUIT")

	play_btn.pressed.connect(_on_play)
	collection_btn.pressed.connect(_on_collection)
	battle_pass_btn.pressed.connect(_on_battle_pass)
	leaderboard_btn.pressed.connect(_on_leaderboard)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	play_btn.grab_focus()

func _on_play() -> void:
	SceneManager.goto_scene("map_select")

func _on_collection() -> void:
	SceneManager.goto_scene("talents")

func _on_battle_pass() -> void:
	SceneManager.goto_scene("battle_pass")

func _on_leaderboard() -> void:
	SceneManager.goto_scene("leaderboard")

func _on_settings() -> void:
	if _settings_panel:
		return
	_settings_panel = Control.new()
	_settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_settings_panel)

	# 半透明背景
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_panel.add_child(overlay)

	# 设置面板
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 15)
	_settings_panel.add_child(vbox)

	var title := Label.new()
	title.text = I18n.t("SETTINGS")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	# 语言选择
	var lang_label := Label.new()
	lang_label.text = I18n.t("LANGUAGE")
	lang_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lang_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lang_label)

	var lang_hbox := HBoxContainer.new()
	lang_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	lang_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(lang_hbox)

	var current_locale := I18n.get_locale()
	for lang in LANGUAGES:
		var btn := Button.new()
		btn.text = lang["label"]
		btn.custom_minimum_size = Vector2(120, 40)
		if current_locale.begins_with(lang["code"]):
			btn.disabled = true
		btn.pressed.connect(_on_language_selected.bind(lang["code"]))
		lang_hbox.add_child(btn)

	# 关闭按钮
	var close_btn := Button.new()
	close_btn.text = I18n.t("BACK")
	close_btn.custom_minimum_size = Vector2(160, 40)
	close_btn.pressed.connect(_close_settings)
	vbox.add_child(close_btn)

func _on_language_selected(locale: String) -> void:
	I18n.set_locale(locale)
	_close_settings()
	SceneManager.goto_scene_instant("lobby")

func _close_settings() -> void:
	if _settings_panel:
		_settings_panel.queue_free()
		_settings_panel = null

func _on_quit() -> void:
	get_tree().quit()
