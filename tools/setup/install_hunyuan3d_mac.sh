#!/usr/bin/env bash
# install_hunyuan3d_mac.sh
# Self-contained installer for Hunyuan3D 2.0 on Apple Silicon (M1/M2/M3/M4)
# Target: Mac Studio 32GB unified memory, MPS backend, pure pip, no conda.
#
# Idempotent: safe to re-run. Each step checks for completion markers and skips
# work that is already done. Use FORCE_REINSTALL=1 to redo everything.
#
# Usage:
#   bash tools/setup/install_hunyuan3d_mac.sh            # full install
#   SKIP_MODELS=1 bash tools/setup/install_hunyuan3d_mac.sh  # code only
#   FORCE_REINSTALL=1 bash tools/setup/install_hunyuan3d_mac.sh  # rebuild venv
#
# After install, a CLI wrapper is exposed at:
#   ~/.openforge-ai-env/bin/hunyuan3d-gen
#
# Symlink it into your PATH (e.g. /usr/local/bin) manually if you want global
# access — the installer intentionally does not touch system paths.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
ENV_ROOT="${ENV_ROOT:-$HOME/.openforge-ai-env}"
VENV_DIR="$ENV_ROOT/hunyuan3d"
SRC_DIR="$ENV_ROOT/src/Hunyuan3D-2"
MODELS_DIR="$ENV_ROOT/models"
BIN_DIR="$ENV_ROOT/bin"
STATE_DIR="$ENV_ROOT/.state"
LOG_FILE="$ENV_ROOT/install.log"

HUNYUAN_REPO="https://github.com/tencent/Hunyuan3D-2.git"
HUNYUAN_COMMIT="${HUNYUAN_COMMIT:-main}"  # pin to a tag/sha for reproducibility

# Default to the mini model (0.6B) — fits comfortably in 32GB unified memory
# and has much shorter cold-start. Override to hunyuan3d-2 for the 1.1B model.
SHAPE_MODEL_REPO="${SHAPE_MODEL_REPO:-tencent/Hunyuan3D-2mini}"
TEXTURE_MODEL_REPO="${TEXTURE_MODEL_REPO:-tencent/Hunyuan3D-2}"

# Python 3.10 or 3.11 recommended; 3.12 has torch wheel availability caveats
# for some deps. We search for the best available interpreter.
PYTHON_CANDIDATES=(python3.11 python3.10 python3.12 python3)

# Torch version: 2.2+ required for stable MPS. 2.4.0 is the current sweet spot
# for Apple Silicon (Metal shader compiler stability) as of early 2026.
TORCH_VERSION="${TORCH_VERSION:-2.4.0}"
TORCHVISION_VERSION="${TORCHVISION_VERSION:-0.19.0}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { printf '\033[1;34m[hunyuan3d-install]\033[0m %s\n' "$*" | tee -a "$LOG_FILE"; }
warn() { printf '\033[1;33m[hunyuan3d-install] WARN:\033[0m %s\n' "$*" | tee -a "$LOG_FILE" >&2; }
fail() { printf '\033[1;31m[hunyuan3d-install] FATAL:\033[0m %s\n' "$*" | tee -a "$LOG_FILE" >&2; exit 1; }

mark_done()    { mkdir -p "$STATE_DIR"; touch "$STATE_DIR/$1.done"; }
already_done() { [[ -f "$STATE_DIR/$1.done" && -z "${FORCE_REINSTALL:-}" ]]; }

require_macos_arm64() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"
  [[ "$os" == "Darwin" ]] || fail "This installer targets macOS only (got: $os)."
  [[ "$arch" == "arm64" ]] || fail "Apple Silicon (arm64) required (got: $arch). Intel Macs not supported by this script."
}

pick_python() {
  for p in "${PYTHON_CANDIDATES[@]}"; do
    if command -v "$p" >/dev/null 2>&1; then
      local ver
      ver="$("$p" -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
      case "$ver" in
        3.10|3.11|3.12) echo "$p"; return 0 ;;
      esac
    fi
  done
  fail "No compatible Python (3.10/3.11/3.12) found. Install via: brew install python@3.11"
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
mkdir -p "$ENV_ROOT" "$BIN_DIR" "$STATE_DIR" "$MODELS_DIR" "$(dirname "$SRC_DIR")"
: > "$LOG_FILE" 2>/dev/null || true

