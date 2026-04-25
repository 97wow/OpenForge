# Theme Bond Rewire — Applied Report

This document records the outcome of applying `docs/THEME_BOND_REWIRE_SPEC.md` to the live
codebase on 2026-04-25.

## §1. Hunks applied

| Hunk label                         | Target file                                             | Status  | Notes                                                                                              |
|------------------------------------|---------------------------------------------------------|---------|----------------------------------------------------------------------------------------------------|
| File 1, hunk 3.1 (`check_bonds`)   | `gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd`  | APPLIED | BEFORE text matched byte-for-byte (lines 28–50). Replaced with the new null-guarded body.          |
| File 1, hunk 3.2 (`_is_bond_satisfied` + new `_count_cards_in_set`) | `gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd`  | APPLIED | BEFORE text matched byte-for-byte (lines 52–69). Signature simplified and helper added.            |
| File 1, hunk 3.3 (`get_bond_progress`) | `gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd`  | APPLIED | BEFORE text matched byte-for-byte (lines 119–154). Replaced with the helper-driven version.        |
| File 2, hunk 3.4 (`_on_card_picked` call site) | `gamepacks/rogue_survivor/scripts/rogue_card_system.gd` | APPLIED | BEFORE text matched byte-for-byte (around line 358). Inserted the 3 new lines calling `check_bonds()`. |

All four hunks applied cleanly. None were skipped, none partial.

## §2. Verification grep results

### Grep 1 — `_card_manager` references inside `rogue_theme_bond.gd`

```bash
grep -n '_card_manager' gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd
```

Actual output: **(no matches)**

Expected: ZERO matches. ✅ **Matches spec.**

### Grep 2 — `_gm._card_manager` across the two modified files

```bash
grep -n '_gm\._card_manager' \
    gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd \
    gamepacks/rogue_survivor/scripts/rogue_card_system.gd
```

Actual output: **(no matches)**

Expected: ZERO matches. ✅ **Matches spec.**

### Grep 3 — new `theme_bond_module.check_bonds` call site

```bash
grep -n 'theme_bond_module.check_bonds' gamepacks/rogue_survivor/scripts/rogue_card_system.gd
```

Actual output:

```
361:		_gm._theme_bond_module.check_bonds()
```

Expected: exactly ONE match inside `_on_card_picked`. ✅ **Matches spec** (line 361 is inside
`_on_card_picked`, which begins at line 334).

### Grep 4 — all `check_bonds` references in the pack scripts

```bash
grep -rn 'check_bonds' gamepacks/rogue_survivor/scripts/
```

Actual output:

```
gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd:28:func check_bonds() -> Array[String]:
gamepacks/rogue_survivor/scripts/rogue_card_system.gd:361:		_gm._theme_bond_module.check_bonds()
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:401:		_gm._theme_bond_module.check_bonds()
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:571:		_gm._theme_bond_module.check_bonds()
```

Expected: 4 hits total — 1 definition in `rogue_theme_bond.gd`, 1 new call in
`rogue_card_system.gd`, 2 legacy calls in `rogue_card_ui.gd`. ✅ **Matches spec.**

> Note: the spec's prose says "three hits total" while also listing four items. The four-item
> enumeration matches what we have; the "three" was an arithmetic slip in the spec. Result is
> unambiguous: definition + live call + two dead legacy calls.

### Grep 5 — parse check via Godot

Skipped per task instructions (do NOT start Godot). Syntactic soundness was verified by eye; the
edits preserve indentation (tabs), braces, and signature shapes, and the new helper
`_count_cards_in_set` uses only APIs already proven to exist on `RogueCardSystem`
(`held_cards`, `consumed_cards`, each an array of dictionaries with `data.subclass`).

## §3. Files modified

| Path                                                       | Bytes before | Bytes after | Delta |
|------------------------------------------------------------|-------------:|------------:|------:|
| `gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd`     |        4980  |       4805  |  −175 |
| `gamepacks/rogue_survivor/scripts/rogue_card_system.gd`    |       33349  |      33517  |  +168 |
| **Total**                                                  |       38329  |      38322  |    −7 |

No other files were touched. `theme_bonds.json`, translations, scene files, and other scripts
are untouched.

## §4. Rollback snippet

To undo the entire change:

```bash
git checkout -- \
    gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd \
    gamepacks/rogue_survivor/scripts/rogue_card_system.gd
```

## §5. Still-broken call sites (out-of-scope sweep)

The spec flagged `rogue_card_ui.gd` and `rogue_tooltip.gd` as having dead `_card_manager`
references that are harmless because the modules they live in are either never instantiated or
null-guarded. Verified below:

```bash
grep -n '_card_manager' gamepacks/rogue_survivor/scripts/
```

Actual output (full listing):

