# I18n Coverage Audit

_Generated 2026-04-25 — static scan of `I18n.t("KEY")` call sites cross-referenced against `lang/*.json` packs._

> **Scope.** Read-only audit. No language packs, `.gd`, or `.tscn` files were modified. Source of truth: the working tree at the time of the run.

## §1. Pack inventory

Files matched by `lang/*.json`:

| File | `locale` | `name` | `version` | Keys (under `strings`) |
|------|----------|--------|-----------|-----------------------|
| `lang/en.json` | `en` | `English` | `1.0.0` | **907** |
| `lang/zh_CN.json` | `zh_CN` | `简体中文` | `1.0.0` | **907** |
| `lang/ja.json` | `ja` | `日本語` | `1.0.0` | **902** |
| `lang/ko.json` | `ko` | `한국어` | `1.0.0` | **902** |

All four expected packs are present. No extras, no missing locales.

**Per-pack key delta (relative to the union of all keys, 907):**
- `en` and `zh_CN` are the canonical packs; both contain 907 keys.
- `ja` and `ko` are missing **5** keys that exist in `en`/`zh_CN` (see §4).
- No language pack contains a key that is missing from `en` (i.e. there are no "foreign-only" keys).

## §2. Missing translations (statically-called keys missing from a pack)

**Headline result: zero misses.** Every key reached by a static `I18n.t("LITERAL")` call (153 unique keys, 199 total call sites) is present in all four language packs.

| Language | Keys defined | Static keys called | Missing | Coverage |
|----------|--------------|--------------------|---------|----------|
| `en` | 907 | 153 | **0** | 100.0% |
| `zh_CN` | 907 | 153 | **0** | 100.0% |
| `ja` | 902 | 153 | **0** | 100.0% |
| `ko` | 902 | 153 | **0** | 100.0% |

> ⚠️ This result only covers **string-literal** call sites. Dynamic call sites (`I18n.t(name_key)`, `I18n.t("PREFIX_" + var)`) cannot be statically resolved. See §6 and §7 — there are real ship-breaking gaps hiding in the dynamic call paths.

### 2.1  `en` — missing static keys
_None._

### 2.2  `zh_CN` — missing static keys
_None._

### 2.3  `ja` — missing static keys
_None._

### 2.4  `ko` — missing static keys
_None._

## §3. Orphan keys — defined but not statically called

There are **754 keys** defined in at least one language pack that are **never** referenced by a string-literal `I18n.t("KEY")` call. These split into two categories:

### 3.1  Used via dynamic JSON lookup (155 keys) — _DO NOT DELETE_
These keys are referenced by `name_key` / `desc_key` / `icon_key` / `stats_key` / `season_name_key` / `tr_key` fields inside gamepack JSON data files (e.g. `theme_bonds.json`, `relics/*.json`, `talents/*.json`, `quests/*.json`). They are loaded at runtime and passed to `I18n.t(var)`. Static grep cannot see them as call sites, but they **are** live strings.

Distribution by prefix:
| Prefix | Count |
|--------|-------|
| `REWARD_*` | 37 |
| `RELIC_*` | 24 |
| `BOND_*` | 20 |
| `AFFIX_*` | 16 |
| `SET_*` | 15 |
| `TALENT_*` | 14 |
| `CLASS_*` | 12 |
| `QUEST_*` | 9 |
| `BOSS_*` | 3 |
| `DRAW_*` | 1 |
| `BLINK_*` | 1 |
| `MAGE_*` | 1 |
| `RANGER_*` | 1 |
| `WARRIOR_*` | 1 |

### 3.2  Truly orphan (599 keys) — candidates for release-time cleanup (LOW priority)
These keys are present in language packs but have neither a static call site nor a JSON `*_key` reference. They may be:

- **Dynamically constructed at runtime** by GamePack code that builds the key from an `ability_name`, `aura_id`, `card_id`, etc. (most likely explanation for `ABILITY_*`, `AURA_*`, `CARD_*`).
- **Legacy strings** carried over from earlier versions of the game.
- **Pre-staged** for upcoming features that haven't shipped yet.

