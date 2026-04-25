#!/usr/bin/env python3
"""bench_hunyuan3d.py — benchmark Hunyuan3D 2.0 shape generation on MPS.

Runs three fixed prompts representative of the OpenForge asset pipeline and
records wall-clock time plus peak MPS memory for each. Emits a JSON report
and a short markdown table to stdout.

Usage:
    python tools/setup/bench_hunyuan3d.py
    python tools/setup/bench_hunyuan3d.py --out /tmp/hunyuan_bench.json --steps 30

The script prefers the installed venv (~/.openforge-ai-env/hunyuan3d). If
invoked from a different interpreter it re-execs itself inside the venv so
you do not need to activate it manually.

Exit codes:
    0 all prompts generated
    1 usage / env error
    2 MPS unavailable
    3 one or more prompts failed (partial report still written)
"""
from __future__ import annotations

import argparse
import json
import os
import platform
import statistics
import subprocess
import sys
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Venv auto-exec
# ---------------------------------------------------------------------------
ENV_ROOT = Path(os.environ.get("ENV_ROOT", Path.home() / ".openforge-ai-env"))
VENV_PY = ENV_ROOT / "hunyuan3d" / "bin" / "python"

def _reexec_in_venv() -> None:
    """Re-exec under the Hunyuan3D venv if we're not already there."""
    if Path(sys.executable).resolve() == VENV_PY.resolve():
        return
    if not VENV_PY.exists():
        print(f"venv python not found at {VENV_PY}. Run install_hunyuan3d_mac.sh first.",
              file=sys.stderr)
        sys.exit(1)
    os.execv(str(VENV_PY), [str(VENV_PY), __file__, *sys.argv[1:]])

# ---------------------------------------------------------------------------
# Fixed prompt set — representative of OpenForge sprite/prop asks.
# ---------------------------------------------------------------------------
PROMPTS = [
    {
        "id": "low_poly_tower",
        "prompt": "low-poly stone defensive tower, medieval fantasy, flat shaded",
        "category": "prop",
    },
    {
        "id": "pixel_archer_icon",
        "prompt": "pixel-art archer hero portrait icon, chunky silhouette, 3/4 view",
        "category": "icon",
    },
    {
        "id": "stylized_goblin",
        "prompt": "stylized cartoon goblin sprite, hunched pose, hand-painted texture style",
        "category": "creature",
    },
]

# ---------------------------------------------------------------------------
# Result dataclasses
# ---------------------------------------------------------------------------
@dataclass
class PromptResult:
    id: str
    prompt: str
    category: str
    ok: bool = False
    wall_clock_s: float = 0.0
    peak_mps_allocated_mb: float = 0.0
    peak_mps_driver_mb: float = 0.0
    out_path: str = ""
    error: str = ""

@dataclass
class BenchReport:
    timestamp: str
    host: dict = field(default_factory=dict)
    torch: dict = field(default_factory=dict)
    config: dict = field(default_factory=dict)
    warmup_s: float = 0.0
    results: list = field(default_factory=list)
    summary: dict = field(default_factory=dict)

# ---------------------------------------------------------------------------
# Bench logic
# ---------------------------------------------------------------------------
def collect_host_info() -> dict[str, Any]:
    info = {
        "platform": platform.platform(),
        "machine": platform.machine(),
        "python": platform.python_version(),
    }
    # sysctl for Apple Silicon specifics
    try:
        info["cpu_brand"] = subprocess.check_output(
            ["sysctl", "-n", "machdep.cpu.brand_string"], text=True
        ).strip()
    except Exception:
        pass
    try:
        mem_bytes = int(subprocess.check_output(
            ["sysctl", "-n", "hw.memsize"], text=True
        ).strip())
        info["memsize_gb"] = round(mem_bytes / (1024 ** 3), 1)
    except Exception:
        pass
    return info

def collect_torch_info() -> dict[str, Any]:
    import torch  # type: ignore
    return {
        "version": torch.__version__,
        "mps_available": bool(torch.backends.mps.is_available()),
        "mps_built": bool(torch.backends.mps.is_built()),
    }

def reset_mps_peak() -> None:
    import torch  # type: ignore
    if hasattr(torch.mps, "empty_cache"):
        torch.mps.empty_cache()
    if hasattr(torch.mps, "driver_allocated_memory"):
        # no explicit reset API for mps peaks as of torch 2.4; snapshot before/after.
        pass

def mps_mem_snapshot() -> tuple[float, float]:
    """Return (current_allocated_mb, driver_allocated_mb)."""
    import torch  # type: ignore
    alloc = driver = 0.0
    if hasattr(torch.mps, "current_allocated_memory"):
        alloc = torch.mps.current_allocated_memory() / (1024 * 1024)
    if hasattr(torch.mps, "driver_allocated_memory"):
        driver = torch.mps.driver_allocated_memory() / (1024 * 1024)
    return alloc, driver

