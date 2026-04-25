Task #24: Produce docs/I18N_COVERAGE_AUDIT.md — exhaustive cross-reference of every `I18n.t("KEY")` call site against the 4 shipped language packs.

Background: `CLAUDE.md` § 多语言 mandates that all user-visible text go through `I18n.t("KEY")` or `I18n.t("KEY", [args])`, with translations in `lang/en.json`, `lang/zh_CN.json`, `lang/ja.json`, `lang/ko.json`. Any orphan `I18n.t` call without a key in all 4 files produces a fallback string that ships as raw `KEY_NAME`, breaking localization. This task finds every gap.

Procedure:
1. Enumerate language packs: list every file matching `lang/*.json`. Confirm the 4 expected languages are present. Note any extras or missing.
2. For each language pack, load it as JSON and extract the full set of keys.
3. Grep the repo for every `I18n.t("...")` or `I18n.t('...')` call (include both quote styles, both in `.gd` files and `.tscn` files). Deduplicate by key.
4. Grep for `I18n.t_args(...)` or any other I18n variant if the project uses one.
5. Cross-reference:
   - **Keys called but missing in pack(s)** — for each language pack, list every called key that has no entry
   - **Keys defined but never called** — list keys present in any language pack that no call-site references (dead strings; lower priority)
   - **Keys in some but not all packs** — list keys that exist in 2/4 languages but are missing in the other 2 (incomplete localization)
6. Produce `docs/I18N_COVERAGE_AUDIT.md` with:
   - **§1. Pack inventory** — languages found, key counts per pack
   - **§2. Missing translations (by language)** — one sub-section per language. Each lists keys that are called but absent. Sort by frequency of call site (most-common first — these are the biggest UX impact).
   - **§3. Orphan keys (defined but never called)** — can be deleted at release-time cleanup. Mark as low priority.
   - **§4. Incomplete localization (some languages but not all)** — these are the "half-translated" gaps.
   - **§5. Summary table** — for each of the 4 languages: keys defined / keys called / keys missing / coverage %.
   - **§6. Top 10 gaps ranked by impact** — keys with the most call-site references that are missing in ≥1 language. These are what to fix first.
   - **§7. Methodology notes** — what grep patterns you used, any edge cases (dynamic key construction like `I18n.t("WAVE_" + str(n))`) that evade static analysis.

Constraints:
- Do NOT add, remove, or rename any key in any language pack.
- Do NOT create or edit any `.gd` / `.tscn` file.
- If a call-site uses a dynamic key (constructed at runtime via `str()` / concatenation), call it out in §7 — these cannot be statically audited and should be flagged for manual review.
- Be conservative about false positives: a grep match inside a comment or string literal that isn't actually called is not a real call — mention the ambiguity if you can't disambiguate reliably.

Rules:
- No git, no code/data changes.
- Single window, no `[ROTATE]`.
- Emit `[DONE]` when saved.

Deliverable: `docs/I18N_COVERAGE_AUDIT.md`
