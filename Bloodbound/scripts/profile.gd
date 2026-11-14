extends RefCounted
## Centralized profile, with a procedural fallback for absent optional art.
var data := ConfigFile.new()

func _init(path: String) -> void:
	var error := data.load(path)
	if error != OK:
		push_error("Could not read required profile %s (%s)" % [path, error])

func get_value(section: String, key: String, fallback: Variant = null) -> Variant:
	return data.get_value(section, key, fallback)

func optional(section: String, key: String, type: String) -> Resource:
	var path: String = get_value(section, key, "")
	if path.is_empty() or not ResourceLoader.exists(path, type):
		return null
	return ResourceLoader.load(path, type)
