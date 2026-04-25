Task #27: Materialize "Wave A" of the 16 new set-bonus archetypes per `docs/SETS_EXPANSION_PROPOSAL.md` §17. Produce the real JSON files + bond registry entries, taking the shipped set count from 14 to 20.

Background: Task #20 proposed 16 new sets grouped into 3 waves (A/B/C). Wave A was explicitly chosen as "lowest implementation cost — don't require new cards or framework hooks." Task #26 just repaired the theme_bond system so that when these new bonds exist they'll actually be observable at runtime. This task is what ships the compound value.

Procedure:
1. Read `docs/SETS_EXPANSION_PROPOSAL.md` in full, especially §17 "Implementation phasing" to confirm which 6 sets are Wave A.
2. For each Wave A set, read §N (the per-set section) to extract:
   - The proposed `id` (must match pattern `<base>_set_bonus`)
   - The proposed `data/spells.json` bond entry skeleton
   - The proposed `spells/<name>_set_bonus.json` effect skeleton
3. Study ONE existing `gamepacks/rogue_survivor/spells/*_set_bonus.json` file as the canonical schema reference. Match its structure byte-for-byte: key order, nesting depth, tab/space convention. Mis-schema'd JSON will break the `GamePackLoader` at game boot.
4. Study `gamepacks/rogue_survivor/data/spells.json` to locate:
   - The JSON top-level structure (object vs array vs nested dict)
   - Where to insert new `type: "bond"` entries (at the end of that collection, alphabetized, or some other convention — verify, don't guess)
   - The next free numeric `bond_id` — enumerate existing `type:"bond"` entries to find the max current ID, then allocate sequentially from max+1
5. For each of the 6 Wave A sets:
   a. Create `gamepacks/rogue_survivor/spells/<name>_set_bonus.json` with the effect skeleton from the proposal. Copy patterns; do not invent new fields.
   b. Append a new `type: "bond"` entry to `data/spells.json` with the bond skeleton. Use the next numeric bond_id. Add all required name_key / desc_key strings.
6. After all edits, verify:
   - `python3 -c "import json; json.load(open('gamepacks/rogue_survivor/data/spells.json'))"` parses without error
   - `python3 -c "import json; [json.load(open(p)) for p in ['<list of 6 new files>']]"` all parse
   - `grep -c '"type":\s*"bond"' gamepacks/rogue_survivor/data/spells.json` shows count increased by exactly 6
   - No duplicate bond_id across old + new entries
7. Produce `docs/SETS_WAVE_A_APPLIED.md` with:
   - **§1. Sets materialized** — table: set name, new files created (path + line count), new bond_id assigned, i18n keys that should be added next
   - **§2. Validation output** — raw output of each verification command from step 6
   - **§3. I18n keys needed** — list every new `name_key` / `desc_key` string added to JSON that does not yet exist in any `lang/*.json` pack. Do NOT add translations — just enumerate so a follow-up task can translate in bulk.
   - **§4. Rollback snippet** — exact `rm` + `git checkout` to undo the 6 new files + the spells.json edit.
   - **§5. Next wave recommendation** — one line on whether Wave B/C can be done the same way or need something different.

Safety rails:
- Do NOT modify any of the existing 14 bond entries in `data/spells.json`. Only append new ones.
- Do NOT modify any existing `*_set_bonus.json` file. Only create new files.
- Do NOT modify `theme_bonds.json` — Task #14/26 already handled it and the new sets can be linked in later.
- Do NOT invent new fields not present in the canonical example file you studied in step 3.
- If JSON parse fails after your edits: undo the breaking change, document it as SKIPPED in §1, and continue with the rest.
- If you cannot confidently identify the JSON structure of `data/spells.json` (step 4): do NOT guess. Create only the 6 `*_set_bonus.json` files (step 5a), skip step 5b, and document in §1 that spells.json edits were deferred.
- Budget is tight ($2, 1 window). If 6 is too many in time, do 3 and document what's left. Partial ship > corrupt ship.

Rules:
- No git operations.
- Single window, no `[ROTATE]`.
- Emit `[DONE]` when deliverable saved.

Deliverable: `docs/SETS_WAVE_A_APPLIED.md`
