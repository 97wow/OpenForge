# Sets Expansion Proposal — 14 → 30 Set-Bonus Archetypes

> Date: 2026-04-25
> Source: `docs/GAME_DESIGN_PLAN.md` §2.4 (target 30+ sets, current 14 + planned 16)
> Schema reference: `gamepacks/rogue_survivor/spells/*_set_bonus.json` (effect blueprints) and `gamepacks/rogue_survivor/data/spells.json` `type: "bond"` entries (player-facing draftable bonds)

---

## 0. Pre-flight findings (read before reviewing the 16 sections)

### 0.1 The "14 shipped sets" the design plan cites are not the same 14 the player drafts today

Two parallel set systems coexist in the GamePack:

1. **SpellSystem effect blueprints** — 30 `spells/*_set_bonus.json` files. Loaded by `GamePackLoader` into the framework's SpellSystem registry. Effect-only, not player-facing. **All 16 of the planned expansion sets already have a blueprint here** (see §0.3 below).
2. **Draftable bonds** — 14 `type: "bond"` entries in `data/spells.json`, IDs 19, 20, 21, 22, 23, 30, 38, 42, 51, 56, 64, 71, 80, 89. These are what `rogue_card_system.gd` reads when populating the 3-pick draft. Their `subclass` strings are `preparation / economy / artillery / vitamin / master / wuxia / dragon_ball / tianlong / navy_admiral / yonko / akatsuki / wuxia_legend / realm / hero_legend` — i.e. an anime/wuxia card-pool experiment that does **not** thematically map to the 14 design-plan names (splitter / swift / flame / frost / vampire / poison / barrage / lightning / crit / element / guardian / reaper / storm / time_lord).

This means "expanding 14 → 30" is ambiguous. **This proposal assumes the user-visible bond list in `data/spells.json` is what needs to grow.** The 16 new bond entries proposed below would coexist with (or eventually replace) the current 14 anime/wuxia bonds. If product intends to keep the wuxia bonds as a separate "collection" pool, then the 16 new bonds become an additive set bringing the total draftable bond count to 30 (14 wuxia + 16 archetype-themed). Either interpretation works for the JSON skeletons below; only the rollout decision differs (see §17 and §18.1).

### 0.2 What is "already done" vs. what this proposal adds

Component | Status before this proposal | What this proposal adds
---|---|---
SpellSystem effect blueprint (`spells/<name>_set_bonus.json`) | ✅ All 16 already exist | Documents each existing blueprint; flags magnitudes that may need re-tuning for the draftable system; does **not** rewrite them
Cross-set theme bond (`theme_bonds.json`) | ✅ All 16 already have entries (single-set "self-bonds" in addition to the 11 multi-set theme bonds) | Lists 1-2 multi-set theme bond linkages worth strengthening per new bond
Draftable bond (`data/spells.json` `type: "bond"`) | ❌ None of the 16 is wired | Proposes a `bond_id`, `subclass`, `required`, `stats` skeleton per bond
Cards (`data/spells.json` `type: "card"`) referencing the bond | ❌ Not authored | Proposes 2-3 candidate card archetypes per bond (titles + flavor only, no full card bodies)
i18n keys | ❌ Not authored | Names the keys the wiring will need (`SET_<NAME>` / `SET_<NAME>_DESC`)

### 0.3 Bond ID allocation

Used IDs in `data/spells.json`: 19, 20, 21, 22, 23, 30, 38, 42, 51, 56, 64, 71, 80, 89.
Item ID 100 is also taken (`type: "item", subclass: "consumable"`).

Allocated for the 16 new bonds (skipping 100):

ID | Set (CN) | Set (EN) | Rarity / threshold
---|---|---|---
90 | 治愈者 | Healer | 蓝 / `required: 2`
91 | 追踪者 | Tracker | 蓝 / `required: 2`
92 | 召唤师 | Summoner | 蓝 / `required: 2`
93 | 弱点猎手 | Weakness Hunter | 蓝 / `required: 2`
94 | 影刃 | Shadow Blade | 紫 / `required: 3`
95 | 炼金师 | Alchemist | 紫 / `required: 3`
96 | 战争机器 | War Machine | 紫 / `required: 3`
97 | 灵魂收割 | Soul Harvest | 紫 / `required: 3`
98 | 冰火双重 | Ice & Fire | 紫 / `required: 3`
99 | 血月 | Blood Moon | 紫 / `required: 3`
101 | 命运之轮 | Wheel of Fate | 橙 / `required: 4`
102 | 虚空行者 | Void Walker | 橙 / `required: 4`
103 | 龙之力 | Dragon Force | 橙 / `required: 4`
104 | 永恒 | Eternity | 橙 / `required: 4`
105 | 创世 | Genesis | 橙 (终极) / `required: 5`
106 | 毁灭 | Apocalypse | 橙 (终极) / `required: 5`

`required` follows the design-plan rarity convention (蓝=2, 紫=3, 橙=4, ultimate-橙=5). The current 14 wuxia bonds use `required` values of 1, 2, 3 and 7 — none are 4 or 5, so the ultimate-tier draft thresholds proposed here are new territory for the existing UI; flagged in §18.

### 0.4 Power-band guard rail

Per task constraint, no proposed magnitude exceeds the strongest existing set's magnitude by more than ~30%. The shipped ceilings I'm calibrating against:

- **AOE damage proc damage_pct**: existing max is 2.5 (yonko card 48). Cap proposed: 3.0.
- **Bonus-damage `base_damage`**: existing max is 300 (yonko card 46). Cap proposed: 380.
- **`scaling_coef`** on bonus-damage procs: existing max is 0.40 (yonko card 46). Cap proposed: 0.50.
- **Periodic interval lower bound**: existing min is 4.0s (yonko card 47). Cap proposed: 3.0s for the ultimate-tier 橙 sets only.
- **`chance` on `on_hit` procs**: existing max is 0.15 (yonko card 47). Cap proposed: 0.18.
- **Set-bonus blueprint `base_points`**: existing apocalypse `hero_screen_nuke_cooldown: 60` and dragon_force `hero_dragon_breath_damage: 30` are the loudest numbers; nothing in the new bonds should escalate either pattern.

---

