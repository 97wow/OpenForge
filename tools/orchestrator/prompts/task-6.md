Task #6: Draft an automated installer script for Hunyuan3D 2.0 on Apple Silicon Mac Studio (32GB unified memory, MPS backend), plus a benchmark plan.

Deliverable: tools/setup/install_hunyuan3d_mac.sh — a bash script that, when run, sets up a self-contained Python venv under ~/.openforge-ai-env/, installs Hunyuan3D 2.0 with MPS support, downloads models, and exposes a simple `hunyuan3d-gen` CLI wrapper.

Additional deliverables (in the same run):
- tools/setup/README_HUNYUAN3D.md — detailed setup instructions, known MPS pitfalls, fallback to Replicate API, expected memory footprint.
- tools/setup/bench_hunyuan3d.py — a bench script that generates 3 test prompts (low-poly tower, pixel archer hero icon, stylized goblin sprite) and records wall-clock time + peak MPS memory.

Research constraints:
- Use WebFetch/WebSearch if available to get the latest official README (github.com/tencent/Hunyuan3D-2) and Mac-specific install notes.
- Prefer pure pip installs; avoid conda. torch with MPS support.
- The script must be idempotent (safe to re-run).
- Do NOT execute the installer in this run. Only author it.

Rules: don't modify game code; no git; emit [ROTATE] after each deliverable is written; [DONE] once all three files exist and tools/setup/install_hunyuan3d_mac.sh is executable (chmod 755).
