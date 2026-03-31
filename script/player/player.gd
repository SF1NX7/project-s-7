extends CharacterBody2D

var tile_size: int = 32
var move_speed: float = 200.0
var moving: bool = false
var target_position: Vector2
var can_move: bool = true

@onready var blocked_layer = $"../Blocked"

func _ready() -> void:
	target_position = global_position

func _process(delta: float) -> void:
	if not can_move:
		return

	if moving:
		global_position = global_position.move_toward(target_position, move_speed * delta)

		if global_position.distance_to(target_position) < 1.0:
			global_position = target_position
			moving = false
			try_move()
	else:
		try_move()

func try_move() -> void:
	if Input.is_action_pressed("ui_right"):
		start_move(Vector2.RIGHT)
	elif Input.is_action_pressed("ui_left"):
		start_move(Vector2.LEFT)
	elif Input.is_action_pressed("ui_down"):
		start_move(Vector2.DOWN)
	elif Input.is_action_pressed("ui_up"):
		start_move(Vector2.UP)

func start_move(direction: Vector2) -> void:
	if moving:
		return

	var next_position = global_position + direction * tile_size
	var next_feet_position = $CollisionShape2D.global_position + direction * tile_size
	var cell = world_to_cell(next_feet_position)

	if is_npc_on_tile(next_feet_position):
		return

	if blocked_layer.get_cell_source_id(cell) != -1:
		return

	target_position = next_position
	moving = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		var dialogue_ui = get_tree().current_scene.get_node_or_null("DialogueUI")

		if dialogue_ui != null and dialogue_ui.is_active:
			dialogue_ui.next_line()
			return

		if moving:
			return

		var interaction_area = get_node_or_null("InteractionArea")
		if interaction_area == null:
			return

		for area in interaction_area.get_overlapping_areas():
			if area.get_parent().has_method("interact"):
				area.get_parent().interact()
				return

func get_feet_world_pos(node: Node2D) -> Vector2:
	return node.get_node("CollisionShape2D").global_position

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local_pos = blocked_layer.to_local(world_pos)
	return blocked_layer.local_to_map(local_pos)

func is_npc_on_tile(world_pos: Vector2) -> bool:
	var target_cell = world_to_cell(world_pos)

	for npc in get_tree().get_nodes_in_group("npcs"):
		var npc_cell = world_to_cell(get_feet_world_pos(npc))
		if npc_cell == target_cell:
			return true

	return false
