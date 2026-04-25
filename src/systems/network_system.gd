## NetworkSystem — 网络同步框架（对标 TrinityCore WorldSession / SMSG_UPDATE_OBJECT）
## 基于 Godot ENet：服务端权威 + dirty-flag delta 更新 + 兴趣区域裁剪 + 客户端插值
## 框架层系统，GamePack 通过 EventBus 和 EngineAPI 使用
class_name NetworkSystem
extends Node

# === 网络角色 ===
enum Role { NONE = 0, SERVER = 1, CLIENT = 2 }

var role: int = Role.NONE
var peer: MultiplayerPeer = null
var local_peer_id: int = 0
var connected_peers: Array[int] = []

# === 配置 ===
var server_port: int = 7777
var max_clients: int = 8
var tick_rate: int = 20
var interpolation_delay: float = 0.1
var relevance_radius: float = 1500.0  # 兴趣区域半径（超出不发送）

# === Delta 更新（对标 TC dirty-flag SMSG_UPDATE_OBJECT）===
# 上次发送的实体状态缓存：entity_runtime_id -> { field: value }
var _last_sent_state: Dictionary = {}

# === 客户端快照缓冲 ===
var _snapshot_buffer: Array[Dictionary] = []
var _server_tick: int = 0
var _tick_timer: float = 0.0
const MAX_SNAPSHOT_BUFFER := 30

# === 输入缓冲 ===
var _input_buffer: Array[Dictionary] = []

# === 每个客户端的位置（兴趣区域用）===
var _peer_positions: Dictionary = {}  # peer_id -> Vector2

func _ready() -> void:
	EngineAPI.register_system("network", self)

func _process(delta: float) -> void:
	if role == Role.SERVER:
		_tick_timer += delta
		var tick_interval: float = 1.0 / tick_rate
		if _tick_timer >= tick_interval:
			_tick_timer -= tick_interval
			_server_tick += 1
			_broadcast_delta_updates()
	elif role == Role.CLIENT:
		_interpolate_state(delta)

func _reset() -> void:
	disconnect_network()
	_snapshot_buffer.clear()
	_input_buffer.clear()
	_last_sent_state.clear()
	_peer_positions.clear()
	_server_tick = 0

# === 连接 API ===

func host_server(port: int = 0, max_players: int = 0) -> Error:
	if port > 0: server_port = port
	if max_players > 0: max_clients = max_players
	var enet := ENetMultiplayerPeer.new()
	var err: Error = enet.create_server(server_port, max_clients)
	if err != OK:
		push_error("[NetworkSystem] Server failed: %s" % error_string(err))
		return err
	peer = enet
	multiplayer.multiplayer_peer = peer
	role = Role.SERVER
	local_peer_id = 1
	_setup_signals()
	EventBus.emit_event("network_server_started", {"port": server_port})
	return OK

func join_server(address: String, port: int = 0) -> Error:
	if port > 0: server_port = port
	var enet := ENetMultiplayerPeer.new()
	var err: Error = enet.create_client(address, server_port)
	if err != OK:
		push_error("[NetworkSystem] Connect failed: %s" % error_string(err))
		return err
	peer = enet
	multiplayer.multiplayer_peer = peer
	role = Role.CLIENT
	_setup_signals()
	EventBus.emit_event("network_connecting", {"address": address, "port": server_port})
	return OK

func disconnect_network() -> void:
	if peer:
		multiplayer.multiplayer_peer = null
		peer = null
	role = Role.NONE
	local_peer_id = 0
	connected_peers.clear()
	EventBus.emit_event("network_disconnected", {})

func is_server() -> bool: return role == Role.SERVER
func is_client() -> bool: return role == Role.CLIENT
func is_connected_to_network() -> bool: return role != Role.NONE
func get_peer_id() -> int: return local_peer_id
func get_connected_peers() -> Array[int]: return connected_peers.duplicate()

# === 消息发送 ===

func send_to_server(msg_type: String, data: Dictionary) -> void:
	if role != Role.CLIENT: return
	_receive_message.rpc_id(1, msg_type, data)

func send_to_client(peer_id: int, msg_type: String, data: Dictionary) -> void:
	if role != Role.SERVER: return
	_receive_message.rpc_id(peer_id, msg_type, data)

