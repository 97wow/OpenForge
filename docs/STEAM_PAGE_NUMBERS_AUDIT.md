# STEAM_PAGE_DRAFT.md — Numerical Claims Audit

> Date: 2026-04-25 — Reconciliation of "14 set-bonus archetypes / 38 cards" claims against the shipped gamepack data.

---

## 1. What the draft claimed (before this audit)

- **14 set-bonus archetypes** — appeared in short desc (EN+CN), long desc (implicit), feature bullet #1 (EN+CN), Steam tag #2, trailer 60s VO.
- **38 cards drafted 3-at-a-time** — appeared in short desc (EN), feature bullet #1 (EN+CN), trailer 60s VO.

## 2. What the shipped gamepack actually contains

### Player-facing draftable set bonuses (the "set-bonus archetypes")

Source: `gamepacks/rogue_survivor/data/spells.json`, entries with `type: "bond"`.
This file is the single source of truth loaded by `gamepacks/rogue_survivor/scripts/rogue_card_system.gd:855` (the active card system; `card_manager.gd` is unused / vestigial — `_card_manager` stays null in `rogue_game_mode.gd:42`).

- **14 bond entries.** IDs (numeric): 19, 20, 21, 22, 23, 30, 38, 42, 51, 56, 64, 71, 80, 89.
- All 14 are referenced by at least one card via `bond_id`, i.e. all are reachable in-game.
- ✅ The "**14**" figure in the draft is accurate.

### Drafted cards (the "cards drafted 3-at-a-time" pool)

Source: same `spells.json`, entries with `type: "card"`.

- **52 cards.** Tier breakdown: 10 tier-1 (common), 11 tier-2 (rare), 22 tier-3 (epic), 9 tier-4 (legendary).
- Cards have no `set_id` field set, so they all default to `"basic"` and enter the initial draft pool — confirmed by `_build_initial_pool()` in `rogue_card_system.gd:521`.
- The first 3 draws are forced "prep" picks (cards 1/2/3, all bond_id=19) shown in the same 3-card UI; from draw 4 onward the pool randomises 3-at-a-time from the remaining 49 cards.
- ❌ The "**38**" figure in the draft is wrong — actual shipped count is **52**.

### Other set/bond data files (for context — not part of the headline claim)

| File | Count | What it is | Player-facing? |
|---|---|---|---|
| `data/spells.json` `type:"bond"` | 14 | Draftable set bonuses with cards | **Yes — this is the "14" we ship** |
| `spells/*_set_bonus.json` | 30 | SpellSystem-level effect definitions; loaded by `GamePackLoader` into the framework's SpellSystem registry | No — these are internal effect blueprints, several are referenced indirectly by the 14 player bonds and by theme bonds |
| `theme_bonds.json` | 26 | Cross-set "second-layer" theme bonds (complete N different sets → unlock extra effect), loaded by `rogue_theme_bond.gd` | Yes, but separate concept — NOT what the Steam draft means by "set-bonus archetypes" |

The 30 `*_set_bonus.json` files are the most likely source of the surplus that triggered the audit. They are SpellSystem definitions, not draftable archetypes — the reason the player-facing count stays at 14 is that only the 14 bonds in `spells.json` have cards mapped to them.

## 3. What the design plan said

`docs/GAME_DESIGN_PLAN.md`:

- §2.4 line 67 — header reads `卡组与套装体系（目标 30+ 套装）` ("target 30+ sets").
- §2.4 line 69 — `**当前 14 套装 + 规划新增 16 套**` ("currently 14 sets + 16 new sets planned" → 30 total).
- §2.4 line 96 — planned-set table ends with the 16 listed expansion sets (健愈者…毁灭).
- §6 line 396 — capability comparison table cell `38卡+14套装` ("38 cards + 14 sets").
- §7 line 423 — P2 roadmap item `更多套装（→30个）` ("more sets, target 30").

So the design plan itself is the origin of both numbers in the Steam draft. The "14 sets" still matches reality. The "38 cards" was the count at the time the design plan was written; cards have since been added (52 today) without expanding the bond count.

## 4. Reconciliation decision

