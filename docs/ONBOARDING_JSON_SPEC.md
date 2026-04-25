# rogue_survivor — Onboarding §A Data-Driven Spec

> Companion to `docs/ONBOARDING_PLAN.md` §A1–A5. Scope: specify each must-ship
> beat as a `TriggerSystem` JSON config (ECA: event → conditions → actions)
> and flag the **minimum** net-new action/condition handlers needed where
> the current builtins can't express the beat.
>
> **No code, no JSON, no scenes are created in this task** — this is a design
> and gap-analysis document only.
>
> Source of truth: `src/systems/trigger_system.gd`, `src/gamepack/game_pack_loader.gd`,
> `gamepacks/rogue_survivor/scripts/*.gd`, `gamepacks/rogue_survivor/rules/combat_rules.json`
> (audited 2026-04-25).

---

## §0. Executive summary

| Beat | Ships data-driven? | Blocker |
|---|---|---|
| **A1** Welcome / movement primer | ✅ **Yes** (after §6 handlers) | Needs `show_toast` action + cross-run save flag |
| **A2** First card-draft explainer | ⚠️ **Degraded** data-driven (toast only) | Labelled-arrow overlay cannot be expressed as trigger JSON; fidelity downgraded to toast. Full-fidelity overlay is deferred to an implementation module (see §8). |
| **A3** First set-bonus activation | ✅ **Yes** (after §6 handlers) | Same `show_toast` + save flag |
| **A4** First boss intro | ✅ **Yes** (after §6 handlers) | Needs a boss-detection condition since `wave_started` payload doesn't carry `is_boss` |
| **A5** "Skip all tutorials" toggle | ❌ **Not a trigger beat** — pure UI widget writing to `SaveSystem`. Orthogonal to TriggerSystem. See §5. |

**Total net-new framework surface** needed to ship A1/A3/A4 plus degraded A2:

- **3 new action handlers**: `show_toast`, `set_save_flag`, (optional) `show_boss_subtitle`
- **2 new condition evaluators**: `check_save_flag`, `compare_event_value`

That is **5 new handlers**, above the task's "under 3" budget. The most honest
fix is to accept that:

1. **Onboarding copy needs a UI-rendering action** — `show_message` in
   `engine_api.gd:763` is a `print()` stub and cannot reach the HUD. A data-driven
   copy system can't exist without *one* toast action. This is a general
   framework gap, not an onboarding-specific one — other GamePack designers will
   hit the same wall. Budget **1 handler** against onboarding and
   note the rest as a framework investment.

2. **Cross-run save flags need a persistent variable backend** — `set_variable` /
   `check_variable` use `EngineAPI._variables` which clears on pack unload
   (`game_pack_loader.gd:199`). The plan's `seen_welcome` / `seen_first_bond` /
   `tutorials_disabled` flags *must* survive restart (the one-shot-per-save rule).
   Either back `EngineAPI._variables` with `SaveSystem` under a reserved
   namespace, or add `set_save_flag`/`check_save_flag` as dedicated handlers.
   Budget **2 handlers** (set + check) against onboarding.

3. **Event-field comparison is a framework gap**, not an onboarding gap —
   the current TriggerSystem cannot filter `$event.wave == 1` or
   `$event.level == 2`. `combat_rules.json` sidesteps this by using `has_tag`
   instead of numeric comparisons. This is a 10-line `compare_event_value`
   evaluator that benefits **every** future trigger; budget **1 handler**.

4. **A2 overlay fidelity is out of reach** for pure JSON no matter what
   handlers we add — labelled arrows anchored to three separate runtime
   children of the card panel is not data. Downgrade A2 to a toast inside the
   draft (matching A1/A3 pattern), or ship A2 via an implementation module as
   originally planned in `ONBOARDING_PLAN.md §N`.

**Recommendation:** ship A1, A3, A4 fully data-driven with 4 new handlers
(`show_toast`, `set_save_flag`, `check_save_flag`, `compare_event_value`);
downgrade A2 to a toast in this spec; ship A5 as a checkbox in the settings
scene outside the trigger system.

---

## §1. A1 — Welcome / movement primer (first run only, before wave 1)