log "OpenForge Hunyuan3D 2.0 installer starting."
log "ENV_ROOT=$ENV_ROOT"
require_macos_arm64

if ! command -v git >/dev/null 2>&1; then
  fail "git not found. Install Xcode command line tools: xcode-select --install"
fi

# Apple's /usr/bin/python3 ships without venv on some versions; prefer Homebrew.
PYTHON_BIN="$(pick_python)"
log "Selected Python: $PYTHON_BIN ($("$PYTHON_BIN" --version 2>&1))"

# Warn if Xcode CLT is missing — custom_rasterizer/differentiable_renderer
# compile C++ extensions that need clang + headers.
if ! xcode-select -p >/dev/null 2>&1; then
  warn "Xcode command line tools not detected. Texture-gen C++ extensions may fail to build."
  warn "Install with: xcode-select --install"
fi

# ---------------------------------------------------------------------------
# Step 1: venv
# ---------------------------------------------------------------------------
if already_done "venv"; then
  log "[1/6] venv already exists — skipping."
else
  log "[1/6] Creating venv at $VENV_DIR"
  if [[ -n "${FORCE_REINSTALL:-}" && -d "$VENV_DIR" ]]; then
    log "FORCE_REINSTALL set — removing existing venv."
    rm -rf "$VENV_DIR"
  fi
  "$PYTHON_BIN" -m venv "$VENV_DIR"
  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
  pip install --upgrade pip wheel setuptools >>"$LOG_FILE" 2>&1
  deactivate
  mark_done "venv"
fi

# Activate for remaining steps.
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
log "Active Python: $(python --version) @ $(which python)"

# ---------------------------------------------------------------------------
# Step 2: PyTorch with MPS support
# ---------------------------------------------------------------------------
if already_done "torch"; then
  log "[2/6] PyTorch already installed — skipping."
else
  log "[2/6] Installing PyTorch $TORCH_VERSION with MPS support"
  # Apple Silicon wheels from pypi default index include MPS; no special index URL needed.
  pip install \
    "torch==$TORCH_VERSION" \
    "torchvision==$TORCHVISION_VERSION" \
    >>"$LOG_FILE" 2>&1 || fail "torch install failed — see $LOG_FILE"

  # Sanity check MPS availability.
  python - <<'PY' >>"$LOG_FILE" 2>&1 || fail "MPS not available — check macOS version (need 12.3+)."
import torch
assert torch.backends.mps.is_available(), "MPS unavailable"
assert torch.backends.mps.is_built(), "MPS not built"
print("MPS OK:", torch.__version__)
PY
  mark_done "torch"
fi

# ---------------------------------------------------------------------------
# Step 3: Clone Hunyuan3D-2 source
# ---------------------------------------------------------------------------
if already_done "clone"; then
  log "[3/6] Source already cloned — fetching updates."
  git -C "$SRC_DIR" fetch --quiet origin >>"$LOG_FILE" 2>&1 || warn "git fetch failed (offline?)."
else
  log "[3/6] Cloning $HUNYUAN_REPO -> $SRC_DIR"
  if [[ -d "$SRC_DIR" ]]; then
    rm -rf "$SRC_DIR"
  fi
  git clone --depth 1 --branch "$HUNYUAN_COMMIT" "$HUNYUAN_REPO" "$SRC_DIR" >>"$LOG_FILE" 2>&1 \
    || fail "git clone failed — see $LOG_FILE"
  mark_done "clone"
fi

# ---------------------------------------------------------------------------
# Step 4: Install Hunyuan3D Python deps
# ---------------------------------------------------------------------------
if already_done "deps"; then
  log "[4/6] Python deps already installed — skipping."
