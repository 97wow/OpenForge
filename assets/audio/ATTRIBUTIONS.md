# Audio Attributions — assets/audio/

Source-of-truth attribution table for every audio file currently shipped under
`assets/audio/`. Originally generated as part of Task #16 (audio-pipeline gap
re-audit, 2026-04-25).

`.source.json` sidecars live next to each replaced asset and capture the
canonical record `{source, source_url, source_file, source_sha256, license,
transform, output_sha256, output_duration_sec, picked_at}`. This table reflects
the sidecar contents — if they ever drift, the sidecar is authoritative.

## BGM

| Filename | Relative path | Plausible source | License | Description |
|---|---|---|---|---|
| `battle_01.mp3` | `assets/audio/bgm/battle_01.mp3` | unknown — deferred to MusicGen render task (see `docs/AUDIO_REPLACEMENT_PLAN.md` §12 Option A) | unknown | Looping orchestral combat track (~3.0 MB) used as the only live BGM today |

## SFX — framework layer (top-level `assets/audio/`)

Replaced 2026-04-25 with Kenney CC0 picks per `docs/AUDIO_REPLACEMENT_PLAN.md`.
All sources are CC0 1.0 Universal (no attribution required), audited against
the per-file selection criteria in the plan. Each WAV is mono / 44.1 kHz /
16-bit PCM (re-encoded via `afconvert -d LEI16 -c 1 -f WAVE`). Provenance for
every row is recorded in the matching `<file>.source.json` sidecar.

| Filename | Relative path | Source | License | Description |
|---|---|---|---|---|
| `death.wav` | `assets/audio/death.wav` | Kenney "Impact Sounds" pack (file `impactSoft_heavy_000.ogg`, https://kenney.nl/assets/impact-sounds) | CC0 1.0 | Generic enemy-death thud auto-played on `entity_killed` |
| `hit_fire.wav` | `assets/audio/hit_fire.wav` | Kenney "Sci-Fi Sounds" pack (file `laserRetro_000.ogg`, https://kenney.nl/assets/sci-fi-sounds) | CC0 1.0 | Fire-school damage tick, energy/zap transient |
| `hit_frost.wav` | `assets/audio/hit_frost.wav` | Kenney "Impact Sounds" pack (file `impactGlass_light_001.ogg`, https://kenney.nl/assets/impact-sounds) | CC0 1.0 | Frost-school damage tick, glassy crackle |
| `hit_nature.wav` | `assets/audio/hit_nature.wav` | Kenney "Sci-Fi Sounds" pack (file `slime_000.ogg`, https://kenney.nl/assets/sci-fi-sounds) | CC0 1.0 | Nature/poison damage tick, organic squelch |
| `hit_physical.wav` | `assets/audio/hit_physical.wav` | Kenney "Impact Sounds" pack (file `impactPunch_medium_000.ogg`, https://kenney.nl/assets/impact-sounds) | CC0 1.0 | Physical damage tick, dull body thump |
| `hit_shadow.wav` | `assets/audio/hit_shadow.wav` | Kenney "Impact Sounds" pack (file `impactBell_heavy_004.ogg`, https://kenney.nl/assets/impact-sounds) | CC0 1.0 | Shadow-school damage tick, dark resonant tone |
| `level_up.wav` | `assets/audio/level_up.wav` | Kenney "Interface Sounds" pack (file `confirmation_002.ogg`, https://kenney.nl/assets/interface-sounds) | CC0 1.0 | Hero level-up confirmation stinger (placeholder — upgrade to true fanfare in Wave B) |
| `shoot.wav` | `assets/audio/shoot.wav` | Kenney "Sci-Fi Sounds" pack (file `laserSmall_001.ogg`, https://kenney.nl/assets/sci-fi-sounds) | CC0 1.0 | Generic projectile-launch zap auto-played on `spell_cast` |

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

1. ~~Locate the original download/commit for the eight top-level `.wav` files
   and `bgm/battle_01.mp3` and record source + license.~~ **Done 2026-04-25 for
   the 8 SFX (Kenney CC0 swap).** `bgm/battle_01.mp3` is still pending —
   defer to the MusicGen-render task per `docs/AUDIO_REPLACEMENT_PLAN.md` §12
   Option A (or §12 Option B FMA fallback) before commercial launch.
2. When the Kenney sourcing in `assets/audio/sfx/` is confirmed, replace the
   `(per gaps doc; unverified)` qualifier with the specific Kenney pack name
   and version each file came from.
3. Adopt the `<file>.source.json` sidecar convention from
   `docs/AUDIO_GAP_REPORT.md` §1 for all future audio additions so this
   table can be regenerated automatically. **Already adopted for the 8 SFX
   replaced 2026-04-25** — extend to `assets/audio/sfx/` next.
4. `level_up.wav` is currently a short confirmation stinger (~0.54 s) rather
   than a true 1–2 s ascending fanfare — flagged as placeholder. Upgrade in
   Wave B with a proper level-up motif (Pixabay search or MusicGen render).
5. In-game audition: boot `rogue_survivor`, force-trigger each cue
   (`DebugOverlay` or matching event) and confirm the new SFX reads the same
   role as the original. Roll back any cue that doesn't pass.
