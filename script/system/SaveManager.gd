extends Node
class_name SaveManager

# SaveManager v8
# Autoload name recommended: Save_Manager
#
# New in v8:
# - You can set a readable location name in Inspector:
#     current_location_display_name
# - It is saved into each slot as "location_name"
# - Slot descriptions use location_name instead of technical scene file name.
# - Restores inventory items from saved inventory_item_ids via Item_Database.
# - Also saves/restores items queued inside InventoryService/Inventory_Service.
# - Uses deferred inventory restore after scene loading, so UI has time to appear.
# - Detailed item restore debug: loaded ids, database hits/misses, inventory count.
# - Fallback scan in res://data/items if Item_Database autoload is missing.
#
# Example slot text:
#   Слот 1 — Деревня у реки | Золото: 100 | 20.04.2026 18:45

signal saved(slot: int)
signal loaded(slot: int)
signal save_failed(slot: int, reason: String)
signal load_failed(slot: int, reason: String)

@export_group("Slots")
@export var current_save_slot: int = 1
@export var max_slots: int = 3

@export_group("Start Scene")
@export var default_start_scene_path: String = "res://scene/world/World_1.tscn"

@export_group("Slot Description")
# This is what the save/load menu will show as location name.
# Change it from Inspector when entering a different world/scene,
# or call Save_Manager.set_location_display_name("Дом старосты") from a world script.
@export var current_location_display_name: String = "Деревня у реки"

@export var empty_slot_text: String = "Пустой слот"
@export var slot_summary_template: String = "Слот %d — %s | Золото: %d | %s"
@export var print_save_debug: bool = true

const SAVE_VERSION: int = 1


func set_current_slot(slot: int) -> void:
	current_save_slot = int(clamp(slot, 1, max_slots))


func set_location_display_name(value: String) -> void:
	current_location_display_name = value


func get_slot_path(slot: int = -1) -> String:
	var s: int = current_save_slot if slot <= 0 else slot
	s = int(clamp(s, 1, max_slots))
	return "user://save_slot_%d.json" % s


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(get_slot_path(slot))


func save_game(slot: int = -1) -> bool:
	var s: int = current_save_slot if slot <= 0 else slot
	s = int(clamp(s, 1, max_slots))

	var data: Dictionary = _collect_save_data()
	data["slot"] = s
	data["saved_unix_time"] = Time.get_unix_time_from_system()

	var path: String = get_slot_path(s)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		emit_signal("save_failed", s, "Cannot open save file.")
		return false

	var json_text: String = JSON.stringify(data, "\t")
	file.store_string(json_text)
	file.close()

	emit_signal("saved", s)
	return true


func load_game(slot: int = -1) -> Dictionary:
	var s: int = current_save_slot if slot <= 0 else slot
	s = int(clamp(s, 1, max_slots))

	var data: Dictionary = peek_slot_data(s)
	if data.is_empty():
		emit_signal("load_failed", s, "Save slot does not exist or is corrupted.")
		return {}

	current_save_slot = s
	emit_signal("loaded", s)
	return data


func peek_slot_data(slot: int) -> Dictionary:
	var s: int = int(clamp(slot, 1, max_slots))
	var path: String = get_slot_path(s)

	if not FileAccess.file_exists(path):
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	return parsed as Dictionary


func get_slot_summary(slot: int) -> String:
	var s: int = int(clamp(slot, 1, max_slots))
	var data: Dictionary = peek_slot_data(s)

	if data.is_empty():
		return "Слот %d — %s" % [s, empty_slot_text]

	var location_name: String = str(data.get("location_name", ""))
	if location_name.strip_edges() == "":
		# fallback for old saves created before v3
		var scene_path: String = str(data.get("scene_path", "Unknown"))
		location_name = scene_path.get_file().get_basename()

	var gold_amount: int = int(data.get("gold", 0))
	var saved_time: int = int(data.get("saved_unix_time", 0))
	var time_text: String = _format_save_time(saved_time)

	return slot_summary_template % [s, location_name, gold_amount, time_text]


func start_new_game(slot: int, scene_path: String = "") -> void:
	var s: int = int(clamp(slot, 1, max_slots))
	current_save_slot = s
	_clear_runtime_inventory_before_new_game()

	var path: String = scene_path
	if path.strip_edges() == "":
		path = default_start_scene_path

	get_tree().change_scene_to_file(path)


