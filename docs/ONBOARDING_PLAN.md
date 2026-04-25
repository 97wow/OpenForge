# rogue_survivor — Minimum-Viable Onboarding Plan

> Closes the §8.1 "新手引导" checkbox surfaced in `docs/ROGUE_SURVIVOR_GAPS.md` §3.
> Scope: design only — no code changes in this task.
> Audit basis: `gamepacks/rogue_survivor/scripts/` and `src/systems/` as of 2026-04-25.

---

## Guiding principles (from CLAUDE.md + GAME_DESIGN_PLAN.md §2)

1. **Don't pause combat** unless the design beat is itself a modal (card draft, class promotion). The "Brotato / Vampire Survivors first 60s feel" is keep-moving-while-learning, not a wall of text.
2. **One-shot per save by default.** Repeating tutorial popups every run is what makes survivor games feel hostile to veterans.
3. **Player autonomy.** A single "Skip All Tutorials" toggle in the save flag must always work. Per-beat dismissal also stores the flag.
4. **Reuse what ships.** `rogue_hud_announce` (left-side fading toast) and the boss-warning flash already exist — most beats should hang off them rather than build new HUD widgets.
5. **Never invent events.** Every Trigger below is grounded in a real `EventBus.emit_event(...)` or `_gm.emit(...)` call site, or marked **REQUIRES NEW EVENT** when the engine cannot currently fire the hook.

---

## Verified emitted-event inventory (the only hooks we may use)

| Event | Bus | Emitter | Payload keys |
|---|---|---|---|
| `wave_started` | EventBus | `rogue_wave_system.gd:144` | `wave`, `duration`, `elite_count` |
| `wave_started` | _gm bus | `rogue_spawner.gd:95` | `wave_index`, `enemy_count` |
| `draft_available` | EventBus | `rogue_wave_system.gd:290` | `wave` |
| `all_waves_complete` | EventBus | `rogue_wave_system.gd:306` | (empty) |
| `game_time_up` | EventBus | `rogue_wave_system.gd:163` | (empty) |
| `bond_activated` | EventBus | `rogue_card_system.gd:430` | `bond_id` |
| `hero_level_up` | _gm bus | `rogue_hero.gd:125` | `level` |
| `card_selected` | _gm bus | `rogue_card_ui.gd:409,578` | `card_id`, `level` |
| `entity_killed` | EventBus | framework `damage_pipeline.gd` | `entity`, `killer`, `ability`, `overkill` |
| `entity_damaged` | EventBus | framework `damage_pipeline.gd` | `entity`, `amount`, `source` |
| `game_victory` / `game_defeat` | _gm bus | `rogue_game_mode.gd:419,427` | `reason` |

**Not emitted today (REQUIRES NEW EVENT to support some beats below):**
`elite_spawned`, `boss_spawned`, `class_promotion_offered`, `rare_card_offered`, `first_relic_offered`. The closest signal we can reach without engine changes is `wave_started` + checking `WAVE_CONFIGS[current_wave].is_boss`, or hooking `rogue_spawner.show_boss_warning()` directly.

---

## §A — MUST-SHIP beats (cuts the "I have no idea what's happening" problem)

These are the five that shipping without is the actual blocker on §8.1.

### A1. Welcome / movement primer (first run only, before wave 1)

- **Trigger:** `wave_started` (EventBus) where payload `wave == 1` AND save flag `seen_welcome` is false.
  - Verified at `rogue_wave_system.gd:144`. Persistence via `SaveSystem.save_data("rogue_survivor_onboarding", "seen_welcome", true)` (pattern matches `src/systems/save_system.gd:32`).
- **UI surface:** Left-side `rogue_hud_announce.add(...)` toast, **non-modal**. Movement keys also rendered as a 5-second pulsing label centred on hero (reuse the `_boss_warning_label` style from `rogue_spawner.gd:205`, recoloured cyan).
- **Copy (≤ 30 words EN):**
  - `TUTORIAL_WELCOME_MOVE` — EN: `WASD or arrow keys to move. Attacks fire automatically — focus on positioning.` / CN: `WASD 或方向键移动，攻击自动释放，专注走位即可。`