else
  log "[4/6] Installing Hunyuan3D Python dependencies"
  pushd "$SRC_DIR" >/dev/null

  # The upstream requirements.txt pulls in a handful of packages that either
  # don't build on Apple Silicon or are CUDA-only. Strip them here; we patch
  # a filtered copy rather than editing upstream.
  if [[ -f requirements.txt ]]; then
    grep -viE '^(xformers|flash[-_]attn|bitsandbytes|triton)\b' requirements.txt \
      > requirements.mac.txt || true
    pip install -r requirements.mac.txt >>"$LOG_FILE" 2>&1 \
      || fail "pip install -r requirements.mac.txt failed — see $LOG_FILE"
  else
    warn "requirements.txt missing from upstream — skipping."
  fi

  pip install -e . >>"$LOG_FILE" 2>&1 \
    || fail "pip install -e . failed — see $LOG_FILE"

  # Texture-gen C++ extensions. These often fail on Mac because they assume
  # CUDA. We attempt the build but do not hard-fail; the user can still do
  # shape-only generation without texture.
  if [[ -d hy3dgen/texgen/custom_rasterizer ]]; then
    log "Attempting custom_rasterizer build (may fail without CUDA)..."
    ( cd hy3dgen/texgen/custom_rasterizer && python setup.py install ) \
      >>"$LOG_FILE" 2>&1 \
      && log "custom_rasterizer built" \
      || warn "custom_rasterizer build failed — texture gen will be unavailable. Use Replicate fallback for textures."
  fi
  if [[ -d hy3dgen/texgen/differentiable_renderer ]]; then
    log "Attempting differentiable_renderer build (may fail without CUDA)..."
    ( cd hy3dgen/texgen/differentiable_renderer && python setup.py install ) \
      >>"$LOG_FILE" 2>&1 \
      && log "differentiable_renderer built" \
      || warn "differentiable_renderer build failed — texture gen will be unavailable."
  fi

  # Always available: huggingface_hub for model download + trimesh for export.
  pip install "huggingface_hub>=0.23" "trimesh>=4.0" "Pillow>=10.0" \
    >>"$LOG_FILE" 2>&1
  popd >/dev/null
  mark_done "deps"
fi

# ---------------------------------------------------------------------------
# Step 5: Download models
# ---------------------------------------------------------------------------
if [[ -n "${SKIP_MODELS:-}" ]]; then
  log "[5/6] SKIP_MODELS set — skipping model download."
elif already_done "models"; then
  log "[5/6] Models already downloaded — skipping."
else
  log "[5/6] Downloading models to $MODELS_DIR"
  log "       shape:   $SHAPE_MODEL_REPO"
  log "       texture: $TEXTURE_MODEL_REPO"
  HF_HOME="$MODELS_DIR" python - <<PY >>"$LOG_FILE" 2>&1 || fail "model download failed — see $LOG_FILE"
import os
from huggingface_hub import snapshot_download

cache = os.environ["HF_HOME"]
for repo in ["$SHAPE_MODEL_REPO", "$TEXTURE_MODEL_REPO"]:
    print(f"Downloading {repo} -> {cache}")
    snapshot_download(
        repo_id=repo,
        cache_dir=cache,
        local_dir=os.path.join(cache, repo.replace("/", "--")),
        local_dir_use_symlinks=False,
        ignore_patterns=["*.onnx", "*.safetensors.index.json.bak"],
    )
PY
  mark_done "models"
fi

# ---------------------------------------------------------------------------
# Step 6: CLI wrapper
# ---------------------------------------------------------------------------
WRAPPER="$BIN_DIR/hunyuan3d-gen"
PY_ENTRY="$BIN_DIR/_hunyuan3d_gen.py"

log "[6/6] Writing CLI wrapper -> $WRAPPER"

cat > "$PY_ENTRY" <<'PY'
#!/usr/bin/env python3
"""hunyuan3d-gen — minimal CLI wrapper around the Hunyuan3D 2.0 pipeline.

Usage:
    hunyuan3d-gen --prompt "low-poly stone tower" --out tower.glb
    hunyuan3d-gen --image input.png --out model.glb --steps 30
    hunyuan3d-gen --prompt "..." --texture --out model.glb  # if texgen built

Exit codes: 0 ok, 1 user error, 2 runtime error, 3 MPS unavailable.
"""
from __future__ import annotations
import argparse, os, sys, time, traceback