func load_slot_and_enter_game(slot: int) -> void:
	var s: int = int(clamp(slot, 1, max_slots))
	var data: Dictionary = load_game(s)
	if data.is_empty():
		return

	var scene_path: String = str(data.get("scene_path", ""))
	if scene_path.strip_edges() == "":
		scene_path = default_start_scene_path

	var err: Error = get_tree().change_scene_to_file(scene_path)
	if err != OK:
		emit_signal("load_failed", s, "Cannot change scene to: %s" % scene_path)
		return

	# Wait until the new scene is actually installed, then give it a few frames.
	await get_tree().tree_changed
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	apply_loaded_data(data)

	# Inventory UI/Menu may be created a bit later, so retry restoring inventory for a short time.
	_restore_inventory_deferred(data)


func apply_loaded_data(data: Dictionary) -> void:
	if data.is_empty():
		return

	if data.has("location_name"):
		current_location_display_name = str(data["location_name"])

	_apply_player_position(data)
	_apply_gold(data)
	_apply_inventory_items(data)
	_apply_game_state(data)


func _collect_save_data() -> Dictionary:
	var data: Dictionary = {}
	data["version"] = SAVE_VERSION
	data["scene_path"] = _get_current_scene_path()
	data["location_name"] = current_location_display_name
	data["player"] = _collect_player_data()
	data["gold"] = _collect_gold()
	data["inventory_item_ids"] = _collect_inventory_item_ids()
	data["game_state"] = _collect_game_state()
	return data


func _format_save_time(saved_time: int) -> String:
	if saved_time <= 0:
		return "Нет даты"

	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(saved_time)
	return "%02d.%02d.%04d %02d:%02d" % [
		int(dt.get("day", 0)),
		int(dt.get("month", 0)),
		int(dt.get("year", 0)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0))
	]



func _clear_runtime_inventory_before_new_game() -> void:
	var service: Node = _get_inventory_service()
	if service != null:
		if "_queued_items" in service:
			service._queued_items.clear()
		if "_queued_gold" in service:
			service._queued_gold = 0

	var inv: Node = _find_inventory_screen()
	if inv != null and ("starting_items" in inv):
		var arr: Array = inv.starting_items
		arr.clear()
		inv.starting_items = arr

func _get_current_scene_path() -> String:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return ""
	return scene.scene_file_path


func _collect_player_data() -> Dictionary:
	var out: Dictionary = {}
	var player: Node2D = _find_player()
	if player == null:
		return out

	out["x"] = player.global_position.x
	out["y"] = player.global_position.y

	if "last_direction" in player:
		var dir: Vector2 = player.last_direction
		out["dir_x"] = dir.x
		out["dir_y"] = dir.y

	return out


func _collect_gold() -> int:
	if typeof(Global) != TYPE_NIL:
		if "gold" in Global:
			return int(Global.gold)

	if typeof(Inventory_Service) != TYPE_NIL:
		if "gold" in Inventory_Service:
			return int(Inventory_Service.gold)

	return 0


func _collect_inventory_item_ids() -> Array[String]:
	var ids: Array[String] = []

	# 1) InventoryScreen, if it exists.
	var inv: Node = _find_inventory_screen()
	if inv != null and ("starting_items" in inv):
		var arr: Array = inv.starting_items
		_append_item_ids_from_array(ids, arr)

	# 2) InventoryService queued items.
	# This is important because rewards can be stored in the service while InventoryScreen is hidden/not opened yet.
	var service: Node = _get_inventory_service()
	if service != null:
		if "_queued_items" in service:
			var queued: Array = service._queued_items
			_append_item_ids_from_array(ids, queued)

	# Remove duplicates only if the same resource accidentally exists in both places.
	# Keep quantity if player has two different instances with same ID? For now, quantities are stored as repeated IDs.
	if print_save_debug:
		print("SaveManager: saving inventory ids = ", ids)

	return ids


func _append_item_ids_from_array(out_ids: Array[String], items: Array) -> void:
	for it in items:
		if it == null:
			continue

		var id_text: String = ""
		if "id" in it:
			id_text = str(it.id).strip_edges()

		if id_text == "":
			if "resource_path" in it:
				var rp: String = str(it.resource_path)
				if rp != "":
					id_text = rp.get_file().get_basename()

		if id_text.strip_edges() != "":
			out_ids.append(id_text)