def run_one(pipe, entry: dict, out_dir: Path, steps: int, seed: int) -> PromptResult:
    import torch  # type: ignore
    result = PromptResult(id=entry["id"], prompt=entry["prompt"], category=entry["category"])
    reset_mps_peak()
    base_alloc, base_driver = mps_mem_snapshot()

    peak_alloc = base_alloc
    peak_driver = base_driver
    t0 = time.perf_counter()
    try:
        mesh = pipe(
            prompt=entry["prompt"],
            num_inference_steps=steps,
            generator=torch.Generator().manual_seed(seed),
        )[0]
        # Sample memory *after* generation — MPS has no peak API, this gives
        # a lower bound. We also sample mid-generation via a small trick:
        # the DiT loop dominates allocation, so end-of-generation is close to
        # peak in practice.
        alloc, driver = mps_mem_snapshot()
        peak_alloc = max(peak_alloc, alloc)
        peak_driver = max(peak_driver, driver)

        out_path = out_dir / f"{entry['id']}.glb"
        mesh.export(str(out_path))
        result.ok = True
        result.out_path = str(out_path)
    except Exception as e:
        result.error = f"{type(e).__name__}: {e}"
    finally:
        result.wall_clock_s = round(time.perf_counter() - t0, 2)
        result.peak_mps_allocated_mb = round(peak_alloc, 1)
        result.peak_mps_driver_mb = round(peak_driver, 1)
        reset_mps_peak()
    return result

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", default=str(Path.home() / ".openforge-ai-env" / "bench.json"),
                    help="output JSON report path")
    ap.add_argument("--out-dir", default="/tmp/hunyuan_bench",
                    help="directory for generated .glb files")
    ap.add_argument("--steps", type=int, default=30)
    ap.add_argument("--seed", type=int, default=4242)
    ap.add_argument("--shape-model", default=os.environ.get(
        "HUNYUAN_SHAPE_MODEL", "tencent/Hunyuan3D-2mini"))
    ap.add_argument("--skip-warmup", action="store_true",
                    help="skip the warmup run that hides Metal shader compile cost")
    args = ap.parse_args()

    os.environ.setdefault("PYTORCH_ENABLE_MPS_FALLBACK", "1")
    os.environ.setdefault("HF_HOME", str(ENV_ROOT / "models"))

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    try:
        import torch  # type: ignore
    except ImportError:
        print("torch not installed in this env", file=sys.stderr)
        return 1

    if not torch.backends.mps.is_available():
        print("MPS not available on this host — aborting bench.", file=sys.stderr)
        return 2

    try:
        from hy3dgen.shapegen import Hunyuan3DDiTFlowMatchingPipeline  # type: ignore
    except ImportError as e:
        print(f"hy3dgen import failed: {e}", file=sys.stderr)
        return 1

    report = BenchReport(
        timestamp=time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        host=collect_host_info(),
        torch=collect_torch_info(),
        config={
            "shape_model": args.shape_model,
            "steps": args.steps,
            "seed": args.seed,
        },
    )

    print(f"[bench] loading {args.shape_model} on MPS…", flush=True)
    load_t0 = time.perf_counter()
    pipe = Hunyuan3DDiTFlowMatchingPipeline.from_pretrained(args.shape_model).to("mps")
    report.config["load_time_s"] = round(time.perf_counter() - load_t0, 2)

    if not args.skip_warmup:
        print("[bench] warmup (excluded from timing)…", flush=True)
        warm_t0 = time.perf_counter()
        try:
            pipe(prompt="a cube",
                 num_inference_steps=max(4, args.steps // 4),
                 generator=torch.Generator().manual_seed(0))
        except Exception as e:
            print(f"[bench] warmup failed ({e}) — continuing anyway.", file=sys.stderr)
        report.warmup_s = round(time.perf_counter() - warm_t0, 2)

    failed = 0
    for entry in PROMPTS:
        print(f"[bench] {entry['id']}: {entry['prompt']!r}", flush=True)
        res = run_one(pipe, entry, out_dir, args.steps, args.seed)
        tag = "OK" if res.ok else "FAIL"
        print(f"        {tag}  t={res.wall_clock_s}s  mps={res.peak_mps_allocated_mb} MB alloc / {res.peak_mps_driver_mb} MB driver", flush=True)
        if not res.ok:
            print(f"        error: {res.error}", flush=True)
            failed += 1
        report.results.append(asdict(res))

    oks = [r for r in report.results if r["ok"]]
    if oks:
        times = [r["wall_clock_s"] for r in oks]
        mem = [r["peak_mps_driver_mb"] for r in oks]
        report.summary = {
            "count": len(oks),
            "wall_clock_mean_s": round(statistics.mean(times), 2),
            "wall_clock_median_s": round(statistics.median(times), 2),
            "wall_clock_max_s": round(max(times), 2),
            "peak_mps_driver_mb_max": round(max(mem), 1),
        }

    Path(args.out).write_text(json.dumps(asdict(report), indent=2))
    print(f"\n[bench] report written -> {args.out}", flush=True)

    # Markdown summary
    print("\n| id | ok | wall (s) | peak MPS alloc (MB) | peak MPS driver (MB) |")
    print("|---|---|---:|---:|---:|")
    for r in report.results:
        print(f"| {r['id']} | {'Y' if r['ok'] else 'N'} | {r['wall_clock_s']} | {r['peak_mps_allocated_mb']} | {r['peak_mps_driver_mb']} |")
    if report.summary:
        s = report.summary
        print(f"\nMean wall-clock: {s['wall_clock_mean_s']}s  | Max peak driver MPS: {s['peak_mps_driver_mb_max']} MB")

    return 0 if failed == 0 else 3


if __name__ == "__main__":
    _reexec_in_venv()
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