- **Dismissal:** One-shot per save. Auto-fades after 5 s; sets flag immediately on display.
- **Skip:** Suppressed entirely if `tutorials_disabled == true`.

### A2. First card-draft explainer (the §3.3 "rarity / set bonus" gap)

- **Trigger:** `hero_level_up` (`_gm` bus) where `level == 2` AND save flag `seen_first_draft` is false.
  - Verified at `rogue_hero.gd:125`. Note: `level == 2` is the first level-up after spawn (Lv1 → Lv2).
  - **Implementation note:** the beat must paint *before* `rogue_card_ui.show_card_selection()` opens, so the listener has to fire on `hero_level_up`, set a one-frame `_pending_first_draft_hint = true`, and `rogue_card_ui` must call `_render_first_draft_overlay()` inside `show_card_selection()` when the flag is set.
- **UI surface:** Modal overlay rendered as a child of the existing card-draft panel — three labelled arrows pointing at (a) the rarity stripe, (b) the card name, (c) the "X / 14 sets" counter (`CARDS_COUNT` label already exists in `rogue_card_ui.gd`). "Got it" button dismisses.
- **Copy:**
  - `TUTORIAL_DRAFT_TITLE` — EN: `Pick one card.` / CN: `三选一抽卡。`
  - `TUTORIAL_DRAFT_RARITY` — EN: `Blue → Purple → Orange = stronger and rarer.` / CN: `蓝→紫→橙，越亮越强、越稀有。`
  - `TUTORIAL_DRAFT_SETS` — EN: `Collect cards of the same colour family to unlock set bonuses.` / CN: `集齐同色卡片可激活套装羁绊。`
  - `TUTORIAL_DRAFT_OK` — EN: `Got it` / CN: `知道了`
- **Dismissal:** One-shot per save. Sets `seen_first_draft = true` on click, before card pick.
- **Skip:** Suppressed if `tutorials_disabled`.

### A3. First set bonus (羁绊) activation

- **Trigger:** `bond_activated` (EventBus) — first occurrence per save.
  - Verified at `rogue_card_system.gd:430`. Payload `bond_id` resolves via existing bond table for display name.
  - Persist `seen_first_bond = true` after first fire.
- **UI surface:** Existing `rogue_hud.add_announcement()` already prints a line on bond_activate today (per gap-audit notes). We **add** a second one-time toast that explicitly explains *what just happened*, plus a 1.5 s screen vignette pulse (already present in `rogue_vfx`).
- **Copy:**
  - `TUTORIAL_BOND_FIRST` — EN: `Set bonus unlocked! Collecting matching cards triggers stronger effects — check the right-side panel.` / CN: `首次激活套装羁绊！集齐同色卡牌可触发更强效果，详情见右侧面板。`
- **Dismissal:** One-shot. Toast auto-fades (5 s, `rogue_hud_announce` default).
- **Skip:** Suppressed if `tutorials_disabled`. The underlying gameplay log line still prints.

### A4. First boss intro

- **Trigger:** `wave_started` (EventBus) where `WAVE_CONFIGS[current_wave].is_boss == true` AND save flag `seen_first_boss` is false.
  - Verified data path at `rogue_wave_system.gd:204` (boss spawn) and `rogue_spawner.show_boss_warning()` at `rogue_spawner.gd:198`. The wave system already triggers `show_boss_warning` for boss waves (`rogue_spawner.gd:124`, `:166`).
  - **Cleanest hook:** add the listener at the wave-system level, not the spawner — `wave_started` carries enough info; otherwise a new `boss_intro_shown` event would have to be added (avoid).
- **UI surface:** Reuses the existing red `_boss_warning_label` flash from `rogue_spawner.gd:205-219`. **Adds** a one-time subtitle line below it for first-time players only ("This is a boss wave — they hit harder, drop more loot, and respawn every ~2 minutes").
- **Copy:**
  - `TUTORIAL_BOSS_FIRST` — EN: `Boss wave! Bosses hit harder and drop guaranteed rewards. They return roughly every 2 minutes.` / CN: `BOSS 来袭！更高伤害、保底奖励，约每 2 分钟出现一次。`