func broadcast(msg_type: String, data: Dictionary) -> void:
	if role != Role.SERVER: return
	_receive_message.rpc(msg_type, data)

func send_input(input_data: Dictionary) -> void:
	if role != Role.CLIENT: return
	input_data["tick"] = _server_tick
	_input_buffer.append(input_data)
	if _input_buffer.size() > 60:
		_input_buffer = _input_buffer.slice(-30)
	send_to_server("player_input", input_data)

func update_peer_position(peer_id: int, pos: Vector3) -> void:
	## 服务端记录客户端位置（用于兴趣区域裁剪）
	_peer_positions[peer_id] = pos

@rpc("any_peer", "reliable")
func _receive_message(msg_type: String, data: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	# 客户端位置上报
	if msg_type == "position_update" and role == Role.SERVER:
		var pos_x: float = data.get("x", 0)
		var pos_y: float = data.get("y", 0)
		var pos_z: float = data.get("z", 0)
		_peer_positions[sender_id] = Vector3(pos_x, pos_y, pos_z)
	EventBus.emit_event("network_message", {
		"sender_id": sender_id, "msg_type": msg_type, "data": data,
	})

# === Delta 更新（对标 TC dirty-flag，仅发送变化字段）===

func _broadcast_delta_updates() -> void:
	## 服务端：为每个客户端生成定制的 delta 包（兴趣区域 + dirty 字段）
	var all_entities: Array = EngineAPI.find_entities_by_tag("networked")
	var now: float = Time.get_ticks_msec() / 1000.0
	for pid in connected_peers:
		var peer_pos: Vector3 = _peer_positions.get(pid, Vector3.ZERO)
		var delta_entities: Dictionary = {}
		for e in all_entities:
			if not is_instance_valid(e) or not (e is GameEntity):
				continue
			var ge: GameEntity = e as GameEntity
			# 兴趣区域裁剪（对标 TC visibility grid）
			if relevance_radius > 0 and peer_pos != Vector3.ZERO:
				if ge.global_position.distance_to(peer_pos) > relevance_radius:
					continue
			var rid: int = ge.runtime_id
			var current := _snapshot_entity(ge)
			var prev: Dictionary = _last_sent_state.get(rid, {})
			# Dirty-flag：仅发送变化的字段
			if prev.is_empty():
				delta_entities[rid] = current  # 全量（新实体）
				delta_entities[rid]["_full"] = true
			else:
				var diff: Dictionary = {}
				for key in current:
					if not prev.has(key) or prev[key] != current[key]:
						diff[key] = current[key]
				if not diff.is_empty():
					delta_entities[rid] = diff
			_last_sent_state[rid] = current
		if not delta_entities.is_empty():
			send_to_client(pid, "delta_update", {
				"tick": _server_tick, "timestamp": now,
				"entities": delta_entities,
			})

func _snapshot_entity(ge: GameEntity) -> Dictionary:
	var health: Node = EngineAPI.get_component(ge, "health")
	return {
		"pos_x": snappedi(int(ge.global_position.x), 1),
		"pos_y": snappedi(int(ge.global_position.y), 1),
		"hp": snappedf(health.current_hp, 0.1) if health else 0.0,
		"max_hp": health.max_hp if health else 0.0,
		"flags": ge.unit_flags,
		"alive": ge.is_alive,
		"def_id": ge.def_id,
		"faction": ge.faction,
	}

# === 重连快照协议（对标 KK 对战平台 reconnect snapshot）===

func send_full_state_to_peer(peer_id: int) -> void:
	## 服务端 → 重连客户端：发送完整世界状态快照
	## 客户端用此快照重建整个游戏画面，然后恢复接收 delta 更新
	if role != Role.SERVER:
		return
	var snapshot := _capture_full_snapshot()
	send_to_client(peer_id, "full_state_snapshot", snapshot)
	# 重置该客户端的 dirty 缓存（下次 delta 从全新开始）
	_last_sent_state.clear()
	EventBus.emit_event("reconnect_snapshot_sent", {
		"peer_id": peer_id,
		"entity_count": snapshot.get("entities", {}).size(),
	})

func _capture_full_snapshot() -> Dictionary:
	## 捕获完整世界状态（所有实体 + 资源 + 游戏状态）
	var entities: Dictionary = {}
	var all: Array = EngineAPI.find_entities_by_tag("networked")
	for e in all:
		if not is_instance_valid(e) or not (e is GameEntity):
			continue
		var ge: GameEntity = e as GameEntity
		var data := _snapshot_entity(ge)
		data["_full"] = true
		data["tags"] = Array(ge.tags)
		# Aura 状态
		var aura_mgr: Node = EngineAPI.get_system("aura")
		if aura_mgr:
			var auras: Array = aura_mgr.call("get_auras_on", ge)
			var aura_list: Array = []
			for aura in auras:
				aura_list.append({
					"aura_id": aura.get("aura_id", ""),
					"aura_type": aura.get("aura_type", ""),
					"remaining": aura.get("remaining", 0),
					"stacks": aura.get("stacks", 1),
				})
			data["auras"] = aura_list
		entities[ge.runtime_id] = data
	# 资源状态
	var resources: Dictionary = {}
	var res_sys: Node = EngineAPI.get_system("resource")
	if res_sys and res_sys.has_method("get_all_resources"):
		resources = res_sys.call("get_all_resources")
	return {
		"tick": _server_tick,
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"game_state": EngineAPI.get_game_state(),
		"entities": entities,
		"resources": resources,
		"is_reconnect": true,
	}

# === 客户端快照插值 ===

func apply_snapshot(snapshot: Dictionary) -> void:
	_snapshot_buffer.append(snapshot)
	if _snapshot_buffer.size() > MAX_SNAPSHOT_BUFFER:
		_snapshot_buffer = _snapshot_buffer.slice(-MAX_SNAPSHOT_BUFFER)

func _interpolate_state(_delta: float) -> void:
	if _snapshot_buffer.size() < 2:
		return
	var render_time: float = Time.get_ticks_msec() / 1000.0 - interpolation_delay
	var prev: Dictionary = _snapshot_buffer[0]
	var next: Dictionary = _snapshot_buffer[0]
	for i in range(_snapshot_buffer.size() - 1):
		if _snapshot_buffer[i]["timestamp"] <= render_time and _snapshot_buffer[i + 1]["timestamp"] >= render_time:
			prev = _snapshot_buffer[i]
			next = _snapshot_buffer[i + 1]
			break
	var t_range: float = next["timestamp"] - prev["timestamp"]
	if t_range <= 0:
		return
	var t: float = clampf((render_time - prev["timestamp"]) / t_range, 0.0, 1.0)
	var prev_ents: Dictionary = prev.get("entities", {})
	var next_ents: Dictionary = next.get("entities", {})
	for eid in next_ents:
		if not prev_ents.has(eid):
			continue
		var p: Dictionary = prev_ents[eid]
		var n: Dictionary = next_ents[eid]
		var entity: Node3D = EngineAPI.get_entity_by_id(eid)
		if entity and is_instance_valid(entity):
			var px: float = p.get("pos_x", n.get("pos_x", 0))
			var py: float = p.get("pos_y", n.get("pos_y", 0))
			var pz: float = p.get("pos_z", n.get("pos_z", 0))
			entity.global_position = Vector3(
				lerpf(px, n.get("pos_x", px), t),
				lerpf(py, n.get("pos_y", py), t),
				lerpf(pz, n.get("pos_z", pz), t))

# === 信号 ===

func _setup_signals() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(id: int) -> void:
	connected_peers.append(id)
	EventBus.emit_event("network_peer_connected", {"peer_id": id})

func _on_peer_disconnected(id: int) -> void:
	connected_peers.erase(id)
	_peer_positions.erase(id)
	EventBus.emit_event("network_peer_disconnected", {"peer_id": id})

func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	EventBus.emit_event("network_connected", {"peer_id": local_peer_id})

func _on_connection_failed() -> void:
	EventBus.emit_event("network_connection_failed", {})
	disconnect_network()

func _on_server_disconnected() -> void:
	EventBus.emit_event("network_server_disconnected", {})
	disconnect_network()
