Task #14: Fix gamepacks/rogue_survivor/theme_bonds.json set-ID mismatches and verify it has a loader.

Background: a prior code review found that `theme_bonds.json` references set IDs that do not match the actual `*_set_bonus.json` filenames in `gamepacks/rogue_survivor/spells/`. The likely-broken IDs (verify before changing — do NOT trust this list blindly):
- `lightning_chain` → real source likely `spells/lightning_set_bonus.json`
- `crit_master` → `spells/crit_set_bonus.json`
- `storm_bringer` → `spells/storm_set_bonus.json`
- `swift_wind` → `spells/swift_set_bonus.json`
- `weakness_hunter` → `spells/weakness_set_bonus.json`
- `summoner` → `spells/summoner_new_set_bonus.json`

Procedure:
1. For each `*_set_bonus.json` in `gamepacks/rogue_survivor/spells/`, read its `id` field (or whatever the schema's identity field is) and build a true map of valid set IDs.
2. Open `gamepacks/rogue_survivor/theme_bonds.json` and reconcile every `required_sets` array against that map. Edit the JSON to use the canonical IDs. If a referenced set genuinely does not exist (no spell file matches), note it in the deliverable rather than silently dropping the bond.
3. Verify a loader exists: `grep -rn theme_bonds gamepacks/rogue_survivor/scripts/`. If no loader is wired, identify the right place (likely `rogue_card_sys.gd` or `rogue_game_mode.gd` near where DataRegistry / pack data is loaded) and add a minimal loader call. If you are not confident where it should go, document the gap in the deliverable instead of guessing — better to leave a clear TODO than wire it wrong.
4. Write `docs/THEME_BONDS_FIX_NOTES.md` summarizing: (a) ID corrections applied, (b) loader status (already wired / wired by you / TODO + reason), (c) any bonds with no fixable set match, (d) any sets on disk that no bond references (potential design gap).

Rules:
- No git operations.
- Single window — do NOT emit `[ROTATE]`.
- Emit `[DONE]` only after `docs/THEME_BONDS_FIX_NOTES.md` is saved and `theme_bonds.json` edits are complete.
- Do not invent set IDs or bonds. Every change must trace to a verified file on disk.
- If you cannot verify a step, write the uncertainty into the notes rather than guessing.

Deliverable: `docs/THEME_BONDS_FIX_NOTES.md`
