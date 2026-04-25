# Steam Store Page Draft — OpenForge: 不思议求生 (Rogue Survivor)

> Ground truth: `docs/GAME_DESIGN_PLAN.md` + `docs/ROGUE_SURVIVOR_GAPS.md` (2026-04-24).
> No features outside the design plan have been invented.

---

## 1. Short Description

### EN (≤300 chars)
Roguelike deckbuilder meets survivor tower-defense. Every run you draft from 52 cards 3-at-a-time, snap together 14 set-bonus builds, and climb Lv.1–Lv.20 with a Lv.5 job-change. Ten difficulties (N1–N10), a 10-minute final boss, then endless. Free to play, never pay-to-win. *(275 chars)*

### CN 简短简介 (≤300 字符)
肉鸽构筑 × 求生塔防。每局从 52 张卡池随机 3 选 1 抽卡，拼出 14 套羁绊构筑；1–20 级成长、5 级转职、六系伤害与装备词条让每条 Build 都不同。N1–N10 十档难度，两分钟 BOSS、十分钟终极 BOSS，之后进入无尽爬塔。四语言原生支持，免费畅玩，绝不卖数值。*(约 144 字符)*

---

## 2. Long Description

### EN

**One run, a hundred builds.** *Rogue Survivor* is a roguelike deckbuilder wrapped around a survivor-style tower-defense loop. Enemies pour in every seven seconds, elites arrive with randomized affix-words, and a boss lands every two minutes — all the way to a ten-minute final encounter. Between waves, you pick one of three cards: rarity colors show the risk, set-bonus tags show the payoff. Snap a full set and a brand-new behavior unlocks — chain-lightning that bounces, crit stacks that keep climbing, a reaper that collects souls on every kill.

**Depth where it matters.** Choose one of three classes — Warrior, Mage, or Ranger — and commit to a job-change at Level 5 that rewrites how your kit scales. Six damage schools (Physical, Frost, Fire, Nature, Shadow, Holy) each interact with enemy resistances, elite affixes, and proc triggers. Equipment drops from loot tables, talent points go into a tree you can reset for free, and ten difficulty tiers (N1–N10) re-scale enemy density, boss mechanics, and reward quality.

**Built on a modern engine, with Warcraft-3 RPG DNA.** OpenForge is a data-driven RPG-map framework inspired by the custom-map platforms that 20 years of fantasy-RPG players grew up on — rebuilt on Godot 4.6 with a spell/aura/proc architecture borrowed from open-source MMORPG servers. Every card, set, aura, and boss script is a JSON file, which means balance patches ship fast and the modding door is wide open.

**Global from day one.** Native English, 简体中文, 日本語, 한국어. No pay-to-win: an optional small seasonal cosmetic pass offers cosmetics, XP-curve boosts, and seasonal relics — every stat-relevant item is earned in-run. If you like Brotato's 20-minute arcs, Vampire Survivors' muscle-memory dodging, or the deep synergy-hunting of modern deckbuilders, this sits at that intersection.

### CN 详细介绍

**一局游戏，百种 Build。** 《不思议求生》是一款肉鸽构筑 × 求生塔防。敌人每 7 秒一波涌来，精英怪每 5 波带来随机词缀，每 2 分钟刷一波 BOSS，直到第 10 分钟的终极 BOSS。波次间 3 选 1 抽卡：颜色代表稀有度，标签代表羁绊套装。凑齐一套，技能会"活"过来 ——闪电链开始弹射、暴击成长永不封顶、死神在每次击杀时收割灵魂。

**该有深度的地方不缺。** 三个初始职业（战士 / 法师 / 游侠）、5 级转职定义中后期走向；六系伤害（物理 / 冰 / 火 / 自然 / 暗影 / 神圣）与敌人抗性、精英词缀、触发效果全部互动。装备词条掉落、天赋树自由重置，N1–N10 十档难度重塑敌人密度、BOSS 机制与掉落品质。

