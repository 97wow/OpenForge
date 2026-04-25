Task #25: Produce docs/ONBOARDING_JSON_SPEC.md — specify each of the 5 §A (must-ship) onboarding beats from `docs/ONBOARDING_PLAN.md` as data-driven TriggerSystem / EventBus JSON configs, avoiding net-new game code as far as possible.

Background: `CLAUDE.md` explicitly states "数据驱动优先于代码 — 新技能/效果/规则应该只需写 JSON，不需要改代码" and documents a framework `TriggerSystem` as "ECA 引擎（事件→条件→动作）". `docs/ONBOARDING_PLAN.md` §A1-A5 specify 5 must-ship onboarding beats (welcome, first draft, first bond, first boss, skip-toggle). The goal of this task is to express those 5 beats as TriggerSystem JSON so they ship without new GDScript — or, if TriggerSystem is missing any action type needed, document the minimum new action handlers required.

Procedure:
1. Read `docs/ONBOARDING_PLAN.md` §A1-A5 in full — these are the 5 beats to specify.
2. Read the TriggerSystem source (likely `src/systems/trigger_system.gd` or equivalent — grep for `TriggerSystem` to locate). Understand:
   - JSON schema for a trigger (event name, condition expression, action list)
   - What action handlers exist today (enumerate every registered action type)
   - What event names are emitted by the game vs. declared-only
3. Read `gamepacks/rogue_survivor/scripts/rogue_announce.gd` and `rogue_hud.gd` to see what UI surfaces (toasts, modals, highlights) can be driven from external code — these are what TriggerSystem actions would target.
4. For each of §A1-A5, produce:
   - **JSON config block** — a valid TriggerSystem trigger entry ready to drop into a data file (likely `gamepacks/rogue_survivor/triggers/onboarding.json` or wherever the trigger registry expects). Use only event names verified to be emitted and action types verified to exist.
   - **Where to register** — which file/registry loads this JSON (grep to confirm; do NOT invent a loader).
   - **Required new action handlers (if any)** — if an existing action type can't express the beat (e.g. "highlight this UI element"), document the minimum Godot-side action class that would need to be added. Describe its API as a code comment spec, don't write the implementation. Keep count of total new actions under 3 — if more are needed, the fix is bigger than a data-driven patch.
   - **I18n keys used** — the keys proposed in `ONBOARDING_PLAN.md`; confirm they fit the project's I18n convention.
5. Produce `docs/ONBOARDING_JSON_SPEC.md` with:
   - **§0. Executive summary** — "Beats A1, A2, A5 can ship purely data-driven; A3 and A4 need 1 new action handler (`show_highlighted_toast`)" or whatever the real answer is
   - **§1-§5. One section per beat (A1-A5)** — each containing the 4 items above
   - **§6. Required new action handlers** — consolidated list with API specs (if any)
   - **§7. Loader registration** — which file needs a one-line change to auto-load the new trigger JSON at pack boot
   - **§8. Risks and open questions** — anything you found in the existing TriggerSystem that blocks this approach (e.g. "TriggerSystem doesn't support one-shot triggers; we'd need a `oneshot: true` flag add")

Constraints:
- Do NOT create any new JSON, `.gd`, or `.tscn` file. This is a spec document only.
- Do NOT invent TriggerSystem API that doesn't exist — grep to confirm every field name and action type before citing it.
- Do NOT invent event names. If an onboarding beat needs an event that isn't currently emitted (verify with `_emit("...")` grep), flag it explicitly in §8.
- Prefer fewer, larger JSON blocks over many tiny ones — onboarding is conceptually one feature.

Rules:
- No git, no code/data changes.
- Single window, no `[ROTATE]`.
- Emit `[DONE]` when saved.

Deliverable: `docs/ONBOARDING_JSON_SPEC.md`
