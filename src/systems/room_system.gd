## RoomSystem — 房间/匹配系统（对标 KK 对战平台 + WoW LFG）
## 房间创建/加入/离开 + 快速匹配 + ELO 评分
## 与 NetworkSystem 协作：房间就绪后启动网络连接
## 框架层系统，零游戏知识
class_name RoomSystem
extends Node

# === 房间状态 ===
enum RoomState {
	WAITING = 0,    # 等待玩家
	READY = 1,      # 全员就绪
	IN_GAME = 2,    # 游戏中
	FINISHED = 3,   # 已结束
}

# === 匹配状态 ===
enum MatchState {
	IDLE = 0,
	SEARCHING = 1,
	FOUND = 2,
}

# === 数据存储 ===
# 房间列表: room_id -> RoomData
var _rooms: Dictionary = {}
var _next_room_id: int = 1
# 当前玩家所在房间
var current_room_id: String = ""
# 匹配队列: [{ "player_id": String, "elo": float, "game_mode": String, "enqueue_time": float }]
var _match_queue: Array[Dictionary] = []
var match_state: int = MatchState.IDLE
# ELO: player_id -> float
var _elo_ratings: Dictionary = {}

const DEFAULT_ELO := 1000.0
const ELO_K_FACTOR := 32.0
const MATCH_ELO_RANGE := 200.0  # 初始匹配范围
const MATCH_RANGE_EXPAND_RATE := 50.0  # 每秒扩大范围
const MATCH_CHECK_INTERVAL := 1.0

var _match_timer: float = 0.0

func _ready() -> void:
	EngineAPI.register_system("room", self)

func _process(delta: float) -> void:
	if _match_queue.is_empty():
		return
	_match_timer += delta
	if _match_timer >= MATCH_CHECK_INTERVAL:
		_match_timer -= MATCH_CHECK_INTERVAL
		_try_match()

func _reset() -> void:
	_rooms.clear()
	_match_queue.clear()
	current_room_id = ""
	match_state = MatchState.IDLE
	_next_room_id = 1

# === 房间 API ===

func create_room(params: Dictionary) -> String:
	## 创建房间
	## params: { "host_id": String, "game_mode": String, "max_players": int,
	##           "name": String, "password": String, "settings": Dictionary }
	var room_id := "room_%d" % _next_room_id
	_next_room_id += 1
	var room := {
		"room_id": room_id,
		"host_id": params.get("host_id", ""),
		"name": params.get("name", "Room %d" % (_next_room_id - 1)),
		"game_mode": params.get("game_mode", "default"),
		"max_players": params.get("max_players", 4),
		"password": params.get("password", ""),
		"state": RoomState.WAITING,
		"players": {},  # player_id -> { "name": String, "ready": bool, "team": int }
		"settings": params.get("settings", {}),
		"created_at": Time.get_ticks_msec() / 1000.0,
	}
	# 房主自动加入
	var host_id: String = params.get("host_id", "")
	if host_id != "":
		room["players"][host_id] = {
			"name": params.get("host_name", host_id),
			"ready": false, "team": 0,
		}
	_rooms[room_id] = room
	EventBus.emit_event("room_created", {"room_id": room_id, "host_id": host_id})
	return room_id

func join_room(room_id: String, player_id: String, player_name: String = "", password: String = "") -> bool:
	var room: Dictionary = _rooms.get(room_id, {})
	if room.is_empty():
		return false
	if room["state"] != RoomState.WAITING:
		return false
	if room["players"].size() >= room["max_players"]:
		return false
	if room["password"] != "" and room["password"] != password:
		return false
	room["players"][player_id] = {
		"name": player_name if player_name != "" else player_id,
		"ready": false, "team": 0,
	}
	current_room_id = room_id
	EventBus.emit_event("room_player_joined", {
		"room_id": room_id, "player_id": player_id,
	})
	return true

func leave_room(room_id: String, player_id: String) -> void:
	var room: Dictionary = _rooms.get(room_id, {})
	if room.is_empty():
		return
	room["players"].erase(player_id)
	if current_room_id == room_id:
		current_room_id = ""
	EventBus.emit_event("room_player_left", {
		"room_id": room_id, "player_id": player_id,
	})
	# 房间空了 → 删除
	if room["players"].is_empty():
		_rooms.erase(room_id)
		EventBus.emit_event("room_destroyed", {"room_id": room_id})
	elif room["host_id"] == player_id:
		# 房主离开 → 转移房主
		var new_host: String = room["players"].keys()[0]
		room["host_id"] = new_host
		EventBus.emit_event("room_host_changed", {
			"room_id": room_id, "new_host": new_host,
		})