### JSON config

```json
{
  "id": "onboarding_welcome_movement",
  "event": "wave_started",
  "once": true,
  "conditions": [
    { "type": "compare_event_value", "path": "$event.wave", "op": "==", "value": 1 },
    { "type": "check_save_flag", "namespace": "rogue_survivor_onboarding", "key": "tutorials_disabled", "op": "!=", "value": true },
    { "type": "check_save_flag", "namespace": "rogue_survivor_onboarding", "key": "seen_welcome",       "op": "!=", "value": true }
  ],
  "actions": [
    { "type": "show_toast", "i18n_key": "TUTORIAL_WELCOME_MOVE", "color": "#66ccff", "duration": 5.0 },
    { "type": "set_save_flag", "namespace": "rogue_survivor_onboarding", "key": "seen_welcome", "value": true }
  ]
}
```

### Event verification
- `wave_started` emitted at `gamepacks/rogue_survivor/scripts/rogue_wave_system.gd:144`
  with payload `{wave, duration, elite_count}`. `wave` is 1-indexed (line 145:
  `current_wave + 1`). EventBus path, so reachable by TriggerSystem
  (which only listens on EventBus per `trigger_system.gd:47`).

### Where to register
- File: `gamepacks/rogue_survivor/rules/onboarding.json` (new JSON file in the
  existing `rules/` directory — the file itself is out of scope for this spec
  document, but the destination is confirmed).
- Auto-loaded by `src/gamepack/game_pack_loader.gd:162-179` (`_load_rules`) which
  iterates every `.json` in `rules_dir` and calls
  `TriggerSystem.load_triggers()`. **Zero loader changes required** —
  `pack.json:rules_dir` is already `"rules"`.

### Required new action handlers / conditions
- `compare_event_value` — condition (see §6.1)
- `check_save_flag` — condition (see §6.2)
- `show_toast` — action (see §6.3)
- `set_save_flag` — action (see §6.4)

### I18n keys used
- `TUTORIAL_WELCOME_MOVE` — from `ONBOARDING_PLAN.md §A1`. Naming fits the
  project's `SCREAMING_SNAKE_CASE` convention (see existing keys like
  `WAVE_START` in `rogue_wave_system.gd:151`).

### Notes
- The `once: true` field is a native TriggerSystem feature
  (`trigger_system.gd:40, :85`), but it only persists for the trigger object's
  lifetime. Cross-save one-shot is carried by `seen_welcome`, not by `once`.
  Keeping `once: true` anyway makes the same-run re-entry safe.
- The plan's "5-second pulsing cyan label over the hero" is **not** expressible
  in data. This spec degrades that to a cyan-tinted toast. If the label-over-hero
  effect is mandatory, it becomes either (a) a 5th new action
  (`show_world_label`) or (b) lives in an implementation module. Flagged in §8.

---

## §2. A2 — First card-draft explainer (Lv2 level-up)

**Fidelity downgrade.** The plan specifies three labelled arrows anchored to
runtime children of `rogue_card_ui`. That cannot be expressed as trigger JSON:
the arrow anchors are live Control nodes created inside
`show_card_selection()`, not data. Two options:

1. **Data-driven degraded** (this spec's default): replace the overlay with a
   single 3-line toast that fires just *before* the draft modal opens. Still
   covers the "I don't know what the draft is showing me" blocker.
2. **Full fidelity**: keep the overlay approach from `ONBOARDING_PLAN.md §N`
   — a new `rogue_onboarding_overlay.gd` module called from
   `rogue_card_ui.show_card_selection()`. Not data-driven. Flagged in §8.

### JSON config (degraded, ship-ready after §6 handlers)

```json
{
  "id": "onboarding_first_draft",
  "event": "hero_level_up",
  "once": true,
  "conditions": [
    { "type": "compare_event_value", "path": "$event.level", "op": "==", "value": 2 },
    { "type": "check_save_flag", "namespace": "rogue_survivor_onboarding", "key": "tutorials_disabled", "op": "!=", "value": true },
    { "type": "check_save_flag", "namespace": "rogue_survivor_onboarding", "key": "seen_first_draft",   "op": "!=", "value": true }
  ],
  "actions": [
    { "type": "show_toast", "i18n_key": "TUTORIAL_DRAFT_TITLE",  "color": "#ffcc66", "duration": 6.0 },
    { "type": "show_toast", "i18n_key": "TUTORIAL_DRAFT_RARITY", "color": "#ffcc66", "duration": 6.0 },
    { "type": "show_toast", "i18n_key": "TUTORIAL_DRAFT_SETS",   "color": "#ffcc66", "duration": 6.0 },
    { "type": "set_save_flag", "namespace": "rogue_survivor_onboarding", "key": "seen_first_draft", "value": true }
  ]
}
```

### Event verification
- `hero_level_up` is emitted at `rogue_hero.gd:125` via `_gm.emit(...)`.
  `_gm.emit` is `GamePackScript.emit` (`src/gamepack/game_pack_script.gd:29`)
  which calls `EngineAPI.emit_event` which calls `EventBus.emit_event`.
  **Reachable by TriggerSystem.** (The plan's "_gm bus vs EventBus" wording
  is misleading; they are the same bus.)
- Payload: `{"level": _gm._hero_level}`.

### Where to register
- Same file as A1: `gamepacks/rogue_survivor/rules/onboarding.json`.

### Required new action handlers / conditions
- Same four as A1. No additional net-new.

### I18n keys used
- `TUTORIAL_DRAFT_TITLE`, `TUTORIAL_DRAFT_RARITY`, `TUTORIAL_DRAFT_SETS`
  — from `ONBOARDING_PLAN.md §A2`. `TUTORIAL_DRAFT_OK` is dropped (no modal,
  no "Got it" button in the degraded form).

### Notes
- **Firing timing.** `hero_level_up` fires in `rogue_hero.gd:125` *before*
  `rogue_card_ui.show_card_selection()` opens (the plan confirms the ordering).
  The trigger toast will paint a few frames before the draft modal, which is
  the desired UX.
- If the overlay fidelity is a must, this trigger should be **deleted** and
  A2 delivered via the non-data-driven overlay module. Do not ship both — see
  `CLAUDE.md` rule #6 ("同一效果禁止有两条实现路径").

---

## §3. A3 — First set-bonus (羁绊) activation

### JSON config

```json
{
  "id": "onboarding_first_bond",
  "event": "bond_activated",
  "once": true,
  "conditions": [
    { "type": "check_save_flag", "namespace": "rogue_survivor_onboarding", "key": "tutorials_disabled", "op": "!=", "value": true },
    { "type": "check_save_flag", "namespace": "rogue_survivor_onboarding", "key": "seen_first_bond",    "op": "!=", "value": true }
  ],
  "actions": [
    { "type": "show_toast", "i18n_key": "TUTORIAL_BOND_FIRST", "color": "#cc99ff", "duration": 5.0 },
    { "type": "set_save_flag", "namespace": "rogue_survivor_onboarding", "key": "seen_first_bond", "value": true }
  ]
}
```

### Event verification
- `bond_activated` emitted at `gamepacks/rogue_survivor/scripts/rogue_card_system.gd:430`
  via `EventBus.emit_event("bond_activated", {"bond_id": bond_id})`. Direct
  EventBus, no indirection.

### Where to register
- Same file: `gamepacks/rogue_survivor/rules/onboarding.json`.

### Required new action handlers / conditions
- `check_save_flag`, `show_toast`, `set_save_flag`. No additional.
- Does **not** need `compare_event_value` — the "first bond" filter is handled
  entirely by the `seen_first_bond` flag; the trigger fires once per save
  regardless of which bond activated first.

### I18n keys used
- `TUTORIAL_BOND_FIRST` — from `ONBOARDING_PLAN.md §A3`.

### Notes
- The plan mentions a "1.5 s screen vignette pulse (already present in
  `rogue_vfx`)". That effect is **not** expressible in trigger JSON — it's
  a runtime `spawn_vfx` call. Dropped from the data-driven spec; if mandatory,
  add a dedicated `play_vfx` action (see §8). The existing combat-log line on
  bond-activate continues to print through `rogue_card_system` itself.

