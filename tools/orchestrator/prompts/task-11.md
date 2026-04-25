Task #11: Design the audio pipeline. Read docs/ROGUE_SURVIVOR_GAPS.md §audio to see exactly what SFX/BGM are referenced.

Deliverable: docs/AUDIO_GAP_REPORT.md — a plan that lists every needed SFX/BGM, suggests a free-pipeline source (local MusicGen for BGM, Pixabay CC0 for SFX, ElevenLabs free tier for VO), and contains concrete MusicGen prompts for 3 BGMs (menu / combat / boss).

Secondary: tools/setup/install_audio_pipeline_mac.sh — installer for local MusicGen + audio helper scripts. Must be idempotent, MPS-aware, no execution.

Rules: no game code changes; no git; [ROTATE] between the two deliverables; [DONE] when both exist.
