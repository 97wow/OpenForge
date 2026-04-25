# Theme Bonds — Wave A Integration

Append-only addition of 3 cross-set theme bonds to `gamepacks/rogue_survivor/theme_bonds.json` so the 6 Wave A mechanical sets (`healer`, `tracker`, `weakness`, `war_machine`, `soul_harvest`, `blood_moon`) get second-layer (cross-set) payoffs in addition to their single-set self-bonds. Closes Wave A's integration into the cross-set bonus system started in Tasks #14/#27/#28.

No existing entries were modified. Append-only.

---

## §1. New theme bonds added

| `id` | `name_key` | `required_sets` | `bonus_effects` summary | Source proposal section |
|---|---|---|---|---|
| `survivor_creed` | `BOND_SURVIVOR_CREED` | `healer_set_bonus`, `vampire_set_bonus`, `blood_moon_set_bonus` | `+0.05 hero_life_steal`, `+2.0 hero_hp_regen`, `+0.04 hero_kill_heal_pct` | §1 Healer → "Could be added to a *new* `survivor_creed` theme bond linking `healer + vampire + blood_moon` for a pure-sustain build identity." |
| `marksman_doctrine` | `BOND_MARKSMAN_DOCTRINE` | `tracker_set_bonus`, `weakness_set_bonus`, `barrage_set_bonus`, `crit_set_bonus` | `+0.15 hero_mark_damage_bonus`, `+0.15 hero_attack_range_pct`, `+0.2 hero_crit_damage_bonus` | §2 Tracker → "Strong candidate to fold into a *new* `marksman_doctrine` theme bond grouping `tracker + barrage + crit` (precision-attack identity)." Extended to include `weakness_set_bonus` per §4 Weakness Hunter ("Pairs naturally with the proposed `marksman_doctrine`"), so Wave A's weakness subclass also gets cross-set engagement. |
| `necromancer_pact` | `BOND_NECROMANCER_PACT` | `summoner_new_set_bonus`, `soul_harvest_set_bonus`, `reaper_set_bonus` | `+0.3 hero_permanent_damage_per_kill`, `+0.04 hero_summon_on_kill_chance`, `+5.0 hero_summon_duration` | §3 Summoner → "Natural fit for a *new* `necromancer_pact` theme bond pairing `summoner + soul_harvest + reaper` (death-engine identity)." Cross-referenced by §8 Soul Harvest ("Anchor candidate for the proposed `necromancer_pact`"). |

### Wave A coverage map

| Wave A set | Covered by new bond | Covered by pre-existing bond |
|---|---|---|
| `healer_set_bonus` | `survivor_creed` | `divine_protection` (with `guardian`) |
| `tracker_set_bonus` | `marksman_doctrine` | — |
| `weakness_set_bonus` | `marksman_doctrine` | — |
| `war_machine_set_bonus` | (none — see note) | `warrior_spirit` (with `guardian + blood_moon + barrage`) |
| `soul_harvest_set_bonus` | `necromancer_pact` | `soul_reaver` (with `reaper + vampire`) |
| `blood_moon_set_bonus` | `survivor_creed` | `warrior_spirit`, `berserker_fury`, `soul_reaver` (3 entries already) |

`war_machine_set_bonus` was not assigned a new bond in this batch because it is already strongly integrated via existing `warrior_spirit`, and the proposal's only fresh war-machine pairing (`siege_breaker`, §7) lives in the Wuxia/macro-identity backlog flagged for product review (§18.10 caps cross-bond proliferation). All other 5 Wave A IDs now have at least one cross-set bond.

---

## §2. Schema verification

```bash
$ python3 -c "import json; d=json.load(open('gamepacks/rogue_survivor/theme_bonds.json')); print('OK', len(d))"
OK 29
```

Per-entry schema spot-check:

