# ai_gateway

Zero-dependency OpenAI-compatible router across multiple free/cheap LLM providers.

Routes `chat()` calls through Groq / Cerebras / SiliconFlow / Mistral / GitHub Models,
picking the best fit for a `task` tag and auto-falling back on failure / rate-limit.

## Why

- A single import instead of five SDKs.
- Per-task routing: `task="code"` prefers Groq Llama-3.3-70B; `task="quick"` prefers Cerebras;
  `task="chinese"` prefers Qwen via SiliconFlow; etc.
- Auto-fallback means a rate-limit on one provider doesn't block the pipeline.
- Single file, stdlib-only. Drop into any project.

## Setup

```bash
cp .env.example ~/.ai_gateway.env
# fill in whatever keys you have — missing ones are skipped
```

## Use

```bash
python ai_gateway.py --probe                # which providers work?
python ai_gateway.py --list                 # which are configured?
python ai_gateway.py "ping" --task quick
python ai_gateway.py "写一个塔防英雄技能" --task chinese
```

```python
from ai_gateway import chat
code = chat("Write a Godot 4 GDScript signal example", task="code")
```

## Supported providers (verified 2026-04)

| Provider | Free tier | Best for | Key env |
|---|---|---|---|
| **Groq** | Generous rate limit | `code`, `quick` (fastest inference) | `GROQ_API_KEY` |
| **Cerebras** | Free tier | `quick` (very fast) | `CEREBRAS_API_KEY` |
| **SiliconFlow** | Free models marked | `chinese`, `design`, DeepSeek-V3 | `SILICONFLOW_API_KEY` |
| **Mistral** | Free tier | `design`, general chat | `MISTRAL_API_KEY` |
| **GitHub Models** | Free via GitHub | `design`, `code` (gpt-4o-mini, etc) | `GITHUB_MODELS_TOKEN` |

## License

MIT.
