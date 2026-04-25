## 主题羁绊系统 - 跨套装的第二层羁绊
## 从不同套装中各完成至少1套，达成条件触发额外效果
## 与现有套装系统并行，不冲突
class_name RogueThemeBond

var _gm  # 主控引用（rogue_game_mode）
var _all_bonds: Array = []          # 所有主题羁绊定义
var _activated_bonds: Array[String] = []  # 已激活的羁绊 id

func init(game_mode) -> void:
	_gm = game_mode
	_load_bonds()

func _load_bonds() -> void:
	## 从 theme_bonds.json 加载主题羁绊定义
	var path: String = _gm.pack.pack_path.path_join("theme_bonds.json")
	if not FileAccess.file_exists(path):
		print("[ThemeBond] theme_bonds.json not found at: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Array:
		_all_bonds = json.data
	print("[ThemeBond] Loaded %d theme bonds" % _all_bonds.size())

func check_bonds() -> Array[String]:
	## 检查所有主题羁绊，返回本次新激活的羁绊 id 列表
	## 每次获取卡片/完成套装后由主控调用
	var newly_activated: Array[String] = []
	if _gm == null or _gm._card_sys == null:
		return newly_activated

	for bond in _all_bonds:
		if not bond is Dictionary:
			continue
		var bond_id: String = bond.get("id", "")
		if bond_id in _activated_bonds:
			continue  # 已激活，跳过

		var required_sets: Array = bond.get("required_sets", [])
		var min_count: int = bond.get("min_count", 1)

		if _is_bond_satisfied(required_sets, min_count):
			_activated_bonds.append(bond_id)
			_apply_bond_effects(bond)
			newly_activated.append(bond_id)

	return newly_activated

func _is_bond_satisfied(required_sets: Array, min_count: int) -> bool:
	## 每个 required_sets 条目必须有 >= min_count 张持有或已吞噬的卡片匹配
	for set_id in required_sets:
		if _count_cards_in_set(str(set_id)) < min_count:
			return false
	return true

func _count_cards_in_set(set_id: String) -> int:
	## 规则：把 required_sets 条目（形如 "flame_set_bonus"）按去掉 "_set_bonus" 后缀
	## 与卡片的 subclass 字段比较。held_cards 与 consumed_cards 都计入
	## （羁绊效果在吞噬后仍然保留，与 _card_sys._activate_bond → _auto_consume_bond 一致）。
	if _gm == null or _gm._card_sys == null:
		return 0
	var key := set_id
	if key.ends_with("_set_bonus"):
		key = key.trim_suffix("_set_bonus")
	var total := 0
	for entry in _gm._card_sys.held_cards:
		var cdata: Dictionary = entry.get("data", {})
		if str(cdata.get("subclass", "")) == key:
			total += 1
	for entry in _gm._card_sys.consumed_cards:
		var cdata: Dictionary = entry.get("data", {})
		if str(cdata.get("subclass", "")) == key:
			total += 1
	return total

func _apply_bond_effects(bond: Dictionary) -> void:
	## 应用羁绊效果（仅使用 SET_VARIABLE mode:add）
	var I18n: Node = _gm.I18n
	var bond_id: String = bond.get("id", "")
	var effects: Array = bond.get("bonus_effects", [])

	for eff in effects:
		if not eff is Dictionary:
			continue
		var eff_type: String = eff.get("type", "")
		if eff_type != "SET_VARIABLE":
			continue  # 安全规则：只允许 SET_VARIABLE
		var key: String = eff.get("key", "")
		var val: float = eff.get("base_points", 0.0)
		var mode: String = eff.get("mode", "add")
		if key == "":
			continue
		if mode == "add":
			var current: float = float(EngineAPI.get_variable(key, 0.0))
			EngineAPI.set_variable(key, current + val)
		else:
			EngineAPI.set_variable(key, val)

	# 战斗日志通知
	var name_text: String = ""
	if I18n:
		name_text = I18n.t(bond.get("name_key", ""))
	else:
		name_text = bond_id
	if _gm._combat_log_module:
		_gm._combat_log_module._add_log(
			"[BOND] %s" % name_text, Color(0.8, 0.5, 1.0), "system"
		)

# === 查询接口 ===

func get_activated_bonds() -> Array[String]:
	return _activated_bonds

func get_all_bonds() -> Array:
	return _all_bonds

func get_bond_data(bond_id: String) -> Dictionary:
	for b in _all_bonds:
		if b.get("id", "") == bond_id:
			return b
	return {}

func get_bond_progress(bond_id: String) -> Dictionary:
	## 返回某个羁绊的进度信息: { "required": 3, "satisfied": 2, "activated": false, "details": [...] }
	var bond: Dictionary = get_bond_data(bond_id)
	if bond.is_empty():
		return {}
	var required_sets: Array = bond.get("required_sets", [])
	var min_count: int = bond.get("min_count", 1)
	var satisfied := 0
	var details: Array = []
	for set_id in required_sets:
		var sid: String = str(set_id)
		var is_done := _count_cards_in_set(sid) >= min_count
		if is_done:
			satisfied += 1
		details.append({"set_id": sid, "satisfied": is_done})
	return {
		"required": required_sets.size(),
		"satisfied": satisfied,
		"activated": bond_id in _activated_bonds,
		"details": details
	}
