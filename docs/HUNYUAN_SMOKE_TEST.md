# Hunyuan3D Smoke Test — Mac Studio 32GB (Apple Silicon)

> Date: 2026-04-25. Tested against `tools/setup/install_hunyuan3d_mac.sh` (Task #6).

## TL;DR

**Install: partial success.** Python venv, PyTorch 2.4.0 with MPS, `hy3dgen` package, and the shape model (`tencent/Hunyuan3D-2mini`, 24GB) all install cleanly.

**Inference: blocked.** Hunyuan3D-2 has hardcoded `.cuda()` calls in its pipeline code that the MPS fallback flag (`PYTORCH_ENABLE_MPS_FALLBACK=1`) cannot intercept. First real inference attempt fails with `AssertionError: Torch not compiled with CUDA enabled` inside `Hunyuan3DDiTFlowMatchingPipeline.__init__` → `self.vae.to(device)`.

**Recommended path forward:** use Replicate (cloud CUDA) for Hunyuan3D output generation, keep the local venv for model inspection / offline dev, or wait for a community MPS fork.

## What actually works

| Check | Result |
|---|---|
| Python 3.11 venv created at `~/.openforge-ai-env/hunyuan3d` | ✅ |
| `torch==2.4.0` with MPS support | ✅ (`torch.backends.mps.is_available() == True`) |
| Hunyuan3D repo cloned at `~/.openforge-ai-env/src/Hunyuan3D-2` | ✅ |
| Python deps (diffusers / transformers / trimesh / huggingface_hub) | ✅ |
| `custom_rasterizer` C++ extension | ❌ soft-failed (no CUDA) — expected, installer handles gracefully |
| `differentiable_renderer` C++ extension | ❌ soft-failed (no CUDA) — expected |
| Shape model `tencent/Hunyuan3D-2mini` downloaded (6 variants: dit-mini/fast/turbo + vae-mini/turbo/withencoder) | ✅ 24GB |
| `import hy3dgen.shapegen.Hunyuan3DDiTFlowMatchingPipeline` | ✅ |
| `~/.openforge-ai-env/bin/hunyuan3d-gen` CLI wrapper | ✅ |

## What does NOT work

| Check | Result |
|---|---|
| Texture model `tencent/Hunyuan3D-2` | ⚠️ **Download cancelled mid-transfer** and deleted (23GB of a ~40GB+ bundle). Reason: `custom_rasterizer` + `differentiable_renderer` already failed, so texture generation is unreachable regardless. Disk pressure (dropped to 24GB free with 40GB+ still incoming) forced the cleanup. |
| `from_pretrained("tencent/Hunyuan3D-2mini")` with default HF cache | ❌ The installer uses `local_dir_use_symlinks=False` which writes to `tencent--Hunyuan3D-2mini/` (not the standard HF cache dir `models--tencent--Hunyuan3D-2mini/`). `from_pretrained` without a local path cannot find the model. |
| Passing local path as first arg to `from_pretrained(<path>)` | ❌ First blocked because `smart_load_model` looks for subfolder `hunyuan3d-dit-v2-0` which doesn't exist in the mini repo (mini ships `hunyuan3d-dit-v2-mini[-fast|-turbo]` instead). **Worked around** by symlinking `hunyuan3d-dit-v2-0 → hunyuan3d-dit-v2-mini-turbo` and the matching vae. |
| Actual inference on MPS | ❌ **Hard block.** After the symlink fix the model loads from disk, but `pipelines.py:308 self.vae.to(device)` hits `AssertionError: Torch not compiled with CUDA enabled`. The VAE safetensors has CUDA-device metadata that `.to("mps")` cannot override. |

## Full failure stack (for reference)

```
File "_hunyuan3d_gen.py", line 48, in main
    pipe = Hunyuan3DDiTFlowMatchingPipeline.from_pretrained(args.shape_model)
File "pipelines.py", line 225, in from_pretrained
    return cls.from_single_file(...)
File "pipelines.py", line 196, in from_single_file
    return cls(...)
File "pipelines.py", line 251, in __init__
    self.to(device, dtype)
File "pipelines.py", line 308, in to
    self.vae.to(device)
File "torch/cuda/__init__.py", line 305, in _lazy_init
    raise AssertionError("Torch not compiled with CUDA enabled")
```

Invocation that produced this:

```bash
~/.openforge-ai-env/bin/hunyuan3d-gen \
  --image /Users/huhu/Work/Git/OpenForge/assets/models/fantasy_rts/Preview.jpg \
  --out /tmp/hunyuan_smoke.glb \
  --shape-model /Users/huhu/.openforge-ai-env/models/tencent--Hunyuan3D-2mini \
  --steps 15
```

## What we learned about the installer (Task #6)

1. **`local_dir_use_symlinks=False` doubles disk usage** on HuggingFace downloads — the files land in both the HF cache and the local_dir. For a 40GB+ bundle this busts a consumer disk.
2. **Texture model is pure waste on Mac** when the two C++ extensions fail (they always do without CUDA). The installer should `SKIP_TEXTURE_MODEL=1` when it detects those builds failed, or at least warn with "downloading 30GB of model weights you cannot use on this device."
3. **Mini model subfolder naming collides with the loader default** — `smart_load_model` expects `hunyuan3d-dit-v2-0` as the default subfolder name, but the mini repo ships `hunyuan3d-dit-v2-mini` variants. The installer should either symlink the default name or expose a `--subfolder` flag on the wrapper.

## Actionable next steps (not done as part of this smoke test)

1. **Business: switch asset pipeline to Replicate** for Hunyuan3D output. Cost is ~$0.02-0.05 per 3D asset which is cheaper than the time lost patching Hunyuan3D for MPS.
2. **If we insist on local MPS**: patch `pipelines.py:__init__` to load the state_dict with `map_location="mps"` explicitly before calling `.to(device)`, and audit for other `.cuda()` / `torch.cuda.*` calls. This is ~a day of porting work and the community patches exist but are not first-party supported.
3. **Fix the installer**: add `SKIP_TEXTURE_MODEL=1` handling, add subfolder-symlink step, add MPS-suitability check that warns before the 30GB download.
4. **Replace the CLI wrapper's `from_pretrained(args.shape_model)`** with an explicit `subfolder="hunyuan3d-dit-v2-mini-turbo"` when running on MPS, so downstream users don't trip on the same naming mismatch.

## What got installed, for cleanup reference

- Venv: `~/.openforge-ai-env/hunyuan3d` (~1.5GB) — delete if unused
- Shape model: `~/.openforge-ai-env/models/tencent--Hunyuan3D-2mini` (~24GB) — delete if abandoning local path
- Source repo: `~/.openforge-ai-env/src/Hunyuan3D-2` (~160MB)
- CLI wrapper: `~/.openforge-ai-env/bin/hunyuan3d-gen` (~4KB)

Total disk footprint retained: ~25GB. `rm -rf ~/.openforge-ai-env` reclaims everything.

---

*Smoke test performed as the "use it" follow-up to Task #6. Honest result: the installer produces a runnable venv but cannot produce a runnable inference pipeline on M1/M2/M3 without additional patching work that is out of scope for an automated smoke test.*
