## AudioManager — 音频管理系统（Godot 4 最佳实践）
## BGM 淡入淡出 + 环境音 + AudioStreamPolyphonic SFX + AudioStreamPlayer3D 定位音效
## 自动创建音频总线（BGM/SFX/Ambience）
## 框架层系统，GamePack 通过 EngineAPI 播放音频
class_name AudioManager
extends Node

# === 音频总线名称 ===
const BUS_MASTER   := "Master"
const BUS_BGM      := "BGM"
const BUS_SFX      := "SFX"
const BUS_AMBIENCE := "Ambience"

# === BGM ===
var _bgm_player: AudioStreamPlayer = null
var _bgm_fade_tween: Tween = null
var _current_bgm: String = ""

# === 环境音 ===
var _ambience_player: AudioStreamPlayer = null
var _current_ambience: String = ""

# === SFX（AudioStreamPolyphonic：单 player 多路并发）===
var _sfx_player: AudioStreamPlayer = null
var _sfx_playback: AudioStreamPlaybackPolyphonic = null

# === 定位 SFX（AudioStreamPlayer3D 池）===
var _sfx3d_pool: Array[AudioStreamPlayer3D] = []
const SFX3D_POOL_SIZE := 8

# === 音频缓存 ===
var _stream_cache: Dictionary = {}

# === 音量（0.0 ~ 1.0）===
var _volumes: Dictionary = {
	"master": 1.0, "bgm": 0.7, "sfx": 1.0, "ambience": 0.5,
}

func _ready() -> void:
	EngineAPI.register_system("audio", self)
	_ensure_buses()
	_setup_players()

func _ensure_buses() -> void:
	## 确保 BGM/SFX/Ambience 总线存在（Godot 4 最佳实践）
	for bus_name in [BUS_BGM, BUS_SFX, BUS_AMBIENCE]:
		if AudioServer.get_bus_index(bus_name) < 0:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, BUS_MASTER)

func _setup_players() -> void:
	# BGM
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = BUS_BGM
	add_child(_bgm_player)
	# 环境音
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = BUS_AMBIENCE
	add_child(_ambience_player)
	# SFX（Polyphonic：一个 player 最多 32 路并发，替代手动对象池）
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = BUS_SFX
	var poly_stream := AudioStreamPolyphonic.new()
	poly_stream.polyphony = 32
	_sfx_player.stream = poly_stream
	add_child(_sfx_player)
	_sfx_player.play()
	_sfx_playback = _sfx_player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	# 定位 SFX 池（AudioStreamPlayer3D）
	for _i in range(SFX3D_POOL_SIZE):
		var player3d := AudioStreamPlayer3D.new()
		player3d.bus = BUS_SFX
		player3d.max_distance = 50.0  # 3D 世界单位
		player3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player3d)
		_sfx3d_pool.append(player3d)

func _reset() -> void:
	stop_bgm(0.0)
	stop_ambience(0.0)
	stop_all_sfx()

# === BGM API ===

func play_bgm(stream_path: String, fade_in: float = 1.0) -> void:
	if _current_bgm == stream_path and _bgm_player.playing:
		return
	var stream: AudioStream = _load_stream(stream_path)
	if stream == null:
		return
	_current_bgm = stream_path
	if _bgm_fade_tween and is_instance_valid(_bgm_fade_tween):
		_bgm_fade_tween.kill()
	if _bgm_player.playing and fade_in > 0:
		_bgm_fade_tween = create_tween()
		_bgm_fade_tween.tween_property(_bgm_player, "volume_db", -40.0, fade_in * 0.5)
		_bgm_fade_tween.tween_callback(func() -> void:
			_bgm_player.stream = stream
			_bgm_player.volume_db = _vol_to_db(_volumes["bgm"])
			_bgm_player.play())
	else:
		_bgm_player.stream = stream
		_bgm_player.volume_db = _vol_to_db(_volumes["bgm"])
		_bgm_player.play()

func stop_bgm(fade_out: float = 1.0) -> void:
	if not _bgm_player.playing:
		return
	_current_bgm = ""
	if fade_out > 0:
		if _bgm_fade_tween and is_instance_valid(_bgm_fade_tween):
			_bgm_fade_tween.kill()
		_bgm_fade_tween = create_tween()
		_bgm_fade_tween.tween_property(_bgm_player, "volume_db", -40.0, fade_out)
		_bgm_fade_tween.tween_callback(_bgm_player.stop)
	else:
		_bgm_player.stop()

