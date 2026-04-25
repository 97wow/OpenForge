# rogue_survivor Shipping Gaps

> Cross-references `docs/GAME_DESIGN_PLAN.md` §8.1 tech_roadmap against the actual
> state of `gamepacks/rogue_survivor/` as of 2026-04-24.
>
> §8.1 checklist:
> - [x] Godot 4.6 框架层 (complete)
> - [x] rogue_survivor GamePack (basic version complete)
> - [ ] 美术资源替换 (art replacement)
> - [ ] 音效系统 (SFX system)
> - [ ] 新手引导 (onboarding tutorial)

---

## PRIORITY RANKING (effort-to-ship, smallest → largest)

| # | Gap | Effort | Ship impact |
|---|---|---|---|
| 1 | **Wire existing SFX files to gameplay events.** 15 SFX + 1 BGM are already in `assets/audio/{sfx,bgm}/` with `.import` stubs. Only `battle_01.mp3` is actually played (`rogue_game_mode.gd:207`). Adding `EngineAPI.play_sfx` calls on spell_cast / projectile_hit / entity_died / level_up / card_picked would light up the whole audio layer. | ≤ 0.5 day | Immediately ticks §8.1 "音效系统" to a usable state. |
| 2 | **Fix the two broken `vfx.call("play_sfx", …)` call sites** at `rogue_rewards.gd:475` (boss_death) and `rogue_hero.gd:130` (level_up). `rogue_vfx.gd` has no `play_sfx` method, so these silently no-op today. Redirect to `EngineAPI.play_sfx`. | ≤ 0.5 hour | Removes a dead code path; makes level-up and boss-death audible. |
| 3 | **Add spell/card icons.** `assets/sprites/icons/game_icons/` ships 3,534 game-icons.net SVGs that nothing references. Add an `icon` field to each spell JSON and render it in `rogue_card_ui.gd` + `rogue_hud_skillbar.gd` (both text-only today). | 1 day (icons are already on disk; only wiring + JSON edits). | Card draft and skill bar stop being text-only — huge readability win. |
| 4 | **Replace solid-colour projectile placeholders.** `arrow` / `fireball` / `heavy_bolt` / `enemy_fountain` / `life_fountain` render as flat-colour spheres/cylinders. Simple particle meshes or sprite-billboards would be a drop-in upgrade. | 1–2 days | Combat visual quality goes from prototype to shippable. |
| 5 | **Reassign boss/enemy models.** `bone_dragon`, `shadow_lord`, `void_titan`, `golem`, `goblin`, `archer`, `shadow`, `shaman` all share 4 `Skeleton_*` meshes rescaled 0.7–3.0×. Bosses especially read as scaled-up mooks. Need at minimum 3 unique boss meshes + 2 non-skeleton minion meshes. | 3–5 days (sourcing or commissioning 5+ low-poly models). | Enemy identity + boss encounter moment read correctly. |
| 6 | **First-time-player onboarding flow.** See §3 — zero tutorial content exists. | 3–5 days (designed + localised + scripted). | Ticks §8.1 "新手引导". Retention lever for F2P Steam launch. |

---

## 1. Art Asset Audit

The gamepack has **moved to 3D GLB models** rather than the 2D sprite pipeline the
`assets/sprites/{heroes,enemies,effects}/` directories were built for — those
three directories are still empty on disk. Entities render via `visual.scene` →
`res://assets/models/...glb` or, for projectiles/fountains/training dummy, via
`visual.color` primitives (ColorRect / sphere / cylinder).

### 1.1 Entity-by-entity

| Entity | visual source | File present | Style / placeholder state |
|---|---|---|---|
| hero | `characters/Barbarian.glb` | yes (+ PBR texture PNG) | Real art, low-poly fantasy (Synty-style). The player-visible hero has no class-specific silhouette selection at spawn time. |
| warrior | `characters/Knight.glb` | yes | Real art, matches subject. |
| mage | `characters/Mage.glb` | yes | Real art, matches subject. |
| ranger | `characters/Rogue_Hooded.glb` | yes | Real art, close fit. |
| archer | `enemies/Skeleton_Rogue.glb` | yes | Real art but **wrong subject** — a skeleton stands in for a living archer enemy. Placeholder-by-reuse. |
| goblin | `enemies/Skeleton_Minion.glb` @ 0.7× | yes | Skeleton reused as goblin (wrong subject). |
| skeleton | `enemies/Skeleton_Warrior.glb` | yes | Real art, matches subject. |
| shaman | `enemies/Skeleton_Mage.glb` @ 1.0× | yes | Skeleton mage reused as "shaman" (wrong subject). |
| shadow | `enemies/Skeleton_Rogue.glb` @ 0.9× | yes | Skeleton reused. |
| golem | `enemies/Skeleton_Warrior.glb` @ 1.6× | yes | Skeleton reused as golem, just upscaled. |
| bone_dragon | `enemies/Skeleton_Warrior.glb` @ 2.5× | yes | **Badly wrong** — a 2.5×-scaled warrior skeleton standing in for a dragon boss. |
| shadow_lord | `enemies/Skeleton_Mage.glb` @ 2.0× | yes | Upscaled skeleton mage as boss. |
| void_titan | `enemies/Skeleton_Warrior.glb` @ 3.0× | yes | Upscaled skeleton warrior as boss. |
| arrow | `visual.color #ffee58` sphere | N/A | **Solid colour placeholder** — yellow ball. |
| fireball | `visual.color #ff7043` sphere | N/A | **Solid colour placeholder** — orange ball. |
| heavy_bolt | `visual.color #ffffff` sphere | N/A | **Solid colour placeholder** — white ball. |
| enemy_fountain | `visual.color #d32f2f` cylinder | N/A | **Solid colour placeholder** — red cylinder. |
| life_fountain | `visual.color #ce93d8` cylinder | N/A | **Solid colour placeholder** — purple cylinder. |
| training_dummy | `visual.color #aa8844` cylinder | N/A | **Solid colour placeholder** — brown cylinder (intentional, low priority). |

