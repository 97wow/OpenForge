# Sets Wave A — Applied (Task #27)

> Date: 2026-04-25
> Source plan: `docs/SETS_EXPANSION_PROPOSAL.md` §17 Wave A
> Outcome: shipped bond count 14 → **20** in `gamepacks/rogue_survivor/data/spells.json`

## §1. Sets materialized

All six Wave A `spells/<name>_set_bonus.json` blueprints **already existed** at task start (verified: id field matches proposal verbatim, schema matches the canonical reference). Per safety rail "Do NOT modify any existing `*_set_bonus.json` file", these were left untouched. The shippable delta for this task was the 6 missing draftable bond entries in `data/spells.json`.

| # | Set (CN / EN) | bond_id | subclass | required | Blueprint file (lines) | i18n keys referenced |
|---|---|---|---|---|---|---|
| 1 | 治愈者 / Healer | **90** | `healer` | 2 | `spells/healer_set_bonus.json` (20) — pre-existing | `SET_HEALER`, `SET_HEALER_DESC` |
| 2 | 追踪者 / Tracker | **91** | `tracker` | 2 | `spells/tracker_set_bonus.json` (20) — pre-existing | `SET_TRACKER`, `SET_TRACKER_DESC` |
| 3 | 弱点猎手 / Weakness Hunter | **93** | `weakness_hunter` | 2 | `spells/weakness_set_bonus.json` (20) — pre-existing | `SET_WEAKNESS_HUNTER`, `SET_WEAKNESS_HUNTER_DESC` |
| 4 | 战争机器 / War Machine | **96** | `war_machine` | 3 | `spells/war_machine_set_bonus.json` (27) — pre-existing | `SET_WAR_MACHINE`, `SET_WAR_MACHINE_DESC` |
| 5 | 灵魂收割 / Soul Harvest | **97** | `soul_harvest` | 3 | `spells/soul_harvest_set_bonus.json` (27) — pre-existing | `SET_SOUL_HARVEST`, `SET_SOUL_HARVEST_DESC` |
| 6 | 血月 / Blood Moon | **99** | `blood_moon` | 3 | `spells/blood_moon_set_bonus.json` (27) — pre-existing | `SET_BLOOD_MOON`, `SET_BLOOD_MOON_DESC` |

bond_id 92, 94, 95, 98 reserved for Wave B; 100 already taken by `item: consumable`; 101–106 reserved for Wave C — none allocated this wave.

**Schema notes:**
- Existing 14 bonds in `data/spells.json` use schema `{type, subclass, required, stats}` only — no `name_key`/`desc_key`.
- New entries follow the proposal's tightened skeleton **with** `name_key`/`desc_key` (per proposal §1–§10 and procedure step 5b "Add all required name_key / desc_key strings"). These fields are additive metadata; the live bond display still resolves names via numeric-id lookup in `spells_<lang>.json` (see `rogue_card_system.gd:818 get_spell_name`). The new keys document i18n debt for §3 below — they are not yet wired through any code path.
- Bond entries appended at the end of the JSON object in numeric order (90 → 91 → 93 → 96 → 97 → 99). No existing entry was modified.

## §2. Validation output

```
$ python3 -c "import json; d = json.load(open('gamepacks/rogue_survivor/data/spells.json')); print('OK', len(d), 'entries')"
OK 76 entries

$ python3 -c "import json; [json.load(open(p)) for p in ['gamepacks/rogue_survivor/spells/healer_set_bonus.json','gamepacks/rogue_survivor/spells/tracker_set_bonus.json','gamepacks/rogue_survivor/spells/weakness_set_bonus.json','gamepacks/rogue_survivor/spells/war_machine_set_bonus.json','gamepacks/rogue_survivor/spells/soul_harvest_set_bonus.json','gamepacks/rogue_survivor/spells/blood_moon_set_bonus.json']]"
(no output → all 6 parse cleanly)

$ grep -c '"type": "bond"' gamepacks/rogue_survivor/data/spells.json
20    # was 14 before edit; +6 ✓

$ python3 (duplicate check)
duplicate ids: False    # 20 unique bond ids
```

Bond ids enumerated post-edit: 19, 20, 21, 22, 23, 30, 38, 42, 51, 56, 64, 71, 80, 89, **90, 91, 93, 96, 97, 99**.

## §3. I18n keys needed (follow-up, do not translate here)

`lang/en.json` already contains 5 of the 6 `SET_*` name keys (added under an earlier task — verified at `lang/en.json:402-411`):

- ✅ `SET_HEALER`, `SET_TRACKER`, `SET_WAR_MACHINE`, `SET_SOUL_HARVEST`, `SET_BLOOD_MOON` — present in en.json (also confirmed present in `lang/zh_CN.json`, `lang/ja.json`, `lang/ko.json` via `Grep`).
- ❌ `SET_WEAKNESS_HUNTER` — **missing in all 4 lang packs**.

**All six `*_DESC` keys are missing in all 4 lang packs:**

- `SET_HEALER_DESC`
- `SET_TRACKER_DESC`
- `SET_WEAKNESS_HUNTER_DESC`
- `SET_WAR_MACHINE_DESC`
- `SET_SOUL_HARVEST_DESC`
- `SET_BLOOD_MOON_DESC`

Total i18n debt to retire in a follow-up task: **1 missing name key + 6 missing desc keys = 7 keys × 4 languages = 28 string additions**. Suggested CN copy lives under each set's "EN flavor / CN flavor" entry in `docs/SETS_EXPANSION_PROPOSAL.md` §1–§10.

Additionally, the live bond-display code path resolves name/desc through `gamepacks/rogue_survivor/data/spells_<lang>.json` keyed by **numeric bond id** (`"90" → {name, desc}`), not by `SET_*` keys. To make these new bonds player-visible without a code change, the same follow-up should add `"90"` … `"99"` entries to all four `spells_*.json` files (currently they end at id `"89"`).

## §4. Rollback snippet

The 6 spell blueprint files were **not** created or modified by this task (they pre-existed) — `rm` is **not** appropriate for them. Only `data/spells.json` was edited:

```bash
# Single-file rollback (revert to pre-task state):
git checkout -- gamepacks/rogue_survivor/data/spells.json

# Plus the new doc:
rm docs/SETS_WAVE_A_APPLIED.md
```

If a later task does ship blueprint edits and they need rollback, re-evaluate at that time.

## §5. Next wave recommendation

Wave B (`summoner #92, shadow_blade #94, alchemist #95, ice_fire #98, dragon_force #103, eternity #104`) **cannot** be shipped the same way. The proposal's §17 Wave B rationale is that each set's draft cards depend on net-new ProcManager handlers (`summon_minion`, `swap_school_fire_frost`, `school_immunity`, `revive_full`, etc.) and new proc trigger flags (`on_hit_from_behind`, `on_hit_frozen_target_with_fire`, `on_low_hp`). The bond entries themselves *could* be added cheaply — but doing so without the cards/handlers means the bond is undraftable (no cards reference it) and therefore unobservable, which defeats the point. Recommend bundling Wave B into a single task that ships the handler stubs alongside the bond + card entries.

Wave C (`fate_wheel #101, void_walker #102, genesis #105, apocalypse #106`) requires bigger framework work (weighted random-proc tables, blink-to-target movement primitive, `screen_wipe` effect, designer brief for `genesis` reshape semantics). Should not be attempted before Wave B lands.
