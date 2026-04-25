Task #16: Re-audit docs/AUDIO_GAP_REPORT.md against the actual asset disk state and produce assets/audio/ATTRIBUTIONS.md.

Background: the existing `docs/AUDIO_GAP_REPORT.md` enumerates every SFX/BGM cue with a status flag (✅ wired / 🟡 on disk unwired / ❌ missing). Spot-check found at least one inaccuracy: `sfx_ui_hover` is marked ❌ but `assets/audio/sfx/ui_hover.ogg` is on disk. There may be more.

Procedure:
1. Build the ground-truth audio inventory: enumerate everything under `assets/audio/`, `assets/audio/sfx/`, `assets/audio/bgm/`, and any other audio paths the project uses.
2. Re-grade every cue in `docs/AUDIO_GAP_REPORT.md` §2:
   - ✅ — file is on disk AND the call site emits it (verify by grepping for the cue ID or filename in `gamepacks/rogue_survivor/scripts/`)
   - 🟡 — file is on disk but no call site found (or the path in the report differs from reality)
   - ❌ — file is genuinely absent
   For at least the cues that change status, verify your reasoning by quoting the exact file path you checked and the grep result.
3. Verify the two cited "broken call sites" by reading the lines:
   - `gamepacks/rogue_survivor/scripts/rogue_hero.gd:130`
   - `gamepacks/rogue_survivor/scripts/rogue_rewards.gd:475`
   Confirm the report's characterization of each. Do NOT modify these files.
4. Produce `assets/audio/ATTRIBUTIONS.md` listing every audio file currently on disk, with columns: filename, relative path, plausible source (Kenney CC0 / Pixabay / unknown), license, ~10-word description. For files whose source is genuinely unknown, mark them `unknown — needs follow-up` rather than guessing.
5. Apply surgical edits to `docs/AUDIO_GAP_REPORT.md` to correct the inaccurate statuses. Do not rewrite the document — only flip the status flag and (if needed) update the file path in the row. Leave the wiring plan §3 untouched.

Rules:
- No game code changes (this is a docs/audit task only).
- No git operations.
- Single window — do NOT emit `[ROTATE]`.
- Emit `[DONE]` only after `assets/audio/ATTRIBUTIONS.md` is saved and `AUDIO_GAP_REPORT.md` corrections are applied.
- Be honest: if you cannot determine a source, mark it unknown.

Deliverable: `assets/audio/ATTRIBUTIONS.md`