func pause_bgm() -> void:
	_bgm_player.stream_paused = true

func resume_bgm() -> void:
	_bgm_player.stream_paused = false

func get_current_bgm() -> String:
	return _current_bgm

# === 环境音 API ===

func play_ambience(stream_path: String, fade_in: float = 2.0) -> void:
	if _current_ambience == stream_path and _ambience_player.playing:
		return
	var stream: AudioStream = _load_stream(stream_path)
	if stream == null:
		return
	_current_ambience = stream_path
	_ambience_player.stream = stream
	_ambience_player.volume_db = -40.0 if fade_in > 0 else _vol_to_db(_volumes["ambience"])
	_ambience_player.play()
	if fade_in > 0:
		var tw := create_tween()
		tw.tween_property(_ambience_player, "volume_db", _vol_to_db(_volumes["ambience"]), fade_in)

func stop_ambience(fade_out: float = 2.0) -> void:
	_current_ambience = ""
	if fade_out > 0 and _ambience_player.playing:
		var tw := create_tween()
		tw.tween_property(_ambience_player, "volume_db", -40.0, fade_out)
		tw.tween_callback(_ambience_player.stop)
	else:
		_ambience_player.stop()

# === SFX API（非定位，AudioStreamPolyphonic）===

func play_sfx(stream_path: String, volume: float = 1.0, pitch: float = 1.0) -> void:
	## 播放非定位音效（通过 Polyphonic 多路并发）
	var stream: AudioStream = _load_stream(stream_path)
	if stream == null or _sfx_playback == null:
		return
	var vol_db: float = _vol_to_db(_volumes["sfx"] * volume)
	_sfx_playback.play_stream(stream, 0.0, vol_db, pitch)

func play_sfx_random_pitch(stream_path: String, volume: float = 1.0, pitch_range: float = 0.15) -> void:
	## 带随机音高变化的音效（脚步/打击声更自然）
	var pitch: float = 1.0 + randf_range(-pitch_range, pitch_range)
	play_sfx(stream_path, volume, pitch)

# === 定位 SFX API（AudioStreamPlayer3D，引擎自动距离衰减+panning）===

func play_sfx_at(stream_path: String, world_pos: Vector3, volume: float = 1.0, pitch: float = 1.0) -> void:
	## 播放定位音效（引擎级 3D 空间化）
	var stream: AudioStream = _load_stream(stream_path)
	if stream == null:
		return
	var player: AudioStreamPlayer3D = _get_free_3d_player()
	if player == null:
		return
	player.stream = stream
	player.global_position = world_pos
	player.volume_db = _vol_to_db(_volumes["sfx"] * volume)
	player.pitch_scale = pitch
	player.play()

func stop_all_sfx() -> void:
	for p in _sfx3d_pool:
		if p.playing:
			p.stop()

# === 音量控制 ===

func set_volume(group: String, volume: float) -> void:
	_volumes[group] = clampf(volume, 0.0, 1.0)
	_apply_volume(group)
	EventBus.emit_event("volume_changed", {"group": group, "volume": volume})

func get_volume(group: String) -> float:
	return _volumes.get(group, 1.0)

func _apply_volume(group: String) -> void:
	match group:
		"master":
			var bus_idx: int = AudioServer.get_bus_index(BUS_MASTER)
			if bus_idx >= 0:
				AudioServer.set_bus_volume_db(bus_idx, _vol_to_db(_volumes["master"]))
		"bgm":
			_bgm_player.volume_db = _vol_to_db(_volumes["bgm"])
		"ambience":
			_ambience_player.volume_db = _vol_to_db(_volumes["ambience"])
		"sfx":
			pass  # SFX 在播放时动态应用

# === 内部 ===

func _load_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path) as AudioStream
	if stream:
		_stream_cache[path] = stream
	return stream

func _get_free_3d_player() -> AudioStreamPlayer3D:
	for p in _sfx3d_pool:
		if not p.playing:
			return p
	return null

static func _vol_to_db(vol: float) -> float:
	if vol <= 0.001:
		return -80.0
	return linear_to_db(vol)
