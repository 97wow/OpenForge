# OpenForge - 通用游戏创作平台

## 项目定位
OpenForge 是一个基于 Godot 4.6.1 的通用游戏创作框架，类似 War3 地图编辑器。
框架本身不包含任何游戏类型特定逻辑。塔防/MOBA/RPG/生存 都是 GamePack。

## 架构设计哲学

### 核心参考：魔兽世界服务端架构
OpenForge 的框架设计深度借鉴 TrinityCore/AzerothCore（魔兽世界开源服务端模拟器）的架构思想。
这不是抄袭，而是学习经过 20 年验证的、全球最成功 MMORPG 的系统设计模式。

**关键借鉴领域：**
- **Spell System** — 数据驱动的技能系统（Effect + Aura + Proc），用户写 JSON 即可创建复杂技能
- **Entity/Component** — 实体组件模式（Unit + Spell + Aura 的关系）
- **Event/Proc** — 事件驱动的触发系统（ON_HIT/ON_KILL/ON_DAMAGE_TAKEN 触发连锁效果）
- **Targeting** — 组合式目标选择（Category × Reference × Check × Shape）
- **Damage School** — 伤害类型系统（Physical/Frost/Fire/Nature/Shadow/Holy）

**设计决策时的优先级：**
1. 先查 TrinityCore 怎么做的 → 理解其设计意图
2. 简化适配到 2D + Godot + JSON 的场景
3. 保持可扩展性（GamePack 可注册自定义 Effect/Aura/Proc 处理器）

### 架构层次
```
GamePack层    gamepacks/rogue_survivor/   ← 具体游戏玩法
框架层         SpellSystem / AuraManager / ProcManager / EntitySystem / ...
引擎层         Godot 4.6.1
```

## Autoload
- `EventBus` — 动态事件注册，无硬编码信号
- `EngineAPI` — War3 风格公共 API 门面
- `DataRegistry` — 通用 JSON 数据缓存 (namespace, id)
- `SceneManager` — 场景切换管理
- `DebugOverlay` — 游戏内调试信息显示（GamePack 出错时画面上显示）

## 框架系统
- `EntitySystem` — 通用实体生命周期（spawn/destroy/query）
- `ComponentRegistry` — 组件类型注册工厂
- `SpellSystem` — **核心：数据驱动技能引擎**（借鉴 TrinityCore Spell 框架）
- `AuraManager` — Aura 生命周期（apply/tick/remove/stack）
- `ProcManager` — 事件驱动触发系统（ON_HIT → TRIGGER_SPELL）
- `StatSystem` — 属性计算 (base + flat) * (1 + percent)
- `ResourceSystem` — 通用命名资源
- `GridSystem` — 可选网格
- `TriggerSystem` — ECA 引擎（事件→条件→动作）
- `BuffSystem` — 通过 StatSystem 修改器实现效果（将被 AuraManager 取代）
- `AreaAuraSystem` — 地面持续效果（火圈/毒池/治疗场），对标 TC DynObjAura
- `ImmunitySystem` — 学校免疫 + 机制免疫，ref-counted，与 DamagePipeline/AuraManager 集成
- `RespawnSystem` — 刷新组 + 定时重生 + 条件刷新，对标 TC SpawnGroup
- `FactionSystem` — 多阵营 + Reaction Matrix + 声望系统，对标 TC FactionTemplate
- `MovementGenerator` — 移动行为优先级栈（Chase/Flee/Confused/Home/Follow/Effect），对标 TC MotionMaster
- `DiminishingReturns` — CC 递减（全效→50%→25%→免疫，18秒窗口），与 AuraManager 集成
- `EncounterSystem` — Boss 战斗脚本框架（阶段/定时器/狂暴/回调），对标 TC InstanceScript
- `QuestSystem` — 数据驱动任务（kill/collect/reach/interact + 链式 + 奖励），对标 TC QuestMgr
- `AchievementSystem` — 成就系统（标准评估 + 统计 + 点数），对标 TC AchievementMgr
- `PathfindingSystem` — 寻路（NavigationServer2D + 路径缓存 + 动态障碍），对标 TC MMAP
- `NetworkSystem` — 网络同步（ENet + 状态快照 + 客户端插值 + RPC 消息），对标 TC WorldSession
- `RoomSystem` — 房间/匹配（创建/加入/就绪/ELO/快速匹配），对标 KK 对战平台
- `ChatSystem` — 聊天（频道/密语/系统消息/过滤器），对标 TC ChatHandler
- `ReplaySystem` — 重放（事件录制/回放/快进/导出JSON），对标 SC2 Replay
- `LevelSystem` — 等级/经验/属性成长（升级曲线 + per-level 属性 + 技能点），对标 TC Unit::GiveXP
- `DialogueSystem` — NPC 对话树（JSON节点+选项+条件分支+Quest集成+动作），对标 TC GossipMenu
- `CameraSystem` — 镜头控制（跟随/缩放/震动/过渡/区域锁定），对标 War3 Camera API
- `AudioManager` — 音频管理（BGM淡入淡出/环境音/SFX池化/音量分组），16路SFX对象池
- `GamePackLoader` — 发现/加载/卸载 GamePack

