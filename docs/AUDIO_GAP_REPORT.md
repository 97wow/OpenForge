# Audio Pipeline Gap Report — rogue_survivor GamePack

Scope: enumerate every SFX / BGM / VO cue the `rogue_survivor` GamePack needs
to feel "shipped," map each cue to a free, legally-clean source, and give
reproducible generation prompts for the three BGM tracks that will be made
locally with MusicGen.

References:
- `docs/ROGUE_SURVIVOR_GAPS.md` §2 "Audio Gap Audit" — existing files, live
  call-sites, missing cues.
- `src/systems/audio_manager.gd` — framework playback API.
- `src/core/engine_api.gd` — `EngineAPI.play_sfx` / `play_bgm` wrappers.

This document is a plan. It does **not** change any game code.

---

## 1. Pipeline overview

| Asset class | Source | License | Why |
|---|---|---|---|
| BGM (menu, combat, boss, victory, defeat) | **Local MusicGen** (`facebook/musicgen-small` or `-medium`, MPS) | MIT (model) + CC-BY generated output — we own what we render | Zero marginal cost, infinite re-rolls, consistent tone across tracks |
| SFX (combat, UI, pickup, stinger) | **Pixabay Sound Effects** (CC0 / Pixabay License) | CC0 / royalty-free, no attribution required | Largest free pool, stable CDN, every file is single-file drop-in |
| Optional VO (announcer, hero grunts) | **ElevenLabs free tier** (10k chars/month) | Free tier license permits in-game use with credit; paid tier removes credit req. | Lowest friction; cheap to upgrade if we ship VO |
| Fallback SFX | **Kenney Audio Packs** (already partially used) | CC0 | We already have `assets/audio/sfx/` sourced from here |
| Fallback BGM | **Free Music Archive** filtered to CC-BY / CC0 | CC-BY | In case MusicGen output is unusable for a cue |

Design rule: **every shipped asset must have its source + license recorded
in `assets/audio/ATTRIBUTIONS.md`** (to be created when the pipeline runs —
not in this task). Generated files include the prompt + seed in a sidecar
`.source.json` so a cue can always be re-generated.

---

## 2. Complete cue list

Status legend:
- ✅ on disk, wired (plays today)
- 🟡 on disk, **not** wired (call site missing or broken)
- ❌ missing entirely

### 2.1 BGM

| Cue ID | Trigger | Status | File | Source plan |
|---|---|---|---|---|
| `bgm_menu` | Title / character select / difficulty select | ❌ | `assets/audio/bgm/menu_theme.ogg` | **MusicGen** (prompt §4.1), 90 s loop |
| `bgm_combat` | Wave 1+ standard combat | ✅ | `assets/audio/bgm/battle_01.mp3` | Keep existing; optionally regen with MusicGen for consistency with other tracks |
| `bgm_combat_alt` | Alternate combat track (avoid BGM fatigue in 20-min runs) | ❌ | `assets/audio/bgm/battle_02.ogg` | **MusicGen** (prompt §4.2 variant), 90 s loop |
| `bgm_boss` | Boss wave (every 2 min per §3.1 cadence) | ❌ | `assets/audio/bgm/boss_battle.ogg` | **MusicGen** (prompt §4.3), 120 s loop |
| `bgm_victory` | Run-win screen | ❌ | `assets/audio/bgm/victory.ogg` | **MusicGen** short cue, 20 s one-shot |
| `bgm_defeat` | Game-over screen (wired to new difficulty-system game over) | ❌ | `assets/audio/bgm/defeat.ogg` | **MusicGen** short cue, 15 s one-shot |

### 2.2 SFX — combat / damage

| Cue ID | Trigger | Status | File | Source plan |
|---|---|---|---|---|
| `sfx_hit_physical` | Physical damage tick | ✅ | `assets/audio/hit_physical.wav` | Keep |
| `sfx_hit_fire` | Fire damage tick | ✅ | `assets/audio/hit_fire.wav` | Keep |
| `sfx_hit_frost` | Frost damage tick | ✅ | `assets/audio/hit_frost.wav` | Keep |
| `sfx_hit_nature` | Nature damage tick | ✅ | `assets/audio/hit_nature.wav` | Keep |
| `sfx_hit_shadow` | Shadow damage tick | ✅ | `assets/audio/hit_shadow.wav` | Keep |
| `sfx_hit_holy` | **Holy damage tick — 6th school, missing** | ❌ | `assets/audio/hit_holy.wav` | Pixabay: "divine chime impact" / "bell hit" short |
| `sfx_shoot` | Generic projectile fire | ✅ | `assets/audio/shoot.wav` | Already on disk, need wiring on `projectile_spawned` event |
| `sfx_melee_swing` | Melee attack whoosh | 🟡 | `assets/audio/sfx/melee_swing.ogg` | Wire on `spell_cast` with melee tag |
| `sfx_death` | Enemy death | ✅ | `assets/audio/death.wav` | Wire on `entity_died` filtered by faction=enemy |
| `sfx_boss_death` | Boss dies — **referenced at `rogue_rewards.gd:475` but file missing** | ❌ | `assets/audio/boss_death.ogg` | Pixabay: "demon death roar" + "explosion rumble" mix |

