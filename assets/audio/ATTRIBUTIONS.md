# Audio Attributions — assets/audio/

Source-of-truth attribution table for every audio file currently shipped under
`assets/audio/`. Generated as part of Task #16 (audio-pipeline gap re-audit,
2026-04-25).

No `.source.json` sidecars were present at audit time, so attribution column
records the most plausible origin based on internal documentation
(`docs/ROGUE_SURVIVOR_GAPS.md` §2.1 calls `assets/audio/sfx/` "the Kenney
library") together with what could be verified against the file itself. Where
even that is insufficient, the entry is marked `unknown — needs follow-up`
rather than guessed. Future asset additions should drop a sidecar JSON next
to the file recording prompt/source/license at promotion time.

## BGM

| Filename | Relative path | Plausible source | License | Description |
|---|---|---|---|---|
| `battle_01.mp3` | `assets/audio/bgm/battle_01.mp3` | unknown — needs follow-up | unknown | Looping orchestral combat track (~3.0 MB) used as the only live BGM today |

## SFX — framework layer (top-level `assets/audio/`)

These were added before the Kenney pack landed and have no recoverable
provenance. Treat as `unknown` until somebody confirms or replaces them.

| Filename | Relative path | Plausible source | License | Description |
|---|---|---|---|---|
| `death.wav` | `assets/audio/death.wav` | unknown — needs follow-up | unknown | Generic enemy-death thud auto-played on `entity_killed` |
| `hit_fire.wav` | `assets/audio/hit_fire.wav` | unknown — needs follow-up | unknown | Fire-school damage tick, sizzle/impact, ~6.5 KB |
| `hit_frost.wav` | `assets/audio/hit_frost.wav` | unknown — needs follow-up | unknown | Frost-school damage tick, icy crackle, ~5.2 KB |
| `hit_nature.wav` | `assets/audio/hit_nature.wav` | unknown — needs follow-up | unknown | Nature/poison damage tick, organic squelch, ~4.4 KB |
| `hit_physical.wav` | `assets/audio/hit_physical.wav` | unknown — needs follow-up | unknown | Physical damage tick, dull thump, ~3.5 KB |
| `hit_shadow.wav` | `assets/audio/hit_shadow.wav` | unknown — needs follow-up | unknown | Shadow-school damage tick, dark whoosh, ~7.8 KB |
| `level_up.wav` | `assets/audio/level_up.wav` | unknown — needs follow-up | unknown | Hero level-up celebratory sting, ~17 KB |
| `shoot.wav` | `assets/audio/shoot.wav` | unknown — needs follow-up | unknown | Generic projectile-launch zap auto-played on `spell_cast` |

## SFX — `assets/audio/sfx/`

`docs/ROGUE_SURVIVOR_GAPS.md` §2.1 explicitly labels this folder "SFX —
Kenney library." Kenney's audio packs (Interface Sounds, RPG Audio, Impact
Sounds, etc.) are CC0. No per-file source records exist, so the attribution
is documented-but-unverified. Keep this in mind before shipping commercially
without a fresh CC0 audit.

| Filename | Relative path | Plausible source | License | Description |
|---|---|---|---|---|
| `footstep_01.ogg` | `assets/audio/sfx/footstep_01.ogg` | Kenney CC0 (per gaps doc; unverified) | CC0 | Footfall variant 1 for movement loop (currently unwired) |
| `footstep_02.ogg` | `assets/audio/sfx/footstep_02.ogg` | Kenney CC0 (per gaps doc; unverified) | CC0 | Footfall variant 2 for movement loop (currently unwired) |
| `footstep_03.ogg` | `assets/audio/sfx/footstep_03.ogg` | Kenney CC0 (per gaps doc; unverified) | CC0 | Footfall variant 3 for movement loop (currently unwired) |
| `gold_pickup.ogg` | `assets/audio/sfx/gold_pickup.ogg` | Kenney CC0 (per gaps doc; unverified) | CC0 | Coin/gold pickup chime, in audio cache, no live caller yet |
| `hit_generic.ogg` | `assets/audio/sfx/hit_generic.ogg` | Kenney CC0 (per gaps doc; unverified) | CC0 | Generic hit fallback for damage types without dedicated SFX |
| `hit_light.ogg` | `assets/audio/sfx/hit_light.ogg` | Kenney CC0 (per gaps doc; unverified) | CC0 | Light-impact hit, currently unused by framework |
| `hit_metal.ogg` | `assets/audio/sfx/hit_metal.ogg` | Kenney CC0 (per gaps doc; unverified) | CC0 | Metal clang preferred for physical hits when present |
| `hit_metal_alt.ogg` | `assets/audio/sfx/hit_metal_alt.ogg` | Kenney CC0 (per gaps doc; unverified) | CC0 | Alternate metal hit variant for hit-stack variety, unwired |
| `melee_swing.ogg` | `assets/audio/sfx/melee_swing.ogg` | Kenney CC0 (per gaps doc; unverified) | CC0 | Melee swing whoosh, in audio cache, no caller yet |
| `move_command.ogg` | `assets/audio/sfx/move_command.ogg` | Kenney CC0 (per gaps doc; unverified) | CC0 | RTS-style move-command click (framework selection_system) |
| `select_unit.ogg` | `assets/audio/sfx/select_unit.ogg` | Kenney CC0 (per gaps doc; unverified) | CC0 | RTS-style unit-select click (framework selection_system) |
| `spell_cast.ogg` | `assets/audio/sfx/spell_cast.ogg` | Kenney CC0 (per gaps doc; unverified) | CC0 | Generic magic cast whoosh, in cache, never directly invoked |
| `ui_click.ogg` | `assets/audio/sfx/ui_click.ogg` | Kenney CC0 (per gaps doc; unverified) | CC0 | UI button click, in audio cache, no caller wired |
| `ui_click_alt.ogg` | `assets/audio/sfx/ui_click_alt.ogg` | Kenney CC0 (per gaps doc; unverified) | CC0 | Alternate UI click variant for click-stack variety, unwired |
| `ui_hover.ogg` | `assets/audio/sfx/ui_hover.ogg` | Kenney CC0 (per gaps doc; unverified) | CC0 | UI hover blip — present despite gap report saying missing |
| `ui_hover_alt.ogg` | `assets/audio/sfx/ui_hover_alt.ogg` | Kenney CC0 (per gaps doc; unverified) | CC0 | Alternate UI hover variant for stack variety, unwired |
| `ui_toggle.ogg` | `assets/audio/sfx/ui_toggle.ogg` | Kenney CC0 (per gaps doc; unverified) | CC0 | UI toggle/switch click for checkbox-style controls, unwired |

## Follow-up actions

1. Locate the original download/commit for the eight top-level `.wav` files
   and `bgm/battle_01.mp3` and record source + license, or replace them with
   provenance-clean equivalents (Pixabay / Kenney / MusicGen render).
2. When the Kenney sourcing is confirmed, replace the
   `(per gaps doc; unverified)` qualifier with the specific Kenney pack name
   and version each file came from.
3. Adopt the `<file>.source.json` sidecar convention from
   `docs/AUDIO_GAP_REPORT.md` §1 for all future audio additions so this
   table can be regenerated automatically.