---

## §4. A4 — First boss intro

### JSON config

```json
{
  "id": "onboarding_first_boss",
  "event": "wave_started",
  "once": true,
  "conditions": [
    { "type": "is_boss_wave" },
    { "type": "check_save_flag", "namespace": "rogue_survivor_onboarding", "key": "tutorials_disabled", "op": "!=", "value": true },
    { "type": "check_save_flag", "namespace": "rogue_survivor_onboarding", "key": "seen_first_boss",    "op": "!=", "value": true }
  ],
  "actions": [
    { "type": "show_toast", "i18n_key": "TUTORIAL_BOSS_FIRST", "color": "#ff6666", "duration": 6.0 },
    { "type": "set_save_flag", "namespace": "rogue_survivor_onboarding", "key": "seen_first_boss", "value": true }
  ]
}
```

### Event verification
- `wave_started` payload `{wave, duration, elite_count}` does **not** carry a
  boss flag. The plan's proposed test is
  `WAVE_CONFIGS[current_wave].is_boss == true` — that is a local lookup inside
  `rogue_wave_system.gd`, not event data. `compare_event_value` cannot cross
  into `WAVE_CONFIGS`.
- The existing `rogue_spawner.show_boss_warning()` (`rogue_spawner.gd:198`) is
  the in-game signal that a boss is about to spawn, but it's a function call,
  not an event.

### Required new action handlers / conditions
- One pack-scoped condition evaluator: `is_boss_wave` (see §6.5). It
  encapsulates the `WAVE_CONFIGS[current_wave].is_boss` check so the JSON
  stays readable. Alternative: emit a new `boss_wave_started` event from
  `rogue_wave_system.gd` and trigger off that — but `ONBOARDING_PLAN.md` §15
  explicitly warns "Never invent events", and adding `is_boss_wave` as a
  `register_condition_evaluator` from the pack script is cleaner: it's the
  documented extension point of TriggerSystem (`trigger_system.gd:131`).
- Plus the four shared handlers from §6.
- **This is the extra handler over budget.** If it cannot ship, the fallback
  is a new `boss_wave_started` EventBus event emitted in
  `rogue_wave_system.gd:204` — costs ~3 LOC in `rogue_wave_system.gd` instead
  of a new condition. Either path is small; they are not simultaneously needed.

### Where to register
- JSON: `gamepacks/rogue_survivor/rules/onboarding.json`.
- `is_boss_wave` evaluator: registered by the rogue_survivor pack script on
  `_pack_ready()` via `TriggerSystem.register_condition_evaluator("is_boss_wave", Callable)`.
  Extension-point is documented at `trigger_system.gd:131`. See §6.5.

### I18n keys used
- `TUTORIAL_BOSS_FIRST` — from `ONBOARDING_PLAN.md §A4`.

### Notes
- The existing red boss warning flash in `rogue_spawner.gd:205-219` continues
  to play — the trigger adds the toast *in parallel*, not in place. Plan's
  "subtitle line below the flash" fidelity is downgraded to a side-toast.
- The plan's constraint that boss warnings *themselves* keep firing is honored:
  this trigger only gates the *tutorial* layer with `seen_first_boss`.

---

## §5. A5 — "Skip all tutorials" toggle

**Not a TriggerSystem beat.** A5 is a settings UI widget that writes one flag.
It has no event, no condition, no action — it's just a `CheckBox.toggled`
signal writing `SaveSystem.save_data("rogue_survivor_onboarding", "tutorials_disabled", bool)`.

All TriggerSystem JSON in §1–§4 reads that flag via the `check_save_flag`
condition. So A5 is *consumed* by the JSON, not expressed in it.

### Where to ship
- Host scene: the plan says "pause/settings menu or `character_select` footer".
  Auditing `gamepacks/rogue_survivor/scenes/` confirms `character_select/`
  and `difficulty_select/` exist; no `pause_menu.tscn` ships today. Ticket
  the toggle on `character_select` first. This is a ~10 LOC change inside the
  pack's settings UI script — **not a framework change, not a JSON change**.