**现代引擎，魔兽 3 自定义地图的基因。** OpenForge 是一个数据驱动的 RPG 地图框架 —— 承接"二十年来玩家在 War3 自定义地图平台上长大的那份乐趣"，在 Godot 4.6 上重写 Spell / Aura / Proc 架构（设计灵感来自主流开源 MMORPG 服务端）。每张卡、每套羁绊、每个 BOSS 脚本都是 JSON 文件，平衡更新上线快、Mod 大门是开的。

**从第一天起就面向全球。** 原生支持英文、简体中文、日本语、한국어。绝不卖数值：可选的小额赛季外观通行证只卖外观 / 经验加速 / 限定遗物 —— 所有影响数值的道具都从对局中获取。如果你喜欢《土豆兄弟》的 20 分钟刺激、《吸血鬼幸存者》的肌肉记忆走位，或现代卡组构筑类的深度连携 —— 这款游戏正好站在三者的交叉点上。

---

## 3. Feature Bullets (EN + CN)

1. **EN** — *14 Set-Bonus Archetypes (in-game: 羁绊 / bond), 52 Cards Drafted 3-at-a-Time.* Every pick matters: rarity pushes power, sets push identity. From Piercer and Frost to Reaper, Stormcaller, and Time Lord, no two runs build the same. Plus 26 cross-set theme bonds layered on top.
   **CN** — **14 套羁绊（游戏内：羁绊 / bond）、52 张卡、3 选 1 抽取**。稀有度决定强度，羁绊决定身份。分裂者 / 寒冰 / 死神 / 风暴使者 / 时间领主……每局 Build 各不相同。另有 26 条跨套主题羁绊叠加其上。

2. **EN** — *Three Classes, One Job Change, Twenty Levels.* Warrior / Mage / Ranger each scale through their own attack profile; at Lv.5 you commit to a specialization that rewrites mid- and late-game kit interactions.
   **CN** — **三职业、一次转职、二十等级**。战士 / 法师 / 游侠各有攻击节奏；5 级转职改写中后期技能联动。

3. **EN** — *Ten Difficulties, a 10-Minute Final Boss, and Uncapped Endless.* N1 is a cozy power-fantasy; N10 is a meat grinder. Kill the final boss and the tower of endless waves opens up.
   **CN** — **N1–N10 十档难度 + 十分钟终极 BOSS + 无尽爬塔**。N1 轻松爽快、N10 绞肉机。终极 BOSS 倒下后开启无限模式。

4. **EN** — *Six Damage Schools, Elite Affix Words, Equipment Loot Tables.* Physical / Frost / Fire / Nature / Shadow / Holy all interact with resistances, elite-mob affix words, equipment prefixes, and proc chains — your build is a web, not a list.
   **CN** — **六系伤害 × 精英词缀 × 装备词条**。六系伤害与敌人抗性、精英词缀、装备前缀、触发链条彼此作用 —— Build 是一张网，不是一个清单。

5. **EN** — *Data-Driven, Moddable, Global from Day One.* Built on OpenForge (Godot 4.6 + JSON-first spell framework). Native English / 简体中文 / 日本語 / 한국어. The same engine is the basis for future community-authored RPG maps.
   **CN** — **数据驱动、Mod 友好、首日四语言**。基于 OpenForge（Godot 4.6 + JSON 驱动技能框架），原生支持 EN / 简中 / 日 / 韩。同一引擎也是未来社区自制 RPG 地图的底座。

---

## 4. Proposed Steam Tags (8–10, Ranked)

Ranking priority = expected Steam discoverability lift × honest fit with shipped features.

1. **Roguelike** — core loop is randomized draft + permadeath run.
2. **Deckbuilder** — 3-pick card drafting with 14 set bonuses is the headline mechanic.
3. **Survivors-like** — explicit design target per §2.1 of GAME_DESIGN_PLAN ("roguelike × card construction × tower defense × RPG growth").
4. **Bullet Heaven** — high enemy density, projectile-thick combat, minute-scaled runs.
5. **Roguelite** — permanent talent tree + equipment collection persist between runs.
6. **Action Roguelike** — real-time WASD + auto-attack combat, not turn-based.
7. **Tower Defense** — §2.1 explicitly lists tower-defense strategy as a pillar.
8. **Character Customization** — class × job-change × equipment × talents.
9. **Free to Play** — F2P on Steam per §6.3 ("基础游戏免费").
10. **Replay Value** — randomized draft + 10 difficulty tiers + endless mode.

