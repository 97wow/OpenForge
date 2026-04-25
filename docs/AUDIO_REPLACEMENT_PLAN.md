# Audio Replacement Plan — 9 unknown-provenance files

Scope: concrete per-file CC0 replacement plan for the 9 audio files flagged
`unknown — needs follow-up` in `assets/audio/ATTRIBUTIONS.md` (generated
2026-04-25 during Task #16 audio-pipeline re-audit). Shipping these on Steam
with no recorded source is a commercial-launch blocker, so every one must be
swapped for a provenance-clean asset or have its source recovered before
release.

This document is a **plan only** — it proposes replacements and records the
workflow. It does not download, replace, or modify any audio on disk, and it
does not modify `ATTRIBUTIONS.md` or `AUDIO_GAP_REPORT.md`. Promotion into
the tree is a separate task.

Pixabay deep-link caveat: Pixabay's per-file detail pages and CDN URLs are
behind a bot-guard that returns HTTP 403 to unauthenticated fetches, so the
"Top 3 candidate URLs" below are the verified Pixabay **search-result
pages** scoped to the right keywords unless a specific detail-page URL came
back from a web search. A human must audition on the search page and pick
the best take. This is faithful to the constraint: "If you cannot find
concrete URLs, note `URL not verified — query suggested` rather than
fabricating."

References:
- `assets/audio/ATTRIBUTIONS.md` §SFX-framework and §BGM (the 9 files).
- `docs/AUDIO_GAP_REPORT.md` §2.1 (BGM) and §2.2 (combat SFX) for cue
  descriptions and MusicGen prompts.
- Pixabay License: https://pixabay.com/service/license-summary/ — "free for
  commercial use, no attribution required" (functionally CC0-equivalent).
- Kenney License: https://kenney.nl/faq — all assets CC0 1.0 Universal.

---

## File inventory (from `ATTRIBUTIONS.md`)

| # | Path | Size | Role (from gap report) |
|---|---|---|---|
| 1 | `assets/audio/death.wav` | ~unknown | Generic enemy-death thud auto-played on `entity_killed` |
| 2 | `assets/audio/hit_fire.wav` | ~6.5 KB | Fire-school damage tick, sizzle/impact |
| 3 | `assets/audio/hit_frost.wav` | ~5.2 KB | Frost-school damage tick, icy crackle |
| 4 | `assets/audio/hit_nature.wav` | ~4.4 KB | Nature/poison damage tick, organic squelch |
| 5 | `assets/audio/hit_physical.wav` | ~3.5 KB | Physical damage tick, dull thump |
| 6 | `assets/audio/hit_shadow.wav` | ~7.8 KB | Shadow-school damage tick, dark whoosh |
| 7 | `assets/audio/level_up.wav` | ~17 KB | Hero level-up celebratory sting |
| 8 | `assets/audio/shoot.wav` | ~unknown | Generic projectile-launch zap on `spell_cast` |
| 9 | `assets/audio/bgm/battle_01.mp3` | ~3.0 MB | Looping orchestral combat track (live BGM) |

Strategy: files 1–8 are all short combat/UI one-shots and fit Kenney's
Impact-Sounds / Interface-Sounds CC0 packs or Pixabay one-shots. File 9 is
BGM — treated separately in §12.

---

## 1. `death.wav` — enemy death thud

- **Source platform**: Pixabay (primary). Kenney Impact Sounds as CC0
  fallback if a clean take is in-pack.
- **Search query**: `game death thud short` (Pixabay)
- **Top 3 candidate URLs**:
  - https://pixabay.com/sound-effects/search/game%20death/ — search page;
    top hits include short game-over / enemy-death one-shots.
  - https://pixabay.com/sound-effects/search/death/ — broader search page.
  - https://pixabay.com/sound-effects/horror-monster-cry-94609/ — single
    verified detail page; a short horror creature vocal usable for the
    bigger-enemy death variant. *(Verified via search result.)*
  - Kenney fallback: https://kenney.nl/assets/impact-sounds (130 CC0 one-shots).
- **Selection criterion**: ≤500 ms, dry (no room reverb), no musical tail,
  reads as "impact + groan" not "explosion." Mono preferred so positional
  play via `play_sfx_at` works correctly.
- **Filename to save as**: `death.wav` (keep, so `rogue_game_mode.gd` and
  any other call-sites don't need edits).
- **License-record line** (after swap, goes in `ATTRIBUTIONS.md` SFX table):
  `| death.wav | assets/audio/death.wav | Pixabay (title "<TITLE>", uploader "<USER>", url <DETAIL_URL>) | Pixabay License (no attribution required) | Generic enemy-death thud auto-played on entity_killed |`

---

## 2. `hit_fire.wav` — fire damage sizzle/impact

- **Source platform**: Pixabay (primary).
- **Search query**: `fire impact short` or `sizzle hit`.
- **Top 3 candidate URLs**:
  - https://pixabay.com/sound-effects/search/fire/ — top page, pick a
    short "fire burst" or "fire whoosh" under 400 ms.
  - https://pixabay.com/sound-effects/search/sizzle/ — sizzle-specific,
    good for DOT ticks.
  - https://pixabay.com/sound-effects/search/impact%20hit/ — generic impact
    bed that can be layered if a pure fire take is too soft.
- **Selection criterion**: ≤300 ms, strong transient (crackle at the front),
  short ember tail, no vocal elements. Must not clash with looping `hit`
  events at 2-3 Hz — any tail >500 ms will overlap.
- **Filename to save as**: `hit_fire.wav` (keep).
- **License-record line**:
  `| hit_fire.wav | assets/audio/hit_fire.wav | Pixabay (title "<TITLE>", uploader "<USER>", url <DETAIL_URL>) | Pixabay License (no attribution required) | Fire-school damage tick, sizzle/impact |`

---

## 3. `hit_frost.wav` — icy crackle

- **Source platform**: Pixabay (primary). Kenney Impact Sounds also holds
  useable glass/crystal variants.
- **Search query**: `ice crack short` or `crystal shatter short`.
- **Top 3 candidate URLs**:
  - https://pixabay.com/sound-effects/search/ice-crack/ — search page.
  - https://pixabay.com/sound-effects/search/ice%20crystals/ — search page,
    gives short chime-tinted takes good for frost DOT.
  - https://pixabay.com/sound-effects/search/glass%20shatter/ — fallback
    for harder, percussive variant if a pure ice take is too wet.
- **Selection criterion**: ≤300 ms, high-frequency transient (glassy), no
  long ring-out. Pitched-down variants read as "freezing" vs pitched-up
  reads as "glass breaking" — we want the former.
- **Filename to save as**: `hit_frost.wav` (keep).
- **License-record line**:
  `| hit_frost.wav | assets/audio/hit_frost.wav | Pixabay (title "<TITLE>", uploader "<USER>", url <DETAIL_URL>) | Pixabay License (no attribution required) | Frost-school damage tick, icy crackle |`

---

## 4. `hit_nature.wav` — organic squelch

- **Source platform**: Pixabay (primary).
- **Search query**: `squelch short` or `slime impact`.
- **Top 3 candidate URLs**:
  - https://pixabay.com/sound-effects/search/squelch/ — primary.
  - https://pixabay.com/sound-effects/search/squish/ — more "wet" variant.
  - https://pixabay.com/sound-effects/search/poison/ — thematic but often
    longer; good only if a ≤300 ms take exists.
- **Selection criterion**: ≤300 ms, wet transient, organic (avoid mechanical
  or metal-tinted takes). Should cue "poison / bog" to the ear, not just
  "splash."
- **Filename to save as**: `hit_nature.wav` (keep).
- **License-record line**:
  `| hit_nature.wav | assets/audio/hit_nature.wav | Pixabay (title "<TITLE>", uploader "<USER>", url <DETAIL_URL>) | Pixabay License (no attribution required) | Nature/poison damage tick, organic squelch |`

---

## 5. `hit_physical.wav` — dull thump

- **Source platform**: Kenney Impact Sounds (primary — pack is
  purpose-built for this). Pixabay secondary.
- **Search query**: `punch thump body short` (Pixabay) — for Kenney, browse
  the Impact Sounds pack `.zip` locally (no per-file deep URL).
- **Top 3 candidate URLs**:
  - https://kenney.nl/assets/impact-sounds — full CC0 pack (direct ZIP:
    `https://kenney.nl/media/pages/assets/impact-sounds/8aa7b545c9-1677589768/kenney_impact-sounds.zip`),
    130 takes including `impactSoft_medium_00X.ogg` and
    `impactPlank_medium_00X.ogg` which are the right timbre.
  - https://pixabay.com/sound-effects/search/thump/ — Pixabay fallback.
  - https://pixabay.com/sound-effects/search/body-punch/ — percussive,
    meatier variant for a more "melee" read.
- **Selection criterion**: ≤250 ms, low-mid transient, dry, no ring. Should
  read as "blunt impact on body," not "wooden plank" or "metal clang" — the
  metal variants already live in `assets/audio/sfx/hit_metal*.ogg`.
- **Filename to save as**: `hit_physical.wav` (keep).
- **License-record line (Kenney pick)**:
  `| hit_physical.wav | assets/audio/hit_physical.wav | Kenney "Impact Sounds" pack (file <ORIGINAL_NAME>, https://kenney.nl/assets/impact-sounds) | CC0 1.0 | Physical damage tick, dull thump |`
  (If a Pixabay pick is chosen instead, use the Pixabay license line shape
  from §2.)

---

## 6. `hit_shadow.wav` — dark whoosh

- **Source platform**: Pixabay (primary).
- **Search query**: `dark whoosh short` or `shadow magic impact`.
- **Top 3 candidate URLs**:
  - https://pixabay.com/sound-effects/search/dark%20whooshes/ — directly
    scoped.
  - https://pixabay.com/sound-effects/search/dark%20magic/ — thematic.
  - https://pixabay.com/sound-effects/search/magic%20whoosh/ — broader;
    pitch down in post if takes read too "bright."
- **Selection criterion**: 200–500 ms, low/mid frequency-weighted, airy
  body with a soft impact at the end (whoosh + thud). No vocal stingers
  (keeps it distinct from future Holy school).
- **Filename to save as**: `hit_shadow.wav` (keep).
- **License-record line**:
  `| hit_shadow.wav | assets/audio/hit_shadow.wav | Pixabay (title "<TITLE>", uploader "<USER>", url <DETAIL_URL>) | Pixabay License (no attribution required) | Shadow-school damage tick, dark whoosh |`

---

## 7. `level_up.wav` — celebratory sting

- **Source platform**: Pixabay (primary). Kenney RPG Audio fallback if a
  fanfare is in-pack.
- **Search query**: `level up short` or `rpg fanfare short`.
- **Top 3 candidate URLs**:
  - https://pixabay.com/sound-effects/search/level%20up/ — directly scoped,
    dozens of ~1–2 s fanfares.
  - https://pixabay.com/sound-effects/search/levelup/ — alternate spelling
    gets different uploaders' takes.
  - https://pixabay.com/sound-effects/search/fanfare/ — for a more
    orchestral, less arcade-y variant.
  - Kenney fallback: https://kenney.nl/assets/rpg-audio (50 CC0 RPG
    one-shots including pickup/progress stingers).
