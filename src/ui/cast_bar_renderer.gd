## CastBarRenderer — 施法进度条 + 引导连接线 + 弹道渲染（框架层）
## 监听 SpellSystem 事件自动创建/销毁视觉效果
## 施法条在屏幕底部居中（对标 WoW CastBar）
extends Node

var _cast_bar_ui: Control = null  # 屏幕底部施法条
var _fill_rect: ColorRect = null
var _cast_label: Label = null
var _cast_tween: Tween = null
var _active_beams: Dictionary = {}  # caster_id → {mesh, mat, caster, target, remaining}
var _is_channeling: bool = false

func _ready() -> void:
	EventBus.connect_event("spell_cast_start", _on_cast_start)
	EventBus.connect_event("spell_channel_start", _on_channel_start)
	EventBus.connect_event("spell_channel_tick", _on_channel_tick)
	EventBus.connect_event("spell_cast", _on_cast_complete)
	EventBus.connect_event("spell_interrupted", _on_cast_interrupted)

# === 屏幕施法条（底部居中）===

func _ensure_cast_bar() -> void:
	if _cast_bar_ui and is_instance_valid(_cast_bar_ui):
		return
	# 创建 CanvasLayer 确保在最上层
	var canvas := CanvasLayer.new()
	canvas.layer = 90
	canvas.name = "CastBarLayer"
	add_child(canvas)

	_cast_bar_ui = Control.new()
	_cast_bar_ui.name = "CastBarUI"
	_cast_bar_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cast_bar_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cast_bar_ui.visible = false
	canvas.add_child(_cast_bar_ui)

	# 背景框
	var bg := PanelContainer.new()
	bg.anchor_left = 0.5
	bg.anchor_right = 0.5
	bg.anchor_top = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_left = -160
	bg.offset_right = 160
	bg.offset_top = -120
	bg.offset_bottom = -88
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.9)
	style.border_color = Color(0.3, 0.3, 0.5, 0.8)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	bg.add_theme_stylebox_override("panel", style)
	_cast_bar_ui.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	bg.add_child(vbox)

	# 技能名
	_cast_label = Label.new()
	_cast_label.text = ""
	_cast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cast_label.add_theme_font_size_override("font_size", 12)
	_cast_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	vbox.add_child(_cast_label)

	# 进度条背景
	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(300, 12)
	bar_bg.color = Color(0.1, 0.1, 0.15, 0.9)
	vbox.add_child(bar_bg)

	# 进度条填充
	_fill_rect = ColorRect.new()
	_fill_rect.size = Vector2(0, 12)
	_fill_rect.position = Vector2.ZERO
	_fill_rect.color = Color(1, 0.7, 0.2)
	bar_bg.add_child(_fill_rect)

# === 读条 ===

func _on_cast_start(data: Dictionary) -> void:
	var cast_time: float = data.get("cast_time", 1.0)
	var spell_id: String = str(data.get("spell_id", ""))
	_ensure_cast_bar()
	_is_channeling = false
	_show_bar(spell_id, cast_time, Color(1, 0.7, 0.2), false)

# === 引导 ===

func _on_channel_start(data: Dictionary) -> void:
	var caster = data.get("caster")
	var target = data.get("target")
	var channel_time: float = data.get("channel_time", 1.0)
	var spell_id: String = str(data.get("spell_id", ""))
	_ensure_cast_bar()
	_is_channeling = true
	_show_bar(spell_id, channel_time, Color(0.4, 0.7, 1.0), true)
	# 引导连接线
	if caster and is_instance_valid(caster) and caster is Node3D and target and is_instance_valid(target) and target is Node3D:
		_create_beam(caster as Node3D, target as Node3D, channel_time)

func _on_channel_tick(data: Dictionary) -> void:
	# 连接线闪烁
	var caster = data.get("caster")
	if caster == null or not is_instance_valid(caster):
		return
	var cid: int = caster.get_instance_id()
	if _active_beams.has(cid):
		var mat: StandardMaterial3D = _active_beams[cid].get("mat")
		if mat:
			mat.albedo_color = Color(0.8, 0.6, 1.0, 1.0)
			var mesh_node = _active_beams[cid].get("mesh")
			if mesh_node and is_instance_valid(mesh_node):
				var tw := mesh_node.create_tween()
				tw.tween_property(mat, "albedo_color", Color(0.5, 0.3, 0.9, 0.6), 0.25)

# === 显示施法条 ===

