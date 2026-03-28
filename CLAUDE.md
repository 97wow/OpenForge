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
- `GamePackLoader` — 发现/加载/卸载 GamePack

## 实体与组件
实体 = `GameEntity (Node2D)` + 组件 (子 Node)
没有"塔"和"敌人"的概念，只有 tags + components。

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
7. **多语言** — 所有用户可见文本使用 tr() + CSV 翻译

## 开发规范
- 类名 PascalCase，变量 snake_case，私有 `_` 前缀
- 系统间通过 EventBus 通信，禁止直接引用
- 上层通过 `EngineAPI.xxx()` 调用，不直接操作子系统
- GamePack 脚本继承 `GamePackScript`
- 使用 `set_anchors_and_offsets_preset()` 而非 `anchors_preset =`（Godot 4 代码设置 anchor 的正确方式）
- 赋值来自 Dictionary.get() 或 Variant 的值时，使用显式类型声明（避免类型推断错误）
