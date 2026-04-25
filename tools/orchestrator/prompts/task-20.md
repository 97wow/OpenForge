Task #20: Produce docs/SETS_EXPANSION_PROPOSAL.md — design proposal for the 16 new set-bonus archetypes that take the rogue_survivor GamePack from 14 shipped sets to the 30-set design target.

Procedure:
1. Read `docs/GAME_DESIGN_PLAN.md` §2.4 in full. Line 96 of that doc explicitly lists the 16 expansion sets (planned-set table starting at "健愈者…毁灭"). Use those 16 names verbatim — do NOT invent new ones.
2. Read `docs/STEAM_PAGE_NUMBERS_AUDIT.md` to ground yourself in how the existing 14 sets are structured (file format, ID convention, wiring).
3. Read every existing `gamepacks/rogue_survivor/spells/*_set_bonus.json` file to learn the exact JSON schema in use (field names, effect blocks, magnitudes, what counts as a 2/4 piece bonus).
4. Read `gamepacks/rogue_survivor/data/spells.json` `type: "bond"` entries to see how the player-facing bond record (with `bond_id`, name keys, etc.) ties to the `*_set_bonus.json` effect blueprints.
5. Read `gamepacks/rogue_survivor/theme_bonds.json` (just-fixed in Task #14) to understand cross-set theme bonds that the new 16 sets may want to be referenced by.
6. For each of the 16 new sets, propose:
   - **Set name (EN + CN)** — from the design plan list, plus a one-sentence flavor pitch in each language
   - **Proposed `id`** — follows existing pattern `<base>_set_bonus`
   - **Proposed `data/spells.json` bond entry skeleton** — name_key, desc_key, bond_id (next free numeric ID after the existing 14), set_size_threshold matching existing convention
   - **Proposed `spells/<name>_set_bonus.json` effect skeleton** — JSON-ready, modeled on the closest existing set_bonus file. Include 2-piece and 4-piece tiers if existing sets do.
   - **Card slot impact** — does this set need new cards added to `data/spells.json`? If yes, name 2-3 candidate card archetypes per the bond's flavor; do NOT design full card bodies.
   - **Cross-set theme-bond opportunities** — name 1-2 of the existing 26 theme bonds (or propose a new theme bond) this set could plug into.
   - **Difficulty-curve note** — when in N1–N10 progression should this set become drafted/visible? One sentence.
7. Add §17 "Implementation phasing" — group the 16 sets into 3 ship waves (e.g. "Wave A: 6 sets, lowest implementation cost"; "Wave B: 6 sets, depends on new cards"; "Wave C: 4 sets, requires framework hooks not yet shipped"). Justify each placement.
8. Add §18 "Out of scope / open questions" — anything you saw in the design plan or existing code that needs a designer call before any of the 16 can be authored.

Constraints:
- Do NOT create the actual `*_set_bonus.json` or `spells.json` data files. This task is a written proposal.
- Do NOT invent set names beyond the 16 listed in design plan §2.4 line 96.
- Do NOT propose effect magnitudes that exceed the strongest existing set's magnitudes by more than ~30% — keep the 16 within the existing power band.
- If a design plan entry is unclear (just a name, no flavor), say so in your write-up rather than guessing.

Rules:
- No git, no game code/data changes.
- Single-batch deliverable; aim for 1 window. If you are running tight, finish §1-§16 first then §17-§18, do NOT emit `[ROTATE]`.
- Emit `[DONE]` when the proposal is saved.

Deliverable: `docs/SETS_EXPANSION_PROPOSAL.md`