### 2.3 SFX — spell cast (class / school variants)

One generic `spell_cast.ogg` exists and works but is boring; per §2.4 we want
per-school variants so the 11 spell schools read distinct.

| Cue ID | Used by | Status | File | Source plan |
|---|---|---|---|---|
| `sfx_cast_generic` | Fallback | 🟡 | `assets/audio/sfx/spell_cast.ogg` | Wire existing |
| `sfx_cast_fire` | Fireball / flame cards | ❌ | `assets/audio/sfx/cast_fire.ogg` | Pixabay: "fire whoosh cast" |
| `sfx_cast_frost` | Frost cards | ❌ | `assets/audio/sfx/cast_frost.ogg` | Pixabay: "ice crystal shatter" |
| `sfx_cast_lightning` | Lightning / storm cards | ❌ | `assets/audio/sfx/cast_lightning.ogg` | Pixabay: "thunder crack short" |
| `sfx_cast_nature` | Poison / swift cards | ❌ | `assets/audio/sfx/cast_nature.ogg` | Pixabay: "leaves rustle magic" |
| `sfx_cast_shadow` | Shadow / reaper / vampire | ❌ | `assets/audio/sfx/cast_shadow.ogg` | Pixabay: "dark whoosh evil" |
| `sfx_cast_holy` | Holy / guard cards | ❌ | `assets/audio/sfx/cast_holy.ogg` | Pixabay: "holy shimmer" |
| `sfx_cast_arcane` | Generic magic / element cards | ❌ | `assets/audio/sfx/cast_arcane.ogg` | Pixabay: "magic chime cast" |

### 2.4 SFX — progression / pickup

| Cue ID | Trigger | Status | File | Source plan |
|---|---|---|---|---|
| `sfx_level_up` | Hero gains level — **referenced at `rogue_hero.gd:130` but broken call path** | ✅ | `assets/audio/level_up.wav` | Keep file; **fix call site** to use `EngineAPI.play_sfx` |
| `sfx_xp_orb` | XP orb pickup | ❌ | `assets/audio/sfx/xp_orb.ogg` | Pixabay: "rpg pickup ping short" |
| `sfx_gold_pickup` | Gold pickup | 🟡 | `assets/audio/sfx/gold_pickup.ogg` | Wire on gold grab |
| `sfx_relic_pickup` | Relic acquired | ❌ | `assets/audio/sfx/relic_pickup.ogg` | Pixabay: "powerup gain magic" |
| `sfx_equip_item` | Equip gear | ❌ | `assets/audio/sfx/equip_item.ogg` | Pixabay: "armor equip" |
| `sfx_unequip_item` | Unequip gear | ❌ | `assets/audio/sfx/unequip_item.ogg` | Pixabay: "armor unequip cloth" |
| `sfx_equipment_drop` | Rare/epic drop sparkle | ❌ | `assets/audio/sfx/equipment_drop.ogg` | Pixabay: "magical sparkle drop" |
| `sfx_set_bonus` | Set bonus activates (2/4 pieces) | ❌ | `assets/audio/sfx/set_bonus.ogg` | Pixabay: "achievement fanfare short" |

### 2.5 SFX — cards / draft

All card UI is silent today. The card system is one of the loudest on-screen
interactions; giving it audio is a huge polish win.