- **Selection criterion**: 1–2 s, major-key rising motif resolving on the
  tonic, no looping tail. Must **not** step on the MusicGen `bgm_victory`
  cue designed in `AUDIO_GAP_REPORT.md` §4.4 — level-up plays during combat
  while BGM is ducking, so it needs to cut through without muddying.
- **Filename to save as**: `level_up.wav` (keep).
- **License-record line**:
  `| level_up.wav | assets/audio/level_up.wav | Pixabay (title "<TITLE>", uploader "<USER>", url <DETAIL_URL>) | Pixabay License (no attribution required) | Hero level-up celebratory sting |`

---

## 8. `shoot.wav` — projectile zap

- **Source platform**: Pixabay (primary). Kenney Sci-Fi Sounds also carries
  ready-to-go laser takes.
- **Search query**: `laser zap short` or `projectile fire short`.
- **Top 3 candidate URLs**:
  - https://pixabay.com/sound-effects/search/laser-shoot/ — ~1 s clean
    laser zaps.
  - https://pixabay.com/sound-effects/search/projectile/ — lists the
    "particle projectile cannon" one-shots from prior search results.
  - https://pixabay.com/sound-effects/search/laser/ — broadest, pick the
    shortest take.
  - Kenney fallback: https://kenney.nl/assets/sci-fi-sounds (70 CC0
    sci-fi one-shots — `laser_blast`, `laser_shoot` variants).
