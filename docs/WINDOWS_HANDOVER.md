# OpenForge — Windows + 3090 Handover (2026-04-25)

> 读这一篇就够。给 Windows 那台机的 Claude Code 看的接续稿。

---

## 0. 物理交接（用户做，不是 Claude 做）

Repo 在 Mac 上 main +23 commit ahead of origin/main，**未 push**。Windows 拿到代码的两条路：

- (A) Mac 上 `git push origin main`，Windows `git clone`（最快，但失去 Mac 用户"不要 push"的偏好）
- (B) Mac 整个 `OpenForge/` 目录 USB/cloud 拖到 Windows，保持未 push 状态（推荐）

落地后 Windows 上 `git status` 应是 clean，`git log --oneline -1` 应是 `1346f08`。

---

## 1. TL;DR

- **项目**：`OpenForge` —— Godot 4.6.2 通用 UGC 游戏框架，rogue_survivor 是首发 GamePack
- **Mac 侧 2 轮 own session（共 23 commit）已收尾**：所有数据驱动工作（30 sets / Onboarding / Audio CC0 / i18n / framework hardening）
- **Windows 侧职责**：纯资产生产 + 真 AI 管线（3090 24GB VRAM，CUDA 路径直通，Mac MPS 跑不动的全在这台上做）
- **首要任务（按优先级）**：
  1. `assets/audio/bgm/battle_01.mp3` 走 MusicGen 重渲（**最后 1 个 audio license blocker**）
  2. ART_ASSET_PLAN §1 P0 的 5 个 projectile/fountain sprites（FLUX/SDXL/MJ）
  3. ART_ASSET_PLAN §2A P0 的 3 个 boss meshes（Hunyuan3D 24GB CUDA 直跑）
  4. （可选）TripoSR 大批量 P1 资产（已在 Mac 验证 28s/资产）

---

## 2. Mac 侧已 ship 的内容（不要重做）

23 个 commit，HEAD `1346f08`：

```
1346f08 feat(cards): ship Wave C 4 bonds + 18 cards (26→30, target hit)
b3b00b9 feat(cards): ship Wave B 5 bonds + 17 cards (21→26)
9cd6b35 feat(cards): top up dragon_ball #38 5→7
8012a7b feat(cards): ship 17 cards activating Wave A 6 bonds + Summoner #92
7de6771 test(spell_data): lint that every bond has ≥required cards
4392c0e i18n: backfill 23 SET_/BOND_ keys × 4 langs
9dd8292 feat(audio): wire boss_death + hit_holy SFX
df8031a chore(test): per-suite runner sidesteps gdUnit4 + autoload contamination
72b388f docs(audio): verify all 17 sfx/ files via sha256 match against Kenney CC0
b7e8ad1 feat(onboarding): ship §A5 skip-tutorials toggle (escape hatch)
773cf3a feat(onboarding): ship §A4 first-boss + emit boss_spawned event
c5d04f4 feat(onboarding): ship §A2 first-draft + §A3 first-bond beats
78f0ce9 feat(onboarding): ship §A1 welcome/movement primer (data-driven)
532232a fix(audio): swap 8 unknown-provenance SFX with Kenney CC0 + sidecar JSON
76490c7 fix(framework): unit test fixtures + EventBus stale-callback purge
c5e40cf feat(framework): TrinityCore-level system upgrade — 19 new subsystems + 3D conversion
64423e9 chore: AI tooling + multi-batch orchestrator + framework docs sync
9631ca2 docs: ship-readiness specs + audits + planning
d890c0a i18n: 4-language packs + spell localizations
381bcf7 feat(rogue_survivor): ship-readiness gamepack rebuild
a9d7077 chore: remove deprecated cards/ system
04a4b61 chore: gitignore third-party assets + asset manifest verifier
650cdf6 (origin/main) feat: difficulty system N1-N10 + game over screen with stats
```

具体内容看 `~/.claude/projects/-Users-huhu/memory/openforge_ship_readiness_0425.md`（Mac 上）；Windows 上看 `docs/SHIP_READINESS_v3.md` + `docs/SETS_EXPANSION_PROPOSAL.md` + 本文。

**Bond 全景（30 bonds 全部 drafttable）**：14 IP-themed + 6 Wave A + 6 Wave B + 4 Wave C。每个 bond 都有 cards >= required。`tests/unit/test_spell_data.gd` lint 守住。

**SHIP_READINESS_v3 §3 9 个硬阻塞**：7 个收口 + 2 个等你（5 sprites + 3 boss meshes + battle_01.mp3 BGM）。

---

## 3. 你的具体任务

### 任务 #1（最先做）：`battle_01.mp3` BGM 走 MusicGen

- **Spec**：`docs/AUDIO_REPLACEMENT_PLAN.md` §12 Option A（认真读 §12 整段）
- **关键**：3090 VRAM 24GB，跑 `facebook/musicgen-medium` 或 `musicgen-large` 都没压力（Mac M1 Max 的 MPS 跑 small 都死）
- **Concrete prompt**（已写好，从 §12 抄）：

