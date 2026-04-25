## ChatSystem — 聊天系统（对标 TrinityCore ChatHandler / Channel）
## 频道聊天 + 密语 + 队伍/房间聊天 + 消息过滤
## 框架层系统，与 NetworkSystem 协作发送网络消息
class_name ChatSystem
extends Node

# === 频道类型 ===
enum ChannelType {
	GLOBAL = 0,   # 全局频道
	ROOM = 1,     # 房间/队伍
	WHISPER = 2,  # 私聊
	SYSTEM = 3,   # 系统消息
	CUSTOM = 4,   # 自定义频道
}

# === 频道定义 ===
# channel_id -> ChannelData
var _channels: Dictionary = {}
# player_id -> [channel_id, ...]（订阅列表）
var _subscriptions: Dictionary = {}
# 消息历史: channel_id -> [ChatMessage, ...]
var _history: Dictionary = {}

const MAX_HISTORY_PER_CHANNEL := 100
const MAX_MESSAGE_LENGTH := 500

# 消息过滤回调: Array[Callable(message: Dictionary) -> Dictionary]
# 返回修改后的 message，或空 Dictionary 表示过滤掉
var _filters: Array[Callable] = []

# === 限速（对标 TC spam protection）===
var _rate_limits: Dictionary = {}  # player_id -> { "last_time": float, "count": int, "window_start": float }
const RATE_LIMIT_WINDOW := 5.0     # 5 秒窗口
const RATE_LIMIT_MAX := 8          # 窗口内最多 8 条

# === 禁言（对标 TC GM mute）===
var _muted_players: Dictionary = {}  # player_id -> { "expire": float, "reason": String }

# === 近距离频道配置 ===
var _proximity_channels: Dictionary = {}  # channel_id -> { "radius": float }

func _ready() -> void:
	EngineAPI.register_system("chat", self)
	# 注册默认频道
	create_channel("global", ChannelType.GLOBAL)
	create_channel("system", ChannelType.SYSTEM)

func _reset() -> void:
	_channels.clear()
	_subscriptions.clear()
	_history.clear()
	_filters.clear()
	create_channel("global", ChannelType.GLOBAL)
	create_channel("system", ChannelType.SYSTEM)

# === 频道 API ===

func create_channel(channel_id: String, channel_type: int = ChannelType.CUSTOM) -> void:
	_channels[channel_id] = {
		"channel_id": channel_id,
		"type": channel_type,
		"members": {},  # player_id -> true
	}
	_history[channel_id] = []

func delete_channel(channel_id: String) -> void:
	if channel_id in ["global", "system"]:
		return  # 保护默认频道
	_channels.erase(channel_id)
	_history.erase(channel_id)
	# 移除所有订阅
	for pid in _subscriptions:
		_subscriptions[pid].erase(channel_id)

func join_channel(player_id: String, channel_id: String) -> bool:
	if not _channels.has(channel_id):
		return false
	_channels[channel_id]["members"][player_id] = true
	if not _subscriptions.has(player_id):
		_subscriptions[player_id] = []
	if channel_id not in _subscriptions[player_id]:
		_subscriptions[player_id].append(channel_id)
	return true

func leave_channel(player_id: String, channel_id: String) -> void:
	if _channels.has(channel_id):
		_channels[channel_id]["members"].erase(player_id)
	if _subscriptions.has(player_id):
		_subscriptions[player_id].erase(channel_id)

func get_channel_members(channel_id: String) -> Array[String]:
	var result: Array[String] = []
	if _channels.has(channel_id):
		for pid in _channels[channel_id]["members"]:
			result.append(pid)
	return result

# === 消息 API ===

func send_message(sender_id: String, channel_id: String, text: String) -> bool:
	## 发送频道消息
	if not _channels.has(channel_id):
		return false
	if text.length() > MAX_MESSAGE_LENGTH:
		text = text.left(MAX_MESSAGE_LENGTH)
	if text.strip_edges() == "":
		return false
	# 禁言检查
	if is_muted(sender_id):
		EventBus.emit_event("chat_muted", {"sender_id": sender_id})
		return false
	# 限速检查
	if not _check_rate_limit(sender_id):
		EventBus.emit_event("chat_rate_limited", {"sender_id": sender_id})
		return false
	var message := {
		"sender_id": sender_id,
		"channel_id": channel_id,
		"text": text,
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"type": _channels[channel_id]["type"],
	}
	# 过滤
	message = _apply_filters(message)
	if message.is_empty():
		return false
	# 存储历史
	_add_to_history(channel_id, message)
	# 通知
	EventBus.emit_event("chat_message", message)
	# 网络发送（如果有 NetworkSystem）
	var net: Node = EngineAPI.get_system("network")
	if net and net.call("is_server"):
		net.call("broadcast", "chat", message)
	elif net and net.call("is_client"):
		net.call("send_to_server", "chat", message)
	return true