### I18n key used
- `TUTORIAL_SKIP_TOGGLE` — from `ONBOARDING_PLAN.md §A5`.

### Notes
- There is no A5 JSON block. Leaving one here would be misleading — it would
  imply the toggle is a trigger, which it isn't.
- The widget **must** be built before §A1 ships so players have an escape hatch
  as soon as onboarding goes live.

---

## §6. Required new action / condition handlers (consolidated)

Minimum set to ship §A1/A3/A4 fully data-driven and §A2 in degraded form.
Handler signatures follow the existing pattern in `trigger_system.gd:131-135`
(`register_condition_evaluator(type, evaluator)` /
`register_action_executor(type, executor)`).

### §6.1 Condition `compare_event_value`

```
# API spec — to be registered in trigger_system.gd::_register_builtin_conditions
# condition shape:
#   { "type": "compare_event_value", "path": "$event.wave", "op": "==", "value": 1 }
# path:  string beginning with "$event." — resolved via resolve_value(path, event_data)
# op:    "==" "!=" ">" ">=" "<" "<=" — reuses _compare() for numeric, string-compare otherwise
# value: literal; may itself be a "$event.xxx" reference (resolve_value both sides)
# returns: false when path can't be resolved (null ≠ anything)
#
# Generic: unlocks event-field filtering for every future rule, not just onboarding.
```

Used by: A1 (`wave == 1`), A2 (`level == 2`).

### §6.2 Condition `check_save_flag`

```
# API spec — new condition
# condition shape:
#   { "type": "check_save_flag",
#     "namespace": "rogue_survivor_onboarding",
#     "key": "seen_welcome",
#     "op": "!=", "value": true }
# Reads SaveSystem.load_data(namespace, key, default=null).
# Compares with op/value using _compare() for numbers, strict equality otherwise.
# op defaults to "=="; value defaults to true.
#
# Cross-run persistence: yes — SaveSystem is JSON-backed (see ONBOARDING_PLAN §N+1).
# Required because TriggerSystem's existing check_variable hits EngineAPI._variables,
# which clears on pack unload (game_pack_loader.gd:199).
```

Used by: A1, A2, A3, A4 — every beat gates on `tutorials_disabled` and its own
`seen_*` flag.

### §6.3 Action `show_toast`

```
# API spec — new action
# action shape:
#   { "type": "show_toast",
#     "i18n_key": "TUTORIAL_WELCOME_MOVE",
#     "args": [],              # optional, passed to I18n.t(key, args)
#     "color": "#66ccff",      # optional, BBCode-compatible hex; default "#d8d8e6"
#     "duration": 5.0 }        # advisory; rogue_hud_announce already uses 5s fixed fade
# Rendering: routes to the loaded pack's hud module, specifically
#   rogue_hud.add_announcement(I18n.t(key, args), Color(color))
# which delegates to rogue_hud_announce.add() (verified rogue_hud.gd:128).
#
# Failure mode: if HUD isn't instantiated yet (e.g. first wave_started fires
# a frame before HUD.ready) the action logs a warning via DebugOverlay and no-ops.
# Must not crash the game (framework-health rule).
#
# Why not reuse show_message? engine_api.gd:763 show_message is a print() stub;
# it never reaches the HUD. Either upgrade show_message to render through the
# active HUD surface (preferred — benefits all packs) or add show_toast as
# the rogue_survivor pack's registered extension. The preferred path is the
# framework upgrade; either way, this is the ONE toast action onboarding needs.
```

Used by: A1, A2, A3, A4.

### §6.4 Action `set_save_flag`

```
# API spec — new action
# action shape:
#   { "type": "set_save_flag",
#     "namespace": "rogue_survivor_onboarding",
#     "key": "seen_welcome",
#     "value": true }
# Value may be literal or "$event.xxx" reference (resolve_value).
# Calls SaveSystem.save_data(namespace, key, value) — JSON+checksum persistence
# per src/systems/save_system.gd:32 (cited in ONBOARDING_PLAN §N+1).
# Pair with §6.2 check_save_flag to gate one-shot-per-save beats.
```

Used by: A1, A2, A3, A4 — every beat writes its `seen_*` flag on display.

