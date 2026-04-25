Task #19: Produce docs/ONBOARDING_PLAN.md — a concrete plan for the minimum-viable tutorial / onboarding content for the rogue_survivor GamePack.

Procedure:
1. Read `docs/ROGUE_SURVIVOR_GAPS.md` §3 in full:
   - §3.1 What §2 of GAME_DESIGN_PLAN implies should exist
   - §3.2 What actually exists in-pack
   - §3.3 Onboarding section summary
2. Read `docs/GAME_DESIGN_PLAN.md` §2 to understand the design intent for first-time-player flow.
3. Identify every onboarding moment the player needs to be informed about (first card draft, first set bonus completion, first boss, first job-change at Lv5, first rare card, etc.). Cross-reference §3.1's list with what makes the "Brotato/Vampire Survivors first 60 seconds" feel learnable rather than confusing.
4. For each onboarding beat, design:
   - **Trigger** — exactly when in the game it fires (engine event name + condition; verify against shipped EventBus events by reading `EventBus` autoload + recent `_emit("...")` call sites, do NOT invent events that aren't actually emitted).
   - **UI surface** — toast / modal / arrow / pulse / tooltip.
   - **Copy (EN + CN)** — keep each line ≤ 30 words EN and a tight CN translation matching project convention. Use `I18n.t("KEY")` keys — propose the key.
   - **Dismissal rule** — one-shot (per save) vs. repeats every run.
   - **Skip condition** — how the player opts out of all onboarding (must exist; see CLAUDE.md respect for player autonomy).
5. Order beats by priority: §A "must-ship", §B "nice-to-have", §C "future polish".
6. Add a §N "Implementation footprint" summary: list every existing GamePack file that would need to change to wire this in (do NOT change them in this task — just enumerate). Distinguish "purely additive" (new file, no existing changes) from "modifies existing module" (call out which one).
7. Add a §N+1 "What is already partially wired" section listing any existing `rogue_announce.gd` / `rogue_hud.gd` / etc. surfaces this design can reuse rather than duplicate.

Constraints:
- Do NOT modify game code.
- Do NOT generate localization files; just propose the I18n keys + EN/CN strings inline.
- Do NOT invent events that aren't emitted — verify every Trigger by grepping for the event name in `gamepacks/rogue_survivor/scripts/` and `src/`.
- Stay grounded in shipped reality — if §3.1 implies an onboarding hook the engine cannot currently fire, flag it as "REQUIRES NEW EVENT" rather than designing a beat that can't ship.

Rules:
- No git, no game code changes.
- Single window, no `[ROTATE]`.
- Emit `[DONE]` when the plan is saved.

Deliverable: `docs/ONBOARDING_PLAN.md`