Cut candidates: *Co-Op* (NetworkSystem exists in framework, but multiplayer is not in the shipping scope of this gamepack — do NOT tag). *Open World*, *Story Rich* — do not fit.

---

## 5. Capsule-Art Image Prompts (FLUX / Midjourney)

**Context brief for the artist / prompt engineer:**
Visual heritage is the *War3 custom-map RPG platform* lineage (think: the pre-game load screen of a hand-crafted fantasy map from a custom-map launcher) reimagined through the clean, readable low-poly vocabulary of **Brotato**, **Thronefall**, and **Rogue Tower**. No Warcraft IP — no specific paladin/horde iconography, no Frostmourne, no lich-king silhouettes. Keep heroes generic fantasy: barbarian, knight, hooded mage, hooded rogue (matches shipped Synty-style GLB assets per ROGUE_SURVIVOR_GAPS §1.1). Palette: deep-purple dusk, warm torchlight amber, arcane-cyan rim light, blood-red accent on enemy swarm. Composition: single readable hero silhouette vs. an enemy horde at middle distance, with three floating draft cards as a motif.

### Grand Key Art / Store Page Hero (5 candidates)

1. Low-poly fantasy key-art, lone barbarian hero back-to-camera standing on a stone dais under a dusk sky of purple and amber; a tide of tiny skeletal enemies surges up the valley below him; three ornate tarot-sized cards hover mid-air above his shoulder, faintly glowing cyan, rune-etched backs; volumetric torchlight, clean Thronefall/Rogue Tower silhouettes, readable at thumbnail size, no text, 16:9.

2. Wide epic key-art, isometric-tilted fantasy arena at night, hooded mage at center casting a cone of arcane cyan energy into a circular swarm of low-poly skeletons; three floating cards — Frost, Fire, Reaper — arranged like a fan at the upper left; warm orange campfire glow at the mage's feet, purple sky, painterly low-poly, inspired by Brotato-meets-Thronefall framing, 16:9, no UI.

3. Heroic portrait-scene key-art, three classes — barbarian, knight, hooded rogue — standing shoulder-to-shoulder on a cobblestone platform, silhouettes rim-lit in arcane cyan, an incoming wave of red-eyed enemies on the horizon; one glowing card mid-draft rotates between them, runes drifting off it like embers; Rogue Tower-style clean low-poly, dusk palette, 16:9.

4. Dynamic action key-art, hooded ranger mid-draw, low-poly arrow leaving the string, trailing cyan sparks; enemy horde frozen mid-charge in a grid formation like a tower-defense approach lane; three cards hover above the camera foreground, slightly tilted, backs to viewer; volumetric fog, amber torch markers lining the path, Brotato-like readable chunk-forms, 16:9.

5. Vertical grand-portrait key-art, camera looking up past a barbarian hero on a broken castle parapet into a sky that splits into six colored shards (one per damage school: white, blue, orange, green, purple, gold); behind him on the ground, a dense swarm of low-poly skeletons held back by an arcane circle; three tarot cards drift up toward the shards; painterly, 2:3, no text.

### Main Capsule 616×353 (4 candidates)

6. Mid-range capsule composition, barbarian hero center-left, three fan-spread glowing cards front-right occupying the lower third, a blurred enemy wave in the background under dusk-purple sky; strong silhouette readable at 231×87 thumbnail; leave a clean negative-space wedge at upper-left for the logo; low-poly Synty-adjacent shading, Thronefall color temperature, 616:353, no text.