## 实体与组件
实体 = `GameEntity (Node2D)` + 组件 (子 Node)
没有"塔"和"敌人"的概念，只有 tags + components + faction。

### Faction 阵营系统
每个实体有 `faction` 属性：`"player"` / `"enemy"` / `"neutral"`
- 根据 tags 自动推断（player/friendly/hero → "player", enemy → "enemy"）
- 支持 JSON 或 spawn overrides 显式指定
- `entity.is_hostile_to(other)` / `entity.is_friendly_to(other)` 判断敌我
- `EngineAPI.find_hostiles_in_area(source, center, radius)` — 查找敌对实体
- `EngineAPI.find_allies_in_area(source, center, radius)` — 查找同阵营实体
- SpellSystem 目标解析优先使用 faction（ENEMY/ALLY check → find_hostiles/find_allies）

内置组件：health, movement, combat, path_follow, visual, collision,
player_input, projectile, ai_move_to, alert

### HealthComponent 伤害类型
6 种伤害类型（参考 WoW）：Physical(白) / Frost(蓝) / Fire(橙) / Nature(绿) / Shadow(紫) / Holy(金)

## 关键设计原则
1. **框架健壮性高于一切** — GamePack 出错绝不崩溃游戏
2. **数据驱动优先于代码** — 新技能/效果/规则应该只需写 JSON，不需要改代码
3. **借鉴成熟架构** — 遇到复杂系统设计时，优先参考 TrinityCore/AzerothCore 的解决方案
4. **框架零游戏知识** — 框架不知道"塔防"或"肉鸽"存在
5. **组件化 + ECS-lite** — 利用 Godot 节点系统
6. **可扩展** — GamePack 可注册自定义 Effect/Aura/Proc/Component 处理器
7. **多语言** — `I18n.t("KEY")` / `I18n.t("KEY", [args])`，独立 JSON 语言包（`lang/*.json`），支持运行时下载

## 开发规范

### 命名与风格
- 类名 PascalCase，变量 snake_case，私有 `_` 前缀
- 禁止使用 GDScript 保留字/内置函数名作变量名（如 `name`, `sign`, `class_name`）
- 赋值来自 `Dictionary.get()` 或 Variant 的值时，使用显式类型声明（避免类型推断错误）
- 事件回调中的实体引用必须用 Variant 类型 + `is_instance_valid()` 检查，禁止强类型 `Node2D`

### 文件结构（严格执行）
- **单文件不超过 500 行**。超过时必须拆分为模块
- GamePack 主脚本（如 `rogue_game_mode.gd`）只做主控：初始化、process 循环、委托
- 功能模块用独立 class 文件，通过 `init(game_mode)` 接收主控引用
- 模块间禁止直接引用，通过主控或 EventBus 通信
- 模块划分原则：战斗逻辑、UI/HUD、卡片系统、战斗日志、Tooltip 各自独立

