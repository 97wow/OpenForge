# TowerForge - Godot 4 塔防框架

## 项目概述
数据驱动的塔防游戏框架，支持 UGC（用户自定义地图包）。
引擎：Godot 4.6.1 | 语言：GDScript | 目标平台：Steam (Windows/macOS/Linux)

## 架构（四层）
```
创作者层 → 模板层 → 框架层 → 引擎层(Godot)
  JSON数据    预设模板   核心系统    底层渲染
```

### 核心系统（Autoload）
- `EventBus` - 全局事件总线，解耦系统通信
- `GameEngine` - Engine API 入口，上层只通过它与框架交互
- `DataManager` - JSON 数据加载/缓存

### 子系统（挂载在 Main 场景下）
- `GridSystem` - 网格管理（建造位/路径/障碍）
- `PathSystem` - 敌人路径（支持多路径）
- `WaveSystem` - 波次生成
- `UnitSystem` - 单位生命周期（塔/敌人/投射物）
- `EconomySystem` - 金币/收入
- `BuffSystem` - Buff/Debuff 管理

## 目录结构
```
src/
  core/          # Autoload 脚本
  systems/       # 子系统
  entities/      # 实体（towers/, enemies/, heroes/）
  ui/            # UI 场景和脚本
  maps/          # 地图相关
data/
  towers/        # 防御塔 JSON 数据
  enemies/       # 敌人 JSON 数据
  waves/         # 波次配置
  affixes/       # Buff/效果定义
  maps/          # MapPack（每个子目录是一个地图包）
assets/
  sprites/       # 图片资源
  audio/         # 音频资源
  fonts/         # 字体
  shaders/       # 着色器
```

## 开发规范

### GDScript 风格
- 类名用 PascalCase，变量/函数用 snake_case
- 私有成员用 `_` 前缀
- 信号名用过去时（`enemy_killed` 而非 `kill_enemy`）
- 优先使用强类型（`: int`, `: String`, `-> void`）

### 数据驱动原则
- 游戏逻辑参数全部放在 JSON 中，代码只读不写
- 新增塔/敌人/效果只需添加 JSON，不需要修改代码
- MapPack 是独立目录，包含一张地图的所有数据

### 系统通信
- 系统间通过 `EventBus` 信号通信，禁止直接引用其他系统
- 上层代码通过 `GameEngine.xxx()` 调用框架 API
- 数据查询通过 `DataManager.get_xxx()` 获取

### 场景约定
- 实体基类用 `.tscn` + `.gd` 配对
- 数据差异通过 `setup()` 方法注入，不要为每种塔/敌人创建单独场景
- UI 场景放在 `src/ui/` 下

## 构建与运行
```bash
# 命令行运行（调试）
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/huhu/Work/Git/TowerForge --debug

# 导出（Steam）
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/huhu/Work/Git/TowerForge --export-release "Steam"
```

## 当前版本路线
- V0.1: 框架骨架 + 核心系统 + 示例数据 ← 当前
- V0.2: 可玩原型（3 种塔 + 3 种敌 + 1 张地图）
- V0.3: 完整 UI + 升级系统 + 音效
- V1.0: 3 张地图 + 无尽模式 + Steam 上架
