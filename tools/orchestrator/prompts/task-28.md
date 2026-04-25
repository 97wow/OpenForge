Task #28: Add display entries for the 6 new Wave A bond IDs (90, 91, 93, 96, 97, 99 per `docs/SETS_WAVE_A_APPLIED.md`) into all four `gamepacks/rogue_survivor/data/spells_<lang>.json` files so the new bonds are player-visible without a code change.

Background: Task #27 added 6 new `type: "bond"` entries to `data/spells.json` with bond_ids 90, 91, 93, 96, 97, 99. But the live bond-display path (`rogue_card_system.gd:818 get_spell_name`) looks up display strings by numeric bond_id in the per-language `spells_<lang>.json` files. Those files currently end at id `"89"`, so the new bonds will render as raw ids or fall back to placeholders. This task closes that gap.

Procedure:
1. Read `docs/SETS_WAVE_A_APPLIED.md` §3 — it spells out exactly which bond_ids need entries and which translation strings the agent already verified are present in the `lang/<code>.json` packs.
2. For each of the 4 files — `gamepacks/rogue_survivor/data/spells_en.json`, `spells_zh_CN.json`, `spells_ja.json`, `spells_ko.json`:
   a. Read the file to learn its schema. Each is expected to be a dict keyed by stringified numeric id → `{name, desc}` or similar. Confirm the schema before touching anything.
   b. Locate the last existing id (should be `"89"` per the audit).
   c. For each of `90`, `91`, `93`, `96`, `97`, `99`, append a new entry with:
      - `name` — the language-appropriate translation of the set name. Source: `docs/SETS_EXPANSION_PROPOSAL.md` (it provides EN + CN per set). For `ja` / `ko`, if the proposal doesn't give translations, copy the EN variant (this is honest — a later translation pass can refine, but the keys must not be absent). Mark this fallback in the deliverable.
      - `desc` — one-line description of what the bond does. Use the proposal's bond-effect description, in the target language.
   d. After all 6 entries appended, parse-check the file: `python3 -c "import json; d = json.load(open('<path>')); print(len(d))"` — it must parse and show 6 more keys than before.
3. After all 4 files updated, run a cross-check grep:
   `grep '"90"\|"91"\|"93"\|"96"\|"97"\|"99"' gamepacks/rogue_survivor/data/spells_*.json | wc -l`
   Expected: **24** (6 ids × 4 files).
4. Do NOT touch `lang/*.json` — those files have the `SET_*` keys which are a separate surface and already addressed by earlier tasks.
5. Do NOT modify `data/spells.json` — this task is the display layer, not the data layer.
6. Produce `docs/SPELLS_LANG_BACKFILL.md` with:
   - **§1. Entries added** — 4-column table: file, id, name, desc. Show all 24 rows.
   - **§2. Translation fallback notes** — specifically list which `ja` / `ko` entries were copied from EN due to missing translations in the proposal. These are not errors — they are honest placeholders for a translator to refine.
   - **§3. Validation output** — raw output of parse-checks from step 2d and the grep from step 3.
   - **§4. Rollback snippet** — `git checkout --` on the 4 modified files.
   - **§5. What still requires a code change (reminder)** — the numeric-id lookup path is working, but if the bond hover/tooltip UI pulls the `name_key`/`desc_key` from `data/spells.json` instead of the numeric-id path, those SET_* keys may also be needed. Check and flag; do not fix here.

Safety rails:
- Do NOT modify any existing entries in any of the 4 `spells_<lang>.json` files. Only append new entries.
- Do NOT invent bond_ids — use exactly 90, 91, 93, 96, 97, 99 (the agent should verify these in `data/spells.json` before starting).
- If any of the 4 files has a schema surprise (e.g. not keyed by numeric string), STOP that file and document in §2 rather than force-fitting.
- Budget is tight ($1.5, 1 window). If all 4 files don't fit, do EN + CN first (highest-impact markets per CLAUDE.md), then ja, then ko. Partial is fine; corrupt is not.

Rules:
- No git operations, no other code changes.
- Single window, no `[ROTATE]`.
- Emit `[DONE]` when saved.

Deliverable: `docs/SPELLS_LANG_BACKFILL.md`
