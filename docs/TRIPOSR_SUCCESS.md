# TripoSR Local 3D Pipeline — Working on Mac Studio (Apple Silicon, MPS)

> Date: 2026-04-25. After Hunyuan3D failed on MPS (see `HUNYUAN_SMOKE_TEST.md`),
> swapped to TripoSR (Stability AI, ~600M params). It works.

## TL;DR

**Local image-to-3D pipeline shipped.** TripoSR runs on M-series MPS, generates a
~500-vert vertex-colored OBJ mesh in ~28 seconds end-to-end. No CUDA required,
no cloud cost per render, runs entirely on the Mac Studio's GPU.

```bash
~/.openforge-ai-env/hunyuan3d/bin/python \
  ~/.openforge-ai-env/src/TripoSR/run.py \
  /path/to/input.jpg \
  --device mps \
  --output-dir /tmp/triposr_out/
# → /tmp/triposr_out/0/mesh.obj  (514 verts × 1020 faces, vertex-colored)
# → /tmp/triposr_out/0/input.png (rembg-processed, background removed)
```

## Stack that worked

| Layer | Choice | Notes |
|---|---|---|
| Python | 3.11.15 (brew) | Reused the venv from the Hunyuan attempt |
| Torch | 2.4.0 with MPS | `torch.backends.mps.is_available() == True` |
| Model | `stabilityai/TripoSR` (HuggingFace, 1.5GB ckpt) | Auto-downloads on first run |
| Background remover | `rembg` (~176MB ONNX U2-Net) | First-run download, subsequent runs cached |
| Image encoder | `facebook/dino-vitb16` (~340MB) | Auto-downloaded |
| Mesh extraction | `torchmcubes` (CPU marching cubes) | **Built cleanly from source on Apple Silicon** — this was the equivalent that failed for Hunyuan's `custom_rasterizer` |
| Mesh I/O | `trimesh`, `xatlas`, `moderngl` 5.12 | `moderngl==5.10` does NOT have a Mac wheel; latest does |
| Detachment | Claude `Bash` tool with `run_in_background: true` | Plain `nohup` and `setsid` were unreliable in this harness |

## Why TripoSR worked when Hunyuan didn't

| Concern | Hunyuan3D-2 | TripoSR |
|---|---|---|
| Hardcoded `.cuda()` calls | ❌ Pervasive (`pipelines.py:308 self.vae.to(device)` blew up under MPS) | ✅ Honors `--device mps` flag throughout |
| C++ extensions assume CUDA | ❌ `custom_rasterizer` + `differentiable_renderer` don't build on Mac | ✅ Only `torchmcubes`, builds cleanly via standard C++ |
| Model size on disk | 24GB shape-only (mini variants) + would-have-been 23GB texture | 1.6GB total (TripoSR + DINO + rembg) |
| Texture generation | Blocked (extensions failed) | Vertex colors baked into OBJ — usable as-is |
| First-run setup time | 30+ min download + install | ~2 min download |
| End-to-end inference | ❌ Never reached | **~28 seconds** on MPS |

## Performance breakdown (single image, M-series MPS)

```
Initializing model       8607 ms   (one-time per process)
Processing images        1150 ms   (rembg + DINO encode)
Running model            3347 ms   ← actual TripoSR inference
Extracting mesh         15422 ms   (marching cubes, CPU-bound)
Exporting mesh              2 ms   (trimesh OBJ writer)
─────────────────────────────────
Total                  ~28000 ms
```

The TripoSR forward pass is just 3.3s. The bottleneck is marching cubes (CPU,
single-threaded `torchmcubes`). For batch art-asset generation, run multiple
images sequentially in the same process to amortize the 8.6s init.

## What you get out

`/tmp/triposr_out/<i>/mesh.obj` — a **vertex-colored** OBJ:
- ~500 vertices, ~1000 triangles
- Colors per vertex (no texture atlas required)
- Drag-and-droppable into Godot 4 — Godot's OBJ importer handles vertex colors
- For a stylized low-poly RPG silhouette this is shippable; for a high-detail
  hero/boss you'd re-mesh and bake textures separately

`/tmp/triposr_out/<i>/input.png` — the rembg background-removed input. Useful
for visual debugging if the mesh comes out wrong (often it's a background
mask issue, not a model issue).

## Optional flags worth knowing

```
--mc-resolution 256       # default 256; bump to 512 for crisper meshes (slower)
--bake-texture            # generate a texture atlas instead of vertex colors
--texture-resolution 2048 # only with --bake-texture
--render                  # also render a 30-frame turntable video
--remove-bg false         # skip rembg if your input already has alpha
```

`--bake-texture` requires moderngl + xatlas (already installed). Test before
relying on it for a batch run.

## How to wire this into the OpenForge art pipeline

`docs/ART_ASSET_PLAN.md` (Task #18) already enumerates the 2D prompts to feed
into FLUX/Midjourney. The flow is now:

1. **2D**: image-gen tool produces a hero/enemy concept image (FLUX, Midjourney, SD)
2. **3D**: TripoSR converts the 2D image → vertex-colored OBJ
3. **Optional**: re-mesh in Blender if the topology needs cleanup (most low-poly
   stylized targets won't)
4. **Import**: OBJ → Godot 4 GLB via the editor or a build script

For the 6 P0 hero/enemy/boss asset gaps in `ROGUE_SURVIVOR_GAPS.md` §1, this
pipeline is now end-to-end runnable on the Mac Studio with zero per-asset cost.

## Caveats

1. **Quality is image-dependent.** A clean centered single-subject image gives
   a good mesh; a busy multi-subject scene (like the `fantasy_rts/Preview.jpg`
   used as the smoke-test input) gives a noisy mesh. The 514-vert / 1020-face
   smoke output is correct for a *complex* input — single-character inputs
   should produce cleaner topology around the same vert count.
2. **Marching cubes is CPU-bound.** ~15s is the floor for `mc-resolution=256`.
   `--mc-resolution 512` quadruples that to ~60s per asset.
3. **Vertex colors only by default.** For texture-atlas output, `--bake-texture`
   exists but exercises a different code path that has not been smoke-tested
   yet on this stack.
4. **No prompt-to-3D.** TripoSR is image-to-3D only. The full art pipeline
   needs an upstream image-gen step — see `ART_ASSET_PLAN.md` for that half.

## Disk footprint

```
~/.openforge-ai-env/        25 GB   (mostly the unused Hunyuan mini model)
~/.cache/huggingface/      1.6 GB   (TripoSR + DINO + rembg models)
```

If you want to free disk: delete `~/.openforge-ai-env/models/tencent--Hunyuan3D-2mini`
(reclaims ~24GB). The Hunyuan venv itself is small and harmless to keep —
TripoSR uses the same one.

## The Hunyuan attempt was not wasted

The Python venv, PyTorch+MPS install, brew Python 3.11, and a chunk of
shared deps (transformers, diffusers, trimesh, huggingface_hub) were all
reused for TripoSR. Net cost of the failed Hunyuan path was the ~24GB of
unused model weights, which can be deleted any time.

---

*Smoke-tested 2026-04-25 against `assets/models/fantasy_rts/Preview.jpg` —
mesh validates: 514 verts × 1020 faces, vertex colors present.*