def main() -> int:
    ap = argparse.ArgumentParser(prog="hunyuan3d-gen")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--prompt", help="text prompt (text-to-3D)")
    src.add_argument("--image", help="path to image (image-to-3D)")
    ap.add_argument("--out", required=True, help="output .glb path")
    ap.add_argument("--steps", type=int, default=30)
    ap.add_argument("--seed", type=int, default=1234)
    ap.add_argument("--texture", action="store_true", help="run texture pass (requires built C++ ext)")
    ap.add_argument("--shape-model", default=os.environ.get("HUNYUAN_SHAPE_MODEL", "tencent/Hunyuan3D-2mini"))
    ap.add_argument("--texture-model", default=os.environ.get("HUNYUAN_TEXTURE_MODEL", "tencent/Hunyuan3D-2"))
    ap.add_argument("--device", default="mps", choices=["mps", "cpu"])
    args = ap.parse_args()

    os.environ.setdefault("PYTORCH_ENABLE_MPS_FALLBACK", "1")

    try:
        import torch
    except ImportError:
        print("torch not installed — run install_hunyuan3d_mac.sh first", file=sys.stderr)
        return 2

    if args.device == "mps" and not torch.backends.mps.is_available():
        print("MPS unavailable on this machine — falling back to CPU (very slow).", file=sys.stderr)
        args.device = "cpu"

    try:
        from hy3dgen.shapegen import Hunyuan3DDiTFlowMatchingPipeline
    except ImportError as e:
        print(f"hy3dgen import failed: {e}", file=sys.stderr)
        return 2

    t0 = time.time()
    print(f"[hunyuan3d-gen] loading shape pipeline ({args.shape_model}) on {args.device}...", flush=True)
    pipe = Hunyuan3DDiTFlowMatchingPipeline.from_pretrained(args.shape_model)
    pipe = pipe.to(args.device)

    gen_kwargs = dict(num_inference_steps=args.steps, generator=torch.Generator().manual_seed(args.seed))
    if args.prompt:
        print(f"[hunyuan3d-gen] text->3D: {args.prompt!r}", flush=True)
        mesh = pipe(prompt=args.prompt, **gen_kwargs)[0]
    else:
        from PIL import Image
        img = Image.open(args.image).convert("RGB")
        print(f"[hunyuan3d-gen] image->3D from {args.image}", flush=True)
        mesh = pipe(image=img, **gen_kwargs)[0]

    if args.texture:
        try:
            from hy3dgen.texgen import Hunyuan3DPaintPipeline
            print(f"[hunyuan3d-gen] applying texture pass ({args.texture_model})...", flush=True)
            tex = Hunyuan3DPaintPipeline.from_pretrained(args.texture_model).to(args.device)
            # Texture pass expects an image ref — reuse the conditioning image
            # if one was provided, else skip.
            if args.image:
                from PIL import Image as _I
                mesh = tex(mesh, image=_I.open(args.image).convert("RGB"))
            else:
                print("[hunyuan3d-gen] --texture without --image: skipping (requires image ref).", file=sys.stderr)
        except Exception as e:
            print(f"[hunyuan3d-gen] texture pass failed ({e}) — exporting untextured mesh.", file=sys.stderr)

    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
    mesh.export(args.out)
    dt = time.time() - t0
    print(f"[hunyuan3d-gen] done in {dt:.1f}s -> {args.out}", flush=True)
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception:
        traceback.print_exc()
        sys.exit(2)
PY

cat > "$WRAPPER" <<EOF
#!/usr/bin/env bash
# Auto-generated by install_hunyuan3d_mac.sh — do not edit by hand.
set -euo pipefail
VENV="$VENV_DIR"
export HF_HOME="$MODELS_DIR"
export PYTORCH_ENABLE_MPS_FALLBACK=1
# shellcheck disable=SC1091
source "\$VENV/bin/activate"
exec python "$PY_ENTRY" "\$@"
EOF

chmod 755 "$WRAPPER" "$PY_ENTRY"
mark_done "wrapper"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
log "============================================================"
log "Install complete."
log "  venv:    $VENV_DIR"
log "  models:  $MODELS_DIR"
log "  CLI:     $WRAPPER"
log ""
log "Try it:"
log "  $WRAPPER --prompt 'low-poly stone tower' --out /tmp/tower.glb --steps 30"
log ""
log "To add to PATH:"
log "  ln -s '$WRAPPER' /usr/local/bin/hunyuan3d-gen"
log "============================================================"
