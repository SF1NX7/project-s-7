extends Area2D

const PIXEL_TRANSITION: PackedScene = preload("res://scene/battle/PixelTransition.tscn")

@export_file("*.tscn") var battle_scene: String = "res://scene/battle/BattleTest.tscn"

@export_group("Pixel transition")
@export_range(0.1, 3.0, 0.05, "suffix:s") var transition_duration: float = 0.5
@export_range(2.0, 64.0, 1.0, "suffix:px") var pixel_size: float = 8.0
@export var dissolve_color: Color = Color.BLACK

@export_group("Повторяемость встречи")
## Если включено, после победы этот сюжетный бой больше не запускается в текущей игре.
@export var one_time_encounter: bool = true
## Уникальный постоянный ID встречи. Например world2_goblin_01. Если пусто, используется путь ноды в сцене.
@export var encounter_id_override: String = ""

var _starting: bool = false

func _encounter_key() -> String:
	if not encounter_id_override.strip_edges().is_empty():
		return encounter_id_override.strip_edges()
	return str(get_path())

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var context: Node = get_node_or_null("/root/BattleReturnContext")
	if one_time_encounter and context != null and context.has_method("is_encounter_completed"):
		if bool(context.call("is_encounter_completed", _encounter_key())):
			monitoring = false
			print("S7 ENCOUNTER: сюжетная встреча уже побеждена: ", _encounter_key())

func _on_body_entered(body: Node2D) -> void:
	if _starting or not body.is_in_group("player"):
		return
	if one_time_encounter:
		var check_context: Node = get_node_or_null("/root/BattleReturnContext")
		if check_context != null and check_context.has_method("is_encounter_completed"):
			if bool(check_context.call("is_encounter_completed", _encounter_key())):
				return
	var return_context: Node = get_node_or_null("/root/BattleReturnContext")
	if return_context != null and return_context.call("is_encounter_blocked"):
		return
	if battle_scene.is_empty():
		push_warning("BattleTrigger: battle_scene is empty.")
		return

	# Фиксируем место встречи ДО остановки игрока и смены сцены.
	if return_context != null:
		var world_scene: Node = get_tree().current_scene
		if world_scene != null:
			return_context.call("capture", world_scene.scene_file_path, body, _encounter_key(), one_time_encounter)
	else:
		push_warning("BattleTrigger: добавь BattleReturnContext в Autoload.")
	# Existing World_2 InventoryScreen may hold the starting donut only in its
	# exported starting_items. Import it into the existing global service now,
	# before the World scene (and its UI) gets replaced.
	var inventory_service: Node = get_node_or_null("/root/Inventory_Service")
	if inventory_service != null and inventory_service.has_method("get_item_ids"):
		inventory_service.call("get_item_ids")
	_starting = true
	set_deferred("monitoring", false)

	if "can_move" in body:
		body.can_move = false
	if "moving" in body:
		body.moving = false
	if "target_position" in body:
		body.target_position = body.global_position

	var transition: CanvasLayer = PIXEL_TRANSITION.instantiate()
	get_tree().root.add_child(transition)
	transition.call("play", battle_scene, transition_duration, pixel_size, dissolve_color)
