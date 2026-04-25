# STEAM_PAGE_DRAFT.md — Out-of-Scope Cleanup Pass

> Date: 2026-04-25 — Applies the five fixes flagged in `docs/STEAM_PAGE_NUMBERS_AUDIT.md` §6 that were deliberately deferred from the Task #15 (count-only) audit. Surgical edits only; no other content rewritten.

---

## §6 item (a) — Stray `[ROTATE]` token

- **Before (line 59 pre-edit):** `[ROTATE]` (literal, on its own line, inside the markdown body between feature bullet 5 and the `---` divider)
- **After:** removed entirely. The blank line above and the `---` divider below now sit adjacent with a single blank between them.
- **Edit footprint:** deleted line 59 + the trailing blank (line 60) of the original file. The `---` divider that was line 61 is now line 59.
- **Rationale:** §6 (1) — session-control marker accidentally committed; would render literally on Steam.

## §6 item (b) — Damage-school name verification

- **Source of truth checked:** `src/entity/components/health_component.gd:7-13` declares the enum (named `DamageType`, not `DamageSchool`):
  ```
  PHYSICAL,  # 物理（白色）
  FROST,     # 冰霜（蓝色）
  FIRE,      # 火焰（橙色）
  NATURE,    # 自然（绿色）
  SHADOW,    # 暗影（紫色）
  HOLY,      # 神圣（黄色）
  ```
  Same enum members are referenced in `src/systems/damage_pipeline.gd` and the i18n keys `DMG_PHYSICAL/FROST/FIRE/NATURE/SHADOW/HOLY`.
- **Draft text checked (long desc EN line 24, long desc CN line 34, feature bullet 4 EN line 53, feature bullet 4 CN line 54):** all six names match the enum members exactly (with CN translations 物理 / 冰 / 火 / 自然 / 暗影 / 神圣 mirroring the enum comments).
- **Verdict:** **verified — no draft edit required.**
- **Minor caveat (documented, not actioned):** the enum is named `DamageType` in code while the draft and `CLAUDE.md` call them "damage schools." The audit's concern was *member names*, which match. The collective noun differs but is a marketing-vs-internals choice, not a factual error. Flagging for awareness only.
- **Rationale:** §6 (2) — verify before launch; the audit asked us to confirm the marketing copy doesn't drift from the enum strings. It does not.

## §6 item (c) — `$4.99` season pass softened

- **Edit 1 — long desc EN, line 28:**
  - **Before:** `No pay-to-win: the optional season pass is $4.99 for cosmetics, XP-curve boosts, and seasonal relics — every stat-relevant item is earned in-run.`
  - **After:** `No pay-to-win: an optional small seasonal cosmetic pass offers cosmetics, XP-curve boosts, and seasonal relics — every stat-relevant item is earned in-run.`
- **Edit 2 — long desc CN, line 38:**
  - **Before:** `绝不卖数值：$4.99 赛季通行证只卖外观 / 经验加速 / 限定遗物 —— 所有影响数值的道具都从对局中获取。`
  - **After:** `绝不卖数值：可选的小额赛季外观通行证只卖外观 / 经验加速 / 限定遗物 —— 所有影响数值的道具都从对局中获取。`
- **Rationale:** §6 (3) — pricing claim unverified against any current store config; SKU not finalized. Softened to a non-committal phrasing in both languages while preserving the cosmetics-only / never-pay-to-win promise.

## §6 item (d) — "Set-bonus" vs "bond" alignment parenthetical

- **Pre-check (grep evidence):** `lang/en.json:337` `"BONDS": "Bonds"`; `lang/zh_CN.json:337` `"BONDS": "已获羁绊"`; `lang/zh_CN.json:538` `"THEME_BONDS": "主题羁绊"`. Confirmed in-game UI uses **bond / 羁绊** in both languages, so the parenthetical alignment note is factually grounded.
- **Edit — feature bullet #1, line 44 (EN) and line 45 (CN). (See also §6(e) below — same lines, combined into a single Edit call.)**
  - **Before EN:** `*14 Set-Bonus Archetypes, 52 Cards Drafted 3-at-a-Time.*`
  - **After EN:** `*14 Set-Bonus Archetypes (in-game: 羁绊 / bond), 52 Cards Drafted 3-at-a-Time.*`
  - **Before CN:** `**14 套羁绊、52 张卡、3 选 1 抽取**`
  - **After CN:** `**14 套羁绊（游戏内：羁绊 / bond）、52 张卡、3 选 1 抽取**`
- **Decision per brief:** KEPT marketing term ("Set Bonus / 套") on the store page (reads better to genre fans). ADDED a single parenthetical alignment note on the first feature bullet (EN+CN) so a player who installs the game and sees `BONDS` / `羁绊` in-tooltip can map it back to the storefront term.
- **Rationale:** §6 (4) — marketing-vs-implementation split; not strictly an error, but worth aligning. Parenthetical placement is cheap, prevents player confusion, doesn't dilute the marketing voice elsewhere on the page.

## §6 item (e) — Theme-bonds mention added

- **Source of truth checked:** `gamepacks/rogue_survivor/theme_bonds.json` ships **26 cross-set theme bonds** (figure cited in §2 of the audit and consistent with `THEME_BONDS` i18n key at `lang/zh_CN.json:538`).
- **Edit — feature bullet #1, line 44 (EN) and line 45 (CN). (Combined with §6(d) edit above.)**
  - **EN — appended sentence:** ` Plus 26 cross-set theme bonds layered on top.` (added to the end of the bullet, after the "Stormcaller, and Time Lord, no two runs build the same." sentence)
  - **CN — appended sentence:** `另有 26 条跨套主题羁绊叠加其上。` (added to the end of the bullet, after the "每局 Build 各不相同。" sentence)
- **Length check:** Steam "About This Game" feature bullets have no hard char ceiling (the 8000-char cap is on the long-desc as a whole). Adding ~50 EN chars and ~16 CN chars is well within room.
- **Rationale:** §6 (5) — 26 theme bonds is a shipped, differentiated second layer of cross-set bonuses (vs. plain Brotato) and was missing from the storefront pitch. One factual sentence, no embellishment.

## Short-description char-count annotations (not changed)

- **EN line 11 `*(275 chars)*`** — none of the five fixes touched line 11. **No recompute needed; annotation unchanged.**
- **CN line 14 `*(约 144 字符)*`** — none of the five fixes touched line 14. **No recompute needed; annotation unchanged.**

---

## Summary of edits

| Original line | Section | Item | Edit |
|---|---|---|---|
| 59 | (between feature bullets and `---`) | (a) | Deleted stray `[ROTATE]` token + trailing blank line |
| 28 | Long desc EN | (c) | `$4.99` season pass → "small seasonal cosmetic pass" |
| 38 | Long desc CN | (c) | `$4.99 赛季通行证` → `可选的小额赛季外观通行证` |
| 44 | Feature bullet #1 EN | (d) + (e) | Added `(in-game: 羁绊 / bond)` parenthetical and `Plus 26 cross-set theme bonds layered on top.` tail |
| 45 | Feature bullet #1 CN | (d) + (e) | Added `（游戏内：羁绊 / bond）` parenthetical and `另有 26 条跨套主题羁绊叠加其上。` tail |

(b) — verified, no draft edit required.

Total: 4 surgical edits to the draft, 1 verification with no edit. All five §6 items addressed.
