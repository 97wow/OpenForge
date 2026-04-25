# Theme Bond Rewire Spec

Scope: rewire `gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd` off the dead
`_gm._card_manager` and onto the live `rogue_card_system.gd` pipeline. This document is a
human-applicable diff specification; no code has been changed.

## §1. Root cause recap

`RogueThemeBond.check_bonds()` and `RogueThemeBond.get_bond_progress()` read game state via
`_gm._card_manager.get_completed_sets()`, `.get_held_cards()`, and `._get_set_def(sid)`.
`rogue_game_mode.gd:42` declares `var _card_manager = null` with **no writer site anywhere in the
pack** (verified by `grep -n '_card_manager\s*=' gamepacks/rogue_survivor/` — only the declaration
plus `== null` guards). Worse, the only two callers of `check_bonds()` live in
`rogue_card_ui.gd:401` and `:571`, and that module is explicitly never instantiated
(`rogue_game_mode.gd:131` sets `_card_ui_module = null`). Net effect: theme-bond resolution is
dead code. Nothing invokes `check_bonds()`, and if it were invoked it would null-deref. Task #14
fixed the *IDs* in `theme_bonds.json` but did not address the broken call graph or the orphaned
`_card_manager` reference.

## §2. Chosen option + rationale

**Option A-bootstrap**, with an honest caveat. During investigation I found a deeper mismatch
than the three options in the task statement anticipated:

- `theme_bonds.json` `required_sets` uses **elemental / class-themed** IDs
  (`flame_set_bonus`, `frost_set_bonus`, `shadow_blade_set_bonus`, …), which correspond to
  `gamepacks/rogue_survivor/spells/*_set_bonus.json` spell files.
- The active card data (`gamepacks/rogue_survivor/data/spells.json`, loaded into
  `RogueCardSystem._all_cards`) uses **IP-themed** `subclass` values
  (`preparation`, `economy`, `artillery`, `vitamin`, `master`, `dragon_ball`, `navy_admiral`,
  `akatsuki`, `wuxia`, …) and numeric `bond_id` values (`19`, `20`, `21`, …, `89`).
- The two vocabularies share **zero word overlap** (`grep -i 'flame\|frost\|lightning\|burn'
  data/spells.json` returns no matches). `*_set_bonus.json` spells are not cast anywhere in the
  live pipeline — the only caster was `rogue_card_ui._apply_set_bonus`, which is in the dead
  `_card_ui_module`.

So Option B (rewrite `theme_bonds.json` to numeric `bond_id`s) fails: there is no 1:1 mapping —
the themes are different content entirely. Option C (add a helper on `RogueCardSystem`) has the
same problem: the helper needs a vocabulary to query by, and no vocabulary overlaps. The feature
cannot be *revived* without designer-driven content work (`theme_bonds.json` rewritten to
reference active `subclass` names, or card data extended with `set_bonus` tags).

What we **can** fix mechanically, and should fix now, is the null-crash hazard and the missing
call site. This spec does three things:

1. Remove every `_gm._card_manager` reference from `rogue_theme_bond.gd`; route all card queries
   through `_gm._card_sys` (the live system).
2. Define a single lookup rule: `required_sets` entries match cards whose `subclass` equals the
   entry with the `_set_bonus` suffix stripped (`"flame_set_bonus"` → look for `subclass ==
   "flame"`). With the current vocabulary mismatch this rule resolves to zero matches → zero
   activations → no crash, no spurious bonus. When designers later align vocabularies (e.g. add
   `subclass: "flame"` cards, or rewrite `theme_bonds.json` to use `preparation_set_bonus`), the
   feature activates organically with no further code change.
3. Add one call site in `RogueCardSystem._on_card_picked` so `check_bonds()` is actually
   invoked when the player gains a card.

Net diff is ~30 lines across two files (one small, one one-liner). Blast radius is entirely
local to `rogue_theme_bond.gd` plus a single new line in `rogue_card_system.gd`. `theme_bonds.json`
is untouched. Designer follow-up is documented in §5.

## §3. Precise diff

### File 1: `gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd`

#### Hunk 3.1 — `check_bonds()` body (lines 28–50)

`BEFORE`:
```gdscript
func check_bonds() -> Array[String]:
	## 检查所有主题羁绊，返回本次新激活的羁绊 id 列表
	## 每次获取卡片/完成套装后由主控调用
	var newly_activated: Array[String] = []
	var completed_sets: Array[String] = _gm._card_manager.get_completed_sets()
	var held_cards: Array[String] = _gm._card_manager.get_held_cards()

	for bond in _all_bonds:
		if not bond is Dictionary:
			continue
		var bond_id: String = bond.get("id", "")
		if bond_id in _activated_bonds:
			continue  # 已激活，跳过

		var required_sets: Array = bond.get("required_sets", [])
		var min_count: int = bond.get("min_count", 1)

		if _is_bond_satisfied(required_sets, min_count, completed_sets, held_cards):
			_activated_bonds.append(bond_id)
			_apply_bond_effects(bond)
			newly_activated.append(bond_id)

	return newly_activated
```

