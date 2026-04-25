# Theme Bonds Fix Notes

Scope: align `gamepacks/rogue_survivor/theme_bonds.json` `required_sets` IDs with the canonical
`id` field of every `gamepacks/rogue_survivor/spells/*_set_bonus.json` file, and confirm the JSON
is loaded by a real loader.

## (a) ID corrections applied

Every `*_set_bonus.json` in `spells/` declares its `id` field as `<base>_set_bonus` (verified by
reading every file and printing the `id` field). The bonds JSON was using bare or aliased names.
The full remap, every entry verified against an existing file:

| theme_bonds.json (old) | spells/<file>           | new ID                  |
| ---------------------- | ----------------------- | ----------------------- |
| `flame`                | flame_set_bonus.json    | `flame_set_bonus`       |
| `frost`                | frost_set_bonus.json    | `frost_set_bonus`       |
| `lightning_chain`      | lightning_set_bonus.json| `lightning_set_bonus`   |
| `guardian`             | guardian_set_bonus.json | `guardian_set_bonus`    |
| `war_machine`          | war_machine_set_bonus.json | `war_machine_set_bonus` |
| `blood_moon`           | blood_moon_set_bonus.json | `blood_moon_set_bonus` |
| `barrage`              | barrage_set_bonus.json  | `barrage_set_bonus`     |
| `shadow_blade`         | shadow_blade_set_bonus.json | `shadow_blade_set_bonus` |
| `poison`               | poison_set_bonus.json   | `poison_set_bonus`      |
| `vampire`              | vampire_set_bonus.json  | `vampire_set_bonus`     |
| `healer`               | healer_set_bonus.json   | `healer_set_bonus`      |
| `reaper`               | reaper_set_bonus.json   | `reaper_set_bonus`      |
| `crit_master`          | crit_set_bonus.json     | `crit_set_bonus`        |
| `time_lord`            | time_lord_set_bonus.json | `time_lord_set_bonus`  |
| `void_walker`          | void_walker_set_bonus.json | `void_walker_set_bonus` |
| `dragon_force`         | dragon_force_set_bonus.json | `dragon_force_set_bonus` |
| `fate_wheel`           | fate_wheel_set_bonus.json | `fate_wheel_set_bonus` |
| `alchemist`            | alchemist_set_bonus.json | `alchemist_set_bonus`  |
| `elementalist`         | elementalist_set_bonus.json | `elementalist_set_bonus` |
| `soul_harvest`         | soul_harvest_set_bonus.json | `soul_harvest_set_bonus` |
| `storm_bringer`        | storm_set_bonus.json    | `storm_set_bonus`       |
| `swift_wind`           | swift_set_bonus.json    | `swift_set_bonus`       |
| `tracker`              | tracker_set_bonus.json  | `tracker_set_bonus`     |
| `summoner`             | summoner_new_set_bonus.json | `summoner_new_set_bonus` |
| `weakness_hunter`      | weakness_set_bonus.json | `weakness_set_bonus`    |
| `ice_fire`             | ice_fire_set_bonus.json | `ice_fire_set_bonus`    |
| `eternity`             | eternity_set_bonus.json | `eternity_set_bonus`    |
| `genesis`              | genesis_set_bonus.json  | `genesis_set_bonus`     |
| `apocalypse`           | apocalypse_set_bonus.json | `apocalypse_set_bonus` |

26 `required_sets` entries rewritten across 26 bonds; every replacement traces to a verified
file. The post-edit JSON parses cleanly (`json.load` returns 26 bond dicts).

Aliases that the prior code review flagged are confirmed and resolved:

- `lightning_chain` → `lightning_set_bonus`
- `crit_master` → `crit_set_bonus`
- `storm_bringer` → `storm_set_bonus`
- `swift_wind` → `swift_set_bonus`
- `weakness_hunter` → `weakness_set_bonus`
- `summoner` → `summoner_new_set_bonus` (the only `*_new_*` set on disk)

## (b) Loader status — already wired, but a deeper plumbing gap remains

`theme_bonds.json` is loaded by `gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd`
(`RogueThemeBond._load_bonds` at line 14, reading
`_gm.pack.pack_path.path_join("theme_bonds.json")`). The module is instantiated at
`scripts/rogue_game_mode.gd:133-134` and `check_bonds()` is invoked from
`scripts/rogue_card_ui.gd:400-401` and `:570-571` after card selection. So the wiring at the
*loader* level is intact — no new loader call is needed for this task.

**Caveat / TODO that is out of scope for this task but worth flagging:**
`RogueThemeBond` resolves `required_sets` against `_gm._card_manager._get_set_def(sid)` and
`_gm._card_manager.get_completed_sets()`. In the current tree, `rogue_game_mode.gd:42` declares
`var _card_manager = null` and there is **no assignment site anywhere in the pack** (verified
with grep `_card_manager\s*=` — the only writer is the declaration itself; every other site is a
`== null` guard or a method call). The legacy `card_sets.json` and `cards/*.json` that fed the
old `RogueCardManager` are deleted on the current branch. Net effect at runtime: `check_bonds()`
iterates `_all_bonds`, calls `_gm._card_manager.get_completed_sets()` on null, and would crash on
the first card pick — except every UI caller is also gated `if _gm._card_manager == null:
return`, so the bond loop never even runs.

In short:

- Loader for the *file* on disk: **wired**.
- Resolution of `required_sets` IDs against actual game state: **dead code** until either
  - `RogueThemeBond` is rewritten to look up sets via the new `RogueCardSystem._all_bonds` /
    set-bonus spell IDs (now that `required_sets` carries `*_set_bonus` IDs, this becomes a
    direct match), or
  - `_card_manager` is reinstated and re-fed by the new card pipeline.

I did not make that change here because the task said do not guess where to wire if uncertain,
and because choosing between the two paths is a design decision (the new system in
`rogue_card_system.gd` uses a different bond model — `bond_id` per card, numeric IDs in
`data/spells.json` with `type=bond` — that does not have a clean "completed set" notion). A
follow-up should decide whether `theme_bonds.json` belongs in the new world at all.

## (c) Bonds with no fixable set match

None. Every `required_sets` entry across all 26 bonds maps to a real `*_set_bonus.json` file.

## (d) Sets on disk with no bond reference (potential design gap)

- `splitter_set_bonus` (`spells/splitter_set_bonus.json`) — exists on disk, no theme bond
  mentions it. This may be a deliberate "single-set only" design or an oversight; flagging for
  designer review rather than inventing a bond.
