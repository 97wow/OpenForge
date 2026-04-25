## I18nManager - 全球化多语言框架
## 每种语言独立 JSON 文件，支持内置(res://) + 下载(user://)
## 默认语言(en)作为 fallback，缺失 key 自动回退
## API:
##   I18n.t("KEY")               → 简单翻译
##   I18n.t("KEY", [arg0, arg1]) → 模板翻译 {0} {1}
##   I18n.set_locale("zh_CN")    → 切换语言
##   I18n.get_locale()            → 当前语言
##   I18n.get_available_locales() → 可用语言列表
extends Node

const LANG_DIR_RES := "res://lang/"
const LANG_DIR_USER := "user://lang/"
const DEFAULT_LOCALE := "en"
const SETTINGS_KEY := "locale"

## 当前语言
var _locale: String = DEFAULT_LOCALE
## 默认语言字符串（fallback）
var _default_strings: Dictionary = {}
## 当前语言字符串
var _current_strings: Dictionary = {}
## 可用语言元数据 { locale -> {name, version, path} }
var _available: Dictionary = {}

signal locale_changed(new_locale: String)

func _ready() -> void:
	# 扫描可用语言包
	_scan_languages()
	# 加载默认语言
	_default_strings = _load_language_file(DEFAULT_LOCALE)
	# 读取用户偏好
	var saved_locale: String = str(SaveSystem.load_data("settings", SETTINGS_KEY, DEFAULT_LOCALE))
	set_locale(saved_locale)

# === 公开 API ===

func t(key: String, args: Array = []) -> String:
	## 翻译。支持 {0} {1} 占位符
	var text: String = _current_strings.get(key, "")
	if text == "":
		text = _default_strings.get(key, key)  # fallback → 默认语言 → key 本身
	if args.size() > 0:
		# GDScript format 需要 Array，直接用 format()
		var format_args: Array = []
		for arg in args:
			format_args.append(str(arg))
		text = text.format(format_args)
	return text

func set_locale(locale: String) -> void:
	if locale == _locale and not _current_strings.is_empty():
		return
	_locale = locale
	if locale == DEFAULT_LOCALE:
		_current_strings = _default_strings
	else:
		_current_strings = _load_language_file(locale)
		if _current_strings.is_empty():
			# 语言包不存在，回退到默认
			push_warning("[I18n] Language '%s' not found, falling back to '%s'" % [locale, DEFAULT_LOCALE])
			_locale = DEFAULT_LOCALE
			_current_strings = _default_strings
	# 保存偏好
	SaveSystem.save_data("settings", SETTINGS_KEY, _locale)
	# 同步 Godot TranslationServer（兼容可能残留的 tr() 调用）
	TranslationServer.set_locale(_locale)
	locale_changed.emit(_locale)
	print("[I18n] Locale set to: %s (%d strings)" % [_locale, _current_strings.size()])

func get_locale() -> String:
	return _locale

func get_available_locales() -> Array[Dictionary]:
	## 返回 [{locale, name, version, path}]
	var result: Array[Dictionary] = []
	for locale in _available:
		result.append(_available[locale])
	return result

func get_locale_name(locale: String) -> String:
	if _available.has(locale):
		return _available[locale].get("name", locale)
	return locale

func has_key(key: String) -> bool:
	return _current_strings.has(key) or _default_strings.has(key)

func get_all_keys() -> PackedStringArray:
	## 返回默认语言的所有 key（用于生成翻译模板）
	var keys: PackedStringArray = []
	for k in _default_strings:
		keys.append(k)
	return keys

func export_template(locale: String) -> String:
	## 导出翻译模板 JSON（以默认语言的值为基础）
	var template := {
		"locale": locale,
		"name": locale,
		"version": "1.0.0",
		"strings": {}
	}
	for key in _default_strings:
		var current: String = _current_strings.get(key, "")
		template["strings"][key] = current if current != "" else _default_strings[key]
	return JSON.stringify(template, "\t")

# === 内部 ===

func _scan_languages() -> void:
	_available.clear()
	# 扫描 res://lang/
	_scan_dir(LANG_DIR_RES)
	# 扫描 user://lang/（可覆盖内置版本）
	DirAccess.make_dir_recursive_absolute(LANG_DIR_USER)
	_scan_dir(LANG_DIR_USER)

func _scan_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path := dir_path + file_name
			var meta := _read_language_meta(full_path)
			if not meta.is_empty():
				var locale: String = meta.get("locale", "")
				meta["path"] = full_path
				_available[locale] = meta
		file_name = dir.get_next()

func _read_language_meta(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	# 只读前几行获取 meta（不加载全部字符串）
	if json.parse(file.get_as_text()) != OK:
		return {}
	if not json.data is Dictionary:
		return {}
	var data: Dictionary = json.data
	return {
		"locale": data.get("locale", ""),
		"name": data.get("name", ""),
		"version": data.get("version", "1.0.0"),
	}

func _load_language_file(locale: String) -> Dictionary:
	# 优先 user://，然后 res://
	var paths := [LANG_DIR_USER + locale + ".json", LANG_DIR_RES + locale + ".json"]
	for path in paths:
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				continue
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				var raw: Dictionary = (json.data as Dictionary).get("strings", {})
				if not raw.is_empty():
					# 处理转义字符：\n → 真正换行，\t → 制表符
					var strings: Dictionary = {}
					for key in raw:
						var val: String = str(raw[key])
						val = val.replace("\\n", "\n").replace("\\t", "\t")
						strings[key] = val
					return strings
	return {}