7. Capsule composition with diagonal cut, left half a hooded mage casting arcane-cyan cone, right half a red-tinted enemy swarm approaching, a single card ("Set Bonus: Stormcaller" implied by lightning motif, no readable text) rotates on the split seam; clean low-poly, high silhouette contrast for thumbnail legibility, negative space at top for localized title, 616:353.

8. Two-character capsule, warrior foreground right holding greatsword low, hooded rogue mid-ground left nocking an arrow, swarm of low-poly skeletons rendered tiny in far background as a moving texture; three cards fan upward from between them like a burst of light; purple/amber/cyan palette, Rogue Tower cleanliness, 616:353, title-safe area upper left.

9. Weapon-forward capsule, bottom third is a row of iconic loot — sword, tome, longbow, relic — glowing with prefix-word runes; above, a distant silhouette trio of hero classes on a hilltop against a dusk sky; enemies as a red-dot horizon line; composition invites the eye from loot → heroes → horizon, 616:353, negative space at top-right.

### Small Capsule 462×174 (3 candidates)

10. Horizontal small-capsule, single barbarian hero silhouette left-third, three stacked cards diagonal center-right radiating cyan light, no background swarm (readability priority); flat saturated dusk-purple backdrop with one amber torch bloom; high-contrast silhouette survives at 184×69 scale; leave right third for title text overlay, 462:174.

11. Small-capsule tight portrait, hooded mage from chest-up turning toward camera, card back filling the right side as a design element (rune grid, no readable letters); limited palette — purple, amber, cyan — so logo legibility is guaranteed over it; Brotato-like chunky proportions, 462:174.

12. Small-capsule action-still, one enemy skeleton frozen mid-shatter as arcane-cyan shards explode outward, hero arm reaching in from left corner; dense dark background makes the shatter pop; title-safe zone across entire right half; 462:174, no text, low-poly Rogue Tower material feel.

### Header Capsule 460×215 (3 candidates)

13. Header capsule, cinematic cropped key-art: barbarian hero right-of-center on a stone dais, three cards fanning up behind his shoulder, small distant enemy swarm lower-left, dusk palette; logo-safe band left third; composition should also work cropped to 292×136 and 231×87 without losing the hero, 460:215.

14. Header capsule, flat heraldic composition — a large stylized playing-card motif center-frame (rune-etched, glowing cyan) with a tiny low-poly hero silhouette standing *inside* the card frame like a tarot figure; purple/amber background with floating ember particles; reads instantly as "deckbuilder + fantasy hero", 460:215.

15. Header capsule, action diagonal — camera sweeping low, hero class trio charging forward into a hazy red-tinted enemy line, motion blur on three falling cards at the upper-right corner; leave upper-left third clear for the logo; Thronefall-style readable silhouettes, 460:215.

### One-Paragraph Style Brief

Visual direction is **clean low-poly fantasy with a modern roguelike-deckbuilder overlay**: Synty-style hero silhouettes (matching the shipped Barbarian / Knight / Mage / Rogue GLB meshes) composed against Thronefall-grade dusk lighting and Rogue Tower-grade material simplicity, with Brotato's discipline of "one hero silhouette must read at 231×87." A purple-dusk + amber-torch + arcane-cyan + enemy-red palette anchors the brand across all capsule sizes. Three floating draft cards are the repeating graphic motif — they signal "deckbuilder" instantly on a store shelf where every other bullet-heaven cover is just a hero-plus-swarm. Explicitly off-limits: Warcraft iconography (Frostmourne, lich crowns, Horde/Alliance heraldry, Paladin-specific armor), realism-painted 2D fantasy art, and busy splash-art that collapses at thumbnail size.

---

## 6. Trailer Script Outline

### 60-Second Cut