### §6.5 Condition `is_boss_wave` (pack-scoped)

```
# API spec — pack-registered condition (NOT a framework builtin)
# Registered by rogue_survivor main_script on _pack_ready():
#   TriggerSystem.register_condition_evaluator("is_boss_wave", _is_boss_wave_eval)
# condition shape:
#   { "type": "is_boss_wave" }    # no parameters; reads RogueWaveSystem state
# Looks up the active wave index on _gm._wave_system (or similar) and returns
# WAVE_CONFIGS[current_wave].is_boss.
# ALTERNATIVE (also acceptable): skip this condition entirely and emit a new
# "boss_wave_started" event from rogue_wave_system.gd:204 — then A4's trigger
# just filters on event name. Either costs ~5 LOC; pick whichever fits the
# team's preference for "add events" vs "add conditions".
```

Used by: A4 only.

### Handler count summary

| Handler | Type | Scope | Beats served |
|---|---|---|---|
| `compare_event_value` | condition | framework | A1, A2 |
| `check_save_flag` | condition | framework | A1, A2, A3, A4 |
| `show_toast` | action | framework | A1, A2, A3, A4 |
| `set_save_flag` | action | framework | A1, A2, A3, A4 |
| `is_boss_wave` | condition | pack | A4 |

**4 framework handlers + 1 pack-local extension.** All except `is_boss_wave`
are general-purpose and pay for themselves against future triggers, not just
onboarding.

---

## §7. Loader registration

**Zero code change required to load the new JSON file.**

`src/gamepack/game_pack_loader.gd:162-179` iterates every `.json` in
`<pack>/<rules_dir>/` and calls `TriggerSystem.load_triggers()`. The
rogue_survivor pack already sets `"rules_dir": "rules"` in
`gamepacks/rogue_survivor/pack.json:32`, and `gamepacks/rogue_survivor/rules/`
already exists (currently holds `combat_rules.json`).

Dropping a new `gamepacks/rogue_survivor/rules/onboarding.json` at pack build
time is enough — `_load_rules()` picks it up on pack boot. Each trigger is
registered via `TriggerSystem.register_trigger()` and deduped by `id`, so a
second boot of the same pack is safe.

The only pack-side code the onboarding JSON needs to ride next to is the
`is_boss_wave` evaluator registration in §6.5 — a **single line** inside
`rogue_game_mode.gd::_pack_ready()`:

```gdscript
# (Spec — not implemented in this task.)
EngineAPI.get_system("trigger").register_condition_evaluator(
    "is_boss_wave", _is_boss_wave_eval
)
```

That line + the `_is_boss_wave_eval(cond, event_data) -> bool` method on
`rogue_game_mode.gd` is the entire pack-side footprint.

---

## §8. Risks and open questions

1. **`show_message` is a stub.** `src/core/engine_api.gd:763` prints to console
   and does not render. **No toast-based onboarding beat can ship without
   either (a) upgrading `show_message` to route to an active HUD surface via
   a registered renderer, or (b) adding the `show_toast` action of §6.3.**
   This is a framework gap, not an onboarding gap — flagging it here because
   onboarding is the first feature that hits it.

