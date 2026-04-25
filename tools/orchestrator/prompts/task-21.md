Task #21: Produce docs/SHIP_READINESS_v2.md — an updated ship-readiness audit that synthesizes everything produced in Batches 0/1/2 and updates SHIP_PLAN.md's view of the project state.

Procedure:
1. Read `docs/SHIP_PLAN.md` in full — this is the prior baseline you are updating.
2. Read every deliverable produced by the recent autonomous batches (file paths, do NOT skip any):
   - `docs/STEAM_PAGE_DRAFT.md` (Task #7, edited by #15 + #17)
   - `tools/setup/install_hunyuan3d_mac.sh` (Task #6)
   - `gamepacks/rogue_survivor/theme_bonds.json` (Task #13, fixed by #14)
   - `docs/AUDIO_GAP_REPORT.md` (Task #11, edited by #16)
   - `docs/THEME_BONDS_FIX_NOTES.md` (Task #14)
   - `docs/STEAM_PAGE_NUMBERS_AUDIT.md` (Task #15)
   - `assets/audio/ATTRIBUTIONS.md` (Task #16)
   - `docs/STEAM_PAGE_CLEANUP_NOTES.md` (Task #17)
   - `docs/ART_ASSET_PLAN.md` (Task #18)
   - `docs/ONBOARDING_PLAN.md` (Task #19)
   - `docs/SETS_EXPANSION_PROPOSAL.md` (Task #20 — sibling task in this batch; may not exist yet at task start, that is OK — note it as "in-flight" and skip its content if absent)
3. Read `docs/ROGUE_SURVIVOR_GAPS.md` and `docs/GAME_DESIGN_PLAN.md` headings to keep the synthesis grounded.
4. Produce `docs/SHIP_READINESS_v2.md` with the following sections:
   - **§1. What changed since SHIP_PLAN.md** — bullet list of every artifact added/edited by Batches 1+2, one line each, with the path
   - **§2. New shipping gates that opened/closed** — which entries in SHIP_PLAN's "关键缺口" / "下一会话入口" are now resolved, partially resolved, or still open. Cite the specific deliverable that resolved each.
   - **§3. New gaps surfaced by the batches** — issues found during the autonomous work that SHIP_PLAN didn't know about (e.g. `_card_manager` is null per Task #14, 8 unknown-provenance audio files per Task #16, `splitter_set_bonus` orphan, etc.)
   - **§4. Recommended next 3 work items** — specific, sized, ranked by ship-criticality. Each must trace to an existing deliverable's TODO or a §3 gap. Do NOT invent new agendas.
   - **§5. SHIP_PLAN.md edit suggestions** — exact line-level surgical edits to apply to `docs/SHIP_PLAN.md` to bring it current. Format as a diff-style table (line, before, after). Do NOT apply the edits — propose only.
   - **§6. Hard blockers vs. soft blockers** — every remaining open item categorized as "blocks Steam launch" vs. "post-launch polish". Use the design plan as the launch-criteria reference.
5. Keep the document under 400 lines. This is an executive synthesis, not a re-explanation.

Constraints:
- Do NOT modify `SHIP_PLAN.md`. Propose edits only.
- Do NOT modify any other doc. Read-only synthesis.
- If a Batch-2-sibling deliverable (Task #20's output) doesn't exist when this task runs, gracefully note it as in-flight in §1 and exclude it from §2-§6 reasoning.

Rules:
- No git, no code/data changes.
- Single window, no `[ROTATE]`.
- Emit `[DONE]` when saved.

Deliverable: `docs/SHIP_READINESS_v2.md`