- **Selection criterion**: ≤300 ms, sharp attack, short decay, not too
  sci-fi (rogue_survivor is fantasy-leaning; prefer a "mana/arcane zap"
  read over "blaster"). Will fire at 2–10 Hz in heavy builds, so overlap
  tolerance matters — keep the tail short.
- **Filename to save as**: `shoot.wav` (keep).
- **License-record line**:
  `| shoot.wav | assets/audio/shoot.wav | Pixabay (title "<TITLE>", uploader "<USER>", url <DETAIL_URL>) | Pixabay License (no attribution required) | Generic projectile-launch zap auto-played on spell_cast |`

---

## 9. `bgm/battle_01.mp3` — combat BGM *(special; see §12)*

See §12 for full rationale. Summary pick: **re-render locally with
MusicGen** using the `bgm_combat` prompt adapted from
`AUDIO_GAP_REPORT.md` §4.2. Rationale: guaranteed ownership, consistent
with the other 4 BGMs that will be MusicGen-rendered in the same pass, and
avoids the licensing ambiguity that a swap-to-FMA would introduce.

---

## 10. Manual download workflow

After a human picks a candidate URL from Pixabay or downloads a Kenney ZIP,
this is the verify-and-place recipe. It assumes the user is in the repo
root. Replace `<URL>` and `<DEST>` for each file.

