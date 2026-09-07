class_name Locale
extends RefCounted

const SUPPORTED := ["pt_BR", "en", "zh_CN"]
const DISPLAY_NAMES := {
	"pt_BR": "Português",
	"en": "English",
	"zh_CN": "简体中文",
}
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "locale"
const SETTINGS_KEY := "language"

static var _configured := false


static func setup() -> void:
	if _configured:
		return
	_configured = true
	for code in SUPPORTED:
		if code == "pt_BR":
			continue
		_load_translation(code)
	TranslationServer.set_locale(_resolve())


static func set_language(code: String) -> bool:
	setup()
	if not SUPPORTED.has(code):
		return false
	TranslationServer.set_locale(code)
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY, code)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Could not save language preference: %s" % error_string(err))
	return true


static func current() -> String:
	return _canonical(TranslationServer.get_locale())


static func display_name(code: String) -> String:
	return str(DISPLAY_NAMES.get(code, code))


static func _load_translation(code: String) -> void:
	var path := "res://locale/%s.json" % code
	if not FileAccess.file_exists(path):
		push_warning("Locale file missing: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not read locale file: %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_warning("Corrupt locale file: %s" % path)
		return
	var translation := Translation.new()
	translation.locale = code
	for key in parsed:
		var value: Variant = parsed[key]
		if typeof(key) != TYPE_STRING or typeof(value) != TYPE_STRING:
			push_warning("Skipping non-string locale entry in %s" % path)
			continue
		translation.add_message(key, value)
	TranslationServer.add_translation(translation)


static func _resolve() -> String:
	var saved := _saved_language()
	if SUPPORTED.has(saved):
		return saved
	var language := OS.get_locale_language()
	if language == "en":
		return "en"
	if language == "zh":
		return "zh_CN"
	return "pt_BR"


static func _saved_language() -> String:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return ""
	return str(config.get_value(SETTINGS_SECTION, SETTINGS_KEY, ""))


static func _canonical(locale: String) -> String:
	if SUPPORTED.has(locale):
		return locale
	if locale.begins_with("en"):
		return "en"
	if locale.begins_with("zh"):
		return "zh_CN"
	if locale.begins_with("pt"):
		return "pt_BR"
	return "pt_BR"
