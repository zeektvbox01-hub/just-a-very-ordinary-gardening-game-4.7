@tool
class_name IdRegistry
extends RefCounted

## Root folder where game data is laid out in subfolders:
## res://data/npcs/*.tres, res://data/items/*.tres, res://data/locations/*.tres, etc.
## The category for an enum field is simply the subfolder name.
const DATA_ROOT := "res://data/"


## Returns a list of IDs (file basenames without extension) for the category.
## Category = subfolder inside DATA_ROOT, for example "npcs", "items".
static func get_ids(category: String) -> PackedStringArray:
	var result := PackedStringArray()
	if category.is_empty():
		return result

	var path := DATA_ROOT.path_join(category)
	var dir := DirAccess.open(path)
	if dir == null:
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (
			file_name.ends_with(".tres") or file_name.ends_with(".res") or file_name.ends_with(".dialogue")
		):
			result.append(file_name.get_basename())
		file_name = dir.get_next()
	dir.list_dir_end()

	result.sort()
	return result
	
	
static func get_all_resource(category: String) -> Array[Resource]:
	var result: Array[Resource] = []
	if category.is_empty():
		return result

	var path := DATA_ROOT.path_join(category)
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("IdRegistry: failed to open category directory '%s'" % category)
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (
			file_name.ends_with(".tres") or file_name.ends_with(".res") or file_name.ends_with(".dialogue")
		):
			var file_path := path.path_join(file_name)
			var res := load(file_path)
			if res is Resource:
				result.append(res)
			else:
				push_warning("IdRegistry: failed to load resource at path '%s'" % file_path)
		file_name = dir.get_next()
	dir.list_dir_end()

	return result

static func get_resource(category: String, id: String) -> Resource:
	if id.is_empty():
		return null

	var base_path := DATA_ROOT.path_join(category).path_join(id)
	var extensions: PackedStringArray = [".tres", ".res", ".dialogue"]
	for ext in extensions:
		var path: String = base_path + ext
		if ResourceLoader.exists(path):
			return load(path)

	push_warning("IdRegistry: resource '%s' not found in category '%s'" % [id, category])
	return null


## List of available categories (subfolder names in DATA_ROOT).
## Useful if you want to make an enum field to select the category itself.
static func get_categories() -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(DATA_ROOT)
	if dir == null:
		return result

	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			result.append(name)
		name = dir.get_next()
	dir.list_dir_end()

	return result