**Tally** — 19 entities:
- **5 real + correct**: hero, warrior, mage, ranger, skeleton.
- **8 real-but-reused-wrong-subject**: archer, goblin, shaman, shadow, golem, bone_dragon, shadow_lord, void_titan — 4 enemy meshes stretched across 8 roles, including all three bosses.
- **6 solid-colour primitives**: arrow, fireball, heavy_bolt, enemy_fountain, life_fountain, training_dummy.

### 1.2 Spell / card icons

- Spells examined — `test_fireball`, `frost_slow_spell`, `bone_dragon_breath`, `shadow_lord_nova`, `void_titan_slam`, `reaper_execute`, `poison_dot`, `flame_burn`, `storm_shockwave`, `guardian_reflect`: **none define any `icon` / `icon_path` / `texture` field**.
- `rogue_card_ui.gd` draws card-selection UI procedurally — `Label` + `ColorRect` + `StyleBoxFlat` tinted by rarity. No icon textures loaded.
- `rogue_hud_skillbar.gd` shows 3-character name abbreviations and tier-colour strips. No icons.
- **~3,534 game-icons.net SVGs sit unused in `assets/sprites/icons/game_icons/`**; Kenney UI atlases in `assets/sprites/icons/kenney/` are only wired for panels/bars.

### 1.3 Art section summary — critical shipping gaps

1. All projectiles (`arrow`, `fireball`, `heavy_bolt`) and both fountains render as solid-colour primitives.
2. Four `Skeleton_*` meshes reused across 8 enemy roles, including all 3 bosses.
3. No spell/card icons exist; card draft and skill bar are text-only despite a 3.5 k-file icon pack being in-tree.
4. `hero.json` (base player) uses Barbarian; classes `warrior/mage/ranger` each have a distinct character model, but there is no class-specific hero silhouette at spawn time.

---

## 2. Audio Gap Audit

### 2.1 Files on disk

**BGM** (`assets/audio/bgm/`)
- `battle_01.mp3`

**SFX — framework layer** (`assets/audio/`)
- `death.wav`, `level_up.wav`, `shoot.wav`
- `hit_physical.wav`, `hit_fire.wav`, `hit_frost.wav`, `hit_nature.wav`, `hit_shadow.wav` (no `hit_holy.wav` despite Holy being one of the 6 damage schools)

**SFX — Kenney library** (`assets/audio/sfx/`)
- `footstep_01.ogg`, `footstep_02.ogg`, `footstep_03.ogg`
- `gold_pickup.ogg`
- `hit_generic.ogg`, `hit_light.ogg`, `hit_metal.ogg`, `hit_metal_alt.ogg`
- `melee_swing.ogg`, `move_command.ogg`, `select_unit.ogg`, `spell_cast.ogg`
- `ui_click.ogg`, `ui_click_alt.ogg`, `ui_hover.ogg`, `ui_hover_alt.ogg`, `ui_toggle.ogg`

### 2.2 Call sites in the gamepack

Exhaustive grep for `play_sfx|play_bgm|AudioManager|EngineAPI.play_|.wav|.ogg|.mp3` under `gamepacks/rogue_survivor/`:

| File:line | Call | Status |
|---|---|---|
| `rogue_game_mode.gd:207` | `EngineAPI.play_bgm("res://assets/audio/bgm/battle_01.mp3", 2.0)` | **Works.** Only live audio call in the gamepack. |
| `rogue_rewards.gd:475` | `vfx.call("play_sfx", "boss_death", -3.0)` | **Broken.** `rogue_vfx.gd` has no `play_sfx` method (only `_vfx_proc_*` / `_spawn_ground_circle` / `_effect_to_vfx`). Call no-ops. Also, no `boss_death.ogg/wav` file exists. |
| `rogue_hero.gd:130` | `vfx.call("play_sfx", "level_up", -5.0)` | **Broken.** Same method-missing problem. `level_up.wav` DOES exist but is never reachable through this call path. |
| `test_arena_panel.gd:1735` | `EngineAPI.get_system("audio")` | Dev/debug panel only — just checks the system is registered, doesn't play anything. |