| Time | Visual | Audio / Text |
|---|---|---|
| 0:00–0:03 | Black. A single card flips into frame, glowing cyan, and slams down. Three more follow, fan-spread. | BGM drop-in (low, pulsing). Text: *"One run."* |
| 0:03–0:10 | Quick cuts: barbarian charging, mage casting cone, ranger drawing bow; each kills one enemy with a different damage-school color (white / cyan / orange). | Whoosh / hit SFX. Text: *"Three classes."* |
| 0:10–0:20 | Gameplay montage: 3-pick card draft UI → set-bonus tooltip highlights → chain-lightning starts bouncing between mobs. | VO / onscreen: *"52 cards. 14 sets. Build anything."* |
| 0:20–0:30 | Wave counter ticks: Wave 3 → Wave 12 → Wave 27. Elite with golden affix-word banner appears. Boss drops from sky at 2:00 mark. | VO: *"Elite affix words. Bosses every two minutes."* |
| 0:30–0:42 | Lv.5 job-change screen blooms on — player picks a specialization, kit visibly rewrites (new particles, new projectile). Equipment drops. Talent tree flashes. | VO: *"Job-change at level five. Six damage schools. Ten difficulties."* |
| 0:42–0:52 | Final-boss silhouette fills screen at 10:00 mark, screen-wide AoE, hero dodges. Cut to endless-mode wave counter spinning past 50. | VO: *"Ten-minute final boss. Then endless."* |
| 0:52–0:58 | Language-tag montage: English / 简体中文 / 日本語 / 한국어 card-draft UI flashing in sequence. | VO: *"Four languages. Free to play. Never pay-to-win."* |
| 0:58–1:00 | Logo lock-up: **OpenForge: Rogue Survivor**. Steam "Wishlist Now" prompt. | Stinger hit. |

### 15-Second Cut (Social / TikTok / YouTube Pre-Roll)

| Time | Visual | Audio / Text |
|---|---|---|
| 0:00–0:02 | Black. Three cards flip and slam. | Stinger. Text: *"Draft."* |
| 0:02–0:06 | 2-second chain-lightning combo across a mob swarm; 2-second 100-crit number pops. | Text: *"Build."* |
| 0:06–0:10 | Final-boss silhouette slam; hero dodges; endless wave counter spins past 50. | Text: *"Survive."* |
| 0:10–0:14 | Logo lock-up over card-fan motif. | VO tag: *"OpenForge: Rogue Survivor — wishlist now."* |
| 0:14–0:15 | Steam logo + Wishlist CTA. | Hit. |

---

## 7. ASO — Title Variants

### EN (3 options)

1. **OpenForge: Rogue Survivor** — brand-first, framework-forward (preferred for long-term platform storefront lift, since OpenForge is the umbrella).
2. **Rogue Survivor: A Roguelike Deckbuilder Survivor** — keyword-dense subtitle; maximizes Steam search-tag overlap with "Roguelike" + "Deckbuilder" + "Survivors-like".
3. **Rogue Survivor — Draft, Build, Survive** — verb-triplet subtitle, tighter on mobile listings and trailer end-cards; weakest SEO of the three but highest click-through in social.

### CN (3 options)

1. **OpenForge：不思议求生** —— 品牌优先，与 KK 对战平台调性的"不思议"系列形成软呼应（不侵权），长期利于平台化心智。
2. **不思议求生：肉鸽卡牌构筑** —— 关键词塞满 Steam 中文检索（肉鸽 / 卡牌 / 构筑），短期导流最强。
3. **不思议求生 — 抽卡 · 构筑 · 求生** —— 三动词副标题，契合短视频与直播标题，朗读节奏最佳。

**Recommended primary**: EN #1 + CN #1 (brand-first, long-term). Keep EN #2 / CN #2 ready for a mid-campaign A/B listing test if Week-2 wishlist velocity underperforms.

---

*Draft version: v1.0 | Date: 2026-04-24 | Source of truth: docs/GAME_DESIGN_PLAN.md v2.0 + docs/ROGUE_SURVIVOR_GAPS.md (2026-04-24 audit). Every feature claim is traceable to the design plan or currently-shipped code; multiplayer/co-op, creator revenue share, mobile build, and community-authored maps are on the roadmap but deliberately excluded from this Steam page pending actual ship status.*