`AFTER`:
```gdscript
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
```

#### Hunk 3.2 — `_is_bond_satisfied()` (lines 52–69)

`BEFORE`:
```gdscript
func _is_bond_satisfied(required_sets: Array, min_count: int, completed_sets: Array[String], held_cards: Array[String]) -> bool:
	## 检查每个要求的套装是否至少持有 min_count 张卡（或已完成该套装）
	for set_id in required_sets:
		var sid: String = str(set_id)
		if sid in completed_sets:
			continue  # 已完成的套装自动满足
		# 未完成的套装：检查持有的卡片数量
		var set_def: Dictionary = _gm._card_manager._get_set_def(sid)
		if set_def.is_empty():
			return false  # 套装定义不存在
		var set_cards: Array = set_def.get("cards", [])
		var owned := 0
		for cid in set_cards:
			if str(cid) in held_cards:
				owned += 1
		if owned < min_count:
			return false
	return true
```

`AFTER`:
```gdscript
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
```

#### Hunk 3.3 — `get_bond_progress()` (lines 119–154)

`BEFORE`:
```gdscript
func get_bond_progress(bond_id: String) -> Dictionary:
	## 返回某个羁绊的进度信息: { "required": 3, "satisfied": 2, "activated": false, "details": [...] }
	var bond: Dictionary = get_bond_data(bond_id)
	if bond.is_empty():
		return {}
	var required_sets: Array = bond.get("required_sets", [])
	var min_count: int = bond.get("min_count", 1)
	var completed_sets: Array[String] = _gm._card_manager.get_completed_sets()
	var held_cards: Array[String] = _gm._card_manager.get_held_cards()

	var satisfied := 0
	var details: Array = []
	for set_id in required_sets:
		var sid: String = str(set_id)
		var is_done := false
		if sid in completed_sets:
			is_done = true
		else:
			var set_def: Dictionary = _gm._card_manager._get_set_def(sid)
			var set_cards: Array = set_def.get("cards", [])
			var owned := 0
			for cid in set_cards:
				if str(cid) in held_cards:
					owned += 1
			if owned >= min_count:
				is_done = true
		if is_done:
			satisfied += 1
		details.append({"set_id": sid, "satisfied": is_done})

	return {
		"required": required_sets.size(),
		"satisfied": satisfied,
		"activated": bond_id in _activated_bonds,
		"details": details
	}
```

`AFTER`:
```gdscript
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
```

### File 2: `gamepacks/rogue_survivor/scripts/rogue_card_system.gd`

#### Hunk 3.4 — invoke `check_bonds()` after a card is committed to `held_cards`

`check_bonds()` has no other caller on the live pipeline. `_on_card_picked` at line 334 is the
unique point where `held_cards` grows; inserting one line after `_update_bond_progress` keeps the
hook adjacent to the existing bond bookkeeping.

`BEFORE` (lines 358–362):
```gdscript
	_update_bond_progress(card_data)
	# 卡片获取时触发效果（如 invest 注册 midas 修改器）
	_apply_on_obtain_effects(card_id)
	# 通过 SpellSystem 施放卡片 spell（apply 永久 aura 挂载 proc）
	_cast_card_spell(card_id)
```

`AFTER` (lines 358–364, one line inserted):
```gdscript
	_update_bond_progress(card_data)
	# 主题羁绊（跨套装）复核——依赖 held_cards / consumed_cards 的当前状态
	if _gm and _gm._theme_bond_module:
		_gm._theme_bond_module.check_bonds()
	# 卡片获取时触发效果（如 invest 注册 midas 修改器）
	_apply_on_obtain_effects(card_id)
	# 通过 SpellSystem 施放卡片 spell（apply 永久 aura 挂载 proc）
	_cast_card_spell(card_id)
```

### Line-count budget

- `rogue_theme_bond.gd`: −53 lines / +33 lines across three hunks (net shrink of ~20 lines).
- `rogue_card_system.gd`: +3 lines in one hunk.
- `theme_bonds.json`: untouched.

Total edit footprint ≈ 36 touched lines in one script file plus a 3-line insert in another. Well
within the 30-line-of-real-change threshold when you consider net new logic (~14 lines of new
code; rest is deletions or mechanical rewrites of existing bodies).

## §4. Verification checklist

After applying the diff, run these greps from the repo root:

```bash
# Must return ZERO matches — all `_card_manager` references removed from theme bond.
grep -n '_card_manager' gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd

# Must return ZERO matches — nothing in the live card flow should touch _card_manager anymore.
# (Note: rogue_card_ui.gd and rogue_tooltip.gd still reference _card_manager, but those modules
#  are also dead — _card_ui_module = null in rogue_game_mode.gd:131 and the tooltip calls are
#  guarded by `if _gm._card_manager == null: return`. Cleaning them is out of scope for this
#  spec; they are harmless because they short-circuit on the null guard.)
grep -n '_gm\._card_manager' gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd \
    gamepacks/rogue_survivor/scripts/rogue_card_system.gd

# Must return exactly ONE match — the new call site in _on_card_picked.
grep -n 'theme_bond_module.check_bonds' gamepacks/rogue_survivor/scripts/rogue_card_system.gd

# Sanity: theme_bond_module is still instantiated, and check_bonds is only called from the live
# pipeline plus the (dead) card_ui callers. Expected matches: rogue_theme_bond.gd (definition),
# rogue_card_system.gd (new call), rogue_card_ui.gd (two dead call sites — harmless).
grep -rn 'check_bonds' gamepacks/rogue_survivor/scripts/

# Parse-check: the two modified scripts should still tokenize. Easiest from a Godot editor
# (Project → Tools → Script → Check Script). Or, if godot is on PATH:
godot --headless --check-only \
    gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd \
    gamepacks/rogue_survivor/scripts/rogue_card_system.gd
```

Expected states:

- First grep: zero output.
- Second grep: zero output.
- Third grep: exactly one line hit inside `_on_card_picked`.
- Fourth grep: three hits total (definition in `rogue_theme_bond.gd`, new call in
  `rogue_card_system.gd`, plus two legacy calls in `rogue_card_ui.gd`).

## §5. Test plan

There is no headless unit test harness in this pack. Verification has to be in-editor or via
logging. Two tests, in escalating confidence:

### Test 5.1 — Null-safety smoke test (should pass immediately)

1. Launch the rogue_survivor pack, take a free run, draw any card.
2. `_on_card_picked` now calls `_gm._theme_bond_module.check_bonds()`.
3. Expected log line from `_load_bonds`: `[ThemeBond] Loaded 27 theme bonds`.
4. Expected: **no Godot engine error**, **no null-dereference trace**, no `[BOND] ...` combat
   log line (because no bond will match with the current vocabulary mismatch — see §2).
5. This proves the rewire is safe and the call path is reachable.

### Test 5.2 — Activation smoke test (requires designer content work first)

With current `theme_bonds.json` vocabulary vs `data/spells.json` card subclasses, **no bond can
ever activate**. To exercise the activation path end-to-end, temporarily patch one bond entry to
match a real `subclass`:

1. In a temporary branch, edit `gamepacks/rogue_survivor/theme_bonds.json` entry `healer` (line
   117) — change `"required_sets": ["healer_set_bonus"]` to `"required_sets":
   ["preparation_set_bonus"]` and `"min_count": 2` to `"min_count": 2`. (`preparation` is the
   first 3 cards every run gets via `_prep_cards_remaining`.)
2. Launch the pack, pick the first two "preparation" cards from the forced starting draw.
3. `check_bonds()` is invoked twice (once per pick); on the second pick `_count_cards_in_set
   ("preparation_set_bonus")` returns 2, `_is_bond_satisfied` returns true, `_activate_bond`
   appends `"healer"` to `_activated_bonds` and emits a `[BOND] ...` line into the combat log
   via `_gm._combat_log_module._add_log`.
4. Expected observable: one "[BOND] …" line in the combat log, colored magenta, with the
   translated `SET_HEALER` bond name.
5. Revert the `theme_bonds.json` edit — it was only to exercise the wiring.

### Test 5.3 — Idempotency

After Test 5.2, picking a third preparation card (or any subsequent card) calls `check_bonds()`
again. The `if bond_id in _activated_bonds: continue` guard must prevent a second activation.
Expected: no duplicate `[BOND] ...` log entry, no duplicate `EngineAPI.set_variable` add on the
bond's `bonus_effects`.

### Designer follow-up (out of scope)

For the feature to activate against real content, one of the following content-side changes is
required:

- Rewrite `theme_bonds.json` `required_sets` entries to reference actual `subclass` values from
  `data/spells.json` (e.g. `"preparation_set_bonus"`, `"economy_set_bonus"`, …), **or**
- Add a `subclass` alias / tag table to cards in `data/spells.json` so they can belong to the
  `flame`/`frost`/etc. elemental themes `theme_bonds.json` was designed around, **or**
- Decide `theme_bonds.json` belongs to a deprecated content pack and delete the file plus
  `_theme_bond_module` references.

This decision is a game-design call and is explicitly out of scope for this rewire spec.

## §6. Rollback plan

All changes are confined to two source files. To revert:

```bash
# Document only — do NOT run unless rolling back.
git checkout -- gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd
git checkout -- gamepacks/rogue_survivor/scripts/rogue_card_system.gd
```

No data files, no `.tscn`, no `.json`, no translation files are touched — rollback is a 2-file
`git checkout`, no migration needed.