- **Dismissal:** One-shot. Auto-fades with the existing boss-warning tween (~2.5 s total).
- **Skip:** Suppressed if `tutorials_disabled`. Boss warning itself still plays — that is gameplay framing, not tutorial.

### A5. "Skip all tutorials" toggle

- **Trigger:** Settings panel — must exist before any §A beat ships.
- **UI surface:** Add a single checkbox in the existing pause/settings menu (or character_select footer if there's no in-game settings yet — verify against `scenes/character_select/character_select.tscn`).
- **Copy:**
  - `TUTORIAL_SKIP_TOGGLE` — EN: `Skip all tutorial popups` / CN: `跳过所有新手引导`
- **Dismissal:** Persisted as `SaveSystem.save_data("rogue_survivor_onboarding", "tutorials_disabled", true/false)`.
- **Skip:** N/A — this is the skip control itself.

---

## §B — NICE-TO-HAVE beats (smooth out the "what was that?" moments)

### B1. First class promotion at Lv5 explainer

- **Trigger:** `hero_level_up` (`_gm` bus) where `level == 5` AND save flag `seen_promotion` is false.
  - Verified at `rogue_hero.gd:125`. The Lv5 promotion modal is `rogue_card_ui.show_promotion_selection()` — the explainer overlays *its* panel.
- **UI surface:** Same pattern as A2 — labelled arrows on the two class options before the player picks.
- **Copy:**
  - `TUTORIAL_PROMOTION_FIRST` — EN: `Class change! This choice is permanent for this run — read both passives carefully.` / CN: `转职抉择！本局不可重选，请仔细阅读两条进阶被动。`
- **Dismissal:** One-shot.
- **Skip:** Honors `tutorials_disabled`.

### B2. First elite kill explainer (affix words)

- **Trigger:** `entity_killed` (EventBus) where `data.entity.get_meta_value("is_elite", true) == true` AND save flag `seen_first_elite` is false.
  - Verified: elite metadata flag at `rogue_elite.gd:67`; `entity_killed` hooked already in `rogue_game_mode.gd:175`.
  - **Caveat:** `entity_killed` payload carries `entity`; `is_instance_valid()` check required because the entity is mid-`queue_free` at emit time. Read meta before hand-off.
- **UI surface:** `rogue_hud.add_announcement()` toast (left side, fades), gold colour to match elite framing.
- **Copy:**
  - `TUTORIAL_ELITE_FIRST` — EN: `Elite slain! Elites carry random affix words — watch the buff bar to see what abilities they had.` / CN: `首次击杀精英！精英携带随机词缀，查看 Buff 栏可了解其能力。`
- **Dismissal:** One-shot.
- **Skip:** Honors `tutorials_disabled`.

### B3. First rare (purple/orange) card offered

- **Trigger:** Inside `rogue_card_ui.show_card_selection()` — when the drafted set first contains any card whose rarity tier is purple or higher AND save flag `seen_rare_card` is false.
  - **No event for this exists.** Implementation is a local check inside `rogue_card_ui` before rendering — no event needed.
- **UI surface:** Subtle pulsing border on the rare card's frame (already supported via existing `StyleBoxFlat` rarity tint) + a one-line subtitle above the panel.
- **Copy:**
  - `TUTORIAL_RARE_CARD_FIRST` — EN: `Rare card available! Higher tiers unlock 3-4-card set bonuses — worth grabbing if it fits your build.` / CN: `稀有卡片登场！高阶套装需 3-4 张同色卡，契合 build 时优先选择。`
- **Dismissal:** One-shot.
- **Skip:** Honors `tutorials_disabled`.

### B4. First low-HP warning (defensive prompt)

- **Trigger:** `entity_damaged` (EventBus) where `data.entity == _gm.hero` AND post-damage `health.current_hp / health.max_hp < 0.25` AND save flag `seen_low_hp` is false.
  - Verified: `entity_damaged` is core, fires from `damage_pipeline.gd`. Filter on hero in the listener.
- **UI surface:** `rogue_hud.add_announcement()` red toast + screen-edge red vignette (reuse damage flash if present).
- **Copy:**
  - `TUTORIAL_LOW_HP_FIRST` — EN: `HP critical! Move away from enemies and let regen catch up — you don't have to brawl.` / CN: `生命危险！拉开距离让生命自动恢复，不必正面硬刚。`
- **Dismissal:** One-shot.
- **Skip:** Honors `tutorials_disabled`.

---

## §C — FUTURE-POLISH beats (defer to post-EA)

### C1. Welcome / brand splash before character_select

A proper logo splash + 5-second brand frame. **REQUIRES NEW SCENE** (`scenes/welcome/welcome.tscn`) — currently the pack entry goes straight to `character_select`. Out of scope for an MVP onboarding pass; flag for the EA-launch art pass.

### C2. First treasure / relic pickup explainer

GAME_DESIGN_PLAN.md §3.2 specifies a 50-kill treasure system (3-choose-1). **`rogue_relic.gd` exists** in the pack — but no `relic_offered` / `relic_picked` events are emitted today (verified by full grep). **REQUIRES NEW EVENT** (`relic_offered`, payload `{relic_ids: Array}`) before this beat can ship. Not blocking §A.

### C3. First "endless mode" framing

`all_waves_complete` (EventBus, verified `rogue_wave_system.gd:306`) is the obvious hook. Once endless mode is properly designed (currently a 900 s timer per the wave system), a one-shot "you're in endless — survive until X" toast is trivial to add.

### C4. Per-job opening tip

After class selection, a class-specific 1-liner hint ("Knights heal off blocked hits — stay close to enemies"). Pure copy work + one listener on `card_selected` filtering by promotion-card IDs. Defer until the §A beats prove out.

### C5. Tutorial replay panel

A pause-menu submenu that lets the player re-play any of the §A/§B beats on demand. Worth doing once §A is validated by playtests.

---

## §N — Implementation footprint (what files would need touching)

> No edits in this task. Listed for the implementation ticket that follows.

### Purely additive (new files only)

| New file | Purpose |
|---|---|
| `gamepacks/rogue_survivor/scripts/rogue_onboarding.gd` | Module class. `init(game_mode)`, owns the listener wiring + save-flag reads/writes. Mirrors the per-feature module pattern (e.g., `rogue_elite.gd`, `rogue_rewards.gd`). |
| `gamepacks/rogue_survivor/scripts/rogue_onboarding_overlay.gd` | The labelled-arrow modal used by A2 and B1. Reusable widget; `show(targets: Array, copy: Dictionary)`. |
| Translation keys in **all four** existing `lang/*.json` packs (EN/CN/JP/KR or whichever shipped — check `lang/` directory) — see Constraints note: the user explicitly said *do not* generate these in this task. The keys are listed inline above; the implementation ticket adds them. |

### Modifies existing module (call out which one and why)

| Existing file | Change required | Beat that needs it |
|---|---|---|
| `rogue_game_mode.gd` | Instantiate `RogueOnboarding`; route `wave_started` / `bond_activated` / `entity_killed` listener fan-out to it (the file is already the EventBus hub at `:175`). Add `_onboarding_module` field. | A1, A3, A4, B2, B4 |
| `rogue_hero.gd` | After `_gm.emit("hero_level_up", ...)` at `:125`, add a hand-off line so the onboarding module can intercept *before* card UI opens (one-frame defer is fine). | A2, B1 |
| `rogue_card_ui.gd` | At the top of `show_card_selection()` and `show_promotion_selection()`, check `_gm._onboarding_module.maybe_render_overlay(panel, "first_draft" / "first_promotion")`. **Also** the rare-card scan inside the draft render loop. | A2, B1, B3 |
| `rogue_wave_system.gd` | None — `wave_started` is already emitted with enough info (`wave`, `duration`). The boss-wave check uses local `WAVE_CONFIGS[current_wave].is_boss`. | A4 |
| `rogue_spawner.gd` | None for §A. (If C2 ships, would need a new `relic_offered` emit here or in `rogue_relic.gd`.) | — |
| Settings UI host (likely `scenes/character_select/character_select.gd` or a new pause menu) | Add the "Skip all tutorials" checkbox, persist via `SaveSystem`. | A5 |

### What does NOT need to change

- `rogue_hud_announce.gd` — `add(msg, color)` already covers all toast beats. No new methods.
- `rogue_hud.gd` — `add_announcement()` wrapper is sufficient.
- `rogue_tooltip.gd` — not used by any beat; ignore.
- `rogue_combat_log.gd` — independent; tutorial copy does NOT go here (combat log is for gameplay events, not pedagogy).
- `event_bus.gd` / `damage_pipeline.gd` / `aura_manager.gd` — no framework changes for §A or §B. Only §C2 needs a new event.
- Localization JSONs — added in the ticket, not this design task (per task constraint).

---

## §N+1 — Already-wired surfaces this design reuses

Auditing `gamepacks/rogue_survivor/scripts/` for what we should *not* duplicate:

| Surface | File | What it already does | How onboarding reuses it |
|---|---|---|---|
| **Left-side fading toast** | `rogue_hud_announce.gd:25` (`add(msg, color)`) | 5 s auto-fade, BBCode supported, max 6 entries, mouse-ignore. Already used by level-up announcements (`rogue_hero.gd:135`) and bond activations. | A1, A3, B2, B4 all toast through this. **Zero new HUD code** for these four beats. |
| **HUD wrapper** | `rogue_hud.gd::add_announcement(msg, color)` | Indirection over the panel. | All listeners call this, never the panel directly. |
| **Boss warning flash** | `rogue_spawner.gd:198-219` (`show_boss_warning(boss_id)`) | Centred red label, four-stage tween, ~2.5 s total. Already fires on every boss + final boss. | A4 layers the one-shot subtitle below it, doesn't replicate the flash. |
| **Card-draft modal** | `rogue_card_ui.gd::show_card_selection()` (`:578` area) | Existing 3-choose-1 panel with rarity tints, set-counter label, "got it" flow. | A2 paints the explainer arrows as children of this panel rather than a standalone modal. |
| **Promotion modal** | `rogue_card_ui.gd::show_promotion_selection()` | Lv5 2-choose-1 with class passives. | B1 layers an explainer the same way. |
| **Bond activation feedback** | `rogue_card_system.gd:430` + `rogue_hud.gd._refresh_bond_panel()` | Already announces in combat log + updates right-side bond list. | A3 only adds a *one-shot* explanatory toast on top — does NOT replace existing feedback. |
| **Save persistence** | `src/systems/save_system.gd:32` (`save_data(ns, key, value)`) | JSON-backed key/value with checksum, namespace `rogue_survivor_onboarding` is unused. | All `seen_*` flags + `tutorials_disabled` go here. Pattern matches `talents.gd:283`. |
| **i18n** | `I18n.t("KEY", [args])` | Already used everywhere; the global rule from `CLAUDE.md` forbids `tr()` / direct TranslationServer. | All copy above is keyed (`TUTORIAL_*`) and ready to drop into existing `lang/*.json` files. |
| **Vignette / level-up VFX** | `rogue_vfx.gd::spawn_vfx("level_up", pos)` (`rogue_hero.gd:129`) | Particle burst at hero. | B4's red flash and A3's bond pulse can reuse the same `spawn_vfx` API rather than building new screen overlays. |

**Net design footprint for §A:** 1 new module file + 1 new overlay widget + listener registrations in `rogue_game_mode.gd`. No new HUD widgets, no new events, no framework changes.

---

## Open questions (flag before implementation)

1. Does the in-game pause menu exist yet? If not, the A5 "Skip All Tutorials" toggle has to live on `character_select` first — verify against `scenes/character_select/character_select.tscn` before ticketing.
2. Lang pack file list — verify which of `lang/en.json` / `lang/zh_CN.json` / etc. ship; this plan assumes EN + CN minimum per the I18n project rule.
3. The `rogue_relic.gd` module is referenced in `scripts/` but its trigger/payload contract was not audited in this pass — confirm before scoping C2.

---

*Plan author: Claude (Opus 4.7) | Date: 2026-04-25 | Source of truth: `gamepacks/rogue_survivor/scripts/` and `src/systems/` at audit time.*
