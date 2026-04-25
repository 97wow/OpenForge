# soul_harvest × reaper Magnitude Stacking — Fix Report

> Task #30 — applied 2026-04-25
> Cross-reference: `docs/SHIP_READINESS_v3.md` §5 #3 ; `docs/SETS_EXPANSION_PROPOSAL.md` §18.8

---

## §1. Bug summary

`gamepacks/rogue_survivor/spells/soul_harvest_set_bonus.json` declared
`hero_permanent_damage_per_kill` at `base_points: 0.8` with `mode: "add"`, while
`gamepacks/rogue_survivor/spells/reaper_set_bonus.json` declared the same key
at `base_points: 0.02` with `mode: "set"`. With Task #27 making bond_id 97
(`soul_harvest`, threshold `required: 3`) live and `reaper` already shipped, a
player who completed both subclass thresholds in one run could land in a state
where `soul_harvest` fires after `reaper`: reaper sets the var to `0.02`, then
soul_harvest *adds* `0.80` on top — net `+0.82` permanent attack power **per
kill**, which `rogue_rewards.gd:508` then multiplies into base damage forever.
With the typical kill-count of a normal run, this rapidly exceeds the
balance-curve cap and produces "screen-clearing" damage in 1–2 minutes — the
"stacking bomb" the original proposal warned about, now reachable in ordinary
play. (Note: `reaper`'s own `mode: "set"` is itself an additional latent
hazard against the theme-bond and relic sources of the same key, but that is
out of scope for this fix.)

---

## §2. Fix applied

Per the safety rails ("Modify AT MOST one blueprint file"), exactly one file
was modified.

### Why `mode: "set"` (not `replace` / not rename)

- The `SET_VARIABLE` handler at `src/systems/spell_system.gd:722-736` supports
  exactly three modes: `set`, `add`, `max`. There is no `replace`. The task
  brief used "replace" semantically — the closest supported mode is `set`.
- The brief also suggested a possible rename of one blueprint's stat key. A
  `grep -r hero_permanent_damage_per_kill` shows the key is consumed in
  **5+ places** outside the two set-bonus files (`rogue_rewards.gd:508`,
  `rogue_combat_log.gd:85`, `soul_harvest_1_passive.json`,
  `theme_bonds.json:100,203`, `relics.json:73`). Renaming would silently break
  reward computation and the combat log i18n binding — explicitly disallowed
  by the task. **Rename approach: rejected.**
- The brief's preferred rule "modify the smaller-magnitude block" is moot here
  because **only soul_harvest is `mode: "add"`** — reaper is already `set`.
  The single `add` block is the unique source of the additive stack, so
  switching it is the minimum-footprint fix. After the switch, soul_harvest
  (the larger value, 0.80) ends up authoritative whenever it fires after
  reaper, which preserves the player power that the bond is *intended* to
  grant. This matches the explicit recommendation in
  `docs/SETS_EXPANSION_PROPOSAL.md` §18.8: *"change soul_harvest's `mode` to
  `set` (overrides reaper's value)"*.

### Diff

| File | Lines | Mode change |
|---|---|---|
| `gamepacks/rogue_survivor/spells/soul_harvest_set_bonus.json` | 5–11 | `add` → `set` (key `hero_permanent_damage_per_kill` only) |

**BEFORE**

```json
    {
      "type": "SET_VARIABLE",
      "key": "hero_permanent_damage_per_kill",
      "base_points": 0.8,
      "mode": "add",
      "target": { "category": "SELF" }
    },
```

**AFTER**

```json
    {
      "type": "SET_VARIABLE",
      "key": "hero_permanent_damage_per_kill",
      "base_points": 0.8,
      "mode": "set",
      "target": { "category": "SELF" }
    },
```

The other two effect blocks in `soul_harvest_set_bonus.json`
(`hero_kill_crit_bonus`, `hero_soul_shockwave_threshold`) and **all** of
`reaper_set_bonus.json` were left untouched.

---

## §3. Verification

```
$ python3 -c "import json; json.load(open('gamepacks/rogue_survivor/spells/soul_harvest_set_bonus.json'))" && echo "soul_harvest OK"
soul_harvest OK
$ python3 -c "import json; json.load(open('gamepacks/rogue_survivor/spells/reaper_set_bonus.json'))" && echo "reaper OK"
reaper OK
```

Post-fix grep across both files (note both rows now show `mode=set`,
no `mode=add` remains for this key in any set-bonus blueprint):

```
hero_permanent_damage_per_kill:
    reaper_set_bonus.json        mode=set  base=0.02
    soul_harvest_set_bonus.json  mode=set  base=0.8
```

Result: **the additive-stacking path is removed.** With both blocks now
`mode: "set"`, the final value is whichever bond's effect re-fired most
recently — bounded to either 0.02 or 0.80, never their sum.

> Residual order-dependency caveat: if reaper's effect re-fires after
> soul_harvest's, the variable falls to 0.02. This is the latent reaper bug
> referenced in §1 and is the same hazard that affects `theme_bonds.json` and
> `relics.json`'s `add`-mode contributions to this key. Out of scope for
> Task #30 — flagged below in §4 as future work alongside the broader
> "reaper clobbers other sources" cleanup.

---

## §4. Other duplicate stat-key + `mode: "add"` pairs in the 30 set-bonus files

Programmatic scan of all 30 `*_set_bonus.json` files for `SET_VARIABLE`
effects with the same `key` declared in two or more files. **HIGH** = two or
more `mode: "add"` declarations on the same key (true additive stack);
**MEDIUM** = mixed modes; **LOW** = no `add` modes left.

| Risk | Stat key | Files (mode / base_points) | Worst-case stack |
|---|---|---|---|
| **HIGH** | `hero_chain_chance` | `elementalist_set_bonus.json` (add 0.12) + `lightning_set_bonus.json` (add 0.15) | +0.27 chain chance if a player completes both subclasses |
| **HIGH** | `hero_phys_crit` | `crit_set_bonus.json` (add 0.25) + `swift_set_bonus.json` (add 0.20) | +0.45 crit chance — ~half the crit cap from set bonuses alone |
| LOW | `hero_permanent_damage_per_kill` | `reaper_set_bonus.json` (set 0.02) + `soul_harvest_set_bonus.json` (set 0.8) | Fixed by this task |

**Both HIGH findings are candidates for the same treatment**: switch the
larger-magnitude block to `mode: "set"` (or, if both blocks are *intended* to
combine, deliberately split the keys). They are **not** fixed here — Task #30
is scoped to soul_harvest × reaper only — but they should be filed against
ship-readiness before either subclass pair becomes a normal-run reachable
combination.

---

## §5. Rollback snippet

```bash
git checkout -- gamepacks/rogue_survivor/spells/soul_harvest_set_bonus.json
```

That is the only modified blueprint. Reverting it restores the additive-stack
bug exactly as documented above.
