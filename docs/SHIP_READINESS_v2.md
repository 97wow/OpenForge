# OpenForge Ship Readiness v2

> Synthesis of Batches 0/1/2 against the SHIP_PLAN.md baseline.
> Date: 2026-04-25 | Author: handoff agent | Source baseline: `docs/SHIP_PLAN.md` (last edited 2026-04-24).
> This document is read-only synthesis. It does **not** modify `SHIP_PLAN.md`.

---

## §1. What changed since SHIP_PLAN.md

Artifacts added or edited by Batches 1+2 (one line each, with path):

- **`tools/setup/install_hunyuan3d_mac.sh`** (Task #6) — idempotent Apple-Silicon installer for the local 3D-asset pipeline; ships `hunyuan3d-gen` CLI under `~/.openforge-ai-env/bin/`.
- **`docs/STEAM_PAGE_DRAFT.md`** (Task #7, edited by #15 + #17) — full EN+CN store page v1.0: short/long desc, 5 feature bullets, 10 tags, 15 capsule prompts, 60 s/15 s trailer scripts, 3+3 ASO title variants.
- **`docs/AUDIO_GAP_REPORT.md`** (Task #11, edited by #16) — enumerates every BGM/SFX/VO cue, maps to MusicGen + Pixabay + Kenney sources, includes 5 reproducible MusicGen prompts.
- **`gamepacks/rogue_survivor/theme_bonds.json`** (Task #13, fixed by #14) — 26 entries, all `required_sets` IDs now match real `*_set_bonus.json` files (29 ID corrections applied across 26 bonds).
- **`docs/THEME_BONDS_FIX_NOTES.md`** (Task #14) — documents the ID remap and surfaces the `_card_manager == null` dead-code path that prevents bond resolution at runtime.
- **`docs/STEAM_PAGE_NUMBERS_AUDIT.md`** (Task #15) — reconciled "38 cards" (wrong) → "52 cards" (verified), confirmed "14 sets" (verified), called out 5 deferred copy issues for Task #17.
- **`assets/audio/ATTRIBUTIONS.md`** (Task #16) — provenance table for 26 shipped audio files; **9 files marked `unknown — needs follow-up`** (1 BGM + 8 top-level WAVs).
- **`docs/STEAM_PAGE_CLEANUP_NOTES.md`** (Task #17) — applied 4 of the 5 deferred copy fixes (stray `[ROTATE]` removed, $4.99 softened, bond/set parenthetical added, 26 theme-bonds line added) + 1 verification (damage-school enum names match copy).
- **`docs/ART_ASSET_PLAN.md`** (Task #18) — sized the art queue: 5 projectile/fountain sprites (P0), 3 boss meshes (P0), 5 minion meshes (P1); 8 designer questions blocking further authoring.
- **`docs/ONBOARDING_PLAN.md`** (Task #19) — minimum-viable onboarding design: 5 must-ship beats (§A), 4 nice-to-have (§B), 5 future-polish (§C); every trigger grounded in a verified `EventBus` emit site.
- **`docs/SETS_EXPANSION_PROPOSAL.md`** (Task #20) — 16-bond expansion (IDs 90-106) phased into 3 implementation waves; 11 open design questions in §18.

---

## §2. Shipping gates that opened, partially opened, or remain closed

Mapped against `SHIP_PLAN.md` lines 24-36 (`关键缺口` + `扩展内容`) and lines 53-66 (`下一会话入口`).

| SHIP_PLAN entry | Status after Batches 1+2 | Resolved by |
|---|---|---|
| 关键缺口: 美术资源替换 | **Partially resolved** — pipeline + asset list + prompts done; **0 assets rendered** | `tools/setup/install_hunyuan3d_mac.sh` (#6) + `docs/ART_ASSET_PLAN.md` (#18) |
| 关键缺口: 音效系统 | **Partially resolved** — gap audit complete, 5 BGM prompts ready, attribution table created; **0 new audio rendered or wired** | `docs/AUDIO_GAP_REPORT.md` (#11) + `assets/audio/ATTRIBUTIONS.md` (#16) |
| 关键缺口: 新手引导 | **Partially resolved** — design done with grounded triggers; **0 LOC written** | `docs/ONBOARDING_PLAN.md` (#19) |
| 关键缺口: Server backend | **Open** — no batch deliverable | — |
| 关键缺口: Web 平台 | **Open** — no batch deliverable | — |
| 关键缺口: 支付集成 | **Open** — no batch deliverable; pricing softened in store page (Task #17) so non-blocking for EA copy | — |
| 扩展内容: 16 套装新增 | **Partially resolved** — full design with bond IDs, card skeletons, phasing, magnitude guard rails; blocked on `§18.1` product decision | `docs/SETS_EXPANSION_PROPOSAL.md` (#20) |
| 扩展内容: 宝物系统 | **Open** — flagged as `relic_offered` event missing in `ONBOARDING_PLAN.md §C2` | — |
| 扩展内容: 精英词条 | **Already shipped** per `ONBOARDING_PLAN.md §B2` evidence (`rogue_elite.gd:67` `is_elite` meta is live) | — |
| 扩展内容: 战令系统 | **Open** — no batch deliverable | — |
| 下一会话入口 #1: Task #10 美术管线 | **Unblocked** — installer ready; first sprite batch is the next concrete action | Task #6 |
| 下一会话入口 #2: Task #13 套装扩展 30 | **Designed, gated on §18.1 product call** | Task #20 |
| 下一会话入口 #3: Task #7 Steam 商店页 | **Resolved (draft v1.0)** — ready for hero-art dependency to land before publish | Tasks #7 / #15 / #17 |

---

## §3. New gaps surfaced by the batches

Issues the batches discovered that `SHIP_PLAN.md` did not know about:

1. **`_card_manager` is null at runtime** — `rogue_game_mode.gd:42` declares `var _card_manager = null` with **no assignment site anywhere in the pack**. `RogueThemeBond.check_bonds()` calls `_gm._card_manager.get_completed_sets()`; every call site is gated `if _card_manager == null: return`, so the entire 26-bond theme system is **dead code** despite the JSON now being correct. Source: `THEME_BONDS_FIX_NOTES.md (b)`. Steam page now claims "26 cross-set theme bonds layered on top" (Task #17 added this line); claim is true on disk, false at runtime.

2. **9 audio files have unknown provenance** — `battle_01.mp3` (the only live BGM), plus all 8 top-level `*.wav` files (`death`, `hit_{physical,fire,frost,nature,shadow}`, `level_up`, `shoot`). No license, no source URL. **Hard legal-risk block before commercial release.** Source: `ATTRIBUTIONS.md` rows for top-level files.

3. **`splitter_set_bonus` has no theme-bond reference** — exists at `spells/splitter_set_bonus.json` but no `theme_bonds.json` entry mentions it. Either deliberate single-set design or oversight. Source: `THEME_BONDS_FIX_NOTES.md (d)`.

4. **The "shipped 14 sets" the design plan names are not the 14 the player drafts today** — `data/spells.json` `type:"bond"` ships 14 *anime/wuxia* bonds (yonko / akatsuki / dragon_ball / tianlong / wuxia_legend / etc.), not the 14 archetype-themed sets the design plan §2.4 lists (splitter / swift / flame / frost / vampire / poison / barrage / lightning / crit / element / guardian / reaper / storm / time_lord). Player-facing identity drift is invisible in `SHIP_PLAN.md`. Source: `SETS_EXPANSION_PROPOSAL.md §0.1`.

5. **Soul Harvest magnitude conflict (potential game-breaking bug)** — `soul_harvest_set_bonus.json` declares `hero_permanent_damage_per_kill: 0.80, mode: "add"`; `reaper_set_bonus.json` declares the same key at `0.02, mode: "add"`. If both bonds are active in one run, +0.82 permanent damage per kill = run-breaking. Source: `SETS_EXPANSION_PROPOSAL.md §18.8`.

6. **Onboarding hooks the engine cannot fire today** — `elite_spawned`, `boss_spawned`, `class_promotion_offered`, `rare_card_offered`, `relic_offered` events do not exist. `§A` workarounds use `wave_started` + local checks; `§C2` (relic) requires a new event. Source: `ONBOARDING_PLAN.md §A`/§C2.

7. **No in-game pause / settings menu** for the §A5 "Skip All Tutorials" toggle — would have to live on `character_select` until a pause menu exists. Source: `ONBOARDING_PLAN.md §A5` + open question #1.

8. **23+ ProcManager effect IDs and 9 proc trigger flags do not exist** — required by Sets Expansion Waves B and C (`summon_minion`, `apply_mark`, `screen_wipe`, `school_immunity`, `revive_full`, etc.; triggers `on_blink`, `on_low_hp`, `on_hit_from_behind`, etc.). Source: `SETS_EXPANSION_PROPOSAL.md §18.6`.

9. **No per-enemy school-resist stat** — the Alchemist `reroll_damage_school` bond is balanced around its existence; today it's pure flavor. Source: `SETS_EXPANSION_PROPOSAL.md §18.7`.

10. **Damage-school enum is named `DamageType` in code** but called "damage schools" in marketing copy and `CLAUDE.md` — member names match, collective noun differs. Cosmetic only. Source: `STEAM_PAGE_CLEANUP_NOTES.md §6(b)`.

11. **`rogue_card_system.gd` bond loader does not read `name_key` / `desc_key`** from `data/spells.json` bond entries — labels come from a different code path. Adding new bonds with these fields requires loader changes. Source: `SETS_EXPANSION_PROPOSAL.md §18.2`.

12. **`spells/summoner_new_set_bonus.json` filename oddity** — kept the `_new_` infix from a prior iteration; the bond `id` mirrors it. Cosmetic but error-prone for future renames. Source: `SETS_EXPANSION_PROPOSAL.md §18.5`.

13. **Texture C++ extensions probably won't build on Mac** — installer documents the failure and falls back to shape-only via MPS; texture pass requires Replicate fallback. Source: `install_hunyuan3d_mac.sh` lines 196-209.

---

## §4. Recommended next 3 work items

Ranked by ship-criticality. Each traces to an existing deliverable's TODO or a §3 gap.

### #1 — Reconcile theme-bond dead code (HARD launch blocker)

Pick one of the two paths in `THEME_BONDS_FIX_NOTES.md (b)`:
- (a) Rewrite `RogueThemeBond` to resolve `required_sets` against `RogueCardSystem._all_bonds` directly (now-correct `*_set_bonus` IDs match by string), or
- (b) Reinstate `_card_manager` and feed it from the new card pipeline.

Size: 1-2 days (a) or 3-5 days (b). **Without this, the Steam page line "26 cross-set theme bonds layered on top" (added by Task #17) is false at runtime and the 26-entry `theme_bonds.json` ships as inert JSON.**

### #2 — Audit + replace the 9 unknown-provenance audio files (HARD legal blocker)

Per `ATTRIBUTIONS.md` follow-up #1: locate the original download/commit for `battle_01.mp3` and the 8 top-level WAVs, OR replace each with a provenance-clean equivalent (Pixabay CC0 / Kenney CC0 / MusicGen render with sidecar). Adopt the `<file>.source.json` sidecar convention from `AUDIO_GAP_REPORT.md §1` so this never recurs.

Size: 1 day audit + 2-3 days replace if needed. **Required before any paid Steam release.**

### #3 — Implement Onboarding §A1-A5 (HARD launch blocker — bounce-rate driver)

Per `ONBOARDING_PLAN.md §A`, §N: 1 new module file (`rogue_onboarding.gd`), 1 new overlay widget (`rogue_onboarding_overlay.gd`), listener registrations in `rogue_game_mode.gd` / `rogue_hero.gd` / `rogue_card_ui.gd`, save flag namespace `rogue_survivor_onboarding`, and **8 new i18n keys × 4 languages = 32 translation entries**. No framework changes; no new events.

Size: 2-3 days code + 0.5 day translations + 1 day playtest. **Must precede any wishlist-driving demo or Next Fest slot.**

---

## §5. SHIP_PLAN.md edit suggestions

Diff-style — propose only, do **not** apply.

| Line | Section | Before | After |
|---|---|---|---|
| 4 | header date | `> Last updated: 2026-04-24 by Claude Opus 4.7` | `> Last updated: 2026-04-25 by Claude Opus 4.7 (post Batch 2 audits — see docs/SHIP_READINESS_v2.md)` |
| 27 | 关键缺口 美术 | `- [ ] **美术资源替换**（当前占位图 — 最大缺口）` | `- [~] **美术资源替换** — 管线就绪（install_hunyuan3d_mac.sh）+ 资产清单与提示词完成（ART_ASSET_PLAN.md）；待渲染 5 投射物 + 3 boss + 5 小怪` |
| 28 | 关键缺口 音效 | `- [ ] 音效系统` | `- [~] **音效系统** — 缺口审计完成（AUDIO_GAP_REPORT.md，5 个 MusicGen 提示词就绪）；**9 文件来源未知（ATTRIBUTIONS.md）= 商业发布合规风险**` |
| 29 | 关键缺口 新手 | `- [ ] 新手引导` | `- [~] **新手引导** — §A 5 个必发节拍设计完成（ONBOARDING_PLAN.md），全部触发器已对齐真实 EventBus emit；待落码（1 模块 + 1 overlay + 32 翻译键）` |
| 33 | 扩展内容 套装 | `- [ ] 16 套装新增（14 → 30，见 GAME_DESIGN_PLAN §2.4）` | `- [~] 16 套装新增（SETS_EXPANSION_PROPOSAL.md，3 阶段实现波次）— 阻塞于 §18.1 产品决策："14"指武侠 bonds 还是设计案 archetype` |
| (insert after 36) | 扩展内容 (新增条目) | — | `- [ ] **theme_bonds.json 运行时已死** — `_card_manager` 永为 null，26 条 cross-set bond 不触发；详见 SHIP_READINESS_v2 §3.1` |
| (insert after 36) | 扩展内容 (新增条目) | — | `- [ ] **soul_harvest 数值堆叠 bug** — 与 reaper_set_bonus 的 `hero_permanent_damage_per_kill` 同 key add 模式 = 0.82/kill 局内失控；详见 SETS_EXPANSION_PROPOSAL §18.8` |
| 53-56 | 第一要务 | `### 第一要务：美术资源生成管线（Task #10）` ... `入口：Task #6（Set up Hunyuan3D on Mac Studio）先跑通` | `### 第一要务：跑通 Hunyuan3D 首批 5 个投射物 sprites（ART_ASSET_PLAN §1）` ... `入口：Task #6 已完成（install_hunyuan3d_mac.sh 已交付）— 直接运行 hunyuan3d-gen 渲染 §1 五件资产验证管线` |
| 58-60 | 第二要务 | `### 第二要务：套装扩展到 30（Task #13）` ... `参考 GAME_DESIGN_PLAN §2.4 的 16 套清单` | `### 第二要务：解套套装 §18.1 + 修 theme_bonds 死代码` ... `Wave A 6 套装设计已就绪（SETS_EXPANSION_PROPOSAL.md），但需先回答 §18.1 产品问题；同时修 RogueThemeBond._card_manager 死路径（THEME_BONDS_FIX_NOTES.md (b)）` |
| 62-66 | 第三要务 | `### 第三要务：Steam 商店页 + 胶囊图（Task #7）` ... `先写文案（EN + ZH），胶囊图稍后` | `### 第三要务：实现 Onboarding §A1-A5（ONBOARDING_PLAN.md）` ... `Steam 商店页文案已交付（STEAM_PAGE_DRAFT.md v1.0，胶囊图待美术管线产出 hero 图）` |
| (insert before 85) | 红线提醒 (新增) | — | `7. **不要把 theme_bonds.json 当成已上线特性**：JSON 已修，但 _card_manager 是 null，整个 26 条主题羁绊在运行时不触发（详见 SHIP_READINESS_v2 §3.1）` |

---

## §6. Hard blockers vs. soft blockers

Launch criteria reference: `docs/GAME_DESIGN_PLAN.md` §2.1 (core loop), §6.3 (F2P), §8.1 (client). Multiplayer / Server backend / Web platform are explicitly post-launch per `STEAM_PAGE_DRAFT.md` ("multiplayer/co-op... on the roadmap but deliberately excluded").

### Hard blockers (block Steam EA launch)

| Item | Source | Why hard |
|---|---|---|
| Replace 5 projectile/fountain placeholder sprites | `ART_ASSET_PLAN.md §1` (P0) | Currently solid-colour primitives ship; visible from frame 1 |
| Replace 3 boss meshes (Bone Dragon / Shadow Lord / Void Titan) | `ART_ASSET_PLAN.md §2A` (P0) | Bosses are the §3.1 highlight every 2 minutes; reusing skeletons breaks identity |
| Audit + replace 9 unknown-provenance audio files | `ATTRIBUTIONS.md` follow-up #1 | Legal risk for paid Steam release |
| Implement Onboarding §A1-A5 | `ONBOARDING_PLAN.md §A` | "I have no idea what's happening" = Steam refund |
| Resolve theme-bond dead code (`_card_manager == null`) | `THEME_BONDS_FIX_NOTES.md (b)` | Marketed "26 cross-set theme bonds" claim doesn't fire |
| Fix `soul_harvest` × `reaper` magnitude stacking bug | `SETS_EXPANSION_PROPOSAL.md §18.8` | Game-breaking; 0.82/kill permanent damage |
| `hit_holy.wav` (6th school SFX) | `AUDIO_GAP_REPORT.md §2.2` | Holy is one of 6 marketed schools; silence breaks parity |
| Wire `sfx_level_up` (broken call at `rogue_hero.gd:130`) | `AUDIO_GAP_REPORT.md §2.4` | Asset exists, call site broken — visible regression |
| Wire `boss_death` SFX (broken call at `rogue_rewards.gd:475`) | `AUDIO_GAP_REPORT.md §2.2` | Boss kill currently silent |

### Soft blockers (post-launch polish — game ships fine without)

| Item | Source | Why soft |
|---|---|---|
| Replace 5 minion meshes (Archer / Goblin / Shaman / Shadow / Golem) | `ART_ASSET_PLAN.md §2B` (P1) | Re-skinned Skeletons read OK at gameplay distance for EA |
| 16 new sets (Wave A/B/C) | `SETS_EXPANSION_PROPOSAL.md §17` | Game ships with 14 bonds today |
| §B nice-to-have onboarding (class-promotion / first-elite / first-rare / low-HP) | `ONBOARDING_PLAN.md §B` | §A covers the bounce-rate floor |
| §C future-polish onboarding (welcome splash / relic / endless / per-job tip / replay panel) | `ONBOARDING_PLAN.md §C` | Explicitly EA-followup work |
| BGM expansion (menu + alt combat + boss + victory + defeat) | `AUDIO_GAP_REPORT.md §4` | `battle_01.mp3` + provenance fix gets us to launch; rest is polish |
| Per-school spell-cast SFX (8 cues) | `AUDIO_GAP_REPORT.md §2.3` | `sfx_cast_generic` works; per-school is differentiation polish |
| Card / wave / UI / pickup SFX (~30 cues) | `AUDIO_GAP_REPORT.md §2.4-2.7` | Game has been silent on these forever; not a regression |
| Spell icon mapping pass (~143 spells → game-icons.net SVGs) | `ART_ASSET_PLAN.md §4` | Procedural rarity tints are shippable per `ROGUE_SURVIVOR_GAPS §1.3 #3` |
| ElevenLabs VO (announcer / hero grunts) | `AUDIO_GAP_REPORT.md §2.8` | Explicitly "not required for ship" |
| Capsule art / key art / header / small capsule | `STEAM_PAGE_DRAFT.md §5` | Required for Steam page **publish**, but copy is ready and visuals can land in a second pass |
| 战令 / season pass content | `SHIP_PLAN.md` 扩展内容 | Pricing softened to "small seasonal cosmetic pass" in copy (Task #17); F2P core ships without |
| Server backend / cloud save / leaderboard | `SHIP_PLAN.md` 关键缺口 | Excluded from Steam page promises; offline-first per `GAME_DESIGN_PLAN.md §8.1` |
| Web platform (creator portal) | `SHIP_PLAN.md` 关键缺口 | Post-launch UGC story |
| Payment integration (Paddle) | `SHIP_PLAN.md` 关键缺口 | F2P at launch; payment lights up with first season |
| 宝物 / treasure system (50-kill 3-choose-1) | `GAME_DESIGN_PLAN.md §3.2` | Designed but not shipped; runs work without it |
| `splitter_set_bonus` orphan bond | `THEME_BONDS_FIX_NOTES.md (d)` | One-line theme-bond add or accept the design |
| `summoner_new_set_bonus.json` filename oddity | `SETS_EXPANSION_PROPOSAL.md §18.5` | Cosmetic |
| `DamageType` vs "damage school" naming | `STEAM_PAGE_CLEANUP_NOTES.md §6(b)` | Cosmetic |
| ProcManager effect/trigger gaps (23+ effects, 9 triggers) | `SETS_EXPANSION_PROPOSAL.md §18.6` | Only blocks Sets Expansion Waves B/C; 14-bond launch unaffected |
| Per-enemy school-resist stat | `SETS_EXPANSION_PROPOSAL.md §18.7` | Only blocks Alchemist re-roll bond |
| `rogue_card_system.gd` bond loader name_key/desc_key | `SETS_EXPANSION_PROPOSAL.md §18.2` | Only blocks new bonds; existing 14 use a different label path |
| In-game pause/settings menu | `ONBOARDING_PLAN.md §A5` open Q | A5 toggle can live on `character_select` for EA |
| Texture C++ ext on Mac (Hunyuan3D) | `install_hunyuan3d_mac.sh:196-209` | Replicate fallback path documented; shape-only is acceptable for ~80% of placeholders |

---

*End of synthesis. 13 deliverables read. SHIP_PLAN.md not modified. Apply §5 edits in a follow-up turn if approved.*
