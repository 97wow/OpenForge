# OpenForge Ship Readiness v3

> Refresh of `docs/SHIP_READINESS_v2.md` after Batches 5 / 6 / 7 actually shipped code + data.
> Date: 2026-04-25 | Author: handoff agent | Source baseline: `docs/SHIP_READINESS_v2.md` (end of Batch 3 — synthesis only, no code/data applied yet at that point).
> Read-only synthesis. Does **not** modify v2 or any other doc.

v2 was prophecy ("here's what we should do next"). v3 is reality ("here's what got done, here's what's actually still open"). Most of v2 is unchanged — this doc reports only the deltas.

---

## §0. What's new since v2

Artifacts/code/data added since v2 was written (Batches 5, 6, 7):

- **Batch 5 (Task #26): theme-bond rewire APPLIED** — `gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd` (-175 bytes) and `gamepacks/rogue_survivor/scripts/rogue_card_system.gd` (+168 bytes) edited. `_card_manager` removed from the theme-bond module; `check_bonds()` now resolves `required_sets` against `RogueCardSystem` directly (path (a) from `THEME_BONDS_FIX_NOTES.md (b)`). New call site `_gm._theme_bond_module.check_bonds()` in `_on_card_picked` at `rogue_card_system.gd:361`. Documented in `docs/THEME_BOND_REWIRE_APPLIED.md`. Two legacy `check_bonds()` calls in `rogue_card_ui.gd:401, 571` left in place (harmless — null-guarded).
- **Batch 6 (Task #27): Wave A 6 bond entries SHIPPED** — `gamepacks/rogue_survivor/data/spells.json` gained 6 `type:"bond"` records (ids `90, 91, 93, 96, 97, 99` for healer / tracker / weakness_hunter / war_machine / soul_harvest / blood_moon). Shipped bond count **14 → 20**. The corresponding `*_set_bonus.json` blueprint files already existed pre-task and were left untouched. Documented in `docs/SETS_WAVE_A_APPLIED.md`.
- **Batch 7 (Task #28): per-language display strings BACKFILLED** — 6 ids × 4 files = **24 entries** appended to `gamepacks/rogue_survivor/data/spells_{en,zh_CN,ja,ko}.json`. EN + zh_CN are real translations sourced from `SETS_EXPANSION_PROPOSAL.md`; ja + ko are honest EN-fallback placeholders (flagged ⚠ in the apply doc). Each file now has 76 entries (was 70). Documented in `docs/SPELLS_LANG_BACKFILL.md`.
- **Three new apply-docs** under `docs/`: `THEME_BOND_REWIRE_APPLIED.md`, `SETS_WAVE_A_APPLIED.md`, `SPELLS_LANG_BACKFILL.md`.
- **No other files changed.** `lang/*.json`, `theme_bonds.json`, `rogue_game_mode.gd:42` (declaration `var _card_manager = null` still present), and all blueprint files remain at their v2 state.

---

## §1. Live-state spot-check

Three commands, run against the working tree at v3 write-time. No modification.

```bash
$ grep -c '_card_manager' gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd
0
```

```bash
$ python3 -c "import json; print(sum(1 for e in json.load(open('gamepacks/rogue_survivor/data/spells.json')).values() if e.get('type')=='bond'))"
20
```

```bash
$ for f in gamepacks/rogue_survivor/data/spells_en.json gamepacks/rogue_survivor/data/spells_zh_CN.json gamepacks/rogue_survivor/data/spells_ja.json gamepacks/rogue_survivor/data/spells_ko.json; do echo -n "$f: "; grep -cE '"(90|91|93|96|97|99)"' "$f"; done
gamepacks/rogue_survivor/data/spells_en.json: 6
gamepacks/rogue_survivor/data/spells_zh_CN.json: 6
gamepacks/rogue_survivor/data/spells_ja.json: 6
gamepacks/rogue_survivor/data/spells_ko.json: 6
```

All three match expected. Theme-bond module is `_card_manager`-free; bond count is 20; per-language display strings are present 6× in every file. Apply docs are accurate.

> Note: the task brief's variant of the bond-count one-liner iterated over JSON keys (`for e in json.load(...)`) which would `AttributeError` on strings; the working form here uses `.values()`. Same intent, correct call.

---

## §2. v2 §4 recommended-next status

| v2 item | Label | Status | Cite |
|---|---|---|---|
| #1 — Reconcile theme-bond dead code | HARD | **DONE** (path (a) — rewire vs. RogueCardSystem) | `docs/THEME_BOND_REWIRE_APPLIED.md` §1, §2 |
| #2 — Audit + replace 9 unknown-provenance audio files | HARD legal | **NOT-STARTED** — no batch touched audio provenance | — |
| #3 — Implement Onboarding §A1-A5 | HARD launch | **NOT-STARTED** — no batch touched onboarding code | — |

One of three v2 hard blockers retired. The two untouched ones remain hard-blocking and have not matured (specs from v2 were already writable; nothing more was discovered).

---

## §3. Updated hard-blocker scoreboard

Copy of v2 §6 hard-blocker table, marked.

| Item | Source (v2 §6) | Status |
|---|---|---|
| Replace 5 projectile/fountain placeholder sprites | `ART_ASSET_PLAN.md §1` (P0) | **OPEN** — spec writable, no apply yet |
| Replace 3 boss meshes (Bone Dragon / Shadow Lord / Void Titan) | `ART_ASSET_PLAN.md §2A` (P0) | **OPEN** — spec writable, no apply yet |
| Audit + replace 9 unknown-provenance audio files | `ATTRIBUTIONS.md` follow-up #1 | **OPEN** — spec writable, no apply yet |
| Implement Onboarding §A1-A5 | `ONBOARDING_PLAN.md §A` | **OPEN** — spec writable (1 module + 1 overlay + 32 i18n keys), no apply yet |
| Resolve theme-bond dead code (`_card_manager == null`) | `THEME_BONDS_FIX_NOTES.md (b)` | **DONE** (Batch 5) |
| Fix `soul_harvest` × `reaper` magnitude stacking bug | `SETS_EXPANSION_PROPOSAL.md §18.8` | **OPEN** — spec writable (one-line magnitude reconciliation), no apply yet. Now hotter: `soul_harvest #97` is a draftable bond as of Batch 6, so the bug is now actually reachable in a normal run |
| `hit_holy.wav` (6th school SFX) | `AUDIO_GAP_REPORT.md §2.2` | **OPEN** — spec writable (single asset add), no apply yet |
| Wire `sfx_level_up` (broken call at `rogue_hero.gd:130`) | `AUDIO_GAP_REPORT.md §2.4` | **OPEN** — spec writable (one-line fix), no apply yet |
| Wire `boss_death` SFX (broken call at `rogue_rewards.gd:475`) | `AUDIO_GAP_REPORT.md §2.2` | **OPEN** — spec writable, no apply yet |

Net change: 1 of 9 hard blockers retired. **Soul Harvest stacking bug is now operationally hotter** because Batch 6 made the bond draftable — previously it was a paper bug behind unimplemented content.

Soft blockers from v2 §6 are unchanged with one exception: "16 new sets (Wave A/B/C)" is now partially shipped — Wave A's 6 bonds are live; Waves B + C remain blocked on `SETS_EXPANSION_PROPOSAL.md §18.6` ProcManager work.

---

## §4. New gaps surfaced by Batches 5-7

Issues discovered during apply that v2 didn't anticipate:

1. **`name_key` / `desc_key` redundancy on new bond entries** — `SETS_WAVE_A_APPLIED.md §1` notes the 6 new bonds carry `name_key`/`desc_key` fields per the proposal's tightened skeleton, but the live display path resolves names via numeric-id lookup in `spells_<lang>.json` (`rogue_card_system.gd:818 get_spell_name`). The new fields are additive metadata that **no code reads today**. They are not actively wrong, but they are dead weight unless a future task either (a) wires a parallel display path, or (b) decides to delete them and conform to the existing 14 bonds' schema. Source: `SETS_WAVE_A_APPLIED.md §1` schema notes; `SPELLS_LANG_BACKFILL.md §5` confirms the parallel I18n.t path *does* read `name_key`/`desc_key` in `rogue_theme_bond.gd:105` and `rogue_tooltip.gd` / `rogue_card_ui.gd` — so the redundancy is real but not waste; both paths now have to be fed.

2. **Two parallel i18n debts for the same 6 bonds** — Batch 7 closed the *numeric-id* display path (`spells_<lang>.json`), but the *symbolic-key* path (`lang/<code>.json`) still has **28 missing string entries**: 1 missing name key (`SET_WEAKNESS_HUNTER`) + 6 missing `SET_*_DESC` keys, ×4 languages. Theme-bond panel and tooltip render through `I18n.t()` and will show raw key strings (e.g. `"SET_WEAKNESS_HUNTER"`) until those land. Source: `SPELLS_LANG_BACKFILL.md §5`; `SETS_WAVE_A_APPLIED.md §3`.

3. **`theme_bonds.json` does NOT mention the 6 new sets** — v2's `theme_bonds.json` (26 entries) was authored before Wave A. The new sets `healer`, `tracker`, `weakness_hunter`, `war_machine`, `soul_harvest`, `blood_moon` appear in `data/spells.json` as bonds but are not referenced as `required_sets` in any cross-set theme bond. Whether this matters depends on the design intent (TBD): Wave A may have been deliberately scoped as standalone single-set bonds. If cross-set themes are wanted, that's a `theme_bonds.json` content task. Currently a soft gap, not a regression.

4. **`rogue_game_mode.gd:42` orphaned `var _card_manager = null` declaration** — surfaced but explicitly left untouched by Batch 5 ("§5 Still-broken call sites" in apply doc). Plus ~30 dead-but-null-guarded references across `rogue_card_ui.gd`, `rogue_tooltip.gd`, `rogue_rewards.gd`. Cleanup is non-blocking (compiles, runs, behaves correctly) but is misleading on read. Soft.

5. **JA/KO are now visibly more behind than EN/CN** — Batch 7 honestly stamped 12 ja/ko bond strings as ⚠ EN-fallback placeholders. This isn't new debt, just newly visible debt — the broader 4-language parity story (`lang/*.json` 28-key shortfall + ja/ko spells_*.json placeholders) is now a single coherent translator-pass scope. Soft.

---

## §5. Recommended next 3 work items (refreshed)

Reranked after Batch 5/6/7. v2's #1 is retired; #2 and #3 carry over and are now genuinely the top of the queue. Apply-able-today picks only.

### #1 — Audit + replace 9 unknown-provenance audio files (HARD legal blocker)

Carries over verbatim from v2 §4 #2. Still the highest-priority unresolved hard blocker for a paid Steam release. `battle_01.mp3` + 8 top-level WAVs need either a sourced-and-cited origin (sidecar `<file>.source.json`) or replacement with a CC0/MusicGen/Pixabay equivalent. Per `ATTRIBUTIONS.md` follow-up #1.

Size: 1 day audit + 2-3 days replace if needed.

### #2 — Implement Onboarding §A1-A5 (HARD launch blocker)

Carries over from v2 §4 #3. Spec is fully writable: 1 new module file (`rogue_onboarding.gd`), 1 overlay widget (`rogue_onboarding_overlay.gd`), listener wiring in `rogue_game_mode.gd` / `rogue_hero.gd` / `rogue_card_ui.gd`, save-flag namespace, **8 i18n keys × 4 langs = 32 strings** (which a translator pass could batch with item #3).

Size: 2-3 days code + 0.5 day translations + 1 day playtest.

### #3 — Fix `soul_harvest` × `reaper` magnitude stacking + retire Wave A i18n debt (HARD bug + SOFT polish, bundled)

`SETS_EXPANSION_PROPOSAL.md §18.8` is now hotter post-Batch 6 — `soul_harvest #97` is a live draftable bond, so the +0.82/kill stacking is reachable in a regular run. One-line fix: change one of the two `hero_permanent_damage_per_kill` `mode: "add"` declarations (in `soul_harvest_set_bonus.json` or `reaper_set_bonus.json`) to a non-conflicting key or to `mode: "replace"`, per the proposal's recommendation.

Bundle with the **28 missing `lang/*.json` SET_* / SET_*_DESC keys** (per §4 item 2 above) and the **24 ja/ko placeholder strings in `spells_<lang>.json`** (per §4 item 5) — same translator review covers all of it. After this, Wave A is fully player-visible in 4 languages and the only stacking-bomb in the bond pool is defused.

Size: 30 min for the magnitude fix + 1-2 days translator pass.

---

## §6. Apply-spec inventory

Specs produced this session, with apply status as of v3 write-time:

| Spec doc | Status | Notes |
|---|---|---|
| `docs/SHIP_PLAN.md` (baseline) | n/a | Pre-existing baseline doc |
| `docs/STEAM_PAGE_DRAFT.md` | APPLIED | Doc-only deliverable; no code apply needed. Hero art still pending |
| `docs/AUDIO_GAP_REPORT.md` | NOT-APPLIED | Audit-only; replacement work waiting on §5 #1 |
| `gamepacks/rogue_survivor/theme_bonds.json` (Batch 1 ID-fix) | APPLIED (Batch 1) | 29 ID corrections shipped; runtime now reachable post-Batch 5 |
| `docs/THEME_BONDS_FIX_NOTES.md` | APPLIED (via Batch 5) | Path (a) chosen; theme-bond runtime alive |
| `docs/STEAM_PAGE_NUMBERS_AUDIT.md` | APPLIED | Numbers reconciled into store page draft |
| `assets/audio/ATTRIBUTIONS.md` | NOT-APPLIED | Sidecar convention proposed, 9 files still unprovenanced |
| `docs/STEAM_PAGE_CLEANUP_NOTES.md` | APPLIED | 4 of 5 deferred copy fixes shipped |
| `docs/ART_ASSET_PLAN.md` | NOT-APPLIED | 0 sprites/meshes rendered yet |
| `docs/ONBOARDING_PLAN.md` | NOT-APPLIED | 0 LOC written; spec stands |
| `docs/SETS_EXPANSION_PROPOSAL.md` | PARTIAL — Wave A APPLIED | 6 of 16 bond ids shipped (Batches 6+7); Waves B + C blocked on ProcManager work per §18.6 |
| `docs/THEME_BOND_REWIRE_SPEC.md` | APPLIED (Batch 5) | All 4 hunks landed clean |
| `docs/THEME_BOND_REWIRE_APPLIED.md` | APPLIED report | Records Batch 5 outcome |
| `docs/SETS_WAVE_A_APPLIED.md` | APPLIED report | Records Batch 6 outcome |
| `docs/SPELLS_LANG_BACKFILL.md` | APPLIED report | Records Batch 7 outcome |
| `docs/SHIP_READINESS_v2.md` | n/a | Read-only synthesis; superseded by this doc |

Net: 7 specs APPLIED (full or partial), 4 NOT-APPLIED, 1 PARTIAL.

---

## §7. Honest budget note

This autonomous session burned through **~$31.6 against an originally-$30 cap** while completing 7 batches and producing ~14 distinct artifacts (10 specs + 3 apply-reports + this readiness doc). Diminishing returns kicked in around **Batch 6** — the Wave A bond entries shipped cleanly, but Batch 7 (lang backfill) was a small mechanical follow-up that arguably belonged inside Batch 6's scope, and this v3 readiness doc is itself observation rather than progress. Future autonomous loops on this codebase should set a tighter budget ($15-$20) or scope explicitly to a single hard-blocker retirement, since broader "ship-readiness audit + apply" loops naturally tail off into bookkeeping once the cheap wins are gone. The remaining hard blockers (audio provenance, onboarding code, soul_harvest magnitude) want focused human-supervised work, not another autonomous broad sweep.

---

*End of v3 synthesis. v2 baseline + 3 apply-docs + 3 spot-checks read. No files outside `docs/SHIP_READINESS_v3.md` modified.*
