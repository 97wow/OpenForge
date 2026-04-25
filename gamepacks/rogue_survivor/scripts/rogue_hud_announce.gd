## RogueHudAnnounce — 左侧公告文本（渐隐消失）
extends RefCounted

var _container: VBoxContainer = null
var _entries: Array[Dictionary] = []  # {label: Node, timer: float}

func create(ui_layer: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.125; panel.anchor_right = 0.4  # 左起 1/8 处
	panel.anchor_top = 0.2; panel.anchor_bottom = 0.5
	panel.offset_left = 0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(panel)

	_container = VBoxContainer.new()
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.add_theme_constant_override("separation", 3)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.alignment = BoxContainer.ALIGNMENT_END
	panel.add_child(_container)

func add(msg: String, color: Color = Color(0.85, 0.85, 0.9)) -> void:
	if _container == null or not is_instance_valid(_container):
		return
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.scroll_active = false
	lbl.fit_content = true
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("normal_font_size", 12)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = "[color=#%s]%s[/color]" % [color.to_html(false), msg]
	_container.add_child(lbl)
	_entries.append({"label": lbl, "timer": 5.0})
	while _entries.size() > 6:
		var old: Dictionary = _entries[0]; _entries.remove_at(0)
		if is_instance_valid(old["label"]): (old["label"] as Node).queue_free()

func update(delta: float) -> void:
	var to_remove: Array[int] = []
	for i in range(_entries.size()):
		var e: Dictionary = _entries[i]
		e["timer"] -= delta
		var t: float = e["timer"]
		var lbl: Node = e["label"]
		if not is_instance_valid(lbl):
			to_remove.append(i); continue
		if t <= 0:
			to_remove.append(i); (lbl as CanvasItem).queue_free()
		elif t < 1.0:
			(lbl as CanvasItem).modulate.a = t
	to_remove.reverse()
	for idx in to_remove:
		_entries.remove_at(idx)