func _collect_game_state() -> Dictionary:
	var out: Dictionary = {}
	var gs: Node = _find_game_state()
	if gs == null:
		return out

	if "flags" in gs:
		out["flags"] = gs.flags
	if "quests" in gs:
		out["quests"] = gs.quests

	return out


func _apply_player_position(data: Dictionary) -> void:
	if not data.has("player"):
		return

	var p_data: Dictionary = data["player"] as Dictionary
	if p_data.is_empty():
		return

	var player: Node2D = _find_player()
	if player == null:
		return

	var x: float = float(p_data.get("x", player.global_position.x))
	var y: float = float(p_data.get("y", player.global_position.y))
	player.global_position = Vector2(x, y)

	if "last_direction" in player and p_data.has("dir_x") and p_data.has("dir_y"):
		player.last_direction = Vector2(float(p_data["dir_x"]), float(p_data["dir_y"]))


func _apply_gold(data: Dictionary) -> void:
	if not data.has("gold"):
		return

	var g: int = int(data["gold"])

	if typeof(Global) != TYPE_NIL:
		if "gold" in Global:
			Global.gold = g
			return

	if typeof(Inventory_Service) != TYPE_NIL:
		if "gold" in Inventory_Service:
			Inventory_Service.gold = g



func _apply_inventory_items(data: Dictionary) -> void:
	if not data.has("inventory_item_ids"):
		if print_save_debug:
			print("SaveManager: loaded save has no inventory_item_ids field.")
		return

	var ids_raw: Array = data["inventory_item_ids"] as Array

	if print_save_debug:
		print("SaveManager: loaded inventory ids = ", ids_raw)

	var restored_items: Array[Resource] = []
	for id_value in ids_raw:
		var id_text: String = str(id_value).strip_edges()
		if id_text == "":
			continue

		var item: Resource = _resolve_item_resource(id_text)
		if item != null:
			restored_items.append(item)
			if print_save_debug:
				print("SaveManager: restored id OK: %s -> %s" % [id_text, str(item.resource_path)])
		else:
			push_warning("SaveManager: cannot restore item id: %s" % id_text)

	if print_save_debug:
		print("SaveManager: restoring inventory ids = ", ids_raw)
		print("SaveManager: restored item resources = ", restored_items.size())

	# Clear InventoryService queue first, otherwise old/new items can mix.
	var service: Node = _get_inventory_service()
	if service != null:
		if "_queued_items" in service:
			service._queued_items.clear()

	# Apply to InventoryScreen if it exists in the loaded scene.
	var inv: Node = _find_inventory_screen()
	if inv != null:
		_replace_inventory_screen_items(inv, restored_items)
		return

	# If InventoryScreen does not exist yet, queue into InventoryService.
	if service != null:
		if "_queued_items" in service:
			for item in restored_items:
				if item != null:
					service._queued_items.append(item)
			if service.has_signal("inventory_changed"):
				service.emit_signal("inventory_changed")
			return

		if service.has_method("add_item"):
			for item in restored_items:
				service.call("add_item", item)



func _resolve_item_resource(id_text: String) -> Resource:
	var key: String = id_text.strip_edges()
	if key == "":
		return null

	var db: Node = _get_item_database()
	if db != null and db.has_method("get_item"):
		var item_from_db: Resource = db.call("get_item", key) as Resource
		if item_from_db != null:
			return item_from_db
	else:
		if print_save_debug:
			print("SaveManager: Item_Database not found, using folder fallback for id: ", key)

	return _find_item_resource_in_folder("res://data/items", key)


func _find_item_resource_in_folder(folder_path: String, id_text: String) -> Resource:
	var dir: DirAccess = DirAccess.open(folder_path)
	if dir == null:
		return null

	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name == "":
			break

		if file_name.begins_with("."):
			continue

		var full_path: String = folder_path.path_join(file_name)

		if dir.current_is_dir():
			var nested: Resource = _find_item_resource_in_folder(full_path, id_text)
			if nested != null:
				dir.list_dir_end()
				return nested
			continue

		var ext: String = file_name.get_extension().to_lower()
		if ext != "tres" and ext != "res":
			continue

		var res: Resource = ResourceLoader.load(full_path)
		if res == null:
			continue

		var item_id: String = ""
		if "id" in res:
			item_id = str(res.id).strip_edges()

		if item_id == "":
			item_id = file_name.get_basename()

		if item_id == id_text:
			dir.list_dir_end()
			return res

	dir.list_dir_end()
	return null