## 1. 治愈者 / Healer (Bond #90 — Blue)

- **EN flavor**: *Every kill mends, every breath rebuilds the wall.*
- **CN flavor**: *每次击杀都是一次回血，每次呼吸都在重筑壁垒。*
- **`id`**: `healer_set_bonus` ✅ already exists at `spells/healer_set_bonus.json`.

### Existing blueprint (verbatim, do not rewrite)

```json
{
  "id": "healer_set_bonus", "school": "holy",
  "effects": [
    { "type": "SET_VARIABLE", "key": "hero_kill_heal_pct",   "base_points": 0.05, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_shield_interval", "base_points": 15,   "mode": "add", "target": { "category": "SELF" } }
  ]
}
```

### Proposed `data/spells.json` bond entry skeleton

```json
"90": {
  "type": "bond", "subclass": "healer",
  "name_key": "SET_HEALER",
  "desc_key": "SET_HEALER_DESC",
  "required": 2,
  "stats": {}
}
```

(Note: `name_key` / `desc_key` are not used by the existing 14 wuxia bonds — they pull labels from a different code path. Adding these keys here is a conscious tightening; see §18.4.)

### Card slot impact

Needs **2 new cards** (Blue, both `tier: 1`, both `bond_id: 90`):

1. **`heal_1` — 生命甘露 / Vital Tincture** — flat HP + small `hero_hp_regen` stat bump.
2. **`heal_2` — 圣盾时刻 / Hallowed Moment** — `proc { trigger: "on_kill", chance: 0.10, effect: "shield", value: <flat>, cooldown: 6.0 }`.

Both cards' `consume_condition` should mirror the wuxia bonds' `{ "type": "bond_count", "bond_id": 90, "count": 2 }`.

### Cross-set theme bond opportunities

- `divine_protection` (existing, `theme_bonds.json:38`) already pairs `healer_set_bonus` with `guardian_set_bonus` — wiring the new bond will activate this immediately, no theme-bond changes needed.
- Could be added to a *new* `survivor_creed` theme bond linking `healer + vampire + blood_moon` for a pure-sustain build identity.

### Difficulty-curve note

Should appear in the draft pool from **N1 onward** — it's the canonical "first sustain" set and validates the new wiring at the easiest difficulty.

---

## 2. 追踪者 / Tracker (Bond #91 — Blue)

- **EN flavor**: *Arrows that remember faces. Range that forgets walls.*
- **CN flavor**: *记得每张面孔的箭矢，无视一切距离。*
- **`id`**: `tracker_set_bonus` ✅ already exists.

### Existing blueprint

```json
{
  "id": "tracker_set_bonus", "school": "physical",
  "effects": [
    { "type": "SET_VARIABLE", "key": "hero_attack_range",     "base_points": 0.8, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_homing_projectile","base_points": 1,   "mode": "add", "target": { "category": "SELF" } }
  ]
}
```

### Proposed bond entry

```json
"91": {
  "type": "bond", "subclass": "tracker",
  "name_key": "SET_TRACKER",
  "desc_key": "SET_TRACKER_DESC",
  "required": 2,
  "stats": {}
}
```

### Card slot impact

**2 new cards** (Blue, `tier: 1`):

1. **`track_1` — 鹰眼标记 / Eagle's Mark** — `agi` stat + `hero_attack_range` stat token.
2. **`track_2` — 归位之矢 / Returning Shaft** — `proc { trigger: "on_hit", chance: 0.10, effect: "homing_seek_next", count: 1, cooldown: 0 }` (relies on existing homing system).

### Cross-set theme bonds

- Existing single-bond entry `tracker` (`theme_bonds.json:128`) — auto-active at min_count 2.
- Strong candidate to fold into a *new* `marksman_doctrine` theme bond grouping `tracker + barrage + crit` (precision-attack identity).

### Difficulty-curve note

**N1–N3** — pairs with early-game ranged starter heroes; the homing flag is mostly QoL until N4 enemies start zigzagging.

---

## 3. 召唤师 / Summoner (Bond #92 — Blue)

- **EN flavor**: *Death is just an interview for new help.*
- **CN flavor**: *死亡只是新仆从的入职面试。*
- **`id`**: `summoner_new_set_bonus` ✅ already exists. (Filename retains the `_new_` suffix from a prior iteration; flagged in §18.5.)

### Existing blueprint

```json
{
  "id": "summoner_new_set_bonus", "school": "nature",
  "effects": [
    { "type": "SET_VARIABLE", "key": "hero_summon_on_kill_chance", "base_points": 0.20, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_summon_damage_bonus",   "base_points": 0.30, "mode": "add", "target": { "category": "SELF" } }
  ]
}
```

### Proposed bond entry

```json
"92": {
  "type": "bond", "subclass": "summoner",
  "name_key": "SET_SUMMONER",
  "desc_key": "SET_SUMMONER_DESC",
  "required": 2,
  "stats": {}
}
```

### Card slot impact

**2 new cards** (Blue, `tier: 1`):

1. **`summon_1` — 灵能契约 / Spirit Pact** — `int` stat + flat `hero_summon_on_kill_chance` token. Probably needs an attached `proc { trigger: "on_kill", chance: 0.15, effect: "summon_minion", duration: 8 }`.
2. **`summon_2` — 群鼠齐鸣 / Skitter Chorus** — `proc { trigger: "periodic", interval: 12, effect: "summon_minion", count: 2, duration: 10 }`.

`effect: "summon_minion"` does not appear in any existing card; will need a ProcManager handler unless we reuse `summon_puppet` from card 59. Flagged in §18.6.

### Cross-set theme bonds

- Existing single-bond entry `summoner` (`theme_bonds.json:139`).
- Natural fit for a *new* `necromancer_pact` theme bond pairing `summoner + soul_harvest + reaper` (death-engine identity).

### Difficulty-curve note

**N2–N4** — minion AI cost is non-trivial; introducing summons this early stresses the minion-cap before players learn to manage it.

---

## 4. 弱点猎手 / Weakness Hunter (Bond #93 — Blue)

- **EN flavor**: *Mark first. Strike harder. Repeat.*
- **CN flavor**: *先标记弱点，再狠狠出手。如此循环。*
- **`id`**: `weakness_set_bonus` ✅ already exists.

