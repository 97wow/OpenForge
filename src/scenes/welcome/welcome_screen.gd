## 欢迎页 - 游戏启动Logo + 按任意键继续
extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $VBoxContainer/SubtitleLabel
@onready var hint_label: Label = $VBoxContainer/HintLabel

var _can_proceed: bool = false

func _ready() -> void:
	# 多语言文本
	title_label.text = I18n.t("GAME_TITLE")
	subtitle_label.text = I18n.t("CREATE_PLAY_SHARE")
	hint_label.text = I18n.t("PRESS_ANY_KEY")
	# 淡入动画
	modulate.a = 0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.0)
	await tween.finished
	# 闪烁提示
	_can_proceed = true
	_blink_hint()

func _blink_hint() -> void:
	while is_inside_tree():
		var tween := create_tween()
		tween.tween_property(hint_label, "modulate:a", 0.3, 0.8)
		tween.tween_property(hint_label, "modulate:a", 1.0, 0.8)
		await tween.finished

func _input(event: InputEvent) -> void:
	if not _can_proceed:
		return
	if event is InputEventKey or event is InputEventMouseButton:
		if event.pressed:
			_can_proceed = false
			SceneManager.goto_scene("lobby")
