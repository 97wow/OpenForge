Task #15: Reconcile numerical claims in docs/STEAM_PAGE_DRAFT.md with the actual gamepack data.

Background: the current Steam draft claims "14 set-bonus archetypes" and "38 cards drafted 3-at-a-time", but spot-checking shows:
- `gamepacks/rogue_survivor/spells/` contains 30 `*_set_bonus.json` files
- `gamepacks/rogue_survivor/data/spells.json` contains ~70 spell entries
The numbers in the draft may be design-plan intent rather than shipped reality, or the draft is just wrong. Find out and fix consistently.

Procedure:
1. Count exactly how many SETS the gamepack ships:
   - Enumerate `gamepacks/rogue_survivor/spells/*_set_bonus.json` and extract each set ID
   - Cross-check against any other registry file (`data/spells.json`, pack manifests)
   - Distinguish "shippable sets" (player-facing, named, drafted) from any dev/internal entries
2. Count exactly how many CARDS are in the draft pool:
   - Find which file `rogue_card_sys.gd` (or equivalent) loads as the card pool
   - Count entries; distinguish rarities if the schema does
3. Read `docs/GAME_DESIGN_PLAN.md` to find the design intent. Does it specify 14/38 explicitly, or are those numbers fabricated?
4. Decide the right reconciliation:
   - If shipped reality > design intent: either update STEAM_PAGE_DRAFT.md to match reality (preferred — Steam pages should describe the actual game) OR explain why the surplus is hidden from players
   - If shipped reality < design intent: STEAM_PAGE_DRAFT.md is overstating; correct it down to truth
   - In all cases the number must be consistent across short desc / long desc / feature bullets / trailer script
5. Update STEAM_PAGE_DRAFT.md with surgical edits — every place a number appears must be revised. Do not rewrite the document.
6. Produce `docs/STEAM_PAGE_NUMBERS_AUDIT.md` containing: actual counts found, design-plan numbers found, reconciliation decision + rationale, and a list of every line in STEAM_PAGE_DRAFT.md that you edited.

Rules:
- No git, no game code changes.
- Single window — do NOT emit `[ROTATE]`.
- Emit `[DONE]` only after both files are saved and the draft is internally consistent.
- If you discover other factual errors in STEAM_PAGE_DRAFT.md while auditing, note them in the audit doc; only fix the count-related ones in this task.

Deliverable: `docs/STEAM_PAGE_NUMBERS_AUDIT.md`