### Existing blueprint

```json
{
  "id": "weakness_set_bonus", "school": "physical",
  "effects": [
    { "type": "SET_VARIABLE", "key": "hero_mark_damage_amp", "base_points": 0.15, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_mark_duration",   "base_points": 6,    "mode": "add", "target": { "category": "SELF" } }
  ]
}
```

### Proposed bond entry

```json
"93": {
  "type": "bond", "subclass": "weakness_hunter",
  "name_key": "SET_WEAKNESS_HUNTER",
  "desc_key": "SET_WEAKNESS_HUNTER_DESC",
  "required": 2,
  "stats": {}
}
```

### Card slot impact

**2 new cards** (Blue, `tier: 1`):

1. **`weak_1` — 破甲箭 / Sundering Arrow** — `agi` stat + `proc { trigger: "on_hit", chance: 0.20, cooldown: 1.5, effect: "apply_mark", duration: 4 }`.
2. **`weak_2` — 标的之眼 / Marker's Eye** — flat `crit_rate` + `proc { trigger: "on_crit", effect: "extend_mark", duration: 2 }`.

`effect: "apply_mark"` / `extend_mark` need ProcManager handlers; HealthComponent likely needs a `marked` aura with stacking semantics. Flagged in §18.6.

### Cross-set theme bonds

