## Main - 游戏主场景
## 负责初始化所有子系统、加载 MapPack、启动游戏
extends Node2D

@onready var grid_system: GridSystem = $Systems/GridSystem
@onready var path_system: PathSystem = $Systems/PathSystem
@onready var wave_system: WaveSystem = $Systems/WaveSystem
@onready var unit_system: UnitSystem = $Systems/UnitSystem
@onready var economy_system: EconomySystem = $Systems/EconomySystem
@onready var buff_system: BuffSystem = $Systems/BuffSystem
@onready var game_ui: CanvasLayer = $UI

var lives: int = 20
var max_lives: int = 20

func _ready() -> void:
	# 注册子系统到 GameEngine
	GameEngine.grid_system = grid_system
	GameEngine.path_system = path_system
	GameEngine.wave_system = wave_system
	GameEngine.unit_system = unit_system
	GameEngine.economy_system = economy_system
	GameEngine.buff_system = buff_system

	# 连接事件
	EventBus.lives_changed.connect(_on_lives_changed)
	EventBus.wave_completed.connect(_on_wave_completed)

	# 加载默认地图包
	_load_map("res://data/maps/demo_plains")

func _load_map(pack_path: String) -> void:
	if not DataManager.load_map_pack(pack_path):
		push_error("Main: Failed to load map pack '%s'" % pack_path)
		return

	var config := DataManager.get_map_config()

	# 初始化网格
	var grid_width: int = config.get("grid_width", 20)
	var grid_height: int = config.get("grid_height", 12)
	var layout: Array = config.get("layout", [])
	grid_system.init_grid(grid_width, grid_height, layout)

	# 初始化路径
	var paths: Array = config.get("paths", [])
	path_system.setup_paths(paths)

	# 初始化经济
	var starting_gold: int = config.get("starting_gold", 200)
	var base_income: int = config.get("base_income", 0)
	economy_system.init_economy(starting_gold, base_income)

	# 初始化生命
	lives = config.get("starting_lives", 20)
	max_lives = lives

	GameEngine.state = GameEngine.GameState.PREPARING
	GameEngine.current_map_id = config.get("map_id", "unknown")
	EventBus.map_loaded.emit(GameEngine.current_map_id)

func _on_lives_changed(current: int, _delta: int) -> void:
	lives += current
	EventBus.lives_changed.emit(lives, current)

func _on_wave_completed(wave_index: int) -> void:
	print("Wave %d completed!" % wave_index)
