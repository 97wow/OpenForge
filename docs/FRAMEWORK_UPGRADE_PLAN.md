# OpenForge 框架升级计划 — 全面对标 TrinityCore

> **核心原则**: 任何涉及框架层的新系统、机制、逻辑，都以 [TrinityCore](https://github.com/TrinityCore/TrinityCore) 为参考标准。
> 这不是抄袭，而是学习经过 20 年验证的、全球最成功 MMORPG 的系统设计模式。

---

## 框架开发规范（所有后续开发必须遵循）

### 1. TrinityCore 对标原则
- 新增任何框架系统前，先查 TrinityCore 对应实现（搜 GitHub 源码）
- 简化适配到 2D + Godot 4.6 + JSON 数据驱动
- 不需要 1:1 照搬，但核心设计模式必须一致

### 2. 框架层 vs GamePack 层
- **框架层** (`src/`)：零游戏知识，不包含任何具体游戏逻辑
- **GamePack 层** (`gamepacks/`)：所有游戏特定逻辑
- 规则：如果两个不同 GamePack 都需要，就是框架层的事

### 3. 目标检查统一
- 所有目标选择必须通过 `TargetUtil.is_valid_attack_target()` 或 `is_valid_assist_target()`
- 禁止直接写 `is_instance_valid + is_alive + faction` 散装检查

### 4. 伤害统一
- 所有伤害必须走 `DamagePipeline.deal_damage()`
- `health_component.take_damage()` 内部已委托 Pipeline
- GamePack 通过 `damage_calculating` 事件 hook 增伤/减伤

### 5. 状态管理统一
- 所有 CC/免疫/战斗状态通过 `UnitFlags` bitmask
- 通过 `set_unit_flag() / clear_unit_flag()` 操作
- 禁止用 tag 模拟状态（tag 是静态分类，flag 是动态状态）

### 6. AI 行为统一
- AI 状态机：IDLE → COMBAT → EVADING → HOME
- 目标选择：COMBAT 用 ThreatManager，IDLE 用距离
- 脱战：home_position = 进入战斗时的位置，脱战免疫一切

### 7. 技能生命周期统一
- 所有技能走 PREPARE → START → EXECUTE → EFFECT → FINISH
- 事件顺序由框架保证（先通知再执行效果）
- 新增技能类型只需在 START 阶段加分支

### 8. 事件驱动
- 系统间通信用 EventBus，不直接引用
- 核心事件：entity_damaged / entity_killed / spell_cast / unit_flags_changed
- GamePack 通过 connect_event hook 框架行为

### 9. 数据驱动
- 实体/技能/Aura/掉落 全部 JSON 定义
- 代码只写"怎么执行"，数据决定"执行什么"
- CC 类型通过 JSON aura type（CC_STUN/CC_ROOT 等），不写死在代码里

### 10. 测试规范
- 每个框架系统完成后，在 Test Arena 中添加对应测试按钮
- Test Arena 是框架验证的唯一入口，不在正式 GamePack 中测试框架

---

## 当前框架状态（2026-03-31）

已有 33 个系统 + Test Arena 测试地图（Phase 1-4 全部完成）

### Phase 1 — 战斗核心 ✅ 全部完成
| # | 系统 | 文件 | TC 对应 |
|---|------|------|---------|
| 1.1 | UnitFlags | `src/entity/unit_flags.gd` | UnitFlags/UnitState |
| 1.2 | TargetUtil | `src/entity/target_util.gd` | IsValidAttackTarget |
| 1.3 | ThreatManager | `src/systems/threat_manager.gd` | ThreatManager |
| 1.4 | AI 状态机 | `entity_system.gd` 重构 | CreatureAI |
| 1.5 | CC 效果 | `aura_manager.gd` CC handlers | SPELL_AURA_MOD_STUN 等 |
| 1.6 | 施法状态机 | `spell_system.gd` | Spell 生命周期 |
| 1.7 | 伤害流水线 | `src/systems/damage_pipeline.gd` | Unit::DealDamage |

## Phase 1 — 战斗核心（最高优先级）

所有游戏类型的基础。缺少任何一个都会导致反复踩坑。

### 1.1 Unit State Flags
**TC 对应**: `UnitFlags`, `UnitState`, `DeathState`

当前只有 `is_alive`。需要完整的状态位系统：

```
UnitState:
  ALIVE / DEAD / EVADING

UnitFlags (bitmask):
  STUNNED        — 无法移动+攻击+施法
  ROOTED         — 无法移动，可攻击/施法
  SILENCED       — 无法施法，可移动/攻击
  FEARED         — 随机移动，无法控制
  IMMUNE_DAMAGE  — 免疫所有伤害
  IMMUNE_CC      — 免疫控制效果
  CASTING        — 正在施法（可被打断）
  CHANNELING     — 正在引导（可被打断）
  EVADING        — 正在回家（免疫+无法被选中）
  NOT_SELECTABLE — 不可被选为目标
  IN_COMBAT      — 战斗中
```

**实现方案**: `GameEntity` 新增 `unit_flags: int` (bitmask) + `unit_state: int` (enum)。
所有组件通过 `entity.has_flag(FLAG)` / `entity.set_flag(FLAG)` 读写。

### 1.2 IsValidTarget() — 统一目标检查
**TC 对应**: `Unit::IsValidAttackTarget()`, `Unit::IsValidAssistTarget()`

**一个方法**替代当前散落在 5 个文件的检查：

```gdscript
func is_valid_attack_target(attacker: GameEntity, target: GameEntity) -> bool:
	if target == null or not is_instance_valid(target): return false
	if not target.is_alive: return false
	if target == attacker: return false
	if attacker.is_friendly_to(target): return false
	if target.has_flag(UnitFlags.NOT_SELECTABLE): return false
	if target.has_flag(UnitFlags.IMMUNE_DAMAGE) and not ignore_immunity: return false
	if target.has_flag(UnitFlags.EVADING): return false
	return true
```

所有目标查询（EntitySystem/ProjectileComponent/CombatComponent/SpellSystem）统一调用此方法。

### 1.3 ThreatManager — 仇恨系统
**TC 对应**: `ThreatManager`, `ThreatReference`

每个 Unit 维护一个仇恨列表：
- 对其造成伤害 → 增加威胁值
- 治疗吸引目标的敌人 → 增加威胁值（治疗量 × 0.5）
- 嘲讽 → 强制置顶
- 超距/脱战 → 清除威胁

AI 目标选择 = 仇恨列表排序后取第一个（替代当前的"最近敌人"）。

```gdscript
class ThreatEntry:
	var target: GameEntity
	var threat: float
	var taunt_state: int  # NONE / TAUNTED / DETAUNTED

class ThreatManager:
	var _threat_list: Array[ThreatEntry]
	func add_threat(source, amount)
	func get_victim() -> GameEntity  # 仇恨最高的
	func remove_threat(source)
	func clear()
```

### 1.4 AI 状态机
**TC 对应**: `CreatureAI` 虚基类

```
IDLE    — 站桩/巡逻，无威胁目标
COMBAT  — 仇恨列表非空，攻击 get_victim()
EVADE   — 脱战条件触发，回出生点，清仇恨，免疫
HOME    — 到达出生点，恢复满血，切回 IDLE
```

关键钩子（GamePack 可 override）：
- `on_enter_combat(first_attacker)`
- `on_killed_unit(victim)`
- `on_just_died(killer)`
- `on_evade()`
- `on_update_ai(delta)` — 每帧 AI 逻辑

### 1.5 CC 效果 — 控制类 Aura
**TC 对应**: `SPELL_AURA_MOD_STUN`, `SPELL_AURA_MOD_ROOT` 等

通过 Aura 系统实现，Apply 时设置 UnitFlag，Remove 时清除：

| CC 类型 | UnitFlag | 移动 | 攻击 | 施法 |
|---------|----------|------|------|------|
| STUN    | STUNNED  | ✗    | ✗    | ✗    |
| ROOT    | ROOTED   | ✗    | ✓    | ✓    |
| SILENCE | SILENCED | ✓    | ✓    | ✗    |
| FEAR    | FEARED   | 随机 | ✗    | ✗    |

AuraManager 在 apply_aura 时调 `entity.set_flag()`，remove_aura 时调 `entity.clear_flag()`。
MovementComponent 检查 ROOTED/STUNNED → 速度归零。
CombatComponent 检查 STUNNED → 不攻击。
SpellSystem 检查 SILENCED/STUNNED → 施法失败。

### 1.6 施法状态机
**TC 对应**: `Spell::prepare()` → `Spell::cast()` → `Spell::finish()`

```
IDLE → PREPARING (检查条件) → CASTING (读条) → CAST (释放效果) → FINISHED
								  ↓
							INTERRUPTED (被打断)
```

施法期间设置 CASTING flag，被打断时取消效果。
Channel 类似但持续 tick 效果，被打断提前结束。

### 1.7 统一伤害流水线
**TC 对应**: `Unit::DealDamage()`, `Unit::CalcArmorReducedDamage()`

框架层提供完整伤害链，GamePack 可 hook 任意环节：

```
CalcDamage(base, school, attacker, target)
  → apply_attacker_modifiers (% 增伤)
  → apply_target_modifiers (% 减伤)
  → apply_armor_reduction (物理护甲)
  → apply_resist (魔法抗性)
  → apply_absorb (护盾吸收)
  → apply_damage (扣血)
  → check_kill (击杀判定)
  → on_damage_dealt (触发 proc/日志/仇恨)
  → on_kill (触发击杀奖励/经验/掉落)
```

---

## Phase 2 — 游戏内容支撑

| # | 系统 | TC 对应 | 说明 | 状态 |
|---|------|---------|------|------|
| 8 | 掉落系统升级 | LootMgr | 概率组/条件掉落/多 Roll 模式 | ✅ 完成 |
| 9 | Area Aura | DynObjAura | 地面持续效果（火圈/毒池/治疗场） | ✅ 完成 |
| 10 | 免疫系统 | SchoolImmunity | 学校免疫 + 机制免疫 | ✅ 完成 |
| 11 | Respawn 系统 | SpawnGroup | 定时重生 + 刷新组 + 条件刷新 | ✅ 完成 |
| 12 | 多阵营系统 | FactionTemplate | 多阵营 + 声望 + Reaction Matrix | ✅ 完成 |
| 13 | 移动生成器 | MovementGenerator | Chase/Flee/Confused/Home/Follow 优先级栈 | ✅ 完成 |

### 9. Area Aura ✅
**文件**: `src/systems/area_aura_system.gd`
**TC 对应**: DynamicObject + AreaAura

地面持续效果系统，支持：
- 4 种内置类型：AREA_DAMAGE / AREA_HEAL / AREA_SLOW / AREA_TRIGGER_SPELL
- Enter/Exit 回调（实体进入/离开区域时触发）
- 跟随施法者模式（follow_caster）
- 完整 VFX（环形边缘粒子 + 内部填充，根据伤害学校自动着色）
- GamePack 可注册自定义 AreaAura 类型 Handler
- 硬上限保护：MAX_AREA_AURAS=50, MAX_TARGETS_PER_TICK=20

### 10. 免疫系统 ✅
**文件**: `src/systems/immunity_system.gd`
**TC 对应**: SpellSchoolImmunity + MechanicImmunity

双轨免疫系统：
- **学校免疫**：6 种伤害学校（Physical/Frost/Fire/Nature/Shadow/Holy）+ 复合掩码（ALL_MAGIC/ALL）
- **机制免疫**：STUN/ROOT/SILENCE/FEAR/SLOW/BLEED/POISON/KNOCKBACK
- ref-counted：多个来源独立授予/移除，互不干扰
- 与 DamagePipeline 集成：通过 damage_calculating 事件 hook 阻止免疫学校伤害
- 与 AuraManager 集成：apply_aura 前检查机制免疫
- CC 免疫授予时自动驱散当前对应 CC 效果

### 11. Respawn 系统 ✅
**文件**: `src/systems/respawn_system.gd`
**TC 对应**: SpawnGroup + CreatureRespawn

刷新组管理系统：
- **SpawnGroup**：注册刷新组（entries + respawn_time + max_alive + condition）
- 实体死亡后自动启动重生计时器
- 支持 max_alive 限制（同时存活数上限）
- 支持条件刷新：game_state / variable_check / min_alive
- spawn_group / despawn_group / force_respawn 完整 API
- 通过 entity.meta["spawn_group_id"] 跟踪归属

### 12. 多阵营系统 ✅
**文件**: `src/systems/faction_system.gd`
**TC 对应**: FactionTemplate + ReputationMgr

完整阵营与声望系统：
- 6 级关系等级：HOSTILE / UNFRIENDLY / NEUTRAL / FRIENDLY / HONORED / EXALTED
- **Reaction Matrix**：阵营模板定义默认关系 + 动态覆盖
- **父阵营继承**：子阵营未定义关系时向上查找
- **声望系统**：-42000 ~ +42000 声望值，自动转换为关系等级
- 向后兼容：默认注册 player/enemy/neutral，旧代码无需修改
- 实体间关系查询：are_hostile() / are_friendly()

### 13. 移动生成器 ✅
**文件**: `src/systems/movement_generator.gd`
**TC 对应**: MotionMaster / MovementGenerator

移动行为优先级栈：
- 10 种移动类型（优先级递增）：IDLE → RANDOM → WAYPOINT → FOLLOW → CHASE → FLEE → CONFUSED → POINT → HOME → EFFECT
- **优先级栈**：高优先级行为自动覆盖低优先级，完成后恢复
- RANDOM：随机闲逛（origin + radius + pause interval）
- CONFUSED：恐惧随机移动，自动响应 UnitFlags.FEARED
- EFFECT：强制位移（击退/冲锋），最高优先级
- 与 UnitFlags 联动：FEARED flag 变化自动 push/pop CONFUSED 行为
- 便捷 API：move_chase / move_flee / move_follow / move_point / move_home / move_effect

## Phase 3 — 高级游戏特性

| # | 系统 | 说明 | 状态 |
|---|------|------|------|
| 14 | CC 递减 | PvP 同类 CC 递减（全效→半效→免疫） | ✅ 完成 |
| 15 | Boss 脚本框架 | EncounterState 状态机 + 阶段切换 | ✅ 完成 |
| 16 | 任务系统 | 多目标 + 条件 + 链式 + 奖励 | ✅ 完成 |
| 17 | 成就系统 | 标准评估 + 全局进度 + 奖励 | ✅ 完成 |
| 18 | 寻路/避障 | NavigationServer2D + 路径缓存 | ✅ 完成 |

### 14. CC 递减 ✅
**文件**: `src/systems/diminishing_returns.gd`
**TC 对应**: SpellMgr DiminishingReturns

- 递减等级：100% → 50% → 25% → 免疫
- 递减分组：STUN/ROOT/SILENCE/FEAR/SLOW/KNOCKBACK/INCAPACITATE
- 18 秒衰退窗口，过期自动重置
- 与 AuraManager 集成：apply_aura 时自动查询递减持续时间
- GamePack 可注册自定义 aura 到递减分组

### 15. Boss 脚本框架 ✅
**文件**: `src/systems/encounter_system.gd`
**TC 对应**: InstanceScript / BossAI

- 战斗状态机：NOT_STARTED → IN_PROGRESS → DONE/FAILED
- 多阶段支持 + 阶段切换回调
- 定时器系统（单次/循环）
- 狂暴计时（enrage_time）
- 回调脚本：on_start/on_phase_change/on_update/on_boss_killed/on_fail/on_enrage
- Boss 死亡自动检测 → 战斗完成

### 16. 任务系统 ✅
**文件**: `src/systems/quest_system.gd`
**TC 对应**: QuestMgr

- 5 种目标类型：kill/collect/reach/interact/custom
- 链式任务：next_quest 自动解锁
- 前置任务检查：prerequisites
- 击杀事件自动推进 kill 目标
- 完整生命周期：accept → progress → complete → turn_in

### 17. 成就系统 ✅
**文件**: `src/systems/achievement_system.gd`
**TC 对应**: AchievementMgr

- 9 种标准类型：kill_creature/kill_count/deal_damage/cast_spell/reach_level/complete_quest/win_encounter/custom
- 全局统计计数器（total_kills/total_damage_dealt 等）
- 成就点数系统
- 自动监听框架事件推进标准

### 18. 寻路系统 ✅
**文件**: `src/systems/pathfinding_system.gd`
**TC 对应**: PathGenerator / MMAP

- 基于 NavigationServer2D
- 路径缓存（0.5秒 + 目标移动超50px重算）
- 动态障碍物（add/remove/update）
- 路径可达性检查
- 无导航时自动回退直线

## Phase 4 — 多人/平台级（KK 对战平台）

| # | 系统 | 说明 | 状态 |
|---|------|------|------|
| 19 | 网络同步 | ENet + 状态快照 + 客户端插值 | ✅ 完成 |
| 20 | 房间/匹配 | 房间CRUD + 就绪 + ELO + 快速匹配 | ✅ 完成 |
| 21 | 聊天系统 | 频道/密语/系统消息 + 过滤器 | ✅ 完成 |
| 22 | 重放系统 | 事件录制 + 回放 + 快进/暂停 + JSON导出 | ✅ 完成 |

### 19. 网络同步 ✅
**文件**: `src/systems/network_system.gd`
- 基于 ENet (SceneMultiplayer)，服务端权威
- 状态快照：可配 tick_rate（默认20Hz），广播实体位置/血量/flags
- 客户端插值：快照缓冲 + 延迟插值平滑移动
- RPC 消息：send_to_server / send_to_client / broadcast
- 输入缓冲（客户端预测准备）

### 20. 房间/匹配 ✅
**文件**: `src/systems/room_system.gd`
- 房间 CRUD：创建/加入/离开/密码/就绪/开始
- 自动房主转移（房主离开→第一个玩家）
- ELO 评分：标准 K=32 算法 + update_elo
- 快速匹配：按模式分组 + ELO 范围匹配 + 等待时间扩大范围

### 21. 聊天系统 ✅
**文件**: `src/systems/chat_system.gd`
- 频道：GLOBAL/ROOM/WHISPER/SYSTEM/CUSTOM
- 消息过滤器管道（敏感词/垃圾信息）
- 历史记录（每频道100条）
- 与 NetworkSystem 自动协作（有网络时自动转发）

### 22. 重放系统 ✅
**文件**: `src/systems/replay_system.gd`
- 录制：监听 EventBus 事件 → 时间线（tick+time+event+data）
- 回放：按时间触发 replay_event → GamePack 响应重现
- 控制：暂停/继续/快进(0.25x-8x)/跳转
- 序列化：Entity→ID, Vector2/Color→dict, 导出 JSON 文件
- 关键帧快照：每5秒捕获世界状态，支持回放跳转（对标 Dota2）
- RNG 种子记录：录制时保存初始随机种子（对标 SC2 deterministic replay）

### Phase 4 完善细节（2026-03-31）
- **NetworkSystem**: 全量快照→dirty-flag delta 更新（仅发送变化字段），兴趣区域裁剪（距离过远不发送）
- **RoomSystem**: +重连系统（断线保留槽位60秒）、+Party 组队队列（平均 ELO 入队）
- **ChatSystem**: +限速（5秒窗口最多8条）、+禁言（mute_player/unmute/is_muted）、+近距离频道（set_proximity_channel）
- **ReplaySystem**: +关键帧快照（每5秒）、+RNG 种子记录、+seek_to 利用关键帧快速跳转

## 额外完善（不在原始编号内）

### 掉落/背包/拾取全链路 ✅
- `src/entity/loot_entity.gd` — 地面掉落物实体（稀有度颜色圆形 + 粒子光芒 + 弹跳/浮动 + 30秒消失）
- `src/entity/components/pickup_component.gd` — 自动拾取（0.2s扫描 + 可配半径）+ 手动拾取
- `src/ui/inventory_panel.gd` — 可复用网格式背包 UI（5列 + 稀有度颜色 + tooltip + 右键装备）
- `src/systems/item_system.gd` — 补全 Inventory API（init/add/remove/get/equip_from/unequip_to）
- 完整数据流：enemy death → roll_loot → spawn_loot_entity → PickupComponent → inventory → InventoryPanel

---

## 架构对照（2026-03-31 更新）

| 维度 | TrinityCore | OpenForge | 状态 |
|------|------------|-----------|------|
| 数据存储 | MySQL + DBC | JSON | ✅ 我们更好（UGC 友好） |
| 实体模型 | 深度继承 | Tags + Components | ✅ 我们更好（更灵活） |
| 脚本系统 | C++ ScriptMgr | EventBus + Handler 注册 | ✅ 我们更好（动态） |
| AI 脚本 | SmartScript (DB) | TriggerSystem (JSON ECA) | ✅ 等价物 |
| 战斗 AI | ThreatManager + 状态机 | ThreatManager + AI 4态 + MovementGenerator | ✅ 已对齐 |
| 状态管理 | Flags + State + CC | UnitFlags bitmask + CC + DR + Immunity | ✅ 已对齐 |
| 伤害流水线 | Unit::DealDamage 链 | DamagePipeline 统一链 + hook | ✅ 已对齐 |
| 技能系统 | Spell + Aura + Proc | SpellSystem + AuraManager + ProcManager | ✅ 已对齐 |
| 掉落系统 | LootMgr | ItemSystem(概率组/条件/多Roll) + LootEntity + 背包 | ✅ 已对齐 |
| 阵营/声望 | FactionTemplate + Rep | FactionSystem + Reaction Matrix + 声望 | ✅ 已对齐 |
| Boss 脚本 | InstanceScript | EncounterSystem(阶段/定时器/回调) | ✅ 已对齐 |
| 任务/成就 | QuestMgr + AchievementMgr | QuestSystem + AchievementSystem | ✅ 已对齐 |
| 寻路 | MMAP + PathGenerator | PathfindingSystem (NavigationServer2D) | ✅ 已对齐 |
| 网络 | WorldSession + Opcodes | NetworkSystem (ENet + 快照 + 插值) | ✅ 已对齐 |
| 房间/匹配 | — (BattleNet) | RoomSystem + ELO 匹配 | ✅ 超越 |
| 重放 | — | ReplaySystem (录制/回放/导出) | ✅ 超越 |

---

## 里程碑：框架层完成（2026-03-31）

### 成果
- **67 个框架文件，15,012 行 GDScript**
- **34 个系统** + 组件 + UI + 核心引擎，覆盖 Phase 1-4 全部 22 个编号系统
- TD 可用性 **100%**，RPG 可用性 **95%+**
- 经 TrinityCore 深度对标两轮完善（Phase 3 差距修复 + Phase 4 差距修复）
- Test Arena 10 个标签页，可交互验证所有系统

### 经验教训

**1. 先广后深是错的，应该先深后广**
Phase 1-4 一口气写完 22 个系统，但每个都只是骨架。后来对标 TC 发现 Phase 3-4 全部需要二次返工。
**正确做法**：每个系统写完立即对标 TC 验证深度，通过后再做下一个。

**2. "能编译"不等于"能用"**
掉落系统"完成"了很久，但从没有地面掉落物、没有背包 UI、没有拾取机制。QuestSystem 只 emit 事件不发放奖励。
**正确做法**：系统完成 = 框架层 + EngineAPI 代理 + Test Arena 验证 + 至少一条完整链路跑通。

**3. Test Arena 是框架的命脉**
没有调试面板的系统 = 无法验收 = 不知道是否真的能用。每次补测试标签后立即发现 bug。
**正确做法**：系统实现和测试按钮同步写，不分开。

**4. Godot 特性要用而不是重造**
Camera2D 有内置 limit/smoothing，AudioServer 有 bus 系统，NavigationServer2D 有原生寻路。
第一版全部手写，第二版改用引擎原生功能后更稳定、更高效。

**5. freed instance 是 GDScript 最常见的崩溃源**
Entity 被销毁后，事件回调/遍历/类型检查（`is`运算符）都会崩。
**规则**：所有遍历用 `typeof(val) == TYPE_OBJECT` + `is_instance_valid` 前置检查。

**6. 阵营关系不传递是正确的设计决策**
一开始做了传递方案（set_allied），后来用户指出"怪物不应自动攻击功能性NPC"，回退到显式设置。
框架应保守，让 GamePack 按需组合。

---

## 框架系统完整清单（34+3）

**Phase 1 — 战斗核心（7）**: UnitFlags, TargetUtil, ThreatManager, AI状态机(EntitySystem), CC效果(AuraManager), SpellSystem, DamagePipeline

**Phase 2 — 游戏内容（6）**: AreaAuraSystem, ImmunitySystem, RespawnSystem, FactionSystem, MovementGenerator, ItemSystem

**Phase 3 — 高级特性（5）**: DiminishingReturns, EncounterSystem, QuestSystem, AchievementSystem, PathfindingSystem

**Phase 4 — 多人平台（4）**: NetworkSystem, RoomSystem, ChatSystem, ReplaySystem

**通用系统（11）**: EntitySystem, StatSystem, ResourceSystem, GridSystem, TriggerSystem, VfxSystem, BuffSystem, SaveSystem, SeasonSystem, ComponentRegistry, GamePackLoader

**额外组件/UI（3）**: LootEntity, PickupComponent, InventoryPanel

**核心引擎（5 Autoload）**: EventBus, EngineAPI, DataRegistry, SceneManager, DebugOverlay, I18nManager