```
prompt: "Epic orchestral combat with driving percussion. 130 BPM.
Heavy taiko drums on the downbeat, rapid 16th-note snare pattern.
Low brass ostinato in E minor playing a 4-note repeating motif.
Soaring french horn melody over the top. Distorted electric cello
layer for grit. No vocals. Builds continuously — tension maintained,
never resolves. Suitable for wave-based combat in a roguelite. Loopable."
duration: 90
seed: 2024
```

- **输出**：覆盖 `assets/audio/bgm/battle_01.mp3` 或 ship 成 `battle_01.ogg`（OGG ~128kbps 更好 loop）
- **必做**：写 `assets/audio/bgm/battle_01.mp3.source.json` sidecar，schema 抄 `assets/audio/death.wav.source.json`（同目录有 8 个 sample 可看）
- **必做**：更新 `assets/audio/ATTRIBUTIONS.md` 把 BGM 那行从 "unknown — deferred" 改成 verified MusicGen
- **commit 名**：`feat(audio): render battle_01.mp3 via MusicGen on 3090 (close 9th license blocker)`

### 任务 #2：5 个 projectile/fountain sprites（P0）

- **Spec**：`docs/ART_ASSET_PLAN.md` §1（详细 prompt + 尺寸都在里面）
- **路径**：`assets/sprites/` 下 — 现有 placeholder 结构 grep 一下能定位
- **建议工具链**：
  - FLUX.1 [dev] 24GB VRAM 跑得动，`black-forest-labs/FLUX.1-dev` HF
  - 或 SDXL + ControlNet 出 sprite sheet
  - 或 MJ Web 手出（如果想快）
- **每个 sprite 配 sidecar JSON**（同 audio 模式）
- **commit 名**：`feat(art): replace 5 projectile placeholders via FLUX (close P0 art blocker)`

### 任务 #3：3 个 boss meshes（P0）

- **Spec**：`docs/ART_ASSET_PLAN.md` §2A（Bone Dragon / Shadow Lord / Void Titan）
- **走 Hunyuan3D**：Mac MPS 死了，3090 CUDA 是设计目标
  - 装机：`pip install -e .[texgen]` 在 `~/.openforge-ai-env/src/Hunyuan3D` 里（Mac 装过但 inference 死，Windows 重装即可）
  - Mac 上的 24GB 形状模型在 `~/.openforge-ai-env/models/tencent--Hunyuan3D-2mini/` 已下载（如果走 USB 方案可以一起拖过来省下载时间）
  - 详见 `docs/HUNYUAN_SMOKE_TEST.md` 看 Mac 上死哪一行（你不会踩）
- **输出**：`assets/models/<name>/` 下 .glb 或 .obj + .png 纹理
- **commit 名**：`feat(art): boss meshes (bone_dragon/shadow_lord/void_titan) via Hunyuan3D on 3090`

### 任务 #4（可选）：批量 P1 资产（TripoSR）

TripoSR 已在 Mac 验证（28s/资产，vertex-colored）。Windows + 3090 应该 5-10s/资产。`~/.openforge-ai-env/hunyuan3d/bin/python ~/.openforge-ai-env/src/TripoSR/run.py <image> --device cuda --output-dir <out>`（Mac 用 mps，Windows 改 cuda）。详见 `docs/TRIPOSR_SUCCESS.md`。

---

## 4. 用户的硬规则（CLAUDE.md，必读）

> 这些是 Mac 上 user 全局 CLAUDE.md 的偏好，Windows 上也适用：

1. **用简体中文回复**（不是英文）
2. **❌ 不要主动创建文档**（README/指南/说明等 .md 文件），除非用户明确说"写个文档"
3. **❌ 不要主动 git push / amend 已有 commit**。每次新错误开新 fix commit
4. **数据库 / API / 后端代码**：基于事实查询而非假设，但**这个项目没数据库**，规则不适用
5. **每次 session 收尾前编译验证**：`bash tools/test/run_all_tests.sh` 必须 6/6 PASS
6. **CLAUDE.md "经验教训 §1-9"**（项目级）：
   - 全局替换扫 .gd + .tscn + .json
   - sed/批量替换后验证完整性
   - 同一效果禁止有两条实现路径
   - PROC 必须有 cooldown
   - SpellSystem CHAIN/AOE 框架级硬上限

---

## 5. 验证你的工作

每次 commit 前后都跑：

```bash
# 集成 smoke
GODOT_BIN=/path/to/Godot.exe bash addons/gdUnit4/runtest.sh -a tests/integration/test_smoke.gd
# 全套（per-suite，绕跨 suite SIGSEGV）
GODOT_BIN=/path/to/Godot.exe bash tools/test/run_all_tests.sh
```

预期：smoke 8/8 PASS，全套 6/6 PASS。

⚠️ **跨 suite SIGSEGV**：`runtest.sh -a tests/` 在第 4 个 suite 转入时仍崩（gdUnit4 + autoload 状态污染，Mac 上 commit `df8031a` 加了 per-suite runner 绕开）。**别尝试单跑 `runtest.sh -a tests/`**，永远走 `tools/test/run_all_tests.sh`。