func _show_bar(spell_id: String, duration: float, color: Color, reverse: bool) -> void:
	if _cast_tween and is_instance_valid(_cast_tween):
		_cast_tween.kill()
	_cast_bar_ui.visible = true
	_cast_label.text = _spell_display_name(spell_id)
	_cast_label.add_theme_color_override("font_color", color)
	_fill_rect.color = color

	if reverse:
		# 引导：从满到空
		_fill_rect.size.x = 300
		_cast_tween = _fill_rect.create_tween()
		_cast_tween.tween_property(_fill_rect, "size:x", 0.0, duration)
		_cast_tween.tween_callback(_hide_bar)
	else:
		# 读条：从空到满
		_fill_rect.size.x = 0
		_cast_tween = _fill_rect.create_tween()
		_cast_tween.tween_property(_fill_rect, "size:x", 300.0, duration)
		_cast_tween.tween_callback(_hide_bar)

func _hide_bar() -> void:
	if _cast_bar_ui and is_instance_valid(_cast_bar_ui):
		_cast_bar_ui.visible = false
	_clear_all_beams()

# === 完成/打断 ===

func _on_cast_complete(data: Dictionary) -> void:
	var caster = data.get("caster")
	var target = data.get("target")
	_hide_bar()
	# 施法完成弹道
	if caster and is_instance_valid(caster) and caster is Node3D and target and is_instance_valid(target) and target is Node3D and target != caster:
		_spawn_projectile_vfx(caster as Node3D, target as Node3D)

func _on_cast_interrupted(data: Dictionary) -> void:
	# 变红后消失
	if _fill_rect and is_instance_valid(_fill_rect):
		_fill_rect.color = Color(1, 0.2, 0.2)
	if _cast_label and is_instance_valid(_cast_label):
		_cast_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		_cast_label.text += " - INTERRUPTED"
	if _cast_tween and is_instance_valid(_cast_tween):
		_cast_tween.kill()
	# 0.5 秒后隐藏
	get_tree().create_timer(0.5).timeout.connect(_hide_bar)

# === 引导连接线 ===

func _create_beam(caster: Node3D, target: Node3D, duration: float) -> void:
	var cid: int = caster.get_instance_id()
	_remove_beam(cid)
	var mesh_inst := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	mesh_inst.mesh = im
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.3, 0.9, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.3, 0.9)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.set_surface_override_material(0, mat)
	_rebuild_beam_mesh(im, caster.global_position, target.global_position)
	var scene_root: Node = caster.get_tree().current_scene
	if scene_root:
		scene_root.add_child(mesh_inst)
	_active_beams[cid] = {"mesh": mesh_inst, "im": im, "mat": mat, "caster": caster, "target": target, "remaining": duration}

func _rebuild_beam_mesh(im: ImmediateMesh, from: Vector3, to: Vector3) -> void:
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	im.surface_add_vertex(from + Vector3(0, 0.5, 0))
	im.surface_add_vertex(to + Vector3(0, 0.5, 0))
	im.surface_end()

func _process(delta: float) -> void:
	var remove: Array = []
	for cid in _active_beams:
		var bd: Dictionary = _active_beams[cid]
		var mesh_inst = bd.get("mesh")
		var caster = bd.get("caster")
		var target = bd.get("target")
		if not is_instance_valid(mesh_inst) or not is_instance_valid(caster):
			remove.append(cid)
			continue
		bd["remaining"] -= delta
		if bd["remaining"] <= 0 or (target != null and not is_instance_valid(target)):
			remove.append(cid)
			continue
		var im: ImmediateMesh = bd.get("im")
		if im:
			var t_pos: Vector3 = (target as Node3D).global_position if is_instance_valid(target) else (caster as Node3D).global_position
			_rebuild_beam_mesh(im, (caster as Node3D).global_position, t_pos)
	for cid in remove:
		_remove_beam(cid)

func _remove_beam(cid: int) -> void:
	if _active_beams.has(cid):
		var mesh = _active_beams[cid].get("mesh")
		if mesh and is_instance_valid(mesh):
			mesh.queue_free()
		_active_beams.erase(cid)

func _clear_all_beams() -> void:
	for cid in _active_beams.keys():
		_remove_beam(cid)

# === 弹道 VFX ===

func _spawn_projectile_vfx(from: Node3D, to: Node3D) -> void:
	var bullet := MeshInstance3D.new()
	bullet.global_position = from.global_position + Vector3(0, 0.5, 0)
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	bullet.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.7, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.7, 1.0)
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bullet.set_surface_override_material(0, mat)
	var scene_root: Node = from.get_tree().current_scene
	if scene_root:
		scene_root.add_child(bullet)
	var tw := bullet.create_tween()
	tw.tween_property(bullet, "global_position", to.global_position + Vector3(0, 0.5, 0), 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_callback(bullet.queue_free)

# === 工具 ===

func _spell_display_name(spell_id: String) -> String:
	var i18n_node: Node = Engine.get_main_loop().root.get_node_or_null("I18n") if Engine.get_main_loop() else null
	if i18n_node and i18n_node.has_method("t"):
		var key: String = "SPELL_" + spell_id.to_upper()
		var result: String = i18n_node.call("t", key)
		if result != key:
			return result
	return spell_id.replace("test_", "").replace("_", " ").capitalize()