### 多语言（I18n）
- 所有用户可见文本必须通过 `I18n.t("KEY")` 或 `I18n.t("KEY", [args])`
- **禁止** `tr()`、`TranslationServer` 直接调用、`.tscn` 中的 `auto_translate_mode`
- 语言包为独立 JSON 文件（`lang/*.json`），每种语言一个文件
- 新增功能必须同时添加翻译 key 到所有语言包
- JSON 中的 `\n` 由 I18nManager 自动转换为真正换行

### 事件系统
- 系统间通过 EventBus 通信，禁止直接引用
- 上层通过 `EngineAPI.xxx()` 调用，不直接操作子系统
- `projectile_hit`、`spell_cast` 等框架组件发出的事件必须在 `core_events` 保护列表中
- 事件回调中禁止使用 lambda 捕获实体引用（会导致 freed 错误），改用 `bind()` 或独立方法
- 延迟操作用 `await get_tree().create_timer(n).timeout` 而非 `create_timer.connect(func)`

### UI 规范
- 使用 `set_anchors_and_offsets_preset()` 而非 `anchors_preset =`
- 面板必须设置 `content_margin_*`（padding），禁止内容贴边
- Tooltip 使用自定义即时显示系统，禁止 Godot 默认延迟 tooltip
- 所有 `.tscn` 中的文本都需要在 `_ready()` 中用 `I18n.t()` 覆盖

### 阵营与目标
- 实体有 `faction` 属性，通过 `FactionSystem` 管理多阵营关系（不限于 player/enemy/neutral）
- 目标查询优先使用 `find_hostiles_in_area(source, ...)` / `find_allies_in_area(source, ...)`
- SpellSystem 的 ENEMY/ALLY check 自动使用 faction 感知查询
- DOT/间接伤害不触发 `on_hit` proc（防止无限循环）
- **阵营关系不传递**：A↔B=FRIENDLY 且 B↔C=HOSTILE **不**意味着 A↔C=HOSTILE
- 每对阵营的关系必须显式设置，未设置的回退到 `base_reactions` 或 NEUTRAL
- 这是设计决策：怪物不应自动攻击功能性 NPC，只在明确对立时手动设置

### 经验教训（严格遵守）
1. **全局替换必须扫描 .gd + .tscn + .json**，不能只改 .gd 文件
2. **sed/批量替换后必须验证**上下文完整性，`sed -i` 容易破坏缩进和变量名
3. **新增 Autoload 后** GamePack 动态加载的脚本可能无法直接访问，需要 `@onready var X = get_node_or_null("/root/X")` 或 `EngineAPI` 代理
4. **EventBus.clear_all_custom_events()** 会删除非 core 事件的所有 listener，框架系统注册的 listener 会丢失
5. **take_damage/heal 的 ability 参数**：所有伤害/治疗调用应标注来源技能名，用于战斗日志准确显示
6. **同一效果禁止有两条实现路径**：如果 GamePack 手动代码实现了闪电链，就必须删除 SpellSystem JSON 中的同功能 spell，否则改了一条忘了另一条会导致效果叠加/失控。**修改效果时必须 `grep -r` 搜索所有 .json + .gd 中的相关引用**
7. **SpellSystem CHAIN/AOE 必须有框架级硬上限**：JSON 中的 `max_targets`/`chain_targets` 不可信，框架层 `_resolve_targets` 必须强制 `max_targets = mini(max_targets, 10)`。PROC 触发的 spell 产生的伤害**禁止**再触发 `deal_damage` proc（防止 A→B→A 无限级联）
8. **PROC 安全规则**：(a) `on_hit` flag 只能由 `projectile_hit` 触发，`entity_damaged` 只触发 `deal_damage`；(b) PROC 触发的 spell 造成的伤害事件应标记 `is_proc: true`，ProcManager 跳过带此标记的事件；(c) 所有 PROC 必须有 `cooldown`（最低 0.5s）
9. **所有连锁/分裂效果必须有三重安全边界**：(a) `_xxx_fired_this_volley` 标记防止多发弹道重复触发；(b) 产物不能再触发同类效果（如分裂弹的 `ability_name="split"` 命中时跳过分裂逻辑）；(c) 目标数/伤害有硬上限（`mini(count, N)` / `minf(dmg, M)`）。修复一个效果时必须检查所有同类效果是否也有相同问题
