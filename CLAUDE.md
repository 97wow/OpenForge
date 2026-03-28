# OpenForge - 通用游戏创作平台

## 项目定位
OpenForge 是一个基于 Godot 4.6.1 的通用游戏创作框架，类似 War3 地图编辑器。
框架本身不包含任何游戏类型特定逻辑。塔防/MOBA/RPG/生存 都是 GamePack。

## 架构
```
GamePack层    gamepacks/tower_defense/   ← 塔防只是一个 GamePack
框架层         EngineAPI / EventBus / DataRegistry / EntitySystem / TriggerSystem
引擎层         Godot 4.6.1
```

### Autoload（3个）
- `EventBus` — 动态事件注册，无硬编码信号
- `EngineAPI` — War3 风格公共 API 门面
- `DataRegistry` — 通用 JSON 数据缓存 (namespace, id)

### 框架系统（场景树挂载）
- `EntitySystem` — 通用实体生命周期（spawn/destroy/query）
- `ComponentRegistry` — 组件类型注册工厂
- `StatSystem` — 属性计算 (base + flat) * (1 + percent)
- `ResourceSystem` — 通用命名资源（gold/lives/mana 都只是字符串）
- `GridSystem` — 可选网格（tile 状态用字符串，GamePack 自定义语义）
- `TriggerSystem` — ECA 引擎（事件→条件→动作），UGC 逻辑核心
- `BuffSystem` — 通过 StatSystem 修改器实现效果
- `GamePackLoader` — 发现/加载/卸载 GamePack

### 实体与组件
实体 = `GameEntity (Node2D)` + 组件 (子 Node)
没有"塔"和"敌人"的概念，只有 tags + components。

内置组件：health, movement, combat, path_follow, visual, collision

## 目录结构
```
src/
  core/              # 3 个 Autoload
  systems/           # 框架子系统
  entity/            # GameEntity + components/
  gamepack/          # GamePack 加载基础设施
gamepacks/
  tower_defense/     # 示例 GamePack
    pack.json        # 包元数据
    entities/        # 实体定义 JSON
    rules/           # ECA 触发规则 JSON
    buffs/           # Buff 定义 JSON
    maps/            # 地图数据
    scripts/         # GDScript 扩展
```

## 关键设计原则
1. **框架健壮性高于一切** — GamePack 出错绝不崩溃游戏，DebugOverlay 直接在画面上显示错误
2. **框架零游戏知识** — 框架不知道"塔防"存在
3. **数据驱动** — 实体/规则/效果全部 JSON 定义
3. **字符串化** — 事件名/tile状态/游戏状态都用 String
4. **组件化** — ECS-lite，利用 Godot 节点系统
5. **可扩展** — GamePack 脚本可注册自定义组件/条件/动作

## 开发规范
- 类名 PascalCase，变量 snake_case，私有 `_` 前缀
- 系统间通过 EventBus 通信，禁止直接引用
- 上层通过 `EngineAPI.xxx()` 调用，不直接操作子系统
- GamePack 脚本继承 `GamePackScript`

## 构建与运行
```bash
# 运行默认 GamePack (tower_defense)
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/huhu/Work/Git/OpenForge

# 指定 GamePack
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/huhu/Work/Git/OpenForge -- --pack=survival
```
