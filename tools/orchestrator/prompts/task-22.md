Task #22: Produce docs/AUDIO_REPLACEMENT_PLAN.md — concrete per-file replacement plan for the 8 unknown-provenance audio files flagged in `assets/audio/ATTRIBUTIONS.md`.

Background: `assets/audio/ATTRIBUTIONS.md` lists 8 top-level `.wav` files plus `bgm/battle_01.mp3` as `unknown — needs follow-up` because no source/license could be recovered from disk metadata. These are a commercial-launch blocker: shipping audio of unknown provenance on Steam is risky.

The 8 files (verify against ATTRIBUTIONS.md before writing):
1. `assets/audio/death.wav`
2. `assets/audio/hit_fire.wav`
3. `assets/audio/hit_frost.wav`
4. `assets/audio/hit_nature.wav`
5. `assets/audio/hit_physical.wav`
6. `assets/audio/hit_shadow.wav`
7. `assets/audio/level_up.wav`
8. `assets/audio/shoot.wav`
Plus `assets/audio/bgm/battle_01.mp3`.

Procedure:
1. Read `assets/audio/ATTRIBUTIONS.md` and `docs/AUDIO_GAP_REPORT.md` §2 to confirm the list and understand each file's purpose.
2. For each of the 9 files, propose a concrete CC0 replacement:
   - **Source platform** — `Pixabay` (https://pixabay.com/sound-effects/) and/or `Kenney.nl` (https://kenney.nl/assets?q=audio). Both are CC0.
   - **Search query** — exact query string the user/agent would type
   - **Top 3 candidate URLs** — using WebSearch / WebFetch to actually find pages on Pixabay or Kenney that match the cue. List concrete URLs, not "search Pixabay for X". If you cannot find concrete URLs, note `URL not verified — query suggested` rather than fabricating.
   - **Selection criterion** — one line: what makes a candidate the right pick (e.g. "≤200ms attack, dry mix, no reverb tail" for a hit SFX)
   - **Filename to save as** — keep the existing filename so call-sites don't need updating
   - **License-record line** — what the new entry in `ATTRIBUTIONS.md` should say after the swap
3. Add a §10 "Manual download workflow" — a 4-line bash recipe the user can run to fetch the chosen file (curl + sha256 + move into place). Generic; the user fills the URL.
4. Add a §11 "Sanity audit" — after the swap, what should be re-verified (file durations match originals within ~30%, sample rates compatible with Godot AudioStream, etc.)
5. Add a §12 "battle_01.mp3 special handling" — this is BGM not SFX. Recommend either MusicGen render (per `AUDIO_GAP_REPORT.md` §4 prompts already designed) OR a Free Music Archive CC-BY pick. Choose one with rationale.

Constraints:
- Do NOT actually download or replace any audio file. This is a planning document.
- Do NOT modify `ATTRIBUTIONS.md` or `AUDIO_GAP_REPORT.md`.
- Use WebSearch / WebFetch to find concrete URLs where possible. If a search returns nothing usable, that itself is information — record the query attempted and `no clean match found` rather than guessing.
- Stay strict about CC0 — Pixabay's "Pixabay License" qualifies; CC-BY is also acceptable but record it explicitly so the user can decide whether they want to attribute.

Rules:
- No git, no code/data changes.
- Single window, no `[ROTATE]`.
- Emit `[DONE]` when saved.

Deliverable: `docs/AUDIO_REPLACEMENT_PLAN.md`