| Cue ID | Trigger | Status | File | Source plan |
|---|---|---|---|---|
| `sfx_card_draft_open` | Card-draft panel opens | ❌ | `assets/audio/sfx/card_draft_open.ogg` | Pixabay: "deck shuffle + whoosh" |
| `sfx_card_hover` | Hover over card (throttled 150 ms) | ❌ | `assets/audio/sfx/card_hover.ogg` | Pixabay: "paper flick soft" |
| `sfx_card_pick` | Card chosen | ❌ | `assets/audio/sfx/card_pick.ogg` | Pixabay: "card flip confirm" |
| `sfx_card_refresh` | Refresh cards button | ❌ | `assets/audio/sfx/card_refresh.ogg` | Pixabay: "shuffle reshuffle" |
| `sfx_card_rare` | Draft panel contains a rare-rarity card (stinger) | ❌ | `assets/audio/sfx/card_rare.ogg` | Pixabay: "magic reveal glow" |

### 2.6 SFX — wave / encounter stingers

| Cue ID | Trigger | Status | File | Source plan |
|---|---|---|---|---|
| `sfx_wave_start` | Wave begins | ❌ | `assets/audio/sfx/wave_start.ogg` | Pixabay: "war horn short" |
| `sfx_wave_clear` | Wave cleared | ❌ | `assets/audio/sfx/wave_clear.ogg` | Pixabay: "victory chime short" |
| `sfx_elite_spawn` | Elite enemy enters screen | ❌ | `assets/audio/sfx/elite_spawn.ogg` | Pixabay: "monster growl low" |
| `sfx_boss_spawn` | Boss wave begins | ❌ | `assets/audio/sfx/boss_spawn.ogg` | Pixabay: "boss roar cinematic" |
| `sfx_countdown_tick` | Final 3-2-1 before boss / timer tension | ❌ | `assets/audio/sfx/countdown_tick.ogg` | Pixabay: "clock tick digital" |

### 2.7 SFX — UI

| Cue ID | Trigger | Status | File | Source plan |
|---|---|---|---|---|
| `sfx_ui_click` | Button press | 🟡 | `assets/audio/sfx/ui_click.ogg` | Wire everywhere |
| `sfx_ui_hover` | Button hover | 🟡 | `assets/audio/sfx/ui_hover.ogg` | Pixabay: "button hover soft" |
| `sfx_ui_back` | Back / close | ❌ | `assets/audio/sfx/ui_back.ogg` | Pixabay: "menu back" |
| `sfx_ui_error` | Invalid action | ❌ | `assets/audio/sfx/ui_error.ogg` | Pixabay: "error buzzer short" |
| `sfx_pause` | Pause toggle | ❌ | `assets/audio/sfx/ui_pause.ogg` | Pixabay: "pause chime" |

### 2.8 VO (optional, ElevenLabs free tier)

Not required for ship, but if we have the budget (the free tier is 10k
chars/month, which is enough for all of the below several times over):

| Cue ID | Line | Source plan |
|---|---|---|
| `vo_wave_start` | "Wave incoming." | ElevenLabs "Adam" male narrator |
| `vo_boss_warning` | "A boss approaches." | ElevenLabs "Adam" |
| `vo_victory` | "The run is complete." | ElevenLabs "Rachel" |
| `vo_defeat` | "You have fallen." | ElevenLabs "Adam" |
| `vo_level_up` | "Level up." | ElevenLabs, pitched down 10 % |

Each line is short; the whole set fits comfortably inside one month's free
quota. Generate each line 3–5 times with different voice/emotion presets and
keep the best take.

### 2.9 Totals

| Class | On disk & wired | On disk, unwired | Missing |
|---|---:|---:|---:|
| BGM | 1 | 0 | 5 |
| SFX | 0 | ~9 | ~32 |
| VO | 0 | 0 | 5 (optional) |

---

## 3. Wiring plan (for a separate follow-up task — **not** this task)

For reference only — the gap report enumerates what to produce; wiring is a
separate piece of work.