func _replace_inventory_screen_items(inv: Node, items: Array[Resource]) -> void:
	if inv == null:
		return

	if "starting_items" in inv:
		var arr: Array = inv.starting_items
		arr.clear()

		for item in items:
			if item != null:
				arr.append(item)

		inv.starting_items = arr

	if inv.has_method("_apply_filter"):
		inv.call("_apply_filter")
	elif inv.has_method("open"):
		# Do not force visible; only build/refresh if your screen needs it.
		pass

	if print_save_debug:
		print("SaveManager: InventoryScreen starting_items restored = ", items.size())


func _get_item_database() -> Node:
	var db: Node = get_node_or_null("/root/Item_Database")
	if db != null:
		return db

	db = get_node_or_null("/root/ItemDatabase")
	if db != null:
		return db

	return null


func _get_inventory_service() -> Node:
	var service: Node = get_node_or_null("/root/Inventory_Service")
	if service != null:
		return service

	service = get_node_or_null("/root/InventoryService")
	if service != null:
		return service

	return null



func _restore_inventory_deferred(data: Dictionary) -> void:
	call_deferred("_restore_inventory_retry_loop", data, 0)


func _restore_inventory_retry_loop(data: Dictionary, attempt: int) -> void:
	var expected_count: int = 0
	if data.has("inventory_item_ids"):
		var ids_raw: Array = data["inventory_item_ids"] as Array
		expected_count = ids_raw.size()

	if attempt > 90:
		if print_save_debug:
			print("SaveManager: inventory restore retry stopped after 90 attempts. expected=%d" % expected_count)
		return

	_apply_inventory_items(data)

	var inv: Node = _find_inventory_screen()
	var service: Node = _get_inventory_service()

	var inv_count: int = -1
	if inv != null and ("starting_items" in inv):
		var arr: Array = inv.starting_items
		inv_count = arr.size()

	var queued_count: int = -1
	if service != null and ("_queued_items" in service):
		var queued: Array = service._queued_items
		queued_count = queued.size()

	if print_save_debug and (attempt == 0 or attempt % 10 == 0 or inv_count >= expected_count):
		print("SaveManager: inventory restore attempt %d | expected=%d | inv=%s count=%d | service=%s queued=%d" % [
			attempt,
			expected_count,
			str(inv != null),
			inv_count,
			str(service != null),
			queued_count
		])

	# Stop only when inventory has at least as many items as the save says.
	# This avoids stopping too early when InventoryScreen exists but still has only default editor items.
	if inv != null and inv_count >= expected_count:
		return

	await get_tree().process_frame
	_restore_inventory_retry_loop(data, attempt + 1)


func _apply_game_state(data: Dictionary) -> void:
	if not data.has("game_state"):
		return

	var gs: Node = _find_game_state()
	if gs == null:
		return

	var d: Dictionary = data["game_state"] as Dictionary

	if d.has("flags") and ("flags" in gs):
		gs.flags = d["flags"]
	if d.has("quests") and ("quests" in gs):
		gs.quests = d["quests"]


func _find_player() -> Node2D:
	var p: Node = get_tree().get_first_node_in_group("player")
	if p != null and p is Node2D:
		return p as Node2D

	var scene: Node = get_tree().current_scene
	if scene == null:
		return null

	var found: Node = scene.find_child("Player", true, false)
	if found != null and found is Node2D:
		return found as Node2D

	return null


func _find_inventory_screen() -> Node:
	var inv: Node = get_tree().get_first_node_in_group("inventory_screen")
	if inv != null:
		return inv

	var scene: Node = get_tree().current_scene
	if scene == null:
		return null

	return scene.find_child("InventoryScreen", true, false)


func _find_game_state() -> Node:
	var gs: Node = get_tree().get_first_node_in_group("game_state")
	if gs != null:
		return gs

	var scene: Node = get_tree().current_scene
	if scene != null:
		var found: Node = scene.find_child("GameState", true, false)
		if found != null:
			return found

	return null