| Claim | Draft said | Reality | Decision |
|---|---|---|---|
| Set-bonus archetypes | 14 | 14 | **Keep 14** — accurate and consistent with design plan |
| Cards in draft pool | 38 | 52 | **Update to 52** — Steam page should describe the actual shipped game |

**Rationale for choosing the precise "52" over rounded "50+"**: the draft already uses precise counts elsewhere (10 difficulties, 6 schools, 20 levels, 10-minute boss). Switching to a rounded marketing figure for one number breaks the voice. "52" is also more compelling than "50+" in feature-bullet copy because it implies a hand-curated catalogue, not an inflated marketing approximation.

**Why not lower the "14" to match the 30 file count**: the 30 files in `spells/` are SpellSystem effect blueprints loaded into the framework registry, not playable archetypes the player drafts toward. They have no cards mapped to them in `spells.json`. Citing 30 would be the inverse error — overstating shipped player content.

## 5. Edits made to `docs/STEAM_PAGE_DRAFT.md`

Surgical edits only; no other content was rewritten.

| Line | Section | Before | After |
|---|---|---|---|
| 11 | EN short desc | `draft 3-pick cards, snap together 14 set-bonus builds` | `draft from 52 cards 3-at-a-time, snap together 14 set-bonus builds` (also tightened phrasing elsewhere in the sentence to keep total ≤300 chars: `Lv.1–Lv.20 with a Lv.5 job-change`, `then endless`) |
| 14 | CN short desc | `每局随机 3 选 1 抽卡，拼出 14 套羁绊构筑` | `每局从 52 张卡池随机 3 选 1 抽卡，拼出 14 套羁绊构筑` |
| 44 | Feature bullet #1 EN | `*14 Set-Bonus Archetypes, 38 Cards Drafted 3-at-a-Time.*` | `*14 Set-Bonus Archetypes, 52 Cards Drafted 3-at-a-Time.*` |
| 45 | Feature bullet #1 CN | `**14 套羁绊、38 张卡、3 选 1 抽取**` | `**14 套羁绊、52 张卡、3 选 1 抽取**` |
| 139 | 60s trailer VO row | `"Draft 38 cards. Snap 14 sets. Build anything."` | `"52 cards. 14 sets. Build anything."` |

Tag #2 (line 68, "3-pick card drafting with 14 set bonuses") already used the correct 14 — left untouched.

The character-count annotations `*(298 chars)*` (line 11) and `*(约 140 字符)*` (line 14) were recomputed and updated to `*(275 chars)*` and `*(约 144 字符)*` respectively. Both remain under Steam's 300-character short-description ceiling.

## 6. Other factual issues spotted during the audit (NOT fixed in this task)

These are out of scope (count-related only is the brief), but recording for whoever picks up next:

1. **Stray `[ROTATE]` token at line 59** — a session-control marker from a previous LLM run got committed into the markdown body. It will render literally on Steam. Should be deleted.
2. **"Six damage schools" naming inconsistency**: the draft calls them *Physical / Frost / Fire / Nature / Shadow / Holy* (matches `CLAUDE.md`). Verify against the actual `HealthComponent` enum in framework code before launch — names sometimes drift between marketing copy and enum strings.
3. **"$4.99 season pass" specificity** — pricing claim is unverified against any current store config; if the season-pass SKU isn't finalised, soften to "small seasonal cosmetic pass" before publication.
4. **"Set-bonus" naming**: the in-game system uses the term "羁绊 / bond" (per `spells.json` `type:"bond"` and `_all_bonds` in `rogue_card_system.gd`), while the Steam copy uses "set bonus / 套装". This is a marketing-vs-implementation split, not strictly an error, but worth aligning if the in-game UI ever localises to English — players reading "bond" in-tooltip won't immediately map it to "set bonus" on the store page.
5. **Theme bonds (26 entries in `theme_bonds.json`) are not mentioned anywhere in the Steam draft.** They are a shipped second layer of cross-set bonuses and are arguably the differentiator vs. plain Brotato. Future copy revision could add a "+ 26 cross-set theme bonds layered on top" line to the feature bullet — the framework and content already exist.

---

*Audit by automated reconciliation pass; counts re-verifiable by re-running the JSON enumeration steps in §2.*
