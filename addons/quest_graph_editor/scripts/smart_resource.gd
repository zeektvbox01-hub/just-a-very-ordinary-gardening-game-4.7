@tool
@abstract
class_name SmartResource
extends Resource


func _id_fields() -> Dictionary:
	return {}


func _get_property_list() -> Array:
	var list: Array = []
	for field_name in _id_fields():
		var category: String = _id_fields()[field_name]
		var ids := IdRegistry.get_ids(category)
		var hint_string := ",".join(Array(ids)) if ids.size() > 0 else "(нет данных в res://data/%s/)" % category

		hint_string = "\t," + hint_string

		list.append({
			"name": field_name,
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": hint_string,
		})
	return list
