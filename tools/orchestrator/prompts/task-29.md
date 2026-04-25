Task #29: Produce docs/SHIP_READINESS_v3.md — refreshed ship readiness reflecting batches 5/6/7 (theme-bond rewire applied, Wave A 6 new bonds shipped, lang backfill).

Background: `docs/SHIP_READINESS_v2.md` was written at the end of Batch 3 (just before any code/data was actually applied). Three subsequent batches did real work:
- Batch 5 (Task #26): `rogue_theme_bond.gd` + `rogue_card_system.gd` rewire APPLIED — the bond engine moved from dead code to functional
- Batch 6 (Task #27): 6 new bonds added to `data/spells.json` (ids 90, 91, 93, 96, 97, 99). Shipped count 14 → 20. Blueprint files already existed pre-task.
- Batch 7 (Task #28): 6 entries × 4 languages added to `spells_<lang>.json` so the new bonds display correctly. 24 entries total.

This task synthesizes those changes against `SHIP_READINESS_v2.md` to produce a v3 that is current as of end-of-batch-7.

Procedure:
1. Read `docs/SHIP_READINESS_v2.md` in full — this is the v2 baseline.
2. Read the three apply-doc deliverables:
   - `docs/THEME_BOND_REWIRE_APPLIED.md`
   - `docs/SETS_WAVE_A_APPLIED.md`
   - `docs/SPELLS_LANG_BACKFILL.md`
3. Spot-check live state (do NOT modify anything):
   - `grep -c '_card_manager' gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd` — confirm 0
   - `python3 -c "import json; print(sum(1 for e in json.load(open('gamepacks/rogue_survivor/data/spells.json')) if e.get('type')=='bond'))"` — confirm 20
   - `grep -cE '"(90|91|93|96|97|99)"' gamepacks/rogue_survivor/data/spells_*.json` per file — confirm 6 each
   Quote each command's actual output in §1.
4. Produce `docs/SHIP_READINESS_v3.md` with:
   - **§0. What's new since v2** — bullet list of every artifact/code/data change since v2 was written. Cite file paths.
   - **§1. Live-state spot-check** — output of the 3 grep/parse commands above. This is the "trust but verify" layer — v2 was prophecy, v3 reports reality.
   - **§2. v2 §4 recommended-next status** — for each of v2's three "next 3 work items," report status: DONE / IN-PROGRESS / NOT-STARTED. Cite the deliverable that addressed each.
   - **§3. Updated hard-blocker scoreboard** — copy v2 §6 hard-blocker list, mark each item DONE / OPEN. For any still-OPEN, flag whether the blocker has now matured to a writable spec or remains unspecced.
   - **§4. New gaps surfaced by batches 5-7** — anything we discovered while applying that wasn't in v2's awareness (e.g. `name_key`/`desc_key` redundancy noted in `SETS_WAVE_A_APPLIED.md` §1, or the missing `theme_bonds.json` entries for the 6 new bonds — TBD if needed at all)
   - **§5. Recommended next 3 work items (refreshed)** — same format as v2 §4 (#1/#2/#3 with HARD/SOFT label). Pick from the genuinely-still-blocking items, ranked by ship-criticality. Be ruthless about cutting items that are now nice-to-have rather than blockers.
   - **§6. Apply-spec inventory** — table of every "spec" doc produced this session with status: APPLIED (already done in batches 5/6/7), PARTIAL (started but more to do), NOT-APPLIED (waiting on human or scope constraint). One line per spec.
   - **§7. Honest budget note** — one short paragraph: this autonomous session spent ~$31.6 of an originally-$30 cap, completed 7 batches, and produced N artifacts. Note that diminishing returns kicked in around batch 6 — future autonomous loops should set a tighter budget or scope.

Constraints:
- Do NOT modify SHIP_READINESS_v2.md. Produce v3 as a sibling file.
- Do NOT modify any other doc. Read-only synthesis.
- Keep under 250 lines. v2 was 175; v3 should be tighter, not longer — most of the v2 picture is unchanged.

Rules:
- No git, no code/data changes.
- Single window, no `[ROTATE]`.
- Emit `[DONE]` when saved.

Deliverable: `docs/SHIP_READINESS_v3.md`