func set_ready(room_id: String, player_id: String, is_ready: bool) -> void:
	var room: Dictionary = _rooms.get(room_id, {})
	if room.is_empty() or not room["players"].has(player_id):
		return
	room["players"][player_id]["ready"] = is_ready
	EventBus.emit_event("room_player_ready", {
		"room_id": room_id, "player_id": player_id, "ready": is_ready,
	})
	# 检查全员就绪
	if _all_ready(room):
		room["state"] = RoomState.READY
		EventBus.emit_event("room_all_ready", {"room_id": room_id})

func start_game(room_id: String) -> bool:
	## 房主启动游戏
	var room: Dictionary = _rooms.get(room_id, {})
	if room.is_empty() or room["state"] != RoomState.READY:
		return false
	room["state"] = RoomState.IN_GAME
	EventBus.emit_event("room_game_started", {
		"room_id": room_id,
		"players": room["players"].duplicate(),
		"game_mode": room["game_mode"],
		"settings": room["settings"],
	})
	return true

func end_game(room_id: String) -> void:
	var room: Dictionary = _rooms.get(room_id, {})
	if not room.is_empty():
		room["state"] = RoomState.FINISHED
		EventBus.emit_event("room_game_ended", {"room_id": room_id})

func set_team(room_id: String, player_id: String, team: int) -> void:
	var room: Dictionary = _rooms.get(room_id, {})
	if not room.is_empty() and room["players"].has(player_id):
		room["players"][player_id]["team"] = team

# === 查询 ===

func get_room(room_id: String) -> Dictionary:
	return _rooms.get(room_id, {})

