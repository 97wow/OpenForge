#!/usr/bin/env python3
"""
ai_gateway — Unified OpenAI-compatible router across multiple free/cheap LLM providers.

Routes LLM calls through whichever of SiliconFlow / Groq / Cerebras / Mistral / GitHub
Models is configured, with automatic fallback on failure or rate-limit.

Usage:
  from ai_gateway import chat
  reply = chat("Explain factions in OpenForge", task="quick")

CLI:
  python ai_gateway.py "design a TD hero skill" --task code
  python ai_gateway.py --probe            # test all configured providers

Config is loaded from ~/.ai_gateway.env or env vars (see .env.example).
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable

CONFIG_PATH = Path.home() / ".ai_gateway.env"


def _load_dotenv(path: Path) -> None:
    if not path.exists():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


_load_dotenv(CONFIG_PATH)


@dataclass
class Provider:
    name: str
    base_url: str
    env_key: str
    default_model: str
    strengths: list[str] = field(default_factory=list)
    extra_headers: dict[str, str] = field(default_factory=dict)

    @property
    def api_key(self) -> str | None:
        return os.environ.get(self.env_key)

    @property
    def configured(self) -> bool:
        return bool(self.api_key)


PROVIDERS: list[Provider] = [
    Provider(
        name="groq",
        base_url="https://api.groq.com/openai/v1",
        env_key="GROQ_API_KEY",
        default_model="llama-3.3-70b-versatile",
        strengths=["quick", "code", "chat"],
    ),
    Provider(
        name="cerebras",
        base_url="https://api.cerebras.ai/v1",
        env_key="CEREBRAS_API_KEY",
        default_model="llama3.1-8b",
        strengths=["quick", "chat"],
    ),
    Provider(
        name="siliconflow",
        base_url="https://api.siliconflow.cn/v1",
        env_key="SILICONFLOW_API_KEY",
        default_model="Qwen/Qwen2.5-7B-Instruct",
        strengths=["chat", "chinese", "image_prompt"],
    ),
    Provider(
        name="mistral",
        base_url="https://api.mistral.ai/v1",
        env_key="MISTRAL_API_KEY",
        default_model="mistral-small-latest",
        strengths=["chat", "design"],
    ),
    Provider(
        name="github_models",
        base_url="https://models.inference.ai.azure.com",
        env_key="GITHUB_MODELS_TOKEN",
        default_model="gpt-4o-mini",
        strengths=["design", "code", "chat"],
    ),
]


TASK_MODEL_OVERRIDES: dict[str, dict[str, str]] = {
    "code": {
        "groq": "llama-3.3-70b-versatile",
        "siliconflow": "deepseek-ai/DeepSeek-V3",
        "github_models": "gpt-4o-mini",
    },
    "design": {
        "siliconflow": "deepseek-ai/DeepSeek-V3",
        "github_models": "gpt-4o-mini",
        "mistral": "mistral-small-latest",
    },
    "quick": {
        "cerebras": "llama3.1-8b",
        "groq": "llama-3.1-8b-instant",
    },
    "chinese": {
        "siliconflow": "Qwen/Qwen2.5-7B-Instruct",
    },
}


TASK_PROVIDER_ORDER: dict[str, list[str]] = {
    "code": ["groq", "siliconflow", "github_models", "cerebras", "mistral"],
    "design": ["siliconflow", "github_models", "mistral", "groq"],
    "quick": ["cerebras", "groq", "siliconflow", "mistral", "github_models"],
    "chinese": ["siliconflow", "groq", "mistral"],
    "chat": ["groq", "siliconflow", "cerebras", "mistral", "github_models"],
}


class ProviderError(RuntimeError):
    def __init__(self, provider: str, status: int, body: str) -> None:
        super().__init__(f"[{provider}] HTTP {status}: {body[:400]}")
        self.provider = provider
        self.status = status
        self.body = body


def _post_chat(provider: Provider, model: str, messages: list[dict], **kwargs) -> dict:
    url = provider.base_url.rstrip("/") + "/chat/completions"
    payload: dict[str, Any] = {"model": model, "messages": messages}
    for k in ("max_tokens", "temperature", "top_p", "stop"):
        if k in kwargs and kwargs[k] is not None:
            payload[k] = kwargs[k]
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": f"Bearer {provider.api_key}",
            "Content-Type": "application/json",
            "User-Agent": "ai_gateway/0.1 (+https://github.com/llmapi-pro)",
            **provider.extra_headers,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            body = resp.read().decode()
    except urllib.error.HTTPError as e:
        raise ProviderError(provider.name, e.code, e.read().decode(errors="replace"))
    except urllib.error.URLError as e:
        raise ProviderError(provider.name, 0, str(e))
    return json.loads(body)


@dataclass
class CallLog:
    provider: str
    model: str
    latency_ms: int
    prompt_tokens: int
    completion_tokens: int
    content: str

    def as_dict(self) -> dict:
        return {
            "provider": self.provider,
            "model": self.model,
            "latency_ms": self.latency_ms,
            "prompt_tokens": self.prompt_tokens,
            "completion_tokens": self.completion_tokens,
        }


_log_history: list[CallLog] = []


def chat(
    prompt: str | list[dict],
    *,
    task: str = "chat",
    provider: str | None = None,
    model: str | None = None,
    max_tokens: int = 1024,
    temperature: float = 0.7,
    on_log: Callable[[CallLog], None] | None = None,
) -> str:
    """Send a chat request, falling back across providers for the given task.

    Returns the assistant's text content. Raises RuntimeError if all providers fail.
    """
    messages = (
        [{"role": "user", "content": prompt}]
        if isinstance(prompt, str)
        else prompt
    )
    order = [provider] if provider else TASK_PROVIDER_ORDER.get(task, TASK_PROVIDER_ORDER["chat"])
    errors: list[str] = []
    for name in order:
        p = next((x for x in PROVIDERS if x.name == name), None)
        if p is None or not p.configured:
            errors.append(f"{name}: not configured")
            continue
        picked_model = model or TASK_MODEL_OVERRIDES.get(task, {}).get(name) or p.default_model
        t0 = time.time()
        try:
            data = _post_chat(
                p, picked_model, messages,
                max_tokens=max_tokens, temperature=temperature,
            )
        except ProviderError as e:
            errors.append(str(e))
            continue
        latency_ms = int((time.time() - t0) * 1000)
        try:
            content = data["choices"][0]["message"]["content"]
        except (KeyError, IndexError) as e:
            errors.append(f"{name}: malformed response {e}")
            continue
        usage = data.get("usage") or {}
        log = CallLog(
            provider=p.name,
            model=picked_model,
            latency_ms=latency_ms,
            prompt_tokens=int(usage.get("prompt_tokens", 0)),
            completion_tokens=int(usage.get("completion_tokens", 0)),
            content=content,
        )
        _log_history.append(log)
        if on_log:
            on_log(log)
        return content
    raise RuntimeError("All providers failed:\n  " + "\n  ".join(errors))


def probe() -> list[dict]:
    """Ping every configured provider and return a status report."""
    report: list[dict] = []
    for p in PROVIDERS:
        entry: dict[str, Any] = {"provider": p.name, "configured": p.configured}
        if not p.configured:
            entry["status"] = "skipped (no API key)"
            report.append(entry)
            continue
        t0 = time.time()
        try:
            _post_chat(p, p.default_model, [{"role": "user", "content": "ping"}], max_tokens=5)
            entry["status"] = "ok"
        except ProviderError as e:
            entry["status"] = f"fail: HTTP {e.status}"
        entry["latency_ms"] = int((time.time() - t0) * 1000)
        report.append(entry)
    return report


def history() -> list[CallLog]:
    return list(_log_history)


def _cli() -> None:
    ap = argparse.ArgumentParser(description="ai_gateway CLI")
    ap.add_argument("prompt", nargs="?", help="Prompt to send")
    ap.add_argument("--task", default="chat", choices=list(TASK_PROVIDER_ORDER.keys()))
    ap.add_argument("--provider", help="Force a specific provider")
    ap.add_argument("--model", help="Override the model")
    ap.add_argument("--max-tokens", type=int, default=1024)
    ap.add_argument("--temperature", type=float, default=0.7)
    ap.add_argument("--probe", action="store_true", help="Probe all providers")
    ap.add_argument("--list", action="store_true", help="List providers + configured state")
    args = ap.parse_args()

    if args.list:
        for p in PROVIDERS:
            mark = "✓" if p.configured else "✗"
            print(f"  {mark} {p.name:<14} {p.base_url}")
        return
    if args.probe:
        for r in probe():
            print(json.dumps(r, ensure_ascii=False))
        return
    if not args.prompt:
        ap.error("prompt required (or use --probe / --list)")
    reply = chat(
        args.prompt,
        task=args.task,
        provider=args.provider,
        model=args.model,
        max_tokens=args.max_tokens,
        temperature=args.temperature,
    )
    print(reply)
    if _log_history:
        last = _log_history[-1]
        print(f"\n--- {last.provider}/{last.model} · {last.latency_ms}ms · in={last.prompt_tokens} out={last.completion_tokens}", file=sys.stderr)


if __name__ == "__main__":
    _cli()