```bash
# 1. Fetch into a quarantine dir (never overwrite the live asset directly)
mkdir -p /tmp/audio_incoming && curl -L -o /tmp/audio_incoming/candidate.wav "<URL>"

# 2. Record the sha256 for provenance so the sidecar JSON is reproducible
shasum -a 256 /tmp/audio_incoming/candidate.wav | tee /tmp/audio_incoming/candidate.sha256

# 3. Audition locally before promoting (macOS); bail out if it's not the right take
afplay /tmp/audio_incoming/candidate.wav

# 4. Promote into place (Kenney pack files: unzip first, then move the picked .ogg/.wav)
mv /tmp/audio_incoming/candidate.wav assets/audio/<DEST>.wav
```

After the move, hand-write a `<DEST>.source.json` sidecar next to the file
recording `{source_url, uploader, title, license, sha256, picked_at}` per
`AUDIO_GAP_REPORT.md` §1 convention, and update the line in
`ATTRIBUTIONS.md` using the `License-record line` template from the
per-file section above.

---

## 11. Sanity audit (post-swap verification)

Run these checks after each file is replaced — if any fail, roll back
rather than shipping a mismatch.

1. **Duration drift**: new file's length must be within ~30% of the
   original (e.g. a ≤300 ms hit SFX replacing a ~250 ms original is fine;
   a 1.5 s replacement is not — it will tail across subsequent hits and
   double up). Use `ffprobe -i <file> -show_entries format=duration`.
2. **Sample rate / channel count**: Godot's `AudioStreamWAV` / `...OggVorbis`
   accept 22.05 / 44.1 / 48 kHz mono or stereo. Reject anything else or
   transcode (`ffmpeg -i in.wav -ar 44100 -ac 1 out.wav`). Mono is preferred
   for positional play via `AudioManager.play_sfx_at` — stereo disables
   per-channel panning.
3. **Peak level**: normalize to -3 dBFS peak, or -14 LUFS integrated for
   consistency with the Kenney pack in `assets/audio/sfx/` (`ffmpeg -i
   in.wav -filter:a loudnorm=I=-14:TP=-1.5:LRA=11 out.wav`). A louder
   replacement will blow out the mix when it plays alongside existing SFX.
4. **Format match for call-sites**: all 8 SFX files are currently `.wav`.
   Replacing with `.ogg` requires updating every `preload`/`load` call
   that references the filename. Simplest path: keep `.wav` extension even
   if the source is `.ogg` (Godot re-encodes on import either way — the
   filename on disk is what matters for call-sites). Grep:
   `grep -rn "death.wav\|hit_fire.wav\|hit_frost.wav\|hit_nature.wav\|hit_physical.wav\|hit_shadow.wav\|level_up.wav\|shoot.wav\|battle_01.mp3" src/ gamepacks/`.
5. **In-game listen test**: boot rogue_survivor, force-trigger each cue
   (use `DebugOverlay` or spawn the matching event), confirm the new SFX
   reads the same role as the original. Write a one-line check-off in the
   `ATTRIBUTIONS.md` follow-up PR so reviewers can reproduce.
