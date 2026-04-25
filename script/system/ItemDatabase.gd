extends Node
class_name ItemDatabase

# ItemDatabase v2 DEBUG
# Autoload:
#   Path: res://script/system/ItemDatabase.gd
#   Node Name: Item_Database
#
# This version prints exactly what it loaded and supports several possible ID field names:
# - id
# - item_id
# - ID
# - fallback: file basename

@export var items_folder: String = "res://data/items"
@export var print_debug: bool = true

var _items_by_id: Dictionary = {}


func _ready() -> void:
	print("ItemDatabase READY at /root/%s" % name)
	rebuild()


func rebuild() -> void:
	_items_by_id.clear()
	_scan_folder(items_folder)

	if print_debug:
		print("ItemDatabase: loaded %d items from %s" % [_items_by_id.size(), items_folder])
		print("ItemDatabase: ids = ", get_all_ids())


func get_item(id_key: String) -> Resource:
	var key: String = id_key.strip_edges()
	if key == "":
		return null

	if _items_by_id.has(key):
		return _items_by_id[key] as Resource

	var lower_key: String = key.to_lower()
	if _items_by_id.has(lower_key):
		return _items_by_id[lower_key] as Resource

	push_warning("ItemDatabase: item id not found: %s. Known IDs: %s" % [key, str(get_all_ids())])
	return null


func has_item(id_key: String) -> bool:
	return _items_by_id.has(id_key.strip_edges())


func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in _items_by_id.keys():
		ids.append(str(k))
	ids.sort()
	return ids


func _scan_folder(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		push_warning("ItemDatabase: cannot open folder: %s" % path)
		return

	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name == "":
			break

		if file_name.begins_with("."):
			continue

		var full_path: String = path.path_join(file_name)

		if dir.current_is_dir():
			_scan_folder(full_path)
			continue

		var ext: String = file_name.get_extension().to_lower()
		if ext != "tres" and ext != "res":
			continue

		var res: Resource = ResourceLoader.load(full_path)
		if res == null:
			if print_debug:
				print("ItemDatabase: failed to load resource: ", full_path)
			continue

		_register_item(res, full_path)

	dir.list_dir_end()


func _register_item(item: Resource, path: String) -> void:
	var id_text: String = _extract_item_id(item).strip_edges()

	if id_text == "":
		id_text = path.get_file().get_basename()

	if id_text == "":
		return

	# Register exact ID.
	_items_by_id[id_text] = item

	# Register lowercase alias too. This helps if a save says HP_Small but item says hp_small.
	var lower_id: String = id_text.to_lower()
	if lower_id != id_text:
		_items_by_id[lower_id] = item

	# Register filename alias too.
	var file_id: String = path.get_file().get_basename()
	if file_id != "" and not _items_by_id.has(file_id):
		_items_by_id[file_id] = item

	if print_debug:
		print("ItemDatabase: %s -> %s" % [id_text, path])


func _extract_item_id(item: Resource) -> String:
	if item == null:
		return ""

	if "id" in item:
		return str(item.id)

	if "item_id" in item:
		return str(item.item_id)

	if "ID" in item:
		return str(item.ID)

	return ""
