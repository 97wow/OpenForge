Task #31: Extend `gamepacks/rogue_survivor/theme_bonds.json` with 3 new cross-set theme bonds that incorporate the 6 Wave A mechanical set IDs (`healer_set_bonus`, `tracker_set_bonus`, `weakness_set_bonus`, `war_machine_set_bonus`, `soul_harvest_set_bonus`, `blood_moon_set_bonus`). This closes Wave A's integration into the second-layer cross-set bonus system.

Background: Wave A landed 6 mechanical bonds in `data/spells.json` (Task #27) and got language display backfill (Task #28). The existing `theme_bonds.json` (post-Task #14 fix) has 26 entries that already reference some of these blueprint IDs — but not in combinations that exercise multiple Wave A subclasses together. This task adds 3 new cross-set bonds that USE Wave A subclasses as primary participants, giving Wave A players a payoff for combining the new mechanical archetypes.

Procedure:
1. Read `gamepacks/rogue_survivor/theme_bonds.json` in full — confirm the schema, especially:
   - The exact JSON structure (top-level array vs object)
   - Field names (`id`, `name_key`, `desc_key`, `required_sets`, `bonus_effects`, etc.)
   - The format of `bonus_effects` blocks (look at 3-5 existing entries to copy the pattern)
2. Read `docs/SETS_EXPANSION_PROPOSAL.md` per-set sections (§1-§6 for healer/tracker/weakness/war_machine/soul_harvest/blood_moon) — each one's "Cross-set theme bond opportunities" subsection has design recommendations for what the new theme bonds should be. Use those proposals as the basis; do NOT invent fresh combinations from scratch.
3. Pick the 3 most thematically-coherent, lowest-design-risk cross-bond combinations from those proposals. Examples that should appear in the proposal text:
   - **Resilience** (or similar): `healer_set_bonus` + `war_machine_set_bonus` (defensive sustain × offensive durability)
   - **Apex Predator** (or similar): `tracker_set_bonus` + `weakness_set_bonus` (target-marking + damage amplification)
   - **Twilight Reaper** (or similar): `soul_harvest_set_bonus` + `blood_moon_set_bonus` (soul stacking + low-HP damage)
   Use the proposal's actual proposed names if it gave them. Otherwise pick names per the proposal's flavor cues.
4. For each of the 3 new theme bonds, design a minimal `bonus_effects` block that:
   - Uses ONLY effect types and stat keys already used by existing entries in `theme_bonds.json` (do NOT invent new types)
   - Magnitudes stay within the existing band — eyeball the existing 26 entries and pick a value at the median or below; do not exceed the strongest existing magnitude
   - Has 2-3 effect blocks per theme bond (consistent with existing entries)
5. Append the 3 new entries to `theme_bonds.json`. Do NOT modify any of the existing 26 entries.
6. Validate:
   - `python3 -c "import json; d=json.load(open('gamepacks/rogue_survivor/theme_bonds.json')); print('OK', len(d))"` — must parse and show 29 entries
   - Schema spot-check: every new entry has the same set of top-level keys as the closest existing entry
7. Produce `docs/THEME_BONDS_WAVE_A_INTEGRATION.md` with:
   - **§1. New theme bonds added** — table: name_key, required_sets, bonus_effects summary, source proposal section
   - **§2. Schema verification** — output of validation commands from step 6
   - **§3. I18n keys needed** — list of new BOND_* `name_key` and `desc_key` values added; flag whether they exist in `lang/*.json` (they likely don't yet — that's a follow-up i18n task, not this task)
   - **§4. Magnitude rationale** — one paragraph per new theme bond on why the chosen magnitudes fit within existing power band
   - **§5. Rollback snippet** — `git checkout -- gamepacks/rogue_survivor/theme_bonds.json`

Safety rails:
- Do NOT modify any existing theme_bond entry. Only append.
- Do NOT invent new effect type strings or stat keys. Reuse from the existing 26 entries.
- Do NOT exceed the strongest existing magnitude in any field.
- If the proposal's cross-set suggestions are unclear or absent, pick conservatively and document the choice in §4 rather than guessing aggressively.
- Budget is tight ($1.5, 1 window). If 3 don't fit cleanly, do 2 and document the third for a follow-up.

Rules:
- No git, no other code/data changes.
- Single window, no `[ROTATE]`.
- Emit `[DONE]` when saved.

Deliverable: `docs/THEME_BONDS_WAVE_A_INTEGRATION.md`
