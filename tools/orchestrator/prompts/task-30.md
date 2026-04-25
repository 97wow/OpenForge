Task #30: Fix the live `soul_harvest × reaper` magnitude stacking bug per `docs/SHIP_READINESS_v3.md` §5 #3 (cross-referenced from `docs/SETS_EXPANSION_PROPOSAL.md` §18.8).

Background: With Task #27 making bond_id 97 (`soul_harvest`) live and bond_id `reaper` already shipped, both blueprint files declare `hero_permanent_damage_per_kill` with `mode: "add"`. A player who picks 3+ cards of each subclass gets BOTH bonuses summed into the same stat — this is the "stacking bomb" the original proposal warned about, now reachable in a normal run.

Procedure:
1. Read both blueprint files:
   - `gamepacks/rogue_survivor/spells/soul_harvest_set_bonus.json`
   - `gamepacks/rogue_survivor/spells/reaper_set_bonus.json`
   Find every effect block that targets `hero_permanent_damage_per_kill`.
2. Read `docs/SETS_EXPANSION_PROPOSAL.md` §18.8 (or wherever the open-question discusses magnitude stacking) — see what fix the proposal recommended.
3. Read enough of `src/systems/stat_system.gd` (or whichever StatSystem implements `mode: "add" / "replace" / etc.`) to confirm what `mode` values are supported and what the right semantics are. Do NOT modify StatSystem.
4. Apply the smallest possible fix:
   - **Preferred**: change one of the two effect blocks from `mode: "add"` to `mode: "replace"` (so the stronger of the two wins instead of stacking). Pick whichever blueprint already has the *smaller* magnitude — replacing the smaller with the larger preserves player power; replacing the larger with the smaller would feel like a nerf.
   - **Alternative**: rename one blueprint's stat key from `hero_permanent_damage_per_kill` to a distinct key like `hero_soul_damage_per_kill`, BUT only if you can verify by grep that the key is not consumed elsewhere in the codebase. If it is consumed elsewhere, do NOT rename — fall back to the `mode: "replace"` approach.
   Document your choice in the deliverable with one paragraph of rationale.
5. After applying, parse-check both blueprint files (`python3 -c "import json; json.load(open(p))"` for each).
6. Produce `docs/SOUL_HARVEST_REAPER_FIX.md` with:
   - **§1. Bug summary** — one paragraph on what stacked and why
   - **§2. Fix applied** — table: file, line range, BEFORE block, AFTER block, mode change. Include the exact JSON diff.
   - **§3. Verification** — output of parse-checks + a grep showing both files still tokenize as expected
   - **§4. Other stat keys with similar risk** — quick scan of the 30 `*_set_bonus.json` files for any OTHER duplicate stat-key + `mode: "add"` pairs (not just soul_harvest/reaper). Report any findings as candidates for a future fix; do NOT fix here.
   - **§5. Rollback snippet** — `git checkout --` the modified file(s).

Safety rails:
- Modify AT MOST one blueprint file. If both files need changes for the right fix, that's a sign the rename approach is needed — re-evaluate before touching anything.
- Do NOT touch `data/spells.json` or any `spells_<lang>.json`.
- Do NOT modify StatSystem code.
- Do NOT introduce new fields the schema doesn't already use.
- If after reading you cannot identify a 1-line fix, document the obstacle in §2 and apply nothing — leave the bug live with a flagged plan rather than a half-applied confused state.

Rules:
- No git operations.
- Single window, no `[ROTATE]`.
- Emit `[DONE]` when saved.

Deliverable: `docs/SOUL_HARVEST_REAPER_FIX.md`