- Existing single-bond entry `weakness_hunter` (`theme_bonds.json:150`).
- Pairs naturally with the proposed `marksman_doctrine` (see #2) and with `crit_set_bonus` for a "marked-then-crit" identity.

### Difficulty-curve note

**N3+** — payoff scales with target HP, so it underperforms vs. trash mobs in N1-N2 and shines once elite/boss density rises.

---

## 5. 影刃 / Shadow Blade (Bond #94 — Purple)

- **EN flavor**: *Strike the spine first; the eyes won't catch up.*
- **CN flavor**: *先击脊柱，再让目光追不上你。*
- **`id`**: `shadow_blade_set_bonus` ✅ already exists.

### Existing blueprint

```json
{
  "id": "shadow_blade_set_bonus", "school": "shadow",
  "effects": [
    { "type": "SET_VARIABLE", "key": "hero_shadow_damage_pct",   "base_points": 0.20, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_backstab_damage_pct", "base_points": 0.30, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_stealth_kill_mana",   "base_points": 10,   "mode": "add", "target": { "category": "SELF" } }
  ]
}
```

### Proposed bond entry

```json
"94": {
  "type": "bond", "subclass": "shadow_blade",
  "name_key": "SET_SHADOW_BLADE",
  "desc_key": "SET_SHADOW_BLADE_DESC",
  "required": 3,
  "stats": {}
}
```

### Card slot impact

**3 new cards** (Purple, `tier: 2`):

1. **`shadow_1` — 暗影渗透 / Shade Walk** — `agi` stat + `proc { trigger: "periodic", interval: 20, effect: "stealth_buff", duration: 3 }`.
2. **`shadow_2` — 背刺刀法 / Spinepiercer** — `crit_rate` + `proc { trigger: "on_hit_from_behind", chance: 0.50, effect: "double_damage", cooldown: 1 }`.
3. **`shadow_3` — 致命收割 / Lethal Reap** — `proc { trigger: "on_stealth_kill", effect: "restore_mana", value: 10 }`.

Requires `from_behind` positional check (does not exist in the current proc flag list — see §18.6) and a stealth aura that turns the hero into an invalid target for enemy AI.

### Cross-set theme bonds

- Existing `shadow_arts` (`theme_bonds.json:27`) already pairs `shadow_blade + poison + vampire` — auto-active.
- Could chain with `void_walker` for a "shadowstep + backstab" combo theme — propose a *new* `shadow_dance` (shadow_blade + void_walker + reaper).

### Difficulty-curve note

**N4+** — the back-damage angle math is unforgiving on dense waves; in early difficulties the bonus rarely triggers.

---

## 6. 炼金师 / Alchemist (Bond #95 — Purple)

- **EN flavor**: *Mix two elements. Pray for a third.*
- **CN flavor**: *混合两种元素，祈祷出现第三种。*
- **`id`**: `alchemist_set_bonus` ✅ already exists.

### Existing blueprint

```json
{
  "id": "alchemist_set_bonus", "school": "nature",
  "effects": [
    { "type": "SET_VARIABLE", "key": "hero_random_element_chance", "base_points": 0.30, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_element_damage_pct",    "base_points": 0.25, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_element_fusion_damage", "base_points": 50,   "mode": "add", "target": { "category": "SELF" } }
  ]
}
```

### Proposed bond entry

```json
"95": {
  "type": "bond", "subclass": "alchemist",
  "name_key": "SET_ALCHEMIST",
  "desc_key": "SET_ALCHEMIST_DESC",
  "required": 3,
  "stats": {}
}
```

### Card slot impact

**3 new cards** (Purple, `tier: 2`):

1. **`alch_1` — 元素易容 / Elemental Glamour** — `proc { trigger: "on_hit", chance: 0.30, effect: "reroll_damage_school" }` (frost/fire/nature/shadow random).
2. **`alch_2` — 混合反应 / Catalysis** — `proc { trigger: "on_hit", chance: 0.15, effect: "fusion_burst", damage_pct: 1.5, cooldown: 2 }`.
3. **`alch_3` — 转化术 / Transmutation** — `proc { trigger: "on_kill", chance: 0.10, effect: "drop_random_potion" }`.

### Cross-set theme bonds

- Existing `chaos_weaver` (`theme_bonds.json:83`) pairs `fate_wheel + alchemist + elementalist` — auto-active.
- Reasonable secondary linkage with `ice_fire` (school overlap) and `flame + frost + lightning` element-master clusters.

### Difficulty-curve note

**N3-N5** — the random school re-roll has neutral expected value at N1-N2, but starts winning once enemies have school-specific resists (currently planned for N5+ enemies; see §18.7).

---

## 7. 战争机器 / War Machine (Bond #96 — Purple)

- **EN flavor**: *Push them off the map. Then push the map off itself.*
- **CN flavor**: *把他们撞出地图。然后把地图也撞翻。*
- **`id`**: `war_machine_set_bonus` ✅ already exists.

### Existing blueprint

```json
{
  "id": "war_machine_set_bonus", "school": "physical",
  "effects": [
    { "type": "SET_VARIABLE", "key": "hero_knockback_force", "base_points": 0.8, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_armor_shred",     "base_points": 5,   "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_aoe_damage_pct",  "base_points": 0.5, "mode": "add", "target": { "category": "SELF" } }
  ]
}
```

### Proposed bond entry

```json
"96": {
  "type": "bond", "subclass": "war_machine",
  "name_key": "SET_WAR_MACHINE",
  "desc_key": "SET_WAR_MACHINE_DESC",
  "required": 3,
  "stats": {}
}
```

### Card slot impact

**3 new cards** (Purple, `tier: 2`):

1. **`war_1` — 重型护甲 / Heavy Plate** — `str` + `armor` stat bump.
2. **`war_2` — 撕甲弹 / Sundershot** — `proc { trigger: "on_hit", chance: 0.18, cooldown: 2, effect: "armor_shred", value: 3, duration: 5 }` (`chance` matches §0.4 cap).
3. **`war_3` — 冲击波 / Shockwave Launcher** — `proc { trigger: "periodic", interval: 6, effect: "aoe_damage", range: 3.5, damage_pct: 1.4 }`.

### Cross-set theme bonds

- Existing `warrior_spirit` (`theme_bonds.json:15`) groups `guardian + war_machine + blood_moon + barrage` — auto-active.
- Strong overlap with `splitter` (both push physical-AOE archetypes) — propose a *new* `siege_breaker` theme bond if product wants more macro identities.

### Difficulty-curve note

**N3+** — knockback economy starts mattering when enemy density exceeds ~30 on screen; wasted on the sparse waves of N1-N2.

---

## 8. 灵魂收割 / Soul Harvest (Bond #97 — Purple)

- **EN flavor**: *Each kill is a deposit. Compound interest is real.*
- **CN flavor**: *每次击杀都是一笔存款。复利是真的。*
- **`id`**: `soul_harvest_set_bonus` ✅ already exists.

### Existing blueprint

```json
{
  "id": "soul_harvest_set_bonus", "school": "shadow",
  "effects": [
    { "type": "SET_VARIABLE", "key": "hero_permanent_damage_per_kill", "base_points": 0.80, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_kill_crit_bonus",           "base_points": 0.08, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_soul_shockwave_threshold",  "base_points": 80,   "mode": "add", "target": { "category": "SELF" } }
  ]
}
```

> The 0.80 permanent-damage-per-kill on the bond + cards needs throttling — see §18.8. The shipped `reaper_set_bonus` uses 0.02 for the same key. The 0.80 figure here is intended as a `set` mode override but the blueprint declares `add`, so it stacks. Recommend a designer call before this bond goes live.

### Proposed bond entry

```json
"97": {
  "type": "bond", "subclass": "soul_harvest",
  "name_key": "SET_SOUL_HARVEST",
  "desc_key": "SET_SOUL_HARVEST_DESC",
  "required": 3,
  "stats": {}
}
```

### Card slot impact

**3 new cards** (Purple, `tier: 2`):

1. **`soul_1` — 灵魂烙印 / Soul Brand** — `proc { trigger: "on_kill", effect: "add_growth", stats: { "atk": 0.3 } }`.
2. **`soul_2` — 死亡收益 / Reaper's Dividend** — `proc { trigger: "on_kill", chance: 0.25, effect: "restore_mana", value: 8 }`.
3. **`soul_3` — 灵魂震波 / Soul Burst** — `proc { trigger: "kill_count", every: 80, effect: "aoe_damage", range: 4.0, damage_pct: 2.0 }` (uses the `hero_soul_shockwave_threshold` blueprint key).

### Cross-set theme bonds

- Existing `soul_reaver` (`theme_bonds.json:94`) pairs `soul_harvest + reaper + vampire` — auto-active.
- Anchor candidate for the proposed `necromancer_pact` (see #3).

### Difficulty-curve note

**N5+** — the cumulative growth makes it dominant in long runs, so it needs to enter the pool only once players reach the difficulty band where runs go past 8 minutes regularly.

---

## 9. 冰火双重 / Ice & Fire (Bond #98 — Purple)

- **EN flavor**: *Freeze. Then ignite the freezer.*
- **CN flavor**: *先冻住，再点燃冰块本身。*
- **`id`**: `ice_fire_set_bonus` ✅ already exists.

### Existing blueprint

```json
{
  "id": "ice_fire_set_bonus", "school": "fire",
  "effects": [
    { "type": "SET_VARIABLE", "key": "hero_ice_fire_alternate",   "base_points": 1,    "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_ice_fire_amp",         "base_points": 0.25, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_fusion_explosion_damage","base_points": 40, "mode": "add", "target": { "category": "SELF" } }
  ]
}
```

### Proposed bond entry

```json
"98": {
  "type": "bond", "subclass": "ice_fire",
  "name_key": "SET_ICE_FIRE",
  "desc_key": "SET_ICE_FIRE_DESC",
  "required": 3,
  "stats": {}
}
```

### Card slot impact

**3 new cards** (Purple, `tier: 2`):

1. **`if_1` — 寒火交替 / Hot-Cold Cycle** — `proc { trigger: "on_hit", effect: "swap_school_fire_frost" }` (alternates damage school every shot; uses the `hero_ice_fire_alternate` flag).
2. **`if_2` — 蒸汽爆炸 / Steam Burst** — `proc { trigger: "on_hit_frozen_target_with_fire", effect: "aoe_damage", range: 2.5, damage_pct: 2.5 }`.
3. **`if_3` — 元素双修 / Dual Mastery** — `int` + flat `hero_ice_fire_amp` token.

### Cross-set theme bonds

- No multi-set theme bond currently includes `ice_fire`. Strong candidates to add: `flame + frost + ice_fire` for a "polar-mastery" theme; or fold into existing `elemental_master` (currently `flame + frost + lightning`) by adding `ice_fire` as a 4th option.

### Difficulty-curve note

**N4+** — needs both `flame` and `frost` blueprints active in the same run for the steam-burst effect to fire reliably; before N4 the chance of having all three is too low.

---

## 10. 血月 / Blood Moon (Bond #99 — Purple)

- **EN flavor**: *Bleed in red, kill in red, breathe in red.*
- **CN flavor**: *流血是红，击杀是红，呼吸亦是红。*
- **`id`**: `blood_moon_set_bonus` ✅ already exists.

### Existing blueprint

```json
{
  "id": "blood_moon_set_bonus", "school": "physical",
  "effects": [
    { "type": "SET_VARIABLE", "key": "hero_low_hp_damage_bonus",        "base_points": 0.30, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_low_hp_attack_speed",        "base_points": 0.50, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_low_hp_invincible_duration", "base_points": 3,    "mode": "add", "target": { "category": "SELF" } }
  ]
}
```

### Proposed bond entry

```json
"99": {
  "type": "bond", "subclass": "blood_moon",
  "name_key": "SET_BLOOD_MOON",
  "desc_key": "SET_BLOOD_MOON_DESC",
  "required": 3,
  "stats": {}
}
```

### Card slot impact

**3 new cards** (Purple, `tier: 2`):

1. **`blood_1` — 染血战意 / Crimson Resolve** — `str` stat + `hero_low_hp_damage_bonus` token.
2. **`blood_2` — 不死之血 / Undying Blood** — `proc { trigger: "on_damage_taken", chance: 0.10, cooldown: 30, effect: "heal_pct", value: 0.20 }`.
3. **`blood_3` — 血月狂怒 / Lunar Frenzy** — `proc { trigger: "on_low_hp", threshold: 0.3, effect: "aspd_buff", value: 0.5, duration: 5, cooldown: 20 }`.

### Cross-set theme bonds

- Existing `berserker_fury` (`theme_bonds.json:50`) pairs `blood_moon + reaper + crit` — auto-active.
- Existing `warrior_spirit` includes `blood_moon` (see #7).

### Difficulty-curve note

**N4+** — the low-HP threshold rarely triggers in N1-N3 because runs end too fast for the hero to drop into the danger zone meaningfully.

---

## 11. 命运之轮 / Wheel of Fate (Bond #101 — Orange)

- **EN flavor**: *Every shot is a coin flip. Every flip is loaded.*
- **CN flavor**: *每一发都是抛硬币。每次抛掷都被动了手脚。*
- **`id`**: `fate_wheel_set_bonus` ✅ already exists.

### Existing blueprint

```json
{
  "id": "fate_wheel_set_bonus", "school": "holy",
  "effects": [
    { "type": "SET_VARIABLE", "key": "hero_random_effect_on_hit",     "base_points": 1, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_random_buff_interval",     "base_points": 8, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_random_crit_effect",       "base_points": 1, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_random_kill_reward_multi", "base_points": 2, "mode": "add", "target": { "category": "SELF" } }
  ]
}
```

### Proposed bond entry

```json
"101": {
  "type": "bond", "subclass": "fate_wheel",
  "name_key": "SET_FATE_WHEEL",
  "desc_key": "SET_FATE_WHEEL_DESC",
  "required": 4,
  "stats": {}
}
```

### Card slot impact

**4 new cards** (Orange, `tier: 3`):

1. **`fate_1` — 转动命轮 / Spin the Wheel** — base stats + `proc { trigger: "on_hit", chance: 0.10, effect: "random_proc_table", table_id: "fate_minor" }`.
2. **`fate_2` — 命运赏赐 / Fortune's Tip** — `proc { trigger: "periodic", interval: 8, effect: "random_buff_self", duration: 5 }`.
3. **`fate_3` — 暴击之运 / Lucky Crit** — `crit_rate` stat + `proc { trigger: "on_crit", effect: "random_proc_table", table_id: "fate_major" }`.
4. **`fate_4` — 击杀大奖 / Jackpot Kill** — `proc { trigger: "on_kill", chance: 0.05, effect: "random_drop_multi", multi: 2 }`.

The "random_proc_table" mechanic does not exist in the current ProcManager — flagged in §18.6. Tables (`fate_minor`, `fate_major`) would be a new JSON resource: a list of weighted effect entries.

### Cross-set theme bonds

- Existing `chaos_weaver` (`theme_bonds.json:83`) pairs `fate_wheel + alchemist + elementalist` — auto-active.
- High-variance bond identity makes it a good anchor for any future "wild-build" theme.

### Difficulty-curve note

**N6+** — random effects need broad table coverage to feel exciting; recommend gating until enemy/run scale gives the random pulls room to land.

---

## 12. 虚空行者 / Void Walker (Bond #102 — Orange)

- **EN flavor**: *Step through nowhere. Arrive everywhere.*
- **CN flavor**: *穿过虚无，抵达万处。*
- **`id`**: `void_walker_set_bonus` ✅ already exists.

### Existing blueprint

```json
{
  "id": "void_walker_set_bonus", "school": "shadow",
  "effects": [
    { "type": "SET_VARIABLE", "key": "hero_blink_interval",      "base_points": 4,   "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_blink_attack_speed",  "base_points": 0.6, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_shadow_clone",        "base_points": 1,   "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_slow_field_radius",   "base_points": 120, "mode": "add", "target": { "category": "SELF" } }
  ]
}
```

### Proposed bond entry

```json
"102": {
  "type": "bond", "subclass": "void_walker",
  "name_key": "SET_VOID_WALKER",
  "desc_key": "SET_VOID_WALKER_DESC",
  "required": 4,
  "stats": {}
}
```

### Card slot impact

**4 new cards** (Orange, `tier: 3`):

1. **`void_1` — 闪烁步法 / Phase Step** — `agi` stat + `proc { trigger: "periodic", interval: 4, effect: "blink_to_target", distance: 4.0 }`.
2. **`void_2` — 闪烁急袭 / Phase Strike** — `proc { trigger: "on_blink", effect: "aspd_buff", value: 0.6, duration: 2 }`.
3. **`void_3` — 暗影分身 / Shadow Clone** — `proc { trigger: "on_blink", chance: 0.25, effect: "summon_shadow_clone", duration: 6 }`.
4. **`void_4` — 时空裂缝 / Rift Wake** — `proc { trigger: "on_blink", effect: "spawn_slow_field", radius: 120, duration: 3 }`.

`blink_to_target`, `summon_shadow_clone`, `spawn_slow_field`, and the `on_blink` proc trigger are all new — flagged in §18.6.

### Cross-set theme bonds

- Existing `time_space` (`theme_bonds.json:60`) pairs `time_lord + void_walker` — auto-active.
- Strong pair with proposed `shadow_dance` (see #5).

### Difficulty-curve note

**N6+** — auto-blink is disorienting for new players; gate behind difficulties where players have learned to read positional state.

---

## 13. 龙之力 / Dragon Force (Bond #103 — Orange)

- **EN flavor**: *Wings of fire. Skin of mountain. Breath of judgment.*
- **CN flavor**: *烈焰之翼，山岳之肤，审判之息。*
- **`id`**: `dragon_force_set_bonus` ✅ already exists.

### Existing blueprint

```json
{
  "id": "dragon_force_set_bonus", "school": "fire",
  "effects": [
    { "type": "SET_VARIABLE", "key": "hero_dragon_breath_damage",    "base_points": 30,   "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_dragon_armor",            "base_points": 12,   "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_flight_speed_pct",        "base_points": 0.35, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_element_immune_duration", "base_points": 5,    "mode": "add", "target": { "category": "SELF" } }
  ]
}
```

### Proposed bond entry

```json
"103": {
  "type": "bond", "subclass": "dragon_force",
  "name_key": "SET_DRAGON_FORCE",
  "desc_key": "SET_DRAGON_FORCE_DESC",
  "required": 4,
  "stats": {}
}
```

### Card slot impact

**4 new cards** (Orange, `tier: 3`):

1. **`dragon_1` — 龙息 / Dragon Breath** — `int` stat + `proc { trigger: "periodic", interval: 6, effect: "cone_damage", angle: 60, range: 5, damage_pct: 2.0 }`.
2. **`dragon_2` — 龙鳞护甲 / Scaled Hide** — flat `armor` stat + flat `hero_dragon_armor` token.
3. **`dragon_3` — 飞行 / Flight** — `proc { trigger: "passive", effect: "ignore_collision_with_units" }`.
4. **`dragon_4` — 元素免疫 / Elemental Aegis** — `proc { trigger: "on_low_hp", threshold: 0.3, cooldown: 60, effect: "school_immunity", schools: ["fire","frost","nature","shadow"], duration: 5 }` (uses existing `ImmunitySystem`).

### Cross-set theme bonds

- Existing `dragon_slayer` (`theme_bonds.json:71`) pairs `dragon_force + flame + crit` — auto-active.
- Natural anchor for an "elite-killer" theme; pairs with `weakness_hunter` and `crit`.

### Difficulty-curve note

**N7+** — the cooldown-gated school immunity is balanced around N7-N10 boss damage; in earlier difficulties the ability rarely triggers and the orange-tier weight wastes a draft slot.

---

## 14. 永恒 / Eternity (Bond #104 — Orange)

- **EN flavor**: *Death is a difficulty toggle. You set it to "off."*
- **CN flavor**: *死亡只是个难度开关。你把它关了。*
- **`id`**: `eternity_set_bonus` ✅ already exists.

### Existing blueprint

```json
{
  "id": "eternity_set_bonus", "school": "holy",
  "effects": [
    { "type": "SET_VARIABLE", "key": "hero_revive_on_death",      "base_points": 1,    "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_invincible_interval",  "base_points": 25,   "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_all_stats_pct",        "base_points": 0.15, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_time_rewind",          "base_points": 1,    "mode": "add", "target": { "category": "SELF" } }
  ]
}
```

### Proposed bond entry

```json
"104": {
  "type": "bond", "subclass": "eternity",
  "name_key": "SET_ETERNITY",
  "desc_key": "SET_ETERNITY_DESC",
  "required": 4,
  "stats": {}
}
```

### Card slot impact

**4 new cards** (Orange, `tier: 3`):

1. **`eternity_1` — 复活 / Phoenix Clause** — `proc { trigger: "on_death", chance: 1.0, cooldown: 600, effect: "revive_full" }`.
2. **`eternity_2` — 无敌时刻 / Vow of Inviolability** — `proc { trigger: "periodic", interval: 25, effect: "invuln_buff", duration: 1.5 }`.
3. **`eternity_3` — 全属性永驻 / Boundless Attributes** — `str_pct: 0.05`, `agi_pct: 0.05`, `int_pct: 0.05`.
4. **`eternity_4` — 时间倒流 / Time Rewind** — `proc { trigger: "on_damage_taken_lethal", chance: 0.20, cooldown: 90, effect: "rewind_hp_to_pct", value: 0.5 }`.

`revive_full` and `rewind_hp_to_pct` likely overlap with the existing `cheat_death` effect (yonko card 49) — recommend reusing `cheat_death` semantics rather than authoring two near-identical effects (§18.6).

### Cross-set theme bonds

- No multi-set theme bond currently includes `eternity`. Propose a *new* `immortality_pact` linking `eternity + healer + blood_moon`.
- Pairs naturally with `genesis` for endgame builds.

### Difficulty-curve note

**N8+** — Eternity's real value is in N9/N10 where death is otherwise inevitable; it's wasted earlier.

---

## 15. 创世 / Genesis (Bond #105 — Orange ultimate)

- **EN flavor**: *Tear up the rulebook. Hand-write a new one.*
- **CN flavor**: *撕掉规则手册，亲手再写一本。*
- **`id`**: `genesis_set_bonus` ✅ already exists.

### Existing blueprint

```json
{
  "id": "genesis_set_bonus", "school": "holy",
  "effects": [
    { "type": "SET_VARIABLE", "key": "hero_all_damage_pct",         "base_points": 0.30, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_all_defense_pct",        "base_points": 0.30, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_battlefield_reshape",    "base_points": 1,    "mode": "add", "target": { "category": "SELF" } }
  ]
}
```

> The design plan flavor is "重塑战场规则" / "reshape battlefield rules" — concretely under-specified. The blueprint exposes a `hero_battlefield_reshape` flag but no GamePack code currently reads it. Treat this as a placeholder to be filled by designers (§18.9).

### Proposed bond entry

```json
"105": {
  "type": "bond", "subclass": "genesis",
  "name_key": "SET_GENESIS",
  "desc_key": "SET_GENESIS_DESC",
  "required": 5,
  "stats": {}
}
```

### Card slot impact

**5 new cards** (Orange, `tier: 4`):

1. **`genesis_1` — 万物之伤 / Sovereign Strike** — `hero_all_damage_pct +0.10`.
2. **`genesis_2` — 万物之御 / Sovereign Aegis** — `hero_all_defense_pct +0.10`.
3. **`genesis_3` — 重塑地形 / Reshape Terrain** — `proc { trigger: "on_cast", cooldown: 30, effect: "reshape_battlefield", details: "TBD" }` — placeholder.
4. **`genesis_4` — 法则编织 / Law-Weaving** — `proc { trigger: "periodic", interval: 20, effect: "rewrite_one_enemy_modifier" }` — placeholder.
5. **`genesis_5` — 创世之印 / Seal of Genesis** — capstone: `proc { trigger: "on_full_set_active", effect: "permanent_aura_amplify_all_self_buffs", value: 0.20 }`.

Heavy designer dependency. Three of the five cards' `effect` IDs do not yet exist anywhere — recommend cards 3-4 be deferred to a later wave (§17, Wave C).

### Cross-set theme bonds

- No multi-set bond currently includes `genesis` (it has only the single-set self-bond at `theme_bonds.json:280`). Genesis was clearly intended as a build-around capstone and probably should *not* anchor a multi-set theme.

### Difficulty-curve note

**N9-N10** — meaningful only at the difficulty band where the player has enough draft picks to assemble 5 specific orange cards. Below N7 the bond cannot complete.

---

## 16. 毁灭 / Apocalypse (Bond #106 — Orange ultimate)

- **EN flavor**: *Every screen is a coffin. Yours is on the other side.*
- **CN flavor**: *每张屏幕都是棺材。你站在另一面。*
- **`id`**: `apocalypse_set_bonus` ✅ already exists.

### Existing blueprint

```json
{
  "id": "apocalypse_set_bonus", "school": "shadow",
  "effects": [
    { "type": "SET_VARIABLE", "key": "hero_damage_aura",         "base_points": 15, "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_crit_explosion",      "base_points": 1,  "mode": "add", "target": { "category": "SELF" } },
    { "type": "SET_VARIABLE", "key": "hero_screen_nuke_cooldown","base_points": 60, "mode": "add", "target": { "category": "SELF" } }
  ]
}
```

### Proposed bond entry

```json
"106": {
  "type": "bond", "subclass": "apocalypse",
  "name_key": "SET_APOCALYPSE",
  "desc_key": "SET_APOCALYPSE_DESC",
  "required": 5,
  "stats": {}
}
```

### Card slot impact

**5 new cards** (Orange, `tier: 4`):

1. **`apoc_1` — 死亡光环 / Mortal Aura** — `proc { trigger: "passive_aura", radius: 3.5, dps: 15 }`.
2. **`apoc_2` — 暴击爆裂 / Crit Detonation** — `proc { trigger: "on_crit", chance: 0.30, effect: "aoe_damage", range: 2.5, damage_pct: 1.5, cooldown: 1 }`.
3. **`apoc_3` — 全屏毁灭 / Screen Nuke** — `proc { trigger: "periodic", interval: 60, effect: "screen_wipe", damage_pct: 3.0 }` (matches §0.4 cap).
4. **`apoc_4` — 毁灭之标记 / Doom Mark** — `proc { trigger: "on_hit", chance: 0.10, cooldown: 4, effect: "apply_doom_mark", duration: 3, damage_at_expire_pct: 2.5 }`.
5. **`apoc_5` — 终局裁决 / Final Verdict** — capstone: `proc { trigger: "on_kill", chance: 0.02, effect: "instant_kill_aoe", radius: 4.0 }` — bounded by the 0.02 chance to keep value below the soul-shockwave cumulative ceiling.

`screen_wipe` does not exist as an effect; the cooldown of 60s + damage_pct 3.0 mirrors the blueprint's `hero_screen_nuke_cooldown` of 60. Flagged in §18.6.

### Cross-set theme bonds

- No multi-set bond currently includes `apocalypse` (only its single-set entry at `theme_bonds.json:291`).
- Propose a *new* `world_ender` linking `apocalypse + storm + reaper` for screen-clearing identity.

### Difficulty-curve note

**N9-N10** — needs a 5-card draft to activate; only feasible at the highest difficulty bands.

---

## 17. Implementation phasing

The 16 sets fall into three implementation waves grouped by ascending dependency on framework work that does not yet exist.

### Wave A — Lowest cost (6 sets, ship first)

`healer (#90), tracker (#91), weakness_hunter (#93), war_machine (#96), blood_moon (#99), soul_harvest (#97)`

**Rationale**: All six can be wired with effects already implemented in the ProcManager (`shield`, `apply_mark`, `armor_shred`, `aoe_damage`, `aspd_buff`, `add_growth`, `restore_mana`, `heal_pct`). All six already have a single-set theme bond entry in `theme_bonds.json`, so wiring them as draftable bonds activates the bonuses immediately. Magnitudes are moderate; risk of balance drift is low. `soul_harvest` is in this wave despite the §18.8 magnitude warning because the fix is a tuning call, not a code change.

### Wave B — Depends on new cards / minor handlers (6 sets)

`summoner (#92), shadow_blade (#94), alchemist (#95), ice_fire (#98), dragon_force (#103), eternity (#104)`

**Rationale**: Each requires either a new ProcManager effect handler (`apply_mark` already in Wave A, but `summon_minion`, `swap_school_fire_frost`, `school_immunity`, `revive_full` are net-new), a new proc trigger flag (`on_hit_from_behind`, `on_hit_frozen_target_with_fire`, `on_low_hp`), or reuse-with-renames of an existing system (`cheat_death` → `revive_full`). All can be authored without a designer-led mechanic change; just ProcManager work. Multi-set theme bonds for these already exist (`shadow_arts`, `chaos_weaver`, `dragon_slayer`).

### Wave C — Requires framework hooks not yet shipped (4 sets)

`fate_wheel (#101), void_walker (#102), genesis (#105), apocalypse (#106)`

**Rationale**:
- `fate_wheel` needs a weighted `random_proc_table` system that does not exist; designing the table format itself is a separable task.
- `void_walker` needs an auto-blink movement primitive plus a `MovementGenerator` profile for "blink-to-target," plus a slow-field `AreaAura`.
- `genesis` has 2/5 cards whose effects are explicitly placeholder ("reshape battlefield," "rewrite enemy modifier") and need a designer brief.
- `apocalypse` needs `screen_wipe`, `passive_aura` DPS, and `apply_doom_mark` — none of which exist.

These 4 should ship together once the prerequisite framework features land, to avoid a half-stocked orange-tier draft pool.

---

## 18. Out of scope / open questions

### 18.1 Which "14" gets superseded?
Per §0.1, the player-facing 14 are wuxia/anime bonds in `data/spells.json`, not the 14 design-plan archetypes (splitter/swift/flame/...). Adding 16 archetype-themed bonds without a product call yields a 30-bond pool of mixed thematic identity (14 wuxia + 16 western archetypes). Recommend a designer call to choose: (a) keep 14 wuxia + add 16 archetypes = 30 mixed; (b) deprecate the 14 wuxia bonds and wire the 14 design-plan archetype `*_set_bonus.json` blueprints (splitter/swift/flame/etc.) as the new "14 base," then add the 16 expansion sets on top; (c) park the wuxia bonds as a separate "Wuxia Map Pack" GamePack and reset the rogue_survivor pool to archetype-only.

### 18.2 Bond record schema divergence
The existing 14 wuxia bonds have **no** `name_key` / `desc_key` fields — labels come from a different code path (likely hard-coded in `rogue_card_system.gd`). Proposed new bonds add `name_key` / `desc_key` to align with how `theme_bonds.json` references its bonds. Confirm with whichever engineer owns `rogue_card_system.gd` whether the loader can read `name_key` from bond entries before relying on it.

### 18.3 Card pool size
Adding the 16 sets at the proposed card counts (2/2/2/2/3/3/3/3/3/3/4/4/4/4/5/5 = 52 new cards) **doubles** the draft pool from 52 to 104, which dilutes the chance of completing any one set. Recommend gating new sets by difficulty (§N1-N10 notes per set above) so the pool grows with progression, not all at once.

### 18.4 i18n key budget
Each new bond needs 2 keys (`SET_<NAME>` / `SET_<NAME>_DESC`); each card needs 2-3 keys (name + description + flavor). Total estimated new keys: ~32 bond-side + ~150 card-side = **~182 new i18n keys per language**, across all 4 supported languages. Verify with the I18n owner that the JSON files can absorb this expansion before authoring cards in Wave A.

### 18.5 Filename oddity
`spells/summoner_new_set_bonus.json` retains `_new_` from a prior iteration. Either rename the file to `summoner_set_bonus.json` and update any string references, or keep the historical name. Decide before Wave A so the bond's `id` (`summoner_new_set_bonus`) and `subclass` (`summoner`) don't drift.

### 18.6 ProcManager / SpellSystem effect ID gaps
The proposed cards reference effects that don't exist in the current handler registry. Confirmed gaps:

- New trigger flags: `on_hit_from_behind`, `on_hit_frozen_target_with_fire`, `on_blink`, `on_low_hp`, `on_stealth_kill`, `on_full_set_active`, `kill_count`, `passive_aura`, `passive`.
- New effect handlers: `summon_minion`, `apply_mark`, `extend_mark`, `apply_doom_mark`, `reroll_damage_school`, `swap_school_fire_frost`, `fusion_burst`, `drop_random_potion`, `random_proc_table`, `random_buff_self`, `random_drop_multi`, `blink_to_target`, `summon_shadow_clone`, `spawn_slow_field`, `cone_damage`, `school_immunity`, `revive_full`, `rewind_hp_to_pct`, `reshape_battlefield`, `rewrite_one_enemy_modifier`, `permanent_aura_amplify_all_self_buffs`, `screen_wipe`, `instant_kill_aoe`.

Wave A only needs the existing handler set; the gaps are concentrated in Waves B and C, which is reflected in the ordering.

### 18.7 School-resistance dependency
The Alchemist card pitch (§6) assumes enemies have school-specific resistances so that re-rolling damage school is meaningful. As of today, only `ImmunitySystem` and `DiminishingReturns` are shipped — there is no per-enemy school-resist stat. Either add school-resists to the difficulty curve (planned per the design plan but not yet in code), or downgrade the alchemist re-roll to a flavor effect.

### 18.8 Soul Harvest magnitude conflict
The shipped `soul_harvest_set_bonus.json` declares `hero_permanent_damage_per_kill: 0.80, mode: "add"` but the same key is set to `0.02` (40× lower) in `reaper_set_bonus.json`. If both bonds are active in the same run the values stack additively (`+0.82` per kill = run-breaking). Either:
- change soul_harvest's `mode` to `set` (overrides reaper's value), or
- drop the soul_harvest base_points to ~0.05 to keep stacking sane.

### 18.9 Genesis "battlefield reshape" is undefined
The blueprint exposes `hero_battlefield_reshape` but no consumer reads it. The design plan's flavor ("重塑战场规则") doesn't disambiguate — does it mean spawn rate, terrain, enemy AI, or wave composition? Cards 3-4 of the proposed Genesis roster are placeholders; designer brief required before authoring.

### 18.10 Theme-bond proliferation
This proposal mentions five potential *new* theme bonds (`survivor_creed`, `marksman_doctrine`, `necromancer_pact`, `shadow_dance`, `siege_breaker`, `world_ender`, `immortality_pact`). The current theme-bond count is 26. Adding seven would push it to 33 — beyond the design plan's stated `theme bond ≈ set count` ratio. Recommend choosing 2-3 of the most strategically-meaningful new theme bonds, not all of them.

### 18.11 `required` thresholds of 4 and 5 are new
None of the existing 14 wuxia bonds use `required: 4` or `required: 5`. Confirm `rogue_card_system.gd` UI handles set-completion progress display correctly at these higher thresholds (e.g. progress bar segments, "X / 5" string formatting) before Wave C.

---

*Proposal v1 — 2026-04-25 | Author: handoff agent | Subject to designer revision per §18.*