Distribution by prefix (top 30):
| Prefix | Count |
|--------|-------|
| `CARD_*` | 186 |
| `STAT_*` | 113 |
| `ABILITY_*` | 76 |
| `SET_*` | 45 |
| `ENTITY_*` | 17 |
| `FORGE_*` | 16 |
| `HUD_*` | 10 |
| `AURA_*` | 8 |
| `DIFF_*` | 7 |
| `POWER_*` | 6 |
| `MARTIAL_*` | 6 |
| `DMG_*` | 6 |
| `CHAKRA_*` | 6 |
| `EQUIP_*` | 6 |
| `LANG_*` | 4 |
| `TIER_*` | 4 |
| `BOND_*` | 3 |
| `TURRET_*` | 3 |
| `BOSS_*` | 3 |
| `DRAW_*` | 3 |
| `CHALLENGE_*` | 3 |
| `UPGRADE_*` | 3 |
| `TOWER_*` | 3 |
| `WEAPON_*` | 2 |
| `WAVE_*` | 2 |
| `SHIELD_*` | 2 |
| `WARRIOR_*` | 2 |
| `MAGE_*` | 2 |
| `DARK_*` | 2 |
| `FINAL_*` | 2 |

Concrete confirmed dynamic-construction sites (from §7) explain most of these:
- `I18n.t("AURA_" + aura)` at `gamepacks/rogue_survivor/scripts/rogue_combat_log.gd:429` → consumes all `AURA_*` orphans
- `I18n.t("SET_" + set_id.to_upper())` at `src/systems/item_system.gd:558` and `rogue_card_ui.gd:394, 564` → consumes `SET_*` orphans
- `I18n.t("CLASS_" + _gm._promoted_class.to_upper())` at `rogue_rewards.gd:324` → consumes `CLASS_*` orphans
- `combat_log` and `combat_text` paths likely build `ABILITY_*`/`STAT_*`/`DMG_*` keys from event payload — manual review required (see §7).

**Recommendation:** Do NOT bulk-delete §3.2 keys without first manually confirming each prefix family is unused. The risk of false-positive deletion is high.

## §4. Incomplete localization (defined in some langs, missing in others)

**5 keys** are present in `en` and `zh_CN` but absent from `ja` and `ko`. All five are `ABILITY_*` keys and are paired with currently-undefined twins (`ABILITY_SPLASH` is defined nowhere as `..._DESC`, etc.). They will fall back to the raw key string on Japanese/Korean clients if reached at runtime.

| Key | Present in | Missing in |
|-----|------------|------------|
| `ABILITY_BLACK_POWDER` | en, zh_CN | **ja, ko** |
| `ABILITY_CHAIN` | en, zh_CN | **ja, ko** |
| `ABILITY_IRON_AXE` | en, zh_CN | **ja, ko** |
| `ABILITY_MIDAS_TOUCH` | en, zh_CN | **ja, ko** |
| `ABILITY_SPLASH` | en, zh_CN | **ja, ko** |

> Note: these all live in §3.2 (truly orphan from a static-grep perspective). They are most likely surfaced via `I18n.t("ABILITY_" + ability_name.to_upper())` in the combat log path.

## §5. Summary table

| Language | Keys defined | Static keys called | Missing (static) | Coverage (static) | JSON-ref keys missing | Coverage (JSON-ref, 198) |
|----------|--------------|--------------------|------------------|-------------------|------------------------|---------------------------|
| `en` | 907 | 153 | 0 | 100.0% | 41 | 79.3% |
| `zh_CN` | 907 | 153 | 0 | 100.0% | 41 | 79.3% |
| `ja` | 902 | 153 | 0 | 100.0% | 41 | 79.3% |
| `ko` | 902 | 153 | 0 | 100.0% | 41 | 79.3% |

| Aggregate metric | Value |
|------------------|-------|
| Static `I18n.t("KEY")` call sites | 199 |
| Unique static keys referenced | 153 |
| Dynamic call sites (variable as 1st arg) | 68 |
| Dynamic call sites (string concatenation prefix) | 5 |
| Keys reachable via JSON `*_key` lookup | 198 |
| Total keys defined (union across all 4 packs) | 907 |
| Orphan keys (no static call, no JSON ref) | 599 |
| Orphan-but-JSON-referenced keys | 155 |
| **JSON-referenced keys totally undefined in all 4 packs** | **41** |
| Keys defined in only 2 of 4 langs (en+zh_CN) | 5 |

## §6. Top 10 gaps ranked by impact

