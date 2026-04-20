extends Node
class_name InventoryService
# InventoryService v1
# Goal: one single API for giving items/gold from ANY source (Chest, SecretWall, NPC rewards, etc.)
#
# How it works:
# - Tries to find InventoryScreen in the active scene and use its methods/arrays.
# - If InventoryScreen isn't currently in the tree, it queues rewards and delivers them later.
#
# IMPORTANT:
# - Add this script as an Autoload singleton named: InventoryService
#   Project -> Project Settings -> Autoload -> Path: this file -> Name: InventoryService -> Add

signal inventory_changed
signal gold_changed(new_gold: int)

# Queues when inventory UI is not loaded yet
var _queued_items: Array[Resource] = []   # ItemData
var _queued_gold: int = 0

# Optional "global" counter if you don't have one yet
var gold: int = 0


func add_item(item: Resource) -> void:
	if item == null:
		return

	# Prefer delivering immediately
	if _try_deliver_item_now(item):
		emit_signal("inventory_changed")
		return

	# Otherwise, queue
	_queued_items.append(item)
	emit_signal("inventory_changed")


func add_items(items: Array) -> void:
	for it in items:
		add_item(it)


func add_gold(amount: int) -> void:
	if amount == 0:
		return

	# Try to deliver to your existing gold system if present
	if _try_deliver_gold_now(amount):
		emit_signal("gold_changed", gold)
		return

	_queued_gold += amount
	gold += amount
	emit_signal("gold_changed", gold)


func has_item_id(id_key: String) -> bool:
	var want: String = id_key.strip_edges()
	if want == "":
		return false

	# Check InventoryScreen if it exists
	var inv: Node = _find_inventory_screen()
	if inv != null:
		# If it has a helper, use it
		if inv.has_method("has_item"):
			return bool(inv.call("has_item", want))

		# Else scan starting_items if present
		if "starting_items" in inv:
			var arr: Array = inv.starting_items
			for it in arr:
				if it == null:
					continue
				if ("id" in it) and str(it.id) == want:
					return true
			return false

	# If no InventoryScreen, we can only check queued items
	for itq in _queued_items:
		if itq == null:
			continue
		if ("id" in itq) and str(itq.id) == want:
			return true
	return false


func _process(_delta: float) -> void:
	# Deliver queued rewards when UI appears.
	_flush_queues()


func _flush_queues() -> void:
	if _queued_items.is_empty() and _queued_gold == 0:
		return

	var inv: Node = _find_inventory_screen()
	if inv == null:
		return

	# Items
	if not _queued_items.is_empty():
		var pending: Array = _queued_items.duplicate()
		_queued_items.clear()
		for it in pending:
			_try_deliver_item_now(it)

	# Gold
	if _queued_gold != 0:
		var g := _queued_gold
		_queued_gold = 0
		_try_deliver_gold_now(g)

	# Nudge UI if it has refresh/apply methods
	if inv.has_method("_apply_filter"):
		inv.call("_apply_filter")
	emit_signal("inventory_changed")
	emit_signal("gold_changed", gold)


func _find_inventory_screen() -> Node:
	# Try group first (recommended)
	var inv := get_tree().get_first_node_in_group("inventory_screen")
	if inv != null:
		return inv

	# Fallback by name
	var root := get_tree().current_scene
	if root == null:
		return null
	return root.find_child("InventoryScreen", true, false)


func _try_deliver_item_now(item: Resource) -> bool:
	var inv: Node = _find_inventory_screen()
	if inv == null:
		return false

	# Best: method
	if inv.has_method("add_item_to_inventory"):
		inv.call("add_item_to_inventory", item)
		return true
	if inv.has_method("add_item"):
		inv.call("add_item", item)
		return true

	# Fallback: push into starting_items if it exists
	if "starting_items" in inv:
		var arr: Array = inv.starting_items
		arr.append(item)
		inv.starting_items = arr
		return true

	return false


func _try_deliver_gold_now(amount: int) -> bool:
	# Update local counter (always)
	gold += amount

	# If InventoryScreen has add_gold, use it
	var inv: Node = _find_inventory_screen()
	if inv != null and inv.has_method("add_gold"):
		inv.call("add_gold", amount)
		return true

	# If you have Global.gd with gold, update it
	if typeof(Global) != TYPE_NIL:
		if "gold" in Global:
			Global.gold = int(Global.gold) + amount
			return true
		if Global.has_method("add_gold"):
			Global.call("add_gold", amount)
			return true

	return inv != null
