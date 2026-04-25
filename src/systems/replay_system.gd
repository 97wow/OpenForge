## ReplaySystem — 重放系统（对标 WoW Combat Log Replay / SC2 Replay）
## 录制：捕获关键事件帧 → 存储为时间线
## 回放：按时间线重新触发事件 → 确定性重现
## 框架层系统，GamePack 可定义需要录制的事件类型
class_name ReplaySystem
extends Node

# === 录制状态 ===
enum State {
	IDLE = 0,
	RECORDING = 1,
	PLAYING = 2,
	PAUSED = 3,
}

var state: int = State.IDLE

# === 录制数据 ===
var _timeline: Array[Dictionary] = []  # [{tick, time, event, data}]
var _record_start_time: float = 0.0
var _record_tick: int = 0

# === 关键帧快照（对标 Dota2 keyframe，支持跳转）===
var _keyframes: Array[Dictionary] = []  # [{tick, time, snapshot}]
const KEYFRAME_INTERVAL := 5.0  # 每 5 秒一个关键帧
var _last_keyframe_time: float = 0.0

# === RNG 种子记录（对标 SC2 deterministic replay）===
var _rng_seed: int = 0
var _rng_events: Array[Dictionary] = []  # [{tick, seed}]

# === 回放状态 ===
var _playback_index: int = 0
var _playback_time: float = 0.0
var _playback_speed: float = 1.0

# === 配置 ===
# 需要录制的事件类型
var _recorded_events: Dictionary = {}  # event_name -> true
const DEFAULT_RECORDED_EVENTS := [
	"entity_spawned", "entity_destroyed", "entity_killed",
	"entity_damaged", "entity_healed",
	"spell_cast", "spell_interrupted",
	"aura_applied", "aura_removed",
	"ai_entered_combat", "ai_enter_evade",
	"loot_picked_up", "item_equipped",
]

# 元数据
var _metadata: Dictionary = {}  # game_mode, map, duration, date, etc.

func _ready() -> void:
	EngineAPI.register_system("replay", self)

func _process(delta: float) -> void:
	match state:
		State.RECORDING:
			_record_tick += 1
			# 周期性关键帧快照
			var elapsed: float = Time.get_ticks_msec() / 1000.0 - _record_start_time
			if elapsed - _last_keyframe_time >= KEYFRAME_INTERVAL:
				_last_keyframe_time = elapsed
				_capture_keyframe(elapsed)
		State.PLAYING:
			_playback_time += delta * _playback_speed
			_advance_playback()

func _reset() -> void:
	stop()
	_timeline.clear()
	_metadata.clear()
	_recorded_events.clear()

# === 录制 API ===

func start_recording(metadata: Dictionary = {}) -> void:
	## 开始录制
	if state != State.IDLE:
		stop()
	_timeline.clear()
	_keyframes.clear()
	_rng_events.clear()
	_last_keyframe_time = 0.0
	_metadata = metadata.duplicate()
	_metadata["start_time"] = Time.get_datetime_string_from_system()
	_record_start_time = Time.get_ticks_msec() / 1000.0
	_record_tick = 0
	# 记录初始 RNG 种子
	_rng_seed = randi()
	_metadata["rng_seed"] = _rng_seed
	state = State.RECORDING
	# 初始关键帧
	_capture_keyframe(0.0)
	# 注册默认事件监听
	if _recorded_events.is_empty():
		for event_name in DEFAULT_RECORDED_EVENTS:
			register_event(event_name)
	EventBus.emit_event("replay_recording_started", _metadata)

func stop_recording() -> Dictionary:
	## 停止录制，返回回放数据
	if state != State.RECORDING:
		return {}
	state = State.IDLE
	_metadata["duration"] = Time.get_ticks_msec() / 1000.0 - _record_start_time
	_metadata["total_ticks"] = _record_tick
	_metadata["event_count"] = _timeline.size()
	# 取消所有事件监听
	for event_name in _recorded_events:
		EventBus.disconnect_event(event_name, _on_recorded_event)
	_recorded_events.clear()
	EventBus.emit_event("replay_recording_stopped", _metadata)
	return get_replay_data()

func register_event(event_name: String) -> void:
	## 注册需要录制的事件类型
	if _recorded_events.has(event_name):
		return
	_recorded_events[event_name] = true
	EventBus.connect_event(event_name, _on_recorded_event.bind(event_name))

func _on_recorded_event(data: Dictionary, event_name: String) -> void:
	if state != State.RECORDING:
		return
	# 序列化：将实体引用转为 ID/def_id（避免存储 Node 引用）
	var serialized: Dictionary = _serialize_event_data(data)
	_timeline.append({
		"tick": _record_tick,
		"time": Time.get_ticks_msec() / 1000.0 - _record_start_time,
		"event": event_name,
		"data": serialized,
	})

# === 回放 API ===

func start_playback(speed: float = 1.0) -> void:
	## 开始回放
	if _timeline.is_empty():
		return
	state = State.PLAYING
	_playback_index = 0
	_playback_time = 0.0
	_playback_speed = speed
	EventBus.emit_event("replay_playback_started", {
		"speed": speed, "total_events": _timeline.size(),
	})

