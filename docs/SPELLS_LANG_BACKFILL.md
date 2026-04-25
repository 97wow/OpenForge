# Spells Lang Backfill — Wave A bond display entries (Task #28)

> Date: 2026-04-25
> Source: Task #28 (closes the display-layer gap left by Task #27)
> Files modified: `gamepacks/rogue_survivor/data/spells_{en,zh_CN,ja,ko}.json` (4 files, append-only)
> Files NOT touched: `lang/*.json`, `gamepacks/rogue_survivor/data/spells.json`

This task adds player-visible name + description strings for the 6 Wave A bond ids (90, 91, 93, 96, 97, 99) to all 4 per-language `spells_<lang>.json` files. Without these, the live bond-display path (`rogue_card_system.gd:818 get_spell_name` → `_spell_locale[<id>]`) would fall back to rendering the raw bond id (`"90"`, `"91"`, …) since the previous last-known id in each file was `"89"`.

---

## §1. Entries added

24 rows total — 6 ids × 4 files. All entries are **appended** at the end of each file (no existing entry was modified).

| File | id | name | desc |
|---|---|---|---|
| spells_en.json | 90 | Healer | Healer set: kill heal + periodic shield |
| spells_en.json | 91 | Tracker | Tracker set: extra range + homing projectiles |
| spells_en.json | 93 | Weakness Hunter | Weakness Hunter set: mark debuff amplifies damage |
| spells_en.json | 96 | War Machine | War Machine set: knockback + armor shred + AOE |
| spells_en.json | 97 | Soul Harvest | Soul Harvest set: kill stacks + soul shockwave |
| spells_en.json | 99 | Blood Moon | Blood Moon set: low-HP damage + attack speed + invincibility |
| spells_zh_CN.json | 90 | 治愈者 | 治愈者卡组：击杀回血+周期性护盾 |
| spells_zh_CN.json | 91 | 追踪者 | 追踪者卡组：攻击范围+追踪弹道 |
| spells_zh_CN.json | 93 | 弱点猎手 | 弱点猎手卡组：标记敌人放大伤害 |
| spells_zh_CN.json | 96 | 战争机器 | 战争机器卡组：击退+破甲+范围伤害 |
| spells_zh_CN.json | 97 | 灵魂收割 | 灵魂收割卡组：击杀叠加+灵魂震波 |
| spells_zh_CN.json | 99 | 血月 | 血月卡组：低血伤害+攻速+无敌 |
| spells_ja.json | 90 | Healer ⚠ | Healer set: kill heal + periodic shield ⚠ |
| spells_ja.json | 91 | Tracker ⚠ | Tracker set: extra range + homing projectiles ⚠ |
| spells_ja.json | 93 | Weakness Hunter ⚠ | Weakness Hunter set: mark debuff amplifies damage ⚠ |
| spells_ja.json | 96 | War Machine ⚠ | War Machine set: knockback + armor shred + AOE ⚠ |
| spells_ja.json | 97 | Soul Harvest ⚠ | Soul Harvest set: kill stacks + soul shockwave ⚠ |
| spells_ja.json | 99 | Blood Moon ⚠ | Blood Moon set: low-HP damage + attack speed + invincibility ⚠ |
| spells_ko.json | 90 | Healer ⚠ | Healer set: kill heal + periodic shield ⚠ |
| spells_ko.json | 91 | Tracker ⚠ | Tracker set: extra range + homing projectiles ⚠ |
| spells_ko.json | 93 | Weakness Hunter ⚠ | Weakness Hunter set: mark debuff amplifies damage ⚠ |
| spells_ko.json | 96 | War Machine ⚠ | War Machine set: knockback + armor shred + AOE ⚠ |
| spells_ko.json | 97 | Soul Harvest ⚠ | Soul Harvest set: kill stacks + soul shockwave ⚠ |
| spells_ko.json | 99 | Blood Moon ⚠ | Blood Moon set: low-HP damage + attack speed + invincibility ⚠ |

⚠ = English fallback — see §2.

EN strings derive from `docs/SETS_EXPANSION_PROPOSAL.md` §1, §2, §4, §7, §8, §10 (set names are taken verbatim from each section's title; `desc` is a one-line summary of that section's "Existing blueprint" effect bullets, kept terse to match the existing pattern in the file: e.g. id `89` → `"League of Heroes" / "Hero legend set"`).

CN strings derive from the same proposal sections' Chinese set titles + a one-line CN summary of the blueprint's effects.

---

## §2. Translation fallback notes

`docs/SETS_EXPANSION_PROPOSAL.md` provides EN + CN per set, but **does not** provide JA or KO translations. Per the task procedure (step 2c, "if the proposal doesn't give translations, copy the EN variant — this is honest, a later translation pass can refine, but the keys must not be absent"), all 12 ja/ko entries (6 ids × 2 langs) are intentional EN-fallback placeholders.

**Files affected:** `spells_ja.json`, `spells_ko.json`
**Ids affected:** 90, 91, 93, 96, 97, 99 in each file
**Total fallback strings:** 24 (12 names + 12 descs) — every name and desc on the ja/ko rows of the §1 table.

These are **not bugs**. They are honest placeholders that:
- keep the UI from rendering raw bond ids,
- give a translator concrete reference text (the EN copy) to localize from in a follow-up pass,
- are flagged with ⚠ in §1 so review tooling can grep for them.

A follow-up i18n task should replace these 24 strings with real JA/KO translations. The same task should also retire the broader `lang/<code>.json` debt flagged in `docs/SETS_WAVE_A_APPLIED.md` §3 (1 missing `SET_WEAKNESS_HUNTER` name key + 6 missing `SET_*_DESC` desc keys, ×4 languages = 28 missing lang keys).