```
SCHEMA[0]:        ['bonus_effects', 'desc_key', 'id', 'min_count', 'name_key', 'required_sets']
NEW survivor_creed     KEYS: ['bonus_effects', 'desc_key', 'id', 'min_count', 'name_key', 'required_sets']  BE_COUNT: 3
NEW marksman_doctrine  KEYS: ['bonus_effects', 'desc_key', 'id', 'min_count', 'name_key', 'required_sets']  BE_COUNT: 3
NEW necromancer_pact   KEYS: ['bonus_effects', 'desc_key', 'id', 'min_count', 'name_key', 'required_sets']  BE_COUNT: 3
```

All three new entries have the exact same top-level key set as the pre-existing 26 entries (`elemental_master` is the reference). Each carries 3 `bonus_effects` blocks, consistent with the median count of existing entries (range observed: 2–3). Every effect uses `"type": "SET_VARIABLE"` + `"mode": "add"` — the only effect shape that appears in the file.

---

## §3. I18n keys needed

Six new translation keys were introduced and currently exist in **no** language pack:

```
BOND_SURVIVOR_CREED
BOND_SURVIVOR_CREED_DESC
BOND_MARKSMAN_DOCTRINE
BOND_MARKSMAN_DOCTRINE_DESC
BOND_NECROMANCER_PACT
BOND_NECROMANCER_PACT_DESC
```

Verification:

```bash
$ rg "BOND_SURVIVOR_CREED|BOND_MARKSMAN_DOCTRINE|BOND_NECROMANCER_PACT" lang/
(no matches)
```

Lang files affected (each will need both name + desc strings): `lang/en.json`, `lang/zh_CN.json`, `lang/ja.json`, `lang/ko.json`. The I18nManager fallback should keep the bond functional (likely renders the raw key) until the i18n backfill lands, but UI presentation will look broken. **Flagged as follow-up task** — out of scope for this work item, intentionally aligned with how Tasks #27/#28 separated mechanical-bond JSON from the language backfill pass.

---

## §4. Magnitude rationale

All values were chosen to sit at-or-below the median of the equivalent stat key across the existing 26 entries — never exceeding the strongest existing magnitude, since these are *bonus* multi-set bonds layered on top of the underlying single-set self-bonds.

**`survivor_creed`** — `hero_life_steal: 0.05` falls inside the existing 0.03–0.08 band (mid-low; below `blood_moon` self-bond's 0.08). `hero_hp_regen: 2.0` undercuts the only existing reference in `divine_protection` (3.0) by ~33%, appropriate because survivor_creed already stacks with the healer self-bond's regen sources. `hero_kill_heal_pct: 0.04` lands between `healer` self-bond (0.05) and `soul_reaver` (0.03) — explicitly at the band median. Combined effect is a noticeable but not run-defining sustain layer.

**`marksman_doctrine`** — All three keys deliberately come in below their best existing reference: `hero_mark_damage_bonus: 0.15` (vs. `weakness_hunter` self-bond's 0.20), `hero_attack_range_pct: 0.15` (vs. `tracker` self-bond's 0.25), `hero_crit_damage_bonus: 0.2` (vs. `berserker_fury`'s 0.30). Bond pairs four sets (one more than typical), so per-stat magnitude is intentionally trimmed to keep the total power budget in line with 3-set bonds like `chaos_weaver`. Net design thesis: a precision identity that meaningfully amps marked-target crits without eclipsing the self-bond payouts.

**`necromancer_pact`** — `hero_permanent_damage_per_kill: 0.3` matches the `soul_harvest` self-bond exactly (the lower end of the 0.3–0.5 range; `soul_reaver` uses 0.5). Picking 0.3 rather than 0.5 was deliberate because §18.8 of the proposal flagged that this stat compounds across kills and the 0.80 blueprint figure already needs throttling — an additive layered bond should not push the per-kill ramp further. `hero_summon_on_kill_chance: 0.04` is just below the `summoner` self-bond's 0.05. `hero_summon_duration: 5.0` is half the `summoner` self-bond's 10.0, consistent with treating the cross-set bond as an additive seasoning rather than a duplicate of the self-bond.

---

## §5. Rollback snippet

```bash
git checkout -- gamepacks/rogue_survivor/theme_bonds.json
```

Removes the 3 appended entries and restores the file to 26 entries. No follow-up cleanup needed because this task is append-only — no existing data was modified, no other files were touched.
