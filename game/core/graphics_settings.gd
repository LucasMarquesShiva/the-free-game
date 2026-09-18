class_name GraphicsSettings
extends RefCounted

## Persisted graphics quality toggle. Defaults to Performance, the profile
## tuned for weak/integrated GPUs (see approved_world.gd): reduced grass,
## capped character detail, no dynamic shadows/MSAA, 0.8x render scale.
## Quality mode restores full detail for stronger machines. Terrain-density
## choices (grass tuft count) are baked at world setup, so switching modes
## takes effect the next time a village is loaded.
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "graphics"
const SETTINGS_KEY := "high_quality"

static var _configured := false
static var _high_quality := false


static func setup() -> void:
	if _configured:
		return
	_configured = true
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		_high_quality = bool(config.get_value(SETTINGS_SECTION, SETTINGS_KEY, false))


static func high_quality() -> bool:
	setup()
	return _high_quality


static func set_high_quality(value: bool) -> void:
	setup()
	_high_quality = value
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY, value)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Could not save graphics preference: %s" % error_string(err))
