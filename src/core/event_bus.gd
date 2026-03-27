## 全局事件总线 - 解耦系统间通信
## 所有系统通过 EventBus 发送/监听事件，避免直接引用
extends Node

# === 游戏流程 ===
signal game_started
signal game_paused
signal game_resumed
signal game_over(victory: bool)
signal wave_started(wave_index: int)
signal wave_completed(wave_index: int)
signal all_waves_completed

# === 经济系统 ===
signal gold_changed(current: int, delta: int)
signal income_tick(amount: int)

# === 战斗系统 ===
signal enemy_spawned(enemy: Node2D)
signal enemy_reached_end(enemy: Node2D)
signal enemy_killed(enemy: Node2D, killer: Node2D)
signal tower_placed(tower: Node2D, grid_pos: Vector2i)
signal tower_sold(tower: Node2D, refund: int)
signal tower_upgraded(tower: Node2D, new_level: int)
signal projectile_hit(projectile: Node2D, target: Node2D, damage: float)

# === Buff/效果 ===
signal buff_applied(target: Node2D, buff_id: String)
signal buff_removed(target: Node2D, buff_id: String)

# === 玩家状态 ===
signal lives_changed(current: int, delta: int)
signal player_level_up(new_level: int)

# === UI ===
signal tile_selected(grid_pos: Vector2i)
signal tile_deselected
signal tower_selection_changed(tower: Node2D)
signal build_menu_requested(grid_pos: Vector2i, available_towers: Array)

# === 地图/数据 ===
signal map_loaded(map_id: String)
signal map_pack_loaded(pack_id: String)