func pause_playback() -> void:
	if state == State.PLAYING:
		state = State.PAUSED
		EventBus.emit_event("replay_playback_paused", {})

func resume_playback() -> void:
	if state == State.PAUSED:
		state = State.PLAYING
		EventBus.emit_event("replay_playback_resumed", {})

func stop() -> void:
	if state == State.RECORDING:
		for event_name in _recorded_events:
			EventBus.disconnect_event(event_name, _on_recorded_event)
		_recorded_events.clear()
	state = State.IDLE
	_playback_index = 0
	_playback_time = 0.0

func set_playback_speed(speed: float) -> void:
	_playback_speed = clampf(speed, 0.25, 8.0)

func seek_to(time: float) -> void:
	## 跳转到指定时间点（利用关键帧快速定位）
	_playback_time = time
	_playback_index = 0
	# 找最近的关键帧（对标 Dota2 keyframe jump）
	var nearest_kf: Dictionary = {}
	for kf in _keyframes:
		if kf["time"] <= time:
			nearest_kf = kf
	if not nearest_kf.is_empty():
		# 应用关键帧快照
		EventBus.emit_event("replay_keyframe_applied", nearest_kf.get("snapshot", {}))
	# 从关键帧时间点之后开始播放事件
	for i in range(_timeline.size()):
		if _timeline[i]["time"] > time:
			break
		_playback_index = i

func get_playback_progress() -> Dictionary:
	var total_time: float = _metadata.get("duration", 0.0)
	return {
		"time": _playback_time,
		"total_time": total_time,
		"progress": _playback_time / total_time if total_time > 0 else 0.0,
		"event_index": _playback_index,
		"total_events": _timeline.size(),
		"speed": _playback_speed,
		"state": state,
	}

func _advance_playback() -> void:
	while _playback_index < _timeline.size():
		var entry: Dictionary = _timeline[_playback_index]
		if entry["time"] > _playback_time:
			break
		# 触发回放事件
		EventBus.emit_event("replay_event", {
			"original_event": entry["event"],
			"data": entry["data"],
			"tick": entry["tick"],
			"time": entry["time"],
		})
		_playback_index += 1
	# 回放结束
	if _playback_index >= _timeline.size():
		state = State.IDLE
		EventBus.emit_event("replay_playback_finished", _metadata)

# === 数据导入/导出 ===

func get_replay_data() -> Dictionary:
	return {
		"metadata": _metadata.duplicate(),
		"timeline": _timeline.duplicate(),
		"keyframes": _keyframes.duplicate(),
		"rng_seed": _rng_seed,
	}

func load_replay_data(data: Dictionary) -> bool:
	if not data.has("timeline"):
		return false
	_timeline = data["timeline"]
	_metadata = data.get("metadata", {})
	_keyframes = data.get("keyframes", [])
	_rng_seed = data.get("rng_seed", 0)
	return true

func save_to_file(file_path: String) -> Error:
	## 保存录制到文件
	var data: Dictionary = get_replay_data()
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	return OK

func load_from_file(file_path: String) -> bool:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return false
	return load_replay_data(json.data)

# === 关键帧快照（对标 Dota2 periodic keyframe）===

func _capture_keyframe(elapsed: float) -> void:
	## 捕获当前世界状态快照（用于回放跳转）
	var entities: Dictionary = {}
	var all: Array = EngineAPI.find_entities_by_tag("mobile")
	for e in all:
		if not is_instance_valid(e) or not (e is GameEntity):
			continue
		var ge: GameEntity = e as GameEntity
		var health: Node = EngineAPI.get_component(ge, "health")
		entities[ge.runtime_id] = {
			"def_id": ge.def_id,
			"pos_x": ge.global_position.x,
			"pos_y": ge.global_position.y,
			"hp": health.current_hp if health else 0,
			"alive": ge.is_alive,
			"flags": ge.unit_flags,
		}
	_keyframes.append({
		"tick": _record_tick,
		"time": elapsed,
		"snapshot": {"entities": entities},
	})

# === 序列化辅助 ===

func _serialize_event_data(data: Dictionary) -> Dictionary:
	## 将事件数据中的 Node 引用转为可序列化的 ID
	var result: Dictionary = {}
	for key in data:
		var val = data[key]
		# freed Object 检查：typeof == OBJECT 但 is_instance_valid 为 false
		if typeof(val) == TYPE_OBJECT:
			if not is_instance_valid(val):
				result[key] = null
				continue
		if val is GameEntity:
			result[key] = {"_type": "entity", "def_id": val.def_id, "runtime_id": val.runtime_id}
		elif val is Node3D:
			result[key] = {"_type": "node", "name": val.name}
		elif val is Vector3:
			result[key] = {"_type": "vec3", "x": val.x, "y": val.y, "z": val.z}
		elif val is Color:
			result[key] = {"_type": "color", "r": val.r, "g": val.g, "b": val.b, "a": val.a}
		elif val is Dictionary or val is Array or val is String or val is float or val is int or val is bool:
			result[key] = val
		# 其他类型跳过（不可序列化）
	return result
