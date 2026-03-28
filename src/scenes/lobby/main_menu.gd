## 主菜单 - 游戏大厅
extends Control

@onready var play_btn: Button = $CenterPanel/VBox/PlayButton
@onready var collection_btn: Button = $CenterPanel/VBox/CollectionButton
@onready var leaderboard_btn: Button = $CenterPanel/VBox/LeaderboardButton
@onready var settings_btn: Button = $CenterPanel/VBox/SettingsButton
@onready var quit_btn: Button = $CenterPanel/VBox/QuitButton

func _ready() -> void:
	play_btn.pressed.connect(_on_play)
	collection_btn.pressed.connect(_on_collection)
	leaderboard_btn.pressed.connect(_on_leaderboard)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	play_btn.grab_focus()

func _on_play() -> void:
	SceneManager.goto_scene("map_select")

func _on_collection() -> void:
	# TODO: 卡片收藏页面
	print("[Menu] Collection - coming soon")

func _on_leaderboard() -> void:
	# TODO: 排行榜页面
	print("[Menu] Leaderboard - coming soon")

func _on_settings() -> void:
	# TODO: 设置页面
	print("[Menu] Settings - coming soon")

func _on_quit() -> void:
	get_tree().quit()
