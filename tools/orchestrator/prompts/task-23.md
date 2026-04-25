Task #23: Produce docs/THEME_BOND_REWIRE_SPEC.md — a precise, human-applicable diff specification for rewiring `gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd` off the dead `_card_manager` and onto the active `rogue_card_system.gd` pipeline.

Background: Task #14 (`docs/THEME_BONDS_FIX_NOTES.md` §b) discovered that `_card_manager` is declared null at `rogue_game_mode.gd:42` with no writer site. `RogueThemeBond.check_bonds()` calls `_gm._card_manager.get_completed_sets()` and `_gm._card_manager._get_set_def(sid)`, so every bond check silently becomes a no-op — the entire theme-bond feature is dead code even after Task #14's ID fixes. This task produces the spec to revive it.

Procedure:
1. Read `gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd` in full. Note every reference to `_gm._card_manager`.
2. Read `gamepacks/rogue_survivor/scripts/rogue_card_system.gd` — this is the active system. Find:
   - How it tracks owned cards and their bond IDs (likely `_all_bonds`, `_owned_cards`, or similar)
   - What method (if any) exposes "which bonds does the player have ≥N cards of"
   - The naming convention for bond IDs (numeric integers from `data/spells.json` `type: "bond"`)
3. Read `gamepacks/rogue_survivor/data/spells.json` to confirm the bond data format (numeric IDs, `type: "bond"` entries).
4. Understand the mismatch: `RogueThemeBond` was written for a `card_manager` with string set IDs (`"flame"`, `"frost"`), but the active card system uses numeric `bond_id` on each card. `theme_bonds.json` — post-Task-#14 — uses `<name>_set_bonus` string IDs as `required_sets`. There is a string-vs-numeric impedance mismatch.
5. Decide the cleanest rewire:
   - **Option A**: add a translation layer in `RogueThemeBond` that maps `<name>_set_bonus` → numeric bond_id by reading the `set_bonus_id` or equivalent field from each bond entry
   - **Option B**: rewrite `theme_bonds.json` to reference numeric bond_ids instead of `<name>_set_bonus` strings
   - **Option C**: add a helper method `RogueCardSystem.get_bonds_with_count_ge(n)` that returns bonds the player has N+ cards of
   Pick the option with the smallest blast radius — prefer changes local to `rogue_theme_bond.gd` over changes to `theme_bonds.json` or `rogue_card_system.gd`, since the first is the broken side.
6. Produce `docs/THEME_BOND_REWIRE_SPEC.md` with:
   - **§1. Root cause recap** — one paragraph on why check_bonds() is dead
   - **§2. Chosen option + rationale** — which of A/B/C and why, one paragraph
   - **§3. Precise diff** — for every file that needs to change, provide a fenced code block showing `BEFORE` (exact text, quoted from file) → `AFTER` (proposed replacement). Include line numbers to help the human apply. Keep each hunk small and local.
   - **§4. Verification checklist** — what the human should grep/check after applying to confirm no dangling references to `_card_manager`. Include the specific `grep` commands.
   - **§5. Test plan** — what a basic "does it work" test looks like. Cannot actually run the game, so write down what events in-game would exercise the bonds (e.g. "pick 2 flame cards → check_bonds() should now find `flame_set_bonus` and trigger BOND_ELEMENTAL_MASTER if rules match").
   - **§6. Rollback plan** — exact `git checkout` command for each modified file (do NOT run it; document it).

Constraints:
- Do NOT modify any source file. This task produces the spec only; the human applies the diff.
- Do NOT invent method names that don't exist in `rogue_card_system.gd` — grep to confirm before proposing the new call site.
- Do NOT recommend changes >30 lines total across the codebase. If the fix is bigger than that, pick a different option or split into phases.
- If after reading the source you conclude the rewire is more invasive than the 3 options suggest (e.g. fundamental data-model mismatch), document that honestly in §2 and propose a smaller "bootstrap" spec — even a partial fix beats the null-crash situation.

Rules:
- No git, no code changes.
- Single window, no `[ROTATE]`.
- Emit `[DONE]` when saved.

Deliverable: `docs/THEME_BOND_REWIRE_SPEC.md`
