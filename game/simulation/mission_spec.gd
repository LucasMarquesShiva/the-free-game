extends RefCounted
## Data-only KaM teaching-mission loader. Default sandbox play does not apply this.

const DIR := "res://content/missions"

var id := ""
var save_mission_key := ""
var briefing: Array[String] = []
var available_buildings: Array[String] = []
var available_roles: Array[String] = []
var start: Dictionary = {}
var objectives: Array[Dictionary] = []
var win: Dictionary = {}
var lose: Array[Dictionary] = []


static func load_id(mission_id: String) -> RefCounted:
	var spec := new()
	var error := spec._load_path("%s/%s.json" % [DIR, mission_id])
	if not error.is_empty():
		push_error(error)
		return null
	return spec


func _load_path(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "Mission file missing: " + path
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "Mission file unreadable: " + path
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return "Mission JSON must be an object: " + path
	return _apply(parsed)


func _apply(data: Dictionary) -> String:
	id = str(data.get("id", ""))
	save_mission_key = str(data.get("save_mission_key", id))
	if id.is_empty():
		return "Mission id is required."
	briefing = _string_array(data.get("briefing", []))
	available_buildings = _string_array(data.get("available_buildings", []))
	available_roles = _string_array(data.get("available_roles", []))
	start = data.get("start", {})
	if typeof(start) != TYPE_DICTIONARY:
		return "Mission start must be an object."
	objectives = _dict_array(data.get("objectives", []))
	win = data.get("win", {})
	if typeof(win) != TYPE_DICTIONARY:
		win = {}
	lose = _dict_array(data.get("lose", []))
	return ""


func allows_building(kind: String) -> bool:
	return available_buildings.has(kind)


func allows_role(role: String) -> bool:
	return available_roles.has(role)


func objectives_met(completed_counts: Dictionary) -> bool:
	if not bool(win.get("all_objectives", false)):
		return false
	for row in objectives:
		if not _predicate_met(row, completed_counts):
			return false
	return not objectives.is_empty()


func _predicate_met(row: Dictionary, completed_counts: Dictionary) -> bool:
	if str(row.get("op", "")) != "completed":
		return false
	var kind := str(row.get("kind", ""))
	var need := int(row.get("count", 1))
	return int(completed_counts.get(kind, 0)) >= need


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


static func _dict_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				result.append(item)
	return result