| Event | Cue(s) | Call site |
|---|---|---|
| `spell_cast` (EventBus) | `sfx_cast_<school>` by spell tag, fallback `sfx_cast_generic` | `rogue_game_mode.gd` event handler |
| `projectile_spawned` | `sfx_shoot` (positional via `play_sfx_at`) | `rogue_game_mode.gd` |
| `projectile_hit` | `sfx_hit_<school>` by damage type | already-existing HealthComponent hit handler |
| `entity_died` (faction=enemy, not boss) | `sfx_death` | `rogue_game_mode.gd` |
| `entity_died` (boss tag) | `sfx_boss_death` + replace broken line at `rogue_rewards.gd:475` | `rogue_rewards.gd` |
| `hero_level_up` | `sfx_level_up` — fix `rogue_hero.gd:130` | `rogue_hero.gd` |
| `xp_orb_picked` / `gold_picked` | `sfx_xp_orb` / `sfx_gold_pickup` | `rogue_game_mode.gd` pickup handlers |
| `relic_granted` | `sfx_relic_pickup` | `rogue_relics.gd` |
| `equipment_equipped` / `_unequipped` | `sfx_equip_item` / `sfx_unequip_item` | `rogue_equipment.gd` |
| `card_draft_opened` | `sfx_card_draft_open` (+ `sfx_card_rare` if any rare card in draft) | `rogue_card_ui.gd` |
| `card_hovered` | `sfx_card_hover` (throttled) | `rogue_card_ui.gd` |
| `card_picked` | `sfx_card_pick` | `rogue_card_ui.gd` |
| `card_refreshed` | `sfx_card_refresh` | `rogue_card_ui.gd` |
| `wave_started` | `sfx_wave_start` | `rogue_wave_system.gd` |
| `wave_cleared` | `sfx_wave_clear` | `rogue_wave_system.gd` |
| `elite_spawned` | `sfx_elite_spawn` | `rogue_elite.gd` |
| `boss_spawned` | `sfx_boss_spawn` + crossfade to `bgm_boss` | `rogue_wave_system.gd` |
| `wave_cleared` (boss wave) | crossfade back to `bgm_combat` | `rogue_wave_system.gd` |
| Pause toggle | `sfx_pause` | `rogue_hud.gd` |

---

## 4. MusicGen prompts

These are the three primary BGM prompts. All of them target
`facebook/musicgen-small` (300 M params) running on MPS via the helper CLI
installed by `tools/setup/install_audio_pipeline_mac.sh`. Each prompt has
been designed for a **90–120 s** duration that loops cleanly
(no drum fills at the end, instrumentation tapers in the final bar).

Render recipe, common to all three:
- Sample rate: 32 kHz (MusicGen default), upsample to 44.1 kHz on export.
- `duration=90` (menu, combat, combat_alt) or `duration=120` (boss).
- `temperature=1.0`, `top_k=250`, `cfg_coef=3.0`.
- Render 4 seeds per prompt and pick by ear.
- Post-process in Audacity or `ffmpeg`:
  - Normalize to -14 LUFS (consistent with Kenney SFX levels).
  - Fade out last 500 ms.
  - Export as OGG Vorbis, quality 6 (~128 kbps) for game-ready size.

### 4.1 Menu theme (`bgm_menu.ogg`)

```
prompt: "Dark mysterious fantasy dungeon ambient. Slow, sparse, minor key.
Ethereal female choir in the far background. Distant low tom drum every 4
beats. Soft pad strings in D minor. No percussion in the foreground. Light
wind chime accent every 8 bars. 65 BPM. Cinematic, patient, curious rather
than threatening. Loopable."
duration: 90
seed: 42
```

**Why these choices**: menu music should be *ambient* — the player may sit
on the main screen for 30+ seconds reading difficulty options. Minor key +
choir reads "dark fantasy" and sets expectations for combat. Sparse
percussion means it can sit under UI SFX without muddying them.

### 4.2 Combat BGM (`bgm_combat_alt.ogg`)

(`battle_01.mp3` already covers primary combat; this is the alt-track to
avoid 20-minute-run fatigue.)

```
prompt: "Epic orchestral combat with driving percussion. 130 BPM. Heavy
taiko drums on the downbeat, rapid 16th-note snare pattern. Low brass
ostinato in E minor playing a 4-note repeating motif. Soaring french horn
melody over the top. Distorted electric cello layer for grit. No vocals.
Builds continuously — tension maintained, never resolves. Suitable for
wave-based combat in a roguelite. Loopable."
duration: 90
seed: 1337
```

**Why these choices**: 130 BPM puts player actions on-beat for most
attack-speed ranges (2/s to 4/s). E minor complements menu D minor (a
whole-step jump feels like a "gear shift" when the fight starts). Taiko +
horn is the genre-standard "Diablo / Path of Exile / Hades" combat sound —
players recognize it instantly.

### 4.3 Boss battle BGM (`bgm_boss.ogg`)

```
prompt: "Apocalyptic boss battle music. 90 BPM (half-time feel). Deep
church pipe organ in C minor playing a slow menacing chord progression.
Massive layered timpani hits on beats 1 and 3. Low male choir chanting a
single sustained note in Latin. Distorted bass drone throughout. Brief
screeching violin stab every 8 bars. Cinematic and oppressive, conveys
dread and scale. No resolution, no release. Loopable."
duration: 120
seed: 666
```

