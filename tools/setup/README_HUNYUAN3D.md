# Hunyuan3D 2.0 on Apple Silicon — Setup Guide

This directory contains the OpenForge tooling for running Tencent's
[Hunyuan3D 2.0](https://github.com/tencent/Hunyuan3D-2) locally on an
Apple Silicon Mac (Mac Studio M-series, 32 GB unified memory recommended).

## What you get

| File                         | Purpose                                                  |
| ---------------------------- | -------------------------------------------------------- |
| `install_hunyuan3d_mac.sh`   | Idempotent installer. Creates a self-contained Python venv under `~/.openforge-ai-env/`, installs Hunyuan3D 2.0 with MPS (Metal) support, downloads models, exposes a `hunyuan3d-gen` CLI. |
| `README_HUNYUAN3D.md`        | This file.                                                |
| `bench_hunyuan3d.py`         | Three-prompt benchmark: records wall-clock time and peak MPS memory. |

## TL;DR

```bash
# one-time install (takes ~20 min on a fast connection, most of it is model download)
bash tools/setup/install_hunyuan3d_mac.sh

# run benchmark
~/.openforge-ai-env/bin/hunyuan3d-gen --prompt "low-poly stone tower" --out /tmp/tower.glb
python tools/setup/bench_hunyuan3d.py --out /tmp/hunyuan_bench.json
```

To put the CLI on your global `$PATH`:

```bash
ln -s ~/.openforge-ai-env/bin/hunyuan3d-gen /usr/local/bin/hunyuan3d-gen
```

## Requirements

- macOS 13 (Ventura) or newer; macOS 14+ strongly preferred for MPS stability.
- Apple Silicon (M1/M2/M3/M4). Intel Macs are explicitly not supported.
- Xcode command line tools: `xcode-select --install`.
- Homebrew Python 3.10 or 3.11 preferred (`brew install python@3.11`).
  Python 3.12 works for shape generation; some texture-gen deps may not have
  wheels.
- ~25 GB free disk (models are large; ~8 GB each).

## What the installer does

1. Creates `~/.openforge-ai-env/hunyuan3d` venv.
2. Installs `torch==2.4.0` + `torchvision==0.19.0` (MPS-capable wheels from PyPI).
3. Clones `github.com/tencent/Hunyuan3D-2` into `~/.openforge-ai-env/src/Hunyuan3D-2`.
4. Strips CUDA-only deps (`xformers`, `flash-attn`, `bitsandbytes`, `triton`)
   from `requirements.txt`, then installs the filtered set.
5. Attempts the `custom_rasterizer` and `differentiable_renderer` C++ builds
   (for texture gen). These routinely fail on Mac — the installer logs a
   warning and continues. Shape gen works without them.
6. Downloads models via `huggingface_hub` into `~/.openforge-ai-env/models/`:
   - `tencent/Hunyuan3D-2mini` (0.6 B params — default shape model)
   - `tencent/Hunyuan3D-2` (1.3 B params texture model — only used if texgen
     compiled)
7. Writes a wrapper at `~/.openforge-ai-env/bin/hunyuan3d-gen`.

Idempotent: each step drops a marker in `~/.openforge-ai-env/.state/` and is
skipped on re-runs. Set `FORCE_REINSTALL=1` to rebuild the venv from scratch.

## Expected memory footprint (32 GB unified memory)

| Phase                                   | Peak RSS | Peak MPS alloc | Notes                              |
| --------------------------------------- | -------- | -------------- | ---------------------------------- |
| idle venv                               | ~300 MB  | 0              |                                    |
| shape model loaded (Hunyuan3D-2mini)    | ~6 GB    | ~4 GB          | weights resident                   |
| shape inference (30 steps, 512³ grid)   | ~8 GB    | ~7 GB          | peak during DiT forward passes     |
| shape model 1.1 B (full `Hunyuan3D-2`)  | ~11 GB   | ~9 GB          | use `--shape-model tencent/Hunyuan3D-2` |
| texture pass (if C++ ext built)         | ~18 GB   | ~14 GB         | borderline on 32 GB; close browsers |
| Blender / Godot editor open alongside   | add 4 GB | —              | recommend closing during texture gen |

Rule of thumb: shape-only fits comfortably on a 32 GB machine; full
shape+texture is doable but tight — expect MPS OOM if other heavy apps are
running.

## CLI usage

```bash
hunyuan3d-gen --prompt "pixel archer hero icon"  --out archer.glb
hunyuan3d-gen --image hero.png --out hero.glb    --steps 50
hunyuan3d-gen --prompt "stone golem"  --texture --out golem.glb   # needs texgen
```

Flags:

| flag             | default                  | note                                   |
| ---------------- | ------------------------ | -------------------------------------- |
| `--prompt`       | —                        | text-to-3D                             |
| `--image`        | —                        | image-to-3D (mutually exclusive)       |
| `--out`          | required                 | `.glb` path                            |
| `--steps`        | 30                       | 20–50 reasonable; 30 is a good default |
| `--seed`         | 1234                     | reproducibility                        |
| `--texture`      | off                      | only if the C++ ext built              |
| `--shape-model`  | `tencent/Hunyuan3D-2mini`| override via env `HUNYUAN_SHAPE_MODEL` |
| `--device`       | `mps`                    | auto-falls back to CPU if unavailable  |

## Known MPS pitfalls

These are the failure modes that bit us (and the broader community) during
bring-up. Each has a workaround.

1. **`aten::…` not implemented for MPS.** Some ops used inside the DiT stack
   have no Metal kernel. The installer sets `PYTORCH_ENABLE_MPS_FALLBACK=1`
   in the CLI wrapper so unsupported ops fall back to CPU transparently.
   Expect a 10–30 % slowdown on the offending layers but no crash.

2. **`xformers` / `flash-attn` / `bitsandbytes`.** CUDA-only. The installer
   filters them out of `requirements.txt`. Upstream tutorials that reference
   them will not apply on Mac; use the vanilla attention path instead. It is
   slower but works.

3. **`custom_rasterizer` / `differentiable_renderer` C++ builds.** These
   assume CUDA and will usually fail to compile on Mac. The installer treats
   this as a **warning, not a fatal error**. You lose texture generation
   capability but retain shape generation. Fall back to Replicate for
   textures (see below).

4. **MPS memory fragmentation.** After 10+ generations memory usage climbs
   even though you're calling the same pipeline. Two mitigations:
   - Periodically call `torch.mps.empty_cache()` between generations.
   - For batch jobs, spawn a fresh subprocess per N generations.

5. **Metal shader cache cold-start.** First generation after boot compiles a
   large number of Metal shaders (10–30 s overhead). Subsequent runs are
   fast. The bench script excludes cold-start by doing a throwaway warm-up.

6. **`float64` on MPS.** MPS does not support double precision. Any path
   that upcasts to `float64` (e.g. some trimesh utilities) will silently
   copy to CPU. If you see sudden slowdowns, grep your logs for `float64`.

7. **macOS 12.x.** MPS works on 12.3+, but the shader compiler was unstable.
   Upgrade to 14+ if at all possible.

8. **`torch.compile` on MPS.** Flaky as of `torch 2.4`; do not enable it for
   Hunyuan3D on Mac. CPU fallback + MPS eager is the safe combination.

## Fallback: Replicate API

When you do not have the models downloaded, cannot get texture-gen to build,
or need to run on a machine with less than 16 GB unified memory, offload to
Replicate. A few community-hosted endpoints expose Hunyuan3D 2.0:

```bash
export REPLICATE_API_TOKEN=your_token_here
replicate run tencent/hunyuan3d-2 \
  -i prompt="low-poly stone tower" \
  -i output_format="glb"  > tower.glb
```

Cost at time of writing: ~$0.04 per generation with texture, ~$0.01 shape-only
(check replicate.com/tencent for current pricing). For OpenForge's "generate
a sprite on demand from a natural-language prompt" workflow, the Replicate
path is usually faster end-to-end than waiting for a local MPS run plus mesh
post-processing, but it is not self-contained and requires a network round-trip.

We recommend a two-tier strategy:

- **Local MPS** for iteration and assets that should not leak to a third
  party (unreleased game art).
- **Replicate** for cold-start / machines that cannot run the full pipeline.

The OpenForge AI gateway (`tools/ai_gateway/`) has hooks for both paths.

## Troubleshooting

- Installer log lives at `~/.openforge-ai-env/install.log`. Grep it first.
- To nuke and restart: `rm -rf ~/.openforge-ai-env && bash install_hunyuan3d_mac.sh`.
- To keep the venv but re-download models: `rm -rf ~/.openforge-ai-env/.state/models.done ~/.openforge-ai-env/models && bash install_hunyuan3d_mac.sh`.
- If `hunyuan3d-gen` hangs for >2 min on first run, that's the Metal shader
  cache warming up. Subsequent runs are much faster.

## Versions pinned by this installer

| Component              | Version                        |
| ---------------------- | ------------------------------ |
| torch                  | 2.4.0                          |
| torchvision            | 0.19.0                         |
| Hunyuan3D-2 source     | `main` (override via `HUNYUAN_COMMIT`) |
| Shape model            | `tencent/Hunyuan3D-2mini` (0.6 B) |
| Texture model          | `tencent/Hunyuan3D-2` (1.3 B)  |
| Python                 | 3.10 / 3.11 / 3.12             |

To pin a specific upstream commit:

```bash
HUNYUAN_COMMIT=abc1234 bash install_hunyuan3d_mac.sh
```