6. **ATTRIBUTIONS.md diff hygiene**: each row that moves out of
   `unknown — needs follow-up` must gain a non-empty source URL, license,
   and the same description the prior row carried. CI should fail if any
   row still contains "unknown" by ship-date.

---

## 12. `battle_01.mp3` — special handling (BGM, not SFX)

The SFX replacement workflow above does not apply to this file. It is the
sole live BGM, plays continuously during combat (the 90%+ of a run that
isn't menu/boss), and is ~3.0 MB / several minutes long. Two viable paths:

### Option A (recommended): re-render locally with MusicGen

- **Why this wins**: `AUDIO_GAP_REPORT.md` §4.2 already contains a
  battle-tested prompt for `bgm_combat_alt` that is tone-matched to the
  other planned BGMs (menu/boss/victory/defeat). Running the *primary*
  combat BGM through the same pipeline with a slight seed/prompt variant
  (§4.2 minus the "alt-track avoid fatigue" framing) gives us a
  consistent BGM set where every track was rendered by us, recorded in
  sidecar JSON, and owned outright. No third-party attribution
  obligations, no takedown risk.
- **Concrete prompt (adapted from §4.2)**:
  ```
  prompt: "Epic orchestral combat with driving percussion. 130 BPM.
  Heavy taiko drums on the downbeat, rapid 16th-note snare pattern.
  Low brass ostinato in E minor playing a 4-note repeating motif.
  Soaring french horn melody over the top. Distorted electric cello
  layer for grit. No vocals. Builds continuously — tension maintained,
  never resolves. Suitable for wave-based combat in a roguelite.
  Loopable."
  duration: 90
  seed: 2024
  ```
- **Prerequisite**: `tools/setup/install_audio_pipeline_mac.sh` must have
  been run so the MusicGen CLI is available (per `AUDIO_GAP_REPORT.md` §8
  step 1). That's a separate task — this plan doesn't install it.
- **Output path**: overwrite `assets/audio/bgm/battle_01.mp3` **or** ship
  as `assets/audio/bgm/battle_01.ogg` (OGG Vorbis ~128 kbps = smaller and
  better-looped than MP3); if changing extension, update the single
  `.mp3` reference — grep from §11 step 4.
- **License-record line**:
  `| battle_01.mp3 | assets/audio/bgm/battle_01.mp3 | Local MusicGen render (facebook/musicgen-small, prompt + seed in battle_01.source.json) | CC-BY (generated output; see MusicGen model card) | Looping orchestral combat track |`

### Option B (fallback): Free Music Archive CC-BY pick

- **When to use**: only if MusicGen install is blocked (e.g. no MPS,
  macOS Intel, disk-space constrained) or the 4 rendered seeds all fail
  human review. CC-BY requires visible attribution in-game, which adds
  UI work that MusicGen avoids.
- **Search seed**: "dark fantasy orchestral combat loop" on
  https://freemusicarchive.org/search?quicksearch=dark+fantasy+combat
  filtered to `License: CC BY`.
- **Selection criterion**: ≥90 s, loopable (no fade-out at end), ≤5 MB
  encoded, 130 BPM ±20, minor key, no vocals.
- **License-record line**:
  `| battle_01.mp3 | assets/audio/bgm/battle_01.mp3 | Free Music Archive (artist "<ARTIST>", title "<TITLE>", url <FMA_URL>) | CC BY 4.0 (attribution required — add to credits screen) | Looping orchestral combat track |`
- **Follow-up if B is picked**: add the attribution string to the
  in-game credits screen *and* to the Steam store page's third-party
  notices — CC-BY compliance is not optional.

**Decision rule**: default to Option A. Escalate to B only after
recording a blocker (as a comment in the row of `ATTRIBUTIONS.md`) so the
choice is auditable.

---

## 13. Handoff checklist

Before closing this task as done:

- [ ] Human has audited this plan and flagged any cue where the selection
      criterion feels wrong for the game's mix.
- [ ] `tools/setup/install_audio_pipeline_mac.sh` status confirmed (needed
      for §12 Option A).
- [ ] A single follow-up task is opened in the tracker to execute the 9
      swaps end-to-end (download → audition → promote → sidecar → update
      `ATTRIBUTIONS.md` → sanity audit from §11).
- [ ] `ATTRIBUTIONS.md` §"Follow-up actions" item 1 can be closed once
      the follow-up task lands.