### 2.3 What the framework actually provides

`src/systems/audio_manager.gd` exposes: `play_bgm`, `stop_bgm`, `play_ambience`, `play_sfx`, `play_sfx_random_pitch`, `play_sfx_at` (3D positional). `src/core/engine_api.gd:650-670` wraps `play_bgm` / `stop_bgm` / `play_sfx` / `set_audio_volume`. None of the "positional" / "random pitch" variants are called from the gamepack. No `play_ambience` calls anywhere.

### 2.4 Missing — would need to be authored

- `boss_death.ogg` (referenced, absent).
- `hit_holy.wav` (Holy damage school has no SFX).
- Card-draft / card-pick UI SFX (no card interaction sounds).
- Reward-pickup / relic-pickup SFX.
- Class-specific spell-cast variants (today's single `spell_cast.ogg` is generic).
- Wave-start / wave-end / elite-spawn / boss-spawn stingers.
- Menu / character-select / difficulty-select BGM (only one combat track exists).

### 2.5 Audio section summary

The framework audio API is complete and the SFX library is ~80 % stocked, but **the gamepack has effectively no wiring**: only battle BGM plays; every other SFX file on disk is dead weight because nothing calls `EngineAPI.play_sfx` or `AudioManager.play_sfx_at` from combat/reward/UI events. Fixing this is mostly a wiring job (priority #1 above), not an audio-production job.

---

## 3. Tutorial / Onboarding Gap Audit

### 3.1 What §2 of GAME_DESIGN_PLAN implies should exist

The design plan's expected first-time-player arc (inferred from §2.1 / §2.2 / §3.1):
1. **Welcome screen / brand splash** — platform and game identity.
2. **Character select** — choose hero/class.
3. **Difficulty select** — N1–N10 (delivered in commit `650cdf6`).
4. **First-wave tutorial** — explain movement, auto-attack, enemy threat.
5. **First card-draft explainer** — popup teaching the 3-choose-1 card flow, rarity colours, synergy/set-bonus concept.
6. **First elite kill moment** — explain the elite-word affix system (§3.3).
7. **First boss intro** — cinematic or banner framing the boss wave, explain 2-minute cadence.

### 3.2 What actually exists in-pack

| Stage | In repo | Notes |
|---|---|---|
| Welcome / splash | ❌ | No welcome scene. Pack entry goes straight to `character_select`. |
| Character select | ✅ | `scenes/character_select/character_select.{gd,tscn}`. Functional; does class choice. No tutorial overlay, no "first time here?" panel. |
| Difficulty select | ✅ | `scenes/difficulty_select/difficulty_select.{gd,tscn}`. N1–N10 per recent commit. |
| First-wave tutorial | ❌ | `rogue_wave_system.gd` starts wave 1 cold; no hint text, no pause-on-first-enemy, no "WASD / auto-attack" overlay. Player is dropped into combat with no instruction. |
| First card-draft explainer | ❌ | `rogue_card_ui.gd` shows `CARDS_COUNT` + `CARDS_FULL_HINT` i18n labels, but those are runtime state strings, not onboarding. No "this is your first card — here's what rarity means" modal. |
| First elite kill framing | ❌ | `rogue_elite.gd` attaches affixes, but no UI moment marks the player's first elite encounter or teaches the affix-word system. |
| First boss intro | ❌ | No boss-intro banner, cinematic, or explainer. Boss waves arrive identically to normal waves (per §3.1 cadence). `rogue_hud_announce.gd` may show a wave banner — not equivalent to an onboarding beat. |

Full-tree grep for `tutorial|guide|welcome|onboard|first_time|引导|新手` inside `gamepacks/rogue_survivor/` returns zero script matches beyond the empty `shape_hint` keyword (entity JSONs) and two UI `hint` labels in `rogue_card_ui.gd` that are unrelated to onboarding.

### 3.3 Onboarding section summary

**5 of the 7 expected first-time-player moments are missing.** Only character-select and difficulty-select exist. The player currently:
- has no welcome framing,
- is dropped into wave 1 with no control or objective explanation,
- sees their first card-draft with no rarity/synergy tutorial,
- hits their first elite with no indication the affix-word system exists,
- encounters bosses as an undifferentiated "bigger wave".

This is the single largest remaining blocker to `§8.1 - [ ] 新手引导`. It is also effort-heavy because each step needs copy writing (×4 languages via the I18n pipeline), UI layout, trigger plumbing into `rogue_wave_system.gd` / `rogue_card_ui.gd` / `rogue_elite.gd`, and a "first-time only" persistence flag on the local save so returning players don't get re-taught.

---

*Audit date: 2026-04-24. Source of truth: files under `gamepacks/rogue_survivor/` and `assets/` at time of audit — no code modifications were made.*