**Why these choices**: slowing from 130 → 90 BPM when the boss appears is
the classic "everything just got serious" cue. Pipe organ + Latin choir =
unambiguous "big bad" signaling without being self-parody. 120 s is long
enough that a ~90 s boss fight won't loop visibly. Seed = 666 purely for
superstition / reproducibility.

### 4.4 Short cues — victory & defeat

These are one-shots, not loops. Under 30 s each.

```
bgm_victory:
prompt: "Triumphant major-key orchestral fanfare. 20 seconds. Brass
section in D major hitting a rising 3-note motif, resolving to a full
orchestra swell. Bright, celebratory, rewarding. Ends cleanly on the tonic."
duration: 20
seed: 7

bgm_defeat:
prompt: "Somber game-over cue. 15 seconds. Solo cello in D minor playing
a slow descending line. Sparse piano accompaniment. Ends on an unresolved
suspended chord — player feels the loss but is not punished. Short, not
melodramatic."
duration: 15
seed: 13
```

---

## 5. Pixabay SFX fetch plan

Pixabay's sound-effects library is CC0 / Pixabay License (no attribution
required). The installer ships an `openforge-sfx-fetch` helper that can
take a query string, list candidate results via the public API (or a
manually-curated URL list), and download the top N into
`assets/audio/sfx/_incoming/` for human review before promoting.

**Batching rule**: fetch in groups by purpose — "combat hits", "UI clicks",
"stingers" — and audition all of a group in one sitting. Picking the best
take across 5 candidates takes ~2 minutes per cue vs. 20 minutes if you
handle them one at a time.

Recommended query seeds (to be refined during actual sourcing):

| Cue family | Query |
|---|---|
| `sfx_cast_*` | `"magic cast whoosh short"`, `"spell charge"` |
| `sfx_hit_holy` | `"divine chime hit"`, `"bell impact"` |
| `sfx_card_*` | `"card flip"`, `"deck shuffle short"` |
| `sfx_ui_*` | `"ui click soft"`, `"menu button"` |
| `sfx_wave_*` | `"war horn short"`, `"victory chime"` |
| `sfx_boss_spawn` | `"monster roar cinematic"`, `"boss reveal"` |
| `sfx_elite_spawn` | `"demon growl"`, `"zombie groan"` |
| `sfx_xp_orb` | `"rpg pickup ping"`, `"collect chime"` |
| `sfx_relic_pickup` | `"powerup magic gain"` |
| `sfx_equip_item` | `"armor equip"`, `"metal sheath"` |
| `sfx_set_bonus` | `"achievement unlock"`, `"fanfare short"` |

---

## 6. ElevenLabs VO plan (optional)

Gated on budget and on UX call whether spoken lines help rogue_survivor's
pacing (they often *hurt* 20-minute runs because repetition is grating).

If we do it:
- Use a single consistent voice per role: one narrator, one hero.
- Generate each line **3–5 times** and keep the best; save the prompt,
  voice ID, and settings in a sidecar JSON for reproducibility.
- Bake-in a 200 ms fade in/out and compress at -14 LUFS to match BGM.
- Ship only in `en_US.ogg` initially. Do **not** machine-translate VO for
  zh/ja/ko — either omit VO in those locales or record those lines later.

---

## 7. Open questions (for later, not blocking this task)

1. Should we ship per-class BGM (warrior / mage / rogue) or keep combat BGM
   shared? Shared is cheaper; per-class reinforces class identity.
2. Should `bgm_combat` and `bgm_combat_alt` crossfade based on enemy
   density, or just alternate per wave? Crossfade is nicer but requires
   wiring in `AudioManager.play_bgm` that doesn't exist today.
3. Is there budget for a professional audio pass (mastering) before ship?
   MusicGen output at -14 LUFS is fine for playtest, but a shipped game
   typically masters at a consistent -16 to -18 LUFS for BGM.

---

## 8. Next steps (not this task)

1. Run `tools/setup/install_audio_pipeline_mac.sh` to install the local
   MusicGen pipeline.
2. Render the 5 BGMs from §4 using the installed CLI.
3. Run the `openforge-sfx-fetch` helper across the Pixabay query list in §5.
4. Human-review + promote best takes into `assets/audio/{bgm,sfx}/`.
5. **Separate wiring task**: implement the call-site changes in §3 and
   add `assets/audio/ATTRIBUTIONS.md`.
