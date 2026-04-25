## InventoryPanel — 可复用的网格式背包 UI 面板（框架层）
## 纯代码创建，GamePack 实例化后挂到 UI 层即可
## 监听 "inventory_changed" 自动刷新，点击格子 emit 事件供 GamePack 处理
class_name InventoryPanel
extends PanelContainer

var _entity: Node3D = null
var _grid: GridContainer = null
var _slots: Array = []  # Array[PanelContainer]
var _capacity: int = 20
var _columns: int = 5
var _title_label: Label = null
var _is_built: bool = false

const SLOT_SIZE := Vector2(48, 48)

# 稀有度颜色
const RARITY_COLORS := {
	"common": Color(0.5, 0.5, 0.5),
	"uncommon": Color(0.3, 0.85, 0.3),
	"rare": Color(0.3, 0.5, 1.0),
	"epic": Color(0.65, 0.3, 0.9),
	"legendary": Color(1.0, 0.6, 0.15),
}

func setup(entity: Node3D, columns: int = 5) -> void:
	_entity = entity
	_columns = columns
	var item_sys: Node = EngineAPI.get_system("item")
	if item_sys:
		_capacity = item_sys.call("inventory_capacity", entity)
	_build_ui()
	EventBus.connect_event("inventory_changed", _on_inventory_changed)
	refresh()

func _build_ui() -> void:
	if _is_built:
		return
	_is_built = true
	# 面板样式
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.12, 0.95)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_color = Color(0.3, 0.3, 0.5, 0.6)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# 标题栏
	var header := HBoxContainer.new()
	vbox.add_child(header)
	_title_label = Label.new()
	_title_label.text = I18n.t("INVENTORY_TITLE") if Engine.get_main_loop() else "Inventory"
	_title_label.add_theme_font_size_override("font_size", 13)
	_title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.pressed.connect(func() -> void: visible = false)
	header.add_child(close_btn)

	# 格子网格
	_grid = GridContainer.new()
	_grid.columns = _columns
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	vbox.add_child(_grid)

	# 创建格子
	_slots.clear()
	for i in range(_capacity):
		var slot := _create_slot(i)
		_grid.add_child(slot)
		_slots.append(slot)

func _create_slot(index: int) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = SLOT_SIZE
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.1, 0.1, 0.18, 0.8)
	ss.corner_radius_top_left = 3
	ss.corner_radius_top_right = 3
	ss.corner_radius_bottom_left = 3
	ss.corner_radius_bottom_right = 3
	ss.border_color = Color(0.25, 0.25, 0.35, 0.5)
	ss.border_width_top = 1
	ss.border_width_bottom = 1
	ss.border_width_left = 1
	ss.border_width_right = 1
	ss.content_margin_left = 2
	ss.content_margin_right = 2
	ss.content_margin_top = 2
	ss.content_margin_bottom = 2
	slot.add_theme_stylebox_override("panel", ss)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_child(vb)

	# 稀有度颜色指示条
	var color_bar := ColorRect.new()
	color_bar.custom_minimum_size = Vector2(0, 3)
	color_bar.color = Color(0.15, 0.15, 0.2, 0.5)
	color_bar.name = "ColorBar"
	vb.add_child(color_bar)

	# 物品名
	var name_lbl := Label.new()
	name_lbl.text = ""
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 8)
	name_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.custom_minimum_size = Vector2(40, 30)
	name_lbl.name = "NameLabel"
	vb.add_child(name_lbl)

	# 点击事件
	slot.gui_input.connect(_on_slot_input.bind(index))
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return slot

func refresh() -> void:
	if _entity == null or not is_instance_valid(_entity):
		return
	var items: Array = EngineAPI.inventory_get(_entity)
	var item_sys: Node = EngineAPI.get_system("item")
	for i in range(_slots.size()):
		var slot: PanelContainer = _slots[i]
		var color_bar: ColorRect = slot.get_node("VBoxContainer/ColorBar") if slot.has_node("VBoxContainer/ColorBar") else null
		var name_lbl: Label = slot.get_node("VBoxContainer/NameLabel") if slot.has_node("VBoxContainer/NameLabel") else null
		if i < items.size() and not items[i].is_empty():
			var item: Dictionary = items[i]
			var r: String = item.get("def", {}).get("rarity", "common")
			var col: Color = RARITY_COLORS.get(r, Color.GRAY)
			if color_bar:
				color_bar.color = col
			if name_lbl and item_sys:
				name_lbl.text = item_sys.call("get_item_display_name", item)
				name_lbl.add_theme_color_override("font_color", col)
			# Tooltip
			if item_sys:
				slot.tooltip_text = item_sys.call("get_item_tooltip", item)
			else:
				slot.tooltip_text = ""
		else:
			if color_bar:
				color_bar.color = Color(0.15, 0.15, 0.2, 0.5)
			if name_lbl:
				name_lbl.text = ""
				name_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			slot.tooltip_text = ""
	# 更新标题计数
	if _title_label:
		var count: int = items.size()
		var title_text: String = I18n.t("INVENTORY_TITLE") if Engine.get_main_loop() else "Inventory"
		_title_label.text = "%s (%d/%d)" % [title_text, count, _capacity]

func toggle() -> void:
	visible = not visible
	if visible:
		refresh()

func _on_slot_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		var items: Array = EngineAPI.inventory_get(_entity)
		if index >= items.size() or items[index].is_empty():
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			EventBus.emit_event("inventory_slot_clicked", {
				"entity": _entity, "index": index, "item": items[index],
			})
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# 右键快速装备
			_quick_equip(index, items[index])

func _quick_equip(index: int, item: Dictionary) -> void:
	var item_type: String = item.get("def", {}).get("type", "")
	var slot := ""
	match item_type:
		"weapon": slot = "weapon"
		"armor": slot = "armor"
		"accessory":
			# 找第一个空槽
			var equipped: Dictionary = EngineAPI.get_equipped(_entity)
			for s in ["accessory_1", "accessory_2", "accessory_3", "accessory_4"]:
				if not equipped.has(s):
					slot = s
					break
			if slot == "":
				slot = "accessory_1"  # 全满则替换第一个
	if slot != "":
		var item_sys: Node = EngineAPI.get_system("item")
		if item_sys:
			item_sys.call("inventory_equip_from", _entity, index, slot)

func _on_inventory_changed(data: Dictionary) -> void:
	var entity = data.get("entity")
	if entity == _entity:
		refresh()
