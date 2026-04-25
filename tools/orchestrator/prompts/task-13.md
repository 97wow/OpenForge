Task #13: Expand rogue_survivor sets from 14 to 30 by implementing the 16 planned sets listed in docs/GAME_DESIGN_PLAN.md §2.4.

New sets to add (preserving the existing rarity structure blue=2cards/purple=3cards/orange=4cards/final=5cards):
- 蓝: 治愈者, 追踪者, 召唤师, 弱点猎手
- 紫: 影刃, 炼金师, 战争机器, 灵魂收割, 冰火双重, 血月
- 橙: 命运之轮, 虚空行者, 龙之力, 永恒
- 橙(终极 5 张): 创世, 毁灭

For each new set:
1. Add set definition to gamepacks/rogue_survivor/theme_bonds.json (follow existing schema exactly — read it first, do not invent fields).
2. Add the needed card-level spell JSONs to gamepacks/rogue_survivor/spells/ (each spell follows the existing framework conventions from CLAUDE.md — NO hardcoded chain/AOE caps, use existing SpellSystem Effect/Aura/Proc framework).
3. Add i18n keys to gamepacks/rogue_survivor/data/spells_en.json, spells_zh_CN.json, spells_ja.json, spells_ko.json (all four language packs must stay in sync).

HARD CONSTRAINTS (violating any = failure):
- No duplicate spell IDs. Grep existing first.
- Respect CHAIN/AOE framework-level caps (max_targets ≤ 10, minimum cooldown 0.5s on all procs).
- Single path only — do not re-implement an effect both in JSON and in a .gd file.
- Balance must fit the existing BALANCE_SHEET.md power curves (read it first).
- Emit [ROTATE] after every 4 sets are committed to keep per-window context sane.
- Emit [DONE] when all 16 sets are added AND all four spell_*.json language packs are updated AND the single-file rule (<500 lines) still holds on theme_bonds.json.
