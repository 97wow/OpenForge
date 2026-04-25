Task #17: Apply the 5 out-of-scope fixes flagged by docs/STEAM_PAGE_NUMBERS_AUDIT.md §6 to docs/STEAM_PAGE_DRAFT.md.

The Task #15 audit listed five issues it deliberately did not fix because the brief was count-related only. Address each now with surgical edits (do NOT rewrite the document).

Procedure:
1. Read `docs/STEAM_PAGE_NUMBERS_AUDIT.md` §6 in full to ground every change in the audit's findings.
2. Apply each fix:
   a. **Stray `[ROTATE]` token at line 59** — delete it (and any leftover blank-line collateral).
   b. **Damage-school name verification** — the draft lists Physical / Frost / Fire / Nature / Shadow / Holy. Verify against the actual `HealthComponent` enum in framework code (likely `src/components/health_component.gd` or wherever `DamageSchool` is declared). If names match: note "verified" in the deliverable. If they drift: update the draft to match the enum strings exactly.
   c. **`$4.99` season pass specificity** — soften to a non-committal phrasing (e.g. "small seasonal cosmetic pass") in both EN and CN, since the SKU isn't finalized. Note the exact lines edited.
   d. **"Set-bonus" vs "bond" terminology** — the in-game schema uses `type: "bond"` while the Steam copy uses "set bonus / 套装". The audit notes this is a marketing-vs-implementation split. Decision: KEEP the marketing term "set bonus / 套装" on the store page (it reads better to genre fans), but ADD one parenthetical alignment note where the in-game UI is described — e.g. "(in-game: 羁绊 / bond)" on the first feature bullet, both EN and CN. Verify with grep that the in-game UI does say 羁绊/bond before adding.
   e. **Add a theme-bonds mention** — `gamepacks/rogue_survivor/theme_bonds.json` ships 26 cross-set theme bonds; the draft never mentions them. Append a short sentence to feature bullet #1 (EN+CN) noting "+26 cross-set theme bonds layered on top" or equivalent. Keep it factual; do not exceed Steam character limits if the bullet has any.
3. Update the `*(275 chars)*` / `*(约 144 字符)*` annotations on the EN/CN short descriptions if they change as a result of any edit. Recompute exactly, not estimate.
4. Produce `docs/STEAM_PAGE_CLEANUP_NOTES.md` listing every line you edited (line number, before, after, rationale tied back to §6 item a-e).

Rules:
- No git, no game code changes, no rewriting.
- Single window — do NOT emit `[ROTATE]` (in particular: do not emit the literal token; the previous draft already showed how that goes wrong).
- Emit `[DONE]` only when both files are saved.
- If you cannot verify a step (e.g. cannot find the damage-school enum), document the uncertainty rather than guessing.

Deliverable: `docs/STEAM_PAGE_CLEANUP_NOTES.md`
