extends Node
class_name InventoryService

# InventoryService v2
# Keeps a real global inventory list between scene changes.
#
# Autoload name should be ONE of these:
# - InventoryService
# - Inventory_Service
#
# Why this version exists:
# Old v1 delivered items into the current InventoryScreen, but did not always
# keep a global list after changing scenes. So a quest NPC inside another scene
# could fail to see an item that was picked up outside.

signal inventory_changed
signal gold_changed(new_gold: int)

# Main global inventory storage.
var items: Array[Resource] = []

# Queues when inventory UI is not loaded yet.
var _queued_items: Array[Resource] = []
var _queued_gold: int = 0

var gold: int = 0


func add_item(item: Resource) -> void:
	if item == null:
		return

	items.append(item)

	if not _try_deliver_item_now(item):
		_queued_items.append(item)

	emit_signal("inventory_changed")


func add_items(new_items: Array) -> void:
	for it in new_items:
		add_item(it)


func remove_item_id(id_key: String) -> bool:
	var want: String = id_key.strip_edges()
	if want == "":
		return false

	# Remove from global list.
	for i in range(items.size()):
		if _item_matches_id(items[i], want):
			items.remove_at(i)
			_remove_from_inventory_screen(want)
			_remove_from_queue(want)
			emit_signal("inventory_changed")
			return true

	# Fallback: maybe item only exists in InventoryScreen.
	if _remove_from_inventory_screen(want):
		_remove_from_queue(want)
		emit_signal("inventory_changed")
		return true

	# Fallback: maybe item only exists in queue.
	if _remove_from_queue(want):
		emit_signal("inventory_changed")
		return true

	return false


func has_item_id(id_key: String) -> bool:
	var want: String = id_key.strip_edges()
	if want == "":
		return false

	_import_from_inventory_screen_once()

	for it in items:
		if _item_matches_id(it, want):
			return true

	for itq in _queued_items:
		if _item_matches_id(itq, want):
			return true

	var inv: Node = _find_inventory_screen()
	if inv != null:
		if inv.has_method("has_item") and bool(inv.call("has_item", want)):
			return true

		if "starting_items" in inv:
			var arr: Array = inv.starting_items
			for it2 in arr:
				if _item_matches_id(it2, want):
					return true

	return false


func set_items_from_array(new_items: Array) -> void:
	items.clear()
	_queued_items.clear()

	for it in new_items:
		if it != null:
			items.append(it)

	_sync_inventory_screen_from_items()
	emit_signal("inventory_changed")


func get_item_ids() -> Array[String]:
	_import_from_inventory_screen_once()

	var out: Array[String] = []
	for it in items:
		var id_text := _get_item_id(it)
		if id_text != "":
			out.append(id_text)
	return out


func add_gold(amount: int) -> void:
	if amount == 0:
		return

	gold += amount

	if not _try_deliver_gold_now(amount):
		_queued_gold += amount

	emit_signal("gold_changed", gold)


func _process(_delta: float) -> void:
	_flush_queues()
	_sync_inventory_screen_from_items()


func _flush_queues() -> void:
	var inv: Node = _find_inventory_screen()
	if inv == null:
		return

	if not _queued_items.is_empty():
		var pending: Array = _queued_items.duplicate()
		_queued_items.clear()
		for it in pending:
			_try_deliver_item_now(it)

	if _queued_gold != 0:
		var g := _queued_gold
		_queued_gold = 0
		_try_deliver_gold_now(g)

	if inv.has_method("_apply_filter"):
		inv.call("_apply_filter")


func _sync_inventory_screen_from_items() -> void:
	var inv: Node = _find_inventory_screen()
	if inv == null:
		return
	if not ("starting_items" in inv):
		return

	var arr: Array = inv.starting_items

	for it in items:
		if it == null:
			continue
		if not arr.has(it):
			arr.append(it)

	inv.starting_items = arr

	if inv.has_method("_apply_filter"):
		inv.call("_apply_filter")


func _import_from_inventory_screen_once() -> void:
	var inv: Node = _find_inventory_screen()
	if inv == null:
		return
	if not ("starting_items" in inv):
		return

	var arr: Array = inv.starting_items
	for it in arr:
		if it != null and not items.has(it):
			items.append(it)


func _remove_from_inventory_screen(id_key: String) -> bool:
	var inv: Node = _find_inventory_screen()
	if inv == null:
		return false
	if not ("starting_items" in inv):
		return false

	var arr: Array = inv.starting_items
	for i in range(arr.size()):
		if _item_matches_id(arr[i], id_key):
			arr.remove_at(i)
			inv.starting_items = arr
			if inv.has_method("_apply_filter"):
				inv.call("_apply_filter")
			return true

	return false


func _remove_from_queue(id_key: String) -> bool:
	for i in range(_queued_items.size()):
		if _item_matches_id(_queued_items[i], id_key):
			_queued_items.remove_at(i)
			return true
	return false


func _find_inventory_screen() -> Node:
	var inv := get_tree().get_first_node_in_group("inventory_screen")
	if inv != null:
		return inv

	var scene := get_tree().current_scene
	if scene != null:
		var found := scene.find_child("InventoryScreen", true, false)
		if found != null:
			return found

	return get_tree().root.find_child("InventoryScreen", true, false)


func _try_deliver_item_now(item: Resource) -> bool:
	var inv: Node = _find_inventory_screen()
	if inv == null:
		return false

	if inv.has_method("add_item_to_inventory"):
		inv.call("add_item_to_inventory", item)
		return true

	if inv.has_method("add_item"):
		inv.call("add_item", item)
		return true

	if "starting_items" in inv:
		var arr: Array = inv.starting_items
		if not arr.has(item):
			arr.append(item)
		inv.starting_items = arr
		return true

	return false


func _try_deliver_gold_now(amount: int) -> bool:
	var inv: Node = _find_inventory_screen()
	if inv != null and inv.has_method("add_gold"):
		inv.call("add_gold", amount)
		return true

	if typeof(Global) != TYPE_NIL:
		if "gold" in Global:
			Global.gold = int(Global.gold) + amount
			return true
		if Global.has_method("add_gold"):
			Global.call("add_gold", amount)
			return true

	return inv != null


func _item_matches_id(item, id_key: String) -> bool:
	if item == null:
		return false

	var want: String = id_key.strip_edges()
	if want == "":
		return false

	if "id" in item and str(item.id).strip_edges() == want:
		return true

	if "resource_path" in item:
		var rp: String = str(item.resource_path)
		if rp != "" and rp.get_file().get_basename() == want:
			return true

	if "title" in item and str(item.title).strip_edges() == want:
		return true

	return false


func _get_item_id(item) -> String:
	if item == null:
		return ""

	if "id" in item:
		var id_text := str(item.id).strip_edges()
		if id_text != "":
			return id_text

	if "resource_path" in item:
		var rp: String = str(item.resource_path)
		if rp != "":
			return rp.get_file().get_basename()

	return ""
