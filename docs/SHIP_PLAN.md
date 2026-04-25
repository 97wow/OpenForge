# OpenForge Ship Plan — Session Handoff

> Living doc. Each Claude Code session reads this first.
> Last updated: 2026-04-24 by Claude Opus 4.7

## 战略定位（已对齐）

- **产品**：OpenForge（Godot 4 UGC 游戏创作平台）+ `rogue_survivor` 旗舰 gamepack
- **目标**：Steam EA 发布（跳过中国 App Store IAP / 版号）
- **差异化**：KK 对战平台的海外版；全球化 + 现代引擎 + UGC 生态
- **变现**：F2P + 战令 $4.99/月 + 会员 $9.99/月 + 终身通行证 $29.99 + 皮肤
- **红线**：绝不卖数值（Pay-to-Win 毁口碑）

## 当前状态快照

### 已完成
- Godot 4.6.1 框架层（34 系统，TrinityCore 级架构）
- rogue_survivor gamepack：143 spells、19 entities、14 套装、meta progression、season、relics、class promotions
- 语言包 4 种：en / ja / ko / zh_CN
- 单元测试：SpellSystem / StatSystem / DamagePipeline / SpellData
- **工具链：`tools/ai_gateway/` — 5 免费 provider 统一路由**（本次新建）
- claude-next 已装（`/next` / `continue A`）

### 关键缺口（user 自己的 tech_roadmap）
- [ ] **美术资源替换**（当前占位图 — 最大缺口）
- [ ] 音效系统
- [ ] 新手引导
- [ ] Server backend（auth / leaderboard / 地图商店）
- [ ] Web 平台（创作者后台）
- [ ] 支付集成（Paddle key 已有）

### 扩展内容（设计已定但未实现）
- [ ] 16 套装新增（14 → 30，见 GAME_DESIGN_PLAN §2.4）
- [ ] 宝物系统（击杀 50 解锁 3 选 1，见 §3.2）
- [ ] 精英词条（反射/闪电护盾/分裂/吸血/冰冻光环）
- [ ] 战令系统 + 第一个赛季

## 本次会话产出

1. **战略研究完成**（8 份报告，~200 次联网搜索）
   - 结论：OpenForge + 旗舰 gamepack 路线 = devil's-advocate agent 的 Plan B，用户已在走
   - 废弃了"小弓箭手 / 3 线并行"原始计划
2. **ai_gateway 工具链**：`tools/ai_gateway/ai_gateway.py`
   - 5 免费 provider 验证可用：Groq 639ms / Cerebras 1021ms / SiliconFlow 143ms / Mistral 1068ms / GitHub Models 3218ms
   - Per-task routing: code/design/quick/chinese/chat
   - Auto-fallback，stdlib only
   - 配置：`~/.ai_gateway.env`
3. **任务列表重新对齐**（见 TaskList）
4. **claude-next 安装 + 验证**

## 下一会话入口（优先级顺序）

### 第一要务：美术资源生成管线（Task #10）
- Mac Studio 32GB + Hunyuan3D + FLUX 本地部署
- 目标资产：6 英雄 + 15 敌人 + 143 技能图标 + UI
- 入口：Task #6（Set up Hunyuan3D on Mac Studio）先跑通

### 第二要务：套装扩展到 30（Task #13）
- 纯 JSON 数据驱动，不动 GDScript
- 参考 GAME_DESIGN_PLAN §2.4 的 16 套清单
- SpellSystem 里找 spell id 复用模式

### 第三要务：Steam 商店页 + 胶囊图（Task #7）
- 需要至少一张英雄概念图先（依赖美术管线）
- 先写文案（EN + ZH），胶囊图稍后

## 关键路径（CRITICAL PATH）

```
Hunyuan3D 本地部署 (Day 1-2)
  ↓
首批 10 个资产验证 (Day 3)
  ↓
批量生成 + 入库 (Day 4-14)
  ↓
套装扩展同步进行（数据驱动，不阻塞美术）
  ↓
Steam 商店页上线收 wishlist (Week 3)
  ↓
Next Fest demo (Month 2-3)
  ↓
EA 发布 (Month 4-6)
```

## 红线提醒（务必读 CLAUDE.md §经验教训）

1. 全局替换必须扫 .gd + .tscn + .json
2. 禁止 SpellSystem 双实现路径（JSON + 硬编码同功能）
3. CHAIN/AOE 必须框架级硬上限（`max_targets = mini(n, 10)`）
4. PROC 三重安全边界必守
5. 单文件不超过 500 行
6. **不会 git 操作**（用户明示）

## 用户需要亲自出手的事（待办）

- [ ] Steam Direct 商店页首次创建（登录 Steamworks）
- [ ] 首次付费 API 订阅（目前全免费栈够用，暂无）
- [ ] 真机玩测反馈（每 milestone）
- [ ] 主播/Reddit/Discord 社区运营

## Credentials 速查

- 项目路径：`/Users/huhu/Work/Git/OpenForge`
- ai_gateway 配置：`~/.ai_gateway.env`
- 全局 CLAUDE.md：`/Users/huhu/.claude/CLAUDE.md`
- 项目 CLAUDE.md：`/Users/huhu/Work/Git/OpenForge/CLAUDE.md`
- 设计文档：`docs/GAME_DESIGN_PLAN.md` / `docs/BALANCE_SHEET.md` / `docs/FRAMEWORK_UPGRADE_PLAN.md`
- 凭据库：`/Volumes/192.168.1.11/CREDENTIALS.md`