**Impact ranking method:** since every static-call key is fully covered, the real impact is in the dynamic path. The keys below are referenced by gamepack JSON data files (loaded into UI at runtime), but are missing from **all four** language packs. They will render as raw `KEY_NAME` to every player on every locale.

| Rank | Key | Origin | Likely UX surface |
|------|-----|--------|-------------------|
| 1 | `ITEM_RUSTY_SWORD` | `./gamepacks/rogue_survivor/items/rusty_sword.json` | Equipment tooltip / inventory grid (visible on every loot pickup) |
| 2 | `ITEM_WOODEN_BOW` | `./gamepacks/rogue_survivor/items/wooden_bow.json` | Equipment tooltip / inventory grid (visible on every loot pickup) |
| 3 | `ITEM_CLOTH_ROBE` | `./gamepacks/rogue_survivor/items/cloth_robe.json` | Equipment tooltip / inventory grid (visible on every loot pickup) |
| 4 | `ITEM_LEATHER_VEST` | `./gamepacks/rogue_survivor/items/leather_vest.json` | Equipment tooltip / inventory grid (visible on every loot pickup) |
| 5 | `ITEM_STORMCALLER_BOW` | `./gamepacks/rogue_survivor/items/stormcaller_bow.json` | Equipment tooltip / inventory grid (visible on every loot pickup) |
| 6 | `ITEM_DRAGONFIRE_SWORD` | `./gamepacks/rogue_survivor/items/dragonfire_sword.json` | Equipment tooltip / inventory grid (visible on every loot pickup) |
| 7 | `ITEM_APPRENTICE_STAFF` | `./gamepacks/rogue_survivor/items/apprentice_staff.json` | Equipment tooltip / inventory grid (visible on every loot pickup) |
| 8 | `ITEM_CROWN_OF_TIME` | `./gamepacks/rogue_survivor/items/crown_of_time.json` | Equipment tooltip / inventory grid (visible on every loot pickup) |
| 9 | `ITEM_AEGIS_OF_LIGHT` | `./gamepacks/rogue_survivor/items/aegis_of_light.json` | Equipment tooltip / inventory grid (visible on every loot pickup) |
| 10 | `ITEM_LIFE_RING` | `./gamepacks/rogue_survivor/items/life_ring.json` | Equipment tooltip / inventory grid (visible on every loot pickup) |

**Why these are the worst offenders:**
- `ITEM_*` (24 keys total) are referenced by every equipment JSON in `gamepacks/rogue_survivor/items/`. Each one is shown to the player as soon as the corresponding item drops. **Every locale, including `en`, ships raw `ITEM_RUSTY_SWORD`-style strings.**
- `SET_*_DESC` (16 keys) and `SET_WEAKNESS_HUNTER` (1) come from `theme_bonds.json` `desc_key` / `name_key` fields. They surface in the theme-bond tooltip and the on-screen activation banner.
- These are **not** "missing translations" — they are **missing in all four packs**. Adding them once to `en.json` will at least give an English fallback for all locales (assuming `I18nManager` falls back to `en` when the active locale is missing a key — verify).

**Secondary tier (lower-impact, locale-asymmetric gaps):** the 5 `ABILITY_*` keys from §4, missing in `ja`/`ko`. These only fire when the corresponding ability is actually cast in a run, and the combat log will fall back to the raw key on those locales.

## §7. Methodology notes

### Pack loading
Each `lang/*.json` is parsed as JSON; the actual translation table lives under the top-level `"strings"` object (alongside `locale`, `name`, `version` metadata). The audit reads from `data["strings"]`, not the top level.

### Static call-site extraction
Walked `src/**/*.{gd,tscn}` and `gamepacks/**/*.{gd,tscn}`. Skipped lines whose first non-whitespace char is `#` (whole-line comments). For each remaining line, applied:
```python
# Static literal — must be a complete key (closing quote followed by ',' or ')')
strict_pat = re.compile(r'''I18n\.t(?:_args)?\(\s*(["'])([A-Za-z0-9_]+)\1\s*[,)]''')

# Concatenated literal prefix — counted as DYNAMIC, not static
concat_pat = re.compile(r'''I18n\.t(?:_args)?\(\s*(["'])([A-Za-z0-9_]*)\1\s*\+''')

# Bare variable as first arg — counted as DYNAMIC
dynamic_var_pat = re.compile(r'''I18n\.t(?:_args)?\(\s*(?!["'])[A-Za-z_]''')
```
This includes `I18n.t_args(...)` since it accepts the same key-as-first-arg shape. No other I18n entrypoint variants exist (verified: only `I18n.t` and `I18n.t_args` are referenced anywhere in the tree).