func get_room_list(game_mode: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rid in _rooms:
		var room: Dictionary = _rooms[rid]
		if room["state"] != RoomState.WAITING:
			continue
		if game_mode != "" and room["game_mode"] != game_mode:
			continue
		if room["password"] != "":
			continue  # 隐藏有密码的房间（或标记）
		result.append({
			"room_id": rid,
			"name": room["name"],
			"game_mode": room["game_mode"],
			"players": room["players"].size(),
			"max_players": room["max_players"],
		})
	return result

func get_player_count(room_id: String) -> int:
	return _rooms.get(room_id, {}).get("players", {}).size()

# === 匹配 API ===

func enqueue_match(player_id: String, game_mode: String = "default") -> void:
	## 加入匹配队列
	for entry in _match_queue:
		if entry["player_id"] == player_id:
			return  # 已在队列
	_match_queue.append({
		"player_id": player_id,
		"elo": get_elo(player_id),
		"game_mode": game_mode,
		"enqueue_time": Time.get_ticks_msec() / 1000.0,
	})
	match_state = MatchState.SEARCHING
	EventBus.emit_event("match_searching", {"player_id": player_id})

func dequeue_match(player_id: String) -> void:
	for i in range(_match_queue.size() - 1, -1, -1):
		if _match_queue[i]["player_id"] == player_id:
			_match_queue.remove_at(i)
	if _match_queue.is_empty():
		match_state = MatchState.IDLE

# === ELO ===

func get_elo(player_id: String) -> float:
	return _elo_ratings.get(player_id, DEFAULT_ELO)

func set_elo(player_id: String, elo: float) -> void:
	_elo_ratings[player_id] = elo

func update_elo(winner_id: String, loser_id: String) -> void:
	## 标准 ELO 计算
	var ra: float = get_elo(winner_id)
	var rb: float = get_elo(loser_id)
	var ea: float = 1.0 / (1.0 + pow(10.0, (rb - ra) / 400.0))
	var eb: float = 1.0 - ea
	set_elo(winner_id, ra + ELO_K_FACTOR * (1.0 - ea))
	set_elo(loser_id, rb + ELO_K_FACTOR * (0.0 - eb))
	EventBus.emit_event("elo_updated", {
		"winner": winner_id, "loser": loser_id,
		"winner_elo": get_elo(winner_id), "loser_elo": get_elo(loser_id),
	})

# === 重连系统（对标 WoW reconnect session）===

# 断线玩家保留槽位: room_id -> { player_id -> { "expire": float, "data": Dictionary } }
var _reconnect_slots: Dictionary = {}
const RECONNECT_TIMEOUT := 60.0  # 保留 60 秒

func handle_disconnect(room_id: String, player_id: String) -> void:
	## 玩家断线：保留槽位而非直接移除
	var room: Dictionary = _rooms.get(room_id, {})
	if room.is_empty() or room["state"] != RoomState.IN_GAME:
		leave_room(room_id, player_id)
		return
	# 标记为断线，保留数据
	if not _reconnect_slots.has(room_id):
		_reconnect_slots[room_id] = {}
	_reconnect_slots[room_id][player_id] = {
		"expire": Time.get_ticks_msec() / 1000.0 + RECONNECT_TIMEOUT,
		"data": room["players"].get(player_id, {}),
	}
	room["players"][player_id]["disconnected"] = true
	EventBus.emit_event("room_player_disconnected", {
		"room_id": room_id, "player_id": player_id,
		"timeout": RECONNECT_TIMEOUT,
	})

func try_reconnect(room_id: String, player_id: String) -> bool:
	## 玩家重连：恢复槽位
	if not _reconnect_slots.has(room_id) or not _reconnect_slots[room_id].has(player_id):
		return false
	var slot: Dictionary = _reconnect_slots[room_id][player_id]
	if Time.get_ticks_msec() / 1000.0 > slot["expire"]:
		_reconnect_slots[room_id].erase(player_id)
		return false
	var room: Dictionary = _rooms.get(room_id, {})
	if room.is_empty():
		return false
	room["players"][player_id] = slot["data"]
	room["players"][player_id]["disconnected"] = false
	_reconnect_slots[room_id].erase(player_id)
	current_room_id = room_id
	# 自动触发 NetworkSystem 发送完整快照给重连客户端
	var net_sys: Node = EngineAPI.get_system("network")
	if net_sys and net_sys.call("is_server"):
		# player_id → peer_id 映射（通过 room player data）
		var peer_id: int = room["players"][player_id].get("peer_id", 0)
		if peer_id > 0:
			net_sys.call("send_full_state_to_peer", peer_id)
	EventBus.emit_event("room_player_reconnected", {
		"room_id": room_id, "player_id": player_id,
	})
	return true

# === Party/组队 队列（对标 WoW Group Finder）===

# party_id -> [player_id, ...]
var _parties: Dictionary = {}
var _next_party_id: int = 1

func create_party(leader_id: String) -> String:
	var party_id := "party_%d" % _next_party_id
	_next_party_id += 1
	_parties[party_id] = [leader_id]
	return party_id

func join_party(party_id: String, player_id: String) -> bool:
	if not _parties.has(party_id):
		return false
	if player_id in _parties[party_id]:
		return false
	_parties[party_id].append(player_id)
	return true

func leave_party(party_id: String, player_id: String) -> void:
	if _parties.has(party_id):
		_parties[party_id].erase(player_id)
		if _parties[party_id].is_empty():
			_parties.erase(party_id)

func enqueue_party(party_id: String, game_mode: String = "default") -> void:
	## 组队匹配：按队伍平均 ELO 入队
	if not _parties.has(party_id):
		return
	var members: Array = _parties[party_id]
	var total_elo := 0.0
	for pid in members:
		total_elo += get_elo(pid)
	var avg_elo: float = total_elo / members.size() if members.size() > 0 else DEFAULT_ELO
	# 以队长身份入队，附带队伍信息
	_match_queue.append({
		"player_id": members[0],  # 队长
		"party_id": party_id,
		"party_members": members.duplicate(),
		"elo": avg_elo,
		"game_mode": game_mode,
		"enqueue_time": Time.get_ticks_msec() / 1000.0,
	})
	match_state = MatchState.SEARCHING

# === 内部 ===

func _all_ready(room: Dictionary) -> bool:
	if room["players"].size() < 2:
		return false
	for pid in room["players"]:
		if not room["players"][pid]["ready"]:
			return false
	return true

func _try_match() -> void:
	## 匹配算法：按 ELO 范围匹配同模式玩家
	if _match_queue.size() < 2:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	# 按 game_mode 分组
	var by_mode: Dictionary = {}
	for entry in _match_queue:
		var mode: String = entry["game_mode"]
		if not by_mode.has(mode):
			by_mode[mode] = []
		by_mode[mode].append(entry)
	for mode in by_mode:
		var pool: Array = by_mode[mode]
		if pool.size() < 2:
			continue
		# 按 ELO 排序
		pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["elo"] < b["elo"])
		# 相邻配对
		var matched: Array = []
		var i := 0
		while i < pool.size() - 1:
			var a: Dictionary = pool[i]
			var b: Dictionary = pool[i + 1]
			var wait_a: float = now - a["enqueue_time"]
			var wait_b: float = now - b["enqueue_time"]
			var max_wait: float = maxf(wait_a, wait_b)
			var allowed_range: float = MATCH_ELO_RANGE + max_wait * MATCH_RANGE_EXPAND_RATE
			if absf(a["elo"] - b["elo"]) <= allowed_range:
				matched.append([a, b])
				i += 2
			else:
				i += 1
		# 处理配对
		for pair in matched:
			var a: Dictionary = pair[0]
			var b: Dictionary = pair[1]
			_match_queue.erase(a)
			_match_queue.erase(b)
			# 创建房间
			var room_id: String = create_room({
				"host_id": a["player_id"],
				"game_mode": mode,
				"max_players": 2,
				"name": "Match %d" % _next_room_id,
			})
			join_room(room_id, b["player_id"])
			EventBus.emit_event("match_found", {
				"room_id": room_id,
				"players": [a["player_id"], b["player_id"]],
				"elo_diff": absf(a["elo"] - b["elo"]),
			})
	if _match_queue.is_empty():
		match_state = MatchState.IDLE