2. **`check_variable` / `set_variable` do not persist.** `EngineAPI._variables`
   is cleared on pack unload (`game_pack_loader.gd:199`). The one-shot-per-save
   contract in `ONBOARDING_PLAN.md` (rule 2 and each beat's "Dismissal") is
   unsatisfiable without save-backed conditions/actions. This is why §6.2 and
   §6.4 exist. An alternative is to teach `EngineAPI._variables` to
   write-through to `SaveSystem` under a reserved namespace and turn the
   existing `check_variable`/`set_variable` into persistent operators —
   cleaner, but a behavior change that would affect every other `check_variable`
   consumer. For this ticket, net-new handlers are safer.

3. **`wave_started` has no `is_boss` field.** The plan proposes a local
   `WAVE_CONFIGS[current_wave].is_boss` lookup inside the listener. The
   TriggerSystem equivalent is §6.5's pack-scoped `is_boss_wave` condition,
   or a new `boss_wave_started` EventBus event. Prefer the former — fewer
   events in flight, and the extension point exists (`trigger_system.gd:131`).

4. **A2 overlay fidelity is not data-expressible.** Labelled arrows anchored
   to live child nodes of a modal cannot be JSON. `ONBOARDING_PLAN.md §N`
   already schedules a `rogue_onboarding_overlay.gd` module for exactly this.
   This spec downgrades A2 to a triple-toast because the task constraint
   is "avoiding net-new game code as far as possible" — an overlay
   widget is clearly net-new code. If the overlay is mandatory, delete
   the A2 JSON block and ship it via the module instead (the "one effect,
   one implementation path" rule from `CLAUDE.md` rule #6 forbids shipping
   both).

5. **A1's "pulsing cyan label over the hero"** (the recoloured
   `_boss_warning_label` from `rogue_spawner.gd:205`) is likewise not JSON.
   Same options as A2: accept toast-only fidelity, or add a `spawn_world_label`
   action (then budget grows to 5 new framework handlers). Default in this spec
   is toast-only.

6. **A3's 1.5 s vignette pulse** via `rogue_vfx.spawn_vfx` is not JSON. Same
   trade-off. If a `play_vfx` action is desired, add a 6th handler that calls
   `EngineAPI.get_system("vfx").spawn_vfx(id, pos)` — one line, but another
   budget hit.

7. **Event name `wave_started` is double-emitted.** `ONBOARDING_PLAN.md`'s
   inventory notes that `rogue_spawner.gd:95` also emits `wave_started` on
   the `_gm` bus with a different payload (`wave_index`, `enemy_count`).
   `_gm.emit` routes to the same EventBus, so the TriggerSystem listener will
   fire on **both** emissions with **different payload shapes**. `$event.wave`
   resolves for the wave-system version but returns `null` for the spawner
   version (it carries `wave_index`, not `wave`). With `compare_event_value`
   returning false on null-vs-number, this is self-filtering — the trigger only
   fires for the correct emitter. Document this carefully if `once: true` is
   ever relied on: the `fired_count` still increments once across both
   emissions, which is the desired behavior here but may surprise future
   rule authors. Consider consolidating the two emitters as a follow-up.

8. **Pack-unload vs trigger lifetime.** `TriggerSystem._triggers` is not
   cleared on pack unload (it lives on the framework-level
   `/root/Systems/TriggerSystem` from `src/main.tscn:79`). Re-loading the pack
   re-registers the same `id`s via `register_trigger`, which **overwrites**
   each entry (`trigger_system.gd:34`). `fired_count` therefore resets on
   pack reload, which is fine here because the persistent gate lives in
   `SaveSystem`, not in `once`. Worth noting so nobody relies on `once: true`
   for cross-run state in the future.

9. **Copy length.** All toasts in §1–§4 fit in `rogue_hud_announce`'s 12pt
   RichTextLabel at 0.275-screen width. `TUTORIAL_BOND_FIRST` is the longest
   in the plan (~25 CN chars / ~80 EN chars) — borderline. Implementation
   ticket should verify wrap behavior; if it breaks, shorten the keys' values
   rather than changing the framework.

10. **I18n fallback.** `I18n.t("KEY")` returns the key itself when missing
    (verified indirectly via `engine_api.gd:759`). If the translation keys
    ship in the JSON but the `lang/*.json` pack forgets them, players will see
    `TUTORIAL_WELCOME_MOVE` in-game. This is survivable but ugly — the
    implementation ticket should add a lint step that greps every
    `"i18n_key"` value in trigger JSON against `lang/en.json` and
    `lang/zh_CN.json` keys at pack boot. Not blocking.

---

*Spec author: Claude (Opus 4.7) | Date: 2026-04-25 | Grounded in:
`src/systems/trigger_system.gd`, `src/gamepack/game_pack_loader.gd`,
`src/gamepack/game_pack_script.gd`, `src/core/engine_api.gd`,
`gamepacks/rogue_survivor/rules/combat_rules.json`,
`gamepacks/rogue_survivor/pack.json`, and the emitter inventory in
`docs/ONBOARDING_PLAN.md`.*