```
gamepacks/rogue_survivor/scripts/rogue_tooltip.gd:133:	if _gm._card_sys and not _gm._card_manager:
gamepacks/rogue_survivor/scripts/rogue_tooltip.gd:143:	if _gm._card_manager == null:
gamepacks/rogue_survivor/scripts/rogue_tooltip.gd:145:	var held: Array[String] = _gm._card_manager.get_held_cards()
gamepacks/rogue_survivor/scripts/rogue_tooltip.gd:148:	var card_data: Dictionary = _gm._card_manager.get_card_data(held[slot_idx])
gamepacks/rogue_survivor/scripts/rogue_tooltip.gd:232:	if set_id != "" and _gm._card_manager != null:
gamepacks/rogue_survivor/scripts/rogue_tooltip.gd:233:		var held: Array[String] = _gm._card_manager.get_held_cards()
gamepacks/rogue_survivor/scripts/rogue_tooltip.gd:319:	var set_data: Dictionary = _gm._card_manager.get_set_data(set_id)
gamepacks/rogue_survivor/scripts/rogue_tooltip.gd:332:		var cd: Dictionary = _gm._card_manager.get_card_data(str(cid))
gamepacks/rogue_survivor/scripts/rogue_tooltip.gd:354:	if _gm._card_manager == null or _tooltip_ui_layer == null:
gamepacks/rogue_survivor/scripts/rogue_tooltip.gd:358:	var set_data: Dictionary = _gm._card_manager.get_set_data(set_id)
gamepacks/rogue_survivor/scripts/rogue_tooltip.gd:397:		var cdata: Dictionary = _gm._card_manager.get_card_data(str(cid))
gamepacks/rogue_survivor/scripts/rogue_game_mode.gd:42:var _card_manager = null
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:218:	if _gm._card_manager == null:
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:225:	var choices: Array[Dictionary] = _gm._card_manager.draw_three()
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:266:	slot_hint.text = I18n.t("CARDS_COUNT", [_gm._card_manager.get_card_count(), RogueCardManager.MAX_CARDS])
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:278:	var is_full: bool = _gm._card_manager.is_full()
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:298:		var held_cards: Array[String] = _gm._card_manager.get_held_cards()
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:300:			var held_data: Dictionary = _gm._card_manager.get_card_data(held[slot_idx])   # (line 300)
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:380:	if _pending_card_id == "" or _gm._card_manager == null:
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:384:	_gm._card_manager.remove_card(replace_id)
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:386:	var result: Dictionary = _gm._card_manager.select_card(_pending_card_id)
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:387:	var card_data: Dictionary = _gm._card_manager.get_card_data(_pending_card_id)
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:392:		var set_data: Dictionary = _gm._card_manager.get_set_data(set_id)
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:519:	if set_id != "" and _gm._card_manager:
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:520:		var set_data: Dictionary = _gm._card_manager.get_set_data(set_id)
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:522:		var held: Array[String] = _gm._card_manager.get_held_cards()
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:543:	if _gm._card_manager == null:
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:546:	if _gm._card_manager.is_full():
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:554:	var result: Dictionary = _gm._card_manager.select_card(card_id)
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:555:	var card_data: Dictionary = _gm._card_manager.get_card_data(card_id)
gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:562:		var set_data: Dictionary = _gm._card_manager.get_set_data(set_id)
gamepacks/rogue_survivor/scripts/rogue_rewards.gd:399:	if _gm._card_manager == null:
gamepacks/rogue_survivor/scripts/rogue_rewards.gd:401:	var held: Array[String] = _gm._card_manager.get_held_cards()
gamepacks/rogue_survivor/scripts/rogue_rewards.gd:417:		var cdata: Dictionary = _gm._card_manager.get_card_data(cid)
```

Assessment:

- `rogue_game_mode.gd:42` — declaration (`var _card_manager = null`) untouched, as expected.
- `rogue_game_mode.gd:131` — `_card_ui_module = null` (verified by reading the file), so all
  references in `rogue_card_ui.gd` are in methods on a module that is never constructed. Dead
  code. Harmless.
- `rogue_tooltip.gd` — every pathway that reads `_card_manager` without a guard is reached only
  from `show_card_tooltip(slot_idx)` (line ~143) or `show_set_tooltip(set_id)` (line ~354); both
  have an early-return null guard at the top of the function. Lines 232–233, 319, 332, 397 are
  inside branches that are only taken after those guards. Dead-but-harmless.
- `rogue_rewards.gd` — **surprise finding not mentioned in the spec.** Lines 399–417 reference
  `_gm._card_manager`, guarded at line 399 by `if _gm._card_manager == null: return`. Because the
  guard is explicit, this too is dead-but-harmless. Flagging it here so a future cleanup pass
  knows about it; it does not affect this rewire.

Net: no surprise that threatens the rewire. All remaining `_card_manager` references either
declare the null field, short-circuit on null, or live in a module that is never instantiated.

## §6. Next step recommendation

All four hunks applied cleanly, all grep verifications matched the spec's expected states.

**Ready for runtime smoke-test by a human.** Spec §5.1 (null-safety smoke test) is the
appropriate next gate: launch the pack, take a free run, pick one card, confirm no null-deref
trace. Spec §5.2 requires a temporary `theme_bonds.json` edit and is a designer-content call;
not part of this rewire.

One non-blocking follow-up the human may wish to schedule: a cleanup pass that deletes the dead
`_card_manager` references in `rogue_card_ui.gd`, `rogue_tooltip.gd`, and `rogue_rewards.gd`
along with the orphaned declaration in `rogue_game_mode.gd:42`. That is strictly out of scope
for this rewire but would remove ~30 harmless but misleading call sites.
