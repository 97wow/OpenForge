Task #26: Apply the diff documented in `docs/THEME_BOND_REWIRE_SPEC.md` to the live codebase, then run the spec's §4 verification grep checklist, and document the outcome in `docs/THEME_BOND_REWIRE_APPLIED.md`.

Background: Task #23 produced a 385-line spec that documents the exact before/after text for each hunk that needs to change in `gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd` and `gamepacks/rogue_survivor/scripts/rogue_card_system.gd`, plus grep-based verification commands in §4. This task makes the edits that the spec specified.

Procedure:
1. Read `docs/THEME_BOND_REWIRE_SPEC.md` in full — it is your exact instruction set for this task.
2. For each BEFORE/AFTER hunk in §3:
   - Read the target file to confirm the BEFORE text still matches exactly (the codebase may have drifted since the spec was written).
   - If BEFORE matches exactly: apply the AFTER replacement.
   - If BEFORE does NOT match exactly (even one whitespace/comment difference): do NOT apply that hunk. Instead, record the mismatch in the deliverable and move on — partial application is fine; corrupt application is not.
3. After applying: run every grep command in the spec's §4 "Verification checklist." Capture the output of each. A mismatch vs. the expected result (e.g. "should return ZERO matches" but got 1) means the application is incomplete — flag it clearly.
4. Do NOT start the game or run Godot. The spec's §5 test plan requires runtime play which is out of scope for an automated task.
5. Produce `docs/THEME_BOND_REWIRE_APPLIED.md` with:
   - **§1. Hunks applied** — table: hunk label (e.g. "File 1, hunk 3"), status (APPLIED / SKIPPED / PARTIAL), notes. For each SKIPPED/PARTIAL, quote the exact BEFORE text you saw vs. what the spec expected.
   - **§2. Verification grep results** — copy-paste the grep command + actual output for every item in spec §4. Flag any mismatch with the spec's expected result.
   - **§3. Files modified** — exact list with byte-count before/after, so the human can see the scope.
   - **§4. Rollback snippet** — ready-to-run `git checkout -- <files>` to undo the whole change, regenerated from the actual modified files list (not copy-pasted from the spec).
   - **§5. Still-broken call sites** — per spec §4's note about `rogue_card_ui.gd` / `rogue_tooltip.gd` having dead `_card_manager` references, grep those too and confirm they remain dead-but-harmless, or flag if the grep result surprises you.
   - **§6. Next step recommendation** — if §1 shows any hunk SKIPPED/PARTIAL, recommend a spec refresh; otherwise state "Ready for runtime smoke-test by a human."

Safety rails:
- Do NOT apply any edit whose BEFORE text doesn't match byte-for-byte. Skip it and document.
- Do NOT modify any file outside the two named in the spec (`rogue_theme_bond.gd`, `rogue_card_system.gd`).
- Do NOT delete files.
- Do NOT attempt to fix the `rogue_card_ui.gd` / `rogue_tooltip.gd` dead call sites — the spec explicitly marks them out of scope.
- If at any point you feel like you're being clever beyond what the spec says: stop, skip that hunk, document it. The spec is the source of truth.

Rules:
- No git operations.
- Single window, no `[ROTATE]`.
- Emit `[DONE]` when `docs/THEME_BOND_REWIRE_APPLIED.md` is saved.

Deliverable: `docs/THEME_BOND_REWIRE_APPLIED.md`