No schema surprises were encountered. All 4 files use the same structure (`{"<id>": {"name": "...", "desc": "..."}}`, 4-space indent, `"89"` as last existing entry) and all 4 were processed.

---

## §3. Validation output

**Parse-checks (step 2d):**

```
$ for f in gamepacks/rogue_survivor/data/spells_en.json gamepacks/rogue_survivor/data/spells_zh_CN.json gamepacks/rogue_survivor/data/spells_ja.json gamepacks/rogue_survivor/data/spells_ko.json; do python3 -c "import json; d = json.load(open('$f')); print('$f', len(d), 'entries')"; done
gamepacks/rogue_survivor/data/spells_en.json 76 entries
gamepacks/rogue_survivor/data/spells_zh_CN.json 76 entries
gamepacks/rogue_survivor/data/spells_ja.json 76 entries
gamepacks/rogue_survivor/data/spells_ko.json 76 entries
```

Each file was 70 entries before this task (verified visually pre-edit: ids end at `"89"`). Each is now 76 — exactly +6, matching the 6 appended bonds. ✓

**Cross-check grep (step 3):**

```
$ grep '"90"\|"91"\|"93"\|"96"\|"97"\|"99"' gamepacks/rogue_survivor/data/spells_en.json gamepacks/rogue_survivor/data/spells_zh_CN.json gamepacks/rogue_survivor/data/spells_ja.json gamepacks/rogue_survivor/data/spells_ko.json | wc -l
24
```

Expected 24 (6 ids × 4 files). Got 24. ✓

**Source-of-truth cross-check** (`data/spells.json` confirms the 6 ids exist as `type: bond` with the expected subclasses, so the new display strings will actually be looked up at runtime):

```
$ python3 -c "import json; d = json.load(open('gamepacks/rogue_survivor/data/spells.json')); [print(k, '->', d[k].get('type'), d[k].get('subclass')) for k in ['90','91','93','96','97','99']]"
90 -> bond healer
91 -> bond tracker
93 -> bond weakness_hunter
96 -> bond war_machine
97 -> bond soul_harvest
99 -> bond blood_moon
```

---

## §4. Rollback snippet

```bash
git checkout -- \
  gamepacks/rogue_survivor/data/spells_en.json \
  gamepacks/rogue_survivor/data/spells_zh_CN.json \
  gamepacks/rogue_survivor/data/spells_ja.json \
  gamepacks/rogue_survivor/data/spells_ko.json

# Plus the new doc:
rm docs/SPELLS_LANG_BACKFILL.md
```

`data/spells.json` and `lang/*.json` are not in the rollback set because they were not modified by this task.

---

## §5. What still requires a code change (reminder)

The numeric-id lookup path is now unblocked — the display call site at `gamepacks/rogue_survivor/scripts/rogue_card_system.gd:818 get_spell_name` (and the matching `get_spell_desc:825`) reads `_spell_locale[<id>]`, which is loaded from the per-language `spells_<lang>.json` files. With this task's edits, `get_spell_name("90")` etc. now return the appended strings instead of the raw id. **No code change is needed for this path to work.**

**However**, a parallel display surface uses the `name_key` / `desc_key` fields on the `bond` records in `data/spells.json` directly, bypassing the numeric-id lookup. Confirmed by grep:

- `gamepacks/rogue_survivor/scripts/rogue_theme_bond.gd:105` — `name_text = I18n.t(bond.get("name_key", ""))` — theme-bond panel reads `name_key` from the bond record and resolves via `I18n.t()`. For these new bonds that means `SET_HEALER`, `SET_TRACKER`, `SET_WEAKNESS_HUNTER`, `SET_WAR_MACHINE`, `SET_SOUL_HARVEST`, `SET_BLOOD_MOON` (name) plus the matching `_DESC` keys.
- `gamepacks/rogue_survivor/scripts/rogue_tooltip.gd:161,173,197,333,398,404` — card and bond tooltips read `name_key` / `desc_key` and run `I18n.t()` on them. Falls back to the raw `held[slot_idx]` string when missing, which won't crash but will render unstyled.
- `gamepacks/rogue_survivor/scripts/rogue_card_ui.gd:84,94,302,396,466,493,566` — draft and held-card UIs read `name_key` / `desc_key` similarly.

**i18n debt that this task does NOT close** (per `docs/SETS_WAVE_A_APPLIED.md` §3, verbatim — re-flagged here so it's not lost):

- `SET_WEAKNESS_HUNTER` — **missing in all 4 `lang/*.json` packs.** Theme-bond panel will render the raw key string `"SET_WEAKNESS_HUNTER"` for bond #93.
- All 6 `SET_*_DESC` keys (`SET_HEALER_DESC`, `SET_TRACKER_DESC`, `SET_WEAKNESS_HUNTER_DESC`, `SET_WAR_MACHINE_DESC`, `SET_SOUL_HARVEST_DESC`, `SET_BLOOD_MOON_DESC`) — **missing in all 4 `lang/*.json` packs.** Theme-bond panel desc text will render as raw `_DESC` key strings.

Total still-missing: 1 name key + 6 desc keys = **7 keys × 4 langs = 28 string additions** in `lang/*.json` to fully retire the i18n debt for Wave A.

**Recommendation for the follow-up task:** add the 28 missing `SET_*` / `SET_*_DESC` entries to `lang/en.json`, `lang/zh_CN.json`, `lang/ja.json`, `lang/ko.json`. CN copy can be sourced verbatim from the proposal sections; EN copy from same; ja/ko need the same translator-pass treatment described in §2 here.

**No code change is required.** The current GDScript code paths are correct and read from the right places — the only outstanding work is data (string keys in lang packs).