**`.tscn` files contain zero `I18n.` references** — translations are applied in `_ready()` per the project's I18n contract (see `CLAUDE.md` § 多语言), so `.tscn` extraction was empty.

### Dynamic call sites — flagged for manual review (cannot be statically audited)

**5 string-prefix concatenations:**
| Site | Prefix | Source variable |
|------|--------|-----------------|
| `src/systems/item_system.gd:558` | `SET_` | `set_id.to_upper()` |
| `gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:394` | `SET_` | `set_id.to_upper()` |
| `gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:564` | `SET_` | `set_id.to_upper()` |
| `gamepacks/rogue_survivor/scripts/rogue_rewards.gd:324` | `CLASS_` | `_gm._promoted_class.to_upper()` |
| `gamepacks/rogue_survivor/scripts/rogue_combat_log.gd:429` | `AURA_` | `aura` |

**68 variable-arg call sites** (sampled) include patterns like:
- `I18n.t(season_name_key)` — `name_key` value comes from a season JSON.
- `I18n.t(cls["name_key"])`, `I18n.t(cls["desc_key"])`, `I18n.t(cls["stats_key"])`, `I18n.t(cls["icon_key"])` — character-select class metadata.
- `I18n.t(diff["desc_key"])` — difficulty option metadata.
- `I18n.t(relic.get("name_key", ""))`, `I18n.t(relic.get("desc_key", ""))` — relic metadata.
- `I18n.t(tdata.get("name_key", tid))`, `I18n.t(tdata.get("desc_key", ""))` — talent metadata.
- `I18n.t(name_key)` in the battle-pass and reward UI.

To resolve these, the audit walks every JSON file outside `lang/` and `.git/`, recursively visits all string values whose **parent dict key** ends with `_key` (or matches one of `name_key`, `desc_key`, `icon_key`, `stats_key`, `tr_key`, `season_name_key`). The collected values are treated as runtime-reachable I18n keys.

This recovers **198 additional keys** (visible in §6) but is still imperfect:
- It cannot see keys built from non-`*_key` fields (e.g. `ability_name` strings used by `combat_log.gd` to build `"ABILITY_" + ability_name.to_upper()`).
- It cannot see keys built from raw enum values (e.g. damage school → `"DMG_" + school.to_upper()`).
- It assumes JSON values that look like SHOUT_CASE identifiers are i18n keys, even if they are also valid as raw display strings.

**Implication:** the 599 "truly orphan" keys in §3.2 include both dead strings and live strings reached via these untraceable paths. A clean release-time cleanup pass should:
1. Audit each prefix family (`ABILITY_*`, `STAT_*`, `CARD_*`, `DMG_*`, `CHAKRA_*`, `MARTIAL_*`, etc.) by manually reading the GDScript that consumes those event payloads.
2. Only delete keys whose family is confirmed unused.
3. Prefer `grep -r '"PREFIX_'` against the entire repo (including `.json` data files) before any deletion.

### False-positive discipline
- Whole-line `#` comments are skipped, but inline comments (e.g. `var x = I18n.t("FOO") # legacy`) are NOT skipped — the call still counts. This is intentional: those lines compile and execute.
- The `CLAUDE.md` and `docs/*.md` files contain the literal string `I18n.t("KEY")` as documentation. Those matches are **excluded** by the file-walker (only `.gd` and `.tscn` are scanned).
- The `tools/orchestrator/prompts/task-*.md` files also mention `I18n.t(...)` in prompt text and are likewise excluded.
- A line like `if name_key != "" and I18n` is correctly NOT counted as a call (no `I18n.t(`).

### What the audit **does not** cover
- Plural / gender variants (no evidence the project uses them).
- Format-string argument count mismatches (e.g. `I18n.t("X", [a, b])` vs. `"X": "{0}"` — only one slot in the template). A separate audit could compare `{N}` token counts in pack values against arg-list lengths at call sites.
- Runtime-downloaded language packs (per `CLAUDE.md`, packs may be fetched at runtime; only the four shipped packs are audited).
- The `name`/`locale`/`version` metadata fields — only the `strings` table is compared.