func send_whisper(sender_id: String, target_id: String, text: String) -> bool:
	## 私聊
	if text.strip_edges() == "":
		return false
	if text.length() > MAX_MESSAGE_LENGTH:
		text = text.left(MAX_MESSAGE_LENGTH)
	var message := {
		"sender_id": sender_id,
		"target_id": target_id,
		"text": text,
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"type": ChannelType.WHISPER,
		"channel_id": "whisper_%s_%s" % [sender_id, target_id],
	}
	message = _apply_filters(message)
	if message.is_empty():
		return false
	EventBus.emit_event("chat_whisper", message)
	return true

func send_system_message(text: String) -> void:
	## 系统公告
	var message := {
		"sender_id": "SYSTEM",
		"channel_id": "system",
		"text": text,
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"type": ChannelType.SYSTEM,
	}
	_add_to_history("system", message)
	EventBus.emit_event("chat_message", message)

# === 过滤 ===

func add_filter(filter_fn: Callable) -> void:
	## 注册消息过滤器（敏感词/垃圾信息等）
	_filters.append(filter_fn)

func _apply_filters(message: Dictionary) -> Dictionary:
	for f in _filters:
		if f.is_valid():
			message = f.call(message)
			if message.is_empty():
				return {}
	return message

# === 历史查询 ===

func get_history(channel_id: String, count: int = 50) -> Array[Dictionary]:
	if not _history.has(channel_id):
		return []
	var msgs: Array = _history[channel_id]
	var start: int = maxi(0, msgs.size() - count)
	var result: Array[Dictionary] = []
	for i in range(start, msgs.size()):
		result.append(msgs[i])
	return result

func get_subscribed_channels(player_id: String) -> Array[String]:
	if not _subscriptions.has(player_id):
		return []
	return _subscriptions[player_id].duplicate()

func _add_to_history(channel_id: String, message: Dictionary) -> void:
	if not _history.has(channel_id):
		_history[channel_id] = []
	_history[channel_id].append(message)
	if _history[channel_id].size() > MAX_HISTORY_PER_CHANNEL:
		_history[channel_id] = _history[channel_id].slice(-MAX_HISTORY_PER_CHANNEL)

# === 禁言（对标 TC GM mute）===

func mute_player(player_id: String, duration: float, reason: String = "") -> void:
	_muted_players[player_id] = {
		"expire": Time.get_ticks_msec() / 1000.0 + duration,
		"reason": reason,
	}
	EventBus.emit_event("chat_player_muted", {
		"player_id": player_id, "duration": duration, "reason": reason,
	})

func unmute_player(player_id: String) -> void:
	_muted_players.erase(player_id)

func is_muted(player_id: String) -> bool:
	if not _muted_players.has(player_id):
		return false
	if Time.get_ticks_msec() / 1000.0 > _muted_players[player_id]["expire"]:
		_muted_players.erase(player_id)
		return false
	return true

# === 限速（对标 TC spam protection）===

func _check_rate_limit(player_id: String) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	if not _rate_limits.has(player_id):
		_rate_limits[player_id] = {"window_start": now, "count": 1}
		return true
	var rl: Dictionary = _rate_limits[player_id]
	if now - rl["window_start"] > RATE_LIMIT_WINDOW:
		rl["window_start"] = now
		rl["count"] = 1
		return true
	rl["count"] += 1
	return rl["count"] <= RATE_LIMIT_MAX

# === 近距离频道（对标 TC /say /yell）===

func set_proximity_channel(channel_id: String, radius: float) -> void:
	## 将频道设为近距离模式（仅 radius 内的实体能收到）
	_proximity_channels[channel_id] = {"radius": radius}

func is_proximity_channel(channel_id: String) -> bool:
	return _proximity_channels.has(channel_id)