---

## 6. 资产 sidecar JSON 约定

每个新资产配 `<file>.source.json`：

```json
{
  "source": "<工具名 / 包名>",
  "source_url": "<下载 URL 或 model card>",
  "source_file": "<原始文件名 / prompt>",
  "source_sha256": "<原始 hash>",
  "license": "<CC0 / CC-BY / Pixabay / MusicGen 输出>",
  "license_url": "<license 链接>",
  "transform": "<转码 / 压缩 / 切片步骤>",
  "output_sha256": "<最终文件 hash>",
  "output_duration_sec": <音频长度，可选>,
  "picked_at": "2026-04-XX",
  "picked_by": "<commit subject>"
}
```

参考 `assets/audio/death.wav.source.json`（Mac 落地的 8 个 SFX 都有，schema 已经稳了）。

`assets/audio/ATTRIBUTIONS.md` 是 SoT，每加一个资产同步更新该文件对应行。

---

## 7. 推荐的开工顺序

1. **5 分钟**：`git status && git log --oneline -10 && bash tools/test/run_all_tests.sh` —— 确认 baseline 干净
2. **30 分钟**：先做任务 #1 (battle_01.mp3 MusicGen)，是闭环最快的（render → sidecar → commit），验证 Windows 路径都通
3. **半天**：任务 #2 (5 sprites)，如果工具链熟悉就 1-2 小时
4. **半天-1 天**：任务 #3 (3 boss meshes via Hunyuan3D)
5. **可选 multi-day**：任务 #4 批量 TripoSR

每个任务完成都开新 fix/feat commit，不要 amend。

---

## 8. 工具链速查

- Godot 4.6.2 stable —— 已在 `addons/gdUnit4` (gdUnit4) 装好
- `tools/test/run_all_tests.sh` —— per-suite test runner，绕开跨 suite SIGSEGV
- `tools/setup/download_assets.sh` —— 验证第三方包齐全（10 个包：characters/enemies/monsters/dungeon/fantasy_rts/nature/game_icons/ui/fonts/gdUnit4）
- `tools/setup/install_hunyuan3d_mac.sh` —— Mac 装机脚本（**Windows 重写一份**，去掉 MPS 处理，加 CUDA 检测）
- `tools/orchestrator/` —— 多批 own 工具链（如果想跑长 session）

---

## 9. 关键文件路径速查

```
gamepacks/rogue_survivor/data/spells.json              # 30 bonds + ~70 cards (本文 §2 提到)
gamepacks/rogue_survivor/data/spells_<en|zh_CN|ja|ko>.json  # 卡牌/bond i18n
gamepacks/rogue_survivor/theme_bonds.json              # 29 跨集羁绊
gamepacks/rogue_survivor/rules/onboarding.json         # 4 个 onboarding trigger
gamepacks/rogue_survivor/scripts/rogue_*.gd            # GamePack 业务代码
gamepacks/rogue_survivor/spells/*_set_bonus.json       # 30 set bonus blueprint
src/systems/                                           # 框架层 (TrinityCore-style 19+ 系统)
src/core/{event_bus,engine_api,data_registry}.gd       # autoload
lang/{en,zh_CN,ja,ko}.json                             # 框架级 i18n（含 onboarding/SET_*/BOND_*）
assets/audio/                                          # SFX + BGM + sidecar JSON
assets/audio/sfx/                                      # 17 个 Kenney CC0 已 sha256 verified
assets/audio/ATTRIBUTIONS.md                           # SoT
docs/                                                  # 30+ spec 文档
addons/gdUnit4/                                        # 测试框架
```

---

## 10. 不要 break

- ✅ 30 bonds 全部 drafttable（commit `1346f08`）
- ✅ per-suite test runner（`df8031a`）
- ✅ ATTRIBUTIONS.md 全部 CC0 verified
- ✅ Onboarding §A1-A5 全部 ship-ready
- ✅ Wave A bonds 真激活（不是 paper-shipped）
- ✅ EventBus stale-callback purge（`76490c7`）

新加资产时改 ATTRIBUTIONS.md 的对应行 + 加 sidecar 即可。改其他东西先确认它不依赖于上述任何一项。

---

## 11. 出问题怎么办

1. 测试挂了 → 先 `git diff` 看自己改了啥，`git stash` 回到 clean，看是不是 baseline 就有问题（baseline 应该 6/6 PASS）
2. Hunyuan3D Windows 装机失败 → 看 `docs/HUNYUAN_SMOKE_TEST.md` Mac 死的位置，Windows 重写 install 脚本时跳过 MPS 处理
3. Godot 编译错 → 按 CLAUDE.md "经验教训 §1-9" 修，commit 名走 `fix(framework): ...` 前缀
4. 不知道怎么办 → 读 `docs/SHIP_READINESS_v3.md` 看上下文

---

*Mac 侧最后 session: 2026-04-25, 16 commit, Claude Opus 4.7 (1M context). HEAD `1346f08`.*
